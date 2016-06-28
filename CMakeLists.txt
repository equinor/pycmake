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

cmake_minimum_required (VERSION 2.8.11)
project (PYTHON_MODULE_VERSIONS)

function(find_python_module module)
  set(PY_VERSION_ACCESSOR "__version__")
  set(PY_module_name ${module})
  if(${module} MATCHES "PyQt4")
    set(PY_module_name "PyQt4.Qt")
    set(PY_VERSION_ACCESSOR "PYQT_VERSION_STR")
  endif(${module} MATCHES "PyQt4")
  execute_process(COMMAND "python" "-c"
    "import ${PY_module_name} as py_m; print(py_m.${PY_VERSION_ACCESSOR})"
    RESULT_VARIABLE _${module}_fail#    error code 0 if success
    OUTPUT_VARIABLE _${module}_version# major.minor.patch
    ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT _${module}_fail)
    set(PY_${module} ${_${module}_version})# local scope, for message
    set(PY_${module} ${_${module}_version} PARENT_SCOPE)
    message(STATUS "Found " ${module} " " ${PY_${module}})
  endif(NOT _${module}_fail)
endfunction(find_python_module)

function(find_python_package package version)
  find_python_module(${package})
  if(NOT DEFINED PY_${package})
    message(SEND_ERROR "No such package " ${package})
  elseif(${PY_${package}} VERSION_LESS ${version})
    message(WARNING "Package ${package} too old.  Wanted ${version}, found ${PY_${package}}")
  else(NOT DEFINED PY_${package})
    message(STATUS "Package ${package} works. ${package} ${PY_${package}} >= ${version}")
  endif(NOT DEFINED PY_${package})
endfunction(find_python_package)

find_package( PythonLibs   2.6 REQUIRED )
find_package( PythonInterp 2.6 REQUIRED )

find_python_module( matplotlib )
find_python_module( numpy )
find_python_module( pandas )
find_python_module( PyQt4 )
find_python_module( re )
find_python_module( requests )
#find_python_module( celery )



find_python_package( matplotlib  1.2.0 )
find_python_package( numpy       1.7.1 )
find_python_package( pandas      0.15.1 )
find_python_package( PyQt4       4.8.0 )
find_python_package( re          2.2.1 )
find_python_package( requests    2.5.0 )
#find_python_package( celery      0.0.1 )
