import unittest

include ../src/emerald

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
        var ss = newStringStream()
        if_test.render(ss, false, false, false)
        ss.flush()
        check ss.data == """<body><img src="heading"/></body>"""
        ss = newStringStream()
        if_test.render(ss, true, false, false)
        ss.flush()
        check ss.data == """<body><header><h1>NoB2</h1><h2>Subtitle</h2></header></body>"""
        ss = newStringStream()
        if_test.render(ss, true, true, false)
        ss.flush()
        check ss.data == """<body><header><h1>B2</h1><h2>Subtitle</h2></header></body>"""
        ss = newStringStream()
        if_test.render(ss, false, true, true)
        ss.flush()
        check ss.data == """<body><div><h1>B2</h1><h2>Subtitle</h2></div></body>"""
    
    test "case":
        var ss = newStringStream()
        case_test.render(ss, 1)
        ss.flush()
        check ss.data == """<body><h1>1</h1></body>"""
        ss = newStringStream()
        case_test.render(ss, 2)
        ss.flush()
        check ss.data == """<body><p>2</p></body>"""
        ss = newStringStream()
        case_test.render(ss, 3)
        ss.flush()
        check ss.data == """<body><nav><p>3</p></nav></body>"""
        ss = newStringStream()
        case_test.render(ss, 4)
        ss.flush()
        check ss.data == """<body>default</body>"""
        ss = newStringStream()
        case_test.render(ss, 10)
        ss.flush()
        check ss.data == """<body><footer><p>10</p></footer></body>"""
