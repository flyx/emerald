import testbase

proc standaloneParam(param: string) {.html_templ.} =
    {. compact_mode = true .}
    param

proc paramInExpr(param: string) {.html_templ.} =
    {. compact_mode = true .}
    "foo " & param

proc paramInIf(param: bool) {.html_templ.} =
    {. compact_mode = true .}
    if param: "foo"

proc paramInIfExpr(param: bool) {.html_templ.} =
    {. compact_mode = true .}
    if param and true: "foo"

proc paramInAttr(param: string) {.html_templ.} =
    {. compact_mode = true .}
    p(id=param)

proc paramInAttrExpr(param: bool) {.html_templ.} =
    {. compact_mode = true .}
    p(id=if param: "value" else: "foo")

proc identity(param: string): string = param

proc paramInProcCall(param: string) {.html_templ.} =
    {. compact_mode = true .}
    put identity(param)

suite "template parameters":
    test "standalone param":
        var
            ss = newStringStream()
            templ = newStandaloneParam()
        templ.param = "value"
        templ.render(ss)
        check diff(ss.data, "value")
    
    test "param in expression":
        var
            ss = newStringStream()
            templ = newParamInExpr()
        templ.param = "value"
        templ.render(ss)
        check diff(ss.data, "foo value")
    
    test "param in if condition":
        var
            ss = newStringStream()
            templ = newParamInIf()
        templ.param = true
        templ.render(ss)
        check diff(ss.data, "foo")
        ss = newStringStream()
        templ.param = false
        templ.render(ss)
        check diff(ss.data, "")

    test "param in expression in if condition":
        var 
            ss = newStringStream()
            templ = newParamInIfExpr()
        templ.param = true
        templ.render(ss)
        check diff(ss.data, "foo")
        ss = newStringStream()
        templ.param = false
        templ.render(ss)
        check diff(ss.data, "")
    
    test "param in attribute value":
        var
            ss = newStringStream()
            templ = newParamInAttr()
        templ.param = "value"
        templ.render(ss)
        check diff(ss.data, """<p id="value"></p>""")
    
    test "param in attribute value expression":
        var
            ss = newStringStream()
            templ = newParamInAttrExpr()
        templ.param = true
        templ.render(ss)
        check ss.data == "<p id=\"value\"></p>"
    
    test "param in proc call":
        var
            ss = newStringStream()
            templ = newParamInProcCall()
        templ.param = "value"
        templ.render(ss)
        check diff(ss.data, "value")