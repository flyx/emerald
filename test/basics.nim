import unittest

include ../src/emerald

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
        var ss = newStringStream()
        base.render(ss)
        ss.flush()
        check ss.data == """<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
    <head>
        <title>Basics</title>
    </head>
    <body>
        <p>Content</p>
    </body>
</html>
"""

    test "basic template with parameters":
        var ss = newStringStream()
        withParams.render(ss, "T1", false)
        ss.flush()
        check ss.data == """<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
    <head>
        <title>T1</title>
    </head>
    <body>
        <h1>Heading</h1>
    </body>
</html>
"""
        ss = newStringStream()
        withParams.render(ss, "T2", true)
        ss.flush()
        check ss.data == """<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
    <head>
        <title>T2</title>
    </head>
    <body>
        <h1>Heading</h1>
        <p>Content</p>
    </body>
</html>
"""

    test "tag classes":
        var ss = newStringStream()
        tagClasses.render(ss)
        ss.flush()
        check ss.data == """<body class="main"><p class="first">First paragraph</p><p class="second last">Second paragraph</p></body>"""
    
    test "variables":
        var ss = newStringStream()
        variables.render(ss)
        ss.flush()
        check ss.data == """<ul class="d"><li>a</li><li>c</li><li>b</li></ul>"""
        