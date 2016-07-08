# TODO 

A short list of issues and requests for future work.

## Supporting more non-conformant modules

What to do with libraries such as *PySerial*, *libxslt*, *libxml2*, *inspect*?
We could consider hardcoding (and maintaining) a map from libraries to version
accessor.  E.g., `PyQt4.Qt`&nbsp;&rarr;&nbsp;`"PYQT_VERSION_STR"`, 
`SQLite2`&nbsp;&rarr;&nbsp;`"version"`, etc.



## Improved output on keyword EXACT

Today, when a condition is met, we output (e.g.)

    "Found numpy.  1.8.2 >= 1.8.2"

However, if the `EXACT` keyword is used, we should output&nbsp;`==` instead
of&nbsp;`>=`.

## Several attempts for version accessor

Suppose *SQLite2* later added a field `__version__` and deprecated the use of
`version` (I'm a dreamer).  How to make it possible to try any of two accessors?



## Using *pkg_resources* for improved version support (not going to happen)

if `import my_module;print(my_module.__version__)` fails try
`pkg_resources.get_distribution(my_module).version`

ironically(?), *pkg_resources* does not expose __version__.

Update:

1. `pkg_resources.DistributionNotFound: PyQt4`.
1. [PEP-365](https://www.python.org/dev/peps/pep-0365/) was rejected.
1. "Improved version support" was a bit optimistic, it seems.
