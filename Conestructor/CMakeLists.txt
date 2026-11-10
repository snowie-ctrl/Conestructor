cmake_minimum_required(VERSION 3.16)

project(Conestructor VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Svg)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appConestructor
    main.cpp
    exportmanager.h exportmanager.cpp
)

set_source_files_properties(
    qml/AppState.qml
    qml/PostProcessor.qml
    PROPERTIES
        QT_QML_SINGLETON_TYPE TRUE
)

# Satellite backgrounds of local practice lots are kept out of the public
# repo (map imagery can't be republished); bundle them only when present.
set(CONESTRUCTOR_LOCAL_BACKGROUNDS)
foreach(bg duckPondBirdeye riverwindBirdeye)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/images/${bg}.png")
        list(APPEND CONESTRUCTOR_LOCAL_BACKGROUNDS assets/images/${bg}.png)
    endif()
endforeach()

qt_add_qml_module(appConestructor
    URI Conestructor
    QML_FILES
        qml/Main.qml
        qml/AppState.qml
        qml/PostProcessor.qml

        qml/elements/ConeUtils.js

        qml/CanvasArea.qml
        qml/ElementPanel.qml
        qml/PropertyPanel.qml

        qml/ElementSpawner.qml

        qml/elements/Element.qml
        qml/elements/Chicane.qml
        qml/elements/Hairpin.qml
        qml/elements/Ruler.qml
        qml/elements/Slalom.qml
        qml/elements/Straight.qml
        qml/elements/Target.qml

    RESOURCES
        assets/images/blueprintBackground.png
        ${CONESTRUCTOR_LOCAL_BACKGROUNDS}

        assets/images/crosshair.svg

        assets/images/upright-cone.png
        assets/images/sideways-cone.png
)





# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appConestructor PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appConestructor
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appConestructor
    PRIVATE Qt6::Quick Qt6::Svg
)

include(GNUInstallDirs)
install(TARGETS appConestructor
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
