# - Try to find an installed version of Qt based on QT_VERSION
# Once done this will define
#
# Qt4or5_FOUND - The specified Qt version was found
# Qt4or5_<Component>_FOUND - For each <Component> specified, if found
# QT_QMAKE_EXECUTABLE - Path to qmake
# QT_IMPORTS_DIR - Path to qtquick1 imports dir
#
# Use qt4or5_use_modules(target [ LINK_PUBLIC | LINK_PRIVATE ] <modules>)
# to make use of Qt4 or Qt5 on a target
#
# https://github.com/tswindell/qt-gstreamer

set(Qt4_MIN_VERSION 4.7)
set(Qt5_MIN_VERSION 5.0)

set(QT_VERSION "5" CACHE STRING "Expected Qt version used for the build")
set_property(CACHE QT_VERSION PROPERTY STRINGS 4 5)

if(NOT(QT_VERSION VERSION_EQUAL "4" OR QT_VERSION VERSION_EQUAL "5"))
    message(FATAL_ERROR "Expected value for QT_VERSION is either '4' or '5'")
endif()

if(${QT_VERSION} STREQUAL "5")
    set(USE_QT5 TRUE)
elseif(${QT_VERSION} STREQUAL "4")
    set(USE_QT4 TRUE)
endif()

macro(_qt4or5_component_name_to_qt_component qt_component component)
    if(${component} STREQUAL "Widgets" AND ${QT_VERSION} STREQUAL "4")
        set(${qt_component} "Gui")
    elseif(${component} STREQUAL "Quick1")
        set(${qt_component} "Declarative")
    elseif(${component} STREQUAL "Quick2" AND ${QT_VERSION} STREQUAL "5")
        set(${qt_component} "Quick")
    else()
        set(${qt_component} ${component})
    endif()
endmacro()

macro(_qt4or5_component_name_from_qt_component component qt_component)
    if(${qt_component} STREQUAL "Declarative")
        set(${component} "Quick1")
    elseif(${qt_component} STREQUAL "Quick")
        set(${component} "Quick2")
    else()
        set(${component} ${qt_component})
    endif()
endmacro()

macro(_qt4or5_component_names_to_qt_components output_list)
    foreach(module ${ARGN})
        _qt4or5_component_name_to_qt_component(qt_component ${module})
        list(APPEND ${output_list} ${qt_component})
        unset(qt_component)
    endforeach()

    list(REMOVE_DUPLICATES ${output_list})
endmacro()

if(Qt4or5_FIND_QUIETLY)
    set(_Qt4or5_FIND_PACKAGE_ARGS QUIET)
endif()

_qt4or5_component_names_to_qt_components(_Qt4or5_FIND_COMPONENTS ${Qt4or5_FIND_COMPONENTS})
_qt4or5_component_names_to_qt_components(_Qt4or5_FIND_COMPONENTS ${Qt4or5_FIND_OPTIONAL_COMPONENTS})

if(${QT_VERSION} STREQUAL "5")
    set(Qt4or5_MIN_VERSION "${Qt5_MIN_VERSION}")

    if(NOT Qt4or5_FIND_QUIETLY)
        message(STATUS "Using Qt5 (min qt version: ${Qt4or5_MIN_VERSION})")
    endif()

    # Find Qt5 modules
    foreach(qt_component ${_Qt4or5_FIND_COMPONENTS})
        find_package(Qt5${qt_component} ${Qt5_MIN_VERSION} ${_Qt4or5_FIND_PACKAGE_ARGS})

        if(Qt5${qt_component}_FOUND)
            _qt4or5_component_name_from_qt_component(component ${qt_component})
            set(Qt4or5_${component}_FOUND TRUE)
            unset(component)
        endif()
    endforeach()

    set(_Qt4or5_FOUND ${Qt5Core_FOUND})

    # Set QT_QMAKE_EXECUTABLE, QT_IMPORTS_DIR and QT_QML_DIR
    if(Qt5Core_FOUND)
        get_target_property(QT_QMAKE_EXECUTABLE ${Qt5Core_QMAKE_EXECUTABLE} IMPORTED_LOCATION)

        function(_QT5_QUERY_QMAKE VAR RESULT)
            execute_process(COMMAND "${QT_QMAKE_EXECUTABLE}" -query ${VAR}
                RESULT_VARIABLE return_code
                OUTPUT_VARIABLE output
                OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_STRIP_TRAILING_WHITESPACE)

            if(NOT return_code)
                file(TO_CMAKE_PATH "${output}" output)
                set(${RESULT} ${output} PARENT_SCOPE)
            endif()
        endfunction()

        _qt5_query_qmake(QT_INSTALL_IMPORTS QT_IMPORTS_DIR)
        _qt5_query_qmake(QT_INSTALL_QML QT_QML_DIR)
    endif()

    function(qt5_use_modules _target _link_type)
        if(NOT TARGET ${_target})
            message(FATAL_ERROR "The first argument to qt5_use_modules must be an existing target.")
        endif()

        if("${_link_type}" STREQUAL "LINK_PUBLIC" OR "${_link_type}" STREQUAL "LINK_PRIVATE")
            set(_qt5_modules ${ARGN})
            set(_qt5_link_type ${_link_type})
        else()
            set(_qt5_modules ${_link_type} ${ARGN})
        endif()

        if("${_qt5_modules}" STREQUAL "")
            message(FATAL_ERROR "qt5_use_modules requires at least one Qt module to use.")
        endif()

        foreach(_module ${_qt5_modules})
            if(NOT Qt5${_module}_FOUND)
                find_package(Qt5${_module} PATHS "${_Qt5_COMPONENT_PATH}" NO_DEFAULT_PATH)

                if(NOT Qt5${_module}_FOUND)
                    message(FATAL_ERROR "Cannot use \"${_module}\" module which has not yet been found.")
                endif()
            endif()

            target_link_libraries(${_target} PRIVATE ${_qt5_link_type} ${Qt5${_module}_LIBRARIES})
            set_property(TARGET ${_target} APPEND PROPERTY INCLUDE_DIRECTORIES ${Qt5${_module}_INCLUDE_DIRS})
            set_property(TARGET ${_target} APPEND PROPERTY COMPILE_DEFINITIONS ${Qt5${_module}_COMPILE_DEFINITIONS})
            set_property(TARGET ${_target} APPEND PROPERTY COMPILE_DEFINITIONS_RELEASE QT_NO_DEBUG)
            set_property(TARGET ${_target} APPEND PROPERTY COMPILE_DEFINITIONS_RELWITHDEBINFO QT_NO_DEBUG)
            set_property(TARGET ${_target} APPEND PROPERTY COMPILE_DEFINITIONS_MINSIZEREL QT_NO_DEBUG)

            if(Qt5_POSITION_INDEPENDENT_CODE
                AND(NOT CMAKE_CXX_COMPILER_ID STREQUAL "GNU"
                OR CMAKE_CXX_COMPILER_VERSION VERSION_LESS 5.0))
                set_property(TARGET ${_target} PROPERTY POSITION_INDEPENDENT_CODE ${Qt5_POSITION_INDEPENDENT_CODE})
            endif()
        endforeach()
    endfunction()

    # Set pkg-config package names
    foreach(component Core Gui Widgets Quick1 Quick2 Test OpenGL)
        _qt4or5_component_name_to_qt_component(qt_component ${component})
        set(Qt4or5_${component}_PKGCONFIG_DEP "Qt5${qt_component}")
        unset(qt_component)
    endforeach()

elseif(${QT_VERSION} STREQUAL "4")
    set(Qt4or5_MIN_VERSION "${Qt4_MIN_VERSION}")

    if(NOT Qt4or5_FIND_QUIETLY)
        message(STATUS "Using Qt4 (min qt version: ${Qt4or5_MIN_VERSION})")
    endif()

    # Find Qt4
    set(QT_USE_IMPORTED_TARGETS TRUE)
    find_package(Qt4 ${Qt4_MIN_VERSION} ${_Qt4or5_FIND_PACKAGE_ARGS})

    set(_Qt4or5_FOUND ${QT4_FOUND})

    # set Qt4or5_Foo_FOUND
    foreach(qt_component ${_Qt4or5_FIND_COMPONENTS})
        string(TOUPPER ${qt_component} u_qt_component)

        if(QT_QT${u_qt_component}_FOUND)
            _qt4or5_component_name_from_qt_component(component ${qt_component})
            set(Qt4or5_${component}_FOUND TRUE)

            # special case for QtWidgets, which is part of QtGui in Qt4
            if(${component} STREQUAL "Gui")
                set(Qt4or5_Widgets_FOUND TRUE)
            endif()

            unset(component)
        endif()

        unset(u_qt_component)
    endforeach()

    # define or include qt4_use_modules()
    # copy-paste from Qt4Macros, just to support cmake 2.8.9
    # if(CMAKE_VERSION VERSION_LESS 2.8.10)
    function(qt4_use_modules _target _link_type)
        if("${_link_type}" STREQUAL "LINK_PUBLIC" OR "${_link_type}" STREQUAL "LINK_PRIVATE")
            set(modules ${ARGN})
            set(link_type ${_link_type})
        else()
            set(modules ${_link_type} ${ARGN})
        endif()

        foreach(_module ${modules})
            string(TOUPPER ${_module} _ucmodule)

            if(NOT QT_QT${_ucmodule}_FOUND)
                message(FATAL_ERROR "Can not use \"${_module}\" module which has not yet been found.")
            endif()

            if("${_ucmodule}" STREQUAL "MAIN")
                message(FATAL_ERROR "Can not use \"${_module}\" module with qt4_use_modules.")
            endif()

            target_link_libraries(${_target} PRIVATE ${link_type} ${QT_QT${_ucmodule}_LIBRARY})
            set_property(TARGET ${_target} APPEND PROPERTY INCLUDE_DIRECTORIES
                ${QT_QT${_ucmodule}_INCLUDE_DIR} ${QT_HEADERS_DIR} ${QT_MKSPECS_DIR}/default)
            set_property(TARGET ${_target} APPEND PROPERTY COMPILE_DEFINITIONS
                ${QT_QT${_ucmodule}_COMPILE_DEFINITIONS})
        endforeach()
    endfunction()

    # else()
    # include(Qt4Macros)
    # endif()

    # Set pkg-config package names
    foreach(component Core Gui Widgets Quick1 Quick2 Test OpenGL)
        _qt4or5_component_name_to_qt_component(qt_component ${component})
        set(Qt4or5_${component}_PKGCONFIG_DEP "Qt${qt_component}")
        unset(qt_component)
    endforeach()

else()
    message(WARNING "Unsupported QT_VERSION specified: ${QT_VERSION}")
    set(_Qt4or5_FOUND FALSE)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Qt4or5 REQUIRED_VARS _Qt4or5_FOUND HANDLE_COMPONENTS)
set(Qt4or5_FOUND ${QT4OR5_FOUND})

# Core library needed for compilation tests
if(${QT_VERSION} STREQUAL "4")
    set(Qt4or5_Core_LIBRARIES ${QT_QTCORE_LIBRARY})
else()
    set(Qt4or5_Core_LIBRARIES ${Qt5Core_LIBRARIES})
endif()

# qt4or5_use_modules(target [ LINK_PUBLIC | LINK_PRIVATE ] <modules>)
# Supported modules: Core, Gui, Widgets, Quick1, Quick2, Test, OpenGL
function(qt4or5_use_modules _target _link_type)
    if("${_link_type}" STREQUAL "LINK_PUBLIC" OR "${_link_type}" STREQUAL "LINK_PRIVATE")
        set(modules ${ARGN})
        set(link_type ${_link_type})
    else()
        set(modules ${_link_type} ${ARGN})
    endif()

    _qt4or5_component_names_to_qt_components(real_modules ${modules})

    # Verify that Qt5 was found before using qt5_* macros,
    # otherwise cmake will bail out if they are undefined.
    if(${QT_VERSION} STREQUAL "5" AND Qt5Core_FOUND)
        qt5_use_modules(${_target} ${link_type} ${real_modules})
    elseif(${QT_VERSION} STREQUAL "4")
        qt4_use_modules(${_target} ${link_type} ${real_modules})
    endif()
endfunction()

# qt4or5_wrap_ui(outfiles inputfile ... )
macro(qt4or5_wrap_cpp)
    if(${QT_VERSION} STREQUAL "5" AND Qt5Core_FOUND)
        qt5_wrap_cpp(${ARGV})
    elseif(${QT_VERSION} STREQUAL "4")
        qt4_wrap_cpp(${ARGV})
    endif()
endmacro()

# qt4or5_wrap_ui(outfiles inputfile ... )
macro(qt4or5_wrap_ui)
    if(${QT_VERSION} STREQUAL "5" AND Qt5Core_FOUND)
        qt5_wrap_ui(${ARGV})
    elseif(${QT_VERSION} STREQUAL "4")
        qt4_wrap_ui(${ARGV})
    endif()
endmacro()

# qt4or5_add_resources(outfiles inputfile ... )
macro(qt4or5_add_resources)
    if(${QT_VERSION} STREQUAL "5" AND Qt5Core_FOUND)
        qt5_add_resources(${ARGV})
    elseif(${QT_VERSION} STREQUAL "4")
        qt4_add_resources(${ARGV})
    endif()
endmacro()
