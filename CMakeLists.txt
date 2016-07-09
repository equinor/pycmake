# Setting up

cmake_minimum_required( VERSION 2.0 )
project( TEST_PROJECT )
find_package( PythonInterp 2.6 REQUIRED )


# Loading pycmake macros

include(pycmake.cmake)


# Using the above features

python_module( ctypes )
python_module( numpy  REQUIRED 1.8 )
python_module( pandas REQUIRED 0.18.1 EXACT )

python_module( matplotlib REQUIRED 1.2    MINIMUM                    )
python_module( PyQt4      REQUIRED 4.8                               )
python_module( PyQt4.Qt   REQUIRED 4.8    MINIMUM   "QT_VERSION_STR" )
python_module( PyQt4.Qt   REQUIRED 4.10   MINIMUM "PYQT_VERSION_STR" )
python_module( re         REQUIRED 2.2.1  MINIMUM                    )
python_module( requests   REQUIRED 2.2.1  EXACT                      )
python_module( inspect    OPTIONAL                                   )
#python_module( pandas    REQUIRED 9.9.9  OPTIONAL )                 # will warn but pass

if (DEFINED PY_inspect)
  # Here we can do stuff depending on having *inspect*
  message(STATUS "We have inspect.")
else()
  # And here we can do stuff when we do not have *inspect*
  message(STATUS "We do not have inspect, ignoring ...")
endif()
