import macros, streams

type
    ## This writer is used for creating an AST which represents the
    ## implementation of an emerald template. It merges adjacent literal
    ## strings into one instead of creating one write command for every
    ## literal string.
    StmtListWriterObj* = tuple
        streamIdent: NimNode
        output: NimNode
        filteredStringCache: string
        literalStringCache: string
        filters: seq[tuple[name: NimNode, params: NimNode]]

    StmtListWriter* = ref StmtListWriterObj not nil

proc newStmtListWriter*(streamName: NimNode,
                        lineRef: NimNode = nil):
                       StmtListWriter {.compileTime.} =
    new(result)
    result.streamIdent = streamName
    result.output = newNimNode(nnkStmtList, lineRef)
    result.filteredStringCache = ""
    result.literalStringCache = ""
    result.filters = newSeq[tuple[name: NimNode, params: NimNode]]()

proc add_filtered_node(writer: StmtListWriter, node: NimNode) {.compileTime.} =
    if writer.filters.len > 0:
        var i = writer.filters.len
        while i > 0:
            i = i - 1
            var call = newCall(writer.filters[i].name)
            call.add(if i == 0: writer.streamIdent else: ident(if i mod 2 == 0:
                        ":cache1" else: ":cache2"))
            call.add(if i == writer.filters.len - 1: node else:
                    ident(if i mod 2 == 0: ":cache2" else: ":cache1"))
            for param in writer.filters[i].params.children:
                call.add(param)
            writer.output.add(call)
    else:
        writer.output.add(newCall(newIdentNode("write"),
                          copyNimTree(writer.streamIdent),
                          node))

proc consume_cache(writer : StmtListWriter) {.compileTime.} =
    if writer.filteredStringCache.len > 0:
        writer.addFilteredNode(newStrLitNode(writer.filteredStringCache))
        writer.filteredStringCache = ""
    if writer.literalStringCache.len > 0:
        writer.output.add(newCall(ident("write"), writer.streamIdent,
                newStrLitNode(writer.literalStringCache)))
        writer.literalStringCache = ""

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

proc add_node*(writer : StmtListWriter, val: NimNode) {.compileTime.} =
    writer.consume_cache()
    writer.output.add(val)

proc set_filters*(writer: StmtListWriter, filters: seq[tuple[name: NimNode,
                 params: NimNode]]) {.compileTime.} =
    if writer.filteredStringCache.len > 0:
        writer.consume_cache()
    writer.filters = filters