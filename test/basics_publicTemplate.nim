import ../src/emerald

proc publicTemplate*() {. html_templ .} =
    {. compact_mode = true .}
    body:
        p: "Content"
