import layout, strutils

layout.sites.add((title: "Changelog", url: "changelog.html", anchors: @[]))

proc issueLink(issue: string): string =
    """<a href="https://github.com/flyx/emerald/issues/""" & substr(issue, 1) &
        """">""" & issue & "</a>"

proc releaseLink(release: string): string =
    """<a href="https://github.com/flyx/emerald/releases/tag/""" & release &
        """">""" & release & "</a>"

# filter that adds links to the release tags
proc releases(target: Stream, value: string) =
    var
        state = 0
        name = ""
    
    for c in value:
        if c == '<' and state == 0: state = 1
        elif c == 'h' and state == 1: state = 2
        elif c == '2' and state == 2: state = 3
        elif c == '>' and state == 3:
            state = 4
            name = ""
        elif state == 4:
            if c == '<':
                target.write(releaseLink(name))
                state = 0
            else:
                name.add(c)
                continue
        elif state != 3: state = 0
        target.write(c)

# filter that automatically adds links to issues when the text mentions "#[num]"
proc issues(target: Stream, value: string) =
    var buf = ""
    for c in value:
        case c
        of '#':
            case buf.len
            of 0: buf = "#"
            of 1:
                target.write('#')
                buf = ""
            else:
                target.write(buf)
                target.write('#')
                buf = ""
        of '0'..'9':
            if buf.len > 0:
                buf.add(c)
            else:
                target.write(c)
        of ' ', '\x0A', '\t', '.', ',', ':', ';', '?', '!', '(', ')', '[', ']':
            if buf.len > 0:
                target.write(issueLink(buf))
                buf = ""
            target.write(c)
        else:
            if buf.len > 0:
                target.write(buf)
                buf = ""
            target.write(c)
    if buf.len > 0:
        target.write(issueLink(buf))      

proc changelog*() {. html_templ: layout .} =
    title = "Changelog"
    replace content:
        {.filters = rst() & issues() & releases() .}
        put readFile("../CHANGELOG.rst")