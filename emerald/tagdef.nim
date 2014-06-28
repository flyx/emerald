import
    sets, tables, macros

type
    TContentCategory* = enum
        flow_content, phrasing_content, embedded_content, heading_content,
        sectioning_content, metadata_content, interactive_content,
        text_content, transparent, any_content

    TTagDef* = tuple[contentCategories: set[TContentCategory],
                     permittedContent : set[TContentCategory],
                     forbiddenContent : set[TContentCategory],
                     permittedTags : TSet[string],
                     forbiddenTags : TSet[string],
                     tagOmission   : bool,
                     requiredAttrs : TSet[string],
                     optionalAttrs : TSet[string]]

    TTagList* = TTable[string, TTagDef]
    PTagList* = ref TTagList

proc identName(node: PNimrodNode): string {.compileTime, inline.} =
    case node.kind:
    of nnkAccQuoted:
        return $node[0]
    of nnkIdent:
        return $node
    of nnkPostfix:
        return identName(node[1])
    else:
        quit "Invalid token (expected identifier): " & $node.kind

iterator itemNames(node: PNimrodNode): string {.inline.} =
    case node.kind:
    of nnkIdent, nnkAccQuoted:
        yield identName(node)
    of nnkPar:
        for child in node.children:
            yield identName(child)
    else:
        quit "Unexpected node kind: \"" & $node.kind & "\" (Expected identifier)"

proc parseCategory(node: PNimrodNode): TContentCategory {.compileTime.} =
    assert node.kind == nnkIdent
    case $node:
    of "flow_content": return flow_content
    of "phrasing_content": return phrasing_content
    of "embedded_content": return embedded_content
    of "heading_content": return heading_content
    of "sectioning_content": return sectioning_content
    of "metadata_content": return metadata_content
    of "interactive_content": return interactive_content
    of "text_content": return text_content
    of "any_content": return any_content
    of "transparent": return transparent
    else:
        quit "Unknown content category: " & $node

iterator categories(node: PNimrodNode): TContentCategory {.inline.} =
    case node.kind:
    of nnkIdent:
        yield node.parseCategory
    of nnkPar:
        for child in node.children:
            yield child.parseCategory
    else:
        quit "Unexpected node kind: \"" & $node.kind & "\" (Expected identifier)"

proc setBuilder(typeName, name: string, content: PNimrodNode): PNimrodNode {.compileTime.} =
    result = newNimNode(nnkExprColonExpr)
    result.add(newIdentNode(name))
    var
        call = newNimNode(nnkCall)
        bracketExpr = newNimNode(nnkBracketExpr)
    if content.len == 0:
        bracketExpr.add(newIdentNode("initSet"))
    else:
        bracketExpr.add(newIdentNode("toSet"))
    bracketExpr.add(newIdentNode(typeName))
    call.add(bracketExpr)
    if content.len > 0:
        call.add(content)
    result.add(call)

proc buildSet(name: string, source: TSet[string]): PNimrodNode {.compileTime.} =
    var content: PNimrodNode 
    content = newNimNode(nnkBracket)
    for item in source:
        content.add(newStrLitNode(item))
    return setBuilder("string", name, content)

proc buildSet(name: string, source: set[TContentCategory]): PNimrodNode {.compileTime.} =
    var content = newNimNode(nnkCurly)
    for item in source:
        content.add(newIdentNode($item))
    result = newNimNode(nnkExprColonExpr)
    result.add(newIdentNode(name))
    result.add(content)

macro tagdef*(content: stmt): stmt {.immediate.} =
    ## define a set of tags with this macro. Structure is:
    ##
    ## tagName:
    ##     content_categories: (flow_content, sectioning_content)
    ##     permitted_content: phrasing_content
    ##     tag_omission: false
    ##
    ## All childs are optional. You can define multiple tags at once:
    ##
    ## (h1, h2, h3, h4, h5, h6):
    ##     ...
    ##
    ## You can define global properties at the beginning of your
    ## proc:
    ##
    ## global:
    ##     ...
    ##
    ## This macro is to be used as pragma on a proc returning
    ## a PTagList.

    assert content.kind == nnkProcDef
    let cacheVar = identName(content[0]) & "Cache"

    var
        stmtListIndex =  -1
        i = 0
    for child in content.children:
        if child.kind == nnkStmtList:
            stmtListIndex = i
            break
        inc(i)
    if stmtListIndex < 0:
        quit "Error: empty proc"

    var bodyStmts = newNimNode(nnkStmtList, content[stmtListIndex])

    # we need that at some places
    var derefProto = newNimNode(nnkBracketExpr)
    #derefProto.add(newIdentNode(cacheVar)) # issue 1314
    derefProto.add(newIdentNode("result"))  # do this instead

    # initialize cache variable (we only want to parse stuff once)
    block headers:
        result = newNimNode(nnkStmtList)
        var
            varSection = newNimNode(nnkVarSection)
            identDefs  = newNimNode(nnkIdentDefs)
            pragmaExpr = newNimNode(nnkPragmaExpr)
            pragmaNode = newNimNode(nnkPragma)
        pragmaExpr.add(newIdentNode(cacheVar))
        pragmaNode.add(newIdentNode("compileTime"))
        pragmaExpr.add(pragmaNode)
        #identDefs.add(pragmaExpr) # see below, issue 903
        identDefs.add(newIdentNode(cacheVar))
        #identDefs.add(newIdentNode("PTagList")) # cannot do that due to issue 1314
        identDefs.add(newIdentNode("TTagList"))  # use this instead
        identDefs.add(newNimNode(nnkEmpty))
        varSection.add(identDefs)
        # Doesn't work because of https://github.com/Araq/Nimrod/issues/903
        #result.add(varSection)

        var
            outProc  = copyNimTree(content)
            outStmts = newNimNode(nnkStmtList)

            ifStmt = newNimNode(nnkIfStmt)
            elifBranch = newNimNode(nnkElifBranch)
            bracketExpr = newNimNode(nnkBracketExpr)
        #elifBranch.add(newCall(newIdentNode("isNil"), newIdentNode(cacheVar))) # 1314
        elifBranch.add(newIdentNode("true"))
        elifBranch.add(bodyStmts)
        ifStmt.add(elifBranch)
        outStmts.add(varSection) # see above, issue 903
        outStmts.add(ifStmt)
        #outStmts.add(newAssignment(newIdentNode("result"), newIdentNode(cacheVar))) # issue 1314
        outStmts.add(newAssignment(copyNimTree(derefProto), newIdentNode(cacheVar))) # do this instead
        outProc[stmtListIndex] = outStmts
        result.add(outProc)

        #bodyStmts.add(newCall(newIdentNode("new"), newIdentNode(cacheVar))) # issue 1314
        bodyStmts.add(newCall(newIdentNode("new"), newIdentNode("result")))  # do this instead
        bracketExpr.add(newIdentNode("initTable"))
        bracketExpr.add(newIdentNode("string"))
        bracketExpr.add(newIdentNode("TTagDef"))
        #bodyStmts.add(newAssignment(copyNimTree(derefProto), newCall(bracketExpr))) # issue 1314
        bodyStmts.add(newAssignment(newIdentNode(cacheVar), newCall(bracketExpr)))   # do this instead


    var definedTags: seq[string] = newSeq[string]()
    
    for child in content[stmtListIndex].children:
        if child.kind != nnkCall:
            quit "Unexpected token (expected call): " & $child.kind
        if child[1].kind != nnkDo:
            quit "Unexpected token (expected do): " & $child[1].kind

        var
            tags = initSet[string]()
        for tag in child[0].itemNames:
            if tag in definedTags:
                quit "Error: Tag \"" & tag & "\" defined twice!"
            else:
                definedTags.add(tag)
            tags.incl(tag)
        var
            contentCategories, permittedContent, forbiddenContent : set[TContentCategory] = {}
            requiredAttrs, optionalAttrs, permittedTags, forbiddenTags : TSet[string] = initSet[string]()
            tagOmission: bool = false
        for child1 in child[1].children:
            case child1.kind:
            of nnkEmpty, nnkFormalParams:
                discard
            of nnkStmtList:
                for assign in child1.children:
                    assert assign.kind == nnkAsgn
                    case identName(assign[0]):
                    of "content_categories":
                        for category in assign[1].categories:
                            contentCategories.incl(category)
                    of "permitted_content":
                        for category in assign[1].categories:
                            permittedContent.incl(category)
                    of "forbidden_content":
                        for category in assign[1].categories:
                            forbiddenContent.incl(category)
                    of "permitted_tags":
                        for tag in assign[1].itemNames:
                            permittedTags.incl(tag)
                    of "forbidden_tags":
                        for tag in assign[1].itemNames:
                            forbiddenTags.incl(tag)
                    of "tag_omission":
                        assert assign[1].kind == nnkIdent
                        case $assign[1]:
                        of "true": tagOmission = true
                        of "false": tagOmission = false
                        else: quit "Not a boolean value: " & $assign[1]
                    of "required_attrs":
                        for attr in assign[1].itemNames:
                            requiredAttrs.incl(attr)
                    of "optional_attrs":
                        for attr in assign[1].itemNames:
                            optionalAttrs.incl(attr)
                    else:
                        quit "Unknown key: " & identName(assign[0])
            else:
                quit "Unexpected node type: \"" & $child1.kind & "\""

        for tag in tags:
            var
                assignment = newNimNode(nnkAsgn, child)
                bracketExpr = newNimNode(nnkBracketExpr, child)
                par = newNimNode(nnkPar, child)
            bracketExpr.add(newIdentNode(cacheVar))
            bracketExpr.add(newStrLitNode(tag))
            assignment.add(bracketExpr)

            par.add(buildSet("contentCategories", contentCategories))
            par.add(buildSet("permittedContent", permittedContent))
            par.add(buildSet("forbiddenContent", forbiddenContent))
            par.add(buildSet("permittedTags", permittedTags))
            par.add(buildSet("forbiddenTags", forbiddenTags))
            
            var
                colonExpr = newNimNode(nnkExprColonExpr)
            colonExpr.add(newIdentNode("tagOmission"))
            colonExpr.add(newIdentNode($tagOmission))
            par.add(colonExpr)

            par.add(buildSet("requiredAttrs", requiredAttrs))
            par.add(buildSet("optionalAttrs", optionalAttrs))
            assignment.add(par)
            bodyStmts.add(assignment)

    echo "tags parsed"
