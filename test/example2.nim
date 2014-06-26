include ../src/html_templates
import streams

proc mac() {.html_template_macro.} =
    "this is a macro"

proc templ() {.html_template.} =
    html(lang = "en"):
        head:
            title: "pageTitle"
        body:
            d.forTest:
                for i in 1..10:
                    i
                    " "
            d.whileTest:
                var j = 20
                while j > 10:
                    j
                    call inc(j, -1)
            p.macroTest:
                include mac()
            p.putTest:
                put repeatChar(10, '-')
            p.discardTest:
                discard 1 + 1
            p.escapeTest(id = "\"escape\">-<\'test\' &&&"):
                "Let's <see> whether \"NimHTML\" escapes & stuff *properly*."
            p.caseTest:
                case 1:
                of 2: "hurr"
                else: "durr"
        when false:
            include foobar()

templ(newFileStream(stdout))