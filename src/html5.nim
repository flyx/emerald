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

proc processChilds(tags: TTable[string, TTagHandling], node: string,
                   parent: PNimrodNode, depth: int, target : var PNimrodNode,
                   mode  : var TOutputMode) {.compileTime.} =
    ## Called on a nnkStmtList. Process all child nodes of the lists, parse
    ## supported structures, generate the code of the compiled template.
    for child in parent.children:
        case child.kind:
        of nnkEmpty, nnkFormalParams:
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
        of nnkForStmt:
            var
                forNode = copyNimTree(child)
                forContent = newNimNode(nnkStmtList, child)
            processChilds(tags, node, child[2], depth, forContent, mode)
            forNode[2] = forContent
            target.add(forNode)
        of nnkVarSection:
            target.add(copyNimNode(child))
        else:
            quit "Unexpected node type (" & $child.kind & ")"

proc identName(node: PNimrodNode): string {.compileTime, inline.} =
    ## Used to be able to parse accent-quoted HTML tags as well.
    ## A prominent HTML tag is <div>, which is a keyword in Nimrod.
    ## You can either escape it with ``, or simply use "d" as a substitute.
    let name: string = if node.kind == nnkAccQuoted: $node[0] else: $node
    return if name == "d": "div" else: name

proc processNode(tags: TTable[string, TTagHandling], parent: PNimrodNode,
                 depth: int, target : var PNimrodNode, mode: TOutputMode) =
    ## Process one node the represents an HTML tag in the source tree.
    echo treeRepr(parent)
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


macro html5*(params : openarray[stmt]): stmt {.immediate.} =
    ## parse the child tree of this node as HTML template. The macro
    ## transforms the template into Nimrod code. Currently,
    ## it is assumed that a variable "result" exists, and the generated
    ## code will append its output to this variable.

    var
        tags : TTagList = initTable[string, TTagHandling]()
    tags["body"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : initSet[string](),
                    optionalChilds : initSet[string](),
                    instaClosable  : false)
    tags["br"]  = (requiredAttrs  : initSet[string](),
                   optionalAttrs  : initSet[string](),
                   requiredChilds : initSet[string](),
                   optionalChilds : initSet[string](),
                   instaClosable  : true)
    tags["div"] = (requiredAttrs  : initSet[string](),
                   optionalAttrs  : initSet[string](),
                   requiredChilds : initSet[string](),
                   optionalChilds : initSet[string](),
                   instaClosable  : false)
    tags["h1"] = (requiredAttrs  : initSet[string](),
                  optionalAttrs  : initSet[string](),
                  requiredChilds : initSet[string](),
                  optionalChilds : initSet[string](),
                  instaClosable  : false)
    tags["h2"] = (requiredAttrs  : initSet[string](),
                  optionalAttrs  : initSet[string](),
                  requiredChilds : initSet[string](),
                  optionalChilds : initSet[string](),
                  instaClosable  : false)
    tags["h3"] = (requiredAttrs  : initSet[string](),
                  optionalAttrs  : initSet[string](),
                  requiredChilds : initSet[string](),
                  optionalChilds : initSet[string](),
                  instaClosable  : false)
    tags["h4"] = (requiredAttrs  : initSet[string](),
                  optionalAttrs  : initSet[string](),
                  requiredChilds : initSet[string](),
                  optionalChilds : initSet[string](),
                  instaClosable  : false)
    tags["h5"] = (requiredAttrs  : initSet[string](),
                  optionalAttrs  : initSet[string](),
                  requiredChilds : initSet[string](),
                  optionalChilds : initSet[string](),
                  instaClosable  : false)
    tags["h6"] = (requiredAttrs  : initSet[string](),
                  optionalAttrs  : initSet[string](),
                  requiredChilds : initSet[string](),
                  optionalChilds : initSet[string](),
                  instaClosable  : false)
    tags["head"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : toSet[string](["title"]),
                    optionalChilds : initSet[string](),
                    instaClosable  : false)
    tags["html"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : toSet[string](["head", "body"]),
                    optionalChilds : initSet[string](),
                    instaClosable  : false)
    tags["p"] = (requiredAttrs  : initSet[string](),
                 optionalAttrs  : initSet[string](),
                 requiredChilds : initSet[string](),
                 optionalChilds : initSet[string](),
                 instaClosable  : false)
    tags["script"] = (requiredAttrs : initSet[string](),
                      optionalAttrs : toSet(["type"]),
                      requiredChilds: initSet[string](),
                      optionalChilds: initSet[string](),
                      instaClosable : false)
    tags["span"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : initSet[string](),
                    optionalChilds : initSet[string](),
                    instaClosable  : false)
    tags["title" ] = (requiredAttrs  : initSet[string](),
                      optionalAttrs  : initSet[string](),
                      requiredChilds : initSet[string](),
                      optionalChilds : initSet[string](),
                      instaClosable  : false)


    result = newNimNode(nnkStmtList, params[0])
    result.add(newCall("add", newIdentNode("result"),
                       newStrLitNode("<!DOCTYPE html>\n")))

    var dummyParent = newNimNode(nnkCall, params[0])
    dummyParent.add(newIdentNode("html"))
    var dummyChild = newNimNode(nnkDo, dummyParent)
    for i in 0 .. (params.len - 1):
        dummyChild.add(params[i])
    dummyParent.add(dummyChild)
    processNode(tags, dummyParent, 0, result, blockmode)
    echo "---\n" & treeRepr(result)
