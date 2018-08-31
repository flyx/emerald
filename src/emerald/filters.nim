import 
    streams, strtabs, osproc,
    packages / docutils / [rst, rstgen]

proc escape_html*(target: Stream, value: string,
                  escapeQuotes: bool = false) =
    ## translates the characters `&`, `<` and `>` to their corresponding
    ## HTML entities. if `escapeQuotes` is `true`, also translates
    ## `"` and `'`.
    
    for c in value:
        case c:
        of '&': target.write("&amp;")
        of '<': target.write("&lt;")
        of '>': target.write("&gt;")
        of '"':
            if escapeQuotes: target.write("&quot;")
            else: target.write('"')
        of '\'':
            if escapeQuotes: target.write("&#39;")
            else: target.write('\'')
        else:
            target.write(c)

proc change_indentation*(target: Stream, value: string,
                         indentation: string) =
    var
        in_indentation = false
        initial = true
        consumed_whitespace = false
    for c in value:
        case c
        of '\l':
            if initial:
                initial = false
                consumed_whitespace = true
            if in_indentation:
                target.write('\l')
            else:
                in_indentation = true
        of ' ':
            if initial:
                consumed_whitespace = true
            else:
                if not in_indentation:
                    target.write(' ')
        else:
            if initial:
                initial = false
                if consumed_whitespace and not in_indentation:
                    target.write(' ');
            if in_indentation:
                target.write('\l' & indentation)
                in_indentation = false
            target.write(c)

proc rst*(target: Stream, value: string, options: RstParseOptions = {},
         config: StringTableRef = newStringTable()) =
    target.write(rstToHtml(value, options, config))

proc pygmentize*(target: Stream, value: string, language: string) =
    var p = startProcess("pygmentize -l " & language & " -f html",
            options={poEvalCommand})
    var input = p.inputStream
    var output = p.outputStream
    input.write(value)
    input.flush()
    input.close()
    discard p.waitForExit()
    var c = output.readChar()
    while c != char(0):
        target.write(c)
        c = output.readChar()
    p.close()