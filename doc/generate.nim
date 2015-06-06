import mainPage, tutorial, documentation, layout

import streams, os

if not dirExists("site"): createDir("site")
copyFile("style.css", "site/style.css")
copyFile("pygments.css", "site/pygments.css")

var fs = newFileStream("site/home.html", fmWrite)
mainPage.home.render(fs, sites)

fs = newFileStream("site/tutorial.html", fmWrite)
tutorial.tut.render(fs, sites)

fs = newFileStream("site/documentation.html", fmWrite)
documentation.doc.render(fs, sites)