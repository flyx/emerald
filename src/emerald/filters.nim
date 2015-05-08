import streams, strtabs
import packages.docutils.rstgen
import packages.docutils.rst

proc escape_html*(target: Stream, value : string,
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
    var in_indentation = false
    var initial = true
    for c in value:
        case c
        of '\l':
            if initial:
                initial = false
            if in_indentation:
                target.write('\l')
            else:
                in_indentation = true
        of ' ':
            if not in_indentation and not initial:
                target.write(' ')
        else:
            if in_indentation:
                target.write('\l' & indentation)
                in_indentation = false
            if initial:
                initial = false
            target.write(c)

proc rst*(target: Stream, value: string, options: TRstParseOptions = {},
         config: StringTableRef = newStringTable()) =
    target.write(rstToHtml(value, options, config))