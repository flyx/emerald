import nake

task "build", "build emerald library":
    shell(nimExe, "c", "--noMain -c", "src/emerald")

task "test", "run emerald test suite":
    shell(nimExe, "c", "-d:debug -r", "test/tests.nim")

# this is needed because nim doesn't run clang with -m32 when compiling a
# 32bit binary. Therefore, we need to generate C code and compile it
# manually.
task "test32", "run emerald test suite in 32bit mode":
    shell("echo", "NOTE: If you get include errors, edit nakefile.nim to point to your Nim location")
    shell(nimExe, "c", "-d:debug --cpu:i386 --compile_only --gen_script", "test/tests.nim")
    withDir "test":
        # Customize the value of -I to point to your Nim installation
        shell("sed", "-i ''", "'s,clang,clang -m32 -I../../../3rdParty/Nim/lib,'", "compile_tests.sh")
        withDir "nimcache":
            shell("sh", "../compile_tests.sh")
            shell("./tests")

task "documentation", "build documentation site":
    withDir "doc":
        shell(nimExe, "c", "-r", "generate.nim")