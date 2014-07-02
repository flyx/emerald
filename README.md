# HTML 5 templating engine for Nimrod

## Overview

Emerald is a macro-based type-safe templating engine for producing well-formed
HTML 5 web pages with Nimrod. It's currently under development. Most features
are still missing.

It is basically a domain-specific language implemented on top of the Nimrod
parser, utilizing Nimrod's macro system. Your HTML template will be parsed
along with your code. The template engine checks whether your HTML structure
is well-formed according to the HTML 5standard - however, it will not cover all
restrictions and rules of the specification. Rules that are covered are:

 * HTML tags are only allowed to contain child tags that are allowed by the
   specification.
 * HTML tags may only have attributes that are allowed by the specification
 * HTML tags must have attributes and childs that are required by the
   specification.

Emerald has been inspired by [Jade][1] and [HAML][2]. But it doesn't use
RegEx for parsing its templates like Jade does *HOW COULD YOU EVEN THINK OF
DOING THAT SERIOUSLY*. Instead, it uses the awesome Nimrod compile-time
infrastructure.

Here is an example template to demonstrate what already works:

```nimrod
proc templ(youAreUsingEmerald: bool) {.html_template.} =
    html(lang = "en"):
        head:
            title: "pageTitle"
            script (`type` = "text/javascript"): """
                if (foo) {
                    bar(1 + 5)
                }
                """
        body:
            h1: "Emerald - Nimrod HTML5 templating engine"
            d.content:
                if youAreUsingEmerald:
                    p:
                        "You are amazing"; br(); "Continue."
                else:
                    p: "Get on it!"
                p: """
                   Emerald is a macro-based type-safe
                   templating engine which validates your
                   HTML structure and relieves you from
                   the ugly mess that HTML code is.
                   """
```

This produces:

```html
<!DOCTYPE html>
<html lang="en">
    <head>
        <title>pageTitle</title>
        <script type="text/javascript">
            if (foo) {
                bar(1 + 5)
            }
        </script>
    </head>
    <body>
        <h1>Emerald - Nimrod HTML5 templating engine</h1>
        <div class="content">
            <p>You are amazing<br />Continue.</p>
            <p>
                Emerald is a macro-based type-safe
                templating engine which validates your
                HTML structure and relieves you from
                the ugly mess that HTML code is.
            </p>
        </div>
    </body>
</html>
```

## Usage

Emerald templates are written as procedures. Just write a procedure
declaration, add any parameters you need, and then add the pragma
`html_template`. This will parse the contents of the procedure
implementation as HTML template. To be able to use the template macros,
you must **include** (not import) the module `emerald.html_templates`.

To use the template, just call it by the name you gave it, **pass
a `PStream` as first argument**, and give values for the parameters
*you* declared afterwards. The `PStream` parameter is injected automatically,
and the `streams` package is imported automatically - do not import it again.

As Emerald generates some declarations of variables and parameters, you have
to treat *all* identifiers starting with `emerald` as reserved - do not use
any identifiers starting with `emerald` inside your HTML templates.

### Hello, World

Here's *Hello, World* in Emerald:

```nimrod
include emerald.html_templates

proc hello() {.html_template.} =
  html:
    head:
      title: "Hello, World!"
    body:
      p: "Hello, World!"


hello(newFileStream(stdout))
```

Compile this with the Nimrod compiler and execute.


## Features

This list of features grows as things get implemented.

### HTML tags

All HTML tags that are valid HTML 5 are allowed. Deprecated tags and attributes
are *not* allowed. There are two ways to add HTML tags:

 * As block nodes: The HTML nodes start a block, which contains the content of
   the node.

   ```nimrod
   head:
       title: "Page title"
   ```

 * As function calls: The HTML nodes look like procedure calls. These calls
   must not be used in expressions, but as standalone statements. Any calls
   used as part of an expression will be resolved as usual nimrod calls.

   ```nimrod
   p: "Some text"; br(); "Some more text"
   ```

   Note that the semicolons are mandatory. You can replace them with line breaks.

Because the `div` tag is used so frequently, it has `d` as shorthand.

The structure will get validated when it is parsed. This validator doesn't
check against the complete HTML 5 specification, but it is intelligent enough
to tell you when you use tags at places where they are forbidden. It also won't
accept tag names it doesn't know.

### String content

String content can be included as string literals. Long literals and infix
operators work, too. Emerald tries to preserve indentation within long string
literals (for JavaScript and such). It strips leading and trailing whitespace per
line and adds its own indentation instead so that the output looks nice.

The characters `<`, `>` and `&` are converted to their corresponding HTML
entity automatically. For attribute values, the characters `'` and `"` are
also converted.

### Control structures

`if`, `elif`, `else`, `when`, `for`, `while` and `case` work exactly as in Nimrod.

### Variables

You can declare variables using `var`, `let`, `const` everywhere. You can assign
variables with a normal assignment statement everywhere. You can output variables
by writing a statement containing only their name. Example:

```nimrod
var i = 10
while i > 5:
	i
	i = i - 1
```

If you're wondering how to call `inc(i, -1)`, see *Calling Nimrod proc* below.

Assume no interaction between HTML tag blocks and variable scope. This will
likely result in an error:

```nimrod
td:
  var i = 1
td:
  var i = 10
```

Because it declares the variable `i` two times in the same scope. The `td`s
do not inject a scope in the generated code - this would lead to a *lot* of
nested blocks in the generated code. However, all Nimrod control structures
(see above) do create a new variable scope in the template.

### HTML attributes

You can add HTML attributes to HTML tags in braces right after the tag.
The syntax is

```nimrod
body:
	d(id = "main-wrapper"):
		d(id = "main"):
			p: "Some content"
```

If the tag name is a Nimrod keyword
like `type`, you can escape the name with accents.

There is a shorthand notation for classes of an HTML tag: write the
class names right behind the tag, separated with `.`, like this:

```nimrod
body.class1.class2:
```

There is also a shorthand notation for the `id` attribute: You can
ommit the `id = ` and just write:

```nimrod
body("myId"):
```

There are a few HTML attributes that have a minus (`-`) in their name. You
have to write them with an underscore, because a minus cannot be part of a
name. So, just write for example `http_equiv` instead of `http-equiv`.

### Calling Nimrod procs

You can call any visible proc that does not return a value from anywhere by
prefixing the call with `call`, and one that does return a value with
`discard`. If you want to use the returned value, you can also assign it
to a variable.

```nimrod
var i
call inc(i)
```

If you want to output the return value of a proc, use `put` instead:

```nimrod
put repeatChar(20, '*')
```

If you want to include a template macro (see below), use `include`:

```nimrod
include myMacro()
```

### Template macros

You don't have to implement your template as a whole. Instead, you can
implement small portions of it as `template macros`, which you can include
in the main template. Example:

```nimrod
proc table(headings : seq[string]) {.html_template_macro.} =
    table:
        thead:
            tr:
                for heading in headings:
                    th: heading

proc templ() {.html_template.} =
	html(lang = "en"):
		head:
			title: "Title"
		body:
			include table(["first", "middle", "last"])
```

Emerald cannot validate whether the macro fits at the current position of
your HTML hierarchy. Don't use `call` to call an Emerald macro, it won't work.

### Error Handling

If your code contains errors, you'll get an error message pointing to the file
and line of the error along with a message about what's wrong. Much like the
Nimrod compiler itself does it.

## API

Emerald currently has 3 public modules:

 * `html_templates`: The main module. Defines the templating macros.
 * `tagdef`: Supplies macros for easily definiing HTML tags and their
   properties. This may be relevant for the user in the future when the
   next iteration of the HTML standard allows the user to include custom
   elements (there is already a working draft for that).
 * `html5`: This defines the HTML tag set as specified by HTML 5. The user
   might need access to it if he wishes to extend it, but the macros currently
   don't allow passing custom tag sets. Oh, and there's also an `escapeHtml`
   proc here, but as Emerald escapes all content strings automatically, you
   normally shouldn't have to use it yourself.

So as you see, only the `html_templates` module is currently usable externally.
But it's always good to be prepared for the future! And by the way,
`html_templates` isn't just called `templates` because I might want to add
something similar to *LESS* in the future for CSS.

## License

[WTFPL][3]

 [1]: http://jade-lang.com
 [2]: http://haml.info
 [3]: http://www.wtfpl.net