{.experimental: "notnil".}
import
    sets, macros, hashes, strutils

const maxTags = 256

type
    ContentCategory* = enum
        flow_content, phrasing_content, embedded_content, heading_content,
        sectioning_content, metadata_content, interactive_content,
        text_content, transparent, any_content

    TagId* = range[1 .. maxTags]
    ExtendedTagId* = range[(int(low(TagId) - 1)) .. int(high(TagId))]

    TagDefObj* = object
        id* : TagId
        content_categories*: set[ContentCategory]
        permitted_content* : set[ContentCategory]
        forbidden_content* : set[ContentCategory]
        permitted_tags* : set[TagId]
        forbidden_tags* : set[TagId]
        tag_omission*   : bool
        required_attrs* : HashSet[string]
        optional_attrs* : HashSet[string]
    TagDef* = ref TagDefObj not nil

const unknownTag* = low(ExtendedTagId)

proc ident_name(node: NimNode): string {.compileTime, inline.} =
    case node.kind:
    of nnkAccQuoted:
        return $node[0]
    of nnkIdent:
        return $node
    of nnkPostfix:
        return ident_name(node[1])
    of nnkStrLit:
        return node.strVal
    else:
        quit "Invalid token (expected identifier): " & $node.kind

proc build_hash_set(name: string, content: NimNode): NimNode {.compileTime.} =
    result = newNimNode(nnkExprColonExpr)
    result.add(newIdentNode(name))
    var
        call = newNimNode(nnkCall)
        bracketExpr = newNimNode(nnkBracketExpr)
    if content.len == 0:
        bracketExpr.add(newIdentNode("initSet"))
    else:
        bracketExpr.add(newIdentNode("toSet"))
    bracketExpr.add(newIdentNode("string"))
    call.add(bracketExpr)
    if content.len > 0:
        call.add(content)
    result.add(call)

proc id(tags: var seq[tuple[name: string, def: bool]], name: string,
              definition: bool = false): int {.compileTime.} =
    result = 1
    for tag in tags:
        if tag.name == name:
            break
        inc(result)
    
    if result > tags.len:
        tags.add((name, definition))
    elif definition:
        if tags[result - 1].def:
            quit "Multiple definitions of tag \"" & name & "\"!"
        tags[result - 1].def = true

macro tag_list*(content: untyped): untyped =
    ## define a set of tags with this macro. Structure is:
    ##
    ## tagName:
    ##     content_categories = (flow_content, sectioning_content)
    ##     permitted_content = phrasing_content
    ##     tag_omission = false
    ##
    ## All childs are optional. You can define multiple tags at once:
    ##
    ## (h1, h2, h3, h4, h5, h6):
    ##     ...
    ##
    ## as TableRefs do not work well with the VM, this code constructs
    ## a number of procs instead:
    ##
    ## proc tag_id_for*(name: string): TagId
    ##
    ## proc tag_def_for*(id: TagId): TagDef
    ##
    ## proc is_global_attr*(name: string): bool
    ##
    ## proc is_bool_attr*(name: string): bool
    ##
    ## proc string_to_prepend*(id: TagId): string
    ##
    ## iterator injected_attrs*(id: TagId): tuple[name: string, val: NimNode]
    
    assert content.kind == nnkStmtList
    assert content.len > 0
    
    var tags = newSeq[tuple[name: string, def: bool]]()
    
    var
        tagIdForCase = newNimNode(nnkCaseStmt).add(
                newNimNode(nnkInfix).add(ident("and"),
                newCall("hashIgnoreCase", ident("name")), newCall("high",
                ident("int32"))))
        tagDefForCase = newNimNode(nnkCaseStmt).add(ident("id"))
        isGlobalAttrCase = newNimNode(nnkCaseStmt).add(ident("name"))
        isBoolAttrCase = newNimNode(nnkCaseStmt).add(ident("name"))
        stringToPrependCase = newNimNode(nnkCaseStmt).add(ident("id"))
        injectedAttrsCase = newNimNode(nnkCaseStmt).add(ident("id"))
    
    # proc definitions
    var
        tagIdFor = newProc(newNimNode(nnkPostfix).add(
                ident("*"), ident("tag_id_for")), [ident("ExtendedTagId"),
                newIdentDefs(ident("name"), ident("string"))],
                body=tagIdForCase)
        tagDefFor = newProc(newNimNode(nnkPostfix).add(
                ident("*"), ident("tag_def_for")), [ident("TagDef"),
                newIdentDefs(ident("id"), ident("TagId"))],
                body=tagDefForCase)
        isGlobalAttr = newProc(newNimNode(nnkPostfix).add(
                ident("*"), ident("is_global_attr")), [ident("bool"),
                newIdentDefs(ident("name"), ident("string"))],
                body=newStmtList())
        isBoolAttr = newProc(newNimNode(nnkPostfix).add(ident("*"),
                ident("is_bool_attr")), [ident("bool"), newIdentDefs(
                ident("name"), ident("string"))], body=newStmtList())
        stringToPrepend = newProc(newNimNode(nnkPostfix).add(ident("*"),
                ident("string_to_prepend")), [ident("string"), newIdentDefs(
                ident("id"), ident("TagId"))], body = newStmtList())
        injectedAttrs = newProc(newNimNode(nnkPostfix).add(ident("*"),
                ident("injected_attrs")), [newNimNode(nnkTupleTy).add(
                newIdentDefs(ident("name"), ident("string")),
                newIdentDefs(ident("val"), ident("NimNode"))),
                newIdentDefs(ident("id"), ident("TagId"))], body = newStmtList(
                ), procType = nnkIteratorDef)
    result = newStmtList(tagIdFor, tagDefFor, isGlobalAttr, isBoolAttr,
            stringToPrepend, injectedAttrs)
    for procdef in result.children:
        if procdef.kind == nnkProcDef:
            procdef[4] = newNimNode(nnkPragma).add(ident("compileTime"))
    
    # process tag definitions
    for child in content.children:
        assert child.kind == nnkCall
        var childrenList: NimNode
        case child[0].kind:
        of nnkPar:
            childrenList = child[0]
        of nnkIdent, nnkAccQuoted:
            childrenList = newNimNode(nnkPar).add(child[0])
        else:
            quit("Invalid child: " & $child[0].kind)
        
        if child[0].kind == nnkIdent and strVal(child[0]) == "global":
            # process global tags, i.e. build is_global_attr and is_bool_attr
            
            for targetChild in child[1].children:
                assert targetChild.kind == nnkAsgn
                case targetChild[0].ident_name
                of "attributes":
                    assert targetChild[1].kind == nnkPar
                    for attribute in targetChild[1].children:
                        isGlobalAttrCase.add(newNimNode(nnkOfBranch).add(
                                newStrLitNode($attribute.ident_name),
                                newAssignment(ident("result"), ident("true"))))
                of "booleans":
                    assert targetChild[1].kind == nnkPar
                    for attribute in targetChild[1].children:
                        isBoolAttrCase.add(newNimNode(nnkOfBranch).add(
                                newStrLitNode($attribute.ident_name),
                                newAssignment(ident("result"), ident("true"))))
                else:
                    quit("Unknown field: " & $targetChild[0].ident_name)
            continue
        
        for definedTag in childrenList.children:
            let
                childName = ident_name(definedTag)
                childHash = hashIgnoreCase(childName) and high(int32)
                tagId = tags.id(childName, true)
        
            block tagIdForProcessing:
                var secondaryCase: NimNode = nil
                for targetChild in tagIdForCase.children:
                    if targetChild.kind == nnkOfBranch:
                        assert targetChild[0].kind == nnkIntLit
                        if targetChild[0].intVal == childHash:
                            assert targetChild[1].kind == nnkStmtList
                            assert targetChild[1][0].kind == nnkCaseStmt
                            secondaryCase = targetChild[1][0]
                            break
                if secondaryCase == nil:
                    secondaryCase = newNimNode(nnkCaseStmt).add(ident("name"))
                    tagIdForCase.add(newNimNode(nnkOfBranch).add(newIntLitNode(
                            childHash), newStmtList(secondaryCase)))
                secondaryCase.add(newNimNode(nnkOfBranch).add(
                        newStrLitNode(childName), newStmtList(
                        newNimNode(nnkReturnStmt).add(newIntLitNode(tagId)))))
        
            block tagDefForProcessing:
                let sym = genSym(nskLet, ":" & childName)
                var content = newNimNode(nnkObjConstr).add(ident("TagDef"))
                content.add(newNimNode(nnkExprColonExpr).add(ident("id"),
                        newIntLitNode(tagId)))
                
                for categorySet in ["content_categories", "permitted_content",
                                    "forbidden_content"]:
                    var valueSet = newNimNode(nnkCurly)
                    for definedProp in child[1].children:
                        if definedProp.kind == nnkAsgn and
                                $definedProp[0].ident_name == categorySet:
                            case definedProp[1].kind:
                            of nnkIdent:
                                valueSet.add(copyNimTree(definedProp[1]))
                            of nnkPar:
                                for name in definedProp[1].children:
                                    valueSet.add(copyNimTree(name))
                            else:
                                quit("Invalid value for $# of $#: $#" %
                                        [categorySet, childName,
                                        $definedProp[1].kind])
                            break
                    content.add(newNimNode(nnkExprColonExpr).add(
                            ident(categorySet), valueSet))
                
                for tagIdSet in ["permitted_tags", "forbidden_tags"]:
                    var valueSet = newNimNode(nnkCurly)
                    for definedProp in child[1].children:
                        if definedProp.kind == nnkAsgn and
                                definedProp[0].ident_name == tagIdSet:
                            case definedProp[1].kind:
                            of nnkIdent:
                                valueSet.add(newCall("TagId",
                                        newIntLitNode(tags.id(
                                        $definedProp[1].ident_name))))
                            of nnkPar:
                                for name in definedProp[1].children:
                                    valueSet.add(newCall("TagId",
                                            newIntLitNode(tags.id(
                                            $name.ident_name))))
                            else:
                                quit("Invalid value for $# of $#: $#" %
                                        [tagIdSet, childName,
                                        $definedProp[1].kind])
                            break
                    content.add(newNimNode(nnkExprColonExpr).add(
                            ident(tagIdSet), valueSet))
                
                for boolVal in ["tag_omission"]:
                    var value: NimNode = nil
                    for definedProp in child[1].children:
                        if definedProp.kind == nnkAsgn and
                                $definedProp[0].ident_name == boolVal:
                            value = copyNimTree(definedProp[1])
                            break
                    if value == nil:
                        value = newIdentNode("false")
                    content.add(newNimNode(nnkExprColonExpr).add(
                            ident(boolVal), value))
                
                for attrSet in ["required_attrs", "optional_attrs"]:
                    var valueSet = newNimNode(nnkBracket)
                    for definedProp in child[1].children:
                        if definedProp.kind == nnkAsgn and
                                $definedProp[0].ident_name == attrSet:
                            case definedProp[1].kind:
                            of nnkIdent:
                                valueSet.add(newStrLitNode(
                                        $definedProp[1].ident_name))
                            of nnkPar:
                                for name in definedProp[1].children:
                                    valueSet.add(newStrLitNode(
                                            $name.ident_name))
                            else:
                                quit("Invalid value for $# of $#: $#" %
                                        [attrSet, childName,
                                        $definedProp[1].kind])
                            break
                    content.add(build_hash_set(attrSet, valueSet))
                
                tagDefForCase.add(newNimNode(nnkOfBranch).add(
                        newIntLitNode(tagId), newStmtList(newNimNode(
                        nnkLetSection).add(newNimNode(nnkIdentDefs).add(
                        sym, newEmptyNode(), content)), newNimNode(
                        nnkReturnStmt).add(sym))))
            
            block processStringToPrepend:
                for definedProp in child[1].children:
                    if definedProp.kind == nnkAsgn and
                            $definedProp[0].ident_name == "prepend":
                        assert definedProp[1].kind == nnkStrLit
                        stringToPrependCase.add(newNimNode(nnkOfBranch).add(
                                newIntLitNode(tagId), newAssignment(
                                ident("result"), definedProp[1])))
            
            block processInjectedAttrs:
                for definedProp in child[1].children:
                    if definedProp.kind == nnkCall and
                            definedProp[0].ident_name == "injected_attrs":
                        assert definedProp[1].kind == nnkStmtList
                        var yields = newStmtList()
                        for attrs in definedProp[1].children:
                            assert attrs.kind == nnkAsgn
                            let val = if attrs[1].kind == nnkStrLit:
                                    newCall("newStrLitNode", attrs[1]) else:
                                    newCall("ident",
                                    newStrLitNode(attrs[1].ident_name))
                            
                            yields.add(newNimNode(nnkYieldStmt).add(
                                    newNimNode(nnkPar).add(newNimNode(
                                    nnkExprColonExpr).add(ident("name"),
                                    newStrLitNode(attrs[0].ident_name)),
                                    newNimNode(nnkExprColonExpr).add(ident(
                                    "val"), val))))
                        injectedAttrsCase.add(newNimNode(nnkOfBranch).add(
                                newIntLitNode(tagId), yields))
    
    # fill case blocks with else branches
    for targetChild in tagIdForCase.children:
        if targetChild.kind == nnkOfBranch:
            assert targetChild[1].kind == nnkStmtList
            assert targetChild[1][0].kind == nnkCaseStmt
            targetChild[1][0].add(newNimNode(nnkElse).add(
                    newNimNode(nnkReturnStmt).add(ident("unknownTag"))))
            
    tagIdForCase.add(newNimNode(nnkElse).add(newNimNode(nnkReturnStmt).add(
            ident("unknownTag"))))
    tagDefForCase.add(newNimNode(nnkElse).add(newCall("quit",
            newStrLitNode("Should never happen"))))
    
    for boolProcs in [(c: isGlobalAttrCase, p: isGlobalAttr),
                      (c: isBoolAttrCase, p: isBoolAttr)]:
        if boolProcs.c.len > 1:
            boolProcs.c.add(newNimNode(nnkElse).add(newAssignment(
                    ident("result"), ident("false"))))
            boolProcs.p[6].add(boolProcs.c)
        else:
            boolProcs.p[6].add(ident("false"))
    
    if stringToPrependCase.len > 1:
        stringToPrependCase.add(newNimNode(nnkElse).add(newAssignment(
                ident("result"), newStrLitNode(""))))
        stringToPrepend[6].add(stringToPrependCase)
    else:
        stringToPrepend[6].add(newStrLitNode(""))
    
    if injectedAttrsCase.len > 1:
        injectedAttrsCase.add(newNimNode(nnkElse).add(newNimNode(
                nnkDiscardStmt).add(newEmptyNode())))
        injectedAttrs[6].add(injectedAttrsCase)
    else:
        injectedAttrs[6].add(newNimNode(nnkDiscardStmt).add(newEmptyNode()))