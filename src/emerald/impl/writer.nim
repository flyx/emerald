import macros, streams

type
    ## This writer is used for creating an AST which represents the
    ## implementation of an emerald template. It merges adjacent literal
    ## strings into one instead of creating one write command for every
    ## literal string.
    StmtListWriterObj* = tuple
        streamIdent: NimNode
        output: NimNode
        stringCache: string
        filters: seq[tuple[name: NimNode, params: NimNode]]

    StmtListWriter* = ref StmtListWriterObj not nil

proc newStmtListWriter*(streamName: NimNode,
                        lineRef: NimNode = nil):
                       StmtListWriter {.compileTime.} =
    new(result)
    result.streamIdent = streamName
    result.output = newNimNode(nnkStmtList, lineRef)
    result.stringCache = ""
    result.filters = newSeq[tuple[name: NimNode, params: NimNode]]()

proc addFilteredNode(writer: StmtListWriter, node: NimNode) {.compileTime.} =
    if writer.filters.len > 0:
        var i = writer.filters.len
        while i > 0:
            i = i - 1
            var call = newCall(writer.filters[i].name)
            call.add(if i == 0: writer.streamIdent else: ident(if i mod 2 == 0: ":cache1" else: ":cache2"))
            call.add(if i == writer.filters.len - 1: node else:
                    ident(if i mod 2 == 0: ":cache2" else: ":cache1"))
            for param in writer.filters[i].params.children:
                call.add(param)
            writer.output.add(call)
    else:
        writer.output.add(newCall(newIdentNode("write"),
                          copyNimTree(writer.streamIdent),
                          newStrLitNode(writer.stringCache)))

proc consumeCache(writer : StmtListWriter) {.compileTime.} =
    if writer.stringCache.len > 0:
        writer.addFilteredNode(newStrLitNode(writer.stringCache))
        writer.stringCache = ""

proc result*(writer : StmtListWriter): NimNode {.compileTime.} =
    ## Get the current result AST. This proc has the side effect of finalizing
    ## the current literal string cache.

    writer.consumeCache()
    return writer.output

proc streamName*(writer: StmtListWriter):
        NimNode {.inline, compileTime.} =
    ## returns the node containing the name of the output stream variable.
    writer.streamIdent

proc addString*(writer : StmtListWriter, val: string) {.compileTime.} =
    writer.stringCache.add(val)

proc addLiteralString*(writer: StmtListWriter, val: string) {.compileTime.} =
    writer.consumeCache()
    writer.output.add(newCall(ident("write"), writer.streamIdent, newStrLitNode(val)))

proc addContentNode*(writer: StmtListWriter, val: NimNode) {.compileTime.} =
    writer.consumeCache()
    writer.addFilteredNode(val)

proc addNode*(writer : StmtListWriter, val: NimNode) {.compileTime.} =
    writer.consumeCache()
    writer.output.add(val)

proc setFilters*(writer: StmtListWriter, filters: seq[tuple[name: NimNode, params: NimNode]]) {.compileTime.} =
    writer.consumeCache()
    writer.filters = filters