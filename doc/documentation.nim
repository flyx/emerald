import layout

layout.sites.add((title: "Documentation", url: "documentation.html",
                  anchors: @[("Interface", "interface"), ("Tags", "tags"),
                             ("Attributes", "attributes"),
                             ("Text Content", "content"),
                             ("Control Structures", "control"),
                             ("Pragmas", "pragmas"), ("Filters", "filters"),
                             ("Template inheritance", "inheritance")]))

proc doc*() {. html_templ: layout .} =
    title = "Documentation"
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
            p:
                """Like Nim itself, emerald treats all keywords, commands and
                procs it declares independently of style and casing, so you can
                use both """; code("mixin_content"); " and "
                code("mixinContent"); """ as you please. HTML tag and
                attribute names are also parsed case-independently; however,
                the styling matters here: """; code("http_equiv")
                " is not the same as "; code("httpEquiv"); "."
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
type templ = ref object of RootObj
    param: string

proc newTempl(): templ =
    new(result)

method render(obj: templ_class, s: Stream) =
    #...
"""
                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "... the resulting AST, visualized as Nim code ..."
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
var
    ss = newStringStream()
    myTempl = newTempl()
templ.param = "foo"
templ.render(ss)
"""
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
                be parsed as HTML template. Parsing will convert the proc into
                an object type with the same name, a constructor proc for this
                type, and a method named """; code("render()")
                " that operates on this type. This is shown in the example code."
            p:
                "The "; code("render"); """ method takes an instance of the 
                template object as first parameter and a """; code("Stream")
                """ as second parameter. The object type, the constructor proc
                and the render method will have the same visibility as the
                original proc, so you can have private and public templates."""
            p:
                """All parameters of the original proc will be transformed into
                fields of the resulting object type. This enables you to re-use
                an object instance multiple times without needing to specify all
                parameters each time."""
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
                calling """; code("mixin_content()"); ". If you call "
                code("mixin_content()"); """ in the mixin code, but do not
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
                which only generate a part of an HTML DOM-tree. You would
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
        
        # defining data attributes
        const varValue = "value2"
        d(data={"key1": "value1", "key2": varValue})
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
            p:
                "Some HTML attributes contain a "; code("-"); """ in their name.
                This cannot be a part of a Nim identifier. Therefore, you must
                use a """; code("_"); """ instead. So, for example, you have to
                write """; code("http_equiv"); " instead of "
                code("http-equiv"); """. Also be aware that attribute names are
                case and style sensitive."""
            h3(id="data-attributes"): "Data Attributes"
            p:
                """HTML 5 allows any HTML tag to have an arbitrary number of """
                em("data"); " attributes, named like this: "; code("data-*")
                """emerald treats these values as a table, meaning that you can
                assign the """; code("data"); " attribute a "
                a(href="http://nim-lang.org/docs/manual.html#statements-and-expressions-table-constructor",
                        "table constructor");
                """. This constructor must have string literals as keys, so that
                emerald can check the validity of the names at compile time - it
                doesn't make much sense to define the data attribute names with
                variables anyway. The value of each data attribute may be any
                expression. The example shows how to set data attributes."""
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
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
proc templ() {.html_templ.} =
    # define variables
    const max = 5
    var current = 2
    
    ul:
        # use a for loop
        for i in 0 .. val:
            li:
                # use if
                if i == current:
                    i
                else:
                    a(href=$i & ".html", i)
"""
                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "using control structures"
            h2(id="control"): "Control structures"
            p:
                """Most of Nim's control structures are directly usable in
                emerald: You can use """; code("if"); ", "; code("case")
                " and "; code("while"); """ just like you would in Nim code.
                You can also declare and assign variables in your template.
                However, you cannot do everything in emerald you could do in
                Nim, and if you need to write logic that spans more than a few
                lines, it is probably a good idea to write it in a proper Nim
                proc and call that from within your template."""
        
        section:
            h2(id="pragmas"): "Pragmas"
            p:
                """You can modify the way emerald compiles your template by
                using pragmas. Pragmas use the usual Nim syntax """
                code: "{. "; em("pragma here"); " .}"
                """. emerald supports the following pragmas:"""
            dl:
                dt:
                    code: "{. compact_mode = "; em("val"); " .}"
                dd:
                    """Toggles whether the generated HTML should be written
                    in human-readable form with newlines and indentation, or as
                    compact as possible without any unnecessary whitespace. """
                    em("val"); " may be either "; code("true"); " or "
                    code("false"); ", default value is "; code("false"); "."
                    
                dt:
                    code: "{. indent_step = "; em("val"); " .}"
                dd:
                    """Sets the amount of spaces added to every new level of
                    indentation. """; em("val"); """ may be any non-negative
                    integer value. default is """; code("4"); "."
                dt:
                    code: "{. preserve_whitespace = "; em("val"); " .}"
                dd:
                    """Defines whether the lines of generated text content will
                    be indented to the current output indentation, removing any
                    existing indentation. """; em("val"); " may be "
                    code("true"); " or "; code("false"); ", default is "
                    code("false"); ". If "; code("true"); """, the existing
                    whitespace at the beginning of each line for text output
                    will be preserved and no indentation will be applied (
                    regardless of the value of """; code("compact_mode")
                    """. This is useful when inserting source code or anything
                    similar in your HTML page."""
                dt:
                    code: "{. debug = "; em("val"); " .}"
                dd:
                    """Enables or disables debugging output. If enabled,
                    emerald will output the generated AST as Nim code to
                    stdout. """; em("val"); " may be "; code("true"); " or "
                    code("false"); ", default is "; code("false"); "."
                dt:
                    code: "{. filters = "; em("filter_chain"); " .}"
                dd:
                    """This pragma manipulates the filter chain and is 
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
            # escape_html is active here, because
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
                    code:
                        """rst(options: TRstParseOptions = {},
                         config: StringTableRef = newStringTable())"""
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
            figure:
                {. filters = pygmentize("nim") .}
                {. preserve_whitespace = true .}
                """
proc parent(title: string,
            homeUrl: string) {. html_templ .} =
    html(lang="en"):
        head:
            title: title
        body:
            h1:
                a(href=homeUrl): title
            block content: discard

proc home() {. html_templ: parent .} =
    title = "Home"
    replace content:
        p: "Content"
"""
                {. filters = escape_html() .}
                {. preserve_whitespace = false .}
                figcaption: "inheriting from a template"
        
            h2(id="inheritance"): "Template Inheritance"
            p:
                """You can inherit from templates by specifying the parent
                template when declaring the child template. This will make the
                generated object type of the child template inherit from the
                object type of the parent template."""
            p:
                """In any template that inherits from another template, you
                cannot have HTML tags or text content nodes on the root level.
                However, you can assign values to the parent template's
                parameters. For adding content, you use the following commands:
                """; code("prepend"); ", "; code("replace"); " and ";
                code("append"); """. Each of these takes one argument and must
                have a child block. The argument must be the name of a block in
                any parent template (does not need to be the immediate parent).
                """; code(" prepend"); """ will add its content before the
                content of the block in the parent template, """
                code("replace"); """ will completely replace the content of the
                block, and """; code("append"); """ will append its content to
                the block in the parent template."""
            p:
                """Blocks must always have names in templates. You may still use
                them for scoping variables as you can do it in Nim, but be aware
                that each block will be compiled into a multimethod."""