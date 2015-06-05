include ../src/emerald

import layout

layout.sites.add((title: "Home", url: "home.html"))

proc home*(sites: seq[tuple[title: string, url: string]])
        {. html_templ: layout("Home", sites) .} =
    {. debug = true .}
    replace content:
        p:
            strong: "emerald"
            """is a Nim library that enables you to write HTML templates. It is
            implemented as domain-specific language that can be used directly in
            your Nim source code via macros."""

        d:
            {. filters = pygmentize("nim") .}
            {. preserve_whitespace = true .}
            """
proc templ(youAreUsingEmerald: bool) {.html_templ.} =
  html(lang = "en"):
    head:
      title: "pageTitle"
      script (`type` = "text/javascript"): """""" & """

        if (foo) {
          bar(1 + 5)
        }
        """""" & """

    body:
      h1: "Emerald - Nimrod HTML5 templating engine"
      d.content:
        if youAreUsingEmerald:
          p:
             "You are amazing"; br(); "Continue."
        else:
          p: "Get on it!"
        p: """""" & """

          Emerald is a macro-based type-safe
          templating engine which validates your
          HTML structure and relieves you from
          the ugly mess that HTML code is.
          """"""
        
            {. filters = pygmentize("html") .}
            """
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
    <head>
        <title>pageTitle</title>
        <script type="text/javascript">if (foo) {
            bar(1 + 5)
            }</script>
    </head>
    <body>
        <h1>Emerald - Nimrod HTML5 templating engine</h1>
        <div class="content">
            <p>You are amazing<br/>Continue.</p>
            <p>Emerald is a macro-based type-safe
                templating engine which validates your
                HTML structure and relieves you from
                the ugly mess that HTML code is.</p>
        </div>
    </body>
</html>"""

        p:
            """To get started with emerald, have a look at the """
            a(href="tutorial.html"): "tutorial "
            """or learn it the hard way by reading the """
            a(href="documentation.html"): "documentation"
            """."""
        
        p:
            "emerald has been created by "
            a(href="https://github.com/flyx"): "flyx"
            ", is licensed under the "
            a(href="http://www.wtfpl.net"): "WTFPL "
            "and can be forked on "
            a(href="https://github.com/flyx/emerald"): "Github"
            "."