import nake

task "build", "build emerald library":
    shell(nimExe, "c", "-d:debug --noMain -c", "src/emerald")

task "test", "run emerald test suite":
    shell(nimExe, "c", "-d:debug -r", "test/tests.nim")

task "documentation", "build documentation site":
    withDir "doc":
        shell(nimExe, "c", "-d:debug -r", "generate.nim")