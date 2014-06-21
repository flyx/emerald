include
    ../src/html5

proc templ(youAreUsingNimHTML: bool): string =
    result = ""
    html5:
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
                p:
                    var i = 10
                    while i > 5:
                        i
                        i = i - 1
                    for j in 1..10:
                        j

echo templ(true)