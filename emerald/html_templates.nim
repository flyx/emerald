static:
    import
        macros, tables, strutils, private.writer, private.context, sets, tagdef

import streams, html5

type PTemplateBlock = proc(emeraldOutput: PStream) not nil

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

template quitUnknown[T](node: PNimrodNode, what: string, val: T) =
    quit node.lineInfo & ": Unknown " & what & ": \"" & $val & "\""

template quitUnexpected[T](node: PNimrodNode, what: string, val: T) =
    quit node.lineInfo & ": Unexpected " & what & ": \"" & $val & "\""

template quitDuplicate[T](node: PNimrodNode, what: string, val: T) =
    quit node.lineInfo & ": Duplicate " & what & ": \"" & $val & "\""

proc processAttribute(writer: PStmtListWriter,
                      name  : string, value: PNimrodNode) {.compileTime.} =
    ## generate code that adds an HTML tag attribute to the output
    var attrName = newStringOfCap(name.len)
    for c in name:
        if c == '_': attrName.add('-')
        else: attrName.add(c)
    writer.addString(" " & attrName & "=\"")
    writer.addEscapedStringExpr(copyNimTree(value), true)
    writer.addString("\"")

proc processNode(writer: PStmtListWriter, context: PContext,
                 node: PNimrodNode) {.compileTime.}

proc identName(node: PNimrodNode): string {.compileTime, inline.} =
    ## Used to be able to parse accent-quoted HTML tags as well.
    ## A prominent HTML tag is <div>, which is a keyword in Nimrod.
    ## You can either escape it with ``, or simply use "d" as a substitute.
    let name: string = if node.kind == nnkAccQuoted: $node[0] else: $node
    return if name == "d": "div" else: name

proc copyNodeParseChildren(writer: PStmtListWriter,
                           node: PNimrodNode, context: PContext):
        PNimrodNode {.compileTime.}

proc childNodeName(node: PNimrodNode): string {.compileTime.} =
    case node[0].kind:
    of nnkIdent, nnkAccQuoted:
        result = identName(node[0])
    of nnkDotExpr:
        result = identName(node[0][0])
    else:
        node.quitUnexpected("token", node[0].kind)

proc processChilds(writer: PStmtListWriter,
                   parent: PNimrodNode, context: PContext) {.compileTime.} =
    ## Called on a nnkStmtList. Process all child nodes of the lists, parse
    ## supported structures, generate the code of the compiled template.
    for child in parent.children:
        case child.kind:
        of nnkEmpty, nnkCommentStmt:
            continue
        of nnkCall:
            if context.mode == unknown:
                context.mode = blockmode
                writer.addString("\n")
            let childName = child.childNodeName
            if not context.tags.hasKey(childName):
                child.quitUnknown("HTM tag", childName)
            let childTag  = context.tags[childName]
            if context.accepts(childTag):
                context.enter(childTag)
                processNode(writer, context, child)
                context.exit()
            else:
                quit child.lineInfo & ": Tag not permitted at this position."
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
            var ifNode = newNimNode(child.kind, child)
            for ifBranch in child.children:
                ifNode.add(copyNodeParseChildren(writer, ifBranch,
                                                 context))
            writer.addNode(ifNode)
        of nnkForStmt, nnkWhileStmt:
            writer.addNode(copyNodeParseChildren(writer, child,
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
                child.quitUnknown("command", identName(child[0]))
        of nnkIncludeStmt:
            if child[0].kind != nnkCall:
                child.quitUnexpected("include param", child[0].kind)
            var call = copyNimTree(child[0])
            call.insert(1, newIdentNode(streamVarName))
            writer.addNode(call)
        else:
            child.quitUnexpected("node type", child.kind)

proc copyNodeParseChildren(writer: PStmtListWriter,
                           node: PNimrodNode,
                           context:  PContext): PNimrodNode =
    if node.kind in [nnkElifBranch, nnkOfBranch, nnkElse, nnkForStmt,
                     nnkWhileStmt]:
        result = copyNimNode(node)
        var childWriter = newStmtListWriter()
        for child in node.children:
            if child.kind == nnkStmtList:
                processChilds(childWriter, child, context)
            else:
                result.add(copyNimTree(child))
        result.add(childWriter.result)
    else:
        result = copyNimTree(node)

proc processNode(writer: PStmtListWriter, context: PContext,
                 node: PNimrodNode) =
    ## Process the header of the current node. This contains
    ## the name of the HTML tag and its attributes. If the
    ## node has any children, `child` will point to their nnkStmtList.
    ## Else, it will be `nil`.
    let
        globalAttributes : TSet[string] = toSet([
                "acceskey", "contenteditable", "contextmenu", "dir",
                "draggable", "dropzone", "hidden", "id", "itemid",
                "itemprop", "itemref", "itemscope", "itemtype",
                "lang", "spellcheck", "style", "tabindex", "title"])
        outputInBlockMode = (context.mode != flowmode)

    var 
        tag: PTagDef
        tagName: string = nil
        nodeChildList: PNimrodNode = nil

    block tagNameAndClasses:
        var classString: string = ""

        case node[0].kind:
        of nnkIdent, nnkAccQuoted:
            tagName = identName(node[0])
        of nnkDotExpr:
            var first = true
            for child in node[0].children:
                if not (child.kind == nnkIdent or child.kind == nnkAccQuoted):
                    quit node[0].lineInfo & ": Unexpected node (" &
                        $child.kind & ")"
                if first:
                    tagName = identName(child)
                    first = false
                else:
                    if classString.len > 0:
                        classString.add(' ')
                    classString.add(identName(child))
        else:
            node[0].quitUnexpected("node type", node[0].kind)
        assert (not isNil(tagName))

        tag = context.tags[tagName]
        if isNil(tag):
            node[0].quitUnknown("HTML tag", tagName)
        if outputInBlockMode:
            writer.addString(repeatChar(4 * context.depth, ' ') & "<" & tagName)
        else:
            writer.addString("<" & tagName)
        if classString.len > 0:
            writer.addString(" class=\"" & classString & "\"")

    block attributes:
        var
            first = true
            parsedAttributes : TSet[string] = initSet[string]()
        for child in node.children:
            if first:
                first = false
                continue
            case child.kind:
            of nnkExprEqExpr:
                let childName = identName(child[0])
                if not (globalAttributes.contains(childName) or
                        tag.requiredAttrs.contains(childName) or
                        tag.optionalAttrs.contains(childName)):
                    quit child[0].lineInfo & ": Attribute \"" &
                        childName & "\" not allowed in tag \"" & tagName & "\""
                if parsedAttributes.contains(childName):
                    child[0].quitDuplicate("attribute", childName)
                parsedAttributes.incl(childName)
                processAttribute(writer, childName, child[1])
            of nnkStrLit:
                if parsedAttributes.contains("id"):
                    child[0].quitDuplicate("attribute", "id")
                else:
                    parsedAttributes.incl("id")
                    processAttribute(writer, "id", child)
            of nnkDo:
                for doChild in child.children:
                    if doChild.kind == nnkStmtList:
                        nodeChildList = doChild
            else:
                child.quitUnexpected("token", child.kind)

        if not (tag.requiredAttrs <= parsedAttributes):
            var
                missing = tag.requiredAttrs
                msg = ""
            missing.excl(parsedAttributes)
            for item in missing:
                msg.add(item & ", ")
            quit node.lineInfo &
                 ": The following mandatory attributes are missing on tag \"" &
                 tagName & "\": " & msg

    block content:
        if isNil(nodeChildList) and tag.tagOmission:
            # TODO: do we really need to XML-like unclosed tags?
            writer.addString(" />")
        else:
            writer.addString(">")
            if not isNil(nodeChildList):
                processChilds(writer, nodeChildList, context)
                if context.mode == blockmode:
                    writer.addString(repeatChar(4 * context.depth, ' '))
            writer.addString("</" & tagName & ">")
        if outputInBlockMode: writer.addString("\n")

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
            var
                writer = newStmtListWriter()
                primary = low(TExtendedTagId)
                context = newContext(html5tags(), primary, blockmode)
            if isTemplate:
                writer.addString("<!DOCTYPE html>\n")
            else:
                primary = TExtendedTagId(context.tags["html"].id)
            processChilds(writer, child, context)
            result.add(writer.result)
        of nnkEmpty, nnkPragma, nnkIdent:
            result.add(copyNimTree(child))
        else:
            child.quitUnexpected("node in template proc def", child.kind)
    echo "done."
