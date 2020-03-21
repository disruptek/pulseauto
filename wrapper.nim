import os

import nimterop/[cimport, build]

#const
#  baseDir = getProjectCacheDir("nimpulseaudio")

static:
  cDebug()

cIncludeDir("/usr/include/pulse/") #baseDir / "src")

#cImport(baseDir / "src" / "pulse" / "pulseaudio.h", recurse = true, flags = "-E_ -F_ -c")
cImport("/usr/include/pulse" / "pulseaudio.h", recurse = true, flags = "-E_ -F_ -c")
