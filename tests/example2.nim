include ../emerald/html_templates

proc mac() {.html_template_macro.} =
    "this is a macro"

proc templ() {.html_template.} =
    html(lang = "en"):
        head:
            title: "pageTitle"
            meta(http_equiv="content-type", content="text/html; charset=UTF-8")
        body:
            const hurr = "durr"
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
                "Let's <see> whether \"Emerald\" escapes & stuff *properly*."
            p.caseTest:
                case 1:
                of 2: "hurr"
                else: hurr
            p.implicitIdTest("myId")
            block blockTest:
                p.blockTest:
                    "stuff in a block"
        when false:
            include foobar()

templ(newFileStream(stdout))