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
proc templ(youAreUsingNimHTML: bool): string =
    result = ""
    html5:
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
<html>
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

## Features

This list of features grows as things get implemented.

### HTML tags

Currently, only a small list of HTML tags are supported, most of them are used
in the example above. More will be added. There are two ways of specifying HTML
tags:

 * As block nodes: The HTML nodes start a block, which contains the content of
   the node.

   ```nimrod
   head:
       title: "Page title"
   ```

 * As function calls: The HTML nodes look like procedure calls. These calls must
   not be used in expressions, but as standalone statements (this may change in
   the future).

   ```nimrod
   p: "Some text"; br(); "Some more text"
   ```

   Note that the semicolons are mandatory. You can replace them with line breaks.

Because the `div` tag is used so frequently, it has `d` as shorthand.

### String content

String content can be included as string literals. Long literals and infix
operators work, too. NimHTML tries to preserve indentation within long string
literals (for JavaScript and such). It strips leading and trailing whitespace per
line and adds its own indentation instead so that the output looks nice.

**TODO:**

 * Add ability to call procs that return a string

### Control structures

`if`, `elif`, `else`, `for` and `while` work exactly as in Nimrod.

**TODO:**

 * Support `case`

### Variables

You can declare variables using `var` everywhere. You can assign variables with
a normal assignment statement everywhere. You can output variables by writing
a statement containing only their name. Example:

```nimrod
var i = 10
while i < 5:
	i
	i = i - 1
```

Note that `inc(i, -1)` doesn't work here as all non-infix calls are parsed as
HTML tag constructors.

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

**TODO:**

 * Provide a shorthand notation for `id`

### License

[WTFPL][3].

 [1]: http://jade-lang.com
 [2]: http://haml.info
 [3]: http://www.wtfpl.net