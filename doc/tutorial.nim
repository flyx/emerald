include ../src/emerald

import layout

layout.sites.add((title: "Tutorial", url: "tutorial.html", anchors: @[]))

proc tut*() {. html_templ: layout .} =
    title = "Tutorial"
    replace content:
        h1: "Tutorial"
        section:
            p:
                """To be able to use emerald, you need to have it available on
                your system. The easiest way to do that is to use the """
                a(href="https://github.com/nim-lang/nimble",
                "Nimble package manager"); ":"
            d.highlight: pre: "$ nimble install emerald"
            p: """Now using emerald consists of three simple steps:"""
            ol:
                li: "Include "; code("emerald"); " in your code."
                li: "Write templates"
                li: "Call your templates"
            p: "Sounds easy enough, doesn't it? Let's look at the details."
        section:
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                "import emerald"
            
                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "import it."
            h2: "1. Import "; code("emerald")
            p:
                "The "; code("emerald"); """ module exports everything you need
                to use emerald: The """; code("streams"); """ module from the
                standard library, and the emerald modules """; code("html")
                " and "; code("filters"); "."
        section:
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
proc templ(pageTitle: string) {.html_templ.} =
    html(lang="en"):
        head:
            title: pageTitle
        body:
            p: "Content"; br(); "More content"
                """
            
                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "write a template."
            h2: "2. Write templates"
            p:
                """You start writing a template with a proc header. The name
                of the proc is the name of your template. The template may take
                any number of parameters and may not have a return value. Then,
                you apply the macro """; code("html_templ")
                """ to it. This macro is provided by emerald and will parse
                the body of the proc as html template."""
            p:
                """In the body, every call that is a statement is interpreted as
                HTML tag. A call is a statement if it is not part of an
                expression, or put more simply: If it stands alone on its line.
                Calls may take two forms: Either a simple call (e.g. """
                code("br()"); """) or a call with a child block (e.g. """
                code("head:"); """). The example shows you how this looks in
                action."""
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
proc templ(numItems: int) {.html_templ.} =
    html(lang="en"):
        const myTitle = "Title"
        head:
            title: myTitle
        body:
            if numItems > 0:
                ul:
                    var content = "x"
                    for i in 1 .. items:
                        li: content
                        content = content & "x"
"""

                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "use variables and control structures."
            p:
                "You can use "; code("if"); ", "; code("case"); " and " 
                code("for"); """ loops inside templates. You can also define and
                use variables with """; code("var"); ", "; code("let"); " and "
                code("const"); """. Every expression that stands alone on a line
                and is not a call will be transformed to a string and written to
                the output HTML. By default, all string output will be filtered
                to escape special HTML characters ("""; code("&"); ", "
                code("<"); ", "; code(">"); ")."
            p:
                """
                emerald checks your HTML structure when parsing your templates.
                It may not be a fully replacement for the W3C HTML 5 validator,
                but it throws errors when you try to use HTML tags at places
                where they are forbidden, or if you forget to set required
                attributes. By the way, attributes can be set as named
                parameters, as you can see on the """; code("html")
                """ element in the example. Instead of the string, you can
                use any expression to define the attribute's value. Some HTML
                attributes have names that are also keywords in Nim. When you
                set them, you need to use backticks around the name (e.g. """
                code("`type`"); ")."
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
proc templ(numItems: int) {.html_templ.} =
    html(lang="en"):
        var i = 1
        ul:
            li: i
            discard inc(i)
            li: i
            li:
                put substr("foobar", i)
"""

                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption:
                    "use "
                    code: "put"
                    " and "
                    code: "discard"
                    " to call procs."
            p:
                """Be aware that while emerald allows you to embed quite much
                business logic in your template, you shouldn't embed program
                logic in the template unless it's absolutely necessary. Other
                templating engines like e.g. """
                a(href="http://mustache.github.io", "mustache")
                """ forbid you by design to embed any logic in the template,
                because the template is not the place for it. emerald allows it
                because it doesn't want to stand in your way, so it's up to you
                to use its features with care."""
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
proc mySection(title: string) {.html_mixin.} =
    section:
        h1: title
        put mixin_content()

proc templ(numItems: int) {.html_templ.} =
    html(lang="en"):
        body:
            call_mixin mySection("First section"):
                p: "Content"
            call_mixin mySection("Second section"):
                p: "More content"
"""

                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "define and use mixins."
            p:
                """As any standalone call will create an HTML tag, emerald
                provides a special syntax to actually call procs: Use the
                familiar """; code("discard"); """ command to call a proc
                without using its return value, and the emerald-specific """
                code("put"); " command to output the return value of a call."
            p:
                """If you have a snippet which you want to use multiple times,
                or if you want to just separate a piece of your template from
                the rest, you can use """; em("mixins")
                """. Mixins are snippets you can include multiple times in your
                template. Like the template itself, mixins can take any number
                of parameters. Mixins are even able to take block content as
                input, which can be called from inside the mixin by using the
                special call """
                code: "mixin_content()"
                ". In the template, you can call the mixin with the command "
                code: "call_mixin"
                ". Look at the example to see how this works."
            p:
                """There is no syntax to call another template from within a
                template, because this is not considered a use-case that makes
                sense. But you can call mixins from within mixins."""
        section:
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
var
    ss = newStringStream()
    myTempl = newTempl()
myTempl.numItems = 3
myTempl.render(ss)
"""

                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "call your template."
                
            h2: "3. Call your templates"
            p:
                """While you write your template as proc, it isn't a proc
                anymore after emerald has parsed it. Instead, it is an object
                type. You can create a new instance with """;
                code:
                    "new"; em("Name"); "()"
                """. This proc never takes parameters. The
                parameters you declared for the template are settable as object
                values. You can render the template by calling the object's """
                code("render"); " proc. This proc takes a "; code("Stream")
                """ as second parameter after the template instance. When
                calling """; code("render")
                """, the template will be rendered into the given stream."""
            p:
                """This concludes the tutorial. For a more detailed
                documentation of emerald's features, refer to the """
                a(href="documentation.html", "documentation section"); "."