import testbase

proc singleAttribute() {.html_templ.} =
    {.compact_mode = true.}
    d(id="myId"):
        p: "Content"

proc multipleAttributes() {.html_templ.} =
    {.compact_mode = true.}
    img(src="src", alt="alt")

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