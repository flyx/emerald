import ../src/emerald

export emerald.html, emerald.filters, emerald.streams

type
    anchor* = tuple[caption: string, id: string]
    site* = tuple[title: string, url: string, anchors: seq[anchor]]

var sites*: seq[site] = newSeq[site]()

proc layout*(title: string,
             sites: seq[site]) {. html_templ .} =
    html(lang="en"):
        head:
            title:
                "emerald, a Nim HTML templating engine - "
                title    
            link(rel="stylesheet", `type`="text/css", href="style.css")
            link(rel="stylesheet", `type`="text/css", href="pygments.css")
        body:
            header:
                h1: "emerald"
                h2:
                    "an HTML templating engine for "
                    a(href="http://nim-lang.org/", "Nim")
            main:
                nav:
                    ul:
                        for site in sites:
                            li(class=if site.title == title: "active" else: ""):
                                a(href=site.url, site.title)
                            if site.title == title:
                                for a in site.anchors:
                                    li.anchor: a(href="#" & a.id, a.caption)
                article:
                    block content: discard
            footer:
                p:
                    "This documentation was generated with emerald."; br()
                    """Its content is, like emerald itself, licensed under the
                    """; a(href="http://www.wtfpl.net", "WTFPL"); "."
            
            {. filters = nil .}
            """<a href="https://github.com/flyx/emerald"><img style="position: absolute; top: 0; right: 0; border: 0;" src="https://camo.githubusercontent.com/652c5b9acfaddf3a9c326fa6bde407b87f7be0f4/68747470733a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f6f72616e67655f6666373630302e706e67" alt="Fork me on GitHub" data-canonical-src="https://s3.amazonaws.com/github/ribbons/forkme_right_orange_ff7600.png"></a>"""