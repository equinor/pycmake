# pycmake

**pycmake** is a CMake macro for testing that we have the necessary Python
modules and the necessary versions for our systems.  The basic assumption of
this package is PEP 396 -- Module Version Numbers as layed out in
https://www.python.org/dev/peps/pep-0396/

Unfortunately, not all Python modules expose a version number, like *inspect*.
Other Python modules expose several version numbers, e.g. one for the underlying
software and one for the python packaging, like *SQLite* and *PyQt*.

For more information on module version numbers, see
[PEP 396](https://www.python.org/dev/peps/pep-0396/).




## Examples

The most vanilla example usage is the following, where we require *numpy*
version at least&nbsp;1.7.0, and any newer version is acceptable.  Consider the
two CMake lines, whose behavior is identical:

    python_module( numpy REQUIRED 1.7.0         )
    python_module( numpy REQUIRED 1.7.0 MINIMUM )


However, sometimes we are phasing out an older Python module, in which case, we
can give the user a warning.  By writing

    python_module( scipy REQUIRED 1.5.1 OPTIONAL )

we are telling CMake to output a warning to the user if a *scipy* version
below&nbsp;1.5.1 is found, and to exit with an error if *scipy* is not found.

Yet other times, our systems do not work with newer versions than a certain
number.  By writing

    python_module( pandas REQUIRED 0.15.1 EXACT )

we ask CMake to fail if *pandas*&nbsp;0.15.1 is not installed, i.e., even if
*pandas*&nbsp;0.15.2 is installed.




## Advanced version look-up

Not every Python module exposes `__version__`, and some module exposes several
flags, like `version` and `apilevel`.  One feature that will be added is the
ability of manually specifying the flag used to look up the module's version.


As evident in the source code, if `module` happens to be "PyQt4", we try to
import `PyQt4.Qt` and check `PYQT_VERSION_STR` instead of `__version__`.  This
is because PyQt4 does not expose `__version__`.

sqlite users beware.  They use expose `sqlite_version_info`, `version`, and
`version_info`.  There is a difference between the SQLite version (e.g.&nbsp;2
or&nbsp;3) and the python-pysqlite version, e.g.&nbsp;1.0.1.  SQLite exposes
`apilevel = '2.0'` and `version = '1.0.1'`.  A future feature is therefore to be
able to get both `apilevel` and `version`, as well as `__version__` etc.





## Technicalities

This repo contains one file of interest, the `CMakeLists.txt` file which
contains two macros:

* `macro( python_module_version module )`
* `macro( python_module module version )`

The first macro, `python_module_version`, checks if `module` is a Python
importable package, and if so, which version `module` has.  The version is found
simply by the following Python program:

    import package as py_m
    print(py_m.__version__)


If this program fails, the status flag will be set to&nbsp;`1`, and the package
will be assumed to not exist.  If the program succeeds, the output of the
program will be stored in the global cmake variable `PY_${package}` where
`${package}` is the name of the package given to the macro `python_module`.


The macro, `python_module(module version)` calls the function,
`python_module_version(module)` and checks if

1. The variable `PY_${module}` has been set, if so, package is found, else
   `SEND_ERROR`
1. The version of the package is at least `version`, if not `WARNING`.
