import testbase

proc singleAttribute() {.html_templ.} =
    {.compact_mode = true.}
    d(id="myId"):
        p: "Content"

proc multipleAttributes() {.html_templ.} =
    {.compact_mode = true.}
    img(src="src", alt="alt")

proc dataAttributes() {.html_templ.} =
    {.compact_mode = true.}
    p(data={"string": "str", "number": 5})

proc paramAsDataAttribute(val: string) {.html_templ.} =
    {.compact_mode = true.}
    p(data={"key": val})

suite "attributes":
    test "single attribute":
        var
            ss = newStringStream()
            templ = newSingleAttribute()
        templ.render(ss)
        ss.flush()
        check diff(ss.data, "<div id=\"myId\"><p>Content</p></div>")
    
    test "multiple attributes":
        var
            ss = newStringStream()
            templ = newMultipleAttributes()
        templ.render(ss)
        ss.flush()
        check diff(ss.data, "<img src=\"src\" alt=\"alt\"/>")
    
    test "data attributes":
        var
            ss = newStringStream()
            templ = newDataAttributes()
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<p data-string="str" data-number="5"></p>""")
    
    test "template parameter as data attribute":
        var
            ss = newStringStream()
            templ = newParamAsDataAttribute()
        templ.val = "value"
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<p data-key="value"></p>""")