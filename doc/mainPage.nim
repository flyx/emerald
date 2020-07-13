import layout

layout.sites.add((title: "Home", url: "index.html", anchors: @[]))

proc home*() {. html_templ: layout .} =
    title = "Home"
    replace content:
        section(class="unmaintained"):
            h2: "Project Status"
            p:
              """This was my very first Nim project, the goal was to test the versatility of Nim's macro system. It worked quite well."""
            p:
              """Since I never went on to actually do something with it, this is now just code I myself do not really know anymore. I also don't have the time to maintain the project, so it is """; strong("unmaintained"); """. Use at your own risk."""
        section:
            h2: "About"
            p:
                strong("emerald"); " is a Nim library for writing "
                a(href="http://www.w3.org/TR/html5/", "HTML 5")
                """ templates. It is implemented as a domain-specific language
                that can be used directly in your Nim source code via macros.
                Features include:"""
            ul:
                li: strong("HTML validation"); """: emerald validates your HTML
                    structure when it compiles your template. This validation
                    checks for unknown, ill-placed and missing HTML tags and
                    attributes, but does not implement the whole HTML 5 spec. It
                    is a tool for you to discover errors early."""
                li: strong("Mixins"); """: You can re-use parts of your template
                    code by placing it in mixins and calling the mixin from the
                    template. emerald is able to check the whole resulting HTML
                    structure."""
                li: strong("Filtering"); """: By default, emerald converts
                    special HTML characters in the content it outputs to their
                    corresponding entities, but you can customize the whole
                    filter chain and also write your own filters."""
                li: strong("Inheritance"); """: Templates can inherit from other
                    templates. You can define your base structure in a master
                    template, and add content with child templates. emerald is
                    still able to check the whole resulting HTML structure."""
            d(id="main-example"):
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
      h1: "Emerald - Nim HTML5 templating engine"
      d.content:
        if youAreUsingEmerald:
          p: "You are amazing"; br(); "Continue."
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
        <h1>Emerald - Nim HTML5 templating engine</h1>
        <div class="content">
            <p>You are amazing<br/>Continue.</p>
            <p>Emerald is a macro-based type-safe
                templating engine which validates your
                HTML structure and relieves you from
                the ugly mess that HTML code is.</p>
        </div>
    </body>
</html>
                """

            p:
                """To get started with emerald, have a look at the """
                a(href="tutorial.html", "tutorial")
                " or learn it the hard way by reading the "
                a(href="documentation.html", "documentation"); "."
            h2: "Authors & License"
            p:
                "emerald has been created by "
                a(href="https://github.com/flyx", "Felix Krause")
                ", is licensed under the "
                a(href="http://www.wtfpl.net", "Do What the Fuck You Want to Public License")
                " and can be forked on "
                a(href="https://github.com/flyx/emerald", "Github"); "."
                
