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

cmake_minimum_required (VERSION 2.8.11)
project (PYTHON_MODULE_VERSIONS)




# try import python module, if success, check its version, store as PY_module.
# the module is imported as-is, hence the case (e.g. PyQt4) must be correct.
function(python_module_version module)
  set(PY_VERSION_ACCESSOR "__version__")
  set(PY_module_name ${module})

  if(${module} MATCHES "PyQt4")
    set(PY_module_name "PyQt4.Qt")
    set(PY_VERSION_ACCESSOR "PYQT_VERSION_STR")
  endif()

  execute_process(COMMAND "${PYTHON_EXECUTABLE}" "-c"
    "import ${PY_module_name} as py_m; print(py_m.${PY_VERSION_ACCESSOR})"
    RESULT_VARIABLE _${module}_fail#    error code 0 if success
    OUTPUT_VARIABLE _${module}_version# major.minor.patch
    ERROR_VARIABLE stderr_output
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  if(NOT _${module}_fail)
    set(PY_${module} ${_${module}_version})# local scope, for message
    set(PY_${module} ${_${module}_version} PARENT_SCOPE)
  endif()
endfunction()



# If we find the correct module and new enough version, set PY_package, where
# "package" is the given argument to the version we found else, display warning
# and do not set any variables.
macro(python_module package version)
  python_module_version(${package})

  if(NOT DEFINED PY_${package})
    message("Could not find Python module " ${package})
  elseif(${PY_${package}} VERSION_LESS ${version})
    message(WARNING "Python module ${package} too old.  "
      "Wanted ${version}, found ${PY_${package}}")
  else()
    message(STATUS "Found ${package}.  ${PY_${package}} >= ${version}")
    set(PY_${package} ${version})
  endif()
endmacro()


#
# Using the above features
#

# TODO we want to write:
# find_python_module( numpy REQUIRED 1.5.3 MINIMUM )
# find_python_module( numpy REQUIRED 1.5.3 EXACT   )
# find_python_module( numpy REQUIRED 1.5.3 OPTIONAL)
# find_python_module( numpy REQUIRED 1.5.3         )
# find_python_module( numpy REQUIRED               )
# find_python_module( numpy WARNING                )


find_package( PythonInterp 2.6 REQUIRED )

python_module( matplotlib  1.2.0 )
python_module( numpy       1.7.1 )
python_module( pandas      0.15.1 )
python_module( PyQt4       4.8.0 )
python_module( re          2.2.1 )
python_module( requests    2.1.3 )
#python_module(celery      0.0.1 )


# TODO how to deal with the following?

# SQLite 2 vs python-pysqlite1
# SQLite uses     apilevel = '2.0'
#                 version  = '1.0.1'

# add feature
# python_module( sqlite REQUIRED 2.0   MINIMUM VERSION_FIELD "apilevel"     )
# python_module( sqlite REQUIRED 1.0.1 MINIMUM VERSION_FIELD "version"      )
# python_module( numpy  REQUIRED 1.7.1 MINIMUM VERSION_FIELD "__version__"  )

# TODO find versioning fields for PySerial, libxslt, libxml2

# TODO
#
# if import my_module;print(my_module.__version__) fails try
# pkg_resources.get_distribution(my_module).version
#
# ironically(?), pkg_resources does not expose __version__

# TODO use module.hasattr("__version__")
