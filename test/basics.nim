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