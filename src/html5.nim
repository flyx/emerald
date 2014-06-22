import
    macros, sets, tables, strutils

type
    TTagHandling = tuple[requiredAttrs  : TSet[string],
                         optionalAttrs  : TSet[string],
                         requiredChilds : TSet[string],
                         optionalChilds : TSet[string],
                         instaClosable  : bool]

    TTagList = TTable[string, TTagHandling]

    TOutputMode = enum
        unknown, blockmode, flowmode

proc processAttribute(tags: TTable[string, TTagHandling],
                      name: string, value: PNimrodNode,
                      target : var PNimrodNode) {.compileTime.} =
    ## generate code that adds an HTML tag attribute to the output
    target.add(newCall("add", newIdentNode("result"),
                       newStrLitNode(" " & name & "=\"")))
    target.add(newCall("add", newIdentNode("result"), copyNimTree(value)))
    target.add(newCall("add", newIdentNode("result"), newStrLitNode("\"")))

proc processNode(tags: TTable[string, TTagHandling], parent: PNimrodNode,
                 depth: int, target : var PNimrodNode,
                 mode: TOutputMode) {.compileTime.}

proc identName(node: PNimrodNode): string {.compileTime, inline.} =
    ## Used to be able to parse accent-quoted HTML tags as well.
    ## A prominent HTML tag is <div>, which is a keyword in Nimrod.
    ## You can either escape it with ``, or simply use "d" as a substitute.
    let name: string = if node.kind == nnkAccQuoted: $node[0] else: $node
    return if name == "d": "div" else: name

proc processChilds(tags: TTable[string, TTagHandling], node: string,
                   parent: PNimrodNode, depth: int, target : var PNimrodNode,
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
                target.add(newCall("add", newIdentNode("result"),
                                   newStrLitNode("\n")))
            processNode(tags, child,
                        if mode == blockMode: depth + 1 else: 0, target, mode)
        of nnkStmtList:
            processChilds(tags, node, child, depth, target, mode)
        of nnkStrLit, nnkInfix:
            if mode == unknown:
                mode = flowmode
            target.add(newCall("add", newIdentNode("result"),
                               copyNimTree(child)))
        of nnkIdent:
            if mode == unknown:
                mode = flowmode
            var printVar = newNimNode(nnkPrefix, child)
            printVar.add(newIdentNode("$"))
            printVar.add(copyNimTree(child))
            target.add(newCall("add", newIdentNode("result"), printVar))
        of nnkTripleStrLit:
            if mode == unknown:
                mode = blockmode
                target.add(newCall("add", newIdentNode("result"),
                                   newStrLitNode("\n")))
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

                target.add(newCall("add", newIdentNode("result"),
                           newStrLitNode(repeatChar(4 * (depth + 1), ' ') &
                                         line[firstContentChar..line.len - 1] &
                                         "\n")))

        of nnkIfStmt:
            assert child[0].kind == nnkElifBranch
            assert child[0][1].kind == nnkStmtList

            var 
                ifNode = newNimNode(nnkIfStmt, child)

            for ifBranch in child.children:
                case ifBranch.kind:
                of nnkElifBranch:
                    var
                        ifCond = newNimNode(nnkElifBranch, ifBranch)
                        ifContent = newNimNode(nnkStmtList, ifBranch[1])
                    ifCond.add(copyNimTree(ifBranch[0]))
                    processChilds(tags, node, ifBranch[1], depth, ifContent,
                                  mode)
                    ifCond.add(ifContent)
                    ifNode.add(ifCond)
                of nnkElse:
                    var
                        elseCond    = newNimNode(nnkElse, ifBranch)
                        elseContent = newNimNode(nnkStmtList, ifBranch)
                    processChilds(tags, node, ifBranch[0], depth, elseContent,
                                  mode)
                    elseCond.add(elseContent)
                    ifNode.add(elseCond)
                else:
                    quit "The nimrod parser should not allow this…"
            target.add(ifNode)
        of nnkForStmt, nnkWhileStmt:
            let stmtIndex = if child.kind == nnkForStmt: 2 else: 1
            var
                newNode = copyNimTree(child)
                newContent = newNimNode(nnkStmtList, child)
            processChilds(tags, node, child[stmtIndex], depth, newContent, mode)
            newNode[stmtIndex] = newContent
            target.add(newNode)
        of nnkAsgn:
            target.add(copyNimTree(child))
        of nnkVarSection:
            target.add(copyNimTree(child))
        of nnkCommand:
            assert child.len == 2
            assert child[0].kind == nnkIdent
            case identName(child[0]):
            of "call":
                target.add(copyNimTree(child[1]))
        of nnkIncludeStmt:
            for incl in child.children:
                target.add(newCall("add", newIdentNode("result"),
                                   copyNimTree(incl)))
        else:
            quit "Unexpected node type (" & $child.kind & ")"

proc processNode(tags: TTable[string, TTagHandling], parent: PNimrodNode,
                 depth: int, target : var PNimrodNode, mode: TOutputMode) =
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

    if not tags.hasKey(name):
        quit "Unknown HTML tag: " & name

    let tagProps = tags[name]

    if mode == blockmode:
        target.add(newCall("add", newIdentNode("result"),
                           newStrLitNode(repeatChar(4 * depth, ' ') &
                           "<" & name)))
    else:
        target.add(newCall("add", newIdentNode("result"),
                           newStrLitNode("<" & name)))

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
        target.add(newCall("add", newIdentNode("result"),
                           newStrLitNode(" class=\"" & classString & "\"")))

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
        processAttribute(tags, childName, parent[childIndex][1], target)
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
        target.add(newCall("add", newIdentNode("result"), newStrLitNode(">")))
        var childMode: TOutputMode = unknown
        processChilds(tags, name, parent[childIndex], depth, target, childMode)

        if childMode == blockmode:
            target.add(newCall("add", newIdentNode("result"),
                               newStrLitNode(repeatChar(4 * depth, ' ') &
                                             "</" & name & ">")))
        else:
            target.add(newCall("add", newIdentNode("result"),
                               newStrLitNode("</" & name & ">")))
    elif tagProps.instaClosable:
        target.add(newCall("add", newIdentNode("result"), newStrLitNode(" />")))
    else:
        target.add(newCall("add", newIdentNode("result"), newStrLitNode("></" & name & ">")))

    if mode == blockmode:
        target.add(newCall("add", newIdentNode("result"),
                           newStrLitNode("\n")))

include impl.htmltags

proc html_template_impl(content: PNimrodNode, doctype: bool): PNimrodNode {.compileTime.} =
    ## parse the child tree of this node as HTML template. The macro
    ## transforms the template into Nimrod code. Currently,
    ## it is assumed that a variable "result" exists, and the generated
    ## code will append its output to this variable.
    echo treeRepr(content) & "\n---"
    assert content.kind == nnkProcDef

    result = newNimNode(nnkProcDef, content)

    for child in content.children:
        case child.kind:
        of nnkFormalParams:
            when false:
                var
                    formalParams = copyNimTree(child)
                    identDef = newNimNode(nnkIdentDefs, child)
                identDef.add(newIdentNode("o"))
                identDef.add(newIdentNode("PStream"))
                formalParams.insert(0, identDef)
                result.add(formalParams)
            else:
                result.add(copyNimTree(child))
        of nnkStmtList:
            var
                stmts = newNimNode(nnkStmtList, child)
                resultInit = newNimNode(nnkInfix, child)
                mode = blockmode
            stmts.add(newAssignment(newIdentNode("result"), newStrLitNode("")))
            if doctype:
                stmts.add(newCall("add", newIdentNode("result"),
                                  newStrLitNode("<!DOCTYPE html>\n")))
            processChilds(tags(), "", child, -1, stmts, mode)
            result.add(stmts)
        of nnkEmpty, nnkPragma, nnkIdent:
            result.add(copyNimTree(child))
        else:
            quit "Unexpected node in template proc def: " & $child.kind

macro html_template*(content: stmt): stmt {.immediate.} =
    result = html_template_impl(content, true)

macro html_template_macro*(content: stmt): stmt {.immediate.} =
    result = html_template_impl(content, false)