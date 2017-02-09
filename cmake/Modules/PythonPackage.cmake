#  Copyright (C)  2016 Statoil ASA, Norway.
#
#  pymake is free software: you can redistribute it and/or modify it under the
#  terms of the GNU General Public License as published by the Free Software
#  Foundation, either version 3 of the License, or (at your option) any later
#  version.
#
#  pymake is distributed in the hope that it will be useful, but WITHOUT ANY
#  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
#  A PARTICULAR PURPOSE.
#
#  See the GNU General Public License at <http://www.gnu.org/licenses/gpl.html>
#  for more details

# This module exports the following functions:
# * to_path_list(var path)
#       which takes a list of paths and constructs a valid PYTHONPATH string,
#       regardless  of platform (path1:path2 for unix, path1;path2 for windows)
#
# * add_python_package(package_name package_path python_files) where
#       which takes a package name, a path and the series of python files that
#       makes that package. It exports the cmake target package_${package_name}
#       in copies all ${python_files} sources to python/${package_path}, and
#       sets up so you can install with `make install`.
#
# * add_python_package(<target> <name>
#                      [APPEND]
#                      [SUBDIR <dir>] [PATH <path>]
#                      [TARGETS <tgt>...] [SOURCES <src>...]
#   Create a new target <target>, analogous to add_library. Creates a python
#   package <name>, optionally at the path specified with PATH. If SUBDIR <dir>
#   is used, then the files will be copied to $root/dir/*, in order to create
#   python sub namespaces - if subdir is not used then all files will be put in
#   $root/*. SOURCES <src> is the python files to be copied to the directory in
#   question, and <tgt> are regular cmake libraries (targets created by
#   add_library).
#
#   When the APPEND option is used, the files and targets given will be added
#   onto the same target package - it is necessary to use APPEND when you want
#   sub modules. Consider the package foo, with the sub module bar. In python,
#   you'd do: `from foo.bar import baz`. This means the directory structure is
#   `foo/bar/baz.py` in the package. This is accomplished with:
#   add_python_package(mypackage mypackage SOURCES __init__.py)
#   add_python_package(mypackage mypackage APPEND SOURCES baz.py)
#
#   This command provides install targets, but no exports.
#
# * add_python_test(testname python_test_file)
#       which sets up a test target (using pycmake_test_runner.py, distributed
#       with this module) and registeres it with ctest.
#
# * add_python_example(package example testname test_file [args...])
#       which sets up an example program which will be run with the arguments
#       [args...] (can be empty) Useful to make sure some program runs
#       correctly with the given arguments, and which will report as a unit
#       test failure.

if (NOT PYTHON_EXECUTABLE)
    include(FindPythonInterp)
endif ()

function(to_path_list var path1)
    if("${CMAKE_HOST_SYSTEM}" MATCHES ".*Windows.*")
        set(sep "\\;")
    else()
        set(sep ":")
    endif()
    set(result "${path1}") # First element doesn't require separator at all...
    foreach(path ${ARGN})
        set(result "${result}${sep}${path}") # .. but other elements do.
    endforeach()
    set(${var} "${result}" PARENT_SCOPE)
endfunction()

if (EXISTS "/etc/debian_version")
    set( PYTHON_PACKAGE_PATH "dist-packages")
else()
    set( PYTHON_PACKAGE_PATH "site-packages")
endif()
set(PYTHON_INSTALL_PREFIX "lib/python${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}/${PYTHON_PACKAGE_PATH}" CACHE STRING "Subdirectory to install Python modules in")

function(add_python_package pkg NAME)
    set(options APPEND)
    set(unary PATH SUBDIR)
    set(nary  TARGETS SOURCES)
    cmake_parse_arguments(PP "${options}" "${unary}" "${nary}" "${ARGN}")

    set(installpath ${CMAKE_INSTALL_PREFIX}/${PYTHON_INSTALL_PREFIX}/${NAME})

    if (PP_PATH)
        # obey an optional path to install into - but prefer the reasonable
        # default of currentdir/name
        set(dstpath ${PP_PATH})
    else ()
        set(dstpath ${NAME})
    endif()

    # if APPEND is passed, we *add* files/directories instead of creating it.
    # this can be used to add sub directories to a package. If append is passed
    # and the target does not exist - create it
    if (TARGET ${pkg} AND NOT PP_APPEND)
        set(problem "Target '${pkg}' already exists")
        set(descr "To add more files to this package")
        set(solution "${descr}, use add_python_package(<target> <name> APPEND)")
        message(FATAL_ERROR "${problem}. ${solution}.")

    elseif (NOT TARGET ${pkg})
        add_custom_target(${pkg} ALL)

        get_filename_component(abspath ${CMAKE_CURRENT_BINARY_DIR} ABSOLUTE)
        set_target_properties(${pkg} PROPERTIES PACKAGE_INSTALL_PATH ${installpath})
        set_target_properties(${pkg} PROPERTIES PACKAGE_BUILD_PATH ${abspath})
    endif ()
    # append subdir if requested
    if (PP_SUBDIR)
        set(dstpath ${dstpath}/${PP_SUBDIR})
        set(installpath ${installpath}/${PP_SUBDIR})
    endif ()

    # copy all .py files into
    foreach (file ${PP_SOURCES})
        get_filename_component(absfile ${file} ABSOLUTE)
        add_custom_command(TARGET ${pkg}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${dstpath}
            COMMAND ${CMAKE_COMMAND} -E copy ${absfile} ${dstpath}/
                )
    endforeach ()

    # targets are compiled as regular C/C++ libraries (via add_library), before
    # we add some python specific stuff for the linker here.
    if (MSVC)
        # on windows, .pyd is used as extension instead of DLL
        set(SUFFIX ".pyd")
    elseif (APPLE)
        # regular shared libraries on OS X are .dylib, but python wants .so
        set(SUFFIX ".so")
        # the spaces in LINK_FLAGS are important; otherwise APPEND_STRING to
        # set_property seem to combine it with previously-set options or
        # mangles it in some other way
        set(LINK_FLAGS " -undefined dynamic_lookup ")
    else()
        set(LINK_FLAGS " -Xlinker -export-dynamic ")
    endif()

    # register all targets as python extensions
    foreach (tgt ${PP_TARGETS})
        set_target_properties(${tgt} PROPERTIES PREFIX "")
        if (LINK_FLAGS)
            set_property(TARGET ${tgt} APPEND_STRING PROPERTY LINK_FLAGS ${LINK_FLAGS})
        endif()
        if (SUFFIX)
            set_property(TARGET ${tgt} APPEND_STRING PROPERTY SUFFIX ${SUFFIX})
        endif()

        # copy all targets into the package directory
        add_custom_command(TARGET ${tgt} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory ${dstpath}
            COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${tgt}> ${dstpath}/
        )
    endforeach ()

    if (NOT PP_SOURCES AND NOT PP_TARGETS AND NOT PP_APPEND)
        message(FATAL_ERROR
            "add_python_package called without .py files or C/C++ targets.")
    endif()

    if (PP_SOURCES)
        install(FILES ${PP_SOURCES} DESTINATION ${installpath})
    endif()

    if (PP_TARGETS)
        install(TARGETS ${PP_TARGETS} EXPORT ${pkg} DESTINATION ${installpath})
    endif()
endfunction()

function(add_python_test TESTNAME PYTHON_TEST_FILE)
    configure_file(${PYTHON_TEST_FILE} ${PYTHON_TEST_FILE} COPYONLY)
    get_filename_component(name ${PYTHON_TEST_FILE} NAME)
    get_filename_component(dir  ${PYTHON_TEST_FILE} DIRECTORY)

    add_test(NAME ${TESTNAME}
            COMMAND ${PYTHON_EXECUTABLE} -m unittest discover -vs ${dir} -p ${name}
            )
endfunction()

function(add_python_example pkg TESTNAME PYTHON_TEST_FILE)
    configure_file(${PYTHON_TEST_FILE} ${PYTHON_TEST_FILE} COPYONLY)

    add_test(NAME ${TESTNAME}
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            COMMAND ${PYTHON_EXECUTABLE} ${PYTHON_TEST_FILE} ${ARGN})

    get_target_property(buildpath ${pkg} PACKAGE_BUILD_PATH)
    to_path_list(pythonpath "$ENV{PYTHONPATH}" ${buildpath})
    set_tests_properties(${TESTNAME} PROPERTIES ENVIRONMENT "PYTHONPATH=${pythonpath}")
endfunction()
