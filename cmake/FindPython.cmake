set(PYTHON_BIN python CACHE STRING "Python executable name")

execute_process(
	COMMAND ${PYTHON_BIN} -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())"
	OUTPUT_VARIABLE PYTHON_SYS_PATH
	)
string(STRIP ${PYTHON_SYS_PATH} PYTHON_SYS_PATH)
FIND_PATH(PYTHON_INCLUDE_PATH Python.h
    PATHS ${PYTHON_SYS_PATH}
    NO_DEFAULT_PATH
    NO_SYSTEM_ENVIRONMENT_PATH
    )

execute_process(
	COMMAND ${PYTHON_BIN} -c "from distutils.sysconfig import get_config_var; print(get_config_var('LIBDIR'))"
	OUTPUT_VARIABLE PYTHON_LIB_PATH
	)
string(STRIP ${PYTHON_LIB_PATH} PYTHON_LIB_PATH)

execute_process(
	COMMAND ${PYTHON_BIN} -c "import sys; print(sys.prefix)"
	OUTPUT_VARIABLE PYTHON_PREFIX_PATH
	)

string(STRIP ${PYTHON_PREFIX_PATH} PYTHON_PREFIX_PATH)

execute_process(
	COMMAND ${PYTHON_BIN} -c "import sys; print('%s.%s' % sys.version_info[:2])"
    OUTPUT_VARIABLE PYTHON_VERSION
	)
string(STRIP ${PYTHON_VERSION} PYTHON_VERSION)
message(STATUS "Python version: ${PYTHON_VERSION}")

string(REPLACE "." "" PYTHON_VERSION_WITHOUT_DOTS ${PYTHON_VERSION})

FIND_LIBRARY(PYTHON_LIBRARY NAMES
        python${PYTHON_VERSION}
        python${PYTHON_VERSION}m
        python${PYTHON_VERSION_WITHOUT_DOTS}
    PATHS ${PYTHON_LIB_PATH} ${PYTHON_PREFIX_PATH}/lib ${PYTHON_PREFIX_PATH}/libs
    PATH_SUFFIXES ${CMAKE_LIBRARY_ARCHITECTURE}
    NO_DEFAULT_PATH
    NO_SYSTEM_ENVIRONMENT_PATH
    )

execute_process(
	COMMAND ${PYTHON_BIN} -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())"
	OUTPUT_VARIABLE PYTHON_INSTALL_PATH_tmp
	)
string(STRIP ${PYTHON_INSTALL_PATH_tmp} PYTHON_INSTALL_PATH_tmp)
set(PYTHON_INSTALL_PATH ${PYTHON_INSTALL_PATH_tmp}
    CACHE BOOL "Python install path")
message(STATUS "Python install path: ${PYTHON_INSTALL_PATH}")

if (NOT WIN32)
    execute_process(
        COMMAND ${PYTHON_BIN} -c "from distutils.sysconfig import get_config_var; print(get_config_var('SOABI'))"
        OUTPUT_VARIABLE PYTHON_EXTENSION_SOABI_tmp
        )
    string(STRIP ${PYTHON_EXTENSION_SOABI_tmp} PYTHON_EXTENSION_SOABI_tmp)
    if (NOT "${PYTHON_EXTENSION_SOABI_tmp}" STREQUAL "None")
        set(PYTHON_EXTENSION_SOABI_tmp ".${PYTHON_EXTENSION_SOABI_tmp}")
    else()
        set(PYTHON_EXTENSION_SOABI_tmp "")
    endif()
endif()
set(PYTHON_EXTENSION_SOABI ${PYTHON_EXTENSION_SOABI_tmp}
    CACHE STRING "Suffix for python extensions")

INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(PYTHON DEFAULT_MSG PYTHON_LIBRARY PYTHON_INCLUDE_PATH PYTHON_INSTALL_PATH)


# Links a Python extension module.
#
# The exact link flags are platform dependent and this macro makes it possible
# to write platform independent cmakefiles. All you have to do is to change
# this:
#
# add_library(simple_wrapper SHARED ${SRC})  # Linux only
# set_target_properties(simple_wrapper PROPERTIES PREFIX "")
#
# to this:
#
# add_python_library(simple_wrapper ${SRC})  # Platform independent
#
# Full example:
#
# set(SRC
#     iso_c_utilities.f90
#     pde_pointers.f90
#     example1.f90
#     example2.f90
#     example_eigen.f90
#     simple.f90
#     simple_wrapper.c
# )
# add_python_library(simple_wrapper ${SRC})

macro(ADD_PYTHON_LIBRARY name)
    # When linking Python extension modules, a special care must be taken about
    # the link flags, which are platform dependent:
    IF(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
        # on Mac, we need to use the "-bundle" gcc flag, which is what MODULE
        # does:
        add_library(${name} MODULE ${ARGN})
        # and "-flat_namespace -undefined suppress" link flags, that we need
        # to add by hand:
        set_target_properties(${name} PROPERTIES
            LINK_FLAGS "-flat_namespace -undefined suppress")
    ELSE(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
        # on Linux, we need to use the "-shared" gcc flag, which is what SHARED
        # does:
        add_library(${name} SHARED ${ARGN})
    ENDIF(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    set_target_properties(${name} PROPERTIES PREFIX "")
    set_target_properties(${name} PROPERTIES OUTPUT_NAME "${name}${PYTHON_EXTENSION_SOABI}")
    target_link_libraries(${name} ${PYTHON_LIBRARY})
    IF(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
        set_target_properties(${name} PROPERTIES SUFFIX ".pyd")
    ENDIF()
endmacro(ADD_PYTHON_LIBRARY)
