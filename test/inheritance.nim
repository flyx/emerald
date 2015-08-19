import testbase

proc base_templ() {. html_templ .} =
    {. compact_mode = true .}
    body:
        block content:
            p: "Base content"

proc prepend_child() {. html_templ: base_templ .} =
    prepend content:
        p: "Prepended content"

proc replace_child() {. html_templ: base_templ .} =
    replace content:
        p: "Replacing content"

proc append_child() {. html_templ: base_templ .} =
    append content:
        p: "Appended content"

proc replace_child_child() {. html_templ: replace_child .} =
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

proc child_without_additional_params() {. html_templ: base_with_params .} =
    replace content:
        p: "Content"

proc child_with_additional_params(content: string)
        {. html_templ: base_with_params .} =
    replace content:
        p: content

proc setting_parent_params_in_child() {.html_templ: base_with_params.} =
    {.debug=true.}
    title = "MyTitle"
    num = 3
    replace content:
        p: "Content"

suite "inheritance":
    test "base template with block":
        var
            ss = newStringStream()
            templ = newBaseTempl()
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<body><p>Base content</p></body>""")

    test "inheritance with prepend":
        var
            ss = newStringStream()
            templ = newPrependChild()
        templ.render(ss)
        ss.flush()
        check diff(ss.data,
                """<body><p>Prepended content</p><p>Base content</p></body>""")
    
    test "inheritance with replace":
        var 
            ss = newStringStream()
            templ = newReplaceChild()
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<body><p>Replacing content</p></body>""")
    
    test "inheritance with append":
        var
            ss = newStringStream()
            templ = newAppendChild()
        templ.render(ss)
        ss.flush()
        check diff(ss.data,
                """<body><p>Base content</p><p>Appended content</p></body>""")

    test "double inheritance with replace and append":
        var
            ss = newStringStream()
            templ = newReplaceChildChild()
        templ.render(ss)
        ss.flush()
        check diff(ss.data,
             """<body><p>Replacing content</p><p>Appended content</p></body>""")
    
    test "inheritance with template params":
        var
            ss = newStringStream()
            templ = newChildWithoutAdditionalParams()
        templ.title = "Titel 1"
        templ.num = 2
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<head><title>Titel 1</title></head><body><ul><li>1</li><li>2</li></ul><p>Content</p></body>""")
    
    test "inheritance with template params in child":
        var
            ss = newStringStream()
            templ = newChildWithAdditionalParams()
        templ.title = "Titel 2"
        templ.num = 1
        templ.content = "Mimimi"
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<head><title>Titel 2</title></head><body><ul><li>1</li></ul><p>Mimimi</p></body>""")
    
    test "setting parent parameters in child template":
        var
            ss = newStringStream()
            templ = newSettingParentParamsInChild()
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<head><title>MyTitle</title></head><body><ul><li>1</li><li>2</li><li>3</li></ul><p>Content</p></body>""")