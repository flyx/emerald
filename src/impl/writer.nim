import macros, htmltags

type
    TStmtListWriter = tuple
        tags: TTagList
        output: PNimrodNode
        literalStringCache: string

    PStmtListWriter* = ref TStmtListWriter not nil

proc newStmtListWriter*(lineRef: PNimrodNode = nil): PStmtListWriter {.compileTime.} =
    new(result)
    result.tags = tags()
    result.output = newNimNode(nnkStmtList, lineRef)
    result.literalStringCache = ""

proc consumeCache(writer : PStmtListWriter) {.compileTime.} =
    if writer.literalStringCache.len > 0:
        writer.output.add(newCall(newIdentNode("add"), newIdentNode("result"),
                          newStrLitNode(writer.literalStringCache)))
        writer.literalStringCache = ""

proc result*(writer : PStmtListWriter): PNimrodNode {.compileTime.} =
    writer.consumeCache()
    return writer.output

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

proc addStringExpr*(writer: PStmtListWriter, val: PNimrodNode) {.compileTime.} =
    writer.consumeCache()
    writer.output.add(newCall(newIdentNode("add"), newIdentNode("result"),
                      copyNimTree(val)))