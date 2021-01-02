# pulseauto

[![Test Matrix](https://github.com/disruptek/pulseauto/workflows/CI/badge.svg)](https://github.com/disruptek/pulseauto/actions?query=workflow%3ACI)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/disruptek/pulseauto?style=flat)](https://github.com/disruptek/pulseauto/releases/latest)
![Minimum supported Nim version](https://img.shields.io/badge/nim-1.0.11%2B-informational?style=flat&logo=nim)
[![License](https://img.shields.io/github/license/disruptek/pulseauto?style=flat)](#license)
[![buy me a coffee](https://img.shields.io/badge/donate-buy%20me%20a%20coffee-orange.svg)](https://www.buymeacoffee.com/disruptek)

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
