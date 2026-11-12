cmake_minimum_required(VERSION 3.16)

project(Conestructor VERSION 0.5.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Svg)

qt_standard_project_setup(REQUIRES 6.8)

# Satellite pictures of local practice lots are kept out of the public repo (map imagery can't be republished);
# bundle them only when present.
set(CONESTRUCTOR_LOCAL_BACKGROUNDS)
set(CONESTRUCTOR_LOCAL_BACKGROUND_FILES)
foreach(bg duckPondBirdeye riverwindBirdeye)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/images/${bg}.png")
        list(APPEND CONESTRUCTOR_LOCAL_BACKGROUNDS ${bg})
        list(APPEND CONESTRUCTOR_LOCAL_BACKGROUND_FILES assets/images/${bg}.png)
    endif()
endforeach()
string(JOIN "," CONESTRUCTOR_BACKGROUND_LIST ${CONESTRUCTOR_LOCAL_BACKGROUNDS})

# The QML module and the small C++ services live in a static library, so the tests load the real thing.
set_source_files_properties(qml/TrackStore.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_library(conestructor_core STATIC)
qt_add_qml_module(conestructor_core
    URI Conestructor
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/TrackStore.qml
        qml/CanvasView.qml
        qml/ElementView.qml
        qml/StatusBar.qml
        qml/ErrorBanner.qml
        qml/ElementPalette.qml
        qml/SetupChecklist.qml
        qml/PaletteTile.qml
        qml/RulerView.qml
        qml/TargetsView.qml
        qml/ConePreview.qml
        qml/PropField.qml
        qml/PropertyPanel.qml
        qml/PreferencesDialog.qml
        qml/RulerLengthBox.qml
        qml/CoachCard.qml
        qml/logic/units.mjs
        qml/logic/conerows.mjs
        qml/logic/elements.mjs
        qml/logic/snapping.mjs
        qml/logic/commands.mjs
        qml/logic/frame.mjs
        qml/logic/postprocess.mjs
        qml/logic/viewport.mjs
        qml/logic/demo.mjs
        qml/logic/selection.mjs
        qml/logic/setup.mjs
        qml/logic/conefile.mjs
        qml/logic/nodes.mjs
        qml/logic/density.mjs
        qml/logic/touchups.mjs
    SOURCES
        services/AppInfo.h
        services/Settings.h services/Settings.cpp
        services/TrackFile.h services/TrackFile.cpp
        services/PhotoStore.h services/PhotoStore.cpp
    RESOURCES
        assets/images/blueprintBackground.png
        assets/images/crosshair.svg
        assets/images/upright-cone.png
        assets/images/sideways-cone.png
        ${CONESTRUCTOR_LOCAL_BACKGROUND_FILES}
)
# The generated type registration includes each header by its bare name.
target_include_directories(conestructor_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/services)
target_compile_definitions(conestructor_core PUBLIC
    CONESTRUCTOR_VERSION="${PROJECT_VERSION}"
    CONESTRUCTOR_BACKGROUNDS="${CONESTRUCTOR_BACKGROUND_LIST}"
)
target_link_libraries(conestructor_core PUBLIC Qt6::Quick Qt6::QuickControls2)

qt_add_executable(appConestructor main.cpp)
target_link_libraries(appConestructor PRIVATE conestructor_coreplugin conestructor_core Qt6::Quick Qt6::QuickControls2 Qt6::Svg)
set_target_properties(appConestructor PROPERTIES WIN32_EXECUTABLE TRUE MACOSX_BUNDLE TRUE)

include(GNUInstallDirs)
install(TARGETS appConestructor
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

option(CONESTRUCTOR_BUILD_TESTS "Build the tests" OFF)
if(CONESTRUCTOR_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
