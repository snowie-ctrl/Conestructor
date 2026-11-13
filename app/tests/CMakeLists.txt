find_package(Qt6 REQUIRED COMPONENTS Test Qml Quick QuickControls2)

# One test executable: its sources, the libraries beyond Qt Test, and a ctest entry. Console programs, so their
# output reaches ctest; offscreen, so no window reaches the owner's screen.
function(conestructor_test name)
    cmake_parse_arguments(T "" "" "SOURCES;LIBS" ${ARGN})
    qt_add_executable(${name} ${T_SOURCES})
    target_link_libraries(${name} PRIVATE Qt6::Test ${T_LIBS})
    set_target_properties(${name} PROPERTIES WIN32_EXECUTABLE FALSE MACOSX_BUNDLE FALSE)
    add_test(NAME ${name} COMMAND ${name})
    set_tests_properties(${name} PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
endfunction()

conestructor_test(tst_qmlload
    SOURCES tst_qmlload.cpp fakehttp.h
    LIBS conestructor_coreplugin Qt6::Qml Qt6::Quick Qt6::QuickControls2)

conestructor_test(tst_settings SOURCES tst_settings.cpp LIBS conestructor_core)
conestructor_test(tst_trackfile SOURCES tst_trackfile.cpp LIBS conestructor_core)
conestructor_test(tst_photostore SOURCES tst_photostore.cpp LIBS conestructor_core)
conestructor_test(tst_teamserver SOURCES tst_teamserver.cpp fakehttp.h LIBS conestructor_core)
