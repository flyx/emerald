import macros

macro filter*(stream: stmt, filter: stmt, value: stmt, params: varargs[expr]): expr =
    let call = newCall(filter, value)
    for i in 0 .. params.len - 1:
        call.add(params[i])
    if value.kind == nnkStrLit or value.kind == nnkTripleStrLit:
        let stringSym = genSym(nskVar)
        var compileTimeCall = newCall(filter, newCall("addr", stringSym), value)
        for i in 0 .. params.len - 1:
            compileTimeCall.add(params[i])

        newStmtList(
            newNimNode(nnkStaticStmt).add(newStmtList(
                newNimNode(nnkVarSection).add(newIdentDefs(stringSym, newEmptyNode(), newStrLitNode(""))),
                compileTimeCall
            )),
            newNimNode(nnkConstSection).add(
                newNimNode(nnkConstDef).add(newIdentNode("filtered"), newEmptyNode(),
                       stringSym)),
            newCall("write", stream, ident("filtered"))
        )
    else:
        var runtimeCall = newCall(filter, stream, value)
        for i in 0 .. params.len - 1:
            runtimeCall.add(params[i])
        runtimeCall