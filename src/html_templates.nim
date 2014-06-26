import
    macros, tables, strutils, impl.writer, impl.context, html5, sets

# interface

proc html_template_impl(content: PNimrodNode, isTemplate: bool):
        PNimrodNode {.compileTime.}

macro html_template*(content: stmt): stmt {.immediate.} =
    ## Use it as pragma on a proc. Parses the content of the proc as HTML
    ## template and replaces its contents with the result
    result = html_template_impl(content, true)

macro html_template_macro*(content: stmt): stmt {.immediate.} =
    ## Same as html_template, but does't write the doctype declaration in
    ## front. Can be called from within other html templates and
    ## template macros.
    result = html_template_impl(content, false)

# implementation

proc processAttribute(writer: PStmtListWriter,
                      name  : string, value: PNimrodNode) {.compileTime.} =
    ## generate code that adds an HTML tag attribute to the output
    var attrName = ""
    for c in name:
        if c == '_': attrName.add('-')
        else: attrName.add(c)
    writer.addString(" " & attrName & "=\"")
    writer.addEscapedStringExpr(copyNimTree(value), true)
    writer.addString("\"")

proc processNode(writer: PStmtListWriter, parent: PNimrodNode,
                 context: PContext) {.compileTime.}

proc identName(node: PNimrodNode): string {.compileTime, inline.} =
    ## Used to be able to parse accent-quoted HTML tags as well.
    ## A prominent HTML tag is <div>, which is a keyword in Nimrod.
    ## You can either escape it with ``, or simply use "d" as a substitute.
    let name: string = if node.kind == nnkAccQuoted: $node[0] else: $node
    return if name == "d": "div" else: name

proc copyNodeParseChildren(writer: PStmtListWriter, htmlTag: string,
                           node: PNimrodNode, context: PContext):
        PNimrodNode {.compileTime.}

proc childNodeName(node: PNimrodNode): string {.compileTime.} =
    case node[0].kind:
    of nnkIdent, nnkAccQuoted:
        result = identName(node[0])
    of nnkDotExpr:
        result = identName(node[0][0])
    else:
        quit node.lineInfo & ": Unexpected token (" & $node[0].kind & ")"

proc processChilds(writer: PStmtListWriter, htmlTag: string,
                   parent: PNimrodNode, context: PContext) {.compileTime.} =
    ## Called on a nnkStmtList. Process all child nodes of the lists, parse
    ## supported structures, generate the code of the compiled template.
    for child in parent.children:
        case child.kind:
        of nnkEmpty, nnkFormalParams, nnkCommentStmt:
            continue
        of nnkCall:
            if context.mode == unknown:
                context.mode = blockmode
                writer.addString("\n")
            let childName = child.childNodeName
            if not writer.tags.hasKey(childName):
                quit child.lineInfo & ": Unknown HTML tag \"" &
                    childName & "\""
            let childTag  = writer.tags[childName]
            if context.accepts(childName, childTag):
                processNode(writer, child, context.enter(childTag))
            else:
                quit child.lineInfo & ": Tag not permitted at this position."
        of nnkStmtList:
            processChilds(writer, htmlTag, child, context)
        of nnkInfix, nnkStrLit:
            if context.mode == unknown:
                context.mode = flowmode
            writer.addEscapedStringExpr(child)
        of nnkIdent:
            if context.mode == unknown:
                context.mode = flowmode
            var printVar = newNimNode(nnkPrefix, child)
            printVar.add(newIdentNode("$"))
            printVar.add(copyNimTree(child))
            writer.addEscapedStringExpr(printVar)
        of nnkTripleStrLit:
            if context.mode == unknown:
                context.mode = blockmode
                writer.addString("\n")
            var first = true
            var baseIndent = 0
            for line in child.strVal.splitLines:
                let frontStripped = line.strip(true, false)
                if frontStripped.len == 0:
                    continue
                if first:
                    baseIndent = line.len - frontStripped.len
                    first = false
                var firstContentChar = -1
                for i in 0..(baseIndent - 1):
                    if line[i] != ' ':
                        firstContentChar = i
                        break
                if firstContentChar == -1:
                    firstContentChar = baseIndent
                writer.addString(repeatChar(4 * (context.depth + 1), ' ') &
                                 line[firstContentChar..line.len - 1] & "\n")

        of nnkIfStmt, nnkWhenStmt, nnkCaseStmt:
            var 
                ifNode = newNimNode(child.kind, child)

            for ifBranch in child.children:
                ifNode.add(copyNodeParseChildren(writer, htmlTag, ifBranch,
                                                 context))
            writer.addNode(ifNode)
        of nnkForStmt, nnkWhileStmt:
            writer.addNode(copyNodeParseChildren(writer, htmlTag, child,
                                                 context))
        of nnkAsgn, nnkVarSection, nnkDiscardStmt:
            writer.addNode(copyNimTree(child))
        of nnkCommand:
            if child.len != 2:
                quit child.lineInfo &
                    ": Command with unexpected number of parameters"
            case identName(child[0]):
            of "call":
                writer.addNode(copyNimTree(child[1]))
            of "put":
                writer.addEscapedStringExpr(copyNimTree(child[1]))
            else:
                quit child.lineInfo & ": Unknown command \"" &
                    identName(child[0]) & "\""
        of nnkIncludeStmt:
            if child[0].kind != nnkCall:
                quit child.lineInfo & ": Unexpected include param (" &
                    $child[0].kind & ")"
            var call = copyNimTree(child[0])
            call.insert(1, newIdentNode(streamVarName))
            writer.addNode(call)
        else:
            quit child.lineInfo() & ": Unexpected node type (" &
                $child.kind & ")"

proc copyNodeParseChildren(writer: PStmtListWriter, htmlTag: string,
                           node: PNimrodNode,
                           context:  PContext): PNimrodNode =
    if node.kind in [nnkElifBranch, nnkOfBranch, nnkElse, nnkForStmt,
                     nnkWhileStmt]:
        result = copyNimNode(node)
        var childWriter = newStmtListWriter(writer.tags)
        for child in node.children:
            if child.kind == nnkStmtList:
                processChilds(childWriter, htmlTag, child, context)
            else:
                result.add(copyNimTree(child))
        result.add(childWriter.result)
    else:
        result = copyNimTree(node)

proc processNode(writer: PStmtListWriter, parent: PNimrodNode,
                 context: PContext) =
    ## Process one node the represents an HTML tag in the source tree.
    let
        globalAttributes : TSet[string] = toSet([
                "acceskey", "contenteditable", "contextmenu", "dir",
                "draggable", "dropzone", "hidden", "id", "itemid",
                "itemprop", "itemref", "itemscope", "itemtype",
                "lang", "spellcheck", "style", "tabindex", "title"])
    var
        childIndex = 1
        parsedAttributes : TSet[string] = initSet[string]()
        name: string = ""
        classes: seq[string] = newSeq[string]()

    case parent[0].kind:
    of nnkIdent, nnkAccQuoted:
        name = identName(parent[0])
    of nnkDotExpr:
        var first = true
        for node in parent[0].children:
            if not (node.kind == nnkIdent or node.kind == nnkAccQuoted):
                quit parent[0].lineInfo & ": Unexpected node (" &
                    $node.kind & ")"
            if first:
                name = identName(node)
                first = false
            else:
                var className: string = identName(node)
                add(classes, className)
    else:
        quit parent[0].lineInfo & ": Unexpected node type (" &
            $parent[0].kind & ")"

    if not writer.tags.hasKey(name):
        quit parent[0].lineInfo & ": Unknown HTML tag \"" & name & "\""

    let
        tagProps = writer.tags[name]
        outputInBlockMode = (context.mode != flowmode)

    if outputInBlockMode:
        writer.addString(repeatChar(4 * context.depth, ' ') & "<" & name)
    else:
        writer.addString("<" & name)

    if classes.len > 0:
        var
            first = true
            classString = ""
        for class in classes:
            if first:
                first = false
            else:
                classString.add(" ")
            classString.add(class)
        writer.addString(" class=\"" & classString & "\"")

    while childIndex < parent.len and parent[childIndex].kind != nnkDo:
        case parent[childIndex].kind:
        of nnkExprEqExpr:
            let childName = identName(parent[childIndex][0])
            if not (globalAttributes.contains(childName) or
                    tagProps.requiredAttrs.contains(childName) or
                    tagProps.optionalAttrs.contains(childName)):
                quit parent[childIndex][0].lineInfo & ": Attribute \"" &
                    childName & "\" not allowed in tag \"" & name & "\""
            if parsedAttributes.contains(childName):
                quit parent[childIndex][0].lineInfo &
                    ": Duplicate attribute: " & childName
            parsedAttributes.incl(childName)
            processAttribute(writer, childName, parent[childIndex][1])
        of nnkStrLit:
            if parsedAttributes.contains("id"):
                quit parent[childIndex][0].lineInfo &
                    ": Duplicate attribute: id"
            else:
                parsedAttributes.incl("id")
                processAttribute(writer, "id", parent[childIndex])
        else:
            quit parent[childIndex].lineInfo & ": Unexpected token (" &
                $parent[childIndex].kind & ")"
        inc(childIndex)

    if not (tagProps.requiredAttrs <= parsedAttributes):
        var
            missing = tagProps.requiredAttrs
            msg = ""
        for item in parsedAttributes:
            missing.excl(item)
        for item in missing:
            msg.add(item & ", ")
        quit parent.lineInfo &
             ": The following mandatory attributes are missing on tag \"" &
             name & "\": " & msg

    if childIndex < parent.len:
        writer.addString(">")
        processChilds(writer, name, parent[childIndex], context)

        if context.mode == blockmode:
            writer.addString(repeatChar(4 * context.depth, ' ') & "</" &
                name & ">")
        else:
            writer.addString("</" & name & ">")
    elif tagProps.tagOmission:
        writer.addString(" />")
    else:
        writer.addString("></" & name & ">")

    if outputInBlockMode:
        writer.addString("\n")

proc html_template_impl(content: PNimrodNode, isTemplate: bool): PNimrodNode =
    ## parse the child tree of this node as HTML template. The macro
    ## transforms the template into Nimrod code. Currently,
    ## it is assumed that a variable "result" exists, and the generated
    ## code will append its output to this variable.
    assert content.kind == nnkProcDef

    echo "parsing template \"" & identName(content[0]) & "\"..."

    result = newNimNode(nnkProcDef, content)

    for child in content.children:
        case child.kind:
        of nnkFormalParams:
            var
                formalParams = copyNimTree(child)
                identDef = newNimNode(nnkIdentDefs, child)
                insertPos = 0
            while insertPos < formalParams.len and 
                    formalParams[insertPos].kind == nnkEmpty:
                inc(insertPos)
            identDef.add(newIdentNode(streamVarName))
            identDef.add(newIdentNode("PStream"))
            identDef.add(newNimNode(nnkEmpty))
            formalParams.insert(insertPos, identDef)
            result.add(formalParams)
        of nnkStmtList:
            var writer = newStmtListWriter(html5tags())
            if isTemplate:
                writer.addString("<!DOCTYPE html>\n")
            processChilds(writer, "", child,
                          initContext(not isTemplate, blockmode))
            result.add(writer.result)
        of nnkEmpty, nnkPragma, nnkIdent:
            result.add(copyNimTree(child))
        else:
            quit child.lineInfo &
                ": Unexpected node in template proc def: " & $child.kind
    echo "done."
