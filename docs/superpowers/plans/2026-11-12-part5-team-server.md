# Conestructor v1 part 5 (team server) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a team share tracks through the owner's server: `server/` in the repo (Flask blueprints for the owner's API service, multi-team tables, team keys, a LAN-only admin API and a command-line admin script), and in the app Preferences › Team (the team code), File › Open from team and File › Upload to team, plus part 4's minors 1 to 5.

**Architecture:** The server side is three Python modules dropped into Caduceus's `util/` beside the other apps' blueprints, in the shape of Gluttony's `server/`: `coneRules.py` (pure checks and team codes), `coneRoutes.py` (the team API at `/api/cone`, the only prefix nginx passes) and `coneAdminRoutes.py` (the admin API at `/api/cone-admin`, LAN only), tested with pytest against a fake MySQL connection, then a smoke test on a scratch database and a live check after cut-over. The app gains one C++ singleton, `TeamServer` (Qt Network), which reads the team code, finds the server (LAN first, then public), lists, uploads and downloads, and draws the upload's thumbnail with QPainter; `TrackFile` learns to build a file's bytes and open bytes; QML gains `TeamTracksDialog.qml`, `UploadDialog.qml` and a Team section in Preferences. The track model and the `.cone` format do not change.

**Tech Stack:** Qt 6.11.1 (MSVC 2022 64-bit): Quick, Controls (Fusion), Dialogs, Network; CMake + Ninja; Qt Test (C++), qmltestrunner (QML/JS); Python 3.12 with Flask 3.1 and pytest (server, in `server/.venv`); MySQL 8 through the server's own `DBUtils`; nginx; PowerShell scripts in `app/tests`.

**Spec:** `docs/superpowers/specs/2026-11-11-part5-team-server-design.md` (the roadmap is in `2026-11-10-v1-roadmap-and-part1-core-canvas-design.md`; part 2's spec and plan explain `.cone` files, `TrackFile` and the autosave backup; part 4's explain touch-ups and the lock). Gluttony's `server/` (the owner's Gluttony checkout beside this repo, `..\Gluttony\server`) is the pattern the server side copies: read its `tests/conftest.py`, `tests/fakes.py`, `gluttonySmoke.py` and `README.md` before Task 1.

## Global Constraints

- The repo is public. Never write the LAN address, the public domain or subdomain, or the server's hostname into code, docs, tests or commit messages; examples use `<LAN address>` and `<public host>`, and tests use `lan.example` and `public.example`. Never copy anything from the server's `DBUtils.py` (it holds the database password). No real team key, admin token or team code in the repo.
- `server/coneAdminConfig.json` and `server/coneAdmin.local.json` are gitignored; only `server/coneAdminConfig.example.json` is committed.
- The two satellite images (`app/assets/images/duckPondBirdeye.png`, `riverwindBirdeye.png`) stay gitignored and are bundled only when present at build time. A clean clone must build without them.
- The `.cone` format stays version 1 and does not change in this part.
- The team code is `CONE1.` + base64url (no padding) of `{"v": 1, "team", "lan"?, "public"?, "key"}`; `lan` or `public` may be missing but not both.
- Team API (`/api/cone/`): `GET /ping` (no key), `GET /team`, `GET /tracks`, `GET /tracks/<id>/thumbnail`, `GET /tracks/<id>/file`, `POST /tracks` (multipart `file` + `thumbnail`); every request but ping needs `X-Team-Key`; another team's track answers 404.
- Admin API (`/api/cone-admin/`, LAN only, `X-Admin-Token`): `POST /teams`, `POST /teams/<id>/key`, `GET /teams`, `GET /tracks[?team=]`, `DELETE /tracks/<id>`.
- Only the SHA-256 of a key is stored. File paths come from ids only: `<TEAMS_ROOT>/<teamId>/<trackId>.cone` and `.jpg`, `TEAMS_ROOT` = `/pool/appFiles/conestructor/teams`.
- A `.cone` upload is at most 40 MB; a thumbnail is a JPEG of at most 200 KB, about 400 px on its long side.
- Error sentences in the app (exact): "Can't reach the team server (tried the LAN and the internet)." / "...(tried the internet)." / "...(tried the LAN)."; "The team code was not accepted. Check it in Preferences › Team."; "Too large to upload (over 40 MB)."; "The server refused the track: <its message>."; "The server had a problem. Try again later.". Preferences › Team: "Not a team code", "Connected to <team> (on the LAN)" / "(over the internet)", "Can't reach the team server", "The server doesn't know this code", "Treat the team code like a password: it opens your team's tracks.". Without a code: "Paste your team code to use team tracks.". Empty list: "No tracks on the team yet. File › Upload to team shares the open track.".
- Version 0.6.0 from CMake; window title `Conestructor 0.6 — <name>`; a team track's title is `Conestructor 0.6 — <name> (from team)`.
- Logic lives in pure JavaScript modules in `app/qml/logic/` (qmltestrunner); QML only draws and forwards input; C++ services are QML singletons (`QML_ELEMENT`/`QML_SINGLETON`).
- `tst_qmlload` keeps `QTest::failOnWarning` in `init()`: any QML warning fails a test. A window test that sets `Settings.teamCode` sets it back to `""` before it ends (the ini under the test's temporary folder is shared by every test in the run).
- Qt Quick gotchas from parts 1 to 4: don't name an id or property after an Item property used inside delegates (`palette`, `layer`, `state`, `data`, `children`); `FileDialog` and `Dialog` have a final `result` property; Repeater and ListView delegates have no QObject parent (tests walk `childItems()`); a Fusion `Dialog` with a custom footer needs a fixed `implicitWidth`; an item with `anchors` inside a Layout warns; `QTest::keyClicks` has no QWindow overload (use `typeText`).
- The laptop's "Silent" power plan swings timings about 4×: any timing check needs a generous budget.
- Build: `powershell -NoProfile -File app\tests\build.ps1`; test: `powershell -NoProfile -File app\tests\run.ps1` (one C++ test: `run.ps1 -NoQml -R tst_teamserver`; one QML file: `run.ps1 -NoCpp -Qml tst_conefile.qml`). Server tests: `server\.venv\Scripts\python.exe -m pytest -q` from `server\`. Qt 6.11.1 MSVC at `D:\allNewQT6\6.11.1\msvc2022_64`, CMake/Ninja under `D:\allNewQT6\Tools`. A clean clone builds in a short path (`%TEMP%\cc-p5`): MSVC fails on long scratchpad paths (C1083).
- Work on branch `part5-team-server`; merge to `main` and push only after the owner's check and a look at what is being pushed.
- Every commit message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (passed as a second `-m`).
- Server steps on the real machine (Task 12) wait for the owner's go-ahead each time; the owner runs every `sudo` step.

## Decisions this plan adds to the spec

- **Request limit 41 MB.** The `.cone` itself is limited to 40 MB (`MAX_FILE`); the whole upload request, which also carries the thumbnail and the form's own lines, to 41 MB (`MAX_REQUEST`). nginx's `client_max_body_size` is `41m` (the spec said 40m).
- **Every success answer also carries `"status": "ok"`**, as Gluttony's routes do; the fields the spec lists are unchanged.
- **The list's entries carry `uploadedText`** besides `uploaded`: the time in local time, `"12 Nov 2026 14:02"`, made by `TeamServer` (Qt's format, English month names).
- **More sentences:** a code with only a LAN address that does not answer says "Can't reach the team server (tried the LAN)."; a download or thumbnail of a track that is gone (404) says "That track is no longer on the team.".
- **The LAN counts only when `/ping` answers 200 with `{"status": "ok"}`**: another machine at that address on some other network does not.
- **Where errors show:** an upload's error shows in the Upload dialog, which stays open to try again; a list or download error shows in the Team tracks dialog's status line; a downloaded file that does not open closes the dialog and shows the usual banner (as a damaged file from disk does).
- **Thumbnails** are files in a temporary folder `TeamServer` keeps for the session: `upload-<n>.jpg` for each one drawn, `thumb-<id>.jpg` for each one fetched. The route line runs through every cone in order, as the preview's does; cones are dots of radius 3 px (standing `#ff8c1a`, leaning `#ffd400`); the route is white at 80% opacity, 1.5 px.
- **`TeamServer.code` follows `Settings.teamCode`** through a `Binding` in `Main.qml`; changing it forgets which address answered and the session's thumbnails.
- **One fixed team code pins the format on both sides:** pytest checks `coneRules.teamCode` makes it, Qt Test checks `TeamServer::parseCode` reads it.
- **`liveCheck.py` reads the team code from `CONE_CHECK_CODE`** and checks every address the code carries; it imports `coneRules` for `readTeamCode`.

## Review Focus

1. **A team code pasted with spaces or a line break around it** (copied from a chat app): accepted and saved without them. Pinned in Task 7 (`codesAreRead`, the padded row) and Task 8 (`theTeamSection`).
2. **The LAN address answering, but not as Conestructor's server** (another network that uses the same address range): not taken for the LAN; the public address is used. Pinned in Task 7 (`theLanMustAnswerLikeTheServer`).
3. **A track name with quotes, a slash, accents or an emoji:** stored as it is by the server, listed back as it is by the app. Pinned in Task 2 (`test_anyNameIsStoredAsItIs`) and Task 7 (`theListIsRead`).
4. **The Team tracks dialog closed (Esc) during a download:** the download stops, nothing opens later, and the dialog lists again when reopened. Pinned in Task 9 (`aDownloadStopsWhenTheDialogCloses`).
5. **Upload pressed twice, or Enter in the name field while it sends:** one upload only. Pinned in Task 7 (`oneTransferAtATime`) and Task 9 (`uploadingToTheTeam`).

## File structure

```
coneRoutes.py                          moved to server/coneRoutes.py (Task 1) and rewritten (Task 2)
.gitignore                             server's own secrets and venv; the old app/config/secrets.json line goes
server/coneRules.py                    NEW: upload checks, keys and hashes, team codes, file paths
server/coneRoutes.py                   the team API, /api/cone
server/coneAdminRoutes.py              NEW: the admin API, /api/cone-admin (LAN only)
server/coneAdmin.py                    NEW: the owner's admin commands (standard library)
server/coneSmoke.py                    NEW: smoke test on a scratch database
server/liveCheck.py                    NEW: the live check after cut-over (standard library + coneRules)
server/schema.sql                      NEW: teams and tracks (replaces the prototype's table)
server/coneAdminConfig.example.json    NEW
server/requirements-dev.txt, pytest.ini, README.md   NEW
server/tests/conftest.py, fakes.py, samples.py      NEW (fakes.py copied from Gluttony's)
server/tests/test_rules.py, test_schema.py, test_team.py, test_admin.py, test_coneadmin.py,
             test_smoke.py, test_livecheck.py        NEW
app/CMakeLists.txt                     version 0.6.0; Qt Network; TeamServer; the two dialogs
app/services/Settings.h/.cpp           teamCode; minor 4 (finite numbers, clamp before converting)
app/services/TrackFile.h/.cpp          documentBytes(), openBytes()
app/services/TeamServer.h/.cpp         NEW: team code, finding the server, requests, thumbnail
app/qml/TrackStore.qml                 teamName, fromTeam, readOpened(), openFromTeam(), uploadResult()
app/qml/PreferencesDialog.qml          the Team section; openAtTeam()
app/qml/TeamTracksDialog.qml           NEW: File › Open from team
app/qml/UploadDialog.qml               NEW: File › Upload to team
app/qml/Main.qml                       File menu items, the Binding, the dialogs, title; minor 2
app/qml/CanvasView.qml                 minor 1
app/qml/logic/conefile.mjs             minor 3
app/tests/CMakeLists.txt               tst_teamserver; fakehttp.h
app/tests/fakehttp.h                   NEW: a small HTTP server for the C++ tests
app/tests/tst_teamserver.cpp           NEW
app/tests/tst_settings.cpp, tst_trackfile.cpp, tst_qmlload.cpp
app/tests/qml/tst_conefile.qml, tst_elements.qml      minors 3 and 5
README.md                              team tracks; server/ in the layout; part 5 status
```

---

### Task 1: Server rules, schema and test scaffolding

**Files:**
- Move: `coneRoutes.py` → `server/coneRoutes.py` (unchanged here; Task 2 rewrites it)
- Create: `server/coneRules.py`, `server/schema.sql`, `server/requirements-dev.txt`, `server/pytest.ini`, `server/coneAdminConfig.example.json`
- Create: `server/tests/conftest.py`, `server/tests/fakes.py`, `server/tests/samples.py`, `server/tests/test_rules.py`, `server/tests/test_schema.py`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces (`coneRules`): `TEAMS_ROOT` (a `Path`), `MAX_FILE` (40 MB), `MAX_THUMBNAIL` (200 KB), `MAX_REQUEST` (41 MB), `MAX_TRACK_NAME` (200), `MAX_TEAM_NAME` (100), `CODE_PREFIX` (`"CONE1."`), `class Refused(Exception)`, `readTrack(data: bytes) -> {"name": str, "cones": int}`, `checkThumbnail(data: bytes) -> None`, `teamName(value) -> str`, `newKey() -> str` (43 characters), `keyHash(key: str) -> str` (64 hex), `teamCode(team, key, lanBase, publicBase) -> str`, `readTeamCode(code) -> {"team", "lan", "public", "key"}` (ValueError when not a code), `utcNow() -> datetime` (naive UTC, whole seconds), `isoUtc(moment) -> "YYYY-MM-DDTHH:MM:SSZ"`, `trackFiles(teamId, trackId) -> (Path .cone, Path .jpg)`.
- Produces (tests): `conftest.loadModule(name)`, fixtures `rules`, `teams` (the test's `TEAMS_ROOT`), `useDb(fetchone=(), fetchall=(), lastrowids=None, failOn=None, rowcounts=())`; constants `ADMIN_TOKEN`, `KEY`, `TEAM`, `LAN`, `PUBLIC`; `samples.coneFile(name="Duck pond", cones=3) -> bytes`, `samples.PICTURE` (a JPEG-headed byte string).

- [ ] **Step 1: Create the branch and move the old routes**

```bash
git checkout -b part5-team-server
mkdir server
git mv coneRoutes.py server/coneRoutes.py
```

- [ ] **Step 2: Set up the server's Python environment**

```bash
py -3 -m venv server\.venv
server\.venv\Scripts\python.exe -m pip install flask==3.1.* pytest
```

Create `server/requirements-dev.txt`:

```
flask==3.1.*
pytest
```

Create `server/pytest.ini`:

```ini
[pytest]
testpaths = tests
```

Add to `.gitignore`, replacing the two lines `# The team server's address and keys (part 4)` and `app/config/secrets.json`:

```
# The team server's own secrets and the server tests' environment (part 5). The team code lives in
# Conestructor.ini, never in the repo.
server/coneAdminConfig.json
server/coneAdmin.local.json
server/.venv/
server/**/__pycache__/
server/.pytest_cache/
```

- [ ] **Step 3: Copy the fake connection and write the test scaffolding**

Copy `..\Gluttony\server\tests\fakes.py` (beside this repo) to `server/tests/fakes.py` unchanged, except its first line, which becomes:

```python
# Copied from Gluttony/server/tests/fakes.py (itself from Artemis/Pageturner); unchanged.
```

Create `server/tests/conftest.py`:

```python
"""
Loads the server modules the way Caduceus does, minus the server. The routes do `from . import DBUtils, coneRules`,
so they are imported as submodules of a stand-in package whose DBUtils refuses to connect: a test that reaches the
database by accident fails loudly instead of touching data. (The pattern is Gluttony's server/tests/conftest.py.)
"""
import importlib.util
import json
import pathlib
import sys
import types

import flask
import pytest

SERVER = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from fakes import FakeConn, FakeCursor  # noqa: E402

ADMIN_TOKEN = "test-admin-token"
KEY = "test-team-key"
TEAM = {"id": 3, "name": "Our team"}
LAN = "http://lan.example:5000"
PUBLIC = "https://public.example"


def _refuseConnection(name):
    raise RuntimeError("tests must not open a database connection")


def _load(name):
    if "cone_server" not in sys.modules:
        package = types.ModuleType("cone_server")
        package.__path__ = [str(SERVER)]
        dbutils = types.ModuleType("cone_server.DBUtils")
        dbutils.initConnection = _refuseConnection
        package.DBUtils = dbutils
        sys.modules["cone_server"] = package
        sys.modules["cone_server.DBUtils"] = dbutils
    spec = importlib.util.spec_from_file_location(f"cone_server.{name}", SERVER / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def loadModule(name):
    """Any server module, loaded inside the stand-in package (the rules, the routes, the smoke test...)."""
    return sys.modules.get(f"cone_server.{name}") or _load(name)


@pytest.fixture
def rules():
    return loadModule("coneRules")


@pytest.fixture(autouse=True)
def isolated(monkeypatch, tmp_path):
    """Each test gets its own teams folder and no database."""
    rules = loadModule("coneRules")
    monkeypatch.setattr(rules, "TEAMS_ROOT", tmp_path / "teams")
    monkeypatch.setattr(sys.modules["cone_server.DBUtils"], "initConnection", _refuseConnection)


@pytest.fixture
def teams(rules):
    """The test's own TEAMS_ROOT (not made yet)."""
    return rules.TEAMS_ROOT


@pytest.fixture
def useDb(monkeypatch):
    """Installs a FakeConn answering the queued rows; returns it."""
    def install(fetchone=(), fetchall=(), lastrowids=None, failOn=None, rowcounts=()):
        conn = FakeConn(FakeCursor(fetchone, fetchall, lastrowids, failOn, rowcounts))

        def connect(name):
            assert name == "cone", f"connected to {name!r}"
            return conn

        monkeypatch.setattr(sys.modules["cone_server.DBUtils"], "initConnection", connect)
        return conn
    return install


def appClient(blueprint, prefix, headers):
    """A Flask test client for one blueprint, sending `headers` (WSGI names, e.g. HTTP_X_TEAM_KEY) on every request."""
    app = flask.Flask("cone-tests")
    app.register_blueprint(blueprint, url_prefix=prefix)
    client = app.test_client()
    client.environ_base.update(headers)
    return client
```

Create `server/tests/samples.py`:

```python
"""Upload samples shared by the route tests and the smoke test's tests."""
import json

# Starts like a JPEG (FF D8 FF); the server checks no more than that and the size.
PICTURE = b"\xff\xd8\xff\xe0" + b"sample-thumbnail" * 8 + b"\xff\xd9"


def coneFile(name="Duck pond", cones=3):
    """A small .cone the server accepts: `cones` standing cones in a row, no photo."""
    return json.dumps({
        "format": "conestructor-track", "version": 1, "name": name, "app": "Conestructor 0.6.0",
        "saved": "2026-11-12T14:02:00Z", "units": "m", "axes": "x toward Direction target",
        "targets": {"origin": {"x": 0, "y": 0}, "direction": {"x": 40, "y": 0}, "distance": 40},
        "cones": [{"index": i, "type": "standing", "x": i * 2.0, "y": 0, "heading": 0, "element": "e1"}
                  for i in range(cones)],
        "design": {}, "photo": None}, ensure_ascii=False, indent=2).encode("utf-8")
```

- [ ] **Step 4: Write the failing tests**

Create `server/tests/test_rules.py`:

```python
import json

import pytest

from samples import PICTURE, coneFile

# The format both sides agree on: coneRules makes it, TeamServer::parseCode reads it (tst_teamserver has the same text).
FIXED_CODE = ("CONE1.eyJ2IjoxLCJ0ZWFtIjoiT3VyIHRlYW0iLCJsYW4iOiJodHRwOi8vbGFuLmV4YW1wbGU6NTAwMCIsInB1YmxpYyI6Imh0dHBzOi8v"
              "cHVibGljLmV4YW1wbGUiLCJrZXkiOiJra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2trIn0")


def test_aTrackFileIsRead(rules):
    assert rules.readTrack(coneFile("Duck pond", 3)) == {"name": "Duck pond", "cones": 3}
    assert rules.readTrack(coneFile("  Spaced  ", 0)) == {"name": "Spaced", "cones": 0}
    assert rules.readTrack(coneFile("x" * 300, 1))["name"] == "x" * 200


def doc(**change):
    d = json.loads(coneFile())
    d.update(change)
    return json.dumps(d).encode("utf-8")


@pytest.mark.parametrize("data, message", [
    (b"not json", "not a track file"),
    (b"\xff\xfe", "not a track file"),
    (b"[1, 2]", "not a track file"),
    (doc(format="something-else"), "not a track file"),
    (doc(version=2), "this track file's version is not supported"),
    (doc(version=True), "this track file's version is not supported"),
    (doc(name=""), "the track has no name"),
    (doc(name="   "), "the track has no name"),
    (doc(name=5), "the track has no name"),
    (doc(cones={}), "the track has no cone list"),
], ids=["text", "not utf-8", "a list", "format", "version 2", "version true", "empty name", "blank name",
        "number name", "cones an object"])
def test_aBadTrackFileIsRefused(rules, data, message):
    with pytest.raises(rules.Refused) as refused:
        rules.readTrack(data)
    assert str(refused.value) == message


def test_aThumbnailMustBeASmallJpeg(rules):
    rules.checkThumbnail(PICTURE)
    with pytest.raises(rules.Refused, match="not a JPEG"):
        rules.checkThumbnail(b"\x89PNG\r\n\x1a\n")
    with pytest.raises(rules.Refused, match="not a JPEG"):
        rules.checkThumbnail(b"")
    with pytest.raises(rules.Refused, match="too large"):
        rules.checkThumbnail(PICTURE[:3] + b"\0" * rules.MAX_THUMBNAIL)


def test_teamNames(rules):
    assert rules.teamName("  Our team ") == "Our team"
    for bad in ["", "   ", None, 5, "x" * 101]:
        with pytest.raises(rules.Refused):
            rules.teamName(bad)


def test_keysAreLongRandomAndOnlyTheirHashIsKept(rules):
    a, b = rules.newKey(), rules.newKey()
    assert len(a) == 43 and a != b
    assert rules.keyHash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    assert len(rules.keyHash(a)) == 64


def test_theTeamCodeHasAFixedForm(rules):
    assert rules.teamCode("Our team", "k" * 43, "http://lan.example:5000/", "https://public.example") == FIXED_CODE


def test_teamCodesReadBack(rules):
    code = rules.teamCode("Équipe 🏁", "abc", None, "https://public.example")
    assert rules.readTeamCode("  " + code + "\n") == {"team": "Équipe 🏁", "lan": None,
                                                       "public": "https://public.example", "key": "abc"}
    with pytest.raises(ValueError):
        rules.teamCode("Our team", "abc", None, None)


@pytest.mark.parametrize("code", ["", "CONE2.e30", "CONE1.!!!", "CONE1.e30", "CONE1." + "W10",
                                  "CONE1.eyJ2IjoxLCJrZXkiOiJhIn0", "CONE1.eyJ2IjoyLCJwdWJsaWMiOiJ4Iiwia2V5IjoiYSJ9"],
                         ids=["empty", "prefix", "not base64", "empty object", "a list", "no address", "version 2"])
def test_notTeamCodes(rules, code):
    with pytest.raises(ValueError):
        rules.readTeamCode(code)


def test_timesAndPaths(rules, teams):
    moment = rules.utcNow()
    assert moment.tzinfo is None and moment.microsecond == 0
    assert rules.isoUtc(moment.replace(year=2026, month=11, day=12, hour=14, minute=2, second=0)) == "2026-11-12T14:02:00Z"
    assert rules.trackFiles(3, 12) == (teams / "3" / "12.cone", teams / "3" / "12.jpg")
```

Create `server/tests/test_schema.py`:

```python
import pathlib
import re

SCHEMA = (pathlib.Path(__file__).resolve().parent.parent / "schema.sql").read_text(encoding="utf-8")


def test_theTablesAreTeamsAndTracks():
    assert set(re.findall(r"CREATE TABLE (\w+)", SCHEMA)) == {"teams", "tracks"}


def test_theOldTableGoesFirstAndTracksBeforeTeams():
    drops = re.findall(r"DROP TABLE IF EXISTS (\w+);", SCHEMA)
    assert drops == ["tracks", "teams"]
    assert SCHEMA.index("DROP TABLE IF EXISTS teams") < SCHEMA.index("CREATE TABLE teams")


def test_everyTableUsesTheHouseEngineAndCollation():
    tails = re.findall(r"CREATE TABLE \w+ \(.*?\n\)(.*?);", SCHEMA, re.S)
    assert len(tails) == 2
    for tail in tails:
        assert tail.strip() == "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci"


def test_onlyTheKeysHashIsStoredAndItIsUnique():
    assert "keyHash CHAR(64) NOT NULL" in SCHEMA
    assert "UNIQUE KEY keyHash (keyHash)" in SCHEMA
    assert not re.search(r"\bkey\s+(VARCHAR|CHAR|TEXT)", SCHEMA, re.I)


def test_noPathsAreStored():
    assert "Path" not in SCHEMA
```

- [ ] **Step 5: Run the tests to see them fail**

Run (from `server\`): `.venv\Scripts\python.exe -m pytest -q`
Expected: FAIL — `coneRules.py` and `schema.sql` do not exist (FileNotFoundError while loading).

- [ ] **Step 6: Write `coneRules.py`**

Create `server/coneRules.py`:

```python
"""
Conestructor's team server: the checks, the keys and the team codes, with no Flask and no database, so the routes stay
thin. Shared by coneRoutes.py (the team API), coneAdminRoutes.py (the LAN-only admin API), the smoke test and the live
check. Repo: Code-Development/Conestructor server/.
"""
import base64
import binascii
import hashlib
import json
import secrets
from datetime import datetime, timezone
from pathlib import Path

# Where the teams' files live: <TEAMS_ROOT>/<teamId>/<trackId>.cone and .jpg. Paths come from ids only, never from a
# request or the database.
TEAMS_ROOT = Path("/pool/appFiles/conestructor/teams")

MAX_FILE = 40 * 1024 * 1024               # one .cone, its photo included
MAX_THUMBNAIL = 200 * 1024
MAX_REQUEST = MAX_FILE + 1024 * 1024      # a whole upload: the file, the thumbnail and the form's own lines
MAX_TRACK_NAME = 200
MAX_TEAM_NAME = 100
CODE_PREFIX = "CONE1."
FORMAT = "conestructor-track"
JPEG_START = b"\xff\xd8\xff"


class Refused(Exception):
    """An upload or a name the server will not take; the message is said to the person."""


def readTrack(data):
    """{"name", "cones"} read from an uploaded .cone's bytes. Refused when it is not a track file this server takes."""
    try:
        doc = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        raise Refused("not a track file")
    if not isinstance(doc, dict) or doc.get("format") != FORMAT:
        raise Refused("not a track file")
    version = doc.get("version")
    if isinstance(version, bool) or version != 1:
        raise Refused("this track file's version is not supported")
    name = doc.get("name")
    if not isinstance(name, str) or not name.strip():
        raise Refused("the track has no name")
    if not isinstance(doc.get("cones"), list):
        raise Refused("the track has no cone list")
    return {"name": name.strip()[:MAX_TRACK_NAME], "cones": len(doc["cones"])}


def checkThumbnail(data):
    """Refused unless `data` starts like a JPEG and is at most MAX_THUMBNAIL bytes."""
    if not data.startswith(JPEG_START):
        raise Refused("the thumbnail is not a JPEG")
    if len(data) > MAX_THUMBNAIL:
        raise Refused("the thumbnail is too large")


def teamName(value):
    """A team's name without surrounding spaces; Refused when blank or too long."""
    if not isinstance(value, str) or not value.strip():
        raise Refused("a team needs a name")
    name = value.strip()
    if len(name) > MAX_TEAM_NAME:
        raise Refused(f"a team name is at most {MAX_TEAM_NAME} characters")
    return name


def newKey():
    """A team key: 32 random bytes, base64url (43 characters)."""
    return secrets.token_urlsafe(32)


def keyHash(key):
    """What the teams table keeps of a key: its SHA-256, in hex."""
    return hashlib.sha256(key.encode("utf-8")).hexdigest()


def teamCode(team, key, lanBase, publicBase):
    """The one line a teammate pastes into Preferences › Team: CONE1. and base64url (no padding) of the team's name,
    the addresses it may use (LAN first) and its key. ValueError when there is no address at all."""
    if not lanBase and not publicBase:
        raise ValueError("a team code needs the LAN address or the public address")
    fields = {"v": 1, "team": team}
    if lanBase:
        fields["lan"] = lanBase.rstrip("/")
    if publicBase:
        fields["public"] = publicBase.rstrip("/")
    fields["key"] = key
    text = json.dumps(fields, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return CODE_PREFIX + base64.urlsafe_b64encode(text).decode("ascii").rstrip("=")


def readTeamCode(code):
    """{"team", "lan", "public", "key"} from a team code (a missing address is None); ValueError when it is not one."""
    code = (code or "").strip()
    if not code.startswith(CODE_PREFIX):
        raise ValueError("not a team code")
    body = code[len(CODE_PREFIX):]
    try:
        raw = base64.b64decode(body + "=" * (-len(body) % 4), altchars=b"-_", validate=True)
        fields = json.loads(raw.decode("utf-8"))
    except (binascii.Error, ValueError, UnicodeDecodeError):
        raise ValueError("not a team code")
    if not isinstance(fields, dict) or fields.get("v") != 1 or isinstance(fields.get("v"), bool):
        raise ValueError("not a team code")
    key, lan, public = fields.get("key"), fields.get("lan"), fields.get("public")
    lan = lan if isinstance(lan, str) and lan else None
    public = public if isinstance(public, str) and public else None
    if not isinstance(key, str) or not key or (lan is None and public is None):
        raise ValueError("not a team code")
    team = fields.get("team")
    return {"team": team if isinstance(team, str) else "", "lan": lan, "public": public, "key": key}


def utcNow():
    """Now in UTC to the second, as the tables keep times (DATETIME, no zone)."""
    return datetime.now(timezone.utc).replace(tzinfo=None, microsecond=0)


def isoUtc(moment):
    """A table's UTC time as ISO 8601: 2026-11-12T14:02:00Z."""
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def trackFiles(teamId, trackId):
    """The track's two files: (<TEAMS_ROOT>/<teamId>/<trackId>.cone, .../<trackId>.jpg)."""
    folder = TEAMS_ROOT / str(int(teamId))
    return folder / f"{int(trackId)}.cone", folder / f"{int(trackId)}.jpg"
```

- [ ] **Step 7: Write the schema and the example config**

Create `server/schema.sql`:

```sql
-- Conestructor's team server (part 5). Run once on coneDB by the owner (server/README.md, "Cut-over"): it replaces
-- the prototype's tracks table, whose three old tracks are not kept. Times are UTC. Only a key's SHA-256 is stored.
-- Track files live at /pool/appFiles/conestructor/teams/<teamId>/<trackId>.cone and .jpg, named by ids, so no path
-- is stored.

DROP TABLE IF EXISTS tracks;
DROP TABLE IF EXISTS teams;

CREATE TABLE teams (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    keyHash CHAR(64) NOT NULL,
    created DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY keyHash (keyHash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE tracks (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    teamId INT UNSIGNED NOT NULL,
    name VARCHAR(200) NOT NULL,
    cones INT UNSIGNED NOT NULL,
    uploaded DATETIME NOT NULL,
    bytes INT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    KEY teamUploaded (teamId, uploaded),
    CONSTRAINT tracksTeam FOREIGN KEY (teamId) REFERENCES teams (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

Create `server/coneAdminConfig.example.json`:

```json
{
  "token": "<a long random token: py -3 -c \"import secrets; print(secrets.token_urlsafe(32))\">",
  "lanBase": "http://<LAN address>:5000",
  "publicBase": "https://<public host>"
}
```

- [ ] **Step 8: Run the tests to see them pass**

Run (from `server\`): `.venv\Scripts\python.exe -m pytest -q`
Expected: PASS (all of `test_rules.py` and `test_schema.py`).

- [ ] **Step 9: Commit**

```bash
git add .gitignore server/coneRules.py server/schema.sql server/coneAdminConfig.example.json server/requirements-dev.txt server/pytest.ini server/tests server/coneRoutes.py
git status --short
git commit -m "Server: coneRoutes.py moves to server/; coneRules (upload checks, keys, team codes), the teams and tracks schema, pytest scaffolding from Gluttony's" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

`git status --short` must show no `.venv`, `__pycache__` or `.pytest_cache` paths staged.

---

### Task 2: The team API (`/api/cone`)

**Files:**
- Rewrite: `server/coneRoutes.py`
- Modify: `server/tests/conftest.py` (fixtures `teamRoutes`, `anonClient`, `teamClient`)
- Test: `server/tests/test_team.py`

**Interfaces:**
- Consumes: Task 1's `coneRules`, `conftest.appClient`, `useDb`, `KEY`, `TEAM`, `samples`.
- Produces: `coneRoutes.coneBP` (blueprint name `"cone"`, registered at `/api/cone` by Caduceus as today), `coneRoutes.DB_NAME = "cone"`, `coneRoutes.database()` (a context manager yielding a connection), `coneRoutes.error(message, code=400)`. Answers: `GET /ping` → `{"status": "ok"}`; `GET /team` → `{"status": "ok", "name"}`; `GET /tracks` → `{"status": "ok", "tracks": [{"id", "name", "cones", "uploaded", "bytes"}]}`; `GET /tracks/<id>/thumbnail` (image/jpeg), `GET /tracks/<id>/file` (application/json); `POST /tracks` → 201 `{"status": "ok", "id"}`; errors `{"status": "error", "message"}` with 400, 401, 404, 413, 500.

- [ ] **Step 1: Add the fixtures**

Append to `server/tests/conftest.py`:

```python
@pytest.fixture
def teamRoutes():
    return loadModule("coneRoutes")


@pytest.fixture
def anonClient(teamRoutes):
    """The team API with no key."""
    return appClient(teamRoutes.coneBP, "/api/cone", {})


@pytest.fixture
def teamClient(teamRoutes):
    """The team API sending KEY; queue TEAM first in useDb's fetchone for the key lookup."""
    return appClient(teamRoutes.coneBP, "/api/cone", {"HTTP_X_TEAM_KEY": KEY})
```

- [ ] **Step 2: Write the failing tests**

Create `server/tests/test_team.py`:

```python
import io
import pathlib
from datetime import datetime

import pytest

from conftest import KEY, TEAM
from samples import PICTURE, coneFile


def upload(client, data=None, picture=PICTURE, **extra):
    form = dict(extra)
    if data is not None:
        form["file"] = (io.BytesIO(data), "track.cone")
    if picture is not None:
        form["thumbnail"] = (io.BytesIO(picture), "thumbnail.jpg")
    return client.post("/api/cone/tracks", data=form, content_type="multipart/form-data")


def leftovers(teams):
    return sorted(p.name for p in teams.rglob("*") if p.is_file()) if teams.exists() else []


def test_pingNeedsNoKey(anonClient):
    answer = anonClient.get("/api/cone/ping")
    assert answer.status_code == 200 and answer.get_json() == {"status": "ok"}


@pytest.mark.parametrize("method, path", [("GET", "/team"), ("GET", "/tracks"), ("GET", "/tracks/1/file"),
                                          ("GET", "/tracks/1/thumbnail"), ("POST", "/tracks")])
def test_everythingElseNeedsAKey(anonClient, method, path):
    answer = anonClient.open("/api/cone" + path, method=method)
    assert answer.status_code == 401
    assert answer.get_json() == {"status": "error", "message": "unauthorized"}


def test_aWrongKeyIsRefusedAndOnlyItsHashIsLookedUp(useDb, teamClient, rules):
    conn = useDb(fetchone=[None])
    assert teamClient.get("/api/cone/team").status_code == 401
    sql, params = conn.cur.executed[0]
    assert sql == "SELECT id, name FROM teams WHERE keyHash = %s"
    assert params == (rules.keyHash(KEY),)


def test_theTeamsName(useDb, teamClient):
    useDb(fetchone=[TEAM])
    assert teamClient.get("/api/cone/team").get_json() == {"status": "ok", "name": "Our team"}


def test_theListIsTheTeamsOwnNewestFirst(useDb, teamClient):
    conn = useDb(fetchone=[TEAM], fetchall=[[
        {"id": 12, "name": "Duck pond", "cones": 132, "uploaded": datetime(2026, 11, 12, 14, 2), "bytes": 3000},
        {"id": 9, "name": "Duck pond", "cones": 120, "uploaded": datetime(2026, 11, 3, 9, 0), "bytes": 2000}]])
    answer = teamClient.get("/api/cone/tracks").get_json()
    assert answer == {"status": "ok", "tracks": [
        {"id": 12, "name": "Duck pond", "cones": 132, "uploaded": "2026-11-12T14:02:00Z", "bytes": 3000},
        {"id": 9, "name": "Duck pond", "cones": 120, "uploaded": "2026-11-03T09:00:00Z", "bytes": 2000}]}
    sql, params = conn.cur.executed[1]
    assert sql == ("SELECT id, name, cones, uploaded, bytes FROM tracks WHERE teamId = %s "
                   "ORDER BY uploaded DESC, id DESC")
    assert params == (3,)


def writeTrack(rules, teamId, trackId, data=b'{"format": "conestructor-track"}', picture=PICTURE):
    cone, jpg = rules.trackFiles(teamId, trackId)
    cone.parent.mkdir(parents=True, exist_ok=True)
    cone.write_bytes(data)
    jpg.write_bytes(picture)


def test_aTracksFilesAreSent(useDb, teamClient, rules):
    writeTrack(rules, 3, 12, coneFile())
    useDb(fetchone=[TEAM, {"id": 12}, TEAM, {"id": 12}])
    file = teamClient.get("/api/cone/tracks/12/file")
    assert file.status_code == 200 and file.mimetype == "application/json" and file.data == coneFile()
    thumbnail = teamClient.get("/api/cone/tracks/12/thumbnail")
    assert thumbnail.status_code == 200 and thumbnail.mimetype == "image/jpeg" and thumbnail.data == PICTURE
    assert "private" in thumbnail.headers["Cache-Control"]


def test_anotherTeamsTrackIsNotFound(useDb, teamClient, rules):
    writeTrack(rules, 4, 12)                              # team 4's track 12 is there
    conn = useDb(fetchone=[TEAM, None])
    answer = teamClient.get("/api/cone/tracks/12/file")
    assert answer.status_code == 404 and answer.get_json()["message"] == "no such track"
    assert conn.cur.executed[1] == ("SELECT id FROM tracks WHERE id = %s AND teamId = %s", (12, 3))


def test_aMissingFileIsNotFound(useDb, teamClient):
    useDb(fetchone=[TEAM, {"id": 12}])
    assert teamClient.get("/api/cone/tracks/12/thumbnail").status_code == 404


def test_anUploadIsStored(useDb, teamClient, rules, teams):
    conn = useDb(fetchone=[TEAM], lastrowids={"tracks": [12]})
    answer = upload(teamClient, coneFile("Duck pond", 3))
    assert answer.status_code == 201 and answer.get_json() == {"status": "ok", "id": 12}
    cone, jpg = rules.trackFiles(3, 12)
    assert cone.read_bytes() == coneFile("Duck pond", 3) and jpg.read_bytes() == PICTURE
    assert leftovers(teams) == ["12.cone", "12.jpg"]
    sql, params = conn.cur.statements("INSERT")[0]
    assert sql == "INSERT INTO tracks (teamId, name, cones, uploaded, bytes) VALUES (%s, %s, %s, %s, %s)"
    assert params[:3] == (3, "Duck pond", 3) and params[4] == len(coneFile("Duck pond", 3))
    assert isinstance(params[3], datetime)
    assert conn.commits == 1 and conn.rollbacks == 0


def test_theNameAndCountComeFromTheFile(useDb, teamClient):
    conn = useDb(fetchone=[TEAM], lastrowids={"tracks": [12]})
    upload(teamClient, coneFile("Duck pond", 3), name="Something else", cones="999")
    assert conn.cur.statements("INSERT")[0][1][1:3] == ("Duck pond", 3)


def test_anyNameIsStoredAsItIs(useDb, teamClient):
    conn = useDb(fetchone=[TEAM], lastrowids={"tracks": [12]})
    name = 'Duck "pond" / wet é 🏁'
    assert upload(teamClient, coneFile(name, 1)).status_code == 201
    assert conn.cur.statements("INSERT")[0][1][1] == name


@pytest.mark.parametrize("data, picture, message", [
    (b"not json", PICTURE, "not a track file"),
    (coneFile().replace(b'"version": 1', b'"version": 2'), PICTURE, "this track file's version is not supported"),
    (coneFile(), b"\x89PNG\r\n\x1a\n", "the thumbnail is not a JPEG"),
    (None, PICTURE, "the upload needs a file and a thumbnail"),
    (coneFile(), None, "the upload needs a file and a thumbnail"),
], ids=["not json", "version 2", "png thumbnail", "no file", "no thumbnail"])
def test_aBadUploadIsRefused(useDb, teamClient, teams, data, picture, message):
    conn = useDb(fetchone=[TEAM])
    answer = upload(teamClient, data, picture)
    assert answer.status_code == 400 and answer.get_json()["message"] == message
    assert conn.cur.statements("INSERT") == [] and leftovers(teams) == []


def test_aThumbnailTooLargeIsRefused(useDb, teamClient, rules, teams):
    useDb(fetchone=[TEAM])
    answer = upload(teamClient, coneFile(), PICTURE[:3] + b"\0" * rules.MAX_THUMBNAIL)
    assert answer.status_code == 400 and answer.get_json()["message"] == "the thumbnail is too large"


def test_aRequestTooLargeIsRefusedBeforeItIsRead(useDb, teamClient, rules, monkeypatch):
    monkeypatch.setattr(rules, "MAX_REQUEST", 100)
    useDb(fetchone=[TEAM])
    answer = upload(teamClient, coneFile())
    assert answer.status_code == 413 and answer.get_json() == {"status": "error", "message": "too large"}


def test_aFileTooLargeIsRefused(useDb, teamClient, rules, monkeypatch, teams):
    monkeypatch.setattr(rules, "MAX_FILE", 100)
    useDb(fetchone=[TEAM])
    answer = upload(teamClient, coneFile())
    assert answer.status_code == 413 and leftovers(teams) == []


def test_aFailedInsertLeavesNothing(useDb, teamClient, teams):
    conn = useDb(fetchone=[TEAM], failOn="INSERT INTO tracks")
    answer = upload(teamClient, coneFile())
    assert answer.status_code == 500 and answer.get_json()["message"] == "could not store the track"
    assert leftovers(teams) == [] and conn.rollbacks == 1 and conn.commits == 0


def test_aFailedRenameLeavesNothing(useDb, teamClient, teams, monkeypatch):
    conn = useDb(fetchone=[TEAM], lastrowids={"tracks": [12]})
    realReplace = pathlib.Path.replace
    calls = []

    def secondFails(self, target):
        calls.append(target)
        if len(calls) == 2:
            raise OSError("disk full")
        return realReplace(self, target)
    monkeypatch.setattr(pathlib.Path, "replace", secondFails)
    assert upload(teamClient, coneFile()).status_code == 500
    assert leftovers(teams) == [] and conn.rollbacks == 1 and conn.commits == 0


def test_aFailedCommitLeavesNothing(useDb, teamClient, teams):
    conn = useDb(fetchone=[TEAM], lastrowids={"tracks": [12]})

    def refuse():
        raise RuntimeError("lost connection")
    conn.commit = refuse
    assert upload(teamClient, coneFile()).status_code == 500
    assert leftovers(teams) == [] and conn.rollbacks == 1
```

- [ ] **Step 3: Run the tests to see them fail**

Run (from `server\`): `.venv\Scripts\python.exe -m pytest -q tests/test_team.py`
Expected: FAIL — the old `coneRoutes.py` imports `mysql.connector` (ModuleNotFoundError) and has none of these routes.

- [ ] **Step 4: Rewrite `coneRoutes.py`**

Replace `server/coneRoutes.py` with:

```python
"""
Conestructor's team API on the server, at /api/cone (Caduceus registers coneBP there). The only prefix nginx passes
from the public subdomain; the LAN reaches it on the API's own port. Every request but ping needs X-Team-Key, and a
team sees only its own tracks: another team's track answers 404, as one that does not exist. Checks live in coneRules,
so the routes stay thin. Repo: Code-Development/Conestructor server/ (README.md there says what goes where).
"""
import uuid
from contextlib import contextmanager

from flask import Blueprint, g, jsonify, request, send_file

from . import DBUtils, coneRules as rules

coneBP = Blueprint("cone", __name__)

DB_NAME = "cone"


def error(message, code=400):
    return jsonify({"status": "error", "message": message}), code


@contextmanager
def database():
    conn = DBUtils.initConnection(DB_NAME)
    try:
        yield conn
    finally:
        conn.close()


@coneBP.errorhandler(413)
def tooLarge(_):
    return error("too large", 413)


@coneBP.before_request
def requireTeamKey():
    """Finds the team whose key this is (by the key's hash) and keeps it in g.team; 401 when none."""
    if request.endpoint == "cone.ping":
        return None
    key = request.headers.get("X-Team-Key", "")
    if not key:
        return error("unauthorized", 401)
    try:
        with database() as conn:
            cur = conn.cursor(dictionary=True)
            cur.execute("SELECT id, name FROM teams WHERE keyHash = %s", (rules.keyHash(key),))
            team = cur.fetchone()
            cur.close()
    except Exception as e:
        print(f"[cone] looking up a team key failed: {e}")
        return error("database error", 500)
    if team is None:
        return error("unauthorized", 401)
    g.team = team
    return None


@coneBP.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok"})


@coneBP.route("/team", methods=["GET"])
def team():
    return jsonify({"status": "ok", "name": g.team["name"]})


@coneBP.route("/tracks", methods=["GET"])
def tracks():
    try:
        with database() as conn:
            cur = conn.cursor(dictionary=True)
            cur.execute("SELECT id, name, cones, uploaded, bytes FROM tracks WHERE teamId = %s "
                        "ORDER BY uploaded DESC, id DESC", (g.team["id"],))
            rows = cur.fetchall()
            cur.close()
    except Exception as e:
        print(f"[cone] listing tracks failed: {e}")
        return error("database error", 500)
    return jsonify({"status": "ok", "tracks": [
        {"id": r["id"], "name": r["name"], "cones": r["cones"], "uploaded": rules.isoUtc(r["uploaded"]),
         "bytes": r["bytes"]} for r in rows]})


def ownTrack(trackId):
    """Whether track `trackId` is this team's."""
    with database() as conn:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT id FROM tracks WHERE id = %s AND teamId = %s", (trackId, g.team["id"]))
        row = cur.fetchone()
        cur.close()
    return row is not None


def sendTrackFile(trackId, which, mimetype):
    """One of the track's two files (0: the .cone, 1: the thumbnail), never cached by anything in between."""
    try:
        if not ownTrack(trackId):
            return error("no such track", 404)
    except Exception as e:
        print(f"[cone] finding track {trackId} failed: {e}")
        return error("database error", 500)
    path = rules.trackFiles(g.team["id"], trackId)[which]
    if not path.is_file():
        return error("the track's file is missing", 404)
    answer = send_file(path, mimetype=mimetype, max_age=0)
    answer.headers["Cache-Control"] = "private, no-cache"
    return answer


@coneBP.route("/tracks/<int:trackId>/file", methods=["GET"])
def trackFile(trackId):
    return sendTrackFile(trackId, 0, "application/json")


@coneBP.route("/tracks/<int:trackId>/thumbnail", methods=["GET"])
def thumbnail(trackId):
    return sendTrackFile(trackId, 1, "image/jpeg")


@coneBP.route("/tracks", methods=["POST"])
def upload():
    """A multipart form: `file` (the .cone) and `thumbnail` (a JPEG). The name and cone count are read from the file."""
    if request.content_length is not None and request.content_length > rules.MAX_REQUEST:
        return error("too large", 413)
    request.max_content_length = rules.MAX_REQUEST     # Flask 3.1: also caps a body sent without a length
    file = request.files.get("file")
    picture = request.files.get("thumbnail")
    if file is None or picture is None:
        return error("the upload needs a file and a thumbnail")
    data = file.read(rules.MAX_FILE + 1)
    if len(data) > rules.MAX_FILE:
        return error("too large", 413)
    thumbnailData = picture.read(rules.MAX_THUMBNAIL + 1)
    try:
        info = rules.readTrack(data)
        rules.checkThumbnail(thumbnailData)
    except rules.Refused as e:
        return error(str(e))
    return store(info, data, thumbnailData)


def store(info, data, thumbnailData):
    """Writes both files under temporary names, inserts the row, renames the files to the row's id and commits. Any
    failure rolls the row back and removes every file it wrote, so a failed upload leaves nothing behind."""
    teamId = g.team["id"]
    folder = rules.TEAMS_ROOT / str(int(teamId))
    temporary = uuid.uuid4().hex
    written = [folder / f".upload-{temporary}.cone", folder / f".upload-{temporary}.jpg"]
    placed = []
    conn = None
    try:
        folder.mkdir(parents=True, exist_ok=True)
        written[0].write_bytes(data)
        written[1].write_bytes(thumbnailData)
        conn = DBUtils.initConnection(DB_NAME)
        cur = conn.cursor()
        cur.execute("INSERT INTO tracks (teamId, name, cones, uploaded, bytes) VALUES (%s, %s, %s, %s, %s)",
                    (teamId, info["name"], info["cones"], rules.utcNow(), len(data)))
        trackId = cur.lastrowid
        cur.close()
        for temporaryPath, final in zip(written, rules.trackFiles(teamId, trackId)):
            temporaryPath.replace(final)
            placed.append(final)
        conn.commit()
    except Exception as e:
        print(f"[cone] storing an upload failed: {e}")
        if conn is not None:
            try:
                conn.rollback()
            except Exception:
                pass
        for path in written + placed:
            try:
                path.unlink(missing_ok=True)
            except OSError:
                pass
        return error("could not store the track", 500)
    finally:
        if conn is not None:
            conn.close()
    return jsonify({"status": "ok", "id": trackId}), 201
```

- [ ] **Step 5: Run the tests to see them pass**

Run (from `server\`): `.venv\Scripts\python.exe -m pytest -q`
Expected: PASS (every test so far).

If `request.max_content_length = ...` raises `AttributeError` (a Flask older than 3.1), stop: the server runs Flask 3.1.2 and the venv must match it (`pip install flask==3.1.*`).

- [ ] **Step 6: Commit**

```bash
git add server/coneRoutes.py server/tests/conftest.py server/tests/test_team.py
git commit -m "Server: the team API at /api/cone (key by hash, the team's own tracks, multipart upload that leaves nothing behind on failure)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The admin API (`/api/cone-admin`, LAN only)

**Files:**
- Create: `server/coneAdminRoutes.py`
- Modify: `server/tests/conftest.py` (fixtures `adminRoutes`, `adminClient`, `anonAdminClient`, helper `writeConfig`)
- Test: `server/tests/test_admin.py`

**Interfaces:**
- Consumes: `coneRules` (Task 1), `conftest` (Tasks 1–2).
- Produces: `coneAdminRoutes.coneAdminBP` (name `"coneAdmin"`, registered at `/api/cone-admin`), `CONFIG_FILE`, `_configCache`, `config() -> dict`. Answers: `POST /teams {"name"}` → 201 `{"status", "id", "name", "key", "code"}`; `POST /teams/<id>/key` → `{"status", "id", "name", "key", "code"}`; `GET /teams` → `{"status", "teams": [{"id", "name", "tracks", "created"}]}`; `GET /tracks[?team=<id>]` → `{"status", "tracks": [{"id", "teamId", "team", "name", "cones", "uploaded", "bytes"}]}`; `DELETE /tracks/<id>` → `{"status": "ok", "id"}`.

- [ ] **Step 1: Add the fixtures**

Append to `server/tests/conftest.py`:

```python
def writeConfig(admin, path, fields):
    """Writes coneAdminConfig.json for the admin routes and makes them read it again."""
    path.write_text(json.dumps(fields), encoding="utf-8")
    admin.CONFIG_FILE = path
    admin._configCache.update({"mtime": None, "config": {}})


@pytest.fixture
def adminRoutes(monkeypatch, tmp_path):
    admin = loadModule("coneAdminRoutes")
    path = tmp_path / "coneAdminConfig.json"
    monkeypatch.setattr(admin, "CONFIG_FILE", path)
    writeConfig(admin, path, {"token": ADMIN_TOKEN, "lanBase": LAN, "publicBase": PUBLIC})
    return admin


@pytest.fixture
def adminClient(adminRoutes):
    return appClient(adminRoutes.coneAdminBP, "/api/cone-admin", {"HTTP_X_ADMIN_TOKEN": ADMIN_TOKEN})


@pytest.fixture
def anonAdminClient(adminRoutes):
    return appClient(adminRoutes.coneAdminBP, "/api/cone-admin", {})
```

- [ ] **Step 2: Write the failing tests**

Create `server/tests/test_admin.py`:

```python
from datetime import datetime

import pytest

from conftest import ADMIN_TOKEN, LAN, PUBLIC, appClient, writeConfig


@pytest.mark.parametrize("token", [None, "", "wrong"])
def test_everyRouteNeedsTheToken(adminRoutes, token):
    headers = {} if token is None else {"HTTP_X_ADMIN_TOKEN": token}
    client = appClient(adminRoutes.coneAdminBP, "/api/cone-admin", headers)
    for method, path in [("GET", "/teams"), ("POST", "/teams"), ("GET", "/tracks"), ("DELETE", "/tracks/1"),
                         ("POST", "/teams/1/key")]:
        answer = client.open("/api/cone-admin" + path, method=method)
        assert answer.status_code == 401, (method, path)


def test_withoutAConfigNothingIsAllowed(adminRoutes, tmp_path):
    adminRoutes.CONFIG_FILE = tmp_path / "missing.json"
    adminRoutes._configCache.update({"mtime": None, "config": {}})
    client = appClient(adminRoutes.coneAdminBP, "/api/cone-admin", {"HTTP_X_ADMIN_TOKEN": ADMIN_TOKEN})
    assert client.get("/api/cone-admin/teams").status_code == 401


def test_aTeamIsMadeWithACodeThatReadsBack(useDb, adminClient, rules):
    conn = useDb(lastrowids={"teams": [5]})
    answer = adminClient.post("/api/cone-admin/teams", json={"name": "  Our team "})
    assert answer.status_code == 201
    made = answer.get_json()
    assert made["id"] == 5 and made["name"] == "Our team" and len(made["key"]) == 43
    assert rules.readTeamCode(made["code"]) == {"team": "Our team", "lan": LAN, "public": PUBLIC, "key": made["key"]}
    sql, params = conn.cur.statements("INSERT")[0]
    assert sql == "INSERT INTO teams (name, keyHash, created) VALUES (%s, %s, %s)"
    assert params[:2] == ("Our team", rules.keyHash(made["key"])) and made["key"] not in params
    assert isinstance(params[2], datetime) and conn.commits == 1


@pytest.mark.parametrize("body", [{}, {"name": ""}, {"name": "   "}, {"name": "x" * 101}, {"name": 5}])
def test_aTeamNeedsAName(adminClient, body):
    answer = adminClient.post("/api/cone-admin/teams", json=body)
    assert answer.status_code == 400


def test_aCodeNeedsAnAddressInTheConfig(adminRoutes, adminClient, tmp_path):
    writeConfig(adminRoutes, tmp_path / "coneAdminConfig.json", {"token": ADMIN_TOKEN})
    answer = adminClient.post("/api/cone-admin/teams", json={"name": "Our team"})
    assert answer.status_code == 500
    assert answer.get_json()["message"] == "coneAdminConfig.json has neither lanBase nor publicBase"


def test_aCodeMayCarryOnlyThePublicAddress(adminRoutes, adminClient, useDb, rules, tmp_path):
    writeConfig(adminRoutes, tmp_path / "coneAdminConfig.json", {"token": ADMIN_TOKEN, "publicBase": PUBLIC})
    useDb(lastrowids={"teams": [5]})
    code = adminClient.post("/api/cone-admin/teams", json={"name": "Our team"}).get_json()["code"]
    assert rules.readTeamCode(code)["lan"] is None


def test_aNewKeyReplacesTheOldOne(useDb, adminClient, rules):
    conn = useDb(fetchone=[{"name": "Our team"}])
    answer = adminClient.post("/api/cone-admin/teams/5/key").get_json()
    assert answer["id"] == 5 and answer["name"] == "Our team"
    assert rules.readTeamCode(answer["code"])["key"] == answer["key"]
    sql, params = conn.cur.statements("UPDATE")[0]
    assert sql == "UPDATE teams SET keyHash = %s WHERE id = %s"
    assert params == (rules.keyHash(answer["key"]), 5) and conn.commits == 1


def test_aNewKeyForNoTeam(useDb, adminClient):
    conn = useDb(fetchone=[None])
    assert adminClient.post("/api/cone-admin/teams/9/key").status_code == 404
    assert conn.cur.statements("UPDATE") == []


def test_theTeams(useDb, adminClient):
    conn = useDb(fetchall=[[{"id": 1, "name": "Our team", "created": datetime(2026, 11, 12, 9, 30), "tracks": 4}]])
    answer = adminClient.get("/api/cone-admin/teams").get_json()
    assert answer == {"status": "ok", "teams": [{"id": 1, "name": "Our team", "tracks": 4,
                                                  "created": "2026-11-12T09:30:00Z"}]}
    assert conn.cur.executed[0][0] == ("SELECT t.id, t.name, t.created, COUNT(k.id) AS tracks FROM teams t "
                                       "LEFT JOIN tracks k ON k.teamId = t.id GROUP BY t.id, t.name, t.created "
                                       "ORDER BY t.id")


def test_theTracksOfOneTeamOrAll(useDb, adminClient):
    row = {"id": 12, "teamId": 1, "team": "Our team", "name": "Duck pond", "cones": 132,
           "uploaded": datetime(2026, 11, 12, 14, 2), "bytes": 3000}
    conn = useDb(fetchall=[[row], [row]])
    answer = adminClient.get("/api/cone-admin/tracks?team=1").get_json()
    assert answer["tracks"] == [dict(row, uploaded="2026-11-12T14:02:00Z")]
    sql, params = conn.cur.executed[0]
    assert sql.endswith("WHERE k.teamId = %s ORDER BY k.uploaded DESC, k.id DESC") and params == (1,)
    adminClient.get("/api/cone-admin/tracks")
    sql, params = conn.cur.executed[1]
    assert "WHERE" not in sql and params == ()


def test_aBadTeamFilter(adminClient):
    assert adminClient.get("/api/cone-admin/tracks?team=x").status_code == 400


def test_deletingATrackRemovesItsRowAndFiles(useDb, adminClient, rules):
    for trackId in (12, 13):
        for path in rules.trackFiles(1, trackId):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"x")
    conn = useDb(fetchone=[{"teamId": 1}])
    assert adminClient.delete("/api/cone-admin/tracks/12").get_json() == {"status": "ok", "id": 12}
    assert conn.cur.statements("DELETE")[0] == ("DELETE FROM tracks WHERE id = %s", (12,))
    assert conn.commits == 1
    assert not any(p.exists() for p in rules.trackFiles(1, 12))
    assert all(p.exists() for p in rules.trackFiles(1, 13))


def test_deletingNoTrack(useDb, adminClient):
    conn = useDb(fetchone=[None])
    assert adminClient.delete("/api/cone-admin/tracks/99").status_code == 404
    assert conn.cur.statements("DELETE") == []
```

- [ ] **Step 3: Run the tests to see them fail**

Run (from `server\`): `.venv\Scripts\python.exe -m pytest -q tests/test_admin.py`
Expected: FAIL — `coneAdminRoutes.py` does not exist.

- [ ] **Step 4: Write `coneAdminRoutes.py`**

Create `server/coneAdminRoutes.py`:

```python
"""
Conestructor's admin API on the server, at /api/cone-admin (Caduceus registers coneAdminBP there). LAN only: nginx never
passes this prefix from the public subdomain. Every request needs X-Admin-Token matching coneAdminConfig.json beside
this file (chmod 600, never committed), which also holds the two addresses team codes carry, so they live only on the
server and inside codes. server/coneAdmin.py on the owner's PC calls these routes.
"""
import hmac
import json
from contextlib import contextmanager
from pathlib import Path

from flask import Blueprint, jsonify, request

from . import DBUtils, coneRules as rules

coneAdminBP = Blueprint("coneAdmin", __name__)

CONFIG_FILE = Path(__file__).resolve().parent / "coneAdminConfig.json"
DB_NAME = "cone"
NO_ADDRESS = "coneAdminConfig.json has neither lanBase nor publicBase"
_configCache = {"mtime": None, "config": {}}


def config():
    """coneAdminConfig.json as a dict ({} when it is missing or unreadable), read again whenever the file changes."""
    try:
        mtime = CONFIG_FILE.stat().st_mtime
    except (OSError, AttributeError, TypeError):
        return {}
    if _configCache["mtime"] != mtime:
        try:
            loaded = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
            _configCache["config"] = loaded if isinstance(loaded, dict) else {}
        except (OSError, ValueError):
            _configCache["config"] = {}
        _configCache["mtime"] = mtime
    return _configCache["config"]


def error(message, code=400):
    return jsonify({"status": "error", "message": message}), code


@contextmanager
def database():
    conn = DBUtils.initConnection(DB_NAME)
    try:
        yield conn
    finally:
        conn.close()


@coneAdminBP.before_request
def requireAdminToken():
    expected = config().get("token")
    given = request.headers.get("X-Admin-Token", "")
    if not isinstance(expected, str) or not expected or not hmac.compare_digest(given.encode(), expected.encode()):
        return error("unauthorized", 401)
    return None


def body():
    """The JSON body as a dict, or {} (never Flask 3's automatic 415)."""
    data = request.get_json(silent=True)
    return data if isinstance(data, dict) else {}


def codeFor(name, key):
    settings = config()
    return rules.teamCode(name, key, settings.get("lanBase"), settings.get("publicBase"))


@coneAdminBP.route("/teams", methods=["POST"])
def makeTeam():
    try:
        name = rules.teamName(body().get("name"))
    except rules.Refused as e:
        return error(str(e))
    key = rules.newKey()
    try:
        code = codeFor(name, key)
    except ValueError:
        return error(NO_ADDRESS, 500)
    try:
        with database() as conn:
            cur = conn.cursor()
            cur.execute("INSERT INTO teams (name, keyHash, created) VALUES (%s, %s, %s)",
                        (name, rules.keyHash(key), rules.utcNow()))
            teamId = cur.lastrowid
            cur.close()
            conn.commit()
    except Exception as e:
        print(f"[cone-admin] making a team failed: {e}")
        return error("database error", 500)
    return jsonify({"status": "ok", "id": teamId, "name": name, "key": key, "code": code}), 201


@coneAdminBP.route("/teams/<int:teamId>/key", methods=["POST"])
def replaceKey(teamId):
    key = rules.newKey()
    try:
        with database() as conn:
            cur = conn.cursor(dictionary=True)
            cur.execute("SELECT name FROM teams WHERE id = %s", (teamId,))
            row = cur.fetchone()
            if row is None:
                cur.close()
                return error("no such team", 404)
            code = codeFor(row["name"], key)
            cur.execute("UPDATE teams SET keyHash = %s WHERE id = %s", (rules.keyHash(key), teamId))
            cur.close()
            conn.commit()
    except ValueError:
        return error(NO_ADDRESS, 500)
    except Exception as e:
        print(f"[cone-admin] replacing team {teamId}'s key failed: {e}")
        return error("database error", 500)
    return jsonify({"status": "ok", "id": teamId, "name": row["name"], "key": key, "code": code})


@coneAdminBP.route("/teams", methods=["GET"])
def teams():
    try:
        with database() as conn:
            cur = conn.cursor(dictionary=True)
            cur.execute("SELECT t.id, t.name, t.created, COUNT(k.id) AS tracks FROM teams t "
                        "LEFT JOIN tracks k ON k.teamId = t.id GROUP BY t.id, t.name, t.created ORDER BY t.id")
            rows = cur.fetchall()
            cur.close()
    except Exception as e:
        print(f"[cone-admin] listing teams failed: {e}")
        return error("database error", 500)
    return jsonify({"status": "ok", "teams": [
        {"id": r["id"], "name": r["name"], "tracks": int(r["tracks"]), "created": rules.isoUtc(r["created"])}
        for r in rows]})


@coneAdminBP.route("/tracks", methods=["GET"])
def tracks():
    team = request.args.get("team")
    if team is not None and not team.isdigit():
        return error("team must be a number")
    sql = ("SELECT k.id, k.teamId, t.name AS team, k.name, k.cones, k.uploaded, k.bytes FROM tracks k "
           "JOIN teams t ON t.id = k.teamId")
    params = ()
    if team is not None:
        sql += " WHERE k.teamId = %s"
        params = (int(team),)
    sql += " ORDER BY k.uploaded DESC, k.id DESC"
    try:
        with database() as conn:
            cur = conn.cursor(dictionary=True)
            cur.execute(sql, params)
            rows = cur.fetchall()
            cur.close()
    except Exception as e:
        print(f"[cone-admin] listing tracks failed: {e}")
        return error("database error", 500)
    return jsonify({"status": "ok", "tracks": [
        {"id": r["id"], "teamId": r["teamId"], "team": r["team"], "name": r["name"], "cones": r["cones"],
         "uploaded": rules.isoUtc(r["uploaded"]), "bytes": r["bytes"]} for r in rows]})


@coneAdminBP.route("/tracks/<int:trackId>", methods=["DELETE"])
def deleteTrack(trackId):
    try:
        with database() as conn:
            cur = conn.cursor(dictionary=True)
            cur.execute("SELECT teamId FROM tracks WHERE id = %s", (trackId,))
            row = cur.fetchone()
            if row is None:
                cur.close()
                return error("no such track", 404)
            cur.execute("DELETE FROM tracks WHERE id = %s", (trackId,))
            cur.close()
            conn.commit()
    except Exception as e:
        print(f"[cone-admin] deleting track {trackId} failed: {e}")
        return error("database error", 500)
    for path in rules.trackFiles(row["teamId"], trackId):
        try:
            path.unlink(missing_ok=True)
        except OSError as e:
            print(f"[cone-admin] track {trackId}'s file {path.name} stayed: {e}")
    return jsonify({"status": "ok", "id": trackId})
```

- [ ] **Step 5: Run the tests to see them pass**

Run (from `server\`): `.venv\Scripts\python.exe -m pytest -q`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add server/coneAdminRoutes.py server/tests/conftest.py server/tests/test_admin.py
git commit -m "Server: the LAN-only admin API at /api/cone-admin (make a team and its code, replace a key, list, delete a track)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The admin script (`coneAdmin.py`)

**Files:**
- Create: `server/coneAdmin.py`
- Test: `server/tests/test_coneadmin.py`

**Interfaces:**
- Consumes: the admin API's answers (Task 3).
- Produces: `coneAdmin.main(argv=None, out=sys.stdout, err=sys.stderr, ask=input, environ=os.environ, local=None) -> int` (0 done, 1 failed, 2 bad arguments from argparse), `coneAdmin.settings(environ, local) -> (base, token)`, `coneAdmin.localTime(iso) -> "YYYY-MM-DD HH:MM"`, `coneAdmin.size(bytes) -> "1.4 MB" | "12 KB"`, `class Failed(Exception)`.

- [ ] **Step 1: Write the failing tests**

Create `server/tests/test_coneadmin.py`:

```python
import io
import json
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

from conftest import loadModule

TOKEN = "admin-token-for-tests"


class StandIn:
    """A tiny HTTP server answering canned replies by (method, path) and recording each request."""

    def __init__(self, replies):
        self.replies = replies
        self.requests = []
        outer = self

        class Handler(BaseHTTPRequestHandler):
            def answer(self, method):
                length = int(self.headers.get("Content-Length") or 0)
                data = self.rfile.read(length) if length else b""
                outer.requests.append({"method": method, "path": self.path,
                                       "token": self.headers.get("X-Admin-Token"),
                                       "body": json.loads(data) if data else None})
                status, reply = outer.replies.get((method, self.path), (404, {"status": "error", "message": "no such route"}))
                text = json.dumps(reply).encode("utf-8")
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(text)))
                self.end_headers()
                self.wfile.write(text)

            def do_GET(self):
                self.answer("GET")

            def do_POST(self):
                self.answer("POST")

            def do_DELETE(self):
                self.answer("DELETE")

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.server.server_address[1]}"

    def close(self):
        self.server.shutdown()
        self.server.server_close()


@pytest.fixture
def standIn():
    made = []

    def make(replies):
        server = StandIn(replies)
        made.append(server)
        return server
    yield make
    for server in made:
        server.close()


@pytest.fixture
def admin():
    return loadModule("coneAdmin")


def run(admin, server, *argv, ask=None):
    out, err = io.StringIO(), io.StringIO()
    environ = {"CONE_ADMIN_URL": server.base if server else "http://127.0.0.1:9", "CONE_ADMIN_TOKEN": TOKEN}

    def refuse(prompt):
        raise AssertionError("asked: " + prompt)
    code = admin.main(list(argv), out=out, err=err, ask=ask or refuse, environ=environ)
    return code, out.getvalue(), err.getvalue()


def test_makeTeamPrintsTheCodeOnce(admin, standIn):
    server = standIn({("POST", "/api/cone-admin/teams"): (201, {"status": "ok", "id": 1, "name": "Our team",
                                                               "key": "k", "code": "CONE1.abc"})})
    code, out, err = run(admin, server, "make-team", "Our team")
    assert code == 0 and err == ""
    assert out.splitlines() == ["Team 1 (Our team) made. Its team code, shown only now; paste it into "
                                "Preferences > Team:", "CONE1.abc"]
    assert server.requests == [{"method": "POST", "path": "/api/cone-admin/teams", "token": TOKEN,
                                "body": {"name": "Our team"}}]
    assert TOKEN not in out


def test_newKey(admin, standIn):
    server = standIn({("POST", "/api/cone-admin/teams/1/key"): (200, {"status": "ok", "id": 1, "name": "Our team",
                                                                     "key": "k2", "code": "CONE1.def"})})
    code, out, _ = run(admin, server, "new-key", "1")
    assert code == 0
    assert out.splitlines() == ["New key for team 1 (Our team): codes made before no longer work. Its team code:",
                                "CONE1.def"]


def test_theTeams(admin, standIn):
    server = standIn({("GET", "/api/cone-admin/teams"): (200, {"status": "ok", "teams": [
        {"id": 1, "name": "Our team", "tracks": 4, "created": "2026-11-12T09:30:00Z"}]})})
    code, out, _ = run(admin, server, "teams")
    assert code == 0
    assert out.strip() == f"1  Our team  (4 tracks, made {admin.localTime('2026-11-12T09:30:00Z')})"
    empty = standIn({("GET", "/api/cone-admin/teams"): (200, {"status": "ok", "teams": []})})
    assert run(admin, empty, "teams")[1].strip() == "No teams yet."


TRACK = {"id": 12, "teamId": 1, "team": "Our team", "name": "Duck pond", "cones": 132,
         "uploaded": "2026-11-12T14:02:00Z", "bytes": 1468006}


def test_theTracks(admin, standIn):
    server = standIn({("GET", "/api/cone-admin/tracks?team=1"): (200, {"status": "ok", "tracks": [TRACK]})})
    code, out, _ = run(admin, server, "tracks", "--team", "1")
    assert code == 0
    assert out.strip() == f"12  Duck pond  (Our team, 132 cones, {admin.localTime(TRACK['uploaded'])}, 1.4 MB)"


def test_deleteAsksFirst(admin, standIn):
    replies = {("GET", "/api/cone-admin/tracks"): (200, {"status": "ok", "tracks": [TRACK]}),
               ("DELETE", "/api/cone-admin/tracks/12"): (200, {"status": "ok", "id": 12})}
    server = standIn(replies)
    code, out, _ = run(admin, server, "delete", "12", ask=lambda prompt: "n")
    assert code == 0 and out.splitlines()[-1] == "Kept."
    assert [r["method"] for r in server.requests] == ["GET"]
    code, out, _ = run(admin, server, "delete", "12", ask=lambda prompt: "y")
    assert code == 0 and out.splitlines()[-1] == "Deleted track 12."
    assert server.requests[-1]["method"] == "DELETE"
    code, out, _ = run(admin, server, "delete", "12", "--yes")      # never asks
    assert code == 0 and out.splitlines()[-1] == "Deleted track 12."


def test_deleteNoTrack(admin, standIn):
    server = standIn({("GET", "/api/cone-admin/tracks"): (200, {"status": "ok", "tracks": [TRACK]})})
    code, _, err = run(admin, server, "delete", "99", "--yes")
    assert code == 1 and err.strip() == "coneAdmin: no track 99"


def test_aWrongToken(admin, standIn):
    server = standIn({("GET", "/api/cone-admin/teams"): (401, {"status": "error", "message": "unauthorized"})})
    code, _, err = run(admin, server, "teams")
    assert code == 1 and err.strip() == "coneAdmin: unauthorized (check the admin token)"


def test_aServerError(admin, standIn):
    server = standIn({("POST", "/api/cone-admin/teams"): (500, {"status": "error", "message": "database error"})})
    code, _, err = run(admin, server, "make-team", "x")
    assert code == 1 and err.strip() == "coneAdmin: the server answered 500: database error"


def test_noServer(admin):
    code, _, err = run(admin, None, "teams")
    assert code == 1 and err.startswith("coneAdmin: can't reach http://127.0.0.1:9")


def test_settingsComeFromTheEnvironmentOrTheLocalFile(admin, tmp_path):
    local = tmp_path / "coneAdmin.local.json"
    with pytest.raises(admin.Failed, match="set CONE_ADMIN_URL and CONE_ADMIN_TOKEN"):
        admin.settings({}, local)
    local.write_text(json.dumps({"url": "http://lan.example:5000/", "token": "t"}))
    assert admin.settings({}, local) == ("http://lan.example:5000", "t")
    assert admin.settings({"CONE_ADMIN_URL": "http://x:1", "CONE_ADMIN_TOKEN": "u"}, local) == ("http://x:1", "u")


def test_timesAndSizes(admin):
    expected = datetime(2026, 11, 12, 14, 2, tzinfo=timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M")
    assert admin.localTime("2026-11-12T14:02:00Z") == expected
    assert admin.size(1468006) == "1.4 MB" and admin.size(12000) == "12 KB" and admin.size(10) == "1 KB"
```

- [ ] **Step 2: Run the tests to see them fail**

Run (from `server\`): `.venv\Scripts\python.exe -m pytest -q tests/test_coneadmin.py`
Expected: FAIL — `coneAdmin.py` does not exist.

- [ ] **Step 3: Write `coneAdmin.py`**

Create `server/coneAdmin.py`:

```python
"""
The owner's admin commands for Conestructor's team server, run from the PC on the LAN (never deployed). They call the
LAN-only admin API (/api/cone-admin, coneAdminRoutes.py) with the admin token. Standard library only.

    py -3 server\\coneAdmin.py make-team "Our team"     makes a team and prints its team code, once
    py -3 server\\coneAdmin.py new-key 1                replaces team 1's key; codes made before stop working
    py -3 server\\coneAdmin.py teams
    py -3 server\\coneAdmin.py tracks [--team 1]
    py -3 server\\coneAdmin.py delete 12 [--yes]

The server's LAN base (http://<LAN address>:5000) and the admin token come from CONE_ADMIN_URL and CONE_ADMIN_TOKEN, or
from coneAdmin.local.json beside this file ({"url": ..., "token": ...}; gitignored). The token is never printed.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

LOCAL_CONFIG = Path(__file__).resolve().parent / "coneAdmin.local.json"
AGENT = "ConestructorAdmin/1.0"


class Failed(Exception):
    pass


def settings(environ=os.environ, local=None):
    """(LAN base without a trailing slash, admin token)."""
    local = LOCAL_CONFIG if local is None else local
    url, token = environ.get("CONE_ADMIN_URL"), environ.get("CONE_ADMIN_TOKEN")
    if (not url or not token) and local.is_file():
        try:
            stored = json.loads(local.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            stored = {}
        if isinstance(stored, dict):
            url = url or stored.get("url")
            token = token or stored.get("token")
    if not url or not token:
        raise Failed("set CONE_ADMIN_URL and CONE_ADMIN_TOKEN, or write server/coneAdmin.local.json")
    return url.rstrip("/"), token


def call(base, token, method, route, body=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    request = urllib.request.Request(base + "/api/cone-admin" + route, data=data, method=method)
    request.add_header("User-Agent", AGENT)
    request.add_header("X-Admin-Token", token)
    if data is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=30) as answer:
            return json.loads(answer.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 401:
            raise Failed("unauthorized (check the admin token)")
        try:
            message = json.loads(e.read().decode("utf-8")).get("message")
        except (ValueError, AttributeError):
            message = None
        raise Failed(f"the server answered {e.code}" + (f": {message}" if message else ""))
    except (urllib.error.URLError, OSError) as e:
        raise Failed(f"can't reach {base}: {getattr(e, 'reason', e)}")


def localTime(iso):
    """A UTC time from the server (2026-11-12T14:02:00Z) in this PC's time: 2026-11-12 09:02."""
    moment = datetime.strptime(iso, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    return moment.astimezone().strftime("%Y-%m-%d %H:%M")


def size(count):
    if count >= 1024 * 1024:
        return f"{count / 1024 / 1024:.1f} MB"
    return f"{max(1, round(count / 1024))} KB"


def makeTeam(base, token, name, out):
    team = call(base, token, "POST", "/teams", {"name": name})
    print(f"Team {team['id']} ({team['name']}) made. Its team code, shown only now; paste it into Preferences > Team:",
          file=out)
    print(team["code"], file=out)


def newKey(base, token, teamId, out):
    team = call(base, token, "POST", f"/teams/{teamId}/key")
    print(f"New key for team {team['id']} ({team['name']}): codes made before no longer work. Its team code:", file=out)
    print(team["code"], file=out)


def teams(base, token, out):
    rows = call(base, token, "GET", "/teams")["teams"]
    if not rows:
        print("No teams yet.", file=out)
    for t in rows:
        print(f"{t['id']}  {t['name']}  ({t['tracks']} tracks, made {localTime(t['created'])})", file=out)


def describe(track):
    return (f"{track['name']}  ({track['team']}, {track['cones']} cones, {localTime(track['uploaded'])}, "
            f"{size(track['bytes'])})")


def tracks(base, token, team, out):
    rows = call(base, token, "GET", "/tracks" + (f"?team={team}" if team is not None else ""))["tracks"]
    if not rows:
        print("No tracks.", file=out)
    for track in rows:
        print(f"{track['id']}  {describe(track)}", file=out)


def delete(base, token, trackId, yes, out, ask):
    rows = call(base, token, "GET", "/tracks")["tracks"]
    track = next((k for k in rows if k["id"] == trackId), None)
    if track is None:
        raise Failed(f"no track {trackId}")
    print(f"Track {trackId}: {describe(track)}", file=out)
    if not yes and ask("Delete it? [y/N] ").strip().lower() not in ("y", "yes"):
        print("Kept.", file=out)
        return
    call(base, token, "DELETE", f"/tracks/{trackId}")
    print(f"Deleted track {trackId}.", file=out)


def main(argv=None, out=sys.stdout, err=sys.stderr, ask=input, environ=os.environ, local=None):
    parser = argparse.ArgumentParser(prog="coneAdmin.py",
                                     description="Admin commands for Conestructor's team server (LAN only).")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("make-team", help="make a team and print its team code").add_argument("name")
    commands.add_parser("new-key", help="replace a team's key and print its new code").add_argument("team", type=int)
    commands.add_parser("teams", help="list the teams")
    listing = commands.add_parser("tracks", help="list the tracks")
    listing.add_argument("--team", type=int)
    removing = commands.add_parser("delete", help="delete a track")
    removing.add_argument("track", type=int)
    removing.add_argument("--yes", action="store_true", help="do not ask first")
    args = parser.parse_args(argv)
    try:
        base, token = settings(environ, local)
        if args.command == "make-team":
            makeTeam(base, token, args.name, out)
        elif args.command == "new-key":
            newKey(base, token, args.team, out)
        elif args.command == "teams":
            teams(base, token, out)
        elif args.command == "tracks":
            tracks(base, token, args.team, out)
        else:
            delete(base, token, args.track, args.yes, out, ask)
    except Failed as e:
        print(f"coneAdmin: {e}", file=err)
        return 1
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="backslashreplace")
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to see them pass**

Run (from `server\`): `.venv\Scripts\python.exe -m pytest -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/coneAdmin.py server/tests/test_coneadmin.py
git commit -m "Server: coneAdmin.py, the owner's admin commands (make-team, new-key, teams, tracks, delete) over the LAN-only admin API" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The smoke test, the live check and the server README

**Files:**
- Create: `server/coneSmoke.py`, `server/liveCheck.py`, `server/README.md`
- Test: `server/tests/test_smoke.py`, `server/tests/test_livecheck.py`

**Interfaces:**
- Consumes: `coneRules`, `coneRoutes.coneBP`, `coneAdminRoutes.coneAdminBP` (Tasks 1–3).
- Produces: `coneSmoke.scratchConnections(database, connect)`, `coneSmoke.runSteps(client, teamsRoot) -> int`, `coneSmoke.main(argv) -> int`; `liveCheck.multipart(parts) -> (body: bytes, contentType: str)`, `liveCheck.main(argv=None, environ=os.environ) -> int`.

- [ ] **Step 1: Write the failing tests**

Create `server/tests/test_smoke.py`:

```python
from types import SimpleNamespace

import pytest

from conftest import loadModule


def test_theRealDatabaseIsRefused():
    smoke = loadModule("coneSmoke")
    for name in ["coneDB", "bad name;", "gluttonyDB", ""]:
        with pytest.raises(ValueError):
            smoke.scratchConnections(name, lambda n: None)


def test_everyConnectionSwitchesToTheScratchDatabase():
    smoke = loadModule("coneSmoke")
    executed = []
    cursor = SimpleNamespace(execute=lambda sql: executed.append(sql), close=lambda: None)
    conn = SimpleNamespace(cursor=lambda: cursor)
    connect = smoke.scratchConnections("cone_smoke", lambda name: conn)
    assert connect("cone") is conn and executed == ["USE `cone_smoke`"]


def test_mainRefusesABadNameWithExitTwo():
    smoke = loadModule("coneSmoke")
    assert smoke.main(["--database", "conedb"]) == 2


def test_aNonEmptyScratchDatabaseFailsTheFirstStep(capsys, tmp_path):
    smoke = loadModule("coneSmoke")
    answer = SimpleNamespace(status_code=200, mimetype="application/json",
                             get_json=lambda silent=True: {"status": "ok", "teams": [{"id": 1}]},
                             get_data=lambda: b"")
    client = SimpleNamespace(open=lambda *args, **kwargs: answer)
    assert smoke.runSteps(client, tmp_path) == 1
    assert "FAIL  empty: the scratch database is not empty: drop and recreate it" in capsys.readouterr().out
```

Create `server/tests/test_livecheck.py`:

```python
import io

import flask

from conftest import loadModule


def test_theFormIsReadByFlask():
    live = loadModule("liveCheck")
    body, kind = live.multipart([("file", "track.cone", "application/json", b'{"a": 1}'),
                                 ("thumbnail", "thumbnail.jpg", "image/jpeg", b"\xff\xd8\xff\x00")])
    app = flask.Flask("live-form")
    seen = {}

    @app.route("/echo", methods=["POST"])
    def echo():
        seen.update({name: (f.filename, f.mimetype, f.read()) for name, f in flask.request.files.items()})
        return "ok"
    assert app.test_client().post("/echo", data=io.BytesIO(body), content_type=kind).status_code == 200
    assert seen == {"file": ("track.cone", "application/json", b'{"a": 1}'),
                    "thumbnail": ("thumbnail.jpg", "image/jpeg", b"\xff\xd8\xff\x00")}


def test_withoutACodeItSaysWhatToSet(capsys):
    live = loadModule("liveCheck")
    assert live.main([], environ={}) == 2
    assert "CONE_CHECK_CODE" in capsys.readouterr().err
```

- [ ] **Step 2: Run the tests to see them fail**

Run (from `server\`): `.venv\Scripts\python.exe -m pytest -q tests/test_smoke.py tests/test_livecheck.py`
Expected: FAIL — `coneSmoke.py` and `liveCheck.py` do not exist.

- [ ] **Step 3: Write `coneSmoke.py`**

Create `server/coneSmoke.py`:

```python
"""
The real-MySQL smoke test, run on the server against a scratch database before cut-over (the route tests only ever meet
a fake connection):

    cd /database/API && /database/venv/bin/python -m util.coneSmoke --database cone_smoke

Every connection is switched to the scratch database, and track files go to a temporary folder, so nothing touches
coneDB or /pool. Prints PASS or FAIL per step and stops at the first failure. The scratch database must be empty, with
schema.sql loaded (server/README.md, "The smoke test").
"""
import argparse
import io
import json
import re
import sys
import tempfile
from pathlib import Path

import flask

from . import DBUtils, coneAdminRoutes as admin, coneRoutes as team, coneRules as rules

A, T = "/api/cone-admin", "/api/cone"
TOKEN = "smoke-admin-token"
PICTURE = b"\xff\xd8\xff\xe0" + b"smoke" * 20 + b"\xff\xd9"


class SmokeFailed(Exception):
    pass


def scratchConnections(database, connect):
    """Wraps connect so every connection switches to `database`. Only a name containing "smoke" is accepted, so coneDB
    and every other real database are refused."""
    if not re.fullmatch(r"[A-Za-z0-9_]+", database or "") or "smoke" not in database.lower():
        raise ValueError("the smoke test only runs on a scratch database whose name contains smoke, never coneDB")

    def switched(name):
        try:
            conn = connect(name)
            cur = conn.cursor()
            cur.execute(f"USE `{database}`")
            cur.close()
        except Exception as e:
            print(f"smoke: could not open the scratch database: {type(e).__name__}: {e}", file=sys.stderr)
            raise
        return conn
    return switched


def check(condition, message):
    if not condition:
        raise SmokeFailed(message)


def sampleTrack():
    return json.dumps({"format": "conestructor-track", "version": 1, "name": "Smoke track", "cones": [
        {"index": 0, "type": "standing", "x": 1, "y": 2, "heading": 0, "element": "e1"},
        {"index": 1, "type": "leaning", "x": 3, "y": 4, "heading": 90, "element": "e1"}], "photo": None}).encode("utf-8")


def call(client, method, path, key=None, expect=200, **kwargs):
    """The answer (a response); SmokeFailed when its status is not `expect`."""
    headers = {"X-Team-Key": key} if key else {}
    answer = client.open(path, method=method, headers=headers, **kwargs)
    if answer.status_code != expect:
        text = answer.get_data()[:200].decode("utf-8", "replace")
        raise SmokeFailed(f"{method} {path} gave {answer.status_code}: {text}")
    return answer


def steps(teamsRoot):
    def empty(client, state):
        check(call(client, "GET", f"{A}/teams").get_json()["teams"] == [],
              "the scratch database is not empty: drop and recreate it")
        return "no teams yet"

    def teams(client, state):
        for label in ("A", "B"):
            made = call(client, "POST", f"{A}/teams", json={"name": f"Smoke {label}"}, expect=201).get_json()
            check(rules.readTeamCode(made["code"])["key"] == made["key"], "the code does not carry the key")
            state[label] = made
        return f"teams {state['A']['id']} and {state['B']['id']}, codes read back"

    def upload(client, state):
        form = {"file": (io.BytesIO(sampleTrack()), "track.cone"), "thumbnail": (io.BytesIO(PICTURE), "thumbnail.jpg")}
        made = call(client, "POST", f"{T}/tracks", key=state["A"]["key"], expect=201, data=form,
                    content_type="multipart/form-data").get_json()
        state["track"] = made["id"]
        return f"track {made['id']}"

    def listed(client, state):
        tracks = call(client, "GET", f"{T}/tracks", key=state["A"]["key"]).get_json()["tracks"]
        check([(t["id"], t["name"], t["cones"], t["bytes"]) for t in tracks]
              == [(state["track"], "Smoke track", 2, len(sampleTrack()))], f"listed {tracks}")
        return "listed with its name, cones and size"

    def files(client, state):
        key = state["A"]["key"]
        check(call(client, "GET", f"{T}/tracks/{state['track']}/thumbnail", key=key).data == PICTURE,
              "the thumbnail came back changed")
        check(call(client, "GET", f"{T}/tracks/{state['track']}/file", key=key).data == sampleTrack(),
              "the file came back changed")
        return "thumbnail and file byte for byte"

    def otherTeam(client, state):
        key = state["B"]["key"]
        check(call(client, "GET", f"{T}/tracks", key=key).get_json()["tracks"] == [], "team B sees team A's track")
        call(client, "GET", f"{T}/tracks/{state['track']}/file", key=key, expect=404)
        return "team B sees nothing of team A's"

    def newKey(client, state):
        old = state["A"]["key"]
        made = call(client, "POST", f"{A}/teams/{state['A']['id']}/key").get_json()
        call(client, "GET", f"{T}/team", key=old, expect=401)
        check(call(client, "GET", f"{T}/team", key=made["key"]).get_json()["name"] == "Smoke A", "the new key's team")
        call(client, "GET", f"{T}/tracks", key="not-a-key", expect=401)
        state["A"]["key"] = made["key"]
        return "the old key refused, the new one works"

    def delete(client, state):
        call(client, "DELETE", f"{A}/tracks/{state['track']}")
        check(not any(p.exists() for p in rules.trackFiles(state["A"]["id"], state["track"])), "files left behind")
        check(call(client, "GET", f"{T}/tracks", key=state["A"]["key"]).get_json()["tracks"] == [], "still listed")
        return "row and files gone"

    return [("empty", empty), ("teams", teams), ("upload", upload), ("list", listed), ("files", files),
            ("other team", otherTeam), ("new key", newKey), ("delete", delete)]


def runSteps(client, teamsRoot):
    """Runs every step on `client` (an admin and team test client); 0 when all pass, 1 at the first failure."""
    state = {}
    for name, step in steps(teamsRoot):
        try:
            print(f"PASS  {name}: {step(client, state)}")
        except SmokeFailed as e:
            print(f"FAIL  {name}: {e}")
            return 1
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description="Conestructor's team server smoke test (scratch database only).")
    parser.add_argument("--database", required=True)
    args = parser.parse_args(argv)
    try:
        connect = scratchConnections(args.database, DBUtils.initConnection)
    except ValueError as e:
        print(f"smoke: {e}", file=sys.stderr)
        return 2
    DBUtils.initConnection = connect
    with tempfile.TemporaryDirectory(prefix="cone-smoke-") as folder:
        rules.TEAMS_ROOT = Path(folder) / "teams"
        config = Path(folder) / "coneAdminConfig.json"
        config.write_text(json.dumps({"token": TOKEN, "lanBase": "http://lan.example:5000",
                                      "publicBase": "https://public.example"}), encoding="utf-8")
        admin.CONFIG_FILE = config
        admin._configCache.update({"mtime": None, "config": {}})
        app = flask.Flask("cone-smoke")
        app.register_blueprint(team.coneBP, url_prefix=T)
        app.register_blueprint(admin.coneAdminBP, url_prefix=A)
        client = app.test_client()
        client.environ_base["HTTP_X_ADMIN_TOKEN"] = TOKEN
        return runSteps(client, rules.TEAMS_ROOT)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Write `liveCheck.py`**

Create `server/liveCheck.py`:

```python
"""
The rollout's live check (server/README.md, "Rollout" step 7): every route the app calls, against the real server,
from this PC. Never deployed. It reads the team code from CONE_CHECK_CODE and checks each address the code carries (the
LAN first, then the public one). The sample track it uploads on each is deleted at the end through the LAN-only admin
API, with the admin token from CONE_ADMIN_TOKEN (and the LAN base from CONE_ADMIN_URL when the code has none). Neither
the code, the key nor the token is ever printed. Prints PASS or FAIL per step and stops at the first failure.
Standard library and coneRules only.

    set CONE_CHECK_CODE=<the team code>
    set CONE_ADMIN_TOKEN=<the admin token>
    py -3 server\\liveCheck.py
"""
import json
import os
import sys
import urllib.error
import urllib.request
import uuid
from datetime import datetime

import coneRules as rules

AGENT = "ConestructorLiveCheck/1.0"
PICTURE = b"\xff\xd8\xff\xe0" + b"live-check" * 10 + b"\xff\xd9"


class CheckFailed(Exception):
    pass


def check(condition, message):
    if not condition:
        raise CheckFailed(message)


def multipart(parts):
    """A multipart/form-data body from (field, filename, contentType, bytes) parts: (body, Content-Type)."""
    boundary = "----conestructor-" + uuid.uuid4().hex
    chunks = []
    for field, filename, kind, data in parts:
        chunks.append((f"--{boundary}\r\nContent-Disposition: form-data; name=\"{field}\"; filename=\"{filename}\"\r\n"
                       f"Content-Type: {kind}\r\n\r\n").encode("utf-8") + data + b"\r\n")
    return b"".join(chunks) + f"--{boundary}--\r\n".encode("utf-8"), f"multipart/form-data; boundary={boundary}"


def fetch(url, method="GET", headers=None, data=None):
    """(status, body bytes); CheckFailed when nothing answers."""
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header("User-Agent", AGENT)
    for name, value in (headers or {}).items():
        request.add_header(name, value)
    try:
        with urllib.request.urlopen(request, timeout=60) as answer:
            return answer.status, answer.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except (urllib.error.URLError, OSError) as e:
        raise CheckFailed(f"{method} {url.split('/api/')[-1]} reached nothing: {getattr(e, 'reason', e)}")


def sample(label):
    return json.dumps({"format": "conestructor-track", "version": 1, "name": f"Live check ({label})",
                       "cones": [{"index": 0, "type": "standing", "x": 0, "y": 0, "heading": 0, "element": None}],
                       "photo": None}).encode("utf-8")


def baseSteps(label, base, code, uploaded):
    key = {"X-Team-Key": code["key"]}
    api = base + "/api/cone"

    def ping():
        status, data = fetch(api + "/ping")
        check(status == 200 and json.loads(data) == {"status": "ok"}, f"ping gave {status}")
        return "ok"

    def team():
        status, data = fetch(api + "/team", headers=key)
        check(status == 200 and json.loads(data)["name"] == code["team"], f"team gave {status}")
        return code["team"]

    def upload():
        body, kind = multipart([("file", "track.cone", "application/json", sample(label)),
                                ("thumbnail", "thumbnail.jpg", "image/jpeg", PICTURE)])
        status, data = fetch(api + "/tracks", "POST", dict(key, **{"Content-Type": kind}), body)
        check(status == 201, f"upload gave {status}: {data[:200]!r}")
        uploaded.append(json.loads(data)["id"])
        return f"track {uploaded[-1]}"

    def listed():
        status, data = fetch(api + "/tracks", headers=key)
        check(status == 200 and any(t["id"] == uploaded[-1] for t in json.loads(data)["tracks"]), "not listed")
        return "listed"

    def files():
        status, data = fetch(f"{api}/tracks/{uploaded[-1]}/file", headers=key)
        check(status == 200 and data == sample(label), f"file gave {status}, changed or not")
        status, data = fetch(f"{api}/tracks/{uploaded[-1]}/thumbnail", headers=key)
        check(status == 200 and data == PICTURE, f"thumbnail gave {status}, changed or not")
        return "file and thumbnail byte for byte"

    def wrongKey():
        status, _ = fetch(api + "/team", headers={"X-Team-Key": "not-a-key"})
        check(status == 401, f"a wrong key gave {status}")
        return "401"

    return [(f"{label} ping", ping), (f"{label} team", team), (f"{label} upload", upload), (f"{label} list", listed),
            (f"{label} files", files), (f"{label} wrong key", wrongKey)]


def outsideSteps(base):
    def adminHidden():
        status, _ = fetch(base + "/api/cone-admin/teams")
        check(status == 404, f"/api/cone-admin/ gave {status} from outside")
        status, _ = fetch(base + "/")
        check(status == 404, f"/ gave {status} from outside")
        return "/api/cone-admin/ and / answer 404"
    return [("public admin hidden", adminHidden)]


def main(argv=None, environ=os.environ):
    try:
        code = rules.readTeamCode(environ.get("CONE_CHECK_CODE", ""))
    except ValueError:
        print("liveCheck: set CONE_CHECK_CODE to the team code (and CONE_ADMIN_TOKEN to the admin token)", file=sys.stderr)
        return 2
    token = environ.get("CONE_ADMIN_TOKEN")
    adminBase = (code["lan"] or environ.get("CONE_ADMIN_URL") or "").rstrip("/")
    if not token or not adminBase:
        print("liveCheck: set CONE_ADMIN_TOKEN (and CONE_ADMIN_URL when the code has no LAN address)", file=sys.stderr)
        return 2
    uploaded = []
    plan = []
    if code["lan"]:
        plan += baseSteps("LAN", code["lan"].rstrip("/"), code, uploaded)
    if code["public"]:
        plan += baseSteps("public", code["public"].rstrip("/"), code, uploaded) + outsideSteps(code["public"].rstrip("/"))
    failed = 0
    for name, step in plan:
        try:
            print(f"PASS  {name}: {step()}")
        except CheckFailed as e:
            print(f"FAIL  {name}: {e}")
            failed = 1
            break
    for trackId in uploaded:
        try:
            status, _ = fetch(f"{adminBase}/api/cone-admin/tracks/{trackId}", "DELETE", {"X-Admin-Token": token})
            print(f"{'PASS' if status == 200 else 'FAIL'}  cleanup: track {trackId} deleted ({status})")
            failed = failed or int(status != 200)
        except CheckFailed as e:
            print(f"FAIL  cleanup: track {trackId}: {e}")
            failed = 1
    print(f"{datetime.now():%H:%M} {'all passed' if not failed else 'stopped at a failure'}")
    return failed


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="backslashreplace")
    sys.exit(main())
```

`liveCheck.py` imports `coneRules` as a plain module (run from `server\`, the script's folder is on the path). Under pytest it is loaded inside the stand-in package; add `sys.path` there so the import works: append to `server/tests/conftest.py`:

```python
# liveCheck.py imports coneRules as a plain module, as it does when run from server\.
sys.path.insert(0, str(SERVER))
```

- [ ] **Step 5: Write `server/README.md`**

Create `server/README.md`:

````markdown
# Conestructor's team server

Flask blueprints for the owner's API service (Caduceus, in `/database/API/`), beside the other apps' blueprints, plus
two scripts run from the PC. The public subdomain passes only `/api/cone/`; `/api/cone-admin/` stays LAN only because
nginx never routes it (the LAN reaches the API's own port, 5000, directly). The spec is
`docs/superpowers/specs/2026-11-11-part5-team-server-design.md`.

| File | Goes to |
|---|---|
| `coneRules.py`, `coneRoutes.py`, `coneAdminRoutes.py` | `/database/API/util/` |
| `coneAdminConfig.json` (from the example; never committed) | `/database/API/util/`, `chmod 600` |
| `coneSmoke.py` | `/database/API/util/` (only for the smoke test; harmless if left) |
| `schema.sql` | run once by the owner (it replaces the prototype's `tracks` table) |
| `coneAdmin.py`, `liveCheck.py` | stay on the PC |

Track files live in `/pool/appFiles/conestructor/teams/<teamId>/<trackId>.cone` and `.jpg`.

Tests (on the PC): `cd server`, `py -3 -m venv .venv`, `.venv\Scripts\python.exe -m pip install -r requirements-dev.txt`,
then `.venv\Scripts\python.exe -m pytest -q`.

## The admin script

`coneAdmin.py` runs on the PC on the LAN. Set `CONE_ADMIN_URL` to `http://<LAN address>:5000` and `CONE_ADMIN_TOKEN` to
the token in `coneAdminConfig.json`, or write both to `server/coneAdmin.local.json` (`{"url": ..., "token": ...}`,
gitignored).

```
py -3 server\coneAdmin.py make-team "Our team"     prints the team code once: paste it into Preferences > Team
py -3 server\coneAdmin.py new-key 1                replaces the key; codes made before stop working
py -3 server\coneAdmin.py teams
py -3 server\coneAdmin.py tracks [--team 1]
py -3 server\coneAdmin.py delete 12 [--yes]
```

A team code is like a password: whoever holds it can reach the server and the team's tracks. Share it only inside the
team.

## Rollout

Each step waits for the owner's go-ahead at the time. "Claude" steps run from the PC over SSH; "owner" steps are typed
by the owner on the server (every `sudo`).

1. **Check (Claude, read only).** The deployed `util/coneRoutes.py` matches the repo's old one
   (`git show <the commit before part 5>:coneRoutes.py | md5sum` against `md5sum` on the server; `diff --strip-trailing-cr`
   if only line endings differ). `DBUtils.py` maps `"cone"` to `coneDB` (look for the mapping only; never copy the
   file). `Caduceus.py` sets no `MAX_CONTENT_LENGTH` below 41 MB. The nginx site file's existing blocks: their `listen`
   port and `proxy_pass` upstream.
2. **Smoke test.**
   - Owner: `sudo mysql -e "CREATE DATABASE cone_smoke CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"`,
     `sudo mysql -e "GRANT ALL ON cone_smoke.* TO '<the API user>'@'localhost'"`.
   - Claude: back up `util/coneRoutes.py` as `util/coneRoutes.py.bak-<date>`. From the branch, make a tar of the server
     files with LF endings and unpack it on the server:
     `git -c core.autocrlf=false archive -o cone-part5.tar HEAD:server coneRules.py coneRoutes.py coneAdminRoutes.py coneSmoke.py schema.sql`,
     copy it over, `mkdir -p /tmp/cone-part5 && tar -xf cone-part5.tar -C /tmp/cone-part5`, copy the four `.py` files
     into `/database/API/util/`, and `/database/venv/bin/python -m py_compile` each. Caduceus keeps running the old
     routes until it restarts.
   - Owner: `sudo mysql cone_smoke < /tmp/cone-part5/schema.sql`.
   - Claude: `cd /database/API && /database/venv/bin/python -m util.coneSmoke --database cone_smoke`. Every line
     `PASS`.
   - Owner: `sudo mysql -e "DROP DATABASE cone_smoke"`, whether it passed or not.
3. **Cut-over (owner).**
   - `sudo mysql coneDB < /tmp/cone-part5/schema.sql` (the old `tracks` table goes).
   - `rm -r /pool/appFiles/conestructor/tracks` (the three prototype tracks).
   - `mkdir -p /pool/appFiles/conestructor/teams` (owned by the user Caduceus runs as).
   - `coneAdminConfig.json` in `/database/API/util/` from the example, with a new long random token, the LAN base and
     the public base; `chmod 600`.
4. **Register (Claude).** Back up `Caduceus.py` as `Caduceus.py.bak-<date>`. The existing line
   `app.register_blueprint(coneBP,url_prefix="/api/cone")` stays. Add, beside the other admin blocks:

   ```python
   # Conestructor's admin routes (Code-Development/Conestructor server/): LAN only, with their own token. The team API
   # (coneBP, above) is the only prefix the public subdomain passes.
   try:
       from util.coneAdminRoutes import coneAdminBP
       app.register_blueprint(coneAdminBP, url_prefix="/api/cone-admin")
   except Exception as e:
       print(f"cone admin routes not loaded: {e}")
   ```

   `cd /database/API && /database/venv/bin/python -m py_compile Caduceus.py`. Owner: `sudo systemctl restart Caduceus.service`;
   `journalctl -u Caduceus.service -n 100 --no-pager | grep -i "cone admin routes not loaded"` must print nothing.
   LAN check: `/api/cone/ping` answers ok; `/api/cone/team` without a key answers 401.
5. **nginx (Claude).** Back up the site file, add this block beside the others (its `listen` and `proxy_pass` lines the
   same as the existing blocks'), `sudo nginx -t`, `sudo systemctl reload nginx`. Owner: make sure the subdomain is
   routed through the tunnel to nginx.

   ```nginx
   # Conestructor's team API: only its own prefix through the tunnel. The admin prefix (/api/cone-admin/) never
   # matches this location and stays LAN only. An upload is a .cone of up to 40 MB plus its thumbnail.
   server {
       listen 80;
       server_name <public host>;
       location /api/cone/ {
           client_max_body_size 41m;
           add_header Cache-Control "private" always;
           proxy_pass http://127.0.0.1:5000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
       location / {
           return 404;
       }
   }
   ```
6. **The team (owner).** `py -3 server\coneAdmin.py make-team "<team name>"`; paste the code into Preferences › Team.
7. **Live check (Claude).** With `CONE_CHECK_CODE` and `CONE_ADMIN_TOKEN` set: `py -3 server\liveCheck.py`. Every line
   `PASS`, on the LAN, on the public address and the cleanup. On each other public hostname in the nginx site file,
   `/api/cone/ping` must answer 404.
````

- [ ] **Step 6: Run the tests to see them pass**

Run (from `server\`): `.venv\Scripts\python.exe -m pytest -q`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add server/coneSmoke.py server/liveCheck.py server/README.md server/tests/conftest.py server/tests/test_smoke.py server/tests/test_livecheck.py
git commit -m "Server: smoke test on a scratch database, live check for the rollout, README with what goes where and the rollout steps" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 6: Version 0.6.0, Qt Network, the team code setting, `TrackFile` bytes, minor 4

**Files:**
- Modify: `app/CMakeLists.txt` (version, Network)
- Modify: `app/services/Settings.h`, `app/services/Settings.cpp`
- Modify: `app/services/TrackFile.h`, `app/services/TrackFile.cpp`
- Modify: `app/tests/tst_qmlload.cpp` (five window titles `0.5` → `0.6`)
- Test: `app/tests/tst_settings.cpp`, `app/tests/tst_trackfile.cpp`

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `Settings.teamCode` (QString property, `teamCodeChanged`), saved as `teamCode` in `Conestructor.ini`; `setTeamCode` drops surrounding spaces.
  - `static QByteArray TrackFile::documentBytes(const QString &documentText, const PhotoStore *photos, int photoRef)`: the whole file as `saveTo` writes it; empty when the text is not a JSON object.
  - `static QVariantMap TrackFile::openBytes(const QByteArray &bytes, PhotoStore *photos)`: as `openFrom`, from a file's bytes (`{ text, photoRef, photoError }` or `{ error: "notJson" }`).

- [ ] **Step 1: Write the failing tests**

Add to `app/tests/tst_settings.cpp`, before `recentFilesAreNewestFirstAndAtMostEight`:

```cpp
    void theTeamCodeSurvivesARestart()
    {
        {
            Settings s;
            QCOMPARE(s.teamCode(), QString());
            QSignalSpy changed(&s, &Settings::teamCodeChanged);
            s.setTeamCode(QStringLiteral("  CONE1.abc \n"));
            QCOMPARE(s.teamCode(), QStringLiteral("CONE1.abc"));
            QCOMPARE(changed.count(), 1);
            s.setTeamCode(QStringLiteral("CONE1.abc"));
            QCOMPARE(changed.count(), 1);
        }
        Settings again;
        QCOMPARE(again.teamCode(), QStringLiteral("CONE1.abc"));
        QCOMPARE(ini().value("teamCode").toString(), QStringLiteral("CONE1.abc"));
    }

    // Part 4's minor 4: a hand-edited number is checked and kept within its limits before it becomes a whole number.
    void hugeAndNonFiniteNumbersInTheFileAreSafe()
    {
        {
            QSettings settings = ini();
            settings.setValue("conesOwned", "1e20");
            settings.setValue("carLength", "nan");
            settings.setValue("carWidth", "1e300");
            settings.sync();
        }
        Settings s;
        QCOMPARE(s.conesOwned(), Settings::maxConesOwned);
        QCOMPARE(s.carLength(), Settings::defaultCarLength);
        QCOMPARE(s.carWidth(), Settings::maxCarSize);
        {
            QSettings settings = ini();
            settings.setValue("conesOwned", "inf");
            settings.setValue("carLength", "-inf");
            settings.sync();
        }
        Settings again;
        QCOMPARE(again.conesOwned(), 0);
        QCOMPARE(again.carLength(), Settings::defaultCarLength);
    }
```

Add to `app/tests/tst_trackfile.cpp`, after `withoutAPhotoTheFieldIsNull`:

```cpp
    // Part 5: an upload sends exactly what Save writes, and a download opens as a file from disk does.
    void theFilesBytesAreWhatSaveWrites()
    {
        PhotoStore photos(nullptr);
        const int ref = photos.add(png(QSize(32, 24)));
        const QString path = dir.filePath(QStringLiteral("Bytes.cone"));
        QCOMPARE(TrackFile::saveTo(path, document(), &photos, ref), QString());
        QCOMPARE(TrackFile::documentBytes(document(), &photos, ref), read(path));
        QCOMPARE(TrackFile::saveTo(path, document(), nullptr, -1), QString());
        QCOMPARE(TrackFile::documentBytes(document(), nullptr, -1), read(path));
        QVERIFY(TrackFile::documentBytes(QStringLiteral("not an object"), &photos, ref).isEmpty());
    }

    void bytesOpenAsAFileDoes()
    {
        PhotoStore source(nullptr);
        const QByteArray picture = png(QSize(32, 24));
        const QByteArray bytes = TrackFile::documentBytes(document(), &source, source.add(picture));
        PhotoStore photos(nullptr);
        const QVariantMap opened = TrackFile::openBytes(bytes, &photos);
        QVERIFY(!opened.contains(QStringLiteral("error")));
        QCOMPARE(photos.bytes(opened.value(QStringLiteral("photoRef")).toInt()), picture);
        const QJsonObject text = QJsonDocument::fromJson(opened.value(QStringLiteral("text")).toString().toUtf8()).object();
        QCOMPARE(text.value(QStringLiteral("name")).toString(), QStringLiteral("Lot"));
        QVERIFY(!text.contains(QStringLiteral("photo")));
        QCOMPARE(TrackFile::openBytes("hello", &photos).value(QStringLiteral("error")).toString(), QStringLiteral("notJson"));
    }
```

- [ ] **Step 2: Build to see them fail**

Run: `powershell -NoProfile -File app\tests\build.ps1`
Expected: FAIL to compile — `Settings` has no `teamCode`, `TrackFile` has no `documentBytes`/`openBytes`.

- [ ] **Step 3: Version 0.6.0 and Qt Network**

In `app/CMakeLists.txt`:
- `project(Conestructor VERSION 0.5.0 LANGUAGES CXX)` → `project(Conestructor VERSION 0.6.0 LANGUAGES CXX)`
- `find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Svg)` → `find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Svg Network)`
- `target_link_libraries(conestructor_core PUBLIC Qt6::Quick Qt6::QuickControls2)` → `target_link_libraries(conestructor_core PUBLIC Qt6::Quick Qt6::QuickControls2 Qt6::Network)`

In `app/tests/tst_qmlload.cpp`, replace every `Conestructor 0.5 —` with `Conestructor 0.6 —` (five places: `mainOpensWithTheTitle`, `savingAndOpeningATrack`, `unsavedChangesAskFirst`, `aFileNamedAtStartOpens`, `aBackupIsOfferedAtStart`).

- [ ] **Step 4: The team code setting and minor 4**

In `app/services/Settings.h`:
- In the class comment, change `part 4 adds the cones the team owns and the car outline's size and picture.` to `part 4 adds the cones the team owns and the car outline's size and picture; part 5 adds the team code.`
- Add after the `carImage` property line:

```cpp
    Q_PROPERTY(QString teamCode READ teamCode WRITE setTeamCode NOTIFY teamCodeChanged)
```

- Add after `Q_INVOKABLE bool carImageFound() const;`:

```cpp

    // The team code (Preferences › Team): the team server's addresses and the team's key, as the team's admin gave it;
    // "" for none. Kept without the spaces around it; TeamServer reads it.
    QString teamCode() const { return m_teamCode; }
    void setTeamCode(const QString &code);
```

- Add `void teamCodeChanged();` after `void carImageChanged();`, and `QString m_teamCode;` after `QString m_carImage;`.

In `app/services/Settings.cpp`:
- Add `#include <cmath>` after `#include <QSettings>`.
- Replace `storedNumber` with:

```cpp
// A finite number from the ini, or `fallback` when the stored text is not one (or is nan or infinite).
double storedNumber(const QSettings &ini, const QString &key, double fallback)
{
    bool ok = false;
    const double value = ini.value(key).toDouble(&ok);
    return ok && std::isfinite(value) ? value : fallback;
}
```

- In the constructor, replace the `m_conesOwned` line with (kept within limits as a double first: converting 1e20 to int is undefined behaviour):

```cpp
    m_conesOwned = int(qBound(0.0, storedNumber(ini, QStringLiteral("conesOwned"), 0), double(maxConesOwned)));
```

  and add after the `m_carImage` line:

```cpp
    m_teamCode = ini.value(QStringLiteral("teamCode")).toString().trimmed();
```

- Add after `carImageFound()`:

```cpp
void Settings::setTeamCode(const QString &code)
{
    const QString trimmed = code.trimmed();
    if (trimmed == m_teamCode)
        return;
    m_teamCode = trimmed;
    emit teamCodeChanged();
    save();
}
```

- In `save()`, add after the `carImage` line: `ini.setValue(QStringLiteral("teamCode"), m_teamCode);`

- [ ] **Step 5: `TrackFile` bytes**

In `app/services/TrackFile.h`, add to the end of the class comment's first sentence: ` The same bytes are what File › Upload to team sends, and a track downloaded from the team opens from its bytes as a file does.` Then add after `static QVariantMap openFrom(const QString &path, PhotoStore *photos);`:

```cpp
    // The whole file as saveTo writes it: the document's text with the photo added last; empty when the text is not a
    // JSON object.
    static QByteArray documentBytes(const QString &documentText, const PhotoStore *photos, int photoRef);
    // As openFrom, from a file's bytes (a track downloaded from the team).
    static QVariantMap openBytes(const QByteArray &bytes, PhotoStore *photos);
```

In `app/services/TrackFile.cpp`, replace `saveTo` and `openFrom` with:

```cpp
QByteArray TrackFile::documentBytes(const QString &documentText, const PhotoStore *photos, int photoRef)
{
    QByteArray text = documentText.toUtf8().trimmed();
    if (!text.startsWith('{') || !text.endsWith('}'))
        return {};
    text.chop(1);
    while (!text.isEmpty() && QChar::fromLatin1(text.back()).isSpace())
        text.chop(1);

    QByteArray photo = "null";
    if (photos && photoRef >= 0 && photos->has(photoRef)) {
        const QSize size = photos->size(photoRef);
        photo = "{\n    \"mediaType\": \"" + photos->mediaType(photoRef).toUtf8() + "\",\n    \"width\": "
                + QByteArray::number(size.width()) + ",\n    \"height\": " + QByteArray::number(size.height())
                + ",\n    \"data\": \"" + photos->bytes(photoRef).toBase64() + "\"\n  }";
    }
    text += ",\n  \"photo\": " + photo + "\n}\n";
    return text;
}

QString TrackFile::saveTo(const QString &path, const QString &documentText, const PhotoStore *photos, int photoRef)
{
    const QByteArray text = documentBytes(documentText, photos, photoRef);
    if (text.isEmpty())
        return couldNotWrite(path, tr("the track could not be written out"));
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return couldNotWrite(path, file.errorString());
    file.write(text);
    if (!file.commit())
        return couldNotWrite(path, file.errorString());
    return {};
}

QVariantMap TrackFile::openFrom(const QString &path, PhotoStore *photos)
{
    QFile file(path);
    if (!file.exists())
        return { { QStringLiteral("error"), QStringLiteral("missing") },
                 { QStringLiteral("message"), tr("%1 isn't there any more.").arg(QDir::toNativeSeparators(path)) } };
    if (!file.open(QIODevice::ReadOnly))
        return { { QStringLiteral("error"), QStringLiteral("unreadable") },
                 { QStringLiteral("message"),
                   tr("Could not read %1: %2").arg(QDir::toNativeSeparators(path), file.errorString()) } };
    return openBytes(file.readAll(), photos);
}

QVariantMap TrackFile::openBytes(const QByteArray &bytes, PhotoStore *photos)
{
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject())
        return { { QStringLiteral("error"), QStringLiteral("notJson") } };

    QJsonObject object = doc.object();
    int ref = -1;
    bool photoError = false;
    const QJsonValue photo = object.value(QStringLiteral("photo"));
    if (photo.isObject()) {
        const auto decoded = QByteArray::fromBase64Encoding(
            photo.toObject().value(QStringLiteral("data")).toString().toLatin1(),
            QByteArray::AbortOnBase64DecodingErrors);
        if (decoded && photos)
            ref = photos->add(*decoded);
        photoError = ref < 0;
    } else if (!photo.isNull() && !photo.isUndefined()) {
        photoError = true;
    }
    object.remove(QStringLiteral("photo"));
    return { { QStringLiteral("text"), QString::fromUtf8(QJsonDocument(object).toJson(QJsonDocument::Compact)) },
             { QStringLiteral("photoRef"), ref }, { QStringLiteral("photoError"), photoError } };
}
```

- [ ] **Step 6: Build and run the tests**

Run: `powershell -NoProfile -File app\tests\build.ps1`, then `powershell -NoProfile -File app\tests\run.ps1`
Expected: build succeeds; `ctest: passed`; `qml: 382 passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git add app/CMakeLists.txt app/services/Settings.h app/services/Settings.cpp app/services/TrackFile.h app/services/TrackFile.cpp app/tests/tst_settings.cpp app/tests/tst_trackfile.cpp app/tests/tst_qmlload.cpp
git commit -m "Version 0.6.0 with Qt Network; Settings keeps the team code; TrackFile builds a file's bytes and opens bytes; minor 4: ini numbers checked before they become whole numbers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: `TeamServer`: the team code, finding the server, the requests and the thumbnail

**Files:**
- Create: `app/services/TeamServer.h`, `app/services/TeamServer.cpp`
- Create: `app/tests/fakehttp.h`, `app/tests/tst_teamserver.cpp`
- Modify: `app/CMakeLists.txt` (`services/TeamServer.h services/TeamServer.cpp` in `SOURCES`)
- Modify: `app/tests/CMakeLists.txt` (`tst_teamserver`; `fakehttp.h` in `tst_qmlload`'s sources)

**Interfaces:**
- Consumes: `TrackFile::documentBytes`, `TrackFile::openBytes` (Task 6); `PhotoStore::has/bytes/add`.
- Produces (QML singleton `TeamServer`):
  - Properties: `code` (QString, read/write; `Main.qml` binds it to `Settings.teamCode` in Task 8), `hasCode` (bool), `teamName` (QString), `busy` (bool: an upload or download is under way).
  - `Q_INVOKABLE bool isCode(QString)`, `Q_INVOKABLE QUrl makeThumbnail(int photoRef, double mpp, QVariantList cones)`, `Q_INVOKABLE void check()`, `listTracks()`, `fetchThumbnail(int id)`, `download(int id)`, `upload(QString documentText, int photoRef, QUrl thumbnail)`, `cancel()`.
  - Signals: `checked(bool ok, QString message)`, `tracksListed(bool ok, QVariantList tracks, QString error)` (each track `{ id, name, cones, uploaded, uploadedText, bytes }`), `thumbnailReady(int id, QUrl url)`, `downloadProgress(qint64, qint64)`, `downloaded(bool ok, QVariantMap read, QString error)`, `uploadProgress(qint64, qint64)`, `uploaded(bool ok, QString error)`. A cancelled transfer answers `ok` false with an empty error.
  - Static: `parseCode(QString) -> TeamServer::Code { team, lan, publicUrl, key, valid }`, `drawThumbnail(QImage photo, double mpp, QVariantList cones) -> QImage`, `jpeg(QImage) -> QByteArray`; constants `maxFile`, `maxThumbnail`, `thumbnailSide`, `probeTimeout`, `requestTimeout`, `transferTimeout`; test hook `setPhotos(PhotoStore *)`.
  - Tests: `fakehttp.h` gives `FakeHttp` (`base()`, `reply()`, `replyJson()`, `requests`, `count(path)`, `silent`, `static closedPort()`), `FakeRequest`, `FakeReply`, and `teamCodeFor(team, lan, publicUrl, key = "test-key")`.

- [ ] **Step 1: The test HTTP server**

Create `app/tests/fakehttp.h`:

```cpp
#pragma once
// A small HTTP/1.1 server for the tests (this Qt has no Qt HttpServer): it answers canned replies by method and path,
// records every request it was sent (method, path, headers in lower case, body), and can stay silent to look like a
// server that never answers. One request per connection: every answer says "Connection: close".
#include <QByteArray>
#include <QHash>
#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonObject>
#include <QList>
#include <QObject>
#include <QString>
#include <QTcpServer>
#include <QTcpSocket>
#include <QUrl>

struct FakeRequest
{
    QByteArray method;
    QByteArray path;
    QHash<QByteArray, QByteArray> headers;
    QByteArray body;
};

struct FakeReply
{
    int status = 200;
    QByteArray type = "application/json";
    QByteArray body;
};

class FakeHttp : public QObject
{
public:
    explicit FakeHttp(QObject *parent = nullptr) : QObject(parent)
    {
        connect(&m_server, &QTcpServer::newConnection, this, [this]() {
            while (QTcpSocket *socket = m_server.nextPendingConnection()) {
                connect(socket, &QTcpSocket::readyRead, this, [this, socket]() { read(socket); });
                connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
            }
        });
        m_server.listen(QHostAddress::LocalHost);
    }

    QUrl base() const { return QUrl(QStringLiteral("http://127.0.0.1:%1").arg(m_server.serverPort())); }

    void reply(const QByteArray &method, const QByteArray &path, const FakeReply &answer)
    {
        m_replies.insert(method + ' ' + path, answer);
    }
    void replyJson(const QByteArray &method, const QByteArray &path, int status, const QByteArray &json)
    {
        reply(method, path, FakeReply{ status, "application/json", json });
    }

    // How many requests asked for `path`.
    int count(const QByteArray &path) const
    {
        int n = 0;
        for (const FakeRequest &r : requests)
            n += r.path == path ? 1 : 0;
        return n;
    }

    // An address nothing listens on: connecting there is refused.
    static QUrl closedPort()
    {
        QTcpServer probe;
        probe.listen(QHostAddress::LocalHost);
        const quint16 port = probe.serverPort();
        probe.close();
        return QUrl(QStringLiteral("http://127.0.0.1:%1").arg(port));
    }

    QList<FakeRequest> requests;
    bool silent = false;    // read requests but never answer

private:
    void read(QTcpSocket *socket)
    {
        m_buffers[socket] += socket->readAll();
        const QByteArray buffer = m_buffers.value(socket);
        const int end = int(buffer.indexOf("\r\n\r\n"));
        if (end < 0)
            return;
        FakeRequest request;
        const QList<QByteArray> lines = buffer.left(end).split('\n');
        const QList<QByteArray> first = lines.value(0).trimmed().split(' ');
        request.method = first.value(0);
        request.path = first.value(1);
        for (int i = 1; i < lines.size(); ++i) {
            const int colon = int(lines[i].indexOf(':'));
            if (colon > 0)
                request.headers.insert(lines[i].left(colon).trimmed().toLower(), lines[i].mid(colon + 1).trimmed());
        }
        const int length = request.headers.value("content-length").toInt();
        if (buffer.size() < end + 4 + length)
            return;                                   // the body is still coming
        request.body = buffer.mid(end + 4, length);
        m_buffers.remove(socket);
        requests << request;
        if (silent)
            return;
        const FakeReply answer = m_replies.value(request.method + ' ' + request.path,
                                                 FakeReply{ 404, "application/json",
                                                            R"({"status": "error", "message": "no such route"})" });
        socket->write("HTTP/1.1 " + QByteArray::number(answer.status) + " Fake\r\nContent-Type: " + answer.type
                      + "\r\nContent-Length: " + QByteArray::number(answer.body.size())
                      + "\r\nConnection: close\r\n\r\n" + answer.body);
        socket->disconnectFromHost();
    }

    QTcpServer m_server;
    QHash<QTcpSocket *, QByteArray> m_buffers;
    QHash<QByteArray, FakeReply> m_replies;
};

// A team code as the server makes it (server/coneRules.py teamCode): CONE1. and base64url JSON without padding. An
// invalid URL leaves that address out.
inline QString teamCodeFor(const QString &team, const QUrl &lan, const QUrl &publicUrl,
                           const QString &key = QStringLiteral("test-key"))
{
    QJsonObject fields{ { QStringLiteral("v"), 1 }, { QStringLiteral("team"), team }, { QStringLiteral("key"), key } };
    if (lan.isValid())
        fields.insert(QStringLiteral("lan"), lan.toString());
    if (publicUrl.isValid())
        fields.insert(QStringLiteral("public"), publicUrl.toString());
    return QStringLiteral("CONE1.")
           + QString::fromLatin1(QJsonDocument(fields).toJson(QJsonDocument::Compact)
                                     .toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}
```

In `app/tests/CMakeLists.txt`:
- `    SOURCES tst_qmlload.cpp` → `    SOURCES tst_qmlload.cpp fakehttp.h`
- add at the end: `conestructor_test(tst_teamserver SOURCES tst_teamserver.cpp fakehttp.h LIBS conestructor_core)`

In `app/CMakeLists.txt`, add `        services/TeamServer.h services/TeamServer.cpp` to `SOURCES` after the `PhotoStore` line.

- [ ] **Step 2: Write the failing tests**

Create `app/tests/tst_teamserver.cpp`:

```cpp
#include <QBuffer>
#include <QColor>
#include <QDateTime>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QRandomGenerator>
#include <QSignalSpy>
#include <QTest>
#include <memory>

#include "fakehttp.h"
#include "services/PhotoStore.h"
#include "services/TeamServer.h"
#include "services/TrackFile.h"

// The format both sides agree on: server/tests/test_rules.py checks coneRules.teamCode makes exactly this.
static const QString fixedCode = QStringLiteral(
    "CONE1.eyJ2IjoxLCJ0ZWFtIjoiT3VyIHRlYW0iLCJsYW4iOiJodHRwOi8vbGFuLmV4YW1wbGU6NTAwMCIsInB1YmxpYyI6Imh0dHBzOi8v"
    "cHVibGljLmV4YW1wbGUiLCJrZXkiOiJra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2trIn0");
// {"v":1,"team":"Équipe","public":"https://public.example","key":"abc"}
static const QString publicOnlyCode =
    QStringLiteral("CONE1.eyJ2IjoxLCJ0ZWFtIjoiw4lxdWlwZSIsInB1YmxpYyI6Imh0dHBzOi8vcHVibGljLmV4YW1wbGUiLCJrZXkiOiJhYmMifQ");
// A refused connection on Windows can take a couple of seconds, and the Silent power plan stretches everything.
static constexpr int slow = 20000;

class TestTeamServer : public QObject
{
    Q_OBJECT

    static QByteArray png(QSize size)
    {
        QImage image(size, QImage::Format_RGB32);
        image.fill(QColor(30, 160, 60));
        QByteArray bytes;
        QBuffer buffer(&bytes);
        buffer.open(QIODevice::WriteOnly);
        image.save(&buffer, "PNG");
        return bytes;
    }

    static QString document()
    {
        return QStringLiteral("{\n  \"format\": \"conestructor-track\",\n  \"version\": 1,\n  \"name\": \"Lot\",\n"
                              "  \"cones\": []\n}");
    }

    static QVariantList twoCones()
    {
        return { QVariantMap{ { "x", 10.0 }, { "y", 10.0 }, { "type", "standing" } },
                 QVariantMap{ { "x", 30.0 }, { "y", 20.0 }, { "type", "leaning" } } };
    }

    static QByteArray fileBytes(const QString &path)
    {
        QFile file(path);
        file.open(QIODevice::ReadOnly);
        return file.readAll();
    }

private slots:
    // ---- The team code ----

    void codesAreRead_data()
    {
        QTest::addColumn<QString>("text");
        QTest::addColumn<QString>("team");
        QTest::addColumn<QUrl>("lan");
        QTest::addColumn<QUrl>("publicUrl");
        QTest::addColumn<QString>("key");
        QTest::newRow("both addresses") << fixedCode << QStringLiteral("Our team")
                                        << QUrl(QStringLiteral("http://lan.example:5000"))
                                        << QUrl(QStringLiteral("https://public.example")) << QString(43, QLatin1Char('k'));
        // Review focus 1: pasted from a chat app with spaces and line breaks around it.
        QTest::newRow("padded") << QStringLiteral("  \n") + fixedCode + QStringLiteral("\r\n ") << QStringLiteral("Our team")
                                << QUrl(QStringLiteral("http://lan.example:5000"))
                                << QUrl(QStringLiteral("https://public.example")) << QString(43, QLatin1Char('k'));
        QTest::newRow("public only") << publicOnlyCode << QStringLiteral("Équipe") << QUrl()
                                     << QUrl(QStringLiteral("https://public.example")) << QStringLiteral("abc");
    }

    void codesAreRead()
    {
        QFETCH(QString, text);
        const TeamServer::Code code = TeamServer::parseCode(text);
        QVERIFY(code.valid);
        QTEST(code.team, "team");
        QTEST(code.lan, "lan");
        QTEST(code.publicUrl, "publicUrl");
        QTEST(code.key, "key");
        TeamServer team;
        QVERIFY(team.isCode(text));
    }

    void notCodes_data()
    {
        QTest::addColumn<QString>("text");
        QTest::newRow("empty") << QString();
        QTest::newRow("other prefix") << QStringLiteral("CONE2.e30");
        QTest::newRow("not base64") << QStringLiteral("CONE1.!!!");
        QTest::newRow("empty object") << QStringLiteral("CONE1.e30");
        QTest::newRow("a list") << QStringLiteral("CONE1.W10");
        QTest::newRow("no address") << QStringLiteral("CONE1.eyJ2IjoxLCJrZXkiOiJhIn0");
        QTest::newRow("version 2") << QStringLiteral("CONE1.eyJ2IjoyLCJwdWJsaWMiOiJ4Iiwia2V5IjoiYSJ9");
        QTest::newRow("ftp only") << teamCodeFor(QStringLiteral("x"), QUrl(QStringLiteral("ftp://lan.example")), QUrl());
        QTest::newRow("empty key") << teamCodeFor(QStringLiteral("x"), QUrl(),
                                                  QUrl(QStringLiteral("https://public.example")), QString());
        QTest::newRow("cut short") << fixedCode.left(fixedCode.size() - 5);
    }

    void notCodes()
    {
        QFETCH(QString, text);
        QVERIFY(!TeamServer::parseCode(text).valid);
    }

    void aCodeIsTakenWithoutItsSpaces()
    {
        TeamServer team;
        QSignalSpy changed(&team, &TeamServer::codeChanged);
        team.setCode(QStringLiteral("  ") + fixedCode + QStringLiteral("\n"));
        QCOMPARE(team.code(), fixedCode);
        QVERIFY(team.hasCode());
        QCOMPARE(team.teamName(), QStringLiteral("Our team"));
        team.setCode(fixedCode);
        QCOMPARE(changed.count(), 1);
        team.setCode(QStringLiteral("nonsense"));
        QVERIFY(!team.hasCode());
    }

    // ---- The thumbnail ----

    void theThumbnailShowsTheConesOnThePhoto()
    {
        QImage photo(1000, 800, QImage::Format_RGB32);
        photo.fill(QColor(30, 160, 60));
        // 20 photo pixels a metre: the cones at (200, 200) and (600, 400) px span 400 × 200 px; with 10% each side and
        // at least 20 m (400 px) across, the area is 480 × 400 px from (160, 100), shown at 400 / 480.
        const QImage thumb = TeamServer::drawThumbnail(photo, 0.05, twoCones());
        QCOMPARE(thumb.size(), QSize(400, 333));
        const QColor standing(thumb.pixel(33, 83));
        const QColor leaning(thumb.pixel(366, 250));
        const QColor corner(thumb.pixel(3, 3));
        QVERIFY2(standing.red() > 200 && standing.green() > 100 && standing.green() < 180 && standing.blue() < 80,
                 qPrintable(standing.name()));
        QVERIFY2(leaning.red() > 200 && leaning.green() > 190 && leaning.blue() < 80, qPrintable(leaning.name()));
        QVERIFY2(corner.green() > 140 && corner.red() < 60, qPrintable(corner.name()));

        const QImage dark = TeamServer::drawThumbnail(QImage(), 0.05, twoCones());
        QCOMPARE(QColor(dark.pixel(3, 3)), QColor(0x1b, 0x1b, 0x1b));
    }

    void aSmallCourseIsShownAtLeastTwentyMetresAcross()
    {
        const QImage thumb = TeamServer::drawThumbnail(
            QImage(), 0.05, { QVariantMap{ { "x", 5.0 }, { "y", 5.0 }, { "type", "standing" } } });
        QCOMPARE(thumb.size(), QSize(400, 400));
        QVERIFY(QColor(thumb.pixel(200, 200)).red() > 200);
    }

    void theJpegFits()
    {
        QImage noise(400, 400, QImage::Format_RGB32);
        for (int y = 0; y < noise.height(); ++y)
            for (int x = 0; x < noise.width(); ++x)
                noise.setPixel(x, y, QRandomGenerator::global()->generate() | 0xff000000u);
        const QByteArray bytes = TeamServer::jpeg(noise);
        QVERIFY(!bytes.isEmpty());
        QVERIFY(bytes.size() <= TeamServer::maxThumbnail);
        QVERIFY(bytes.startsWith("\xff\xd8"));
    }

    void makeThumbnailWritesAJpegFile()
    {
        PhotoStore photos(nullptr);
        TeamServer team;
        team.setPhotos(&photos);
        const QUrl url = team.makeThumbnail(photos.add(png(QSize(1000, 800))), 0.05, twoCones());
        QVERIFY(url.isLocalFile());
        const QImage written(url.toLocalFile());
        QCOMPARE(written.size(), QSize(400, 333));
        QVERIFY(QFileInfo(url.toLocalFile()).size() <= TeamServer::maxThumbnail);
        QVERIFY(team.makeThumbnail(-1, 0.05, twoCones()) != url);       // a new file each time
    }

    // ---- Finding the server ----

    void theLanIsUsedWhenItAnswers()
    {
        FakeHttp lan, pub;
        lan.replyJson("GET", "/api/cone/ping", 200, R"({"status": "ok"})");
        lan.replyJson("GET", "/api/cone/team", 200, R"({"status": "ok", "name": "Our team"})");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), lan.base(), pub.base()));
        QSignalSpy checked(&team, &TeamServer::checked);
        team.check();
        QTRY_COMPARE(checked.count(), 1);
        QCOMPARE(checked.at(0).at(0).toBool(), true);
        QCOMPARE(checked.at(0).at(1).toString(), QStringLiteral("Connected to Our team (on the LAN)"));
        QCOMPARE(pub.requests.size(), 0);
        QCOMPARE(lan.requests.last().headers.value("x-team-key"), QByteArray("test-key"));
        QVERIFY(lan.requests.last().headers.value("user-agent").startsWith("Conestructor/"));
    }

    void thePublicAddressIsUsedWhenTheLanIsRefused()
    {
        FakeHttp pub;
        pub.replyJson("GET", "/api/cone/team", 200, R"({"status": "ok", "name": "Our team"})");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), FakeHttp::closedPort(), pub.base()));
        QSignalSpy checked(&team, &TeamServer::checked);
        team.check();
        QTRY_COMPARE_WITH_TIMEOUT(checked.count(), 1, slow);
        QCOMPARE(checked.at(0).at(1).toString(), QStringLiteral("Connected to Our team (over the internet)"));
    }

    void thePublicAddressIsUsedWhenTheLanIsSilent()
    {
        FakeHttp lan, pub;
        lan.silent = true;
        pub.replyJson("GET", "/api/cone/team", 200, R"({"status": "ok", "name": "Our team"})");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), lan.base(), pub.base()));
        QSignalSpy checked(&team, &TeamServer::checked);
        QElapsedTimer clock;
        clock.start();
        team.check();
        QTRY_COMPARE_WITH_TIMEOUT(checked.count(), 1, slow);
        QVERIFY(clock.elapsed() >= TeamServer::probeTimeout - 100);
        QCOMPARE(checked.at(0).at(1).toString(), QStringLiteral("Connected to Our team (over the internet)"));
    }

    // Review focus 2: something else answering at the LAN address is not the team server.
    void theLanMustAnswerLikeTheServer()
    {
        FakeHttp pub;
        pub.replyJson("GET", "/api/cone/team", 200, R"({"status": "ok", "name": "Our team"})");
        const QList<FakeReply> others{ FakeReply{ 404, "text/html", "<html>not here</html>" },
                                       FakeReply{ 200, "text/html", "<html>a router's page</html>" } };
        for (const FakeReply &other : others) {
            FakeHttp lan;
            lan.reply("GET", "/api/cone/ping", other);
            TeamServer team;
            team.setCode(teamCodeFor(QStringLiteral("Our team"), lan.base(), pub.base()));
            QSignalSpy checked(&team, &TeamServer::checked);
            team.check();
            QTRY_COMPARE_WITH_TIMEOUT(checked.count(), 1, slow);
            QCOMPARE(checked.at(0).at(1).toString(), QStringLiteral("Connected to Our team (over the internet)"));
        }
    }

    void theAnswerIsRemembered()
    {
        FakeHttp lan;
        lan.replyJson("GET", "/api/cone/ping", 200, R"({"status": "ok"})");
        lan.replyJson("GET", "/api/cone/tracks", 200, R"({"status": "ok", "tracks": []})");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), lan.base(), QUrl()));
        QSignalSpy listed(&team, &TeamServer::tracksListed);
        team.listTracks();
        QTRY_COMPARE(listed.count(), 1);
        team.listTracks();
        QTRY_COMPARE(listed.count(), 2);
        QCOMPARE(lan.count("/api/cone/ping"), 1);
        QCOMPARE(lan.count("/api/cone/tracks"), 2);
    }

    void aLostConnectionFindsTheServerAgain()
    {
        auto lan = std::make_unique<FakeHttp>();
        lan->replyJson("GET", "/api/cone/ping", 200, R"({"status": "ok"})");
        lan->replyJson("GET", "/api/cone/tracks", 200, R"({"status": "ok", "tracks": []})");
        FakeHttp pub;
        pub.replyJson("GET", "/api/cone/tracks", 200, R"({"status": "ok", "tracks": []})");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), lan->base(), pub.base()));
        QSignalSpy listed(&team, &TeamServer::tracksListed);
        team.listTracks();
        QTRY_COMPARE(listed.count(), 1);
        lan.reset();                                          // left home: the LAN is gone
        team.listTracks();
        QTRY_COMPARE_WITH_TIMEOUT(listed.count(), 2, slow);
        QCOMPARE(listed.at(1).at(0).toBool(), false);
        QCOMPARE(listed.at(1).at(2).toString(),
                 QStringLiteral("Can't reach the team server (tried the LAN and the internet)."));
        team.listTracks();                                    // probes again and finds the public address
        QTRY_COMPARE_WITH_TIMEOUT(listed.count(), 3, slow);
        QCOMPARE(listed.at(2).at(0).toBool(), true);
        QCOMPARE(pub.count("/api/cone/tracks"), 1);
    }

    // ---- What the requests say ----

    void theErrorSentences()
    {
        FakeHttp pub;
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        QSignalSpy listed(&team, &TeamServer::tracksListed);
        const auto listError = [&]() {
            listed.clear();
            team.listTracks();
            if (!QTest::qWaitFor([&]() { return listed.count() == 1; }, slow))
                return QStringLiteral("(no answer)");
            return listed.at(0).at(2).toString();
        };
        pub.replyJson("GET", "/api/cone/tracks", 401, R"({"status": "error", "message": "unauthorized"})");
        QCOMPARE(listError(), QStringLiteral("The team code was not accepted. Check it in Preferences › Team."));
        pub.replyJson("GET", "/api/cone/tracks", 500, R"({"status": "error", "message": "database error"})");
        QCOMPARE(listError(), QStringLiteral("The server had a problem. Try again later."));
        pub.reply("GET", "/api/cone/tracks", FakeReply{ 502, "text/html", "<html>bad gateway</html>" });
        QCOMPARE(listError(), QStringLiteral("The server had a problem. Try again later."));

        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), FakeHttp::closedPort()));
        QCOMPARE(listError(), QStringLiteral("Can't reach the team server (tried the internet)."));
        team.setCode(teamCodeFor(QStringLiteral("Our team"), FakeHttp::closedPort(), FakeHttp::closedPort()));
        QCOMPARE(listError(), QStringLiteral("Can't reach the team server (tried the LAN and the internet)."));
        team.setCode(teamCodeFor(QStringLiteral("Our team"), FakeHttp::closedPort(), QUrl()));
        QCOMPARE(listError(), QStringLiteral("Can't reach the team server (tried the LAN)."));
    }

    void checkSaysWhatIsWrong()
    {
        FakeHttp pub;
        pub.replyJson("GET", "/api/cone/team", 401, R"({"status": "error", "message": "unauthorized"})");
        TeamServer team;
        QSignalSpy checked(&team, &TeamServer::checked);
        team.check();
        QCOMPARE(checked.count(), 1);
        QCOMPARE(checked.at(0).at(1).toString(), QStringLiteral("Not a team code"));
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        team.check();
        QTRY_COMPARE(checked.count(), 2);
        QCOMPARE(checked.at(1).at(1).toString(), QStringLiteral("The server doesn't know this code"));
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), FakeHttp::closedPort()));
        team.check();
        QTRY_COMPARE_WITH_TIMEOUT(checked.count(), 3, slow);
        QCOMPARE(checked.at(2).at(1).toString(), QStringLiteral("Can't reach the team server"));
    }

    // Review focus 3: any name comes back as it was uploaded.
    void theListIsRead()
    {
        FakeHttp pub;
        pub.replyJson("GET", "/api/cone/tracks", 200,
                      R"({"status": "ok", "tracks": [{"id": 12, "name": "Duck \"pond\" / wet é 🏁",
                          "cones": 132, "uploaded": "2026-11-12T14:02:00Z", "bytes": 3000}]})");
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        QSignalSpy listed(&team, &TeamServer::tracksListed);
        team.listTracks();
        QTRY_COMPARE(listed.count(), 1);
        QVERIFY(listed.at(0).at(0).toBool());
        const QVariantMap track = listed.at(0).at(1).toList().value(0).toMap();
        QCOMPARE(track.value("id").toInt(), 12);
        QCOMPARE(track.value("name").toString(), QStringLiteral("Duck \"pond\" / wet é \U0001F3C1"));
        QCOMPARE(track.value("cones").toInt(), 132);
        QCOMPARE(track.value("uploaded").toString(), QStringLiteral("2026-11-12T14:02:00Z"));
        QCOMPARE(track.value("uploadedText").toString(),
                 QDateTime::fromString(QStringLiteral("2026-11-12T14:02:00Z"), Qt::ISODate).toLocalTime()
                     .toString(QStringLiteral("d MMM yyyy HH:mm")));
        QCOMPARE(track.value("bytes").toDouble(), 3000.0);
    }

    void thumbnailsAreFetchedOnce()
    {
        FakeHttp pub;
        QImage small(40, 30, QImage::Format_RGB32);
        small.fill(Qt::gray);
        const QByteArray picture = TeamServer::jpeg(small);
        pub.reply("GET", "/api/cone/tracks/12/thumbnail", FakeReply{ 200, "image/jpeg", picture });
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        QSignalSpy ready(&team, &TeamServer::thumbnailReady);
        team.fetchThumbnail(12);
        QTRY_COMPARE(ready.count(), 1);
        const QUrl url = ready.at(0).at(1).toUrl();
        QCOMPARE(fileBytes(url.toLocalFile()), picture);
        team.fetchThumbnail(12);
        QCOMPARE(ready.count(), 2);
        QCOMPARE(ready.at(1).at(1).toUrl(), url);
        QCOMPARE(pub.count("/api/cone/tracks/12/thumbnail"), 1);
    }

    void anUploadSendsTheFileAndTheThumbnail()
    {
        FakeHttp pub;
        pub.replyJson("POST", "/api/cone/tracks", 201, R"({"status": "ok", "id": 12})");
        PhotoStore photos(nullptr);
        TeamServer team;
        team.setPhotos(&photos);
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        const int ref = photos.add(png(QSize(64, 48)));
        const QUrl thumbnail = team.makeThumbnail(ref, 0.05, twoCones());
        QSignalSpy uploaded(&team, &TeamServer::uploaded);
        team.upload(document(), ref, thumbnail);
        QVERIFY(team.busy());
        QTRY_COMPARE(uploaded.count(), 1);
        QCOMPARE(uploaded.at(0).at(0).toBool(), true);
        QCOMPARE(uploaded.at(0).at(1).toString(), QString());
        QVERIFY(!team.busy());
        const FakeRequest sent = pub.requests.last();
        QCOMPARE(sent.method, QByteArray("POST"));
        QCOMPARE(sent.path, QByteArray("/api/cone/tracks"));
        QVERIFY(sent.headers.value("content-type").startsWith("multipart/form-data; boundary="));
        QVERIFY(sent.body.contains("name=\"file\"; filename=\"track.cone\""));
        QVERIFY(sent.body.contains(TrackFile::documentBytes(document(), &photos, ref)));
        QVERIFY(sent.body.contains("name=\"thumbnail\"; filename=\"thumbnail.jpg\""));
        QVERIFY(sent.body.contains(fileBytes(thumbnail.toLocalFile())));
    }

    void refusalsAndSizes()
    {
        FakeHttp pub;
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        const QUrl thumbnail = team.makeThumbnail(-1, 0.05, twoCones());
        QSignalSpy uploaded(&team, &TeamServer::uploaded);

        pub.replyJson("POST", "/api/cone/tracks", 400, R"({"status": "error", "message": "not a track file"})");
        team.upload(document(), -1, thumbnail);
        QTRY_COMPARE(uploaded.count(), 1);
        QCOMPARE(uploaded.at(0).at(1).toString(), QStringLiteral("The server refused the track: not a track file."));

        pub.replyJson("POST", "/api/cone/tracks", 413, R"({"status": "error", "message": "too large"})");
        team.upload(document(), -1, thumbnail);
        QTRY_COMPARE(uploaded.count(), 2);
        QCOMPARE(uploaded.at(1).at(1).toString(), QStringLiteral("Too large to upload (over 40 MB)."));

        const int asked = int(pub.requests.size());
        const QString huge = QStringLiteral("{\"pad\": \"") + QString(int(TeamServer::maxFile), QLatin1Char('x'))
                             + QStringLiteral("\"}");
        team.upload(huge, -1, thumbnail);                     // refused before anything is sent
        QCOMPARE(uploaded.count(), 3);
        QCOMPARE(uploaded.at(2).at(1).toString(), QStringLiteral("Too large to upload (over 40 MB)."));
        QTest::qWait(100);
        QCOMPARE(int(pub.requests.size()), asked);
    }

    // Review focus 5: a second upload, or a download, while one is under way does nothing; Cancel stops it.
    void oneTransferAtATime()
    {
        FakeHttp pub;
        pub.silent = true;
        TeamServer team;
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        const QUrl thumbnail = team.makeThumbnail(-1, 0.05, twoCones());
        QSignalSpy uploaded(&team, &TeamServer::uploaded);
        QSignalSpy downloaded(&team, &TeamServer::downloaded);
        team.upload(document(), -1, thumbnail);
        team.upload(document(), -1, thumbnail);
        team.download(12);
        QTRY_COMPARE(pub.requests.size(), 1);
        QTest::qWait(200);
        QCOMPARE(pub.requests.size(), 1);
        QCOMPARE(downloaded.count(), 0);
        QVERIFY(team.busy());
        team.cancel();
        QTRY_COMPARE(uploaded.count(), 1);
        QCOMPARE(uploaded.at(0).at(0).toBool(), false);
        QCOMPARE(uploaded.at(0).at(1).toString(), QString());
        QVERIFY(!team.busy());
    }

    void aDownloadOpensThroughTrackFile()
    {
        FakeHttp pub;
        PhotoStore source(nullptr);
        const QByteArray picture = png(QSize(16, 12));
        pub.reply("GET", "/api/cone/tracks/12/file",
                  FakeReply{ 200, "application/json", TrackFile::documentBytes(document(), &source, source.add(picture)) });
        PhotoStore photos(nullptr);
        TeamServer team;
        team.setPhotos(&photos);
        team.setCode(teamCodeFor(QStringLiteral("Our team"), QUrl(), pub.base()));
        QSignalSpy downloaded(&team, &TeamServer::downloaded);
        team.download(12);
        QTRY_COMPARE(downloaded.count(), 1);
        QVERIFY(downloaded.at(0).at(0).toBool());
        const QVariantMap read = downloaded.at(0).at(1).toMap();
        QCOMPARE(photos.bytes(read.value("photoRef").toInt()), picture);
        QVERIFY(read.value("text").toString().contains(QStringLiteral("\"name\":\"Lot\"")));

        team.download(13);                                    // not on the team any more
        QTRY_COMPARE(downloaded.count(), 2);
        QCOMPARE(downloaded.at(1).at(2).toString(), QStringLiteral("That track is no longer on the team."));
    }
};

QTEST_MAIN(TestTeamServer)
#include "tst_teamserver.moc"
```

- [ ] **Step 3: Build to see it fail**

Run: `powershell -NoProfile -File app\tests\build.ps1`
Expected: FAIL to compile — `services/TeamServer.h` does not exist.

- [ ] **Step 4: Write `TeamServer.h`**

Create `app/services/TeamServer.h`:

```cpp
#pragma once
#include <QByteArray>
#include <QHash>
#include <QImage>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QTemporaryDir>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>
#include <functional>

class PhotoStore;
class QNetworkAccessManager;
class QNetworkReply;
class QNetworkRequest;

// The team server (server/ in the repo) as the app sees it: the team code from Preferences › Team, which address
// answers (the LAN first, then the public one, remembered for the session), the team's track list and thumbnails, an
// upload of the open track with a thumbnail drawn here, and a download for TrackStore to open. Every answer comes back
// as a signal; errors are sentences to show as they are. One upload or download at a time.
class TeamServer : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString code READ code WRITE setCode NOTIFY codeChanged)
    Q_PROPERTY(bool hasCode READ hasCode NOTIFY codeChanged)
    Q_PROPERTY(QString teamName READ teamName NOTIFY codeChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    // What a team code carries (server/coneRules.py makes them). `valid` is false for anything that is not a code.
    struct Code
    {
        QString team;
        QUrl lan;
        QUrl publicUrl;
        QString key;
        bool valid = false;
    };
    static Code parseCode(const QString &text);

    static constexpr qint64 maxFile = 40LL * 1024 * 1024;
    static constexpr int maxThumbnail = 200 * 1024;
    static constexpr int thumbnailSide = 400;
    static constexpr int probeTimeout = 1500;        // ms for the LAN to answer a ping
    static constexpr int requestTimeout = 15000;     // ms for check, list and thumbnails
    static constexpr int transferTimeout = 30000;    // ms without progress before an upload or download is abandoned

    explicit TeamServer(QObject *parent = nullptr);
    ~TeamServer() override;

    QString code() const { return m_code; }
    // Takes a new code (spaces around it dropped); forgets which address answered and the session's thumbnails.
    void setCode(const QString &code);
    bool hasCode() const { return m_parsed.valid; }
    QString teamName() const { return m_parsed.team; }
    bool busy() const { return m_busy; }

    Q_INVOKABLE bool isCode(const QString &text) const { return parseCode(text).valid; }

    // The upload's thumbnail: the lot photo (photoRef, or -1 for none) cropped to the cones (canvas metres, in driving
    // order, { x, y, type }) with the route through them, as a JPEG file kept for the session; an empty URL when it
    // could not be written.
    Q_INVOKABLE QUrl makeThumbnail(int photoRef, double mpp, const QVariantList &cones);
    static QImage drawThumbnail(const QImage &photo, double mpp, const QVariantList &cones);
    // JPEG bytes no larger than maxThumbnail (the quality is lowered until they fit); empty when they cannot be made.
    static QByteArray jpeg(const QImage &image);

    // Answers with checked(): "Connected to <team> (on the LAN)" or "(over the internet)", or why not.
    Q_INVOKABLE void check();
    // Answers with tracksListed(): [{ id, name, cones, uploaded, uploadedText, bytes }], newest first.
    Q_INVOKABLE void listTracks();
    // Answers with thumbnailReady() once it is here (a failure says nothing); kept for the session.
    Q_INVOKABLE void fetchThumbnail(int id);
    // Answers with downloaded(): `read` as TrackFile.open gives it ({ text, photoRef, photoError } or { error }).
    Q_INVOKABLE void download(int id);
    // The document without its photo (TrackStore.documentText), the photo to add, and the thumbnail's file URL from
    // makeThumbnail. Answers with uploaded().
    Q_INVOKABLE void upload(const QString &documentText, int photoRef, const QUrl &thumbnail);
    // Stops the upload or download under way; it answers with ok false and an empty error.
    Q_INVOKABLE void cancel();

    // Tests hand in their own store; the app uses the QML engine's.
    void setPhotos(PhotoStore *photos) { m_photos = photos; }

signals:
    void codeChanged();
    void busyChanged();
    void checked(bool ok, const QString &message);
    void tracksListed(bool ok, const QVariantList &tracks, const QString &error);
    void thumbnailReady(int id, const QUrl &url);
    void downloadProgress(qint64 received, qint64 total);
    void downloaded(bool ok, const QVariantMap &read, const QString &error);
    void uploadProgress(qint64 sent, qint64 total);
    void uploaded(bool ok, const QString &error);

private:
    PhotoStore *photos() const;
    QNetworkRequest request(const QUrl &base, const QString &route, int timeout) const;
    // Runs `then` with the address to use: the one that answered before, else the LAN when its ping answers like the
    // server within probeTimeout, else the public one. An empty URL when there is none to try.
    void withServer(const std::function<void(const QUrl &)> &then);
    // "" for a success; otherwise the sentence to show. Nothing coming back forgets the address that answered, so the
    // next request finds the server again.
    QString failure(QNetworkReply *reply);
    QString unreachable() const;
    QString tooLarge() const;
    void setBusy(bool busy);
    // Writes a file in the session's folder: its path, or "" when it could not be written.
    QString saveFile(const QString &name, const QByteArray &bytes);

    QNetworkAccessManager *m_net;
    QString m_code;
    Code m_parsed;
    QUrl m_base;
    int m_generation = 0;
    bool m_busy = false;
    bool m_cancelled = false;
    QPointer<QNetworkReply> m_transfer;
    PhotoStore *m_photos = nullptr;
    QTemporaryDir m_files;
    QHash<int, QUrl> m_thumbs;
    int m_serial = 0;
};
```

- [ ] **Step 5: Write `TeamServer.cpp`**

Create `app/services/TeamServer.cpp`. The `›` in C++ strings is written as its UTF-8 bytes `\xE2\x80\xBA`: MSVC does not read sources as UTF-8 unless told to.

```cpp
#include "TeamServer.h"

#include "PhotoStore.h"
#include "TrackFile.h"

#include <QBuffer>
#include <QDateTime>
#include <QFile>
#include <QHttpMultiPart>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPainter>
#include <QPolygonF>
#include <QQmlEngine>
#include <algorithm>

namespace {

const QString codePrefix = QStringLiteral("CONE1.");

// An address from a team code: http or https with a host, or an empty URL.
QUrl address(const QJsonValue &value)
{
    if (!value.isString())
        return {};
    const QUrl url(value.toString(), QUrl::StrictMode);
    if (!url.isValid() || url.host().isEmpty()
        || (url.scheme() != QLatin1String("http") && url.scheme() != QLatin1String("https")))
        return {};
    return url;
}

int statusOf(QNetworkReply *reply)
{
    return reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
}

QHttpPart filePart(const QByteArray &field, const QByteArray &filename, const QByteArray &type, const QByteArray &body)
{
    QHttpPart part;
    part.setHeader(QNetworkRequest::ContentDispositionHeader,
                   QByteArray("form-data; name=\"" + field + "\"; filename=\"" + filename + "\""));
    part.setHeader(QNetworkRequest::ContentTypeHeader, type);
    part.setBody(body);
    return part;
}

} // namespace

TeamServer::TeamServer(QObject *parent) : QObject(parent), m_net(new QNetworkAccessManager(this)) {}

TeamServer::~TeamServer() = default;

TeamServer::Code TeamServer::parseCode(const QString &text)
{
    Code code;
    const QString trimmed = text.trimmed();
    if (!trimmed.startsWith(codePrefix))
        return code;
    QByteArray body = trimmed.mid(codePrefix.size()).toLatin1();
    while (body.size() % 4 != 0)
        body.append('=');
    const auto decoded = QByteArray::fromBase64Encoding(
        body, QByteArray::Base64UrlEncoding | QByteArray::AbortOnBase64DecodingErrors);
    if (!decoded)
        return code;
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(*decoded, &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject())
        return code;
    const QJsonObject fields = doc.object();
    if (fields.value(QStringLiteral("v")).toInt(-1) != 1)
        return code;
    code.team = fields.value(QStringLiteral("team")).toString();
    code.key = fields.value(QStringLiteral("key")).toString();
    code.lan = address(fields.value(QStringLiteral("lan")));
    code.publicUrl = address(fields.value(QStringLiteral("public")));
    code.valid = !code.key.isEmpty() && (code.lan.isValid() || code.publicUrl.isValid());
    return code;
}

void TeamServer::setCode(const QString &code)
{
    const QString trimmed = code.trimmed();
    if (trimmed == m_code)
        return;
    m_code = trimmed;
    m_parsed = parseCode(trimmed);
    m_base = QUrl();
    ++m_generation;
    m_thumbs.clear();
    emit codeChanged();
}

PhotoStore *TeamServer::photos() const
{
    if (m_photos)
        return m_photos;
    QQmlEngine *engine = qmlEngine(this);
    return engine ? engine->singletonInstance<PhotoStore *>("Conestructor", "PhotoStore") : nullptr;
}

// ---- The thumbnail ----

QImage TeamServer::drawThumbnail(const QImage &photo, double mpp, const QVariantList &cones)
{
    const double pixelsPerMetre = mpp > 0 ? 1.0 / mpp : 1.0;
    struct Dot
    {
        QPointF at;     // photo pixels
        bool leaning;
    };
    QList<Dot> dots;
    double minX = 0, minY = 0, maxX = 0, maxY = 0;
    for (const QVariant &value : cones) {
        const QVariantMap cone = value.toMap();
        const QPointF p(cone.value(QStringLiteral("x")).toDouble() * pixelsPerMetre,
                        cone.value(QStringLiteral("y")).toDouble() * pixelsPerMetre);
        if (dots.isEmpty()) {
            minX = maxX = p.x();
            minY = maxY = p.y();
        }
        minX = std::min(minX, p.x());
        maxX = std::max(maxX, p.x());
        minY = std::min(minY, p.y());
        maxY = std::max(maxY, p.y());
        dots.append({ p, cone.value(QStringLiteral("type")).toString() == QLatin1String("leaning") });
    }

    // The cones' extent plus 10% on each side, at least 20 m across; with no cones, the whole photo.
    const double least = 20 * pixelsPerMetre;
    QRectF area;
    if (dots.isEmpty()) {
        area = photo.isNull() ? QRectF(0, 0, least, least) : QRectF(photo.rect());
    } else {
        const double w = std::max((maxX - minX) * 1.2, least);
        const double h = std::max((maxY - minY) * 1.2, least);
        area = QRectF((minX + maxX - w) / 2, (minY + maxY - h) / 2, w, h);
    }
    const double scale = thumbnailSide / std::max(area.width(), area.height());
    QImage out(std::max(1, qRound(area.width() * scale)), std::max(1, qRound(area.height() * scale)),
               QImage::Format_RGB32);
    out.fill(QColor(0x1b, 0x1b, 0x1b));

    QPainter painter(&out);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    const auto toThumb = [&](QPointF p) { return QPointF((p.x() - area.x()) * scale, (p.y() - area.y()) * scale); };
    if (!photo.isNull()) {
        const QRectF inside = area.intersected(QRectF(photo.rect()));
        if (!inside.isEmpty())
            painter.drawImage(QRectF(toThumb(inside.topLeft()), toThumb(inside.bottomRight())), photo, inside);
    }
    if (dots.size() > 1) {
        QPolygonF route;
        for (const Dot &dot : std::as_const(dots))
            route << toThumb(dot.at);
        painter.setPen(QPen(QColor(255, 255, 255, 204), 1.5));
        painter.setBrush(Qt::NoBrush);
        painter.drawPolyline(route);
    }
    painter.setPen(Qt::NoPen);
    for (const Dot &dot : std::as_const(dots)) {
        painter.setBrush(dot.leaning ? QColor(0xff, 0xd4, 0x00) : QColor(0xff, 0x8c, 0x1a));
        painter.drawEllipse(toThumb(dot.at), 3.0, 3.0);
    }
    painter.end();
    return out;
}

QByteArray TeamServer::jpeg(const QImage &image)
{
    QByteArray bytes;
    for (int quality = 85; quality >= 15; quality -= 10) {
        bytes.clear();
        QBuffer buffer(&bytes);
        buffer.open(QIODevice::WriteOnly);
        if (!image.save(&buffer, "JPG", quality))
            return {};
        if (bytes.size() <= maxThumbnail)
            return bytes;
    }
    return {};
}

QString TeamServer::saveFile(const QString &name, const QByteArray &bytes)
{
    if (!m_files.isValid())
        return {};
    const QString path = m_files.filePath(name);
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly) || file.write(bytes) != bytes.size())
        return {};
    return path;
}

QUrl TeamServer::makeThumbnail(int photoRef, double mpp, const QVariantList &cones)
{
    QImage photo;
    PhotoStore *store = photos();
    if (store && photoRef >= 0 && store->has(photoRef)) {
        QByteArray bytes = store->bytes(photoRef);
        QBuffer buffer(&bytes);
        QImageReader reader(&buffer);
        reader.setAutoTransform(true);     // as PhotoStore shows it
        photo = reader.read();
    }
    const QByteArray bytes = jpeg(drawThumbnail(photo, mpp, cones));
    if (bytes.isEmpty())
        return {};
    const QString path = saveFile(QStringLiteral("upload-%1.jpg").arg(++m_serial), bytes);
    return path.isEmpty() ? QUrl() : QUrl::fromLocalFile(path);
}

// ---- Talking to the server ----

QNetworkRequest TeamServer::request(const QUrl &base, const QString &route, int timeout) const
{
    QUrl url = base;
    QString path = url.path();
    while (path.endsWith(QLatin1Char('/')))
        path.chop(1);
    url.setPath(path + QStringLiteral("/api/cone") + route);
    QNetworkRequest r(url);
    r.setRawHeader("X-Team-Key", m_parsed.key.toUtf8());
    r.setHeader(QNetworkRequest::UserAgentHeader, QByteArrayLiteral("Conestructor/" CONESTRUCTOR_VERSION));
    r.setTransferTimeout(timeout);
    return r;
}

void TeamServer::withServer(const std::function<void(const QUrl &)> &then)
{
    if (m_base.isValid()) {
        then(m_base);
        return;
    }
    if (!m_parsed.lan.isValid()) {
        m_base = m_parsed.publicUrl;
        then(m_base);
        return;
    }
    QNetworkReply *reply = m_net->get(request(m_parsed.lan, QStringLiteral("/ping"), probeTimeout));
    const int generation = m_generation;
    connect(reply, &QNetworkReply::finished, this, [this, reply, then, generation]() {
        reply->deleteLater();
        if (generation != m_generation) {
            then(QUrl());
            return;
        }
        const bool ours = statusOf(reply) == 200
                          && QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("status")).toString()
                                 == QLatin1String("ok");
        m_base = ours ? m_parsed.lan : m_parsed.publicUrl;     // empty when the code has no public address
        then(m_base);
    });
}

QString TeamServer::unreachable() const
{
    if (m_parsed.lan.isValid() && m_parsed.publicUrl.isValid())
        return tr("Can't reach the team server (tried the LAN and the internet).");
    if (m_parsed.lan.isValid())
        return tr("Can't reach the team server (tried the LAN).");
    return tr("Can't reach the team server (tried the internet).");
}

QString TeamServer::tooLarge() const
{
    return tr("Too large to upload (over 40 MB).");
}

QString TeamServer::failure(QNetworkReply *reply)
{
    const int status = statusOf(reply);
    if (status == 0) {                  // nothing came back: refused, timed out, no route, TLS...
        m_base = QUrl();
        return unreachable();
    }
    if (status >= 200 && status < 300)
        return {};
    if (status == 401)
        return tr("The team code was not accepted. Check it in Preferences \xE2\x80\xBA Team.");
    if (status == 413)
        return tooLarge();
    if (status == 400) {
        const QString message =
            QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("message")).toString();
        return tr("The server refused the track: %1.").arg(message.isEmpty() ? tr("no reason given") : message);
    }
    return tr("The server had a problem. Try again later.");
}

void TeamServer::setBusy(bool busy)
{
    if (busy == m_busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void TeamServer::check()
{
    if (!m_parsed.valid) {
        emit checked(false, tr("Not a team code"));
        return;
    }
    withServer([this](const QUrl &base) {
        if (!base.isValid()) {
            emit checked(false, tr("Can't reach the team server"));
            return;
        }
        QNetworkReply *reply = m_net->get(request(base, QStringLiteral("/team"), requestTimeout));
        connect(reply, &QNetworkReply::finished, this, [this, reply, base]() {
            reply->deleteLater();
            const int status = statusOf(reply);
            if (status == 0) {
                m_base = QUrl();
                emit checked(false, tr("Can't reach the team server"));
            } else if (status == 401) {
                emit checked(false, tr("The server doesn't know this code"));
            } else if (status != 200) {
                emit checked(false, tr("The server had a problem. Try again later."));
            } else {
                const QString name =
                    QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("name")).toString();
                emit checked(true, (base == m_parsed.lan ? tr("Connected to %1 (on the LAN)")
                                                         : tr("Connected to %1 (over the internet)")).arg(name));
            }
        });
    });
}

void TeamServer::listTracks()
{
    if (!m_parsed.valid) {
        emit tracksListed(false, {}, tr("Not a team code"));
        return;
    }
    withServer([this](const QUrl &base) {
        if (!base.isValid()) {
            emit tracksListed(false, {}, unreachable());
            return;
        }
        QNetworkReply *reply = m_net->get(request(base, QStringLiteral("/tracks"), requestTimeout));
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            reply->deleteLater();
            const QString error = failure(reply);
            if (!error.isEmpty()) {
                emit tracksListed(false, {}, error);
                return;
            }
            QVariantList tracks;
            const QJsonArray list =
                QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("tracks")).toArray();
            for (const QJsonValue value : list) {
                const QJsonObject t = value.toObject();
                const QString uploaded = t.value(QStringLiteral("uploaded")).toString();
                tracks << QVariantMap{
                    { QStringLiteral("id"), t.value(QStringLiteral("id")).toInt() },
                    { QStringLiteral("name"), t.value(QStringLiteral("name")).toString() },
                    { QStringLiteral("cones"), t.value(QStringLiteral("cones")).toInt() },
                    { QStringLiteral("uploaded"), uploaded },
                    { QStringLiteral("uploadedText"), QDateTime::fromString(uploaded, Qt::ISODate).toLocalTime()
                                                          .toString(QStringLiteral("d MMM yyyy HH:mm")) },
                    { QStringLiteral("bytes"), t.value(QStringLiteral("bytes")).toDouble() } };
            }
            emit tracksListed(true, tracks, QString());
        });
    });
}

void TeamServer::fetchThumbnail(int id)
{
    if (m_thumbs.contains(id)) {
        emit thumbnailReady(id, m_thumbs.value(id));
        return;
    }
    if (!m_parsed.valid)
        return;
    const int generation = m_generation;
    withServer([this, id, generation](const QUrl &base) {
        if (!base.isValid() || generation != m_generation)
            return;
        QNetworkReply *reply =
            m_net->get(request(base, QStringLiteral("/tracks/%1/thumbnail").arg(id), requestTimeout));
        connect(reply, &QNetworkReply::finished, this, [this, reply, id, generation]() {
            reply->deleteLater();
            if (generation != m_generation || !failure(reply).isEmpty())
                return;
            const QString path = saveFile(QStringLiteral("thumb-%1.jpg").arg(id), reply->readAll());
            if (path.isEmpty())
                return;
            m_thumbs.insert(id, QUrl::fromLocalFile(path));
            emit thumbnailReady(id, m_thumbs.value(id));
        });
    });
}

void TeamServer::download(int id)
{
    if (m_busy)
        return;
    if (!m_parsed.valid) {
        emit downloaded(false, {}, tr("Not a team code"));
        return;
    }
    setBusy(true);
    m_cancelled = false;
    withServer([this, id](const QUrl &base) {
        if (m_cancelled || !base.isValid()) {
            setBusy(false);
            emit downloaded(false, {}, m_cancelled ? QString() : unreachable());
            return;
        }
        QNetworkReply *reply = m_net->get(request(base, QStringLiteral("/tracks/%1/file").arg(id), transferTimeout));
        m_transfer = reply;
        connect(reply, &QNetworkReply::downloadProgress, this, &TeamServer::downloadProgress);
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            reply->deleteLater();
            m_transfer = nullptr;
            setBusy(false);
            if (m_cancelled) {
                emit downloaded(false, {}, QString());
                return;
            }
            if (statusOf(reply) == 404) {
                emit downloaded(false, {}, tr("That track is no longer on the team."));
                return;
            }
            const QString error = failure(reply);
            if (!error.isEmpty()) {
                emit downloaded(false, {}, error);
                return;
            }
            emit downloaded(true, TrackFile::openBytes(reply->readAll(), photos()), QString());
        });
    });
}

void TeamServer::upload(const QString &documentText, int photoRef, const QUrl &thumbnail)
{
    if (m_busy)
        return;
    if (!m_parsed.valid) {
        emit uploaded(false, tr("Not a team code"));
        return;
    }
    const QByteArray file = TrackFile::documentBytes(documentText, photos(), photoRef);
    if (file.isEmpty()) {
        emit uploaded(false, tr("The track could not be written out."));
        return;
    }
    if (file.size() > maxFile) {
        emit uploaded(false, tooLarge());
        return;
    }
    QFile picture(thumbnail.toLocalFile());
    if (!picture.open(QIODevice::ReadOnly)) {
        emit uploaded(false, tr("The thumbnail could not be read."));
        return;
    }
    const QByteArray thumbnailBytes = picture.readAll();
    setBusy(true);
    m_cancelled = false;
    withServer([this, file, thumbnailBytes](const QUrl &base) {
        if (m_cancelled || !base.isValid()) {
            setBusy(false);
            emit uploaded(false, m_cancelled ? QString() : unreachable());
            return;
        }
        auto *form = new QHttpMultiPart(QHttpMultiPart::FormDataType);
        form->append(filePart("file", "track.cone", "application/json", file));
        form->append(filePart("thumbnail", "thumbnail.jpg", "image/jpeg", thumbnailBytes));
        QNetworkReply *reply = m_net->post(request(base, QStringLiteral("/tracks"), transferTimeout), form);
        form->setParent(reply);
        m_transfer = reply;
        connect(reply, &QNetworkReply::uploadProgress, this, &TeamServer::uploadProgress);
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            reply->deleteLater();
            m_transfer = nullptr;
            setBusy(false);
            if (m_cancelled) {
                emit uploaded(false, QString());
                return;
            }
            const QString error = failure(reply);
            emit uploaded(error.isEmpty(), error);
        });
    });
}

void TeamServer::cancel()
{
    m_cancelled = true;
    if (m_transfer)
        m_transfer->abort();
}
```

- [ ] **Step 6: Build and run the tests**

Run: `powershell -NoProfile -File app\tests\build.ps1`, then `powershell -NoProfile -File app\tests\run.ps1 -NoQml -R tst_teamserver`
Expected: `ctest: passed`. Then the whole suite, `powershell -NoProfile -File app\tests\run.ps1`: `ctest: passed`; `qml: 382 passed, 0 failed`.

If `theThumbnailShowsTheConesOnThePhoto` fails on the size or a pixel, print `thumb.size()` and the three colours with `qDebug()` before changing anything: the expected numbers are worked out in the test's comment, so a difference means `drawThumbnail` does not follow the decisions above.

- [ ] **Step 7: Commit**

```bash
git add app/services/TeamServer.h app/services/TeamServer.cpp app/CMakeLists.txt app/tests/CMakeLists.txt app/tests/fakehttp.h app/tests/tst_teamserver.cpp
git commit -m "TeamServer: reads the team code, finds the server (LAN ping first, then public), lists, fetches thumbnails, uploads and downloads; draws the upload's thumbnail" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Preferences › Team, a track with no path from the team, the title

**Files:**
- Modify: `app/qml/PreferencesDialog.qml` (the Team section, `openAtTeam()`)
- Modify: `app/qml/TrackStore.qml` (`teamName`, `fromTeam`, `readOpened()`, `openFromTeam()`, `uploadResult()`)
- Modify: `app/qml/Main.qml` (the `Binding`, the title, `saveAsStart()`)
- Modify: `app/tests/CMakeLists.txt` (`tst_qmlload` also links `conestructor_core`)
- Test: `app/tests/tst_qmlload.cpp`

**Interfaces:**
- Consumes: `Settings.teamCode` (Task 6); `TeamServer.code`, `hasCode`, `teamName`, `isCode()`, `check()`, `checked` (Task 7).
- Produces:
  - `PreferencesDialog.openAtTeam(hint: string)`: opens the dialog scrolled to the Team section with `hint` shown above it (cleared when it closes). objectNames: `teamHint`, `teamCodeField`, `teamCodeNote`, `teamShowCode`, `teamCheckButton`, `teamClearButton`, `teamCheckResult`.
  - `TrackStore.teamName` (string, "" unless the track came from the team), `TrackStore.fromTeam` (bool), `TrackStore.name` (the file's name, else `teamName`, else "Untitled"), `TrackStore.readOpened(r) -> { track, warning, photoRef } | null`, `TrackStore.openFromTeam(read, name) -> bool`, `TrackStore.uploadResult() -> { cones, canvasCones, targetDistance } | null`.
  - Window title: `Conestructor 0.6 — <name> (from team)` for a team track, with `*` when unsaved, as before.

- [ ] **Step 1: Write the failing tests**

In `app/tests/CMakeLists.txt`, `LIBS conestructor_coreplugin Qt6::Qml Qt6::Quick Qt6::QuickControls2)` (in `tst_qmlload`) → `LIBS conestructor_coreplugin conestructor_core Qt6::Qml Qt6::Quick Qt6::QuickControls2)`.

In `app/tests/tst_qmlload.cpp`, add after `#include <QtMath>`:

```cpp
#include <QScopeGuard>
#include "fakehttp.h"
#include "services/TeamServer.h"
#include "services/TrackFile.h"
```

Add these tests at the end of `TestQmlLoad`:

```cpp
    // Part 5: Preferences › Team takes a team code only when it is one (spaces around it dropped), shows it masked
    // unless Show is ticked, and Clear removes it. Review focus 1.
    void theTeamSection()
    {
        Loaded w;
        QVERIFY(w.load(false));
        QObject *settings = w.engine.singletonInstance<QObject *>("Conestructor", "Settings");
        QObject *team = w.engine.singletonInstance<QObject *>("Conestructor", "TeamServer");
        auto restore = qScopeGuard([settings]() { settings->setProperty("teamCode", QString()); });
        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("preferencesDialog"));
        QVERIFY(dialog);
        QMetaObject::invokeMethod(dialog, "open");
        QTRY_VERIFY(dialog->property("opened").toBool());
        QQuickItem *field = w.named(QStringLiteral("teamCodeField"));
        QVERIFY(field);
        QCOMPARE(field->property("echoMode").toInt(), 2);                    // TextInput.Password
        scrollIntoView(field);
        w.clickItem(field);
        typeText(w.window, QStringLiteral("hello"));
        QVERIFY(w.named(QStringLiteral("teamCodeNote"))->isVisible());
        QCOMPARE(settings->property("teamCode").toString(), QString());

        const QString code = teamCodeFor(QStringLiteral("Our team"), QUrl(), QUrl(QStringLiteral("https://public.example")));
        QTest::keyClick(w.window, Qt::Key_A, Qt::ControlModifier);
        typeText(w.window, QStringLiteral("  ") + code + QStringLiteral("  "));
        QVERIFY(!w.named(QStringLiteral("teamCodeNote"))->isVisible());
        QCOMPARE(settings->property("teamCode").toString(), code);
        QVERIFY(team->property("hasCode").toBool());
        QCOMPARE(team->property("teamName").toString(), QStringLiteral("Our team"));

        QQuickItem *show = w.named(QStringLiteral("teamShowCode"));
        scrollIntoView(show);
        w.clickItem(show);
        QCOMPARE(field->property("echoMode").toInt(), 0);                    // TextInput.Normal
        QQuickItem *clear = w.named(QStringLiteral("teamClearButton"));
        scrollIntoView(clear);
        w.clickItem(clear);
        QCOMPARE(settings->property("teamCode").toString(), QString());
        QVERIFY(!team->property("hasCode").toBool());
        QCOMPARE(field->property("text").toString(), QString());
    }

    // Part 5: a track opened from the team has no file: "(from team)" in the title, not unsaved, not a recent file;
    // Save As starts with its name, and once saved it is an ordinary file.
    void aTrackFromTheTeamOpensWithoutAPath()
    {
        Loaded w;
        QVERIFY(w.load(true));
        QObject *settings = w.engine.singletonInstance<QObject *>("Conestructor", "Settings");
        QObject *trackFile = w.engine.singletonInstance<QObject *>("Conestructor", "TrackFile");
        const QString path = dir.filePath(QStringLiteral("from-team.cone"));
        QVariant ok;
        QMetaObject::invokeMethod(w.store, "saveTo", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, path));
        QVERIFY(ok.toBool());
        QVariantMap read;
        QMetaObject::invokeMethod(trackFile, "open", Q_RETURN_ARG(QVariantMap, read), Q_ARG(QString, path));
        QMetaObject::invokeMethod(w.store, "newTrack");
        const QStringList recent = settings->property("recentFiles").toStringList();

        QMetaObject::invokeMethod(w.store, "openFromTeam", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, QVariant(read)),
                                  Q_ARG(QVariant, QStringLiteral("Duck pond")));
        QVERIFY(ok.toBool());
        QCOMPARE(w.window->title(), QStringLiteral("Conestructor 0.6 — Duck pond (from team)"));
        QVERIFY(w.store->property("fromTeam").toBool());
        QVERIFY(!w.store->property("dirty").toBool());
        QCOMPARE(w.store->property("filePath").toString(), QString());
        QCOMPARE(w.store->property("elementCount").toInt(), 4);
        QCOMPARE(settings->property("recentFiles").toStringList(), recent);
        QCOMPARE(w.store->property("message").toString(), QStringLiteral("Opened Duck pond from the team"));

        QVariant start;
        QMetaObject::invokeMethod(w.window, "saveAsStart", Q_RETURN_ARG(QVariant, start));
        QVERIFY(plain(start).toMap().value(QStringLiteral("file")).toString().endsWith(QStringLiteral("/Duck pond.cone")));

        const QString saved = dir.filePath(QStringLiteral("Saved from team.cone"));
        QMetaObject::invokeMethod(w.store, "saveTo", Q_RETURN_ARG(QVariant, ok), Q_ARG(QVariant, saved));
        QVERIFY(ok.toBool());
        QCOMPARE(w.window->title(), QStringLiteral("Conestructor 0.6 — Saved from team"));
        QVERIFY(!w.store->property("fromTeam").toBool());
        QMetaObject::invokeMethod(w.store, "newTrack");
        QCOMPARE(w.window->title(), QStringLiteral("Conestructor 0.6 — Untitled"));
    }

    // Part 5: a track that cannot be processed is not uploaded; the banner says why.
    void anUploadNeedsATrackThatProcesses()
    {
        Loaded w;
        QVERIFY(w.load(false));
        QVariant result;
        QMetaObject::invokeMethod(w.store, "uploadResult", Q_RETURN_ARG(QVariant, result));
        QVERIFY(isNull(result));
        QVERIFY(findBanner(w.window)->isVisible());

        QMetaObject::invokeMethod(w.window, "loadDemo", Q_ARG(QVariant, QVariant(false)));
        QMetaObject::invokeMethod(w.store, "uploadResult", Q_RETURN_ARG(QVariant, result));
        QVERIFY(plain(result).toMap().value(QStringLiteral("cones")).toList().size() > 40);
    }
```

- [ ] **Step 2: Build and run them to see them fail**

Run: `powershell -NoProfile -File app\tests\build.ps1`, then `powershell -NoProfile -File app\tests\run.ps1 -NoQml -R tst_qmlload`
Expected: FAIL — `teamCodeField` is not found (null), `openFromTeam` and `uploadResult` do not exist.

- [ ] **Step 3: `TrackStore`: a track from the team, and what an upload carries**

In `app/qml/TrackStore.qml`, replace the two lines

```qml
    property string filePath: ""
    readonly property string name: filePath !== "" ? TrackFile.baseName(filePath) : qsTr("Untitled")
```

with

```qml
    property string filePath: ""
    // A track opened from the team has no file until it is saved; its name is the one it was uploaded with.
    property string teamName: ""
    readonly property bool fromTeam: filePath === "" && teamName !== ""
    readonly property string name: filePath !== "" ? TrackFile.baseName(filePath)
                                 : teamName !== "" ? teamName : qsTr("Untitled")
```

In `newTrack()`, add `teamName = ""` after `filePath = ""`.

In `saveTo(path)`, add `teamName = ""` after `filePath = path`.

In `openPath(path)`, add `teamName = ""` after `filePath = path`.

In `restoreBackup(backup)`, add `teamName = ""` after `filePath = backup.trackPath`.

Replace `readTrack(path)` with:

```qml
    // Reads a track file: { track, warning, photoRef }, or null after a banner says why not (this track is untouched).
    function readTrack(path) {
        const r = TrackFile.open(path)
        if (r.error === "missing")
            Settings.removeRecentFile(path)
        return readOpened(r)
    }

    // A track file's contents as TrackFile.open or TeamServer.download gave them ({ text, photoRef, photoError } or
    // { error, message }): { track, warning, photoRef }, or null after a banner says why not.
    function readOpened(r) {
        if (r.error) {
            report(r.error === "notJson" ? ConeFile.MESSAGES.notTrack : r.message, null)
            return null
        }
        let doc = null
        try {
            doc = JSON.parse(r.text)
        } catch (e) {
            doc = null
        }
        const result = ConeFile.fromDocument(doc, r.photoRef)
        if (result.error) {
            if (r.photoRef >= 0)
                PhotoStore.remove(r.photoRef)
            report(result.error, null)
            return null
        }
        return { track: result.track, warning: result.warning, photoRef: r.photoRef }
    }
```

Add after `openPath(path)`:

```qml
    // A track downloaded from the team (`r` from TeamServer.download), under the name it was uploaded with. It has no
    // file until saved, is not unsaved and is not a recent file.
    function openFromTeam(r, trackName) {
        const read = readOpened(r)
        if (!read)
            return false
        filePath = ""
        teamName = trackName
        show(read)
        markSaved()
        message = qsTr("Opened %1 from the team").arg(trackName)
        return true
    }

    // What Upload to team sends the cones of: the touched-up list while locked, otherwise what Place cones would place
    // now ({ cones, canvasCones, targetDistance }); null after a banner says why the track cannot be processed.
    function uploadResult() {
        const result = locked ? Touchups.result(track) : Post.run(track)
        if (result.error) {
            report(result.error.message, result.error.target)
            return null
        }
        return result
    }
```

- [ ] **Step 4: Preferences › Team**

In `app/qml/PreferencesDialog.qml`:
- Change the header comment's first line to: `// Edit > Preferences: Units, Cones (the cones the team owns), Car (the outline's size and picture) and Team (the team code), in one scrolling column.` and delete `// column. Part 5 adds Team.`
- Add after `property bool imageFound: false`:

```qml
    // Shown above the Team section when File › Open from team or Upload to team opened the dialog without a code.
    property string teamHint: ""
    property bool badCode: false
    property bool checking: false
    property string checkResult: ""
    property bool checkOk: false
```

- Replace `onAboutToShow: imageFound = Settings.carImageFound()` with:

```qml
    onAboutToShow: {
        imageFound = Settings.carImageFound()
        codeField.text = Settings.teamCode
        badCode = false
        checkResult = ""
    }
    onClosed: teamHint = ""

    // Opens at the Team section with `hint` above it.
    function openAtTeam(hint) {
        teamHint = hint
        open()
        Qt.callLater(() => {
            const flick = scroll.contentItem
            flick.contentY = Math.max(0, Math.min(teamHeader.y, column.height - flick.height))
        })
    }

    // A code is saved only when it is one; a blank field saves nothing (Clear removes the code).
    function codeTyped(text) {
        checkResult = ""
        if (text.trim() === "") {
            badCode = false
            return
        }
        badCode = !TeamServer.isCode(text)
        if (!badCode)
            Settings.teamCode = text.trim()
    }

    function clearCode() {
        codeField.text = ""
        badCode = false
        checkResult = ""
        Settings.teamCode = ""
    }

    function checkCode() {
        checking = true
        checkOk = false
        checkResult = qsTr("Checking…")
        TeamServer.check()
    }

    Connections {
        target: TeamServer
        function onChecked(ok, message) {
            dialog.checking = false
            dialog.checkOk = ok
            dialog.checkResult = message
        }
    }
```

- Add the Team section at the end of `column`, after the car picture's `RowLayout` with the Choose… and Clear buttons:

```qml
            Label {
                id: teamHeader
                Layout.topMargin: 12
                text: qsTr("Team")
                font.bold: true
            }
            Label {
                objectName: "teamHint"
                visible: dialog.teamHint !== ""
                text: dialog.teamHint
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: "#ffb74d"
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("Team code")
                    color: "#e0e0e0"
                    Layout.preferredWidth: 104
                }
                TextField {
                    id: codeField
                    objectName: "teamCodeField"
                    Layout.fillWidth: true
                    echoMode: showCode.checked ? TextInput.Normal : TextInput.Password
                    placeholderText: qsTr("Paste the team code")
                    onTextEdited: dialog.codeTyped(text)
                }
            }
            Label {
                objectName: "teamCodeNote"
                visible: dialog.badCode
                text: qsTr("Not a team code")
                color: "#ff6b6b"
            }
            RowLayout {
                CheckBox {
                    id: showCode
                    objectName: "teamShowCode"
                    text: qsTr("Show")
                }
                Button {
                    objectName: "teamCheckButton"
                    text: qsTr("Check")
                    enabled: TeamServer.hasCode && !dialog.checking
                    onClicked: dialog.checkCode()
                }
                Button {
                    objectName: "teamClearButton"
                    text: qsTr("Clear")
                    enabled: Settings.teamCode !== "" || codeField.text !== ""
                    onClicked: dialog.clearCode()
                }
            }
            Label {
                objectName: "teamCheckResult"
                visible: text !== ""
                text: dialog.checkResult
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: dialog.checkOk ? "#81c784" : "#ffb74d"
            }
            Label {
                text: qsTr("Treat the team code like a password: it opens your team's tracks.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                color: "#b0b0b0"
            }
```

- [ ] **Step 5: `Main.qml`: the binding, the title, Save As**

In `app/qml/Main.qml`:
- Replace the `title:` line with:

```qml
    title: "Conestructor " + AppInfo.shortVersion + " — " + TrackStore.name
           + (TrackStore.fromTeam ? qsTr(" (from team)") : "") + (TrackStore.dirty ? "*" : "")
```

- Add after `property bool backupAnswered: true`:

```qml

    // The team server follows the team code in Preferences.
    Binding {
        target: TeamServer
        property: "code"
        value: Settings.teamCode
    }
```

- In `saveAsStart()`, replace the two `Untitled` lines' comment and file with the track's name (an untitled track is still named Untitled; a team track by its own name):

```qml
    // Where Save As starts: beside the open track with its name filled in; a track with no file (Untitled, or one from
    // the team) in the last folder used, under its name.
    function saveAsStart() {
        if (TrackStore.filePath === "") {
            const folder = saveDialog.currentFolder.toString()
            return { folder: saveDialog.currentFolder,
                     file: folder + (folder.endsWith("/") ? "" : "/") + TrackStore.name + ".cone" }
        }
        return { folder: TrackFile.folderUrl(TrackStore.filePath), file: TrackFile.fileUrl(TrackStore.filePath) }
    }
```

- [ ] **Step 6: Build and run the tests**

Run: `powershell -NoProfile -File app\tests\build.ps1`, then `powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`; `qml: 382 passed, 0 failed`. `saveAsStartsBesideTheTrack` (part 3) still passes: an Untitled track's name is still "Untitled".

- [ ] **Step 7: Commit**

```bash
git add app/qml/PreferencesDialog.qml app/qml/TrackStore.qml app/qml/Main.qml app/tests/CMakeLists.txt app/tests/tst_qmlload.cpp
git commit -m "Preferences › Team (the team code, masked, checked, cleared); a track from the team opens with no file and '(from team)' in the title; uploadResult" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: File › Open from team and File › Upload to team

**Files:**
- Create: `app/qml/TeamTracksDialog.qml`, `app/qml/UploadDialog.qml`
- Modify: `app/CMakeLists.txt` (the two QML files)
- Modify: `app/qml/Main.qml` (File menu items, `openFromTeam()`, `uploadToTeam()`, `openTeamTrack()`, the two dialogs)
- Test: `app/tests/tst_qmlload.cpp`

**Interfaces:**
- Consumes: `TeamServer` (Task 7); `TrackStore.openFromTeam`, `uploadResult`, `documentText`, `photoRef`, `mpp`, `fromTeam`, `name`, `filePath` (Task 8); `PreferencesDialog.openAtTeam` (Task 8).
- Produces:
  - `TeamTracksDialog` (objectName `teamTracksDialog`): `openList()`, `refresh()`, `openChosen()`, signal `openTrack(var read, string name)`, property `thumbs` (track id → thumbnail URL); objectNames `teamTracksStatus`, `teamTrackList`, `teamRefreshButton`, `teamOpenButton`, `teamDownloadProgress`.
  - `UploadDialog` (objectName `uploadDialog`): `ask(result)`, `send()`, signal `sent(string name)`; objectNames `uploadThumbnail`, `uploadName`, `uploadQuestion`, `uploadProgress`, `uploadError`, `uploadButton`.
  - `Main.openFromTeam()`, `Main.uploadToTeam()`, `Main.openTeamTrack(read, name)`.

- [ ] **Step 1: Write the failing tests**

Add at the end of `TestQmlLoad` in `app/tests/tst_qmlload.cpp`:

```cpp
    // Part 5: without a team code, both team items open Preferences at the Team section with a line saying why.
    void theTeamItemsNeedACode()
    {
        Loaded w;
        QVERIFY(w.load(true));
        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("preferencesDialog"));
        for (const char *action : { "openFromTeam", "uploadToTeam" }) {
            QMetaObject::invokeMethod(w.window, action);
            QTRY_VERIFY(dialog->property("opened").toBool());
            QQuickItem *hint = w.named(QStringLiteral("teamHint"));
            QVERIFY(hint && hint->isVisible());
            QCOMPARE(hint->property("text").toString(), QStringLiteral("Paste your team code to use team tracks."));
            QMetaObject::invokeMethod(dialog, "close");
            QTRY_VERIFY(!dialog->property("visible").toBool());
        }
        QVERIFY(!w.window->findChild<QObject *>(QStringLiteral("teamTracksDialog"))->property("visible").toBool());
        QVERIFY(!w.window->findChild<QObject *>(QStringLiteral("uploadDialog"))->property("visible").toBool());
    }

    // Part 5: Upload to team draws a thumbnail, asks for a name (an Untitled track has none yet), sends the track once
    // however often Enter is pressed, and says so in the status bar. Review focus 5.
    void uploadingToTheTeam()
    {
        FakeHttp server;
        server.replyJson("POST", "/api/cone/tracks", 201, R"({"status": "ok", "id": 12})");
        Loaded w;
        QVERIFY(w.load(true));
        QObject *settings = w.engine.singletonInstance<QObject *>("Conestructor", "Settings");
        auto restore = qScopeGuard([settings]() { settings->setProperty("teamCode", QString()); });
        settings->setProperty("teamCode", teamCodeFor(QStringLiteral("Our team"), QUrl(), server.base()));
        QMetaObject::invokeMethod(w.window, "uploadToTeam");
        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("uploadDialog"));
        QTRY_VERIFY(dialog->property("opened").toBool());
        QQuickItem *name = w.named(QStringLiteral("uploadName"));
        QQuickItem *button = w.named(QStringLiteral("uploadButton"));
        QCOMPARE(name->property("text").toString(), QString());
        QVERIFY(!button->isEnabled());
        const QUrl thumbnail = w.named(QStringLiteral("uploadThumbnail"))->property("source").toUrl();
        QVERIFY(QFileInfo::exists(thumbnail.toLocalFile()));
        QVERIFY(w.named(QStringLiteral("uploadQuestion"))->property("text").toString()
                    .contains(QStringLiteral("cones) to Our team? Teammates will be able to open it.")));

        w.clickItem(name);
        typeText(w.window, QStringLiteral("Duck pond wet"));
        QVERIFY(button->isEnabled());
        QTest::keyClick(w.window, Qt::Key_Return);
        QTest::keyClick(w.window, Qt::Key_Return);             // a second Enter while it sends does nothing
        QTRY_VERIFY(!dialog->property("visible").toBool());
        QCOMPARE(server.count("/api/cone/tracks"), 1);
        const FakeRequest sent = server.requests.last();
        QVERIFY(sent.headers.value("content-type").startsWith("multipart/form-data"));
        QCOMPARE(sent.headers.value("x-team-key"), QByteArray("test-key"));
        QVERIFY(sent.body.contains("\"name\": \"Duck pond wet\""));
        QVERIFY(sent.body.contains("name=\"thumbnail\""));
        QCOMPARE(w.store->property("message").toString(), QStringLiteral("Uploaded Duck pond wet to Our team"));
        QCOMPARE(w.store->property("filePath").toString(), QString());
        QVERIFY(!w.store->property("dirty").toBool());
    }

    void aRefusedUploadSaysWhyAndStaysOpen()
    {
        FakeHttp server;
        server.replyJson("POST", "/api/cone/tracks", 400, R"({"status": "error", "message": "not a track file"})");
        Loaded w;
        QVERIFY(w.load(true));
        QObject *settings = w.engine.singletonInstance<QObject *>("Conestructor", "Settings");
        auto restore = qScopeGuard([settings]() { settings->setProperty("teamCode", QString()); });
        settings->setProperty("teamCode", teamCodeFor(QStringLiteral("Our team"), QUrl(), server.base()));
        QMetaObject::invokeMethod(w.window, "uploadToTeam");
        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("uploadDialog"));
        QTRY_VERIFY(dialog->property("opened").toBool());
        w.clickItem(w.named(QStringLiteral("uploadName")));
        typeText(w.window, QStringLiteral("Lot"));
        w.clickItem(w.named(QStringLiteral("uploadButton")));
        QTRY_COMPARE(w.named(QStringLiteral("uploadError"))->property("text").toString(),
                     QStringLiteral("The server refused the track: not a track file."));
        QVERIFY(dialog->property("visible").toBool());
    }

    // Part 5: Open from team asks about unsaved changes first, lists the team's tracks with their thumbnails, and opens
    // the chosen one with no file.
    void openingFromTheTeam()
    {
        FakeHttp server;
        Loaded w;
        QVERIFY(w.load(true));
        QVariant text;
        QMetaObject::invokeMethod(w.store, "documentText", Q_RETURN_ARG(QVariant, text), Q_ARG(QVariant, QStringLiteral("Duck pond")));
        server.reply("GET", "/api/cone/tracks/12/file",
                     FakeReply{ 200, "application/json", TrackFile::documentBytes(text.toString(), nullptr, -1) });
        server.replyJson("GET", "/api/cone/tracks", 200,
                         R"({"status": "ok", "tracks": [{"id": 12, "name": "Duck pond", "cones": 57,
                             "uploaded": "2026-11-12T14:02:00Z", "bytes": 3000}]})");
        QImage small(40, 30, QImage::Format_RGB32);
        small.fill(Qt::gray);
        server.reply("GET", "/api/cone/tracks/12/thumbnail", FakeReply{ 200, "image/jpeg", TeamServer::jpeg(small) });
        QObject *settings = w.engine.singletonInstance<QObject *>("Conestructor", "Settings");
        auto restore = qScopeGuard([settings]() { settings->setProperty("teamCode", QString()); });
        settings->setProperty("teamCode", teamCodeFor(QStringLiteral("Our team"), QUrl(), server.base()));
        const QStringList recent = settings->property("recentFiles").toStringList();

        w.run(QStringLiteral("place"), { { "id", "e1" }, { "x", 40.0 }, { "y", 30.0 }, { "rotation", 0.0 } });
        QMetaObject::invokeMethod(w.window, "openFromTeam");
        QObject *unsaved = w.window->findChild<QObject *>(QStringLiteral("unsavedDialog"));
        QTRY_VERIFY(unsaved->property("opened").toBool());
        w.clickItem(findButton(w.window, QStringLiteral("Don't save")));

        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("teamTracksDialog"));
        QTRY_VERIFY(dialog->property("opened").toBool());
        QCOMPARE(dialog->property("title").toString(), QStringLiteral("Team tracks: Our team"));
        QTRY_VERIFY(findText(w.window, QStringLiteral("Duck pond")));
        const QString when = QDateTime::fromString(QStringLiteral("2026-11-12T14:02:00Z"), Qt::ISODate).toLocalTime()
                                 .toString(QStringLiteral("d MMM yyyy HH:mm"));
        QVERIFY(findText(w.window, QStringLiteral("57 cones · ") + when));
        QTRY_VERIFY(!plain(dialog->property("thumbs")).toMap().isEmpty());
        w.clickItem(w.named(QStringLiteral("teamOpenButton")));
        QTRY_COMPARE(w.window->title(), QStringLiteral("Conestructor 0.6 — Duck pond (from team)"));
        QVERIFY(!dialog->property("visible").toBool());
        QVERIFY(!w.store->property("dirty").toBool());
        QCOMPARE(settings->property("recentFiles").toStringList(), recent);
        QCOMPARE(w.store->property("elementCount").toInt(), 4);
    }

    void theTeamListSaysWhatIsWrong()
    {
        Loaded w;
        QVERIFY(w.load(true));
        QObject *settings = w.engine.singletonInstance<QObject *>("Conestructor", "Settings");
        auto restore = qScopeGuard([settings]() { settings->setProperty("teamCode", QString()); });
        settings->setProperty("teamCode", teamCodeFor(QStringLiteral("Our team"), QUrl(), FakeHttp::closedPort()));
        QMetaObject::invokeMethod(w.window, "openFromTeam");
        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("teamTracksDialog"));
        QTRY_VERIFY(dialog->property("opened").toBool());
        QQuickItem *status = w.named(QStringLiteral("teamTracksStatus"));
        QCOMPARE(status->property("text").toString(), QStringLiteral("Connecting…"));
        QTRY_COMPARE_WITH_TIMEOUT(status->property("text").toString(),
                                  QStringLiteral("Can't reach the team server (tried the internet)."), 20000);

        FakeHttp server;
        server.replyJson("GET", "/api/cone/tracks", 200, R"({"status": "ok", "tracks": []})");
        settings->setProperty("teamCode", teamCodeFor(QStringLiteral("Our team"), QUrl(), server.base()));
        w.clickItem(w.named(QStringLiteral("teamRefreshButton")));
        QTRY_COMPARE(status->property("text").toString(),
                     QStringLiteral("No tracks on the team yet. File › Upload to team shares the open track."));
        QVERIFY(!w.named(QStringLiteral("teamOpenButton"))->isEnabled());
    }

    // Review focus 4: closing the list during a download stops it; nothing opens later, and the list comes back.
    void aDownloadStopsWhenTheDialogCloses()
    {
        FakeHttp server;
        server.replyJson("GET", "/api/cone/tracks", 200,
                         R"({"status": "ok", "tracks": [{"id": 12, "name": "Duck pond", "cones": 57,
                             "uploaded": "2026-11-12T14:02:00Z", "bytes": 3000}]})");
        Loaded w;
        QVERIFY(w.load(true));
        QObject *settings = w.engine.singletonInstance<QObject *>("Conestructor", "Settings");
        QObject *team = w.engine.singletonInstance<QObject *>("Conestructor", "TeamServer");
        auto restore = qScopeGuard([settings]() { settings->setProperty("teamCode", QString()); });
        settings->setProperty("teamCode", teamCodeFor(QStringLiteral("Our team"), QUrl(), server.base()));
        QMetaObject::invokeMethod(w.window, "openFromTeam");
        QObject *dialog = w.window->findChild<QObject *>(QStringLiteral("teamTracksDialog"));
        QTRY_VERIFY(findText(w.window, QStringLiteral("Duck pond")));
        server.silent = true;                                  // the download never answers
        w.clickItem(w.named(QStringLiteral("teamOpenButton")));
        QTRY_VERIFY(team->property("busy").toBool());
        QTest::keyClick(w.window, Qt::Key_Escape);
        QTRY_VERIFY(!dialog->property("visible").toBool());
        QTRY_VERIFY(!team->property("busy").toBool());
        QTest::qWait(300);
        QCOMPARE(w.window->title(), QStringLiteral("Conestructor 0.6 — Untitled"));

        server.silent = false;
        QMetaObject::invokeMethod(w.window, "openFromTeam");
        QTRY_VERIFY(dialog->property("opened").toBool());
        QTRY_VERIFY(findText(w.window, QStringLiteral("Duck pond")));
        QVERIFY(w.named(QStringLiteral("teamOpenButton"))->isEnabled());
    }
```

Add `#include <QDateTime>` and `#include <QFileInfo>` after `#include <QDir>` at the top of the file.

- [ ] **Step 2: Build and run them to see them fail**

Run: `powershell -NoProfile -File app\tests\build.ps1`, then `powershell -NoProfile -File app\tests\run.ps1 -NoQml -R tst_qmlload`
Expected: FAIL — `openFromTeam`/`uploadToTeam` do not exist on the window (invokeMethod returns false), and `uploadDialog`/`teamTracksDialog` are not found (a null dereference stops the run: that is the failure).

- [ ] **Step 3: The Team tracks dialog**

Create `app/qml/TeamTracksDialog.qml`:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor

// File › Open from team: the team's tracks, newest first, each with its thumbnail, name, cone count and upload time.
// Open (or a double-click) downloads the chosen one; Main opens it with no file. Closing the dialog stops a download.
Dialog {
    id: dialog
    objectName: "teamTracksDialog"
    title: qsTr("Team tracks: %1").arg(TeamServer.teamName)
    modal: true
    focus: true
    implicitWidth: 560      // fixed: Fusion's Dialog sizing loops with a custom button box
    anchors.centerIn: Overlay.overlay

    // A downloaded track (TeamServer.downloaded's `read`) to open under its name.
    signal openTrack(var read, string name)

    property string statusText: ""      // "Connecting…", an error, the empty-team line, or "" once listed
    property bool downloading: false
    property string downloadName: ""
    property var thumbs: ({})           // track id → thumbnail URL, for this session

    ListModel { id: tracksModel }

    function openList() {
        open()
        refresh()
    }

    function refresh() {
        tracksModel.clear()
        list.currentIndex = -1
        statusText = qsTr("Connecting…")
        TeamServer.listTracks()
    }

    function openChosen() {
        if (downloading || list.currentIndex < 0)
            return
        const chosen = tracksModel.get(list.currentIndex)
        downloadName = chosen.name
        downloading = true
        progress.value = 0
        statusText = ""
        TeamServer.download(chosen.trackId)
    }

    onClosed: {
        if (downloading) {
            downloading = false
            TeamServer.cancel()
        }
    }

    Connections {
        target: TeamServer
        function onTracksListed(ok, tracks, error) {
            if (!dialog.visible)
                return
            tracksModel.clear()
            if (!ok) {
                dialog.statusText = error
                return
            }
            for (const t of tracks) {
                tracksModel.append({ trackId: t.id, name: t.name, cones: t.cones, uploadedText: t.uploadedText })
                if (dialog.thumbs[t.id] === undefined)
                    TeamServer.fetchThumbnail(t.id)
            }
            dialog.statusText = tracks.length === 0
                ? qsTr("No tracks on the team yet. File › Upload to team shares the open track.") : ""
            list.currentIndex = tracks.length > 0 ? 0 : -1
        }
        function onThumbnailReady(id, url) {
            const next = Object.assign({}, dialog.thumbs)
            next[id] = url.toString()
            dialog.thumbs = next
        }
        function onDownloadProgress(received, total) {
            progress.value = total > 0 ? received / total : 0
        }
        function onDownloaded(ok, read, error) {
            if (!dialog.downloading)
                return                  // closed meanwhile: nothing opens
            dialog.downloading = false
            if (!ok) {
                dialog.statusText = error
                return
            }
            dialog.close()
            dialog.openTrack(read, dialog.downloadName)
        }
    }

    ColumnLayout {
        width: dialog.availableWidth
        spacing: 8

        Label {
            objectName: "teamTracksStatus"
            visible: text !== ""
            text: dialog.statusText
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: "#e0e0e0"
        }

        ListView {
            id: list
            objectName: "teamTrackList"
            Layout.fillWidth: true
            Layout.preferredHeight: 380
            clip: true
            model: tracksModel
            delegate: ItemDelegate {
                id: row
                required property int index
                required property int trackId
                required property string name
                required property int cones
                required property string uploadedText
                width: ListView.view.width
                height: 76
                highlighted: ListView.isCurrentItem
                onClicked: list.currentIndex = index
                onDoubleClicked: {
                    list.currentIndex = index
                    dialog.openChosen()
                }
                contentItem: RowLayout {
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 64
                        color: "#1b1b1b"
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            source: dialog.thumbs[row.trackId] || ""
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: row.name
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: qsTr("%1 cones · %2").arg(row.cones).arg(row.uploadedText)
                            color: "#b0b0b0"
                        }
                    }
                }
            }
        }

        RowLayout {
            visible: dialog.downloading
            Layout.fillWidth: true
            Label { text: qsTr("Downloading %1").arg(dialog.downloadName) }
            ProgressBar {
                id: progress
                objectName: "teamDownloadProgress"
                Layout.fillWidth: true
            }
        }
    }

    footer: DialogButtonBox {
        Button {
            objectName: "teamRefreshButton"
            text: qsTr("Refresh")
            enabled: !dialog.downloading
            DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            onClicked: dialog.refresh()
        }
        Button {
            objectName: "teamOpenButton"
            text: qsTr("Open")
            enabled: list.currentIndex >= 0 && !dialog.downloading
            DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            onClicked: dialog.openChosen()
        }
        Button {
            text: qsTr("Cancel")
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
    }
}
```

- [ ] **Step 4: The Upload dialog**

Create `app/qml/UploadDialog.qml`:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Conestructor

// File › Upload to team: shows the thumbnail and asks. The name starts as the track's (blank for an Untitled one) and
// changes only the uploaded copy. Upload shows progress; Cancel stops it; an error shows here and the dialog stays open.
Dialog {
    id: dialog
    objectName: "uploadDialog"
    title: qsTr("Upload to team")
    modal: true
    focus: true
    implicitWidth: 460      // fixed: Fusion's Dialog sizing loops with a custom button box
    anchors.centerIn: Overlay.overlay

    // Uploaded under this name.
    signal sent(string name)

    property url thumbnail: ""
    property int coneCount: 0
    property bool sending: false
    property string errorText: ""

    // `uploadResult`: the cones the upload carries (TrackStore.uploadResult).
    function ask(uploadResult) {
        coneCount = uploadResult.cones.length
        thumbnail = TeamServer.makeThumbnail(TrackStore.photoRef(), TrackStore.mpp, uploadResult.canvasCones)
        nameField.text = TrackStore.filePath === "" && !TrackStore.fromTeam ? "" : TrackStore.name
        errorText = ""
        progress.value = 0
        open()
        nameField.forceActiveFocus()
    }

    function send() {
        const name = nameField.text.trim()
        if (name === "" || sending)
            return
        sending = true
        errorText = ""
        TeamServer.upload(TrackStore.documentText(name), TrackStore.photoRef(), thumbnail)
    }

    onClosed: {
        if (sending) {
            sending = false
            TeamServer.cancel()
        }
    }

    Connections {
        target: TeamServer
        function onUploadProgress(done, total) {
            progress.value = total > 0 ? done / total : 0
        }
        function onUploaded(ok, error) {
            if (!dialog.sending)
                return
            dialog.sending = false
            if (ok) {
                const name = nameField.text.trim()
                dialog.close()
                dialog.sent(name)
            } else {
                dialog.errorText = error
            }
        }
    }

    ColumnLayout {
        width: dialog.availableWidth
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            color: "#1b1b1b"
            Image {
                objectName: "uploadThumbnail"
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                cache: false
                source: dialog.thumbnail
            }
        }
        TextField {
            id: nameField
            objectName: "uploadName"
            Layout.fillWidth: true
            placeholderText: qsTr("Name this track")
            enabled: !dialog.sending
            onAccepted: dialog.send()
        }
        Label {
            objectName: "uploadQuestion"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Upload %1 (%2 cones) to %3? Teammates will be able to open it.")
                  .arg(nameField.text.trim() !== "" ? nameField.text.trim() : qsTr("this track"))
                  .arg(dialog.coneCount).arg(TeamServer.teamName)
        }
        ProgressBar {
            id: progress
            objectName: "uploadProgress"
            visible: dialog.sending
            Layout.fillWidth: true
        }
        Label {
            objectName: "uploadError"
            visible: text !== ""
            text: dialog.errorText
            color: "#ff6b6b"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    footer: DialogButtonBox {
        Button {
            objectName: "uploadButton"
            text: qsTr("Upload")
            enabled: nameField.text.trim() !== "" && !dialog.sending
            DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            onClicked: dialog.send()
        }
        Button {
            text: qsTr("Cancel")
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
    }
}
```

In `app/CMakeLists.txt`, add `        qml/TeamTracksDialog.qml` and `        qml/UploadDialog.qml` to `QML_FILES` after `qml/CarOutline.qml`.

- [ ] **Step 5: `Main.qml`: the menu items and the dialogs**

In `app/qml/Main.qml`:
- Add after `function openRecent(path) { ... }`:

```qml
    readonly property string noCodeHint: qsTr("Paste your team code to use team tracks.")

    // File › Open from team: asks about unsaved changes first; without a team code, Preferences at Team.
    function openFromTeam() {
        if (!TeamServer.hasCode) {
            preferences.openAtTeam(noCodeHint)
            return
        }
        whenSaved(() => teamTracksDialog.openList())
    }

    // File › Upload to team: the track must process; it is sent as it is now, with no save first.
    function uploadToTeam() {
        if (!TeamServer.hasCode) {
            preferences.openAtTeam(noCodeHint)
            return
        }
        const result = TrackStore.uploadResult()
        if (result)
            uploadDialog.ask(result)
    }

    function openTeamTrack(read, name) {
        if (TrackStore.openFromTeam(read, name))
            fitSoon()
    }
```

- In the File menu, add after the `&Open…` action:

```qml
            Action { text: qsTr("Open from &team…"); shortcut: "Ctrl+Shift+O"; onTriggered: window.openFromTeam() }
```

  and after the `Save &As…` action:

```qml
            MenuSeparator {}
            Action { text: qsTr("&Upload to team…"); onTriggered: window.uploadToTeam() }
```

- Add after `PreferencesDialog { id: preferences }`:

```qml

    TeamTracksDialog {
        id: teamTracksDialog
        onOpenTrack: (read, name) => window.openTeamTrack(read, name)
    }

    UploadDialog {
        id: uploadDialog
        onSent: (name) => TrackStore.message = qsTr("Uploaded %1 to %2").arg(name).arg(TeamServer.teamName)
    }
```

- [ ] **Step 6: Build and run the tests**

Run: `powershell -NoProfile -File app\tests\build.ps1`, then `powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`; `qml: 382 passed, 0 failed`.

If `aDownloadStopsWhenTheDialogCloses` fails because Escape does not close the dialog, check that `focus: true` is on the `Dialog` (a popup without focus ignores Escape); do not replace the key press with a call to `close()`, which would hide the problem a person would meet.

- [ ] **Step 7: Commit**

```bash
git add app/qml/TeamTracksDialog.qml app/qml/UploadDialog.qml app/qml/Main.qml app/CMakeLists.txt app/tests/tst_qmlload.cpp
git commit -m "File › Open from team (the team's tracks with thumbnails; opens with no file) and File › Upload to team (thumbnail, name, progress, one upload at a time)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Part 4's minors 1, 2, 3 and 5

**Files:**
- Modify: `app/qml/CanvasView.qml` (minor 1)
- Modify: `app/qml/Main.qml` (minor 2: `editMenu` objectName, Duplicate and Reverse direction enabled)
- Modify: `app/qml/logic/conefile.mjs` (`readTouchUps`, minor 3)
- Test: `app/tests/tst_qmlload.cpp` (minors 1, 2), `app/tests/qml/tst_conefile.qml` (minor 3), `app/tests/qml/tst_elements.qml` (minor 5)

**Interfaces:**
- Consumes: `TrackStore.locked`, `Touchups.changes`, `Elements.conesWorld`, `Elements.pathWorld` (existing).
- Produces: nothing new for other tasks.

- [ ] **Step 1: Write the failing tests**

Add at the end of `TestQmlLoad` in `app/tests/tst_qmlload.cpp`:

```cpp
    // Part 4's minor 1: a track piece in hand is put back when touch-ups lock the track.
    void aPieceInHandIsPutBackWhenTheTrackLocks()
    {
        Loaded w;
        QVERIFY(w.load(true));
        QMetaObject::invokeMethod(w.window, "placeCones");
        w.clickItem(w.tile(QStringLiteral("straight")));
        QCOMPARE(w.canvas->property("placingKind").toString(), QStringLiteral("straight"));
        w.run(QStringLiteral("deleteCones"), { { "indices", QVariantList{ 0 } } });
        QVERIFY(w.store->property("locked").toBool());
        QCOMPARE(w.canvas->property("placingKind").toString(), QString());
        QCOMPARE(w.canvas->property("placingBy").toString(), QString());
    }

    // Part 4's minor 2: Edit › Duplicate and Reverse direction are greyed while the track is locked.
    void lockingGreysDuplicateAndReverse()
    {
        Loaded w;
        QVERIFY(w.load(true));
        QObject *menu = w.window->findChild<QObject *>(QStringLiteral("editMenu"));
        QVERIFY(menu);
        const auto enabledNow = [&](const QString &text) {
            QMetaObject::invokeMethod(w.store, "select", Q_ARG(QVariant, QStringLiteral("e1")));
            QMetaObject::invokeMethod(menu, "open");
            QQuickItem *item = nullptr;
            QTest::qWaitFor([&]() { return (item = findMenuItem(w.window, text)) != nullptr; });
            const bool enabled = item && item->isEnabled();
            QMetaObject::invokeMethod(menu, "close");
            QTest::qWaitFor([&]() { return !menu->property("visible").toBool(); });
            return enabled;
        };
        QVERIFY(enabledNow(QStringLiteral("Duplicate")));
        QVERIFY(enabledNow(QStringLiteral("Reverse direction")));
        QMetaObject::invokeMethod(w.window, "placeCones");
        w.run(QStringLiteral("deleteCones"), { { "indices", QVariantList{ 0 } } });
        QVERIFY(w.store->property("locked").toBool());
        QVERIFY(!enabledNow(QStringLiteral("Duplicate")));
        QVERIFY(!enabledNow(QStringLiteral("Reverse direction")));
    }
```

Add to `app/tests/qml/tst_conefile.qml`, after `test_aTouchedUpTrackComesBackLocked` (and add `import "../../qml/logic/touchups.mjs" as Touchups` with the other imports):

```js
    // Part 4's minor 3: a hand-edited placed count below the cones still carrying an element is raised to it, so the
    // change count is never negative.
    function test_thePlacedCountIsNeverBelowTheKeptCones() {
        const d = doc(touchedUp())
        d.design.touchUps.placed = 2
        const back = ConeFile.fromDocument(d, -1).track
        const kept = back.touchUps.cones.filter(c => c.element !== null).length
        compare(back.touchUps.placed, kept)
        compare(Touchups.changes(back.touchUps), back.touchUps.cones.filter(c => c.edited).length)
    }
```

Add to `app/tests/qml/tst_elements.qml`, after `test_outsideConesOnATurn`:

```js
    // Part 4's minor 5: the outside cones lie on the outer side of the arc, whichever way the turn goes. The inside
    // (leaning) cones' middle lies inside the arc, so an outside cone is further from it than the centreline point
    // nearest to that cone.
    function test_outsideConesAreOnTheOuterSide_data() {
        return [{ tag: "right", direction: "right" }, { tag: "left", direction: "left" }]
    }
    function test_outsideConesAreOnTheOuterSide(row) {
        const off = Elements.conesWorld(placed("turn", { direction: row.direction }))
        const onEl = placed("turn", { direction: row.direction, outsideCones: "on" })
        const on = Elements.conesWorld(onEl)
        const added = on.filter(c => !off.some(o => Math.hypot(o.x - c.x, o.y - c.y) < 1e-9))
        verify(added.length > 0)
        const inside = off.filter(c => c.type === "leaning")
        const mid = { x: inside.reduce((s, c) => s + c.x, 0) / inside.length,
                      y: inside.reduce((s, c) => s + c.y, 0) / inside.length }
        const path = Elements.pathWorld(onEl)
        for (const c of added) {
            let nearest = path[0]
            for (const p of path)
                if (Math.hypot(p.x - c.x, p.y - c.y) < Math.hypot(nearest.x - c.x, nearest.y - c.y))
                    nearest = p
            verify(Math.hypot(c.x - mid.x, c.y - mid.y) > Math.hypot(nearest.x - mid.x, nearest.y - mid.y),
                   "an outside cone at " + c.x.toFixed(2) + ", " + c.y.toFixed(2) + " sits inside the centreline")
        }
    }
```

- [ ] **Step 2: Run them to see the right ones fail**

Run: `powershell -NoProfile -File app\tests\build.ps1`, then `powershell -NoProfile -File app\tests\run.ps1`
Expected: `aPieceInHandIsPutBackWhenTheTrackLocks` FAILS (placingKind is still "straight"); `lockingGreysDuplicateAndReverse` FAILS (`editMenu` not found); `test_thePlacedCountIsNeverBelowTheKeptCones` FAILS (placed stays 2). `test_outsideConesAreOnTheOuterSide` PASSES at once: minor 5 was a missing check, and the part 4 reviewer confirmed the geometry. To see that it can fail, swap `>` for `<` in its `verify` once, run `run.ps1 -NoCpp -Qml tst_elements.qml` (it must fail), and put `>` back.

- [ ] **Step 3: Minor 1**

In `app/qml/CanvasView.qml`, add after the line `onSetupDoneChanged: if (!setupDone && Elements.TYPES.indexOf(placingKind) >= 0) cancelPlacing()`:

```qml
    // Touch-ups lock the track: a track piece, the ruler or a target in hand is put back (part 4's minor 1), since the
    // next click would be refused and selectLast would pick an unrelated element. An added cone stays in hand.
    readonly property bool trackLocked: TrackStore.locked
    onTrackLockedChanged: if (trackLocked && placingKind !== "" && placingKind !== "cone") cancelPlacing()
```

- [ ] **Step 4: Minor 2**

In `app/qml/Main.qml`, in the Edit menu: add `objectName: "editMenu"` after `id: editMenu`; change the Duplicate action's `enabled: TrackStore.selectedElements.length > 0` to `enabled: TrackStore.selectedElements.length > 0 && !TrackStore.locked`, and the same for Reverse direction.

- [ ] **Step 5: Minor 3**

In `app/qml/logic/conefile.mjs`, replace the end of `readTouchUps`:

```js
    return { placed: Math.max(0, Math.round(v.placed)), cones: cones }
```

with

```js
    // A hand edit may say fewer were placed than the cones still carrying an element: the count of changes would go
    // below zero, so the placed count is raised to them (part 4's minor 3).
    const kept = cones.filter(c => c.element !== null).length
    return { placed: Math.max(kept, Math.round(v.placed)), cones: cones }
```

- [ ] **Step 6: Run the tests**

Run: `powershell -NoProfile -File app\tests\build.ps1`, then `powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`; `qml: N passed, 0 failed`, N above 382 (the conefile test and the elements test's two rows are new; note N for Task 11).

- [ ] **Step 7: Commit**

```bash
git add app/qml/CanvasView.qml app/qml/Main.qml app/qml/logic/conefile.mjs app/tests/tst_qmlload.cpp app/tests/qml/tst_conefile.qml app/tests/qml/tst_elements.qml
git commit -m "Part 4's minors: a piece in hand is put back when the track locks; Duplicate and Reverse greyed while locked; a hand-edited placed count never makes the change count negative; outside cones checked to be on the outer side" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: README, the whole suite, a clean clone and the push check

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above.
- Produces: the branch ready for the final review.

- [ ] **Step 1: README**

In `README.md`:
- Replace the status block at the top (from `> **v1 in progress.** Parts 1 to 4 of 6 are done:` to `A full guide comes with v1.0.0.`) with:

```markdown
> **v1 in progress.** Parts 1 to 5 of 6 are done: the core canvas (metres underneath, zoom and pan, undo, units, cone
> preview); setup and track files (a setup checklist, `.cone` files with the photo inside, direction arrows, Reverse
> direction, typed rotation, multi-select); ease of use (a coach card through setup, click-to-place, gate nodes that
> pivot and stretch, a fold warning, turns up to 360°, a line tool for walls); cones (a density slider with five
> notches and per-element overrides, outside cones on turns, the cone count against the cones the team owns, touch-ups
> of single cones after placing them, a true-size car outline); and team tracks (a team server, a team code in
> Preferences, Upload to team and Open from team). A full guide comes with v1.0.0.
```

- Add a section after `## Track files` (before `## Build`):

```markdown
## Team tracks

A team can share its tracks through a small server (`server/`: Flask and MySQL, behind nginx). Paste the team code your
team's admin gives you into Edit › Preferences › Team; File › Upload to team then shares the open track, and
File › Open from team lists the team's tracks, each with a thumbnail. The app tries the server on the local network
first, then over the internet. Treat the team code like a password: whoever has it can open your team's tracks and add
to them. Without a code the app works fully on its own. Running the server: [server/README.md](server/README.md).
```

- In `## Build`, change `Qt 6.8 or newer (Quick, Quick Controls, Shapes, Svg)` to `Qt 6.8 or newer (Quick, Quick Controls, Shapes, Svg, Network)`.
- In `## Layout`, replace the line `` - `coneRoutes.py`: the server's Flask routes for uploaded tracks (moves to `server/` in part 5). `` with:

```markdown
- `server/`: the team server (Flask blueprints for the team API and the LAN-only admin API, the schema, the admin
  script, a smoke test and a live check), tested with pytest.
```

  and change `` `services/` is a little C++ (settings, photos, track files). `` to `` `services/` is a little C++ (settings, photos, track files, the team server). ``

- [ ] **Step 2: The whole suite**

Run: `powershell -NoProfile -File app\tests\build.ps1`, then `powershell -NoProfile -File app\tests\run.ps1`
Expected: `ctest: passed`; `qml: N passed, 0 failed` with Task 10's N.

Run (from `server\`): `.venv\Scripts\python.exe -m pytest -q`
Expected: every test passes.

- [ ] **Step 3: A clean clone builds without the map images**

```powershell
Remove-Item -Recurse -Force "$env:TEMP\cc-p5" -ErrorAction SilentlyContinue
git clone --branch part5-team-server . "$env:TEMP\cc-p5"
Test-Path "$env:TEMP\cc-p5\app\assets\images\duckPondBirdeye.png"     # must print False
powershell -NoProfile -File "$env:TEMP\cc-p5\app\tests\build.ps1"
powershell -NoProfile -File "$env:TEMP\cc-p5\app\tests\run.ps1"
Remove-Item -Recurse -Force "$env:TEMP\cc-p5"
```

Expected: the build succeeds and both stages pass in the clone.

- [ ] **Step 4: The push check**

The words to look for (the LAN address, the public domain, the server's hostname) must not be written in the repo
either, so they live in `push-check-patterns.txt` in the session's shared notes folder, outside the repo, one
extended regular expression per line. `$PATTERNS` below is that file's full path. (Git Bash's `grep -f` aborts on
it, so the lines are joined into one expression.)

```bash
git diff --stat main...part5-team-server
git ls-files server | grep -E "coneAdminConfig\.json$|coneAdmin\.local\.json$|\.venv|__pycache__" ; echo "exit $?"
git grep -n -i -E -f "$PATTERNS" part5-team-server -- . ; echo "exit $?"
git log --format=%B main..part5-team-server | grep -i -E "$(paste -sd'|' "$PATTERNS")" ; echo "exit $?"
echo "a test line with $(head -1 "$PATTERNS" | tr -d '\\')" | grep -c -i -E "$(paste -sd'|' "$PATTERNS")"
```

Expected: the `ls-files` and both greps find nothing (each prints only `exit 1`); the last line prints `1`, which shows
the patterns were read. Any hit means stop and remove it before going on. Also read `git diff main...part5-team-server -- server/README.md server/coneAdminConfig.example.json` and check every address there is `<LAN address>`, `<public host>`, `lan.example` or `public.example`.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "README: part 5 status, team tracks, server/ in the layout" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Final review, rollout and the owner's check

Nothing here is merged or pushed until the owner's check passes. Each server step waits for the owner's go-ahead at the time it is reached; the owner runs every `sudo` step.

- [ ] **Step 1: Final whole-branch review** on the most capable model, against the spec and this plan. Fix what it finds (test first), and keep its rulings and any deferred minors in the shared notes.

- [ ] **Step 2: Rollout**, step by step as `server/README.md` "Rollout" says: check (read only), smoke test on `cone_smoke`, cut-over, register the admin blueprint, nginx, make the team, live check. Every smoke and live-check line `PASS`. The team code is never written into the repo, the notes or a commit message.

- [ ] **Step 3: The owner's check** (about 15 minutes, on the branch's build): paste the team code and Check it; upload a track and see it in the list with its thumbnail; open it from the team and save it; upload the same name again and see two entries; do the same over the internet (a phone hotspot, for example); with `coneAdmin.py`, list the tracks and delete one; clear the code and see the team items lead to Preferences.

- [ ] **Step 4: Merge and push.** Fast-forward `main` to the branch (or merge), run `app\tests\run.ps1` and the server's pytest on the merged result, repeat Task 11's push check on `main`, push `main`, delete `part5-team-server`.
