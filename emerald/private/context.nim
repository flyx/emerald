import sets, "../tagdef", tables

type
    TOutputMode* = enum
        unknown, blockmode, flowmode

    TContextLevel = tuple
        outputMode: TOutputMode
        forbiddenCategories: set[TContentCategory]
        forbiddenTags: set[TTagId]
        permittedContent: set[TContentCategory]
        permittedTags: set[TTagId]

    TContext = object
        definedBlocks: TTable[string, PNimrodNode]
        tagList: PTagList
        level: int
        levelProps: seq[TContextLevel]

        

    PContext* = ref TContext

    TExtendedTagId* = range[(int(low(TTagId) - 1)) .. int(high(TTagId))]

template curLevel(): auto {.dirty.} = context.levelProps[context.level]

proc tags*(context: PContext): PTagList {.inline, noSideEffect, compileTime.} =
    context.tagList

proc mode*(context: PContext): TOutputMode {.inline, noSideEffect, compileTime.} =
    curLevel.outputMode

proc `mode=`*(context: PContext, val: TOutputMode) {.inline, compileTime.} =
    curLevel.outputMode = val

proc newContext*(tags: PTagList, primaryTagId : TExtendedTagId,
                 mode: TOutputMode = unknown): PContext {.compileTime.} =
    new(result)
    result.definedBlocks = initTable[string, PNimrodNode]()
    result.tagList = tags
    result.level = 0
    result.levelProps = @[(
            outputMode : mode,
            forbiddenCategories : set[TContentCategory]({}),
            forbiddenTags : set[TTagId]({}),
            permittedContent : set[TContentCategory]({}),
            permittedTags : set[TTagId]({})
        )]
    if primaryTagId == low(TTagId) - 1:
        result.levelProps[0].permittedContent.incl(any_content)
    else:
        result.levelProps[0].permittedTags.incl(TTagId(primaryTagId))

proc depth*(context: PContext): int {.inline, compileTime.} =
    return context.level - 1

proc enter*(context: PContext, tag: PTagDef) {.compileTime.} =
    # SIGSEGV! (probably a compiler bug; works at runtime, but not at compiletime)
    #forbiddenTags : context.forbiddenTags + tag.forbiddenTags
    context.levelProps.add((
            outputMode : if context.mode == flowmode: flowmode else: unknown,
            forbiddenCategories : curLevel.forbiddenCategories,
            forbiddenTags : curLevel.forbiddenTags,
            permittedContent: if tag.permittedContent.contains(transparent):
                curLevel.permittedContent
                else: tag.permittedContent,
            permittedTags : if tag.permittedContent.contains(transparent):
                curLevel.permittedTags
                else: tag.permittedTags
        ))
    inc(context.level)

    for i in tag.forbiddenTags:
        curLevel.forbiddenTags.incl(i)
    for i in tag.forbiddenContent: 
        curLevel.forbiddenCategories.incl(i)

proc exit*(context: PContext) {.compileTime.} =
    assert context.level > 0
    discard context.levelProps.pop()
    inc(context.level, -1)

proc accepts*(context: PContext, tag: PTagDef): bool {.compileTime.} =
    result = false
    if curLevel.permittedContent.contains(any_content):
        return true
    if curLevel.forbiddenTags.contains(tag.id): return false
    if curLevel.permittedTags.contains(tag.id): result = true
    for category in tag.contentCategories:
        if curLevel.forbiddenCategories.contains(category):
            return false
        if curLevel.permittedContent.contains(category):
            result = true

proc addBlock*(context: PContext, name: string, stmts: PNimrodNode) {.inline, compileTime.} =
    context.definedBlocks[name] = stmts

proc hasBlocks*(context: PContext): bool {.inline, compileTime.} =
    return context.definedBlocks.len > 0

iterator blocks*(context: PContext): tuple[key: string, val: PNimrodNode] {.inline.} =
    for b in context.definedBlocks.pairs:
        yield b