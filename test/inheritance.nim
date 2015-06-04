import unittest

include ../src/emerald

proc base_templ() {. html_templ .} =
    {. compact_mode = true .}
    {. debug = true .}
    body:
        block content:
            p: "Base content"

proc prepend_child() {. html_templ: base_templ() .} =
    {. debug = true .}
    prepend content:
        p: "Prepended content"

proc replace_child() {. html_templ: base_templ() .} =
    replace content:
        p: "Replacing content"

proc append_child() {. html_templ: base_templ() .} =
    append content:
        p: "Appended content"

proc replace_child_child() {. html_templ: replace_child() .} =
    append content:
        p: "Appended content"

proc base_with_params(title: string, num: int) {. html_templ .} =
    {. compact_mode = true .}
    head:
        title: title
    body:
        ul:
            for i in 1..num:
                li: i
        block content:
            discard

proc child_with_params(title: string) {. html_templ: base_with_params(title, 2) .} =
    replace content:
        p: "Content"

suite "inheritance":
    test "base template with block":
        var ss = newStringStream()
        base_templ.render(ss)
        ss.flush()
        check ss.data == """<body><p>Base content</p></body>"""

    test "inheritance with prepend":
        var ss = newStringStream()
        prepend_child.render(ss)
        ss.flush()
        check ss.data == """<body><p>Prepended content</p><p>Base content</p></body>"""
    
    test "inheritance with replace":
        var ss = newStringStream()
        replace_child.render(ss)
        ss.flush()
        check ss.data == """<body><p>Replacing content</p></body>"""
    
    test "inheritance with append":
        var ss = newStringStream()
        append_child.render(ss)
        ss.flush()
        check ss.data == """<body><p>Base content</p><p>Appended content</p></body>"""

    test "double inheritance with replace and append":
        var ss = newStringStream()
        replace_child_child.render(ss)
        ss.flush()
        check ss.data == """<body><p>Replacing content</p><p>Appended content</p></body>"""
    
    test "inheritance with template params":
        var ss = newStringStream()
        child_with_params.render(ss, "Titel 1")
        ss.flush()
        check ss.data == """<head><title>Titel 1</title></head><body><ul><li>1</li><li>2</li></ul><p>Content</p></body>"""