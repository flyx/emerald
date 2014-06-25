import
    macros, tables, strutils, impl.writer, impl.htmltags, sets

# interface

proc html_template_impl(content: PNimrodNode, doctype: bool): PNimrodNode {.compileTime.}

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

type
    TOutputMode = enum
        unknown, blockmode, flowmode

proc processAttribute(writer: var PStmtListWriter,
                      name  : string, value: PNimrodNode) {.compileTime.} =
    ## generate code that adds an HTML tag attribute to the output
    writer.addString(" " & name & "=\"")
    writer.addStringExpr(copyNimTree(value))
    writer.addString("\"")

proc processNode(writer: var PStmtListWriter, parent: PNimrodNode,
                 depth : int, mode: TOutputMode) {.compileTime.}

proc identName(node: PNimrodNode): string {.compileTime, inline.} =
    ## Used to be able to parse accent-quoted HTML tags as well.
    ## A prominent HTML tag is <div>, which is a keyword in Nimrod.
    ## You can either escape it with ``, or simply use "d" as a substitute.
    let name: string = if node.kind == nnkAccQuoted: $node[0] else: $node
    return if name == "d": "div" else: name

proc copyNodeParseChildren(htmlTag: string,
                           node: PNimrodNode, depth: int,
                           mode: var TOutputMode): PNimrodNode {.compileTime.}

proc processChilds(writer: var PStmtListWriter, htmlTag: string,
                   parent: PNimrodNode, depth: int,
                   mode  : var TOutputMode) {.compileTime.} =
    ## Called on a nnkStmtList. Process all child nodes of the lists, parse
    ## supported structures, generate the code of the compiled template.
    for child in parent.children:
        case child.kind:
        of nnkEmpty, nnkFormalParams, nnkCommentStmt:
            continue
        of nnkCall:
            if mode == unknown:
                mode = blockmode
                writer.addString("\n")
            processNode(writer, child,
                        if mode == blockMode: depth + 1 else: 0, mode)
        of nnkStmtList:
            processChilds(writer, htmlTag, child, depth, mode)
        of nnkInfix, nnkStrLit:
            if mode == unknown:
                mode = flowmode
            writer.addStringExpr(copyNimTree(child))
        of nnkIdent:
            if mode == unknown:
                mode = flowmode
            var printVar = newNimNode(nnkPrefix, child)
            printVar.add(newIdentNode("$"))
            printVar.add(copyNimTree(child))
            writer.addStringExpr(printVar)
        of nnkTripleStrLit:
            if mode == unknown:
                mode = blockmode
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
                writer.addString(repeatChar(4 * (depth + 1), ' ') &
                                 line[firstContentChar..line.len - 1] & "\n")

        of nnkIfStmt, nnkWhenStmt:
            var 
                ifNode = newNimNode(child.kind, child)

            for ifBranch in child.children:
                ifNode.add(copyNodeParseChildren(htmlTag, ifBranch, depth, mode))
            writer.addNode(ifNode)
        of nnkForStmt, nnkWhileStmt:
            writer.addNode(copyNodeParseChildren(htmlTag, child, depth, mode))
        of nnkAsgn, nnkVarSection, nnkDiscardStmt:
            writer.addNode(copyNimTree(child))
        of nnkCommand:
            assert child.len == 2
            assert child[0].kind == nnkIdent
            case identName(child[0]):
            of "call":
                writer.addNode(copyNimTree(child[1]))
            of "put":
                writer.addStringExpr(copyNimTree(child[1]))
        of nnkIncludeStmt:
            assert child[0].kind == nnkCall
            var call = copyNimTree(child[0])
            call.insert(1, newIdentNode("o"))
            writer.addNode(call)
        else:
            quit "Unexpected node type (" & $child.kind & ")"

proc copyNodeParseChildren(htmlTag: string,
                           node: PNimrodNode, depth: int,
                           mode: var TOutputMode): PNimrodNode =
    var
        childWriter = newStmtListWriter(htmltags())
    result = copyNimNode(node)
    for child in node.children:
        if child.kind == nnkStmtList:
            processChilds(childWriter, htmlTag, child, depth, mode)
        else:
            result.add(copyNimTree(child))
    result.add(childWriter.result)

proc processNode(writer: var PStmtListWriter, parent: PNimrodNode,
                 depth: int, mode: TOutputMode) =
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
            assert(node.kind == nnkIdent or node.kind == nnkAccQuoted)
            if first:
                name = identName(node)
                first = false
            else:
                var className: string = identName(node)
                add(classes, className)
    else:
        quit "Unexpected node type (" & $parent[0].kind & ")"

    if not writer.tags.hasKey(name):
        quit "Unknown HTML tag: " & name

    let tagProps = writer.tags[name]

    if mode == blockmode:
        writer.addString(repeatChar(4 * depth, ' ') & "<" & name)
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

    while childIndex < parent.len and parent[childIndex].kind == nnkExprEqExpr:
        let childName = identName(parent[childIndex][0])
        if not (childName in globalAttributes or
                childName in tagProps.requiredAttrs or
                childName in tagProps.optionalAttrs):
            quit "Attribute \"" & childName &
                 "\" not allowed in tag \"" & name & "\""
        if childName in parsedAttributes:
            quit "Duplicate attribute: " & childName
        parsedAttributes.incl(childName)
        processAttribute(writer, childName, parent[childIndex][1])
        inc(childIndex)

    if not (tagProps.requiredAttrs <= parsedAttributes):
        var
            missing = tagProps.requiredAttrs
            msg = ""
        for item in parsedAttributes:
            missing.excl(item)
        for item in missing:
            msg.add(item & ", ")
        quit "The following mandatory attributes are missing on tag \"" &
             name & "\": " & msg

    if childIndex < parent.len:
        writer.addString(">")
        var childMode: TOutputMode = unknown
        processChilds(writer, name, parent[childIndex], depth, childMode)

        if childMode == blockmode:
            writer.addString(repeatChar(4 * depth, ' ') & "</" & name & ">")
        else:
            writer.addString("</" & name & ">")
    elif tagProps.tagOmission:
        writer.addString(" />")
    else:
        writer.addString("></" & name & ">")

    if mode == blockmode:
        writer.addString("\n")

proc html_template_impl(content: PNimrodNode, doctype: bool): PNimrodNode =
    ## parse the child tree of this node as HTML template. The macro
    ## transforms the template into Nimrod code. Currently,
    ## it is assumed that a variable "result" exists, and the generated
    ## code will append its output to this variable.
    assert content.kind == nnkProcDef

    result = newNimNode(nnkProcDef, content)

    for child in content.children:
        case child.kind:
        of nnkFormalParams:
            var
                formalParams = copyNimTree(child)
                identDef = newNimNode(nnkIdentDefs, child)
                insertPos = 0
            while insertPos < formalParams.len and formalParams[insertPos].kind == nnkEmpty:
                inc(insertPos)
            identDef.add(newIdentNode("o"))
            identDef.add(newIdentNode("PStream"))
            identDef.add(newNimNode(nnkEmpty))
            formalParams.insert(insertPos, identDef)
            result.add(formalParams)
        of nnkStmtList:
            var
                mode = blockmode
                writer = newStmtListWriter(htmltags())
            if doctype:
                writer.addString("<!DOCTYPE html>\n")
            processChilds(writer, "", child, -1, mode)
            result.add(writer.result)
        of nnkEmpty, nnkPragma, nnkIdent:
            result.add(copyNimTree(child))
        else:
            quit "Unexpected node in template proc def: " & $child.kind
