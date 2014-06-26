# HTML 5 templating engine for Nimrod

## Overview

NimHTML is a macro-based type-safe templating engine for producing well-formed
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

NimHTML has been inspired by [Jade][1] and [HAML][2]. But it doesn't use
RegEx for parsing its templates like Jade does *HOW COULD YOU EVEN THINK OF
DOING THAT SERIOUSLY*. Instead, it uses the awesome Nimrod compile-time
infrastructure.

Here is an example template to demonstrate what already works:

```nimrod
proc templ(youAreUsingNimHTML: bool) {.html_template.} =
    html(lang = "en"):
        head:
            title: "pageTitle"
            script (`type` = "text/javascript"): """
                if (foo) {
                    bar(1 + 5)
                }
                """
        body:
            h1: "NimHTML - Nimrod HTML5 templating engine"
            d.content:
                if youAreUsingNimHTML:
                    p:
                        "You are amazing"; br(); "Continue."
                else:
                    p: "Get on it!"
                p: """
                   NimHTML is a macro-based type-safe
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
        <h1>NimHTML - Nimrod HTML5 templating engine</h1>
        <div class="content">
            <p>You are amazing<br />Continue.</p>
            <p>
                NimHTML is a macro-based type-safe
                templating engine which validates your
                HTML structure and relieves you from
                the ugly mess that HTML code is.
            </p>
        </div>
    </body>
</html>
```

## Usage

NimHTML templates are written as procedures. Just write a procedure
declaration, add any parameters you need, and then add the pragma
`html_template`. This will parse the contents of the procedure
implementation as HTML template. To be able to use the template macros,
you must **include** (not import) the module `html5`.

To use the template, just call it by the name you gave it, **pass
a `PStream` as first argument**, and give values for the parameters
*you* declared afterwards. The `PStream` parameter is injected automatically,
so you need to import the package `streams` from the standard library.

**TODO:**

The `PStream` variable is currently named `o`. Forbid the user to use
that name on own variables, and, change the name to something the user
will most certainly not come up with.

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
operators work, too. NimHTML tries to preserve indentation within long string
literals (for JavaScript and such). It strips leading and trailing whitespace per
line and adds its own indentation instead so that the output looks nice.

The characters `<`, `>` and `&` are converted to their corresponding HTML
entity automatically. For attribute values, the characters `'` and `"` are
also converted.

### Control structures

`if`, `elif`, `else`, `when`, `for`, `while` and `case` work exactly as in Nimrod.

### Variables

You can declare variables using `var` everywhere. You can assign variables with
a normal assignment statement everywhere. You can output variables by writing
a statement containing only their name. Example:

```nimrod
var i = 10
while i > 5:
	i
	i = i - 1
```

If you're wondering how to call `inc(i, -1)`, see *Calling Nimrod proc* below.

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

NimHTML cannot validate whether the macro fits at the current position of
your HTML hierarchy. Don't use `call` to call a NimHTML macro, it won't work.

### Error Handling

If your code contains errors, you'll get an error message pointing to the file
and line of the error along with a message about what's wrong. Much like the
Nimrod compiler itself does it.

## License

[WTFPL][3]

 [1]: http://jade-lang.com
 [2]: http://haml.info
 [3]: http://www.wtfpl.net