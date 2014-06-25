include ../src/html_templates

import streams

proc templ(youAreUsingNimHTML: bool) {.html_template.} =
    html(lang = "en"):
        head:
            title: "pageTitle"
            script (`type` = "text/javascript"): """
                if (foo) {
                    bar(1 + 5)
                }
                """
        body:
            h1: "NimHTML - Nimrod HTML5 templating engine"
            d.content:
                if youAreUsingNimHTML:
                    p:
                        "You are amazing"; br(); "Continue."
                else:
                    p: "Get on it!"
                p: """
                   NimHTML is a macro-based type-safe
                   templating engine which validates your
                   HTML structure and relieves you from
                   the ugly mess that HTML code is.
                   """

templ(newFileStream(stdout), true)