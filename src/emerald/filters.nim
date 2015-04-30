import streams, strtabs
import packages.docutils.rstgen
import packages.docutils.rst

type
    StringOrChar* = string or char
    Appendable* = concept x
        x.append("string")
        x.append('c')

proc append*(stream: Stream, value: StringOrChar) {.inline.} =
    stream.write(value)

# this should rather be a `var string`, but unfortunately, I don't find a way
# to define Appendable in a way that a string acting as Appendable is a
# `var string`.
proc append*(str: ptr string, value: StringOrChar) {.inline.} = str[].add(value)

proc escape_html*(target: Appendable, value : string,
                 escapeQuotes: bool = false) =
    ## translates the characters `&`, `<` and `>` to their corresponding
    ## HTML entities. if `escapeQuotes` is `true`, also translates
    ## `"` and `'`.
    
    for c in value:
        case c:
        of '&': target.append("&amp;")
        of '<': target.append("&lt;")
        of '>': target.append("&gt;")
        of '"':
            if escapeQuotes: target.append("&quot;")
            else: target.append('"')
        of '\'':
            if escapeQuotes: target.append("&#39;")
            else: target.append('\'')
        else:
            target.append(c)

proc change_indentation*(target: Appendable, value: string,
                         indentation: string) =
    var in_indentation = false
    var initial = true
    for c in value:
        case c
        of '\l':
            if initial:
                initial = false
            if in_indentation:
                target.append('\l')
            else:
                in_indentation = true
        of ' ':
            if not in_indentation and not initial:
                target.append(' ')
        else:
            if in_indentation:
                target.append('\l' & indentation)
                in_indentation = false
            if initial:
                initial = false
            target.append(c)

proc rst*(target: Appendable, value: string, options: TRstParseOptions = {},
         config: StringTableRef = newStringTable()) =
    target.append(rstToHtml(value, options, config))