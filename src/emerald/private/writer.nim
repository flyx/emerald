{.experimental: "notnil".}
import macros, streams

type
    ## This writer is used for creating an AST which represents the
    ## implementation of an emerald template. It merges adjacent literal
    ## strings into one instead of creating one write command for every
    ## literal string.
    StmtListWriterObj* = tuple
        streamIdent: NimNode
        output: NimNode
        cache1, cache2: NimNode
        filteredStringCache: string
        literalStringCache: string
        curFilters: seq[NimNode]

    StmtListWriter* = ref StmtListWriterObj not nil
    OptionalStmtListWriter* = ref StmtListWriterObj

proc newStmtListWriter*(streamName: NimNode, cache1: NimNode, cache2: NimNode,
                        lineRef: NimNode = nil):
                       StmtListWriter {.compileTime.} =
    new(result)
    result.streamIdent = streamName
    result.output = newNimNode(nnkStmtList, lineRef)
    result.filteredStringCache = ""
    result.literalStringCache = ""
    result.cache1 = cache1
    result.cache2 = cache2
    result.curFilters = newSeq[NimNode]()

proc copy*(writer: StmtListWriter, lineRef: NimNode = nil):
        StmtListWriter {.compileTime.} =
    new(result)
    result.streamIdent = writer.streamIdent
    result.output = newNimNode(nnkStmtList, lineRef)
    result.filteredStringCache = ""
    result.literalStringCache = ""
    result.cache1 = writer.cache1
    result.cache2 = writer.cache2
    result.curFilters = writer.curFilters

proc add_filtered_node(writer: StmtListWriter, node: NimNode) {.compileTime.} =
    if writer.curFilters.len > 0:
        for i in 0 .. writer.curFilters.len - 1:
            var call = newCall(writer.curFilters[i][0])
            if i == writer.curFilters.len - 1:
                call.add(copyNimTree(writer.streamIdent))
            else:
                writer.output.add(newCall(newNimNode(nnkDotExpr).add(
                        if i mod 2 == 0: writer.cache1 else: writer.cache2,
                            ident("setPosition")),  newIntLitNode(0)))
                call.add(if i mod 2 == 0: writer.cache1 else: writer.cache2)
            call.add(if i == 0: node else: newCall("substr",
                    newNimNode(nnkDotExpr).add(if i mod 2 == 0: writer.cache2
                    else: writer.cache1, ident("data")), newIntLitNode(0),
                    newNimNode(nnkInfix).add(ident("-"), newCall("getPosition",
                    if i mod 2 == 0: writer.cache2 else: writer.cache1),
                    newIntLitNode(1))))
            for p in 1..writer.curFilters[i].len - 1:
                call.add(writer.curFilters[i][p])
            writer.output.add(call)
    else:
        writer.output.add(newCall(ident("write"), writer.streamIdent, node))

proc consume_cache(writer : StmtListWriter) {.compileTime.} =
    if writer.filteredStringCache.len > 0:
        writer.add_filtered_node(newStrLitNode(writer.filteredStringCache))
        writer.filteredStringCache = ""
    if writer.literalStringCache.len > 0:
        writer.output.add(newCall(ident("write"), writer.streamIdent,
                newStrLitNode(writer.literalStringCache)))
        writer.literalStringCache = ""

proc set_stream_ident*(writer: StmtListWriter,
                       streamIdent: NimNode) {.compileTime.} =
    writer.consume_cache()
    writer.streamIdent = streamIdent

proc target_stream*(writer: StmtListWriter): NimNode {.compileTime.} =
    writer.streamIdent

proc cache_vars*(writer: StmtListWriter):
        tuple[cache1: NimNode, cache2: NimNode] {.compileTime.} =
        (writer.cache1, writer.cache2)

proc result*(writer : StmtListWriter): NimNode {.compileTime.} =
    ## Get the current result AST. This proc has the side effect of finalizing
    ## the current literal string cache.

    writer.consume_cache()
    return writer.output

proc stream_name*(writer: StmtListWriter):
        NimNode {.inline, compileTime.} =
    ## returns the node containing the name of the output stream variable.
    writer.streamIdent

proc add_filtered*(writer : StmtListWriter, val: string) {.compileTime.} =
    if writer.literalStringCache.len > 0:
        writer.consume_cache()
    writer.filteredStringCache.add(val)

proc add_literal*(writer: StmtListWriter, val: string) {.compileTime.} =
    if writer.filteredStringCache.len > 0:
        writer.consume_cache()
    writer.literalStringCache.add(val)

proc add_filtered*(writer: StmtListWriter, val: NimNode) {.compileTime.} =
    writer.consume_cache()
    writer.add_filtered_node(val)

proc add_literal*(writer: StmtListWriter, val: NimNode) {.compileTime.} =
    writer.consume_cache()
    writer.output.add(newCall(ident("write"), writer.streamIdent,
            val))

proc add_attr_val*(writer: StmtListWriter, name: string,
                   val: NimNode) {.compileTime.} =
    writer.add_literal(' ' & name & "=\"")
    writer.consume_cache()
    writer.output.add(newCall("escape_html", writer.streamIdent, val,
            ident("true")))
    writer.add_literal("\"")

proc add_attr_val*(writer: StmtListWriter, name: string,
                   val: string) {.compileTime.} =
    writer.add_literal(' ' & name & "=\"")
    writer.consume_cache()
    writer.output.add(newCall("escape_html", writer.streamIdent,
            newStrLitNode(val), ident("true")))
    writer.add_literal("\"")

proc add_bool_attr*(writer: StmtListWriter, name: string,
                    val: NimNode) {.compileTime.} =
    writer.consume_cache()
    writer.output.add(newIfStmt((val, newCall("write", writer.streamIdent,
            newStrLitNode(' ' & name & "=\"" & name & "\"")))))

proc add_node*(writer : StmtListWriter, val: NimNode) {.compileTime.} =
    writer.consume_cache()
    writer.output.add(val)

proc `filters=`*(writer: StmtListWriter, filters: seq[NimNode]) {.compileTime.}=
    if writer.filteredStringCache.len > 0:
        writer.consume_cache()
    writer.curFilters = filters