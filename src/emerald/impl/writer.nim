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

proc add_filtered_node(writer: StmtListWriter, node: NimNode) {.compileTime.} =
    if writer.curFilters.len > 0:
        for i in 0 .. writer.curFilters.len - 1:
            var call = newCall(writer.curFilters[i][0])
            if i == writer.curFilters.len - 1:
                call.add(writer.streamIdent)
            else:
                writer.output.add(newAssignment(if i mod 2 == 0: writer.cache1
                        else: writer.cache2, newStrLitNode("")))
                call.add(newCall("addr",
                        if i mod 2 == 0: writer.cache1 else: writer.cache2))
            call.add(if i == 0: node else: 
                    if i mod 2 == 0: writer.cache2 else: writer.cache1)
            for p in 1..writer.curFilters[i].len - 1:
                call.add(writer.curFilters[i][p])
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

proc `filters=`*(writer: StmtListWriter, filters: seq[NimNode]) {.compileTime.}=
    if writer.filteredStringCache.len > 0:
        writer.consume_cache()
    writer.curFilters = filters