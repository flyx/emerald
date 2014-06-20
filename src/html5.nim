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

proc processAttribute(tags : TTable[string, TTagHandling],
                      name : string, value: PNimrodNode, target : var PNimrodNode) {.compileTime.} =
    target.add(newCall("add", newIdentNode("result"), newStrLitNode(" " & name & "=\"")))
    target.add(newCall("add", newIdentNode("result"), copyNimTree(value)))
    target.add(newCall("add", newIdentNode("result"), newStrLitNode("\"")))

proc processNode(tags: TTable[string, TTagHandling], parent: PNimrodNode, depth: int, target : var PNimrodNode) {.compileTime.}

proc processChilds(tags: TTable[string, TTagHandling], node: string,
                   parent: PNimrodNode, depth: int, target : var PNimrodNode,
                   mode  : var TOutputMode) {.compileTime.} =
    for child in parent.children:
        case child.kind:
        of nnkEmpty, nnkFormalParams:
            continue
        of nnkCall:
            if mode == unknown:
                mode = blockmode
                target.add(newCall("add", newIdentNode("result"), newStrLitNode("\n")))
            processNode(tags, child, if mode == blockMode: depth + 1 else: 0, target)
        of nnkStmtList:
            processChilds(tags, node, child, depth, target, mode)
        of nnkStrLit, nnkInfix:
            if mode == unknown:
                mode = flowmode
            target.add(newCall("add", newIdentNode("result"), copyNimTree(child)))
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
                    processChilds(tags, node, ifBranch[1], depth, ifContent, mode)
                    ifCond.add(ifContent)
                    ifNode.add(ifCond)
                of nnkElse:
                    var elseContent = newNimNode(nnkStmtList, ifBranch)
                    processChilds(tags, node, ifBranch[0], depth, elseContent, mode)
                    ifNode.add(elseContent)
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
    if node.kind == nnkAccQuoted:
        return $node[0]
    else:
        return $node

proc processNode(tags: TTable[string, TTagHandling], parent: PNimrodNode, depth: int, target : var PNimrodNode) =
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

    echo "processing content:"
    echo treeRepr(parent)

    target.add(newCall("add", newIdentNode("result"), newStrLitNode(repeatChar(4 * depth, ' ') & "<" & name)))

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
        target.add(newCall("add", newIdentNode("result"), newStrLitNode(" class=\"" & classString & "\"")))

    while childIndex < parent.len and parent[childIndex].kind == nnkExprEqExpr:
        assert(parent[childIndex][0].kind == nnkIdent)
        let childName = $parent[childIndex][0].ident
        if not (childName in globalAttributes or
                childName in tagProps.requiredAttrs or
                childName in tagProps.optionalAttrs):
            quit "Attribute \"" & childName & "\" not allowed in tag \"" & name & "\""
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
        quit "The following mandatory attributes are missing on tag \"" & name & "\": " & msg

    target.add(newCall("add", newIdentNode("result"), newStrLitNode(">")))

    var mode: TOutputMode = unknown

    processChilds(tags, name, parent[childIndex], depth, target, mode)
    if mode == blockmode:
        target.add(newCall("add", newIdentNode("result"), newStrLitNode("\n" & repeatChar(4 * depth, ' ') & "</" & name & ">\n")))
    else:
        target.add(newCall("add", newIdentNode("result"), newStrLitNode("</" & name & ">")))
    echo "---"


macro html5*(params : openarray[stmt]): stmt {.immediate.} =
    var
        tags : TTagList = initTable[string, TTagHandling]()
    tags["html"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : toSet[string](["head", "body"]),
                    optionalChilds : initSet[string](),
                    instaClosable  : false)
    tags["head"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : toSet[string](["title"]),
                    optionalChilds : initSet[string](),
                    instaClosable  : false)
    tags["body"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : initSet[string](),
                    optionalChilds : initSet[string](),
                    instaClosable  : false)
    tags["title" ] = (requiredAttrs  : initSet[string](),
                      optionalAttrs  : initSet[string](),
                      requiredChilds : initSet[string](),
                      optionalChilds : initSet[string](),
                      instaClosable  : false)
    tags["div"] = (requiredAttrs  : initSet[string](),
                   optionalAttrs  : initSet[string](),
                   requiredChilds : initSet[string](),
                   optionalChilds : initSet[string](),
                   instaClosable  : false)

    result = newNimNode(nnkStmtList, params[0])
    result.add(newCall("add", newIdentNode("result"), newStrLitNode("<!doctype html>\n")))

    var dummyParent = newNimNode(nnkCall, params[0])
    dummyParent.add(newIdentNode("html"))
    var dummyChild = newNimNode(nnkDo, dummyParent)
    for i in 0 .. (params.len - 1):
        dummyChild.add(params[i])
    dummyParent.add(dummyChild)
    processNode(tags, dummyParent, 0, result)


proc test(): string =
    result = ""
    var foobar = "herpderp"
    var bla = 3
    html5:
        head (id = "head"):
            title: "bar"
        body.main (id = foobar):
            "foo" & "foo"
            if bla > 3:
                "bar"
            else:
                "bra"
            var blubb = 13
            for i in 1..5:
                "n"
            `div`:
                "mi"

echo test()