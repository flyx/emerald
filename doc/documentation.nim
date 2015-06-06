include ../src/emerald

import layout

layout.sites.add((title: "Documentation", url: "documentation.html",
                  anchors: @[("Interface", "interface"), ("Tags", "tags"),
                             ("Attributes", "attributes"),
                             ("Text Content", "content"),
                             ("Pragmas", "pragmas"), ("Filters", "filters"),
                             ("Template inheritance", "inheritance")]))

proc doc*(sites: seq[site])
    {. html_templ: layout("Documentation", sites) .} =
    replace content:
        h1: "Documentation"
        section:
            p:
                """This is the complete documentation of emerald. It explains
                all of emerald's features and also explains implementation
                details, so it is also the developer documentation. The reader
                is expected to be used to the Nim programming language and its
                concepts."""
            p:
                """emerald tries to omit HTML that is valid """
                a(href="http://www.w3.org/TR/html-polyglot/", "polyglot markup")
                """, i.e. that is valid HTML 5 and also valid XHTML. This means
                that emerald writes properly closed HTML tags in all cases, uses
                quotes for attribute values, and writes a value for boolean
                attributes where HTML permits the value to be omitted. The goal
                is for emerald's output to be as robust as possible."""
        section:
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                "proc templ(param: string) {.html_templ.} =\n    #..."

                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "input..."
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
let templ = templ_class()

proc render(obj: templ_class, s: Stream, param: string) =
    #...
"""
                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "... the resulting AST, visualized as Nim code ..."
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                "var ss = newStringStream()\ntempl.render(ss, \"foo\")"

                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "... and how to use it in your code."
            
            h2(id="interface"): "Interface"
            p:
                "The two macros "; code("html_templ"); " and "
                code("html_mixin"); """ are the main API of emerald. The only
                other things that are publicly exposed are the filters that
                come with emerald. These are explained in """
                a(href="#filters", "Filters"); "."
            h3: code("html_templ")
            p: 
                """This macro can only be applied to a proc. This proc may not
                have a return type and may be publicly exposed (via """
                code("*"); """) or private. The whole content of the proc will
                be parsed as HTML template. Parsing will create a """
                code("let"); """ variable with the name of the parsed proc, so
                if you have a proc called """; code("templ")
                ", you will have a "; code("let"); " variable named "
                code("templ"); "."
            p:
                """"The template code is written into a proc named """
                code("render"); """, which takes the """; code("let")
                """ variable as first parameter and a """; code("Stream")
                """ as second parameter. After those parameters, the parameters
                you defined on the original template proc follow. The """
                code("render"); " proc and the "; code("let"); """ variable will
                have the same visibility as the original proc, so you can have
                private and public templates."""
            p:
                "The example shows a type name "; code("templ_class"); """. This
                is not the actual name of the generated type; you will never
                need to use this name in your code nor are you able to, because
                it's created with """; code("genSym"); """. The type does not
                have any content, it is only used for implementing """
                a(href="#inheritance", "template inheritance"); "."
            h3: code("html_mixin")
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
proc wrapWithSection(title: string) {.html_mixin.} =
    section:
        h1: title
        put mixin_content()

proc templ() {.html_templ.} =
    body:
        call_mixin wrapWithSection("Overview"):
            p: "Foo"
        call_mixin wrapWithSection("Details"):
            p: "Bar"
"""

                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "define and use a mixin"
            p:
                """This macro must also be applied to a proc that has no return
                value. Parsing it will not produce any nodes in the resulting
                AST; instead, it is parsed directly into the """
                code("render"); """ proc at each place where it is called. There
                are two reasons for doing that: Firstly, it enables emerald to
                validate the HTML structure at each position where it is called.
                Secondly, the resulting HTML is properly indented everywhere."""
            p:
                "Mixins can be called with the "; code("call_mixin")
                """ command. The command takes the call to the mixin as first
                parameter; you have to give all parameters you defined for the
                mixin there. You can also give a block as second parameter, in
                which case this block can be called from within the mixin by
                calling """; code("mixin_content()"); ". If you  call "
                code("mixin_content()"); """ in the mixin code, but you don't
                supply a block as parameter in the template where you call the
                mixin, emerald will exit with an error message."""
        section:
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
proc templ() {.html_templ.} =
    # a tag with a child block
    body:
        # a tag without a child block
        img(src="foo.png")
        
        # a tag which has its content defined as
        # direct content
        strong("Content")
        
        # a tag condensed into one line along with
        # two string literals
        "foo"; br(); "bar"
        
        # a <div> can be written as "d"
        d:
            # a tag with a class
            p.someClass: "Bar"
            
            # a tag with two classes that needs
            # to be escaped
            `object`.foo.bar: "Foo"
"""

                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "using the tag syntax"
        
            h2(id="tags"): "Tags"
            p:
                """In an HTML template, every standalone call is interpreted as
                HTML tag. Standalone means that the call is not part of an
                expression, or in simpler terms: The call is written on its own
                line with nothing else there. You can of course condense 
                multiple lines by using semicolons to make your code more
                compact. Standalone calls may, but do not need to, have a child
                block. The structure of the tags is validated according to the
                HTML 5 specification. Infix expressions are not considered to
                be calls; they will be parsed as text content generators (see
                below)."""
            p:
                "The content of a tag may also be given as ";
                em("direct content"); """, meaning that it is written as
                parameter into the brackets of the tag, rather than into the
                child block. This may be convenient for tags that usually occur
                between character data, like e.g. """; code("<strong>"); "."
            p:
                """If a tag name is also a keyword name in Nim, you have to put
                the tag name between accents, like this: """; code("`object`")
                """. As a special feature, you can write """; code("d"); " for "
                code("<div>"); " tags, because they are pretty common and "
                code("div"); " is a keyword in Nim."
            p:
                """You can give tags classes by using the dot notation, as
                illustrated in the example. Tags can have any number of classes.
                The dot notation is somewhat limited, because you cannot use
                expressions for defining the class name, so you can also set the
                attribute """; code("class"); """. You can use both dot notation
                and the """; code("class"); " attribute on one tag."
            p:
                "The "; code("html"); """ tag is kind of a special feature. It
                automatically emits the HTML 5 doctype, gets a proper XML
                namespace definition, and its required attribute """
                code("lang"); " gets automatically copied into the attribute "
                code("xml:lang"); """, which is necessary for valid XHTML. That
                does not mean that you must start every template with an """
                code("html"); """ tag - it is perfectly fine to write templates
                which only generate a part of a compile HTML DOM-tree. You would
                use such templates e.g. for AJAX-based websites."""
        section:
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
proc templ() {.html_templ.} =
    # required attribute; emerald will terminate
    # with an error if it's omitted
    html(lang="en"):
        let large = false
        
        # complex expression as value 
        img(src=if large: "foo-large.png"
            else: "foo.png")

        # attribute name that must be escaped
        script(`type`="text/javascript",
               src="foo.js")
        
        var myClass="active"
        # defining classes with dot notation
        # and attribute
        d.main(class=myClass)
"""

                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "set attribute values"
            h2(id="attributes"): "Attributes"
            p:
                """For each tag, attributes can be specified in the brackets of
                the tag call. The name of the attribute comes first, followed by
                an equals sign and the value of the attribute. The value may be
                any Nim expression. Attributes which are specified to be
                boolean, such as """; code("checked"); " or "; code("readonly")
                ", must have an expression of Nim type "; code("bool")
                """ as value. All other attribute values will be converted into
                strings."""
            p:
                """Like tags, attributes are validated by emerald. A missing
                required attribute and an attribute that is not allowed for the
                tag that contains it both lead to an error message."""
            p:
                """Attribute values are automatically filtered. Unlike the
                filtering of normal text, the filtering of attribute values
                cannot be customized, because there is no use-case for that
                (please file an issue if you can think of one). Filtering will
                convert the characters """; code("<"); ", "; code(">"); ", "
                code("&"); ", "; code("\""); " and "; code("'")
                " to their corresponding HTML entities."
        section:
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
proc templ() {.html_templ.} =
    # simple string literal
    "Foobar"
    
    # triple quoted string literal
    """""" & """Lorem ipsum dolor sit amet,
    consectetur adipiscing elit. Quisque
    nibh leo, tincidunt in feugiat ac,
    egestas ac libero."""""" & """
    
    
    # result of an infix call
    2 + 2
    
    var a = "foo"
    # the value of a variable
    a
    
    # the value of a proc call
    put getDateStr()
    
    var i = 1
    # call a proc without a return value
    discard inc(i)
"""
                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "creating text content"
            h2(id="content"): "Text Content"
            p: 
                """Text content is generated by every expression that is used as
                a statement, excluding calls (which are used for creating HTML
                tags). The simplest way to generate text content is to use
                string literals. Infix expressions also generate text content,
                although they are technically calls. The operator """; code("$")
                """ is used to transform any value into a string for outputting
                it."""
            p: 
                """If you want to call a proc and output the result as text
                content, you have to use the command """; code("put"); """,
                because normal calls are interpreted as HTML tags. If you just
                want to call a proc without using its return value - or a proc
                which does not have a return value at all - use """
                code("discard"); "."
            p:  
                """All text content is processed by the current filter chain
                before being written to the output. By default, this converts
                the HTML characters """; code("<"); ", "; code(">"); " and "
                code("&"); """ to their corresponding HTML entities. The filter
                chain can be customized to your needs, see the next section."""
        section:
            h2(id="pragmas"): "Pragmas"
            p:
                """You can modify the way emerald compiles your template by
                using pragmas. Pragmas use the usual Nim syntax """
                code("{. pragma here .}"); """. emerald supports the following
                pragmas:"""
            dl:
                dt:
                    code: "{. compact_mode = "; em("val"); " .}"
                dd:
                    """ Toggles whether the generated HTML should be written
                    in human-readable form with newlines and indentation, or as
                    compact as possible without any unnecessary whitespace."""
                    em("val"); " may be either "; code("true"); " or "
                    code("false"); ", default value is "; code("false"); "."
                    
                dt:
                    code: "{. indent_step = "; em("val"); " .}"
                dd:
                    """ Sets the amount of spaces added to every new level of
                    indentation. """; em("val"); """ may be any non-negative
                    integer value. default is """; code("4")
                dt:
                    code: "{. preserve_whitespace = "; em("val"); " .}"
                dd:
                    """ Sets whether the lines of generated text content will
                    be indented to the current output indentation, removing any
                    existing indentation. """; em("val"); " may be "
                    code("true"); " or "; code("false"); ", default is "
                    code("false"); "."
                dt:
                    code: "{. debug = "; em("val"); " .}"
                dd:
                    """ Enables or disables debugging output. If enabled,
                    emerald will output the generated AST as nimrod code to
                    stdout. """; em("val"); " may be "; code("true"); " or "
                    code("false"); ", default is "; code("false"); "."
                dt:
                    code: "{. filters = "; em("filter_chain"); " .}"
                dd:
                    """ This pragma manipulates the filter chain and is 
                    described in detail in the next section."""
            p:
                "Apart from "; code("debug"); """, all pragmas are applied to
                the current level of your template code, not globally. That
                means that the new pragma value you have set only affects the
                content of the current HTML tag and all tags within, but not
                the part of the template outside the current HTML tag."""
        section:
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
proc templ() {.html_templ.} =
    html(lang="en"):
        head:
            # disable all filters
            {. filters = nil .}
            "<title>Title</title>"
        body:
            # escape_html is active hear, because
            # we left the tag "head"
            
            d:
                # parse the following content with
                # pygments.
                {. filters = pygmentize("nim") .}
                """""" & """
proc foo() =
    bar()
                """""" & """

                # still use pygmentize, but escape
                # the HTML characters coming from it
                {. filters = filters & escape_html() .}

                # ...
"""
        
                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "modifying the filter chain"
        
            h2(id="filters"): "Filters"
            p:
                """emerald maintains a filter chain while compiling your
                template. All text content is processed by the current filter
                chain. The filter chain may contain zero or more filters. A
                filter is a proc that takes a string as input and writes data
                to an output stream. By default, the filter chain contains one
                filter, """; code("escape_html"); """, which converts HTML
                special characters to their corresponding entities."""
            p:
                """You can modify the filter chain by using the pragma """
                code("filters"); """, which allows you to specify the filter
                chain as a list of filters separated by """; code("&")
                """ operators. You may use the identifier """; code("filters")
                """when setting this chain to insert the previously active
                filters. You may use """; code("nil"); """ to specify that no
                filter at all should be used. The code example shows how to use
                the pragma."""
            p:
                """Filters may take additional parameters. You can set them in
                brackets as seen in the example."""
            h3: "Builtin Filters"
            dl:
                dt:
                    code("escape_html(escapeQuotes: bool = false)")
                dd:
                    """Convert HTML special chars to their corresponding
                    entities. if """; code("escapeQuotes"); " is "; code("true")
                    ", "; code("\""); " and "; code("'")
                    " are escaped as well."
                dt:
                    code("rst(options: TRstParseOptions = {}, config: StringTableRef = newStringTable())")
                dd:
                    """Parses the input as RST, using Nim's internal RST
                    implementation. Be aware that the resulting HTML is not
                    validated by emerald."""
                dt:
                    code("pygmentize(language: string)")
                dd:
                    "Uses "; a(href="http://pygments.org", "pygments")
                    """ to add syntax highlighting to text output. Pygments must
                    be available on your system in order to use this filter.
                    You have to include a pygments css theme in order to
                    actually see the syntax highlighting in the rendered output.
                    """
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
proc remove_vowels(target: Stream, value : string) =
    for c in value:
        case c
        of 'a', 'e', 'i', 'o', 'u': discard
        else: target.write(c)
"""

                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "a simple filter"
            h3: "Writing Your Own Filters"
            p:
                """Filters are simple procs. If you want to write your own
                filter, you just implement it as proc. It should look like 
                this:"""
            p:
                code("proc myFilter(target: Stream, value: string, ...)")
            p:
                "At "; code("..."); """, you can add your own parameters. You
                need to give values for any non-optional parameters you add here
                when using the filter. The first two parameters are added by
                emerald when you use the filter in the filter chain."""
            p:
                """When the filter gets called, you should process """
                code("value"); " and write the result to "; code("target")
                ". That's all."
        section:
            h2(id="inheritance"): "Template Inheritance"