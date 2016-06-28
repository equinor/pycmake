# pymake

This repo contains one file of interest, the `CMakeLists.txt` file which
contains two functions:

* `find_python_module(module)`
* `find_python_package(module version)`

The first function, `find_python_module`, checks if `module` is a python
importable package, and if so, which version `module` has.  The version is found
simply by the following Python program:

    import package as py_m
    print(py_m.__version__)

If this program fails, the status flag will be set to 1, and the package will be
assumed to not exist.  If the program succeeds, the output of the program will
be stored in the global cmake variable `PY_${package}` where `${package}` is the
name of the package given to `find_python_module`.


The second function, `find_python_package(module version)` calls the first function, `find_python_module(module)` and checks if

    1. The variable `PY_${module}` exists, if so, package is found, else ERROR
    2. The version of the package is at least `version`, if not ERROR.


Wooops.  There is a small hack, if `module` happens to be "PyQt4", we try to
import `PyQt4.Qt` and check `PYQT_VERSION_STR` instead of `__version__`.  This
is because PyQt4 didn't find it necessary to expose the standard `__version__`.

sqlite3 users beware.  They use expose `sqlite_version_info`, `version`, and
`version_info`.

For more information on module version numbers, see PEP 396:
https://www.python.org/dev/peps/pep-0396/
