#  Copyright (C)  2016 Statoil ASA, Norway.
#                      Pål Grønås Drange <PGDR@statoil.com>
#
#  This file is part of ERT - Ensemble based Reservoir Tool.
#
#  ERT is free software: you can redistribute it and/or modify it under the
#  terms of the GNU General Public License as published by the Free Software
#  Foundation, either version 3 of the License, or (at your option) any later
#  version.
#
#  ERT is distributed in the hope that it will be useful, but WITHOUT ANY
#  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
#  A PARTICULAR PURPOSE.
#
#  See the GNU General Public License at <http://www.gnu.org/licenses/gpl.html>
#  for more details



# The basic assumption of this package is PEP 396 -- Module Version Numbers as
# layed out in https://www.python.org/dev/peps/pep-0396/

# Unfortunately, not all Python modules expose a version number, like inspect.
# Other Python modules expose several version numbers, e.g. one for the
# underlying software and one for the python packaging, like SQLite and PyQt.

cmake_minimum_required (VERSION 2.8.1)
project (PYTHON_MODULE_VERSIONS)
find_package( PythonInterp 2.6 REQUIRED )



# try import python module, if success, check its version, store as PY_module.
# the module is imported as-is, hence the case (e.g. PyQt4) must be correct.
#
# if given a second argument, the accessor, we call accessor on the module
# instead of the default __version__.
#
# (Yes, accessor could potentially be a function like "os.delete_everything()".)
macro(python_module_version module)
  set(PY_VERSION_ACCESSOR "__version__")
  set(PY_module_name ${module})

  if(${module} STREQUAL "PyQt4")
    set(PY_module_name "PyQt4.Qt")
    set(PY_VERSION_ACCESSOR "PYQT_VERSION_STR")
  endif()

  #  ARGUMENTS: module accessor
  set (extra_macro_args ${ARGN})
  list(LENGTH extra_macro_args num_extra_args)
  if (${num_extra_args} GREATER 0)
    list(GET extra_macro_args 0 accessor)
    set(PY_VERSION_ACCESSOR ${accessor})
  endif()

  execute_process(COMMAND "${PYTHON_EXECUTABLE}" "-c"
    "import ${PY_module_name} as py_m; print(py_m.${PY_VERSION_ACCESSOR})"
    RESULT_VARIABLE _${module}_fail#    error code 0 if success
    OUTPUT_VARIABLE _${module}_version# major.minor.patch
    ERROR_VARIABLE stderr_output
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT _${module}_fail)
    set(PY_${module} ${_${module}_version})
  endif()

  # clean up
  unset(PY_VERSION_ACCESSOR)
  unset(PY_module_name)
  unset(extra_macro_args)
endmacro()



# If we find the correct module and new enough version, set PY_package, where
# "package" is the given argument to the version we found else, display warning
# and do not set any variables.
macro(python_module package)

  #  ARGUMENTS: package package_req module_version version_req accessor
  set (extra_macro_args ${ARGN})
  # Did we get any optional args?
  list(LENGTH extra_macro_args num_extra_args)
  if (${num_extra_args} GREATER 0)
    list(GET extra_macro_args 0 package_req)
  else()
    set(package_req "REQUIRED") # requirement not set, is required
  endif ()
  if (${num_extra_args} GREATER 1)
    list(GET extra_macro_args 1 module_version)
  else()
    set(module_version "0.0.0") # module_version not set, 0.0.0 is ok
  endif ()
  if (${num_extra_args} GREATER 2)
    list(GET extra_macro_args 2 version_req)
  else()
    set(version_req "MINIMUM") # version requirement not set, is minimum
  endif ()
  if (${num_extra_args} GREATER 3)
    list(GET extra_macro_args 3 accessor)
  endif ()

  # We are done expanding the optional arguments

  python_module_version(${package} ${accessor})

  # package not found on system
  if(NOT DEFINED PY_${package})
    if(${package_req} STREQUAL "OPTIONAL")
      message(WARNING "Could not find Python module " ${package})
    else()
      message(SEND_ERROR "Could not find Python module " ${package})
    endif()
  else()
    if (${version_req} STREQUAL "EXACT" AND NOT ${PY_${package}} VERSION_EQUAL ${module_version})
      message(SEND_ERROR "Python module ${package} not exact.  "
        "Wanted EXACT ${module_version}, found ${PY_${package}}")
    elseif (${version_req} STREQUAL "OPTIONAL" AND ${PY_${package}} VERSION_LESS ${module_version})
      message(WARNING "Python module ${package} too old.  "
        "Wanted ${module_version}, found ${PY_${package}}")
    elseif (${version_req} STREQUAL "MINIMUM" AND ${PY_${package}} VERSION_LESS ${module_version})
      message(SEND_ERROR "Python module ${package} too old.  "
        "Wanted MINIMUM ${module_version}, found ${PY_${package}}")
    else()
      message(STATUS "Found ${package}.  ${PY_${package}} >= ${module_version}")
      set(PY_${package} ${module_version})
    endif()
  endif()

  # clean up
  unset(package_req)
  unset(module_version)
  unset(version_req)
  unset(accessor)
  unset(extra_macro_args)
endmacro()


#
# Using the above features
#

python_module( matplotlib REQUIRED 1.2.0  MINIMUM                    )
python_module( numpy      REQUIRED 1.8.2  EXACT                      )
python_module( pandas     REQUIRED 0.15.1                            )
python_module( PyQt4      REQUIRED 4.8.0                             )
python_module( PyQt4.Qt   REQUIRED 4.8.0  MINIMUM "PYQT_VERSION_STR" )
python_module( PyQt4.Qt   REQUIRED 4.8.0  MINIMUM   "QT_VERSION_STR" )
python_module( re         REQUIRED 2.2.1  MINIMUM                    )
python_module( requests   REQUIRED 2.2.1  EXACT   "__version__"      )
#python_module(no_such    OPTIONAL 0.0.1  MINIMUM                    )
