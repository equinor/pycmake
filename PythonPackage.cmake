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
# * add_python_package(<target> <name>
#                      [APPEND] [VERSION__INIT__]
#                      [SUBDIR <dir>] [PATH <path>]
#                      [VERSION <version>]
#                      [TARGETS <tgt>...] [SOURCES <src>...]
#                      [DEPEND_DIRS <tgt1> <dir1> [<tgt2> <dir2>]...]
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
#   When VERSION__INIT__ is used, the pycmake will inject __version__ = '$ver'
#   in the __init__.py file. This version is read from PROJECT_VERSION unless
#   VERSION argument is used. If VERSION is used, this version is used instead.
#   If neither PROJECT_VERSION or VERSION is used, the string "0.0.0" is used
#   as a fallback. The same version number will be used for the add_setup_py
#   pip package.
#
#   DEPEND_DIRS is needed by add_setup_py if sources for the target is set with
#   relative paths. These paths can be set later in order to be less intrusive
#   on non-python aspects of the cmake file. Still, this information is
#   necessary to accurately find and move source files to the build directory,
#   so that setup.py can find them, and might need to be added later.
#
#   To override the version number used for this package, pass the VERSION
#   argument with a complete string. If this option is not used and
#   PROJECT_VERSION is set (CMake 3.x+), PROJECT_VERSION is used.
#
#   This command provides install targets, but no exports.
#
# * add_setup_py(<target> <template>
#                [MANIFEST <manifest>])
#
#   Create a setuptools package that is capable of building (for sdist+bdist)
#   and uploading packages to pypi and similar.
#
#   The target *must* be a target created by add_python_package. The template
#   is any setup.py that works with cmake's configure_file.
#
#   A manifest will be created and project-provided header files will be
#   included, suitable for source distribution. If you want to include other
#   things in the package that isn't suitable to add to the setup.py template,
#   point the MANIFEST argument to your base file.
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

function(pycmake_to_path_list var path1)
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

function(pycmake_list_concat out)
    foreach (arg ${ARGN})
        list(APPEND l ${arg})
    endforeach ()

    set(${out} ${l} PARENT_SCOPE)
endfunction ()

function(pycmake_is_system_path out path)
    string(FIND ${path} ${CMAKE_SOURCE_DIR} ${out})

    if (${out} EQUAL -1)
        set(${out} TRUE PARENT_SCOPE)
    else ()
        set(${out} FALSE PARENT_SCOPE)
    endif ()
endfunction ()

# internal. Traverse the tree of dependencies (linked targets) that are actual
# cmake targets and add to a list
function(pycmake_target_dependencies dependencies target)
    get_target_property(deps ${target} LINK_LIBRARIES)

    list(APPEND result ${target})
    foreach (dep ${deps})
        if (TARGET ${dep})
            pycmake_target_dependencies(linked ${dep})
            foreach (link ${linked})
                list(APPEND result ${link})
            endforeach ()
        endif ()
    endforeach ()

    list(REMOVE_DUPLICATES result)
    set(${dependencies} ${result} PARENT_SCOPE)
endfunction ()

# internal. Traverse the set of dependencies (linked targets) to some parent
# and create a list of its source files, preprocessor definitions, include
# directories and custom compiler options, and write these as properties on the
# the target.
#
# In effect, these properties are set on the python package target (created
# with add_python_package):
#
# PYCMAKE_EXTENSIONS - a list of extensions (C/C++ targets) for the package
# For each extension in this list, these variables are set on the package:
# PYCMAKE_<ext>_INCLUDE_DIRECTORIES
# PYCMAKE_<ext>_SOURCES
# PYCMAKE_<ext>_COMPILE_DEFINITIONS
# PYCMAKE_<ext>_COMPILE_OPTIONS
#
# All properties are lists, and the content correspond to the non-namespaced
# properties (includes, sources etc.)
function(pycmake_include_target_deps pkg tgt depend_dirs)
    pycmake_target_dependencies(deps ${tgt})
    foreach (dep ${deps})
        # If sources files were registered with absolute path (prefix'd with
        # ${CMAKE_CURRENT_SOURCE_DIR}) we can just use this absolute path and
        # be fine. If not, we assume that if the source file is *not* relative
        # but below the current dir if it's NOT in the depend_dir list, in
        # which case we make it absolute. This ends up in the sources argument
        # to Extensions in setup.py
        list(FIND depend_dirs ${dep} index)
        if (NOT ${index} EQUAL -1)
            math(EXPR index "${index} + 1")
            list(GET depend_dirs ${index} prefix)
        else ()
            set(prefix ${CMAKE_CURRENT_SOURCE_DIR})
        endif ()

        get_target_property(incdir ${dep} INCLUDE_DIRECTORIES)
        get_target_property(srcs   ${dep} SOURCES)
        get_target_property(defs   ${dep} COMPILE_DEFINITIONS)
        get_target_property(flgs   ${dep} COMPILE_OPTIONS)

        # prune -NOTFOUND props
        foreach (var incdir srcs defs flgs)
            if(NOT ${var})
                set(${var} "")
            endif ()
        endforeach ()

        list(APPEND includes ${incdir})
        list(APPEND sources  ${prefix}/${srcs})
        list(APPEND defines  ${defs})
        list(APPEND flags    ${flags})
    endforeach()

    get_target_property(extensions ${pkg} PYCMAKE_EXTENSIONS)
    list(APPEND extensions ${tgt})

    # properties may contain generator expressions, which we filter out
    string(REGEX REPLACE "\\$<.*>;?" "" includes "${includes}")
    string(REGEX REPLACE "\\$<.*>;?" "" sources  "${sources}")
    string(REGEX REPLACE "\\$<.*>;?" "" defines  "${defines}")
    string(REGEX REPLACE "\\$<.*>;?" "" flags    "${flags}")

    set_target_properties(${pkg} PROPERTIES
                            PYCMAKE_EXTENSIONS "${extensions}"
                            PYCMAKE_${tgt}_INCLUDE_DIRECTORIES "${includes}"
                            PYCMAKE_${tgt}_SOURCES "${sources}"
                            PYCMAKE_${tgt}_COMPILE_DEFINITIONS "${defines}"
                            PYCMAKE_${tgt}_COMPILE_OPTIONS "${flags}")
endfunction()

function(add_python_package pkg NAME)
    set(options APPEND VERSION__INIT__)
    set(unary PATH SUBDIR VERSION)
    set(nary  TARGETS SOURCES DEPEND_DIRS)
    cmake_parse_arguments(PP "${options}" "${unary}" "${nary}" "${ARGN}")

    set(installpath ${CMAKE_INSTALL_PREFIX}/${PYTHON_INSTALL_PREFIX})

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
        message(SEND_ERROR "${problem}. ${solution}.")

    elseif (NOT TARGET ${pkg})
        add_custom_target(${pkg} ALL)

        get_filename_component(abspath ${CMAKE_CURRENT_BINARY_DIR} ABSOLUTE)
        set_target_properties(${pkg} PROPERTIES PACKAGE_INSTALL_PATH ${installpath})
        set_target_properties(${pkg} PROPERTIES PACKAGE_BUILD_PATH ${abspath})
        set_target_properties(${pkg} PROPERTIES PYCMAKE_PACKAGE_NAME ${NAME})

        set(pkgver "0.0.0")
        if (PROJECT_VERSION)
            set(pkgver ${PROJECT_VERSION})
        endif ()

        if (PP_VERSION)
            set(pkgver ${PP_VERSION})
        endif ()

        set_target_properties(${pkg} PROPERTIES PYCMAKE_PACKAGE_VERSION ${pkgver})

        # set other properties we might populate later
        set_target_properties(${pkg} PROPERTIES PYCMAKE_EXTENSIONS "")

    endif ()
    # append subdir if requested
    if (PP_SUBDIR)
        set(dstpath ${dstpath}/${PP_SUBDIR})
        set(installpath ${installpath}/${PP_SUBDIR})
    endif ()

    # copy all .py files into
    foreach (file ${PP_SOURCES})

        get_filename_component(absfile ${file} ABSOLUTE)
        get_filename_component(fname ${file} NAME)

        if ("${fname}" STREQUAL "__init__.py" AND PP_VERSION__INIT__)
            message(STATUS "Writing __version__ ${pkgver} to package ${pkg}.")

            set(initpy "${CMAKE_CURRENT_BINARY_DIR}/${dstpath}/${fname}")
            configure_file(${absfile} ${initpy} COPYONLY)

            file(APPEND ${initpy} "__version__ = '${pkgver}'")
        else ()

        add_custom_command(TARGET ${pkg}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${dstpath}
            COMMAND ${CMAKE_COMMAND} -E copy ${absfile} ${dstpath}/
                )

        endif ()
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

        # traverse all dependencies and get their include dirs, link flags etc.
        pycmake_include_target_deps(${pkg} ${tgt} "${PP_DEPEND_DIRS}")

    endforeach ()

    if (NOT PP_SOURCES AND NOT PP_TARGETS AND NOT PP_APPEND)
        message(SEND_ERROR
            "add_python_package called without .py files or C/C++ targets.")
    endif()

    install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${dstpath}
            DESTINATION ${installpath})
endfunction()

function(add_setup_py target template)
    set(options)
    set(unary MANIFEST)
    set(nary)
    cmake_parse_arguments(PP "${options}" "${unary}" "${nary}" "${ARGN}")

    string(TOUPPER ${CMAKE_BUILD_TYPE} buildtype)

    get_target_property(PYCMAKE_PACKAGE_NAME ${target} PYCMAKE_PACKAGE_NAME)
    get_target_property(PYCMAKE_VERSION ${target} PYCMAKE_PACKAGE_VERSION)
    get_target_property(extensions ${target} PYCMAKE_EXTENSIONS)

    get_directory_property(dir_inc INCLUDE_DIRECTORIES)
    get_directory_property(dir_def COMPILE_DEFINITIONS)
    get_directory_property(dir_opt COMPILE_OPTIONS)
    string(REGEX REPLACE " " ";" dir_opt "${dir_opt}")

    set(cflags   "${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${buildtype}}")
    set(cxxflags "${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_${buildtype}}")
    string(REGEX REPLACE " " ";" cflags ${cflags})
    string(REGEX REPLACE " " ";" cxxflags ${cxxflags})

    foreach (ext ${extensions})

        get_target_property(cxx ${ext} HAS_CXX)
        if (${cxx})
            set(flags ${cxxflags})
        else ()
            set(flags ${cflags})
        endif ()

        get_target_property(inc ${target} PYCMAKE_${ext}_INCLUDE_DIRECTORIES)
        get_target_property(src ${target} PYCMAKE_${ext}_SOURCES)
        get_target_property(def ${target} PYCMAKE_${ext}_COMPILE_DEFINITIONS)
        get_target_property(opt ${target} PYCMAKE_${ext}_COMPILE_OPTIONS)

        pycmake_list_concat(inc ${dir_inc} ${inc})
        pycmake_list_concat(def ${dir_def} ${def})
        pycmake_list_concat(opt ${flags} ${dir_opt} ${opt})

        # remove the python include dir (which is obviously unecessary)
        list(REMOVE_ITEM inc ${PYTHON_INCLUDE_DIRS})

        # wrap every string in single quotes (because python expects this)
        foreach (item ${inc})
            # project-provided headers must be bundled for sdist
            pycmake_is_system_path(syspath ${item})
            get_filename_component(dstpath include/${item} DIRECTORY)
            if (NOT ${syspath})
                file(COPY ${item} DESTINATION ${dstpath})
            endif ()

            list(APPEND _inc "'include/${item}'")
        endforeach ()
        foreach (item ${src})

            # setup.py is pretty grumpy and wants source files relative itself
            # AND not upwards, so we must copy our entire source tree into the
            # build dir
            configure_file(${item} ${CMAKE_CURRENT_BINARY_DIR}/${item} COPYONLY)
            list(APPEND _src "'./${item}'")
        endforeach ()

        foreach (item ${opt})
            list(APPEND _opt "'${item}'")
        endforeach ()

        # defines are a bit more work, because setup.py expects them as tuples
        foreach (item ${def})
            string(FIND ${item} "=" pos)
            if (${pos} EQUAL -1) # no = in the define, so a None-value
                list(APPEND _def "('${item}', None)")
            else ()
                string(REGEX MATCH "(.*)=(.*)" ignore ${item})
                list(APPEND _def "('${CMAKE_MATCH_0}', '${CMAKE_MATCH_1}')")
            endif ()
        endforeach ()

        list(REMOVE_DUPLICATES _inc)
        list(REMOVE_DUPLICATES _src)
        list(REMOVE_DUPLICATES _def)
        # do not remote duplictes for compiler options, because some are
        # legitemately passed multiple times, e.g. on clang for osx builds
        # `-arch i386 -arch x86_64`

        # then make the list comma-separated (for python)
        string(REGEX REPLACE ";" "," inc "${_inc}")
        string(REGEX REPLACE ";" "," src "${_src}")
        string(REGEX REPLACE ";" "," def "${_def}")
        string(REGEX REPLACE ";" "," opt "${_opt}")

        # TODO: be able to set other name than ext
        list(APPEND setup_extensions "Extension('${PYCMAKE_PACKAGE_NAME}.${ext}',
                                                sources=[${src}],
                                                include_dirs=[${inc}],
                                                define_macros=[${def}],
                                                extra_compile_args=[${opt}])")

    endforeach()

    string(REGEX REPLACE ";" "," PYCMAKE_EXTENSIONS "${setup_extensions}")

    # When extensions are built, headers aren't typically included for source
    # dists, which are instead read from a manifest file. If a base is provided
    # we copy that, then append. If no template is provided, overwrite so it's
    # clean every time we append
    if (PP_MANIFEST)
        configure_file(${PP_MANIFEST} MANIFEST.in COPYONLY)
    else ()
        file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/MANIFEST.in)
    endif ()

    # Make a best-effort guess finding header files, trying all common
    # extensions
    file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/MANIFEST.in
                "recursive-include include *.h *.hh *.H *.hpp *.hxx")

    configure_file(${template} setup.py)
endfunction ()

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
    pycmake_to_path_list(pythonpath "$ENV{PYTHONPATH}" ${buildpath})
    set_tests_properties(${TESTNAME} PROPERTIES ENVIRONMENT "PYTHONPATH=${pythonpath}")
endfunction()
