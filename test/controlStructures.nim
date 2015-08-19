import testbase

proc if_test(b1: bool, b2: bool, b3: bool) {.html_templ.} =
    {. compact_mode = true .}
    body:
        if b1:
            header:
                if b2:
                    h1: "B2"
                else:
                    h1: "NoB2"
                h2: "Subtitle"
        elif b3:
            d:
                if b2:
                    h1: "B2"
                else:
                    h1: "NoB2"
                h2: "Subtitle"
        else:
            img(src="heading")

proc case_test(i: int) {.html_templ.} =
    {. compact_mode = true .}
    body:
        case i
        of 1:
            h1: "1"
        of 2:
            p: "2"
        of 3:
            nav:
                p: "3"
        of 10:
            footer:
                p: "10"
        else: "default"

suite "control structures":
    test "if":
        var
            ss = newStringStream()
            templ = newIfTest()
        templ.b1 = false
        templ.b2 = false
        templ.b3 = false
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<body><img src="heading"/></body>""")
        ss = newStringStream()
        templ.b1 = true
        templ.render(ss)
        ss.flush()
        check diff(ss.data,
             """<body><header><h1>NoB2</h1><h2>Subtitle</h2></header></body>""")
        ss = newStringStream()
        templ.b2 = true
        templ.render(ss)
        ss.flush()
        check diff(ss.data,
               """<body><header><h1>B2</h1><h2>Subtitle</h2></header></body>""")
        ss = newStringStream()
        templ.b1 = false
        templ.b3 = true
        templ.render(ss)
        ss.flush()
        check diff(ss.data,
                """<body><div><h1>B2</h1><h2>Subtitle</h2></div></body>""")
    
    test "case":
        var
            ss = newStringStream()
            templ = newCaseTest()
        templ.i = 1
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<body><h1>1</h1></body>""")
        ss = newStringStream()
        templ.i = 2
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<body><p>2</p></body>""")
        ss = newStringStream()
        templ.i = 3
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<body><nav><p>3</p></nav></body>""")
        ss = newStringStream()
        templ.i = 4
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<body>default</body>""")
        ss = newStringStream()
        templ.i = 10
        templ.render(ss)
        ss.flush()
        check diff(ss.data, """<body><footer><p>10</p></footer></body>""")
