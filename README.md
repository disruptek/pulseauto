# pulseauto
- `gc:refc` [![Build Status](https://travis-ci.org/disruptek/pulseauto.svg?branch=master)](https://travis-ci.org/disruptek/pulseauto)
- `gc:arc` [![Build Status](https://travis-ci.org/disruptek/pulseauto.svg?branch=master)](https://travis-ci.org/disruptek/pulseauto)

## Usage

You can specify `level` as a percentage `40%`, a ratio against the current
value `1.2` (eg. 20% louder), or with a raw 16bit value `26000` (eg. ~40%).

The `client` argument is a regular expression with which to match the client
property specified with the `property` argument.

The `level` will be applied to all matching `client` streams.

```
Usage:
  pulseauto [required&optional-params]
Options:
  -h, --help                                                  print this
                                                              cligen-erated help
  --help-syntax                                               advanced:
                                                              prepend,plurals,..
  -l=, --level=     string  REQUIRED                          set level
  -c=, --client=    string  "(mpd|pianobar)"                  set client
  -p=, --property=  string  "application\\.process\\.binary"  set property
```

## Library Use
There are some procedures exported for your benefit; see [the documentation for the module as generated directly from the source](https://disruptek.github.io/pulseauto/pulseauto.html).

## License
MIT
