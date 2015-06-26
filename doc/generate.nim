import mainPage, tutorial, documentation, layout

import streams, os

if not dirExists("site"): createDir("site")
copyFile("style.css", "site/style.css")
copyFile("pygments.css", "site/pygments.css")

var
    fs = newFileStream("site/home.html", fmWrite)
    mainPageTempl = newHome()
    tutorialTempl = newTut()
    documentationTempl = newDoc()

echo "generating home.html"
mainPageTempl.sites = sites
mainPageTempl.render(fs)

echo "generating tutorial.html"
fs = newFileStream("site/tutorial.html", fmWrite)
tutorialTempl.sites = sites
tutorialTempl.render(fs)

echo "generating documentation.html"
fs = newFileStream("site/documentation.html", fmWrite)
documentationTempl.sites = sites
documentationTempl.render(fs)