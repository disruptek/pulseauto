version = "1.0.7"
author = "disruptek"
description = "setup pulseaudio stream levels via app names or pids"
license = "MIT"

when not defined(release):
  requires "https://github.com/disruptek/testes >= 1.0.0 & < 2.0.0"
requires "cligen >= 0.9.40"
requires "dbus"

bin = @["pulseauto"]

task test, "run unit testes":
  exec "testes --compileOnly"
