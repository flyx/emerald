include
    ../src/html5

proc mac(): string {.html_template_macro.} =
    "this is a macro"

proc templ(): string {.html_template.} =
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
                while j < 10:
                    j
                    call inc(j, -1)
            p.macroTest:
                include mac()
echo templ()