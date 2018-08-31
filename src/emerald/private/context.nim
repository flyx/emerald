{.experimental: "notnil".}
import sets, tagdef, tables, strutils, macros
import writer

type
    TemplateClass* = ref TemplateClassObj
    TemplateClassObj {.acyclic.} = object
        sym: NimNode
        parentClass: TemplateClass
        meths: seq[tuple[name: string, sym: NimNode, context: ParseContext]]
        userParams: NimNode

    OutputMode* = enum
        unknown, blockmode, flowmode
    
    ParseContext* = ref ContextObj not nil
    OptionalParseContext* = ref ContextObj
    
    MixinLevelObj = object
        callbackContent: NimNode
        callable: bool
        callbackCache1, callbackCache2: NimNode
        callContent: seq[tuple[content: NimNode, procSym: NimNode,
                               streamSym: NimNode]]
    
    MixinLevel* = ref MixinLevelObj not nil

    ContextLevel = object
        outputMode: OutputMode
        forbiddenCategories: set[ContentCategory]
        forbiddenTags: set[TagId]
        permitted_content: set[ContentCategory]
        permittedTags: set[TagId]
        indentLength: int
        indentStep: int
        compactOutput: bool
        filters: seq[NimNode]
        preserveWhitespace: bool

    ContextObj = object
        class: TemplateClass
        objName: NimNode
        debugOutput: bool
        globalStmtList: NimNode
        level: int
        levelProps: seq[ContextLevel]
        mixinLevels: seq[MixinLevel]
        isPublic: bool

proc copy*(context: ParseContext): ParseContext {.compileTime.}

proc `mode=`*(context: ParseContext, val: OutputMode) {.inline, compileTime.}

proc newTemplateClass*(sym: NimNode, parent: TemplateClass = nil):
        TemplateClass {.compileTime.} =
    new(result)
    result.sym = sym
    result.parentClass = parent
    result.meths = newSeq[tuple[name: string, sym: NimNode,
                                context: ParseContext]]()
    result.userParams = newNimNode(nnkFormalParams)

proc add_method*(class: TemplateClass, name: string, sym: NimNode,
                 context: ParseContext) {.compileTime.} =
    var copiedContext = context.copy()
    copiedContext.mode = unknown
    class.meths.add((name: name, sym: sym, context: copiedContext))

iterator methods*(class: TemplateClass): 
        tuple[name: string, sym: NimNode, context: ParseContext] =
    for m in class.meths:
        yield m

proc name*(class: TemplateClass): string {.compileTime.} =
    if class.sym.kind == nnkPostfix:
        result = $class.sym[1]
    else:
        result = $class.sym

proc parent*(class: TemplateClass): TemplateClass {.compileTime.} =
    class.parentClass

proc symbol*(class: TemplateClass): NimNode {.compileTime.} = class.sym

template cur_level(): auto {.dirty.} = context.levelProps[context.level]

proc params*(class: TemplateClass): NimNode {.compileTime.} = class.userParams

proc add_param*(class: TemplateClass, param: NimNode) {.compileTime.} =
    class.userParams.add(param)

proc mode*(context: ParseContext): OutputMode {.inline, noSideEffect,
                                                compileTime.} =
    if cur_level.compactOutput: flowmode else: cur_level.outputMode

proc `mode=`*(context: ParseContext, val: OutputMode) =
    cur_level.outputMode = val

proc newMixinLevel*(callbackContent: NimNode): MixinLevel {.compileTime.} =
    new(result)
    result.callbackContent = callbackContent
    result.callable = false

proc newMixinLevel*(callbackContent: NimNode, callbackCache1: NimNode,
                    callbackCache2: NimNode):
        MixinLevel {.compileTime.} =
    new(result)
    result.callbackContent = callbackContent
    result.callable = true
    result.callbackCache1 = callbackCache1
    result.callbackCache2 = callbackCache2
    result.callContent = newSeq[tuple[content: NimNode, procSym: NimNode,
                                      streamSym: NimNode]]()

proc callback_content*(ml: MixinLevel): NimNode {.compileTime.} =
    ml.callbackContent

proc add_call*(ml: MixinLevel, content: NimNode, procSym: NimNode,
               streamSym: NimNode) {.compileTime.} =
    ml.callContent.add((content: content, procSym: procSym,
                        streamSym: streamSym))

iterator call_content_syms*(ml: MixinLevel):
        tuple[content: NimNode, procSym: NimNode, streamSym: NimNode] =
    for sym in ml.callContent:
        yield sym

proc num_calls*(ml: MixinLevel): int {.compileTime.} = ml.callContent.len 

proc callable*(ml: MixinLevel): bool = ml.callable

proc callback_caches*(ml: MixinLevel):
        tuple[cache1: NimNode, cache2: NimNode] {.compileTime.} =
    (cache1: ml.callbackCache1, cache2: ml.callbackCache2)

proc newContext*(globalStmtList: NimNode,
                 class: TemplateClass,
                 objName: NimNode = newEmptyNode(),
                 public: bool = false,
                 primaryTagId : ExtendedTagId = unknownTag,
                 mode: OutputMode = unknown): ParseContext {.compileTime.} =
    new(result)
    result.class = class
    result.objName = objName
    result.debugOutput = false
    result.globalStmtList = globalStmtList
    result.isPublic = public
    result.level = 0
    result.mixinLevels = newSeq[MixinLevel]()
    result.levelProps = @[ContextLevel(
            outputMode : mode,
            forbiddenCategories : set[ContentCategory]({}),
            forbiddenTags : set[TagId]({}),
            permitted_content : set[ContentCategory]({}),
            permittedTags : set[TagId]({}),
            indentLength : 0,
            indentStep : 4,
            compactOutput: false,
            filters: newSeq[NimNode](),
            preserveWhitespace: false
        )]
    if primaryTagId == low(TagId) - 1:
        result.levelProps[0].permitted_content.incl(any_content)
    else:
        result.levelProps[0].permittedTags.incl(TagId(primaryTagId))

proc copy*(context: ParseContext): ParseContext =
    new(result)
    result.class = context.class
    result.objName = context.objName
    result.debugOutput = context.debugOutput
    result.isPublic = context.isPublic
    result.globalStmtList = copyNimTree(context.globalStmtList)
    result.level = context.level
    result.mixinLevels = newSeq[MixinLevel]()
    for ml in context.mixinLevels:
        result.mixinLevels.add(ml)
    result.levelProps = newSeq[ContextLevel]()
    for lp in context.levelProps:
        result.levelProps.add(lp)

proc adapt_to_child_class*(context: ParseContext,
        childContext: ParseContext) {.compileTime.} =
    context.class = childContext.class
    context.globalStmtList = childContext.globalStmtList

proc depth*(context: ParseContext): int {.inline, compileTime.} =
    return context.level - 1

proc enter*(context: ParseContext, tag: TagDef) {.compileTime.} =
    # SIGSEGV! (probably a compiler bug; works at runtime, but not at compiletime)
    #forbiddenTags : context.forbiddenTags + tag.forbiddenTags
    context.levelProps.add(ContextLevel(
            outputMode : if context.mode == flowmode: flowmode else: unknown,
            forbiddenCategories : cur_level.forbiddenCategories,
            forbiddenTags : cur_level.forbiddenTags,
            permittedContent: if tag.permittedContent.contains(transparent):
                curLevel.permitted_content
                else: tag.permitted_content,
            permittedTags : if tag.permitted_content.contains(transparent):
                curLevel.permittedTags
                else: tag.permittedTags,
            indentLength : cur_level.indentLength + cur_level.indentStep,
            indentStep : cur_level.indentStep,
            compactOutput : cur_level.compactOutput,
            filters : cur_level.filters,
            preserveWhitespace: cur_level.preserveWhitespace
        ))
    inc(context.level)

    for i in tag.forbiddenTags:
        cur_level.forbiddenTags.incl(i)
    for i in tag.forbiddenContent: 
        cur_level.forbiddenCategories.incl(i)

proc exit*(context: ParseContext) {.compileTime.} =
    assert context.level > 0
    discard context.levelProps.pop()
    inc(context.level, -1)

proc accepts*(context: ParseContext, tag: TagDef): bool {.compileTime.} =
    result = false
    if cur_level.permitted_content.contains(any_content):
        return true
    if cur_level.forbiddenTags.contains(tag.id): return false
    if cur_level.permittedTags.contains(tag.id):
        result = true
    for category in tag.contentCategories:
        if cur_level.forbiddenCategories.contains(category):
            return false
        if cur_level.permitted_content.contains(category):
            result = true

proc indentation*(context: ParseContext): string {.compileTime.} =
     repeat(' ', curLevel.indentLength)

proc `indent_step=`*(context: ParseContext, val: int) {.compileTime.} =
    curLevel.indentStep = val

proc compact*(context: ParseContext): bool {.compileTime.} =
    curLevel.compactOutput

proc `compact=`*(context: ParseContext, val: bool) {.compileTime.} =
    curLevel.compactOutput = val

proc preserve_whitespace*(context: ParseContext): bool {.compileTime.} =
    curLevel.preserveWhitespace

proc `preserve_whitespace=`*(context: ParseContext, val: bool) {.compileTime.} =
    curLevel.preserveWhitespace = val

proc filters*(context: ParseContext): seq[NimNode] {.compileTime.} =
    curLevel.filters

proc `filters=`*(context: ParseContext, val: seq[NimNode]) {.compileTime.} =
    curLevel.filters = val

proc global_stmt_list*(context: ParseContext): NimNode {.compileTime.} =
    context.globalStmtList

proc push_mixin_level*(context: ParseContext, lev: MixinLevel) {.compileTime.} =
    context.mixinLevels.add(lev)

proc mixin_level*(context: ParseContext): MixinLevel {.compileTime.} =
    context.mixinLevels[context.mixinLevels.len - 1]

proc pop_mixin_level*(context: ParseContext): MixinLevel {.compileTime.} =
    context.mixinLevels.pop()

proc debug*(context: ParseContext): bool {.compileTime.} = context.debugOutput

proc `debug=`*(context: ParseContext, val: bool) {.compileTime.} =
    context.debugOutput = val

proc public*(context: ParseContext): bool {. compileTime.} = context.isPublic

proc global_syms*(context: ParseContext): tuple[class: NimNode, obj: NimNode]
        {.compileTime.} =
    (class: context.class.sym, obj: context.objName)

proc class_instance*(context: ParseContext): NimNode {.compileTime.} =
    context.objName

proc `class_instance=`*(context: ParseContext, val: NimNode) {.compileTime.} =
    context.objName = val

proc cur_class*(context: ParseContext): TemplateClass = context.class

proc `cur_class=`*(context: ParseContext, val: TemplateClass) =
    context.class = val

proc at_root*(context: ParseContext): bool = context.level == 0