import testbase

proc simple_mixin() {. html_mixin .} =
    p: "Simple mixin"

proc simple_templ() {. html_templ .} =
    {. compact_mode = true .}
    body:
        call_mixin simple_mixin()

proc different_style_call() {. html_templ .} =
    {. compact_mode = true .}
    body:
        callMixin simple_mixin()

proc mixin_with_params(content: string) {. html_mixin .} =
    p: content

proc templ_for_mixin_with_params() {. html_templ .} =
    {. compact_mode = true .}
    body:
        call_mixin mixin_with_params("Content")

proc mixin_with_content() {. html_mixin .} =
    d:
        put mixin_content()

proc templ_for_mixin_with_content() {. html_templ .} =
    {. compact_mode = true .}
    body:
        call_mixin mixin_with_content():
            p: "Content"

proc mixin_with_params_and_content(title: string) {. html_mixin .} =
    h1: title
    d:
        put mixin_content()

proc templ_for_mixin_with_params_and_content() {. html_templ .} =
    {. compact_mode = true .}
    body:
        call_mixin mixin_with_params_and_content("Title"):
            p: "Content"

proc inner_mixin() {. html_mixin .} =
    footer:
        put mixinContent()

proc outer_mixin() {. html_mixin .} =
    d:
        call_mixin inner_mixin():
            p: "Content"
            put mixin_content()

proc templ_with_stacked_mixins() {. html_templ .} =
    {. compact_mode = true .}
    body:
        call_mixin outer_mixin():
            p: "Author"

suite "mixins":
    test "simple mixin":
        var
            ss = newStringStream()
            templ = newSimpleTempl()
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<body><p>Simple mixin</p></body>""")
    
    test "call mixin with different style":
        var
            ss = newStringStream()
            templ = newDifferentStyleCall()
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<body><p>Simple mixin</p></body>""")
    
    test "mixin with params":
        var
            ss = newStringStream()
            templ = newTemplForMixinWithParams()
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<body><p>Content</p></body>""")
    
    test "mixin with content":
        var
            ss = newStringStream()
            templ = newTemplForMixinWithContent()
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<body><div><p>Content</p></div></body>""")
    
    test "mixin with params and content":
        var
            ss = newStringStream()
            templ = newTemplForMixinWithParamsAndContent()
        templ.render(ss)
        ss.flush()
        check diff(ss.data,
                """<body><h1>Title</h1><div><p>Content</p></div></body>""")
    
    test "stacked mixins":
        var
            ss = newStringStream()
            templ = newTemplWithStackedMixins()
        templ.render(ss)
        ss.flush()
        check diff(ss.data,
                """<body><div><footer><p>Content</p><p>Author</p></footer></div></body>""")
