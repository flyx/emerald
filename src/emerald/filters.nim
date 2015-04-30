import streams

type
    StringOrChar* = string or char
    Appendable* = concept x
        x.append("string")
        x.append('c')

proc append*(stream: Stream, value: StringOrChar) {.inline.} = stream.write(value)

# this should rather be a `var string`, but unfortunately, I don't find a way
# to define Appendable in a way that a string acting as Appendable is a
# `var string`.
proc append*(str: ptr string, value: StringOrChar) {.inline.} = str[].add(value)

proc escapeHtml*(target: Appendable, value : string, escapeQuotes: bool = false) =
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
    