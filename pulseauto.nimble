version = "1.0.6"
author = "disruptek"
description = "setup pulseaudio stream levels via app names or pids"
license = "MIT"

requires "https://github.com/disruptek/testes >= 0.7.8 & < 1.0.0"
requires "cligen >= 0.9.40"
requires "dbus"

bin = @["pulseauto"]

task test, "run unit testes":
  when defined(windows):
    exec "testes.cmd"
  else:
    exec findExe"testes"
