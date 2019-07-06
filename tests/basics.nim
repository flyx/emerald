import testbase

import basics_publicTemplate


proc base() {.html_templ.} =
    html(lang="en"):
        head:
            title: "Basics"
        body:
            p: "Content"

proc withParams(title: string, content: bool) {.html_templ.} =
    html(lang="en"):
        head:
            title: title
        body:
            h1: "Heading"
            if content:
                p: "Content"

proc tagClasses() {.html_templ.} =
    {. compact_mode = true .}
    body.main:
        p(class="first"): "First paragraph"
        p.second(class="last"): "Second paragraph"
        footer.footer.realLast: "Footer"

proc tagsWithDirectContent() {.html_templ.} =
    {. compact_mode = true .}
    body:
        strong("Strong text")
        a(href="home.html", "home")

proc variables() {.html_templ.} =
    {. compact_mode = true .}
    var a = "a"
    let c = "c"
    const d = "d"
    ul(class=d):
        for i in 1..3:
            if i == 2:
                a = "b"
                li: c
            else:
                li: a

suite "basics":
    test "basic template without parameters":
        var
            ss = newStringStream()
            templ = newBase()
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
    <head>
        <title>Basics</title>
    </head>
    <body>
        <p>Content</p>
    </body>
</html>
""")

    test "basic template with parameters":
        var
            ss = newStringStream()
            templ = newWithParams()
        templ.title = "T1"
        templ.content = false
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
    <head>
        <title>T1</title>
    </head>
    <body>
        <h1>Heading</h1>
    </body>
</html>
""")

        ss = newStringStream()
        templ.title = "T2"
        templ.content = true
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
    <head>
        <title>T2</title>
    </head>
    <body>
        <h1>Heading</h1>
        <p>Content</p>
    </body>
</html>
""")

    test "tag classes":
        var
            ss = newStringStream()
            templ = newTagClasses()
        templ.render(ss)
        ss.flush()
        check ss.data == """<body class="main"><p class="first">First paragraph</p><p class="second last">Second paragraph</p><footer class="footer realLast">Footer</footer></body>"""
    
    test "tags with direct content":
        var
            ss = newStringStream()
            templ = newTagsWithDirectContent()
        templ.render(ss)
        ss.flush()
        check ss.data == """<body><strong>Strong text</strong><a href="home.html">home</a></body>"""
    
    test "variables":
        var
            ss = newStringStream()
            templ = newVariables()
        templ.render(ss)
        ss.flush()
        check ss.data == """<ul class="d"><li>a</li><li>c</li><li>b</li></ul>"""
    
    test "public":
        var
            ss = newStringStream()
            templ = newPublicTemplate()
        templ.render(ss)
        ss.flush()
        check ss.data == """<body><p>Content</p></body>"""
