include ../src/emerald

var sites*: seq[tuple[title: string, url: string]] =
        newSeq[tuple[title: string, url: string]]()

proc layout*(title: string,
             sites: seq[tuple[title: string, url: string]]) {. html_templ .} =
    {. debug = true .}
    html(lang="en"):
        head:
            title: title
            link(rel="stylesheet", `type`="text/css", href="style.css")
            link(rel="stylesheet", `type`="text/css", href="pygments.css")
        body:
            header:
                h1: "emerald"
                h2:
                    "a HTML templating engine for "
                    a(href="http://nim-lang.org/"): "Nim"
            main:
                nav:
                    ul:
                        for site in sites:
                            li(class=if site.title == title: "active" else: ""):
                                a(href=site.url):
                                    site.title
                article:
                    block content:
                        discard
            
            footer:
                p: "This documentation has been generated with emerald."
            
            {. filters = nil .}
            """<a href="https://github.com/flyx/emerald"><img style="position: absolute; top: 0; right: 0; border: 0;" src="https://camo.githubusercontent.com/652c5b9acfaddf3a9c326fa6bde407b87f7be0f4/68747470733a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f6f72616e67655f6666373630302e706e67" alt="Fork me on GitHub" data-canonical-src="https://s3.amazonaws.com/github/ribbons/forkme_right_orange_ff7600.png"></a>"""