import sets, "../tagdef"

type
    TOutputMode* = enum
        unknown, blockmode, flowmode

    TContext* = object
        mode*: TOutputMode
        nodeDepth: int
        forbiddenTags: set[TTagId]
        forbiddenCategories: set[TContentCategory]
        permittedTags: set[TTagId]
        permittedContent: set[TContentCategory]

    PContext* = ref TContext

    TExtendedTagId* = range[(int(low(TTagId) - 1)) .. int(high(TTagId))]

proc initContext*(primaryTagId : TExtendedTagId,
                  mode: TOutputMode = unknown, indent: int = -1): PContext =
    new(result)
    result.mode = mode
    result.nodeDepth = indent
    result.forbiddenCategories = {}
    result.forbiddenTags = {}
    result.permittedContent = {}
    result.permittedTags = {}
    if primaryTagId == low(TTagId) - 1:
        result.permittedContent.incl(any_content)
    else:
        result.permittedTags.incl(TTagId(primaryTagId))

proc depth*(context: PContext): int {.inline.} =
    return context.nodeDepth

proc enter*(context: PContext, tag: TTagDef): PContext =
    new(result)
    result.mode = if context.mode == flowmode: flowmode else: unknown
    result.nodeDepth = context.nodeDepth + 1
    #result.forbiddenTags = context.forbiddenTags + tag.forbiddenTags
    result.forbiddenTags = context.forbiddenTags
    for i in tag.forbiddenTags: result.forbiddenTags.incl(i)
    result.forbiddenCategories = context.forbiddenCategories
    for i in tag.forbiddenContent: result.forbiddenCategories.incl(i)
    # SIGSEGV! (probably a compiler bug; works at runtime, but not at compiletime)
    #result.forbiddenCategories = context.forbiddenCategories + tag.forbiddenContent

    if tag.permittedContent.contains(transparent):
        result.permittedContent = context.permittedContent
        result.permittedTags = context.permittedTags
    else:
        result.permittedTags = tag.permittedTags
        result.permittedContent = tag.permittedContent

proc accepts*(context: PContext, tag: TTagDef): bool =
    result = false
    if context.permittedContent.contains(any_content): return true
    if context.forbiddenTags.contains(tag.id): return false
    if context.permittedTags.contains(tag.id): result = true
    for category in tag.contentCategories:
        if context.forbiddenCategories.contains(category):
            return false
        if context.permittedContent.contains(category):
            result = true
    
