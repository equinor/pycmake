# TODO 

A short list of issues and requests for future work.

## Minimum, exact and optional

We want to write:

    find_python_module( numpy REQUIRED 1.5.3 MINIMUM )
    find_python_module( numpy REQUIRED 1.5.3 EXACT   )
    find_python_module( numpy REQUIRED 1.5.3 OPTIONAL)
    find_python_module( numpy REQUIRED 1.5.3         )
    find_python_module( numpy REQUIRED               )
    find_python_module( numpy WARNING                )



## Dealing with SQLite `apilevel` and `version`

How to deal with the following?  We add a key `VERSION_FIELD` that the cmake
function will use to lookup the version number.

Complex systems like SQLite and Qt exposes more than one version field.  For
instance, SQLite&nbsp;2 vs *python-pysqlite1*.  SQLite has version&nbsp;2.0,
whereas the Python package *python-pysqlite1* has version&nbsp;1.0.1.  These are
accessible by calling

    apilevel = '2.0'
    version  = '1.0.1'

add feature

    python_module( sqlite REQUIRED 2.0   MINIMUM VERSION_FIELD "apilevel"     )
    python_module( sqlite REQUIRED 1.0.1 MINIMUM VERSION_FIELD "version"      )
    python_module( numpy  REQUIRED 1.7.1 MINIMUM VERSION_FIELD "__version__"  )

### PyQt4.Qt

However, *PyQt4* does not export any version field.  Importing *PyQt4.Qt* in
Python reveals fields

    PYQT_VERSION_STR = '4.10.4'
    QT_VERSION_STR = '4.8.6'

Is there a good way to deal with this?


## Don't crash

Call `module.hasattr("__version__")` instead of crashing.  This way, we exit
cleanly if the module is loaded, but the version number will be empty, hence
`$PY_package$` will be set, but will be empty.



## Supporting more non-conformant modules

What to do with *PySerial*, *libxslt*, *libxml2*, *inspect*?


## Using *pkg_resources* for improved version support

if `import my_module;print(my_module.__version__)` fails try
`pkg_resources.get_distribution(my_module).version`

ironically(?), *pkg_resources* does not expose __version__.
