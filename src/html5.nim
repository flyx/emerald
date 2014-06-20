import
    macros, sets, tables, strutils

type
    TTagHandling = tuple[requiredAttrs  : TSet[string],
                         optionalAttrs  : TSet[string],
                         requiredChilds : TSet[string],
                         optionalChilds : TSet[string],
                         instaClosable  : bool]

    TTagList = TTable[string, TTagHandling]

proc processAttribute(tags : TTable[string, TTagHandling],
                      name : string, value: PNimrodNode, target : var PNimrodNode) {.compileTime.} =
    target.add(newCall("add", newIdentNode("result"), newStrLitNode(" " & name & "=\"")))
    target.add(newCall("add", newIdentNode("result"), copyNimTree(value)))
    target.add(newCall("add", newIdentNode("result"), newStrLitNode("\"")))

proc processNode(tags: TTable[string, TTagHandling], parent: PNimrodNode, depth: int, target : var PNimrodNode) {.compileTime.}

proc processChilds(tags: TTable[string, TTagHandling], node: string, parent: PNimrodNode, depth: int, target : var PNimrodNode): bool {.compileTime.} =
    type TOutputMode = enum
        unknown, blockmode, flowmode

    var
        required: TTable[string, bool] = initTable[string, bool]()
        optional: TSet[string]
        mode : TOutputMode = unknown
    
    if not tags.hasKey(node):
        quit "Unknown tag: \"" & node & "\""
    for reqEntry in tags[node].requiredChilds:
        required[reqEntry] = false
    optional = tags[node].optionalChilds

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
            for statement in child.children:
                case statement.kind:
                of nnkStrLit:
                    if mode == unknown:
                        mode = flowmode
                    target.add(newCall("add", newIdentNode("result"), newStrLitNode(statement.strVal)))
                of nnkCall:
                    if mode == unknown:
                        mode = blockmode
                        target.add(newCall("add", newIdentNode("result"), newStrLitNode("\n")))
                    processNode(tags, statement, if mode == blockMode: depth + 1 else: 0, target)
                else:
                    quit "Unexpected node type (" & $statement.kind & ")"
        else:
            quit "Unexpected node type (" & $child.kind & ")"
    return mode == blockmode

proc processNode(tags: TTable[string, TTagHandling], parent: PNimrodNode, depth: int, target : var PNimrodNode) =
    let
        globalAttributes : TSet[string] = toSet([
                "acceskey", "contenteditable", "contextmenu", "dir",
                "draggable", "dropzone", "hidden", "id", "itemid",
                "itemprop", "itemref", "itemscope", "itemtype",
                "lang", "spellcheck", "style", "tabindex", "title"])
        name: string = $parent[0]
        tagProps = tags[name]

    var
        childIndex = 1
        parsedAttributes : TSet[string] = initSet[string]()

    echo "processing content:"
    echo treeRepr(parent)

    target.add(newCall("add", newIdentNode("result"), newStrLitNode(repeatChar(4 * depth, ' ') & "<" & name)))

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

    if processChilds(tags, name, parent[childIndex], depth, target):
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
    html5:
        head (id = "head"):
            title: "bar"
        body (id = foobar):
            "foo"

echo test()