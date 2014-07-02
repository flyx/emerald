import macros, "../html5"

type
    TStmtListWriter = tuple
        streamIdent: PNimrodNode
        output: PNimrodNode
        literalStringCache: string

    PStmtListWriter* = ref TStmtListWriter not nil

proc newStmtListWriter*(streamName: PNimrodNode, lineRef: PNimrodNode = nil):
        PStmtListWriter {.compileTime.} =
    new(result)
    result.streamIdent = streamName
    result.output = newNimNode(nnkStmtList, lineRef)
    result.literalStringCache = ""

proc consumeCache(writer : PStmtListWriter) {.compileTime.} =
    if writer.literalStringCache.len > 0:
        writer.output.add(newCall(newIdentNode("write"),
                          copyNimTree(writer.streamIdent),
                          newStrLitNode(writer.literalStringCache)))
        writer.literalStringCache = ""

proc result*(writer : PStmtListWriter): PNimrodNode {.compileTime.} =
    writer.consumeCache()
    return writer.output

proc streamName*(writer: PStmtListWriter):
        PNimrodNode {.inline, compileTime.} =
    writer.streamIdent

proc addString*(writer : PStmtListWriter, val: string) {.compileTime.} =
    if writer.literalStringCache.len == 0:
        writer.literalStringCache = val
    else:
        # This is an inefficient workaround for this bug:
        # https://github.com/Araq/Nimrod/issues/1297
        writer.literalStringCache = writer.literalStringCache & val

proc addNode*(writer : PStmtListWriter, val: PNimrodNode) {.compileTime.} =
    writer.consumeCache()
    writer.output.add(val)

proc addEscapedStringExpr*(writer: PStmtListWriter, val: PNimrodNode,
                           escapeQuotes: bool = false) {.compileTime.} =
    if val.kind == nnkStrLit:
        writer.addString(escapeHtml(val.strVal, escapeQuotes))
    else:
        writer.consumeCache()
        var escapeCall: PNimrodNode
        if escapeQuotes:
            escapeCall = newCall(newIdentNode("escapeHtml"), copyNimTree(val),
                                 newIdentNode("true"))
        else:
            escapeCall = newCall(newIdentNode("escapeHtml"), copyNimTree(val))

        writer.output.add(newCall(newIdentNode("write"),
                          copyNimTree(writer.streamIdent), escapeCall))