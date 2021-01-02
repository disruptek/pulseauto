version = "1.0.5"
author = "disruptek"
description = "setup pulseaudio stream levels via app names or pids"
license = "MIT"

requires "https://github.com/disruptek/testes >= 0.7.8 & < 1.0.0"
requires "cligen >= 0.9.40"
requires "https://github.com/disruptek/cutelog >= 1.1.2"
requires "dbus"
requires "https://github.com/disruptek/deebus < 20.0.0"
requires "nimterop >= 0.4.4 <= 0.6.11"

bin = @["pulseauto"]

task test, "run unit testes":
  when defined(windows):
    exec "testes.cmd"
  else:
    exec findExe"testes"
