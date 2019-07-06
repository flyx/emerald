# Package

version       = "0.2.3"
author        = "Felix Krause"
description   = "macro-based HTML templating engine"
license       = "WTFPL"
srcDir        = "src"

# Dependencies

requires "nim >= 0.20.0"

# No longer needed - nimble install will suffice

# task "build", "build emerald library":
#   exec "nim c --noMain -c src/emerald"
#   setCommand "nop"

# No longer needed - simply prefix test entrypoint 
# file in ./tests dir with 't'

# task "test", "run emerald test suite":
#   exec "nim c -d:debug -r test/tests.nim"
#   setCommand "nop"

# this is needed because nim doesn't run clang with -m32 when compiling a
# 32bit binary. Therefore, we need to generate C code and compile it
# manually.

task test32, "run emerald test suite in 32bit mode":
  echo "NOTE: If you get include errors, edit emerald.nimble to point to your Nim location"
  exec "nim c -d:debug --cpu:i386 --compileOnly --nimcache:tests/.nimcache --genScript tests/ttests.nim"
  setCommand "nop"
  withDir "tests":
    # Customize the value of -I to point to your Nim installation
    exec "sed -i '' 's,clang,clang -m32 -I/Users/zachcarter/.choosenim/toolchains/nim-#devel/lib,' .nimcache/compile_ttests.sh"
    withDir ".nimcache":
      exec "sh compile_ttests.sh"
      exec "./ttests"

# Can't get this task to work - keep running into:
discard """
layout.nim(12, 32) template/generic instantiation from here
/Users/zachcarter/projects/litz/zacharycarter/emerald.git/src/emerald/html.nim(660, 36) Warning: use {.base.} for base methods; baseless methods are deprecated [UseBase]
SIGSEGV: Illegal storage access. (Attempt to read from nil?)
stack trace: (most recent call last)
Users/zachcarter/.choosenim/toolchains/nim-#devel/lib/system/nimscript.nim(237) documentationTask
Users/zachcarter/.choosenim/toolchains/nim-#devel/lib/system/nimscript.nim(237, 7) Error: unhandled exception: FAILED: nim c -r generate.nim
"""
task documentation, "build documentation site":
  withDir "doc":
    exec "nim c -r generate.nim"
    setCommand "nop"
