import
    macros, sets, tables, strutils

type
    TTagHandling = tuple[requiredAttrs  : TSet[string],
                         optionalAttrs  : TSet[string],
                         requiredChilds : TSet[string],
                         optionalChilds : TSet[string]]

    TTagList = TTable[string, TTagHandling]

proc processAttribute(tags : TTable[string, TTagHandling], name: string, child: PNimrodNode, target : var PNimrodNode) {.compileTime.} =
    assert(child.kind == nnkExprEqExpr)
    assert(child[0].kind == nnkIdent)
    target.add(newCall("add", newIdentNode("result"), newStrLitNode(" " & $child[0].ident & "=\"")))
    target.add(newCall("add", newIdentNode("result"), copyNimTree(child[1])))
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
    var name: string = $parent[0]
    var childIndex = 1
    echo "processing content:"
    echo treeRepr(parent)

    target.add(newCall("add", newIdentNode("result"), newStrLitNode(repeatChar(4 * depth, ' ') & "<" & name)))

    while childIndex < parent.len and parent[childIndex].kind == nnkExprEqExpr:
        processAttribute(tags, name, parent[childIndex], target)
        inc(childIndex)

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
                    optionalChilds : initSet[string]())
    tags["head"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : toSet[string](["title"]),
                    optionalChilds : initSet[string]())
    tags["body"] = (requiredAttrs  : initSet[string](),
                    optionalAttrs  : initSet[string](),
                    requiredChilds : initSet[string](),
                    optionalChilds : initSet[string]())
    tags["title" ] = (requiredAttrs  : initSet[string](),
                      optionalAttrs  : initSet[string](),
                      requiredChilds : initSet[string](),
                      optionalChilds : initSet[string]())

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