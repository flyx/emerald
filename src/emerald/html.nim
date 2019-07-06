import macros, sets, streams, tables, strutils, hashes

import private/writer
import private/context
import private/html5
import private/tagdef
import filters

# commands / magic idents used by emerald.
let
    hPrepend      {.compileTime.} = hashIgnoreStyle("prepend")
    hReplace      {.compileTime.} = hashIgnoreStyle("replace")
    hAppend       {.compileTime.} = hashIgnoreStyle("append")
    hCall         {.compileTime.} = hashIgnoreStyle("call")
    hPut          {.compileTime.} = hashIgnoreStyle("put")
    hCallMixin    {.compileTime.} = hashIgnoreStyle("call_mixin")
    hMixinContent {.compileTime.} = hashIgnoreStyle("mixin_content")

template quit_unknown[T](node: NimNode, what: string, val: T) =
    quit "[emerald] " & node.lineInfo & ": Unknown " & what & ": \"" & $val & "\""

template quit_unexpected[T](node: NimNode, what: string, val: T) =
  quit """[emerald] $1: Unexpected $2: "$3"""" % [node.lineInfo, what, $val]
  # quit "[emerald] " & node.lineInfo & ": Unexpected " & what & ": \"" & $val & "\""

template quit_duplicate[T](node: NimNode, what: string, val: T) =
    quit "[emerald] " & node.lineInfo & ": Duplicate " & what & ": \"" & $val & "\""

template quit_invalid[T](node: NimNode, what: string, val: T) =
    quit "[emerald] " & node.lineInfo & ": Invalid " & what & ": \"" & $val & "\""

template quit_missing(node: NimNode, what: string) =
    quit "[emerald] " & node.lineInfo & ": Missing " & what

proc parse_children(writer: StmtListWriter, context: ParseContext,
                         content: NimNode) {. compileTime .}

proc ident_name(node: NimNode): string {.compileTime, inline.} =
    ## Used to be able to parse accent-quoted HTML tags as well.
    ## A prominent HTML tag is <div>, which is a keyword in Nimrod.
    ## You can either escape it with ``, or simply use "d" as a substitute.
    if not (node.kind in [nnkAccQuoted, nnkPostfix, nnkIdent]):
        quit_invalid(node, "token (expected ident, accent-quoted, or postfix)",
                strVal(node))
    
    let name: string = if node.kind == nnkAccQuoted: strVal(node[0])
            elif node.kind == nnkPostfix: strVal(node[1]) else: strVal(node)
    result = if name == "d": "div" else: name

# mixins are compiled each time they're used. This variable stores the
# declarations of all mixins so that template processing can access them
var
    mixins {.compileTime.} = newStmtList()
    templateClasses {.compileTime.} = newSeq[TemplateClass]()

proc update_template_class(val: TemplateClass) {.compileTime.} =
    ## the VM tends to copy objects that are passed as references. This proc
    ## is a workaround for that: after a template class is changed, it makes
    ## sure that the object contained in `templateClasses` is up-to-date with
    ## the given copy.
    for class in templateClasses:
        if class.name == val.name:
            for meth in val.methods:
                var found = false
                for existing_meth in class.methods:
                    if existing_meth.name == meth.name:
                        found = true
                        break
                if not found:
                    class.add_method(meth.name, meth.sym, meth.context)
            break

proc write_proc_content(streamName: NimNode, content: NimNode,
                        context: ParseContext): NimNode {.compileTime.} =
    let
        cache1 = genSym(nskVar, ":cache1")
        cache2 = genSym(nskVar, ":cache2")
    var
        writer = newStmtListWriter(streamName, cache1, cache2, content)
    context.filters = @[newCall("escapeHtml")]
    writer.output.add(newNimNode(nnkVarSection).add(newIdentDefs(
            cache1, newEmptyNode(), newCall("newStringStream")),
            newIdentDefs(cache2, newEmptyNode(), newCall("newStringStream"))))
    writer.filters = context.filters
    parse_children(writer, context, content)
    return writer.result

proc bool_from_ident(node: NimNode): bool {.compileTime.} =
    case strVal(node)
    of "true": result = true
    of "false": result = false
    else:
        quit_invalid(node, "bool value", strVal(node))

proc int_from_lit(node: NimNode): int {.compileTime.} =
    if node.kind != nnkIntLit:
        quit_unexpected(node, "node kind (expected int literal)", strVal(node))
    result = int(node.intVal)

proc add_filters(target: var seq[NimNode], node: NimNode,
                 context: ParseContext) {.compileTime.} =
    case node.kind
    of nnkInfix:
        if node[0].kind != nnkIdent:
            quit_unexpected(node[0], "token", node[0].kind)
        elif strVal(node[0]) != "&":
            quit_unexpected(node[0], "operator", strVal(node[0]))
        add_filters(target, node[1], context)
        add_filters(target, node[2], context)
    of nnkIdent:
        case strVal(node)
        of "filters":
            target.add(context.filters)
        else:
            quit_unexpected(node, "identifier", strVal(node))
    of nnkCall:
        target.add(node)
    of nnkNilLit:
        discard
    else:
        quit_unexpected(node, "token", node.kind)

proc process_pragma(writer: OptionalStmtListWriter, node: NimNode,
                    context: ParseContext) {.compileTime.} =
    case node.kind
    of nnkExprEqExpr:
        case strVal(node[0])
        of "compact_mode":
            context.compact = bool_from_ident(node[1])
        of "indent_step":
            let length = int_from_lit(node[1])
            if length < 0:
                quit_invalid(node[1], "indentation length", length)
            context.indent_step = length
        of "filters":
            if writer != nil:
                var result = newSeq[NimNode]()
                add_filters(result, node[1], context)
                context.filters = result
                if context.preserve_whitespace:
                    writer.filters = context.filters
                elif context.compact:
                    writer.filters = context.filters
                else:
                    writer.filters = context.filters &
                            newCall("change_indentation",
                            newStrLitNode(context.indentation))
            else:
                quit_invalid(node, "`filters` pragma",
                        "not allowed on root level of inheriting template")
        of "debug":
            context.debug = bool_from_ident(node[1])
        of "preserve_whitespace":
            if writer != nil:
                let pw = bool_from_ident(node[1])
                if pw != context.preserve_whitespace:
                    context.preserve_whitespace = pw
                    if pw or context.compact:
                        writer.filters = context.filters
                    else:
                        writer.filters = context.filters &
                                newCall("change_indentation",
                                newStrLitNode(context.indentation))
            else:
                quit_invalid(node, "`preserve_indentation` pragma",
                        "not allowed on root level of inheriting template")
        else:
            quit_unknown(node[0], "configuration value name",
                    strVal(node[0]))
    else:
        quit_invalid(node, "pragma content", $node.kind)

proc copy_tree_replace_params(context: ParseContext, node: NimNode,
            keepThisIdent: bool = false): NimNode
        {.compileTime.} =
    ## copies a NimNode tree and replaces all parameters that are template
    ## parameters by dot expressions to the corresponding field of the template
    ## class. keepThisIdent is used to prevent idents in dot expressions from
    ## being replaced.
    if node.kind == nnkIdent and not keepThisIdent:
        var isTemplParam = false
        block searchForParam:
            var class = context.cur_class
            while class != nil:
                for param in class.params.children:
                    if strVal(param[0]) == strVal(node):
                        isTemplParam = true
                        break searchForParam
                class = class.parent
        if isTemplParam:
            result = newNimNode(nnkDotExpr).add(context.global_syms.obj, node)
        else:
            result = node
    else:
        result = copyNimNode(node)
        var first = true
        for child in node.children:
            result.add(copy_tree_replace_params(context, child,
                    node.kind == nnkDotExpr and not first))
            first = false

proc process_block_replacements(content: NimNode,
        context: ParseContext, renderBody: NimNode) {.compileTime.} =
    for node in content.children:
        case node.kind
        of nnkAsgn:
            if node[0].kind != nnkIdent:
                quit_unexpected(node[0], "token (expected ident)", node[0].kind)
            var
                curClass = context.cur_class.parent
                foundVar = false
            while curClass != nil:
                for identDef in curClass.params.children:
                    if strVal(node[0]) == identDef[0].ident_name:
                        foundVar = true
                        break
                curClass = curClass.parent
            if foundVar:
                renderBody.add(newAssignment(newNimNode(nnkDotExpr).add(
                        context.global_syms.obj, node[0]),
                        copy_tree_replace_params(context, node[1])))
        of nnkPragma:
            process_pragma(nil, node[0], context)
        of nnkCommand:
            let commandHash = hashIgnoreStyle(node[0].ident_name)
            case commandHash
            of hReplace, hAppend, hPrepend:
                if node[1].kind != nnkIdent:
                    quit_unexpected(node[1], "token (expected ident)",
                            node[1].kind)
                if node.len < 2:
                    quit_missing(node, "body")
                if node[2].kind != nnkStmtList:
                    quit_unexpected(node[2], "token (expected stmt list)",
                            node[2].kind)
                if not context.at_root:
                    quit_invalid(node, "block replacement command",
                            "may only be used at root level")
                let class = context.cur_class
                if class == nil:
                    quit_invalid(node, "block replacement command",
                            "may not be used in mixins")
                if class.parent == nil:
                    quit_invalid(node, "block replacement command",
                            "may only be used in inheriting templates")
                
                let
                    (className, objName) = context.global_syms()
                    blockName = node[1].ident_name
            
                # search for the method we override
                var
                    curClass = class.parent
                    methodName: NimNode = nil
                    baseMethodName: NimNode = nil
                    methodContext: OptionalParseContext = nil
                block outerLoop:
                    while curClass != nil:
                        for m in curClass.methods:
                            if m.name == blockName:
                                methodName = genSym(nskMethod, $m.sym)
                                baseMethodName = m.sym
                                methodContext = m.context
                                break outerLoop
                        curClass = curClass.parent
                if methodContext == nil:
                    quit_unknown(node[1], "block name", blockName)
                else:
                    var targetCotext: ParseContext = methodContext.copy()
                    
                    var childMethodContext = methodContext.copy()
                    childMethodContext.cur_class = context.cur_class
                    childMethodContext.debug = context.debug
                    childMethodContext.class_instance = context.class_instance
            
                    targetCotext.adapt_to_child_class(context)
            
                    let streamName = genSym(nskParam, ":stream")
                    var procContent = write_proc_content(streamName, node[2],
                                                         childMethodContext)
                    if commandHash == hAppend:
                        procContent.insert(0, newNimNode(nnkCommand).add(
                                ident("procCall"), newCall(baseMethodName,
                                newCall(curClass.symbol, objName), streamName)))
                    elif commandHash == hPrepend:
                        procContent.add(newNimNode(nnkCommand).add(
                                ident("procCall"), newCall(baseMethodName,
                                newCall(curClass.symbol, objName), streamName)))

                    let
                        meth = newProc(methodName, [newEmptyNode(),
                                newIdentDefs(objName, className),
                                newIdentDefs(streamName, ident("Stream"))],
                                procContent, nnkMethodDef)
            
                    class.add_method(blockName, methodName, methodContext)
                    update_template_class(class)
                    context.global_stmt_list.add(meth)
            else:
              block:
                quit_unexpected(node, "command (expected replace, prepend or append)", node[0].ident_name)
        else:
            quit_unexpected(node, "token (expected block replacement command)",
                    node.kind)

macro html_mixin*(content: untyped): untyped =
    if content.kind != nnkProcDef:
        quit_invalid(content, "html_mixin subject", "expected a proc def.")
    let fp = content[3]
    
    if fp[0].kind != nnkEmpty:
        quit_invalid(content, "html_mixin proc", "proc must not return a value")
    
    mixins.add(content)
    result = newEmptyNode()

macro html_templ*(arg1: untyped, arg2: untyped = nil): untyped =
    let
        parent = if arg2.kind != nnkNilLit: arg1 else: nil
        content = if arg2.kind == nnkNilLit: arg1 else: arg2
    
    var parentClass: TemplateClass = nil
    if parent != nil:
        if parent.kind != nnkIdent:
            quit_unexpected(parent, "html_templ parameter (expected ident)",
                    parent.kind)
        for class in templateClasses:
            if class.name == parent.ident_name:
                parentClass = class
                break
        if parentClass == nil:
            quit_unknown(parent, "parent template", $(parent[0].ident_name))

    if content.kind != nnkProcDef:
        quit_invalid(content, "html_templ subject", "expected a proc def.")
    let fp = content[3]

    if fp[0].kind != nnkEmpty:
        quit_invalid(content, "template proc", "proc must not return a value.")

    # define a class type for the template object
    let
        className = genSym(nskType, content[0].ident_name)        
        streamName = genSym(nskParam, ":stream")
        objName = genSym(nskParam, ":obj")
    var
        recList = if content[3].len > 0: newNimNode(nnkRecList) else:
                newEmptyNode()
    for identDef in content[3].children:
        if identDef.kind == nnkIdentDefs:
            if content[0].kind == nnkPostfix:
                recList.add(newIdentDefs(newNimNode(nnkPostfix).add(ident("*"),
                        identDef[0]), identDef[1], identDef[2]))
            else:
                recList.add(copyNimTree(identDef))
        elif identDef.kind != nnkEmpty:
            quit_unexpected(identDef, "parameter kind", $identDef.kind)
    
    result = newStmtList(newNimNode(nnkTypeSection).add(
        newNimNode(nnkTypeDef).add(if content[0].kind == nnkPostfix:
        newNimNode(nnkPostfix).add(ident("*"), className) else: className,
        newEmptyNode(), newNimNode(nnkRefTy).add(newNimNode(nnkObjectTy).add(
        newEmptyNode(), newNimNode(nnkOfInherit).add(if parent == nil: ident(
        "RootObj") else: parentClass.symbol), recList
    )))))
    
    # define render method
    var 
        templClass = newTemplateClass(className, parentClass)
        context = newContext(result, templClass, objName,
                content[0].kind == nnkPostfix)
    
    for identDef in content[3].children:
        if identDef.kind != nnkEmpty:
            templClass.add_param(copyNimTree(identDef))
    templateClasses.add(templClass)
    let
        renderName = if content[0].kind == nnkPostfix: newNimNode(nnkPostfix
            ).add(ident("*"), ident("render")) else: ident("render")
        formalParams = newNimNode(nnkFormalParams).add(newEmptyNode(),
                newIdentDefs(objName, className),
                newIdentDefs(streamName, ident("Stream"))
        )
    
    var stmts: NimNode
    if parentClass == nil:
        stmts = write_proc_content(streamName, content[6], context)
    else:
        stmts = newStmtList()
        var call = newCall(ident("render"),
                newCall(parentClass.symbol, objName), streamName)
        for i in 1 .. (parent.len - 1):
            call.add(parent[i])
        process_block_replacements(content[6], context, stmts)
        stmts.add(newNimNode(nnkCommand).add(ident("procCall"), call))
    
    # add new… proc
    result.add(newProc(if content[0].kind == nnkPostfix:
            newNimNode(nnkPostfix).add(ident("*"),
            ident("new" & toUpperAscii(content[0].ident_name))) else:
            ident("new" & toUpperAscii(content[0].ident_name)),
            [className],
            newStmtList(newCall("new", ident("result")))))
    
    # add render proc
    result.add(newNimNode(nnkProcDef).add(renderName,
        newEmptyNode(), newEmptyNode(), formalParams, newEmptyNode(),
        newEmptyNode(), stmts
    ))

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
    
    var mappedInjectedAttrs = initTable[string, seq[string]]()
    for injectedAttr in injected_attrs(tag.id):
        case injectedAttr.val.kind
        of nnkStrLit:
            writer.add_attr_val(injectedAttr.name, injectedAttr.val.strVal)
        of nnkIdent:
            let identName = strVal(injectedAttr.val)
            if mappedInjectedAttrs.hasKey(identName):
                mappedInjectedAttrs[identName] =
                    mappedInjectedAttrs[identName] & injectedAttr.name
            else:
                mappedInjectedAttrs[strVal(injectedAttr.val)] = @[injectedAttr.name]
        else:
            quit "Error in tagdef!"
    
    var classes = ""
    if node[0].kind == nnkDotExpr:
        var first = true
        add_classes(classes, node[0], first)
    
    var
        required_attrs = tag.required_attrs
        optional_attrs = tag.optional_attrs
        directContent: NimNode = nil
    
    let max = if node[node.len - 1].kind == nnkStmtList:
            node.len - 2 else: node.len - 1
    for i in 1 .. max:
        case node[i].kind
        of nnkStrLit, nnkCall, nnkInfix, nnkDotExpr:
            if directContent != nil:
                quit_duplicate(node[i], "direct content", $node[i].kind)
            else:
                directContent = copy_tree_replace_params(context, node[i])
        of nnkExprEqExpr:
            if not (node[i][0].kind in [nnkIdent, nnkAccQuoted]):
                quit_unexpected(node[i][0], "token", node[i][0].kind)
            
            let attrName = toLower(node[i][0].ident_name)
            var added = false
            if attrName == "class":
                if classes.len > 0:
                    writer.add_attr_val(attrName, newNimNode(
                            nnkInfix).add(ident("&"),
                            newStrLitNode(classes & ' '),
                            copy_tree_replace_params(context, node[i][1])))
                    added = true
                    classes = ""
            if attrName == "data":
                if node[i][1].kind != nnkTableConstr:
                    quit_invalid(node[i][1],
                            "value kind for data (expected table constructor)",
                            node[i][1].kind)
                for dataPair in node[i][1].children:
                    # this couldn't be a table constructor if this assertion
                    # fails
                    assert dataPair.kind == nnkExprColonExpr
                    if dataPair[0].kind != nnkStrLit:
                        quit_invalid(dataPair[0],
                                "key token (expected string literal)",
                                dataPair[0].kind)
                    writer.add_attr_val("data-" & dataPair[0].strVal,
                            newCall(ident("$"),
                            copy_tree_replace_params(context, dataPair[1])))
                added = true
            if not added:
                if is_bool_attr(attrName):
                    writer.add_bool_attr(attrName, node[i][1])
                else:
                    writer.add_attr_val(attrName,
                            copy_tree_replace_params(context, node[i][1]))
            
            if attrName in required_attrs:
                required_attrs.excl(attrName)
            elif attrName in optional_attrs:
                optional_attrs.excl(attrName)
            elif not is_global_attr(attrName):
                quit_invalid(node[i][0], "attribute for tag " & name,
                        attrName)
            
            if mappedInjectedAttrs.hasKey(attrName):
                if is_bool_attr(attrName):
                    for targetAttr in mappedInjectedAttrs[attrName]:
                        writer.add_bool_attr(targetAttr, node[i][1])
                else:
                    for targetAttr in mappedInjectedAttrs[attrName]:
                        writer.add_attr_val(targetAttr, node[i][1])
                           
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
        if directContent != nil:
            quit_unexpected(node[node.len - 1], "HTML tag content",
                    "already has direct content")
        writer.add_literal(">")
        context.enter(tag)
        if not context.compact:
            writer.filters = context.filters & newCall("change_indentation",
                    newStrLitNode(context.indentation))
        parse_children(writer, context, node[node.len - 1])
        let finishInBlockMode = context.mode == blockmode
        context.exit()
        if finishInBlockMode:
            writer.add_literal(context.indentation)
        writer.add_literal("</" & name & ">")
        writer.filters = context.filters
    elif directContent != nil:
        writer.add_literal(">")
        writer.add_filtered(directContent)
        writer.add_literal("</" & name & ">")
    elif tag.tag_omission:
        writer.add_literal("/>")
    else:
        writer.add_literal("></" & name & ">")
    if outputInBlockMode:
        writer.add_literal("\n")

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
                result.add(copy_tree_replace_params(context, child))
        result.add(childWriter.result)
    else:
        result = copy_tree_replace_params(context, node)

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
                childName = toLower(node[0].first_ident)
                childTag  = tagIdFor(childName)
            if childTag == unknownTag:
                quit_unknown(node[0], "tag", childName)
            let childTagDef = tagDefFor(childTag)
            if context.accepts(childTagDef):
                parse_tag(writer, context, node, childTagDef, childName)
            else:
                quit_invalid(node, "Tag at this position", childName)
        of nnkPragma:
            process_pragma(writer, node[0], context)
        of nnkStrLit, nnkTripleStrLit:
            if context.mode == unknown:
                context.mode = flowmode
            writer.add_filtered(node.strVal)
        of nnkInfix, nnkDotExpr:
            if context.mode == unknown:
                context.mode = flowmode
            writer.add_filtered(copy_tree_replace_params(context, node))
        of nnkIdent:
            if context.mode == unknown:
                context.mode = flowmode
            writer.add_filtered(newNimNode(nnkPrefix).add(ident("$"),
                    copy_tree_replace_params(context, node)))
        of nnkIfStmt, nnkWhenStmt, nnkCaseStmt:
            var ifNode = newNimNode(node.kind, node)
            for ifBranch in node.children:
                ifNode.add(copy_node_parse_children(writer, context, ifBranch))
            writer.add_node(ifNode)
        of nnkForStmt, nnkWhileStmt:
            writer.addNode(copy_node_parse_children(writer, context, node))
        of nnkAsgn, nnkVarSection, nnkConstSection, nnkLetSection,
                nnkDiscardStmt:
            writer.addNode(copy_tree_replace_params(context, node))
        of nnkBlockStmt:
            if node[0].kind == nnkEmpty:
                quit_missing(node[0], "block name")
            let templ = context.cur_class()
            if templ == nil:
                quit_invalid(node, "block", "no blocks allowed in mixins")
            
            let
                (className, objName) = context.global_syms()
                blockName = node[0].ident_name
            
            # check if we're overriding an existing method
            var curClass = templ
            while curClass != nil:
                for m in curClass.methods:
                    if m.name == blockName:
                        quit_duplicate(node, "block", blockName)
                curClass = curClass.parent
            
            let
                methodName = genSym(nskMethod, ":block-" & templ.name() & "-" &
                        blockName)
                streamName = genSym(nskParam, ":stream")
                meth = newProc(if context.public: newNimNode(nnkPostfix).add(
                        ident("*"), methodName) else: methodName,
                        [newEmptyNode(), newIdentDefs(objName, className),
                        newIdentDefs(streamName, ident("Stream"))],
                        write_proc_content(streamName, node[1], context),
                        nnkMethodDef)
            
            templ.add_method(blockName, methodName, context)
            # references currently not properly handled by VM.
            # templ is a copy, therefore, copy it back.
            context.cur_class = templ
            update_template_class(templ)
            
            context.global_stmt_list.add(meth)
            writer.add_node(newCall(methodName, objName, writer.target_stream))
            
        of nnkCommand:
            let commandHash = hashIgnoreStyle(node[0].ident_name)
            case commandHash
            of hCall:
                for i in 1..(node.len - 1):
                    writer.add_node(copy_tree_replace_params(context, node[i]))
            of hPut:
                for i in 1..(node.len - 1):
                    if node[i].kind == nnkCall and
                            hashIgnoreStyle($node[i][0]) == hMixinContent and
                            node[i].len == 1:
                        let mixinLevel = context.pop_mixin_level()
                        if not mixinLevel.callable:
                            quit_invalid(node[i][0], "mixin content",
                                    "not available")
                        
                        let
                            (cache1, cache2) = mixinLevel.callback_caches()
                            callbackSym = genSym(nskParam, ":content" &
                                    $(mixinLevel.num_calls()))
                        var
                            mixinWriter = newStmtListWriter(genSym(nskParam,
                                    ":m" & $(mixinLevel.num_calls())),
                                    cache1, cache2)
                        
                        parse_children(mixinWriter, context,
                                mixinLevel.callback_content)
                        
                        mixinLevel.add_call(mixinWriter.result, callbackSym,
                                mixinWriter.target_stream())
                        
                        context.push_mixin_level(mixinLevel)
                        
                        writer.add_node(newCall(callbackSym,
                                writer.target_stream()))
                    else:
                        writer.add_filtered(copy_tree_replace_params(context,
                                node[i]))
            of hCallMixin:
                # if we just directly paste the parsed mixin code here, all
                # symbols that are visible here are visible in the mixin. we
                # don't want to have that. therefore, we instanciate a new proc
                # that pastes the content of the mixin.
                
                if node[1].kind != nnkCall:
                    quit_unexpected(node[1], "token (expected call)",
                            node[1].kind)
                
                let name = node[1][0].ident_name
                var procdef : NimNode = nil
                for child in mixins.children:
                    assert child.kind == nnkProcDef
                    if child[0].ident_name == name:
                        procdef = child
                        break
                
                if procdef == nil:
                    quit_unknown(node[1][0], "mixin", name)
                
                # use the mixin's pragma value as instance counter
                var index = 0
                if procdef[4].kind == nnkEmpty or procdef[4].len == 0:
                    procdef[4] = newNimNode(nnkPragma).add(newIntLitNode(0))
                else:
                    index = int(procdef[4][0].intVal)
                    procdef[4][0].intVal = index + 1
                
                let
                    mixinSym = genSym(nskProc, ":" & name & $index)
                    mixinStream = genSym(nskParam, ":stream")
                    (cache1, cache2) = writer.cache_vars()
                
                var
                    mixinLevel = if node.len > 2 and
                        node[2].kind == nnkStmtList: newMixinLevel(node[2],
                                cache1, cache2) else: newMixinLevel(nil)
                
                context.push_mixin_level(mixinLevel)
                
                var
                    mixinStmts = write_proc_content(mixinStream, procdef[6],
                        context)
                    instance = newProc(mixinSym, [newEmptyNode(),
                        newIdentDefs(mixinStream, ident("Stream"))], mixinStmts)
                
                mixinLevel = context.pop_mixin_level()
                   
                for i in 1 .. procdef[3].len - 1:
                    instance[3].add(procdef[3][i])
                
                for s in mixinLevel.call_content_syms:
                    instance[3].add(newIdentDefs(s.procSym, newNimNode(
                            nnkProcTy).add(newNimNode(nnkFormalParams).add(
                            newEmptyNode(), newIdentDefs(s.streamSym,
                            ident("Stream"))), newEmptyNode())))
                
                context.global_stmt_list.add(instance)
                
                var mixinCall = newCall(mixinSym, writer.streamName)
                for i in 1 .. node[1].len - 1:
                    mixinCall.add(node[1][i])
                
                for s in mixinLevel.call_content_syms:
                    mixinCall.add(newNimNode(nnkLambda).add(newEmptyNode(),
                            newEmptyNode(), newEmptyNode(), newNimNode(
                            nnkFormalParams).add(newEmptyNode(), newIdentDefs(
                            s.streamSym, ident("Stream"))), newEmptyNode(),
                            newEmptyNode(), s.content))
                
                writer.add_node(mixinCall)
            else:
                quit_unknown(node, "command", node[0].ident_name)
        else:
            quit_unexpected(node, "token", node.kind)
