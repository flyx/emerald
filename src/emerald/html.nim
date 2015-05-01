import macros, sets
import streams, tables, strutils

import impl/writer
import impl/context
import impl/html5
import impl/tagdef
import filters

macro html_templ*(content: expr): stmt =
    if content.kind != nnkProcDef:
        quit_invalid(content, "html_templ subject",
                    "html_templ only works on procs.")
    let fp = content[3]

    if fp[0].kind != nnkEmpty:
        quit_invalid(content, "template proc", "proc must not return a value.")

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
    # define two cache strings
    let
        cache1 = genSym(nskVar, ":cache1")
        cache2 = genSym(nskVar, ":cache2")
    var
        writer = newStmtListWriter(streamName, cache1, cache2, content)
        context = newContext()
    context.filters = @[newCall("escapeHtml")]
    writer.output.add(newNimNode(nnkVarSection).add(newNimNode(nnkIdentDefs
            ).add(cache1, cache2, ident("string"), newEmptyNode())))
    writer.filters = context.filters
    parse_children(writer, context, content[6])
    stmts.add(writer.result)
    
    # debugging
    #echo repr(result)

template quit_unknown[T](node: NimNode, what: string, val: T) =
    quit node.lineInfo & ": Unknown " & what & ": \"" & $val & "\""

template quit_unexpected[T](node: NimNode, what: string, val: T) =
    quit node.lineInfo & ": Unexpected " & what & ": \"" & $val & "\""

template quit_duplicate[T](node: NimNode, what: string, val: T) =
    quit node.lineInfo & ": Duplicate " & what & ": \"" & $val & "\""

template quit_invalid[T](node: NimNode, what: string, val: T) =
    quit node.lineInfo & ": Invalid " & what & ": \"" & $val & "\""

template quit_missing(node: NimNode, what: string) =
    quit node.lineInfo & ": Missing " & what

proc parse_children(writer: StmtListWriter, context: ParseContext,
                         content: NimNode) {. compileTime .}

proc ident_name(node: NimNode): string {.compileTime, inline.} =
    ## Used to be able to parse accent-quoted HTML tags as well.
    ## A prominent HTML tag is <div>, which is a keyword in Nimrod.
    ## You can either escape it with ``, or simply use "d" as a substitute.
    let name: string = if node.kind == nnkAccQuoted: $node[0] else: $node
    result = if name == "d": "div" else: name

proc first_ident(node: NimNode): string {.compileTime.} =
    var leaf = node
    while leaf.kind == nnkDotExpr:
        leaf = leaf[0]
    
    case leaf.kind:
    of nnkIdent, nnkAccQuoted:
        result = leaf.ident_name
    else:
        node.quit_unexpected("token", leaf.kind)

proc add_classes(classes: var string, node: NimNode,
                 first: var bool) {.compileTime.} =
    case node.kind
    of nnkDotExpr:
        add_classes(classes, node[0], first)
        add_classes(classes, node[1], first)
    of nnkIdent, nnkAccQuoted:
        if first:
            first = false
        else:
            if classes.len > 0:
                classes.add(' ')
            classes.add(node.ident_name)
    else:
        quit_unexpected(node, "token", node.kind)

proc parse_tag(writer: StmtListWriter, context: ParseContext,
               node: NimNode, tag: TagDef, name: string) {.compileTime.} =
    let outputInBlockMode = context.mode != flowmode
    
    let toPrepend = string_to_prepend(tag.id)
    if toPrepend.len > 0:
        if outputInBlockMode:
            writer.add_literal(context.indentation & toPrepend & "\n")
        else:
            writer.add_literal(toPrepend)
    
    # HTML tag block
    if outputInBlockMode:
        writer.add_literal(context.indentation & "<" & name)
    else:
        writer.add_literal("<" & name)
    
    var mappedInjectedAttrs = initTable[string, string]()
    for injectedAttr in injected_attrs(tag.id):
        case injectedAttr.val.kind
        of nnkStrLit:
            writer.add_attr_val(injectedAttr.name, injectedAttr.val.strVal)
        of nnkIdent:
            mappedInjectedAttrs[$injectedAttr.val.ident] = injectedAttr.name
        else:
            quit "Error in tagdef!"
    
    var classes = ""
    if node[0].kind == nnkDotExpr:
        var first = true
        add_classes(classes, node[0], first)
    
    var
        required_attrs = tag.required_attrs
        optional_attrs = tag.optional_attrs
    
    let max = if node[node.len - 1].kind == nnkStmtList:
            node.len - 2 else: node.len - 1
    for i in 1 .. max:
        case node[i].kind
        of nnkStrLit, nnkCall:
            if i == 1:
                writer.add_attr_val("id", node[i])
            else:
                quit_unexpected(node[i], "token [4]", node[i].kind)
        of nnkExprEqExpr:
            if not (node[i][0].kind in [nnkIdent, nnkAccQuoted]):
                quit_unexpected(node[i][0], "token", node[i][0].kind)
            
            let attrName = node[i][0].ident_name
            var added = false
            if attrName == "class":
                if classes.len > 0:
                    writer.add_attr_val(attrName, newNimNode(
                            nnkInfix).add(ident("&"),
                            newStrLitNode(classes & ' '), node[i][1]))
                    added = true
                    classes = ""
            if not added:
                if is_bool_attr(attrName):
                    writer.add_bool_attr(attrName, node[i][1])
                else:
                    writer.add_attr_val(attrName, node[i][1])
            
            if attrName in required_attrs:
                required_attrs.excl(attrName)
            elif attrName in optional_attrs:
                optional_attrs.excl(attrName)
            elif not is_global_attr(attrName):
                quit_invalid(node[i][0], "attribute for tag " & name,
                        attrName)
            
            if mappedInjectedAttrs.hasKey(attrName):
                if is_bool_attr(attrName):
                    writer.add_bool_attr(mappedInjectedAttrs[attrName],
                            node[i][1])
                else:
                    writer.add_attr_val(mappedInjectedAttrs[attrName],
                            node[i][1])
        else:
            quit_unexpected(node[i], "token [2]", node[i].kind)
    if classes.len > 0:
        writer.add_attr_val("class", classes)
    
    if required_attrs.len > 0:
        var list = ""
        for attr in required_attrs:
            list.add(attr & ", ")
        quit_missing(node, "attribute(s) for tag " & name & ": " & list)
    
    if node[node.len - 1].kind == nnkStmtList:
        writer.add_literal(">")
        context.enter(tag)
        writer.filters = context.filters & newCall("change_indentation",
                newStrLitNode(context.indentation))
        parse_children(writer, context, node[node.len - 1])
        let finishInBlockMode = context.mode == blockmode
        context.exit()
        if finishInBlockMode:
            writer.add_literal(context.indentation)
        writer.add_literal("</" & name & ">")
    elif tag.tag_omission:
        writer.add_literal("/>")
    else:
        writer.add_literal("></" & name & ">")
    if outputInBlockMode:
        writer.add_literal("\n")

proc bool_from_ident(node: NimNode): bool {.compileTime.} =
    case $node.ident
    of "true": result = true
    of "false": result = false
    else:
        quit_invalid(node, "bool value", $node.ident)

proc int_from_lit(node: NimNode): int {.compileTime.} =
    if node.kind != nnkIntLit:
        quit_unexpected(node, "node kind (expected int literal)", $node.kind)
    result = int(node.intVal)

proc add_filters(target: var seq[NimNode], node: NimNode,
                 context: ParseContext) {.compileTime.} =
    case node.kind
    of nnkInfix:
        if node[0].kind != nnkIdent:
            quit_unexpected(node[0], "token", node[0].kind)
        elif $node[0].ident != "&":
            quit_unexpected(node[0], "operator", node[0].ident)
        add_filters(target, node[1], context)
        add_filters(target, node[2], context)
    of nnkIdent:
        case $node.ident
        of "filters":
            target.add(context.filters)
        else:
            quit_unexpected(node, "identifier", $node.ident)
    of nnkCall:
        target.add(node)
    else:
        quit_unexpected(node, "token", node.kind)

proc copy_node_parse_children(writer: StmtListWriter, context: ParseContext,
                              node: NimNode): NimNode {.compileTime.} =
    if node.kind in [nnkElifBranch, nnkOfBranch, nnkElse, nnkForStmt,
                     nnkWhileStmt]:
        result = copyNimNode(node)
        var childWriter = writer.copy(node)
        for child in node.children:
            if child.kind == nnkStmtList:
                parse_children(childWriter, context, child)
            else:
                result.add(copyNimTree(child))
        result.add(childWriter.result)
    else:
        result = copyNimTree(node)

proc parse_children(writer: StmtListWriter, context: ParseContext,
                    content: NimNode) =
    for node in content.children:
        case node.kind
        of nnkCall:
            if context.mode == unknown:
                context.mode = blockmode
                if context.depth != -1:
                    writer.add_literal("\n")
            let
                childName = node[0].first_ident
                childTag  = tagIdFor(childName)
            if childTag == unknownTag:
                quit_unknown(node[0], "tag", childName)
            let childTagDef = tagDefFor(childTag)
            if context.accepts(childTagDef):
                parse_tag(writer, context, node, childTagDef, childName)
            else:
                quit_invalid(node, "Tag at this position", childName)
        of nnkPragma:
            case node[0].kind
            of nnkExprEqExpr:
                case $node[0][0].ident
                of "compact_mode":
                    context.compact_output = bool_from_ident(node[0][1])
                of "indent_step":
                    let length = int_from_lit(node[0][1])
                    if length < 0:
                        quit_invalid(node[0][1], "indentation length", length)
                    context.indent_step = length
                of "filters":
                    var result = newSeq[NimNode]()
                    add_filters(result, node[0][1], context)
                    context.filters = result
                    writer.filters = context.filters &
                            newCall("change_indentation",
                            newStrLitNode(context.indentation))
                else:
                    quit_unknown(node[0][0], "configuration value name",
                            $node[0][0].ident)
            else:
                quit_invalid(node[0], "pragma content", $node[0].kind)
                    
            
        of nnkStrLit, nnkTripleStrLit:
            if context.mode == unknown:
                context.mode = flowmode
            writer.add_filtered(node.strVal)
        of nnkInfix:
            if context.mode == unknown:
                context.mode = flowmode
            writer.add_filtered(node)
        of nnkIdent:
            if context.mode == unknown:
                context.mode = flowmode
            writer.add_filtered(newNimNode(nnkPrefix).add(ident("$"), node))
        of nnkIfStmt, nnkWhenStmt, nnkCaseStmt:
            var ifNode = newNimNode(node.kind, node)
            for ifBranch in node.children:
                ifNode.add(copy_node_parse_children(writer, context, ifBranch))
            writer.add_node(ifNode)
        of nnkForStmt, nnkWhileStmt:
            writer.addNode(copy_node_parse_children(writer, context, node))
        of nnkAsgn, nnkVarSection, nnkConstSection, nnkLetSection,
                nnkDiscardStmt:
            writer.addNode(copyNimTree(node))
        of nnkCommand:
            case identName(node[0]):
            of "call":
                for i in 1..(node.len - 1):
                    writer.add_node(copyNimTree(node[1]))
            of "put":
                for i in 1..(node.len - 1):
                    writer.add_filtered(copyNimTree(node[1]))
            else:
                quit_unknown(node, "command", node[0].ident_name)
        else:
            quit_unexpected(node, "token", node.kind)
    