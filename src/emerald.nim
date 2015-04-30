import macros
import streams, tables, strutils

import emerald/impl/writer
import emerald/impl/context
import emerald/impl/html5
import emerald/impl/tagdef
import emerald/filters

template quitUnknown[T](node: NimNode, what: string, val: T) =
    quit node.lineInfo & ": Unknown " & what & ": \"" & $val & "\""

template quitUnexpected[T](node: NimNode, what: string, val: T) =
    quit node.lineInfo & ": Unexpected " & what & ": \"" & $val & "\""

template quitDuplicate[T](node: NimNode, what: string, val: T) =
    quit node.lineInfo & ": Duplicate " & what & ": \"" & $val & "\""

template quitInvalid[T](node: NimNode, what: string, val: T) =
    quit node.lineInfo & ": Invalid " & what & ": \"" & $val & "\""

template quitMissing(node: NimNode, what: string) =
    quit node.lineInfo & ": Missing " & what

proc html_parse_children(writer: StmtListWriter, context: ParseContext, content: NimNode) {. compileTime .}

macro html_templ*(content: expr): stmt =
    if content.kind != nnkProcDef:
        quitInvalid(content, "html_templ subject", "html_templ only works on procs.")
    let fp = content[3]

    if fp[0].kind != nnkEmpty:
        quitInvalid(content, "template proc", "proc must not return a value.")

    # define a class type for the template object
    let
        className = genSym(nskType, ":class-" & $content[0].ident)
        streamName = genSym(nskParam, ":stream")
        objName = genSym(nskParam, ":obj")
    result = newStmtList(newNimNode(nnkTypeSection).add(
        newNimNode(nnkTypeDef).add(className, newEmptyNode(),
        newNimNode(nnkRefTy).add(newNimNode(nnkObjectTy).add(newEmptyNode(),
        newNimNode(nnkOfInherit).add(ident("RootObj")), newEmptyNode()
    )))))
    
    # define render method
    var 
        formalParams = newNimNode(nnkFormalParams).add(newEmptyNode(),
            newIdentDefs(objName, className),
            newIdentDefs(streamName, ident("Stream"))
        )
        stmts: NimNode = newStmtList()
    for identDef in content[3].children:
        if identDef.kind != nnkEmpty:
            formalParams.add(copyNimTree(identDef))
    result.add(newNimNode(nnkProcDef).add(ident("render"),
        newEmptyNode(), newEmptyNode(), formalParams, newEmptyNode(),
        newEmptyNode(), stmts
    ))
    
    # define template object
    result.add(newNimNode(nnkLetSection).add(newIdentDefs(
        ident($content[0].ident), newEmptyNode(), newCall(className)
    )))

    # parse template
    var
        writer = newStmtListWriter(streamName, content)
    # define two cache strings
    let
        cache1 = genSym(nskVar, ":cache1")
        cache2 = genSym(nskVar, ":cache2")
    writer.output.add(newNimNode(nnkVarSection).add(newNimNode(nnkIdentDefs).add(
            cache1, cache2, ident("string"), newEmptyNode())))
    writer.setFilters(@[(name: ident("escapeHtml"), params: newEmptyNode())])
    html_parse_children(writer, newContext(), content[6])
    stmts.add(writer.result)
    
    # debugging
    #echo treerepr(result)

proc identName(node: NimNode): string {.compileTime, inline.} =
    ## Used to be able to parse accent-quoted HTML tags as well.
    ## A prominent HTML tag is <div>, which is a keyword in Nimrod.
    ## You can either escape it with ``, or simply use "d" as a substitute.
    let name: string = if node.kind == nnkAccQuoted: $node[0] else: $node
    result = if name == "d": "div" else: name

proc childNodeName(node: NimNode): string {.compileTime.} =
    case node[0].kind:
    of nnkIdent, nnkAccQuoted:
        result = identName(node[0])
    of nnkDotExpr:
        result = identName(node[0][0])
    else:
        node.quitUnexpected("token", node[0].kind)

proc html_parse_tag(writer: StmtListWriter, context: ParseContext, node: NimNode, tag: TagDef, name: string) {.compileTime.} =
    let outputInBlockMode = context.mode != flowmode
    if node.len == 2 and node[1].kind == nnkStmtList:
        # HTML tag block
        if outputInBlockMode:
            writer.addLiteralString(context.indentation & "<" & name)
        else:
            writer.addLiteralString("<" & name)
        
        # TODO: attributes
        
        writer.addLiteralString(">")
        context.enter(tag)
        html_parse_children(writer, context, node[1])
        let finishInBlockMode = context.mode == blockmode
        context.exit()
        if finishInBlockMode:
            writer.addLiteralString(context.indentation)
        writer.addLiteralString("</" & name & ">")
        if outputInBlockMode:
            writer.addLiteralString("\n")
    else:
        quitUnexpected(node[0], "token", $node.kind)

proc html_parse_children(writer: StmtListWriter, context: ParseContext, content: NimNode) =
    for node in content.children:
        case node.kind:
        of nnkCall:
            if context.mode == unknown:
                context.mode = blockmode
                if context.depth != -1:
                    writer.addLiteralString("\n")
            let
                childName = node.childNodeName
                childTag  = tagIdFor(childName)
            if childTag == unknownTag:
                quitUnknown(node[0], "tag", childName)
            let childTagDef = tagDefFor(childTag)
            if context.accepts(childTagDef):
                html_parse_tag(writer, context, node, childTagDef, childName)
            else:
                quit node.lineInfo & ": Tag not permitted at this position."
            
        of nnkStrLit:
            writer.addString(node.strVal)
        else:
            quit("not implemented!")
    
    