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
                    p: "You are amazing"
                else:
                    p: "Get on it!"
                p: """
                    NimHTML is a macro-based type-safe
                    templating engine which validates your
                    HTML structure and relieves you from
                    the ugly mess that HTML code is.
                    """

echo templ(true)