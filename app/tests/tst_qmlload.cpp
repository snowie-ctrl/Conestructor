#include <QQmlApplicationEngine>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QImage>
#include <QJSValue>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QSettings>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>
#include <QtMath>
#include <cmath>
#include <QtQml/QQmlExtensionPlugin>

Q_IMPORT_QML_PLUGIN(ConestructorPlugin)

// Every item drawn under `root` (Repeater delegates have no QObject parent, so findChildren misses them).
static QList<QQuickItem *> allItems(QQuickItem *root)
{
    QList<QQuickItem *> out;
    for (QQuickItem *child : root->childItems()) {
        out << child;
        out << allItems(child);
    }
    return out;
}

static QQuickItem *findBanner(QQuickWindow *window)
{
    for (QQuickItem *item : allItems(window->contentItem()))
        if (QByteArray(item->metaObject()->className()).startsWith("ErrorBanner"))
            return item;
    return nullptr;
}

// A visible button with this text (dialog buttons included: the overlay is under the content item).
static QQuickItem *findButton(QQuickWindow *window, const QString &text)
{
    for (QQuickItem *item : allItems(window->contentItem()))
        if (item->isVisible() && item->property("text").toString() == text
            && QByteArray(item->metaObject()->className()).contains("Button"))
            return item;
    return nullptr;
}

// The visible setting with this label.
static QQuickItem *findField(QQuickWindow *window, const QString &label)
{
    for (QQuickItem *item : allItems(window->contentItem())) {
        const QVariant def = item->property("def");
        if (def.isValid() && item->isVisible() && def.toMap().value(QStringLiteral("label")).toString() == label)
            return item;
    }
    return nullptr;
}

static QQuickItem *textBox(QQuickItem *field)
{
    for (QQuickItem *item : allItems(field))
        if (QByteArray(item->metaObject()->className()).contains("TextField"))
            return item;
    return nullptr;
}

// Whether a QML `var` property holds null (or nothing).
static bool isNull(const QVariant &v)
{
    return !v.isValid() || v.isNull() || qvariant_cast<QJSValue>(v).isNull();
}

// A QML `var` value as plain Qt values (a JS array becomes a QVariantList, an object a QVariantMap).
static QVariant plain(const QVariant &v)
{
    return v.userType() == qMetaTypeId<QJSValue>() ? qvariant_cast<QJSValue>(v).toVariant() : v;
}

// Types text into whatever has focus in `window` (QTest::keyClicks takes widgets only).
static void typeText(QWindow *window, const QString &text)
{
    for (const QChar c : text)
        QTest::keyClick(window, c.toLatin1());
}

// One loaded Main with the helpers the part 3 window tests share.
struct Loaded
{
    QQmlApplicationEngine engine;
    QQuickWindow *window = nullptr;
    QQuickItem *canvas = nullptr;
    QObject *store = nullptr;

    // Loads and shows Main; `demo` loads the example track (setup done) and waits for it to be fitted.
    bool load(bool demo)
    {
        engine.loadFromModule("Conestructor", "Main");
        if (engine.rootObjects().isEmpty())
            return false;
        window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        if (!window || !QTest::qWaitForWindowExposed(window))
            return false;
        window->requestActivate();
        if (!QTest::qWaitForWindowActive(window))
            return false;
        canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        if (!canvas || !store)
            return false;
        if (demo)
            QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        return QTest::qWaitFor([this]() { return !canvas->property("fitPending").toBool(); });
    }

    QVariantMap element(const QString &id) const
    {
        QVariant v;
        QMetaObject::invokeMethod(store, "element", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, id));
        return qvariant_cast<QJSValue>(v).toVariant().toMap();
    }
    QVariantMap track() const { return plain(store->property("track")).toMap(); }
    double mpp() const { return store->property("mpp").toDouble(); }
    double zoom() const { return canvas->property("zoom").toDouble(); }
    // A point in canvas metres, on screen (canvas coordinates).
    QPointF screen(double mx, double my) const
    {
        QVariant v;
        QMetaObject::invokeMethod(canvas, "toScreen", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, mx / mpp()),
                                  Q_ARG(QVariant, my / mpp()));
        const QVariantMap p = qvariant_cast<QJSValue>(v).toVariant().toMap();
        return { p.value("x").toDouble(), p.value("y").toDouble() };
    }
    // A screen point (canvas coordinates) in photo pixels.
    QPointF world(QPointF s) const
    {
        QVariant v;
        QMetaObject::invokeMethod(canvas, "toWorld", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, s.x()), Q_ARG(QVariant, s.y()));
        const QVariantMap p = qvariant_cast<QJSValue>(v).toVariant().toMap();
        return { p.value("x").toDouble(), p.value("y").toDouble() };
    }
    QPoint scene(QPointF p) const { return canvas->mapToScene(p).toPoint(); }
    void click(QPointF p, Qt::MouseButton button = Qt::LeftButton) const { QTest::mouseClick(window, button, {}, scene(p)); }
    void drag(QPointF from, QPointF to, int steps = 8) const
    {
        const QPoint a = scene(from);
        const QPoint b = scene(to);
        QTest::mousePress(window, Qt::LeftButton, {}, a);
        for (int i = 1; i <= steps; ++i)
            QTest::mouseMove(window, a + (b - a) * i / steps);
        QTest::mouseRelease(window, Qt::LeftButton, {}, b);
    }
    void clickItem(QQuickItem *item) const
    {
        QTest::mouseClick(window, Qt::LeftButton, {}, item->mapToScene(QPointF(item->width() / 2, item->height() / 2)).toPoint());
    }
    void run(const QString &name, const QVariantMap &args) const
    {
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, name), Q_ARG(QVariant, args));
    }
    QString label() const { return store->property("undoLabel").toString(); }
    QQuickItem *named(const QString &objectName) const
    {
        for (QQuickItem *item : allItems(window->contentItem()))
            if (item->objectName() == objectName)
                return item;
        return nullptr;
    }
    // The palette or checklist tile for `kind`.
    QQuickItem *tile(const QString &kind) const
    {
        for (QQuickItem *item : allItems(window->contentItem()))
            if (QByteArray(item->metaObject()->className()).startsWith("PaletteTile") && item->property("kind").toString() == kind)
                return item;
        return nullptr;
    }
    // The ElementView drawing element `id`.
    QQuickItem *view(const QString &id) const
    {
        for (QQuickItem *item : allItems(window->contentItem())) {
            if (!QByteArray(item->metaObject()->className()).startsWith("ElementView"))
                continue;
            const QVariantMap e = qvariant_cast<QJSValue>(item->property("element")).toVariant().toMap();
            if (e.value("id").toString() == id)
                return item;
        }
        return nullptr;
    }
};

// Loads the real window offscreen. Any warning from QML (a broken binding, a missing property) fails the run.
class TestQmlLoad : public QObject
{
    Q_OBJECT

    QTemporaryDir dir;

private slots:
    void initTestCase()
    {
        // Before anything reads settings, so the owner's real ini is never read or written.
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, dir.path());
        QQuickStyle::setStyle(QStringLiteral("Fusion"));
    }

    // Per test function: a failOnWarning set in initTestCase does not reach the test functions.
    void init()
    {
        QTest::failOnWarning(QRegularExpression(QStringLiteral("\\.qml|\\.mjs|QML")));
    }

    void mainOpensWithTheTitle()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        QCOMPARE(engine.rootObjects().size(), 1);
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(window);
        QCOMPARE(window->title(), QStringLiteral("Conestructor 0.4 \u2014 Untitled"));
    }

    void theExampleTrackDrawsAndPlacesCones()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        QObject *root = engine.rootObjects().first();
        QVERIFY(QMetaObject::invokeMethod(root, "loadDemo", Q_ARG(QVariant, QVariant(true))));
        QTest::qWait(300);
        QVariant count;
        QVERIFY(QMetaObject::invokeMethod(root, "conesPlaced", Q_RETURN_ARG(QVariant, count)));
        QVERIFY2(count.toInt() > 40, qPrintable(QStringLiteral("%1 cones").arg(count.toInt())));
    }
    // Drags with real mouse events: placing Origin and the ruler from the palette's functions, then dragging Origin
    // and one ruler end. Each drag must undo as one step, named in the Edit menu.
    void draggingTargetsAndTheRulerUndoesAsOneStep()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        QVERIFY(canvas);
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QVERIFY(store);
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);

        auto drag = [&](QPointF from, QPointF to) {
            const QPoint a = canvas->mapToScene(from).toPoint();
            const QPoint b = canvas->mapToScene(to).toPoint();
            QTest::mousePress(window, Qt::LeftButton, {}, a);
            for (int i = 1; i <= 5; ++i)
                QTest::mouseMove(window, a + (b - a) * i / 5);
            QTest::mouseRelease(window, Qt::LeftButton, {}, b);
        };

        QMetaObject::invokeMethod(canvas, "beginPlacing", Q_ARG(QVariant, QStringLiteral("origin")));
        QMetaObject::invokeMethod(canvas, "finishPlacing", Q_ARG(QVariant, 400.0), Q_ARG(QVariant, 300.0));
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Place Origin"));
        drag({ 400, 300 }, { 460, 330 });
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Move Origin"));

        QMetaObject::invokeMethod(canvas, "beginPlacing", Q_ARG(QVariant, QStringLiteral("ruler")));
        QMetaObject::invokeMethod(canvas, "finishPlacing", Q_ARG(QVariant, 700.0), Q_ARG(QVariant, 500.0));
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Set ruler"));
        drag({ 620, 500 }, { 600, 540 });     // the ruler's first end sits 80 screen pixels left of where it landed

        QMetaObject::invokeMethod(store, "undo");   // the end drag
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Set ruler"));
        QMetaObject::invokeMethod(store, "undo");   // placing the ruler
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Move Origin"));
        QMetaObject::invokeMethod(store, "undo");   // the Origin drag
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Place Origin"));
    }
    // Editing the example track with real mouse and key events: select, drag away (unjoins), drag back (snaps and
    // joins), rotate with the handle, pan from on top of an element, duplicate, delete and undo.
    void editingElementsWithTheMouse()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        window->requestActivate();
        QVERIFY(QTest::qWaitForWindowActive(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QVERIFY(canvas && store);
        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);

        auto element = [&](const QString &id) {
            QVariant v;
            QMetaObject::invokeMethod(store, "element", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, id));
            return qvariant_cast<QJSValue>(v).toVariant().toMap();
        };
        auto joined = [&](const QString &id, const QString &end) {
            return !element(id).value(QStringLiteral("joins")).toMap().value(end).isNull();
        };
        const double mpp = store->property("mpp").toDouble();
        // An element's middle on screen, in canvas coordinates.
        auto middle = [&](const QString &id) {
            const QVariantMap e = element(id);
            QVariant v;
            QMetaObject::invokeMethod(canvas, "toScreen", Q_RETURN_ARG(QVariant, v),
                                      Q_ARG(QVariant, e.value("x").toDouble() / mpp),
                                      Q_ARG(QVariant, e.value("y").toDouble() / mpp));
            const QVariantMap p = qvariant_cast<QJSValue>(v).toVariant().toMap();
            return QPointF(p.value("x").toDouble(), p.value("y").toDouble());
        };
        auto scene = [&](QPointF p) { return canvas->mapToScene(p).toPoint(); };
        auto drag = [&](QPointF from, QPointF to, Qt::MouseButton button = Qt::LeftButton) {
            const QPoint a = scene(from);
            const QPoint b = scene(to);
            QTest::mousePress(window, button, {}, a);
            for (int i = 1; i <= 8; ++i)
                QTest::mouseMove(window, a + (b - a) * i / 8);
            QTest::mouseRelease(window, button, {}, b);
        };
        auto label = [&]() { return store->property("undoLabel").toString(); };

        // Select the Straight (e1, joined at B to the Slalom), then click empty canvas.
        const QPointF straight = middle("e1");
        QTest::mouseClick(window, Qt::LeftButton, {}, scene(straight));
        QCOMPARE(store->property("selectedId").toString(), QStringLiteral("e1"));
        QTest::mouseClick(window, Qt::LeftButton, {}, scene(QPointF(30, 30)));
        QCOMPARE(store->property("selectedId").toString(), QString());

        // Drag it well away: it unjoins, and so does its neighbour.
        drag(straight, straight + QPointF(0, 150));
        QCOMPARE(label(), QStringLiteral("Move Straight"));
        QVERIFY(!joined("e1", "B"));
        QVERIFY(!joined("e2", "A"));
        // Drag it back: it snaps and joins again.
        drag(straight + QPointF(0, 150), straight + QPointF(6, 4));
        QVERIFY(joined("e1", "B"));
        QCOMPARE(element("e2").value("joins").toMap().value("A").toMap().value("id").toString(), QStringLiteral("e1"));

        // The rotate handle sits above the selected Straight; dragging it a quarter turn about the middle turns it
        // by about 90 degrees, as one step.
        const double zoom = canvas->property("zoom").toDouble();
        const QPointF centre = middle("e1");
        const double reach = (2.0 / mpp) * zoom + 24.0;       // half the 4 m track width, plus 24 screen pixels
        const QPointF handle = centre - QPointF(0, reach);
        QPointF last = handle;
        QTest::mousePress(window, Qt::LeftButton, {}, scene(handle));
        for (int i = 1; i <= 9; ++i) {
            const double a = -M_PI / 2 + (M_PI / 2) * i / 9;
            last = centre + QPointF(std::cos(a) * reach, std::sin(a) * reach);
            QTest::mouseMove(window, scene(last));
        }
        QTest::mouseRelease(window, Qt::LeftButton, {}, scene(last));
        QCOMPARE(label(), QStringLiteral("Rotate Straight"));
        QVERIFY2(std::abs(element("e1").value("rotation").toDouble() - 90) < 3,
                 qPrintable(QString::number(element("e1").value("rotation").toDouble())));
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(element("e1").value("rotation").toDouble(), 0.0);

        // A middle-button drag that starts on an element pans and leaves the element where it is.
        const double panX = canvas->property("panX").toDouble();
        const QString before = label();
        drag(middle("e1"), middle("e1") + QPointF(40, 0), Qt::MiddleButton);
        QCOMPARE(canvas->property("panX").toDouble(), panX + 40);
        QCOMPARE(label(), before);

        // Ctrl+D duplicates the selection and selects the copy; Delete removes it; undo brings it back.
        QTest::mouseClick(window, Qt::LeftButton, {}, scene(middle("e1")));
        QTest::keyClick(window, Qt::Key_D, Qt::ControlModifier);
        QCOMPARE(store->property("elementCount").toInt(), 5);
        QCOMPARE(store->property("selectedId").toString(), QStringLiteral("e5"));
        QCOMPARE(label(), QStringLiteral("Duplicate Straight"));
        QTest::keyClick(window, Qt::Key_Delete);
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QCOMPARE(label(), QStringLiteral("Delete Straight"));
        QTest::keyClick(window, Qt::Key_Z, Qt::ControlModifier);
        QCOMPARE(store->property("elementCount").toInt(), 5);

        // Resizing the window changes what is visible, never the zoom.
        const double zoomBefore = canvas->property("zoom").toDouble();
        window->resize(1200, 800);
        QTRY_COMPARE(canvas->width() < 1200, true);
        QCOMPARE(canvas->property("zoom").toDouble(), zoomBefore);
    }

    // The property panel with real clicks and typing.
    void thePropertyPanelEditsTheSelection()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        window->requestActivate();
        QVERIFY(QTest::qWaitForWindowActive(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QObject *settings = engine.singletonInstance<QObject *>("Conestructor", "Settings");
        QVERIFY(canvas && store && settings);
        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);

        auto element = [&](const QString &id) {
            QVariant v;
            QMetaObject::invokeMethod(store, "element", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, id));
            return qvariant_cast<QJSValue>(v).toVariant().toMap();
        };
        auto prop = [&](const QString &id, const QString &key) {
            return element(id).value(QStringLiteral("props")).toMap().value(key).toDouble();
        };
        auto joined = [&](const QString &id, const QString &end) {
            return !element(id).value(QStringLiteral("joins")).toMap().value(end).isNull();
        };
        // The visible setting with this label, and its text box.
        auto field = [&](const QString &label) -> QQuickItem * {
            for (QQuickItem *item : allItems(window->contentItem())) {
                const QVariant def = item->property("def");
                if (def.isValid() && item->isVisible()
                    && def.toMap().value(QStringLiteral("label")).toString() == label)
                    return item;
            }
            return nullptr;
        };
        auto box = [&](QQuickItem *f) -> QQuickItem * {
            for (QQuickItem *item : allItems(f))
                if (QByteArray(item->metaObject()->className()).contains("TextField"))
                    return item;
            return nullptr;
        };
        auto click = [&](QQuickItem *item) {
            QTest::mouseClick(window, Qt::LeftButton, {},
                              item->mapToScene(QPointF(item->width() / 2, item->height() / 2)).toPoint());
        };
        // QTest::keyClicks takes only widgets; this types into the window one character at a time.
        auto typeText = [&](const QString &text) {
            for (const QChar c : text)
                QTest::keyClick(window, c.toLatin1());
        };
        auto retype = [&](QQuickItem *input, const QString &text) {
            click(input);
            QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
            typeText(text);
        };
        auto label = [&]() { return store->property("undoLabel").toString(); };

        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QStringLiteral("e3")));      // the Turn
        QQuickItem *width = field(QStringLiteral("Track width"));
        QVERIFY(width);
        QVERIFY(field(QStringLiteral("Turn angle")));
        QVERIFY(!field(QStringLiteral("Exit radius")));
        QQuickItem *input = box(width);
        QVERIFY(input);
        QCOMPARE(input->property("text").toString(), QStringLiteral("13' 1\""));

        // Typing applies as you go, keeps the chain joined, and is one undo step.
        retype(input, QStringLiteral("12' 6\""));
        QVERIFY(std::abs(prop("e3", "trackWidth") - 3.81) < 1e-9);
        QVERIFY(joined("e2", "B") && joined("e4", "A"));
        // Not a value: red, element unchanged; Esc puts the old text back.
        QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
        typeText(QStringLiteral("abc"));
        QVERIFY(width->property("bad").toBool());
        QVERIFY(std::abs(prop("e3", "trackWidth") - 3.81) < 1e-9);
        QTest::keyClick(window, Qt::Key_Escape);
        QVERIFY(!width->property("bad").toBool());
        QCOMPARE(input->property("text").toString(), QStringLiteral("12' 6\""));
        // Editing keys stay in the field: Backspace and Delete do not delete the element, F does not fit.
        const double zoom = canvas->property("zoom").toDouble();
        QTest::keyClick(window, Qt::Key_End);
        QTest::keyClick(window, Qt::Key_Backspace);
        QTest::keyClick(window, Qt::Key_Delete);
        typeText(QStringLiteral("f"));
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QCOMPARE(canvas->property("zoom").toDouble(), zoom);
        QTest::keyClick(window, Qt::Key_Escape);
        // The up arrow steps one inch; Enter ends the bout, and one undo takes it all back.
        QTest::keyClick(window, Qt::Key_Up);
        QVERIFY(std::abs(prop("e3", "trackWidth") - (3.81 + 0.0254)) < 1e-9);
        QTest::keyClick(window, Qt::Key_Return);
        QCOMPARE(label(), QStringLiteral("Change Track width"));
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(prop("e3", "trackWidth"), 4.0);
        // Out of limits: kept within them, with a note.
        retype(input, QStringLiteral("50 m"));
        QCOMPARE(prop("e3", "trackWidth"), 20.0);
        QCOMPARE(width->property("note").toString(), QStringLiteral("Kept within 3' 3\" to 65' 7\""));
        QTest::keyClick(window, Qt::Key_Return);

        // A changing radius shows Exit radius.
        QQuickItem *changing = nullptr;
        for (QQuickItem *item : allItems(window->contentItem()))
            if (item->isVisible() && item->property("text").toString() == QStringLiteral("Changing")
                && QByteArray(item->metaObject()->className()).contains("Button"))
                changing = item;
        QVERIFY(changing);
        click(changing);
        QCOMPARE(element("e3").value("props").toMap().value("radiusType").toString(), QStringLiteral("changing"));
        QTRY_VERIFY(field(QStringLiteral("Exit radius")));

        // The ruler's real length: elements keep their photo spots and sizes, chains stay joined; undo restores.
        const double mppBefore = store->property("mpp").toDouble();
        const double e1Pixels = element("e1").value("x").toDouble() / mppBefore;
        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QStringLiteral("ruler")));
        QQuickItem *length = field(QStringLiteral("Real length"));
        QVERIFY(length);
        retype(box(length), QStringLiteral("30 m"));
        QTest::keyClick(window, Qt::Key_Return);
        const double mppAfter = store->property("mpp").toDouble();
        QVERIFY(std::abs(mppAfter - mppBefore * 1.5) < 1e-12);
        QVERIFY(std::abs(element("e1").value("x").toDouble() / mppAfter - e1Pixels) < 1e-6);
        QCOMPARE(prop("e1", "length"), 20.0);
        QVERIFY(joined("e1", "B") && joined("e2", "B") && joined("e3", "B"));
        QCOMPARE(label(), QStringLiteral("Set ruler"));
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(store->property("mpp").toDouble(), mppBefore);

        // Units: switching to metres changes the fields at once.
        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QStringLiteral("e1")));
        QCOMPARE(box(field(QStringLiteral("Length")))->property("text").toString(), QStringLiteral("65' 7\""));
        settings->setProperty("units", QStringLiteral("m"));
        QCOMPARE(box(field(QStringLiteral("Length")))->property("text").toString(), QStringLiteral("20 m"));
        settings->setProperty("units", QStringLiteral("ftin"));
    }

    // Placing cones draws them; the toggles, Clear preview and the banners for what is missing.
    void thePreviewAndItsBanners()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QVERIFY(canvas && store);
        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(true)));
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);

        // Cone pictures on the canvas, and where the first one sits.
        auto cones = [&]() {
            QList<QQuickItem *> out;
            for (QQuickItem *item : allItems(canvas))
                if (item->isVisible() && item->property("source").toString().endsWith(QStringLiteral("-cone.png")))
                    out << item;
            return out;
        };
        auto placed = [&]() {
            QVariant n;
            QMetaObject::invokeMethod(window, "conesPlaced", Q_RETURN_ARG(QVariant, n));
            return n.toInt();
        };
        auto banner = [&]() -> QQuickItem * {
            for (QQuickItem *item : allItems(window->contentItem()))
                if (QByteArray(item->metaObject()->className()).startsWith("ErrorBanner"))
                    return item;
            return nullptr;
        };

        QVERIFY(placed() > 40);
        QCOMPARE(cones().size(), placed());
        QVERIFY(store->property("message").toString().startsWith(QStringLiteral("Placed ")));

        // Show cones off hides them; on brings them back.
        store->setProperty("showCones", false);
        QCOMPARE(cones().size(), 0);
        store->setProperty("showCones", true);
        QCOMPARE(cones().size(), placed());

        // Moving an element while the preview is on moves its cones.
        const double before = cones().first()->x();
        QVariantMap args{ { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } };
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("place")), Q_ARG(QVariant, args));
        QTRY_VERIFY(std::abs(cones().first()->x() - before) > 1);

        // Clear preview removes the overlay.
        QMetaObject::invokeMethod(store, "clearPreview");
        QCOMPARE(cones().size(), 0);

        // A new track has no ruler; a ruler without a length gets "Show me", which selects it.
        QMetaObject::invokeMethod(store, "newTrack");
        QMetaObject::invokeMethod(store, "placeCones");
        QVERIFY(banner()->isVisible());
        QCOMPARE(banner()->property("text").toString(),
                 QStringLiteral("Place the ruler on something of known length, then set its real length"));
        QVariantMap ruler{ { "a", QVariantMap{ { "x", 100 }, { "y", 100 } } },
                           { "b", QVariantMap{ { "x", 300 }, { "y", 100 } } }, { "realLength", 0 } };
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("setRuler")), Q_ARG(QVariant, ruler));
        QMetaObject::invokeMethod(store, "placeCones");
        QCOMPARE(banner()->property("text").toString(), QStringLiteral("Set the ruler's real length"));
        QMetaObject::invokeMethod(canvas, "showTarget", Q_ARG(QVariant, banner()->property("target")));
        QCOMPARE(store->property("selectedId").toString(), QStringLiteral("ruler"));
    }

    // A click whose pointer wobbles a pixel only selects: it moves nothing, keeps the chain joined, records no step.
    void aClickWithAWobbleOnlySelects()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QVERIFY(canvas && store);
        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);

        auto element = [&](const QString &id) {
            QVariant v;
            QMetaObject::invokeMethod(store, "element", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, id));
            return qvariant_cast<QJSValue>(v).toVariant().toMap();
        };
        const double mpp = store->property("mpp").toDouble();
        const QVariantMap slalom = element(QStringLiteral("e2"));
        QVariant v;
        QMetaObject::invokeMethod(canvas, "toScreen", Q_RETURN_ARG(QVariant, v),
                                  Q_ARG(QVariant, slalom.value("x").toDouble() / mpp),
                                  Q_ARG(QVariant, slalom.value("y").toDouble() / mpp));
        const QVariantMap p = qvariant_cast<QJSValue>(v).toVariant().toMap();
        const QPoint middle = canvas->mapToScene(QPointF(p.value("x").toDouble(), p.value("y").toDouble())).toPoint();

        QTest::mousePress(window, Qt::LeftButton, {}, middle);
        QTest::mouseMove(window, middle + QPoint(1, 0));
        QTest::mouseMove(window, middle + QPoint(1, 1));
        QTest::mouseRelease(window, Qt::LeftButton, {}, middle + QPoint(1, 1));

        QCOMPARE(store->property("selectedId").toString(), QStringLiteral("e2"));
        QVERIFY(!store->property("canUndo").toBool());
        const QVariantMap joins = element(QStringLiteral("e2")).value("joins").toMap();
        QVERIFY(!joins.value("A").isNull());
        QVERIFY(!joins.value("B").isNull());
    }
    // A lot photo loads through PhotoStore as one undo step; something that is not a picture leaves it alone.
    void aLotPhotoLoadsAndUndoes()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QObject *photos = engine.singletonInstance<QObject *>("Conestructor", "PhotoStore");
        auto *photo = window->findChild<QQuickItem *>(QStringLiteral("photo"));
        QVERIFY(store && photos && photo);
        auto kind = [&]() {
            return qvariant_cast<QJSValue>(store->property("track")).property("photo").property("kind").toString();
        };

        QImage image(200, 100, QImage::Format_RGB32);
        image.fill(Qt::darkGreen);
        const QString path = dir.filePath(QStringLiteral("lot.png"));
        QVERIFY(image.save(path));
        QMetaObject::invokeMethod(window, "loadPhoto", Q_ARG(QVariant, QVariant(QUrl::fromLocalFile(path))));
        QCOMPARE(kind(), QStringLiteral("image"));
        QVERIFY(photo->property("source").toString().startsWith(QStringLiteral("image://photo/")));
        QTRY_COMPARE(photo->property("status").toInt(), 1);          // Image.Ready
        QCOMPARE(photo->property("implicitWidth").toDouble(), 200.0);
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Load photo"));

        QFile notes(dir.filePath(QStringLiteral("notes.png")));
        QVERIFY(notes.open(QIODevice::WriteOnly));
        notes.write("hello");
        notes.close();
        QMetaObject::invokeMethod(window, "loadPhoto", Q_ARG(QVariant, QVariant(QUrl::fromLocalFile(notes.fileName()))));
        QCOMPARE(findBanner(window)->property("text").toString(),
                 QStringLiteral("Could not open that photo. The background is unchanged."));
        QCOMPARE(store->property("undoLabel").toString(), QStringLiteral("Load photo"));

        // A bundled picture loads through its qrc: URL (the Backgrounds menu does this).
        QVariantMap loaded;
        QVERIFY(QMetaObject::invokeMethod(photos, "load", Q_RETURN_ARG(QVariantMap, loaded),
                                          Q_ARG(QString, QStringLiteral("qrc:/qt/qml/Conestructor/assets/images/blueprintBackground.png"))));
        QVERIFY(loaded.value(QStringLiteral("ref")).toInt() > 0);

        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(kind(), QStringLiteral("none"));
        QCOMPARE(photo->property("source").toString(),
                 QStringLiteral("qrc:/qt/qml/Conestructor/assets/images/blueprintBackground.png"));
    }
    // Save writes a .cone the title and Open Recent know about; Open brings it back exactly, with its photo and no
    // undo history; a file that is not a track, or has gone, leaves the open track alone.
    void savingAndOpeningATrack()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QObject *settings = engine.singletonInstance<QObject *>("Conestructor", "Settings");
        auto *photo = window->findChild<QQuickItem *>(QStringLiteral("photo"));
        QVERIFY(store && settings && photo);
        const QString dash = QStringLiteral("Conestructor 0.4 \u2014 ");

        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QCOMPARE(window->title(), dash + QStringLiteral("Untitled"));

        // An edit marks it unsaved; undoing back to the saved state clears the mark.
        QVariantMap move{ { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } };
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("place")), Q_ARG(QVariant, move));
        QCOMPARE(window->title(), dash + QStringLiteral("Untitled*"));
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(window->title(), dash + QStringLiteral("Untitled"));
        QMetaObject::invokeMethod(store, "redo");

        // Save, with a lot photo.
        QImage image(200, 100, QImage::Format_RGB32);
        image.fill(Qt::darkGreen);
        const QString picture = dir.filePath(QStringLiteral("save-lot.png"));
        QVERIFY(image.save(picture));
        QMetaObject::invokeMethod(window, "loadPhoto", Q_ARG(QVariant, QVariant(QUrl::fromLocalFile(picture))));
        const QString path = dir.filePath(QStringLiteral("Duck pond.cone"));
        QVariant ok;
        QMetaObject::invokeMethod(store, "saveTo", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, path));
        QVERIFY(ok.toBool());
        QCOMPARE(window->title(), dash + QStringLiteral("Duck pond"));
        QCOMPARE(settings->property("recentFiles").toStringList().value(0), QDir::toNativeSeparators(path));
        const QString saved = store->property("trackText").toString();

        QFile file(path);
        QVERIFY(file.open(QIODevice::ReadOnly));
        const QByteArray raw = file.readAll();
        file.close();
        QVERIFY(raw.startsWith("{\n  \"format\": \"conestructor-track\",\n  \"version\": 1,\n  \"name\": \"Duck pond\""));
        const QJsonObject doc = QJsonDocument::fromJson(raw).object();
        QVERIFY(doc.value(QStringLiteral("cones")).toArray().size() > 40);
        QCOMPARE(doc.value(QStringLiteral("photo")).toObject().value(QStringLiteral("mediaType")).toString(),
                 QStringLiteral("image/png"));
        QCOMPARE(doc.value(QStringLiteral("design")).toObject().value(QStringLiteral("elements")).toArray().size(), 4);

        // New, then open it again: the same track, its photo, no undo history.
        QMetaObject::invokeMethod(store, "newTrack");
        QCOMPARE(store->property("elementCount").toInt(), 0);
        QCOMPARE(window->title(), dash + QStringLiteral("Untitled"));
        QMetaObject::invokeMethod(window, "openTrack", Q_ARG(QVariant, path));
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QCOMPARE(window->title(), dash + QStringLiteral("Duck pond"));
        QVERIFY(!store->property("canUndo").toBool());
        auto withoutRef = [](const QString &text) {
            QJsonObject o = QJsonDocument::fromJson(text.toUtf8()).object();
            QJsonObject p = o.value(QStringLiteral("photo")).toObject();
            p.remove(QStringLiteral("ref"));
            o.insert(QStringLiteral("photo"), p);
            return o;
        };
        QCOMPARE(withoutRef(store->property("trackText").toString()), withoutRef(saved));
        QVERIFY(photo->property("source").toString().startsWith(QStringLiteral("image://photo/")));
        QTRY_COMPARE(photo->property("status").toInt(), 1);
        QCOMPARE(photo->property("implicitWidth").toDouble(), 200.0);

        // Not a track: a banner, and the open track stays.
        const QString notes = dir.filePath(QStringLiteral("notes.cone"));
        QFile bad(notes);
        QVERIFY(bad.open(QIODevice::WriteOnly));
        bad.write("hello");
        bad.close();
        QMetaObject::invokeMethod(window, "openTrack", Q_ARG(QVariant, notes));
        QCOMPARE(findBanner(window)->property("text").toString(), QStringLiteral("That file isn't a Conestructor track."));
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QCOMPARE(window->title(), dash + QStringLiteral("Duck pond"));

        // A recent file that has gone is dropped from the list.
        QVERIFY(QFile::remove(path));
        QMetaObject::invokeMethod(window, "openRecent", Q_ARG(QVariant, path));
        QVERIFY(findBanner(window)->property("text").toString().contains(QStringLiteral("isn't there any more")));
        QVERIFY(!settings->property("recentFiles").toStringList().contains(QDir::toNativeSeparators(path)));
    }

    // New and closing the window ask first when there are unsaved changes; Cancel keeps everything.
    void unsavedChangesAskFirst()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QObject *dialog = window->findChild<QObject *>(QStringLiteral("unsavedDialog"));
        QVERIFY(store && dialog);
        auto click = [&](const QString &text) {
            QQuickItem *button = findButton(window, text);
            QVERIFY2(button, qPrintable(text));
            QTest::mouseClick(window, Qt::LeftButton, {},
                              button->mapToScene(QPointF(button->width() / 2, button->height() / 2)).toPoint());
        };

        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QVariantMap move{ { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } };
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("place")), Q_ARG(QVariant, move));

        QMetaObject::invokeMethod(window, "newTrack");
        QTRY_VERIFY(dialog->property("opened").toBool());
        click(QStringLiteral("Cancel"));
        QTRY_VERIFY(!dialog->property("visible").toBool());
        QCOMPARE(store->property("elementCount").toInt(), 4);

        QMetaObject::invokeMethod(window, "newTrack");
        QTRY_VERIFY(dialog->property("opened").toBool());
        click(QStringLiteral("Don't save"));
        QTRY_COMPARE(store->property("elementCount").toInt(), 0);
        QCOMPARE(window->title(), QStringLiteral("Conestructor 0.4 \u2014 Untitled"));

        // Closing with changes asks too; Don't save closes.
        QMetaObject::invokeMethod(window, "useBlueprint");
        window->close();
        QTRY_VERIFY(dialog->property("opened").toBool());
        QVERIFY(window->isVisible());
        click(QStringLiteral("Don't save"));
        QTRY_VERIFY(!window->isVisible());
    }
    // A track named on the command line opens at start-up.
    void aFileNamedAtStartOpens()
    {
        const QString path = dir.filePath(QStringLiteral("Start.cone"));
        {
            QQmlApplicationEngine engine;
            engine.loadFromModule("Conestructor", "Main");
            QObject *window = engine.rootObjects().first();
            QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
            // No backup from an earlier test, so start() goes straight to the file.
            QMetaObject::invokeMethod(engine.singletonInstance<QObject *>("Conestructor", "TrackFile"), "deleteBackup");
            QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
            QVariant ok;
            QMetaObject::invokeMethod(store, "saveTo", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, path));
            QVERIFY(ok.toBool());
        }
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QMetaObject::invokeMethod(window, "start", Q_ARG(QVariant, path));
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QCOMPARE(window->title(), QStringLiteral("Conestructor 0.4 \u2014 Start"));
    }

    // Unsaved changes are backed up; at the next start the backup is offered; Discard forgets it; Save removes it.
    void aBackupIsOfferedAtStart()
    {
        auto click = [](QQuickWindow *window, const QString &text) {
            QQuickItem *button = findButton(window, text);
            QVERIFY2(button, qPrintable(text));
            QTest::mouseClick(window, Qt::LeftButton, {},
                              button->mapToScene(QPointF(button->width() / 2, button->height() / 2)).toPoint());
        };
        auto backup = [](QQmlApplicationEngine &engine) {
            QObject *files = engine.singletonInstance<QObject *>("Conestructor", "TrackFile");
            QVariantMap found;
            QMetaObject::invokeMethod(files, "findBackup", Q_RETURN_ARG(QVariantMap, found));
            return found;
        };
        {
            QQmlApplicationEngine engine;
            engine.loadFromModule("Conestructor", "Main");
            QObject *window = engine.rootObjects().first();
            QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
            QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
            QMetaObject::invokeMethod(window, "backUp");
            QVERIFY(backup(engine).isEmpty());                       // nothing unsaved, nothing backed up
            QVariantMap move{ { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } };
            QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("place")), Q_ARG(QVariant, move));
            QMetaObject::invokeMethod(window, "backUp");
            QCOMPARE(backup(engine).value(QStringLiteral("name")).toString(), QStringLiteral("Untitled"));
            // engine goes without a normal close: the backup stays, as after a crash
        }
        {
            QQmlApplicationEngine engine;
            engine.loadFromModule("Conestructor", "Main");
            auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
            QVERIFY(QTest::qWaitForWindowExposed(window));
            QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
            QObject *dialog = window->findChild<QObject *>(QStringLiteral("restoreDialog"));
            QVERIFY(dialog);
            QMetaObject::invokeMethod(window, "start", Q_ARG(QVariant, QString()));
            QTRY_VERIFY(dialog->property("opened").toBool());
            click(window, QStringLiteral("Restore"));
            QTRY_COMPARE(store->property("elementCount").toInt(), 4);
            QVERIFY(store->property("dirty").toBool());
            QCOMPARE(window->title(), QStringLiteral("Conestructor 0.4 \u2014 Untitled*"));
            QVERIFY(!backup(engine).isEmpty());                      // kept until saved or closed normally
            const QString path = dir.filePath(QStringLiteral("Restored.cone"));
            QVariant ok;
            QMetaObject::invokeMethod(store, "saveTo", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, path));
            QVERIFY(ok.toBool());
            QVERIFY(backup(engine).isEmpty());
        }
        {
            QQmlApplicationEngine engine;
            engine.loadFromModule("Conestructor", "Main");
            auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
            QVERIFY(QTest::qWaitForWindowExposed(window));
            QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
            QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
            QVariantMap move{ { "id", "e2" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } };
            QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("place")), Q_ARG(QVariant, move));
            QMetaObject::invokeMethod(window, "backUp");
            QMetaObject::invokeMethod(store, "newTrack");
            QMetaObject::invokeMethod(window, "start", Q_ARG(QVariant, QString()));
            QObject *dialog = window->findChild<QObject *>(QStringLiteral("restoreDialog"));
            QTRY_VERIFY(dialog->property("opened").toBool());
            click(window, QStringLiteral("Discard"));
            QTRY_VERIFY(backup(engine).isEmpty());
            QCOMPARE(store->property("elementCount").toInt(), 0);
        }
    }

    // Dropping a .cone opens it, a PNG or JPG becomes the lot photo, anything else gets a note.
    void droppingFilesOnTheWindow()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        const QString track = dir.filePath(QStringLiteral("Dropped.cone"));
        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QVariant ok;
        QMetaObject::invokeMethod(store, "saveTo", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, track));
        QMetaObject::invokeMethod(store, "newTrack");

        QMetaObject::invokeMethod(window, "dropped", Q_ARG(QVariant, QVariant(QUrl::fromLocalFile(track))));
        QCOMPARE(store->property("elementCount").toInt(), 4);

        QImage image(40, 30, QImage::Format_RGB32);
        image.fill(Qt::gray);
        const QString picture = dir.filePath(QStringLiteral("dropped.jpg"));
        QVERIFY(image.save(picture));
        QMetaObject::invokeMethod(window, "dropped", Q_ARG(QVariant, QVariant(QUrl::fromLocalFile(picture))));
        QCOMPARE(qvariant_cast<QJSValue>(store->property("track")).property("photo").property("kind").toString(),
                 QStringLiteral("image"));

        QMetaObject::invokeMethod(window, "dropped",
                                  Q_ARG(QVariant, QVariant(QUrl::fromLocalFile(dir.filePath(QStringLiteral("notes.txt"))))));
        QCOMPARE(findBanner(window)->property("text").toString(), QStringLiteral("Drop a .cone track or a PNG or JPG photo."));
    }
    // The checklist ticks each step; the track tiles unlock with all four and lock again when one comes undone.
    void theChecklistUnlocksTheTrackPieces()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        auto *checklist = window->findChild<QQuickItem *>(QStringLiteral("setupChecklist"));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QVERIFY(canvas && checklist && store);
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);
        auto count = [&]() { return qvariant_cast<QJSValue>(checklist->property("status")).property("count").toInt(); };
        auto tile = [&](const QString &kind) -> QQuickItem * {
            for (QQuickItem *item : allItems(window->contentItem()))
                if (QByteArray(item->metaObject()->className()).startsWith("PaletteTile")
                    && item->property("kind").toString() == kind)
                    return item;
            return nullptr;
        };
        QVERIFY(tile(QStringLiteral("straight")) && tile(QStringLiteral("ruler")));
        QCOMPARE(count(), 0);
        QVERIFY(!tile(QStringLiteral("straight"))->property("usable").toBool());

        QQuickItem *blueprint = findButton(window, QStringLiteral("Use the blueprint"));
        QVERIFY(blueprint);
        QTest::mouseClick(window, Qt::LeftButton, {},
                          blueprint->mapToScene(QPointF(blueprint->width() / 2, blueprint->height() / 2)).toPoint());
        QCOMPARE(count(), 1);

        QVariantMap ruler{ { "a", QVariantMap{ { "x", 100 }, { "y", 100 } } },
                           { "b", QVariantMap{ { "x", 300 }, { "y", 100 } } }, { "realLength", 20 } };
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("setRuler")), Q_ARG(QVariant, ruler));
        QMetaObject::invokeMethod(canvas, "beginPlacing", Q_ARG(QVariant, QStringLiteral("origin")));
        QMetaObject::invokeMethod(canvas, "finishPlacing", Q_ARG(QVariant, 300.0), Q_ARG(QVariant, 300.0));
        QCOMPARE(count(), 3);
        QVERIFY(!tile(QStringLiteral("straight"))->property("usable").toBool());
        QMetaObject::invokeMethod(canvas, "beginPlacing", Q_ARG(QVariant, QStringLiteral("direction")));
        QMetaObject::invokeMethod(canvas, "finishPlacing", Q_ARG(QVariant, 700.0), Q_ARG(QVariant, 300.0));
        QCOMPARE(count(), 4);
        QVERIFY(tile(QStringLiteral("straight"))->property("usable").toBool());
        QVERIFY(!tile(QStringLiteral("ruler"))->property("usable").toBool());       // one ruler per track
        QVERIFY(checklist->property("done").toBool());
        QVERIFY(!checklist->property("open").toBool());                               // folded to one line

        // A step that comes undone locks the track tiles again and unfolds the list.
        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QStringLiteral("direction")));
        QMetaObject::invokeMethod(store, "deleteSelected");
        QCOMPARE(count(), 3);
        QVERIFY(!tile(QStringLiteral("straight"))->property("usable").toBool());
        QVERIFY(checklist->property("open").toBool());
    }
    // Every element shows arrows; reversing a turn in the middle of a chain flags it with a warning (with a tip on
    // hover) and reversing it back clears it; typing a rotation turns the chain.
    void arrowsReverseAndTypedRotation()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        window->requestActivate();
        QVERIFY(QTest::qWaitForWindowActive(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QVERIFY(canvas && store);
        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);

        auto element = [&](const QString &id) {
            QVariant v;
            QMetaObject::invokeMethod(store, "element", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, id));
            return qvariant_cast<QJSValue>(v).toVariant().toMap();
        };
        auto view = [&](const QString &id) -> QQuickItem * {
            for (QQuickItem *item : allItems(canvas))
                if (QByteArray(item->metaObject()->className()).startsWith("ElementView")
                    && qvariant_cast<QJSValue>(item->property("element")).property("id").toString() == id)
                    return item;
            return nullptr;
        };
        auto backwardIds = [&]() {
            return qvariant_cast<QJSValue>(store->property("backwardIds")).toVariant().toStringList();
        };
        auto label = [&]() { return store->property("undoLabel").toString(); };

        for (const QString &id : { QStringLiteral("e1"), QStringLiteral("e2"), QStringLiteral("e3"), QStringLiteral("e4") })
            QVERIFY2(qvariant_cast<QJSValue>(view(id)->property("arrows")).property("length").toInt() >= 2, qPrintable(id));
        QVERIFY(backwardIds().isEmpty());

        // Reverse the turn in the middle: it now runs against the track.
        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QStringLiteral("e3")));
        QMetaObject::invokeMethod(store, "reverseSelected");
        QCOMPARE(label(), QStringLiteral("Reverse Turn"));
        QCOMPARE(element(QStringLiteral("e3")).value("props").toMap().value("direction").toString(), QStringLiteral("left"));
        QCOMPARE(element(QStringLiteral("e2")).value("joins").toMap().value("B").toMap().value("id").toString(), QStringLiteral("e3"));
        QCOMPARE(element(QStringLiteral("e4")).value("joins").toMap().value("A").toMap().value("id").toString(), QStringLiteral("e3"));
        QCOMPARE(backwardIds(), QStringList({ QStringLiteral("e3") }));
        QVERIFY(view(QStringLiteral("e3"))->property("backwards").toBool());

        // Hovering its warning shows the tip.
        const double mpp = store->property("mpp").toDouble();
        const QVariantMap middle = qvariant_cast<QJSValue>(view(QStringLiteral("e3"))->property("middle")).toVariant().toMap();
        QVariant at;
        QMetaObject::invokeMethod(canvas, "toScreen", Q_RETURN_ARG(QVariant, at),
                                  Q_ARG(QVariant, middle.value("x").toDouble() / mpp),
                                  Q_ARG(QVariant, middle.value("y").toDouble() / mpp));
        const QVariantMap s = qvariant_cast<QJSValue>(at).toVariant().toMap();
        QTest::mouseMove(window, canvas->mapToScene(QPointF(s.value("x").toDouble(), s.value("y").toDouble())).toPoint());
        QTRY_COMPARE(canvas->property("hoverWarning").toString(), QStringLiteral("e3"));
        auto *tip = window->findChild<QQuickItem *>(QStringLiteral("warningTip"));
        QVERIFY(tip && tip->isVisible());

        // Reversing it back clears the warning.
        QMetaObject::invokeMethod(store, "reverseSelected");
        QVERIFY(backwardIds().isEmpty());

        // Typed rotation: 90 degrees turns the whole chain; one undo puts it back; the arrows step 1 and Shift 15.
        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QStringLiteral("e1")));
        QQuickItem *rotation = findField(window, QStringLiteral("Rotation"));
        QVERIFY(rotation);
        QQuickItem *input = textBox(rotation);
        QCOMPARE(input->property("text").toString(), QStringLiteral("0\u00b0"));
        QTest::mouseClick(window, Qt::LeftButton, {}, input->mapToScene(QPointF(input->width() / 2, input->height() / 2)).toPoint());
        QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
        QTest::keyClick(window, '9');
        QTest::keyClick(window, '0');
        QCOMPARE(element(QStringLiteral("e1")).value("rotation").toDouble(), -90.0);   // canvas headings are clockwise
        QVERIFY(!element(QStringLiteral("e1")).value("joins").toMap().value("B").isNull());
        QTest::keyClick(window, Qt::Key_Return);
        QCOMPARE(label(), QStringLiteral("Rotate Straight"));
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(element(QStringLiteral("e1")).value("rotation").toDouble(), 0.0);
        QTest::mouseClick(window, Qt::LeftButton, {}, input->mapToScene(QPointF(input->width() / 2, input->height() / 2)).toPoint());
        QTest::keyClick(window, Qt::Key_Up);
        QCOMPARE(element(QStringLiteral("e1")).value("rotation").toDouble(), -1.0);
        QTest::keyClick(window, Qt::Key_Up, Qt::ShiftModifier);
        QCOMPARE(element(QStringLiteral("e1")).value("rotation").toDouble(), -16.0);
    }
    // Ctrl+click, a Shift+drag box, the shared settings, a group drag, duplicate and delete; Ctrl+click on a target
    // selects it alone.
    void selectingSeveralElements()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        window->requestActivate();
        QVERIFY(QTest::qWaitForWindowActive(window));
        auto *canvas = window->findChild<QQuickItem *>(QStringLiteral("canvasView"));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QVERIFY(canvas && store);
        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QTRY_VERIFY(canvas->property("fitPending").toBool() == false);

        auto element = [&](const QString &id) {
            QVariant v;
            QMetaObject::invokeMethod(store, "element", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, id));
            return qvariant_cast<QJSValue>(v).toVariant().toMap();
        };
        auto prop = [&](const QString &id, const QString &key) {
            return element(id).value(QStringLiteral("props")).toMap().value(key).toDouble();
        };
        auto joinedTo = [&](const QString &id, const QString &end) {
            return element(id).value(QStringLiteral("joins")).toMap().value(end).toMap().value(QStringLiteral("id")).toString();
        };
        auto selection = [&]() {
            return qvariant_cast<QJSValue>(store->property("selection")).toVariant().toStringList();
        };
        const double mpp = store->property("mpp").toDouble();
        auto screen = [&](double wx, double wy) {
            QVariant v;
            QMetaObject::invokeMethod(canvas, "toScreen", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, wx), Q_ARG(QVariant, wy));
            const QVariantMap p = qvariant_cast<QJSValue>(v).toVariant().toMap();
            return canvas->mapToScene(QPointF(p.value("x").toDouble(), p.value("y").toDouble())).toPoint();
        };
        auto middle = [&](const QString &id) {
            const QVariantMap e = element(id);
            return screen(e.value("x").toDouble() / mpp, e.value("y").toDouble() / mpp);
        };
        auto drag = [&](QPoint from, QPoint to, Qt::KeyboardModifiers modifiers = {}) {
            QTest::mousePress(window, Qt::LeftButton, modifiers, from);
            for (int i = 1; i <= 8; ++i)
                QTest::mouseMove(window, from + (to - from) * i / 8);
            QTest::mouseRelease(window, Qt::LeftButton, modifiers, to);
        };
        auto visibleText = [&](const QString &text) {
            for (QQuickItem *item : allItems(window->contentItem()))
                if (item->isVisible() && item->property("text").toString() == text)
                    return true;
            return false;
        };
        auto label = [&]() { return store->property("undoLabel").toString(); };

        // Ctrl+click adds the chicane to the straight; the panel shows what they share.
        QTest::mouseClick(window, Qt::LeftButton, {}, middle(QStringLiteral("e1")));
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, middle(QStringLiteral("e4")));
        QCOMPARE(selection(), QStringList({ QStringLiteral("e1"), QStringLiteral("e4") }));
        QVERIFY(visibleText(QStringLiteral("2 elements selected")));
        QQuickItem *width = findField(window, QStringLiteral("Track width"));
        QVERIFY(width);
        QVERIFY(!findField(window, QStringLiteral("Length")));
        QQuickItem *input = textBox(width);
        QTest::mouseClick(window, Qt::LeftButton, {}, input->mapToScene(QPointF(input->width() / 2, input->height() / 2)).toPoint());
        QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
        for (const char c : QByteArray("5 m"))
            QTest::keyClick(window, c);
        QTest::keyClick(window, Qt::Key_Return);
        QCOMPARE(prop(QStringLiteral("e1"), QStringLiteral("trackWidth")), 5.0);
        QCOMPARE(prop(QStringLiteral("e4"), QStringLiteral("trackWidth")), 5.0);
        QCOMPARE(label(), QStringLiteral("Change Track width (2 elements)"));
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(prop(QStringLiteral("e1"), QStringLiteral("trackWidth")), 4.0);

        // Different values show "mixed".
        QVariantMap wide{ { "id", "e1" }, { "key", "trackWidth" }, { "value", 6.0 } };
        QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("setProp")), Q_ARG(QVariant, wide));
        QTRY_VERIFY(findField(window, QStringLiteral("Track width"))->property("mixed").toBool());
        QCOMPARE(textBox(findField(window, QStringLiteral("Track width")))->property("text").toString(), QString());
        QMetaObject::invokeMethod(store, "undo");

        // Ctrl+click again takes it out.
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, middle(QStringLiteral("e4")));
        QCOMPARE(selection(), QStringList({ QStringLiteral("e1") }));

        // Ctrl+click on a target while elements are selected selects the target alone; Delete deletes only it.
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, middle(QStringLiteral("e4")));
        const QVariantMap origin = qvariant_cast<QJSValue>(store->property("track")).property("targets").property("origin").toVariant().toMap();
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, screen(origin.value("x").toDouble(), origin.value("y").toDouble()));
        QCOMPARE(selection(), QStringList({ QStringLiteral("origin") }));
        QTest::keyClick(window, Qt::Key_Delete);
        QCOMPARE(label(), QStringLiteral("Delete Origin"));
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QMetaObject::invokeMethod(store, "undo");

        // A Shift+drag box from empty canvas above the slalom's middle down across it selects it (and moves nothing).
        QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QString()));
        const QPoint m2 = middle(QStringLiteral("e2"));
        drag(m2 + QPoint(-10, -60), m2 + QPoint(10, 10), Qt::ShiftModifier);
        QCOMPARE(selection(), QStringList({ QStringLiteral("e2") }));
        QCOMPARE(joinedTo(QStringLiteral("e1"), QStringLiteral("B")), QStringLiteral("e2"));

        // A group drag moves both, keeps their join, and breaks the joins to the rest.
        QTest::mouseClick(window, Qt::LeftButton, {}, middle(QStringLiteral("e1")));
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, middle(QStringLiteral("e2")));
        QCOMPARE(selection(), QStringList({ QStringLiteral("e1"), QStringLiteral("e2") }));
        QCOMPARE(joinedTo(QStringLiteral("e1"), QStringLiteral("B")), QStringLiteral("e2"));
        const QPoint from = middle(QStringLiteral("e1"));
        drag(from, from + QPoint(0, 150));
        QCOMPARE(label(), QStringLiteral("Move 2 elements"));
        QCOMPARE(joinedTo(QStringLiteral("e1"), QStringLiteral("B")), QStringLiteral("e2"));
        QVERIFY(element(QStringLiteral("e2")).value("joins").toMap().value("B").isNull());
        QVERIFY(element(QStringLiteral("e3")).value("joins").toMap().value("A").isNull());
        QMetaObject::invokeMethod(store, "undo");
        QCOMPARE(joinedTo(QStringLiteral("e2"), QStringLiteral("B")), QStringLiteral("e3"));

        // A plain click on one of them, without dragging, selects only it.
        QTest::mouseClick(window, Qt::LeftButton, {}, middle(QStringLiteral("e1")));
        QCOMPARE(selection(), QStringList({ QStringLiteral("e1") }));

        // Ctrl+D copies both, keeping their join, and selects the copies; Delete removes them.
        QTest::mouseClick(window, Qt::LeftButton, Qt::ControlModifier, middle(QStringLiteral("e2")));
        QTest::keyClick(window, Qt::Key_D, Qt::ControlModifier);
        QCOMPARE(store->property("elementCount").toInt(), 6);
        QCOMPARE(selection(), QStringList({ QStringLiteral("e5"), QStringLiteral("e6") }));
        QCOMPARE(joinedTo(QStringLiteral("e5"), QStringLiteral("B")), QStringLiteral("e6"));
        QCOMPARE(label(), QStringLiteral("Duplicate 2 elements"));
        QTest::keyClick(window, Qt::Key_Delete);
        QCOMPARE(store->property("elementCount").toInt(), 4);
        QCOMPARE(label(), QStringLiteral("Delete 2 elements"));
    }
    // Typing into a "mixed" field: the first key makes the values the same, and the rest of the typing still lands.
    void typingIntoAMixedField()
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule("Conestructor", "Main");
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        window->requestActivate();
        QVERIFY(QTest::qWaitForWindowActive(window));
        QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
        QObject *settings = engine.singletonInstance<QObject *>("Conestructor", "Settings");
        QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        auto width = [&](const QString &id) {
            QVariant v;
            QMetaObject::invokeMethod(store, "element", Q_RETURN_ARG(QVariant, v), Q_ARG(QVariant, id));
            return qvariant_cast<QJSValue>(v).toVariant().toMap().value("props").toMap().value("trackWidth").toDouble();
        };
        for (const QString unit : { QStringLiteral("m"), QStringLiteral("ft"), QStringLiteral("ftin") }) {
            settings->setProperty("units", unit);
            QVariantMap wide{ { "id", "e1" }, { "key", "trackWidth" }, { "value", 6.0 } };
            QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("setProp")), Q_ARG(QVariant, wide));
            QMetaObject::invokeMethod(store, "seal");
            QVariantList ids{ QStringLiteral("e1"), QStringLiteral("e4") };
            QMetaObject::invokeMethod(store, "selectMany", Q_ARG(QVariant, QVariant(ids)), Q_ARG(QVariant, false));
            QQuickItem *field = findField(window, QStringLiteral("Track width"));
            QVERIFY(field);
            QTRY_VERIFY(field->property("mixed").toBool());
            QQuickItem *input = textBox(field);
            QTest::mouseClick(window, Qt::LeftButton, {}, input->mapToScene(QPointF(input->width() / 2, input->height() / 2)).toPoint());
            QTest::keyClick(window, '1');
            QTest::keyClick(window, '2');
            QVERIFY2(!field->property("bad").toBool(), qPrintable(unit + ": " + input->property("text").toString()));
            const double expected = unit == QStringLiteral("m") ? 12.0 : 12 * 0.3048;
            QVERIFY2(std::abs(width(QStringLiteral("e1")) - expected) < 1e-9, qPrintable(unit + ": " + QString::number(width(QStringLiteral("e1")))));
            QVERIFY(std::abs(width(QStringLiteral("e4")) - expected) < 1e-9);
            QTest::keyClick(window, Qt::Key_Escape);
            QTest::keyClick(window, Qt::Key_Return);
            QMetaObject::invokeMethod(store, "undo");
            QMetaObject::invokeMethod(store, "undo");
            QMetaObject::invokeMethod(store, "select", Q_ARG(QVariant, QString()));
        }
        settings->setProperty("units", QStringLiteral("ftin"));
    }

    // Closing the window while the Restore question is up keeps the backup for next time.
    void closingDuringTheRestoreQuestionKeepsTheBackup()
    {
        auto backup = [](QQmlApplicationEngine &engine) {
            QVariantMap found;
            QMetaObject::invokeMethod(engine.singletonInstance<QObject *>("Conestructor", "TrackFile"), "findBackup",
                                      Q_RETURN_ARG(QVariantMap, found));
            return found;
        };
        {
            QQmlApplicationEngine engine;
            engine.loadFromModule("Conestructor", "Main");
            QObject *window = engine.rootObjects().first();
            QObject *store = engine.singletonInstance<QObject *>("Conestructor", "TrackStore");
            QMetaObject::invokeMethod(window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
            QVariantMap move{ { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } };
            QMetaObject::invokeMethod(store, "run", Q_ARG(QVariant, QStringLiteral("place")), Q_ARG(QVariant, move));
            QMetaObject::invokeMethod(window, "backUp");
            QVERIFY(!backup(engine).isEmpty());
        }
        {
            QQmlApplicationEngine engine;
            engine.loadFromModule("Conestructor", "Main");
            auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
            QVERIFY(QTest::qWaitForWindowExposed(window));
            QObject *dialog = window->findChild<QObject *>(QStringLiteral("restoreDialog"));
            QMetaObject::invokeMethod(window, "start", Q_ARG(QVariant, QString()));
            QTRY_VERIFY(dialog->property("opened").toBool());
            window->close();
            QTRY_VERIFY(!window->isVisible());
            QVERIFY(!backup(engine).isEmpty());
            QMetaObject::invokeMethod(engine.singletonInstance<QObject *>("Conestructor", "TrackFile"), "deleteBackup");
        }
    }

    // A folded turn shows the warning with the fix in display units; a line draws no arrows, a dot per cone, and its
    // cones come last.
    void foldsAndLinesOnTheCanvas()
    {
        Loaded w;
        QVERIFY(w.load(true));
        w.run(QStringLiteral("setProp"), { { "id", "e3" }, { "key", "radius" }, { "value", 1.0 } });
        QCOMPARE(plain(w.store->property("foldedIds")).toStringList(), QStringList{ QStringLiteral("e3") });
        QVERIFY(w.view(QStringLiteral("e3"))->property("folded").toBool());
        QVariant text;
        QMetaObject::invokeMethod(w.canvas, "warningText", Q_RETURN_ARG(QVariant, text), Q_ARG(QVariant, QStringLiteral("e3")));
        // Half the 4 m width, in whatever units an earlier test left saved.
        QVERIFY2(text.toString().startsWith(QStringLiteral("Folds in on itself: make the radius at least "))
                     && text.toString().endsWith(QStringLiteral(", or the track narrower.")), qPrintable(text.toString()));

        w.run(QStringLiteral("add"), { { "type", "line" }, { "x", 120.0 }, { "y", 68.0 } });
        QQuickItem *line = w.view(QStringLiteral("e5"));
        QVERIFY(line);
        QCOMPARE(plain(line->property("chevrons")).toList().size(), 0);
        QCOMPARE(plain(line->property("dots")).toList().size(), 8);
        QVERIFY(plain(w.view(QStringLiteral("e1"))->property("chevrons")).toList().size() >= 2);

        QMetaObject::invokeMethod(w.store, "placeCones");
        const QVariantList cones = plain(w.store->property("preview")).toMap().value("canvasCones").toList();
        QCOMPARE(cones.last().toMap().value("element").toString(), QStringLiteral("e5"));
    }

    // Part 2's minor: arrows were one item per chevron, rebuilt on every edit. Dragging one element of a 40-element
    // course must keep up: the average time to handle a mouse move stays under a budget measured on the owner's machine.
    void draggingOnABigCourseKeepsUp()
    {
        Loaded w;
        QVERIFY(w.load(true));
        for (int i = 5; i <= 40; ++i) {
            QVariantMap add{ { "type", i % 2 ? QStringLiteral("turn") : QStringLiteral("straight") }, { "x", 0.0 }, { "y", 0.0 },
                             { "snap", QVariantMap{ { "ownEnd", "A" }, { "id", QStringLiteral("e%1").arg(i - 1) }, { "end", "B" } } } };
            if (i % 2)
                add.insert("props", QVariantMap{ { "angle", 20.0 } });
            w.run(QStringLiteral("add"), add);
        }
        QCOMPARE(w.store->property("elementCount").toInt(), 40);
        const QVariantMap e1 = w.element(QStringLiteral("e1"));
        const QPointF from = w.screen(e1.value("x").toDouble(), e1.value("y").toDouble());
        const QPoint a = w.scene(from);
        QElapsedTimer timer;
        QTest::mousePress(w.window, Qt::LeftButton, {}, a);
        timer.start();
        const int moves = 20;
        for (int i = 1; i <= moves; ++i)
            QTest::mouseMove(w.window, a + QPoint(0, 4 * i));
        const double perMove = double(timer.elapsed()) / moves;
        QTest::mouseRelease(w.window, Qt::LeftButton, {}, a + QPoint(0, 4 * moves));
        qInfo("ms per move on a 40-element course: %.1f", perMove);
        // Twice the slowest time measured on the owner's laptop (debug build): about 1000 ms in its quiet power mode,
        // 260 ms otherwise. It catches a gross slowdown, not a small one.
        const double budget = 2000;
        QVERIFY2(perMove < budget, qPrintable(QStringLiteral("%1 ms per move").arg(perMove)));
    }

    // A joined straight's open end only stretches; a free straight's end swings it about its other end; each drag is
    // one step; a joined end is not a node.
    void gateNodesPivotAndStretch()
    {
        Loaded w;
        QVERIFY(w.load(true));
        const double perPixel = w.mpp() / w.zoom();          // metres per screen pixel
        const QVariantMap e1 = w.element(QStringLiteral("e1"));
        const double length = e1.value("props").toMap().value("length").toDouble();
        const double x1 = e1.value("x").toDouble();
        const double y1 = e1.value("y").toDouble();

        // e1 (the demo's first straight, rotation 0) is joined at B, so its open A end only stretches.
        const QPointF a = w.screen(x1 - length / 2, y1);
        QTest::mouseMove(w.window, w.scene(a));
        QTRY_COMPARE(w.view(QStringLiteral("e1"))->property("hoverEnd").toString(), QStringLiteral("A"));
        w.drag(a, a + QPointF(-40, 15));
        QCOMPARE(w.label(), QStringLiteral("Stretch Straight"));
        const QVariantMap stretched = w.element(QStringLiteral("e1"));
        QCOMPARE(stretched.value("rotation").toDouble(), 0.0);
        QVERIFY2(std::abs(stretched.value("props").toMap().value("length").toDouble() - (length + 40 * perPixel)) < 1.5 * perPixel,
                 qPrintable(QString::number(stretched.value("props").toMap().value("length").toDouble())));
        QVERIFY(!stretched.value("joins").toMap().value("B").isNull());
        QMetaObject::invokeMethod(w.store, "undo");
        QCOMPARE(w.element(QStringLiteral("e1")).value("props").toMap().value("length").toDouble(), length);

        // A free straight pivots about its other end.
        w.run(QStringLiteral("add"), { { "type", "straight" }, { "x", x1 }, { "y", y1 + 20 } });
        const QPointF freeA = w.screen(x1 - 10, y1 + 20);
        const QPointF freeB = w.screen(x1 + 10, y1 + 20);
        w.drag(freeB, freeA + QPointF(0, 60));
        QCOMPARE(w.label(), QStringLiteral("Stretch Straight"));
        const QVariantMap swung = w.element(QStringLiteral("e5"));
        QVERIFY2(std::abs(swung.value("rotation").toDouble() - 90) < 2, qPrintable(QString::number(swung.value("rotation").toDouble())));
        QVERIFY(std::abs(swung.value("props").toMap().value("length").toDouble() - 60 * perPixel) < 1.5 * perPixel);
        // Its A end has not moved.
        const double r = swung.value("rotation").toDouble() * M_PI / 180;
        const double half = swung.value("props").toMap().value("length").toDouble() / 2;
        QVERIFY(std::abs(swung.value("x").toDouble() - half * std::cos(r) - (x1 - 10)) < 1e-6);
        QVERIFY(std::abs(swung.value("y").toDouble() - half * std::sin(r) - (y1 + 20)) < 1e-6);

        // The joint between e1 and e2 is not a node: pressing there grabs the element, not a stretch.
        const QPointF joint = w.screen(x1 + length / 2, y1);
        w.drag(joint, joint + QPointF(0, 40));
        QVERIFY2(!w.label().startsWith(QStringLiteral("Stretch")), qPrintable(w.label()));
    }

    // Every tile places by clicking it, then the canvas; the ruler takes two clicks and then asks for its length on
    // the spot. Review focus 1, 2 and 5: undo with the box open, typing in feet and inches or nonsense, switching tiles.
    void tilesPlaceByClicking()
    {
        Loaded w;
        QVERIFY(w.load(false));
        QMetaObject::invokeMethod(w.window, "useBlueprint");
        auto placing = [&]() { return w.canvas->property("placingBy").toString(); };
        auto kind = [&]() { return w.canvas->property("placingKind").toString(); };
        auto ruler = [&]() { return w.track().value("ruler").toMap(); };

        // The ruler: two clicks, a rubber band between them.
        w.clickItem(w.tile(QStringLiteral("ruler")));
        QCOMPARE(placing(), QStringLiteral("click"));
        QCOMPARE(kind(), QStringLiteral("ruler"));
        QTest::mouseMove(w.window, w.scene({ 300, 400 }));
        QVERIFY(!isNull(w.canvas->property("placingPoint")));
        w.click({ 300, 400 });
        QVERIFY(ruler().isEmpty());
        QVERIFY(!isNull(w.canvas->property("rulerFirst")));
        QTest::mouseMove(w.window, w.scene({ 500, 400 }));
        QVERIFY(!isNull(w.canvas->property("rulerGhost")));
        w.click({ 500, 400 });
        QCOMPARE(placing(), QString());
        const QPointF a = w.world({ 300, 400 });
        QVERIFY(std::abs(ruler().value("a").toMap().value("x").toDouble() - a.x()) < 1.0 / w.zoom() + 1e-9);
        QCOMPARE(ruler().value("realLength").toDouble(), 0.0);

        // The length box is open and focused: nonsense turns red and stays; 18' 6" sets 5.6388 m and closes it.
        QQuickItem *box = w.named(QStringLiteral("rulerLengthBox"));
        QVERIFY(box);
        QTRY_VERIFY(box->isVisible());
        typeText(w.window, QStringLiteral("abc"));
        QTest::keyClick(w.window, Qt::Key_Return);
        QVERIFY(box->isVisible());
        QVERIFY(box->property("bad").toBool());
        QCOMPARE(ruler().value("realLength").toDouble(), 0.0);
        QTest::keyClick(w.window, Qt::Key_A, Qt::ControlModifier);
        typeText(w.window, QStringLiteral("18' 6\""));
        QTest::keyClick(w.window, Qt::Key_Return);
        QTRY_VERIFY(!box->isVisible());
        QVERIFY(std::abs(ruler().value("realLength").toDouble() - 5.6388) < 1e-9);
        QCOMPARE(w.label(), QStringLiteral("Set ruler"));

        // Undo with the box open: undo the length, then undo the ruler itself while the box shows: it closes for good.
        QMetaObject::invokeMethod(w.store, "undo");          // length off: the box does not reopen by itself
        QVERIFY(!box->isVisible());
        QMetaObject::invokeMethod(w.canvas, "openLengthBox");
        QTRY_VERIFY(box->isVisible());
        QMetaObject::invokeMethod(w.store, "undo");          // the ruler goes
        QTRY_VERIFY(!box->isVisible());
        QVERIFY(!w.canvas->property("lengthBoxOpen").toBool());
        QMetaObject::invokeMethod(w.store, "redo");
        QVERIFY(!box->isVisible());
        QMetaObject::invokeMethod(w.store, "redo");          // the length back

        // Switching tiles: only one is picked up; the same tile again, Esc or a right-click drops it.
        w.clickItem(w.tile(QStringLiteral("origin")));
        QCOMPARE(kind(), QStringLiteral("origin"));
        QVERIFY(w.store->property("message").toString().contains(QStringLiteral("Esc to cancel")));
        w.clickItem(w.tile(QStringLiteral("direction")));
        QCOMPARE(kind(), QStringLiteral("direction"));
        w.clickItem(w.tile(QStringLiteral("direction")));
        QCOMPARE(placing(), QString());
        w.clickItem(w.tile(QStringLiteral("origin")));
        QTest::keyClick(w.window, Qt::Key_Escape);
        QCOMPARE(placing(), QString());
        w.clickItem(w.tile(QStringLiteral("origin")));
        w.click({ 400, 500 }, Qt::RightButton);
        QCOMPARE(placing(), QString());
        QVERIFY(w.track().value("targets").toMap().value("origin").isNull());

        // Origin and Direction by clicking.
        w.clickItem(w.tile(QStringLiteral("origin")));
        w.click({ 400, 500 });
        QCOMPARE(w.label(), QStringLiteral("Place Origin"));
        w.clickItem(w.tile(QStringLiteral("direction")));
        w.click({ 900, 500 });
        QCOMPARE(w.label(), QStringLiteral("Place Direction"));

        // A track piece by clicking, now setup is done: the ghost follows, a click adds it.
        w.clickItem(w.tile(QStringLiteral("straight")));
        QTest::mouseMove(w.window, w.scene({ 600, 650 }));
        QVERIFY(!isNull(w.canvas->property("ghost")));
        w.click({ 600, 650 });
        QCOMPARE(w.store->property("elementCount").toInt(), 1);
        QCOMPARE(w.label(), QStringLiteral("Add Straight"));
        QCOMPARE(placing(), QString());
    }

    // Dragging the ruler or a target from its tile shows where it will land, as track pieces already did.
    void draggingATileShowsAGhost()
    {
        Loaded w;
        QVERIFY(w.load(false));
        QMetaObject::invokeMethod(w.window, "useBlueprint");
        QQuickItem *origin = w.tile(QStringLiteral("origin"));
        const QPoint start = origin->mapToScene(QPointF(origin->width() / 2, origin->height() / 2)).toPoint();
        const QPoint end = w.scene({ 400, 500 });
        QTest::mousePress(w.window, Qt::LeftButton, {}, start);
        for (int i = 1; i <= 8; ++i)
            QTest::mouseMove(w.window, start + (end - start) * i / 8);
        QCOMPARE(w.canvas->property("placingBy").toString(), QStringLiteral("drag"));
        QVERIFY(!isNull(w.canvas->property("placingPoint")));
        QTest::mouseRelease(w.window, Qt::LeftButton, {}, end);
        QCOMPARE(w.label(), QStringLiteral("Place Origin"));
        QVERIFY(isNull(w.canvas->property("placingPoint")));
    }

    // A new track shows the coach card for the step to do now; its buttons start each step; the matching checklist row
    // is highlighted; the card goes when setup is done and comes back when a step comes undone. The banner sits below
    // the card.
    void theCoachCardWalksThroughSetup()
    {
        Loaded w;
        QVERIFY(w.load(false));
        QQuickItem *card = w.named(QStringLiteral("coachCard"));
        QVERIFY(card && card->isVisible());
        auto step = [&]() { return card->property("step").toString(); };
        auto row = [&](int n) { return w.named(QStringLiteral("setupStep%1").arg(n)); };
        auto press = [&](const QString &text) {
            QQuickItem *button = findButton(w.window, text);
            QVERIFY2(button, qPrintable(text));
            w.clickItem(button);
        };
        QCOMPARE(step(), QStringLiteral("photo"));
        QVERIFY(row(1)->property("current").toBool());
        QCOMPARE(w.named(QStringLiteral("setupTitle"))->property("text").toString(), QStringLiteral("Setup: start here"));

        QMetaObject::invokeMethod(w.store, "report", Q_ARG(QVariant, QStringLiteral("A note")), Q_ARG(QVariant, QVariant()));
        QQuickItem *banner = findBanner(w.window);
        QVERIFY(banner->y() >= card->y() + card->height());

        press(QStringLiteral("Use the blueprint"));
        QCOMPARE(step(), QStringLiteral("ruler"));
        QVERIFY(row(2)->property("current").toBool());
        QVERIFY(row(3)->opacity() < 1);

        press(QStringLiteral("Place the ruler"));
        QCOMPARE(w.canvas->property("placingKind").toString(), QStringLiteral("ruler"));
        w.click({ 300, 500 });
        w.click({ 500, 500 });
        QCOMPARE(step(), QStringLiteral("rulerLength"));
        QTRY_VERIFY(w.named(QStringLiteral("rulerLengthBox"))->isVisible());
        typeText(w.window, QStringLiteral("20"));             // a bare number is feet in feet and inches
        QTest::keyClick(w.window, Qt::Key_Return);
        QCOMPARE(step(), QStringLiteral("origin"));

        press(QStringLiteral("Place Origin"));
        w.click({ 400, 600 });
        QCOMPARE(step(), QStringLiteral("direction"));
        press(QStringLiteral("Place Direction"));
        w.click({ 900, 600 });
        QCOMPARE(step(), QString());
        QVERIFY(!card->isVisible());
        QCOMPARE(w.named(QStringLiteral("setupTitle"))->property("text").toString(),
                 QStringLiteral("Setup \u2713 (photo, ruler, targets)"));

        QMetaObject::invokeMethod(w.store, "undo");                  // Direction goes again
        QVERIFY(card->isVisible());
        QCOMPARE(step(), QStringLiteral("direction"));
    }

    // Minor 2: after Don't save and a refused Open, the still-unsaved track is backed up again.
    void aDiscardedTrackIsBackedUpAgain()
    {
        Loaded w;
        QVERIFY(w.load(true));
        QObject *files = w.engine.singletonInstance<QObject *>("Conestructor", "TrackFile");
        auto backup = [&]() {
            QVariantMap found;
            QMetaObject::invokeMethod(files, "findBackup", Q_RETURN_ARG(QVariantMap, found));
            return found;
        };
        w.run(QStringLiteral("place"), { { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } });
        QMetaObject::invokeMethod(w.window, "backUp");
        QVERIFY(!backup().isEmpty());
        QMetaObject::invokeMethod(w.window, "openRecent", Q_ARG(QVariant, dir.filePath(QStringLiteral("Gone.cone"))));
        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("unsavedDialog"));
        QTRY_VERIFY(dialog->property("opened").toBool());
        w.clickItem(findButton(w.window, QStringLiteral("Don't save")));
        QTRY_VERIFY(backup().isEmpty());
        QVERIFY(w.store->property("dirty").toBool());         // the open was refused: the track is still unsaved
        QMetaObject::invokeMethod(w.window, "backUp");
        QVERIFY(!backup().isEmpty());
        QMetaObject::invokeMethod(files, "deleteBackup");
    }

    // Minor 3: a relative path on the command line is opened and kept as an absolute one.
    void aRelativePathAtStartBecomesAbsolute()
    {
        const QString path = dir.filePath(QStringLiteral("Relative.cone"));
        {
            Loaded w;
            QVERIFY(w.load(true));
            QVariant ok;
            QMetaObject::invokeMethod(w.store, "saveTo", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, path));
            QVERIFY(ok.toBool());
        }
        Loaded w;
        QVERIFY(w.load(false));
        // No backup from an earlier test, so start() goes straight to the file.
        QMetaObject::invokeMethod(w.engine.singletonInstance<QObject *>("Conestructor", "TrackFile"), "deleteBackup");
        const QString old = QDir::currentPath();
        QDir::setCurrent(dir.path());
        QMetaObject::invokeMethod(w.window, "start", Q_ARG(QVariant, QStringLiteral("Relative.cone")));
        QDir::setCurrent(old);
        QCOMPARE(w.store->property("elementCount").toInt(), 4);
        QCOMPARE(w.store->property("filePath").toString(), QDir::toNativeSeparators(path));
    }

    // Minor 5: a long track name wraps in the unsaved-changes question.
    void aLongNameWrapsInTheQuestion()
    {
        Loaded w;
        QVERIFY(w.load(true));
        w.store->setProperty("filePath", dir.filePath(QString(120, QChar('x')) + QStringLiteral(".cone")));
        w.run(QStringLiteral("place"), { { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } });
        QMetaObject::invokeMethod(w.window, "newTrack");
        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("unsavedDialog"));
        QTRY_VERIFY(dialog->property("opened").toBool());
        QQuickItem *question = w.named(QStringLiteral("unsavedQuestion"));
        QVERIFY(question);
        QVERIFY(question->property("lineCount").toInt() > 1);
        QVERIFY(question->width() <= dialog->property("availableWidth").toDouble());
        w.clickItem(findButton(w.window, QStringLiteral("Cancel")));
    }

    // Minor 6: Save As starts in the open track's folder with its name; an Untitled track has no start of its own.
    void saveAsStartsBesideTheTrack()
    {
        Loaded w;
        QVERIFY(w.load(true));
        QVariant start;
        QMetaObject::invokeMethod(w.window, "saveAsStart", Q_RETURN_ARG(QVariant, start));
        QVERIFY(isNull(start));
        const QString path = dir.filePath(QStringLiteral("Duck pond.cone"));
        w.store->setProperty("filePath", path);
        QMetaObject::invokeMethod(w.window, "saveAsStart", Q_RETURN_ARG(QVariant, start));
        const QVariantMap s = plain(start).toMap();
        QCOMPARE(s.value("folder").toUrl(), QUrl::fromLocalFile(dir.path()));
        QCOMPARE(s.value("file").toUrl(), QUrl::fromLocalFile(path));
    }

    // Minor 7: a backup that cannot be read says so once and is removed, so it is not offered again.
    void anUnreadableBackupIsRemoved()
    {
        QString backupPath;
        {
            Loaded w;
            QVERIFY(w.load(true));
            w.run(QStringLiteral("place"), { { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } });
            QMetaObject::invokeMethod(w.window, "backUp");
            QObject *files = w.engine.singletonInstance<QObject *>("Conestructor", "TrackFile");
            QVariantMap found;
            QMetaObject::invokeMethod(files, "findBackup", Q_RETURN_ARG(QVariantMap, found));
            backupPath = found.value("path").toString();
            QVERIFY(!backupPath.isEmpty());
        }
        QFile broken(backupPath);
        QVERIFY(broken.open(QIODevice::WriteOnly | QIODevice::Truncate));
        broken.write("not a track");
        broken.close();

        Loaded w;
        QVERIFY(w.load(false));
        QMetaObject::invokeMethod(w.window, "start", Q_ARG(QVariant, QString()));
        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("restoreDialog"));
        QTRY_VERIFY(dialog->property("opened").toBool());
        w.clickItem(findButton(w.window, QStringLiteral("Restore")));
        QTRY_COMPARE(findBanner(w.window)->property("text").toString(),
                     QStringLiteral("The backup couldn't be read and has been removed."));
        QObject *files = w.engine.singletonInstance<QObject *>("Conestructor", "TrackFile");
        QVariantMap found;
        QMetaObject::invokeMethod(files, "findBackup", Q_RETURN_ARG(QVariantMap, found));
        QVERIFY(found.isEmpty());
        QCOMPARE(w.store->property("elementCount").toInt(), 0);
    }

    // Final review: a picked-up tile is dropped when the track is replaced or setup comes undone.
    void placingStopsWhenTheTrackChanges()
    {
        Loaded w;
        QVERIFY(w.load(false));
        QMetaObject::invokeMethod(w.window, "useBlueprint");
        w.clickItem(w.tile(QStringLiteral("ruler")));
        w.click({ 300, 400 });                                       // the ruler's first end
        QVERIFY(!isNull(w.canvas->property("rulerFirst")));
        QMetaObject::invokeMethod(w.store, "newTrack");
        QCOMPARE(w.canvas->property("placingBy").toString(), QString());
        QVERIFY(isNull(w.canvas->property("rulerFirst")));

        QMetaObject::invokeMethod(w.window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        w.clickItem(w.tile(QStringLiteral("straight")));
        QCOMPARE(w.canvas->property("placingKind").toString(), QStringLiteral("straight"));
        w.run(QStringLiteral("setTarget"), { { "which", "direction" }, { "point", QVariant() } });   // setup undone
        QCOMPARE(w.canvas->property("placingBy").toString(), QString());
    }

    // Final review: an element both backwards and folded lists both, one plain line each.
    void aWarningCanSayTwoThings()
    {
        Loaded w;
        QVERIFY(w.load(true));
        QMetaObject::invokeMethod(w.store, "select", Q_ARG(QVariant, QStringLiteral("e3")));
        QMetaObject::invokeMethod(w.store, "reverseSelected");
        w.run(QStringLiteral("setProp"), { { "id", "e3" }, { "key", "radius" }, { "value", 1.0 } });
        QVariant text;
        QMetaObject::invokeMethod(w.canvas, "warningText", Q_RETURN_ARG(QVariant, text), Q_ARG(QVariant, QStringLiteral("e3")));
        QVERIFY2(!text.toString().contains(QChar('\r')), qPrintable(text.toString()));
        const QStringList lines = text.toString().split(QChar('\n'));
        QCOMPARE(lines.size(), 2);
        QVERIFY(lines[0].startsWith(QStringLiteral("Runs against the track")));
        QVERIFY(lines[1].startsWith(QStringLiteral("Folds in on itself")));
    }

    // Final review: right-click and Ctrl+click near an open end still act on the element, as before gate nodes.
    void openEndsStillTakeRightAndCtrlClicks()
    {
        Loaded w;
        QVERIFY(w.load(true));
        const QVariantMap e1 = w.element(QStringLiteral("e1"));
        const double length = e1.value("props").toMap().value("length").toDouble();
        const double x1 = e1.value("x").toDouble();
        const double y1 = e1.value("y").toDouble();
        w.click(w.screen(x1 - length / 2, y1), Qt::RightButton);    // e1's open A end
        QObject *menu = w.window->findChild<QObject *>(QStringLiteral("elementMenu"));
        QVERIFY(menu);
        QTRY_VERIFY(menu->property("opened").toBool());
        QCOMPARE(w.store->property("selectedId").toString(), QStringLiteral("e1"));
        QTest::keyClick(w.window, Qt::Key_Escape);
        QTRY_VERIFY(!menu->property("opened").toBool());

        w.run(QStringLiteral("add"), { { "type", "straight" }, { "x", x1 }, { "y", y1 + 20 } });   // e5, free
        QTest::mouseClick(w.window, Qt::LeftButton, Qt::ControlModifier, w.scene(w.screen(x1 - 10, y1 + 20)));
        QCOMPARE(plain(w.store->property("selection")).toStringList(), QStringList({ QStringLiteral("e1"), QStringLiteral("e5") }));
    }
};

QTEST_MAIN(TestQmlLoad)
#include "tst_qmlload.moc"
