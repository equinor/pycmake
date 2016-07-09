# TODO 

A short list of issues and requests for future work.

## More robust support of non-conformant modules

What to do with libraries such as *PySerial*, *PyQt*, *SQLite*, etc.  Today we
have hardcoded in (some) support for these.  We could consider adding (and
maintaining) a map from libraries to version accessor.  E.g.,

 * `PyQt4.Qt`&nbsp;&rarr;&nbsp;`"PYQT_VERSION_STR"`,
 * `sqlite`&nbsp;&rarr;&nbsp;`"version"`,
 * `serial`&nbsp;&rarr;&nbsp;`"VERSION"`, etc.


Other libraries again do not expose version strings at all, like *libxslt*,
*libxml2*, and *inspect*.  Here we cannot and will not do anything.


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
