import lexbase, streams, strutils, tables, json, sequtils, os

type
  WhitespaceKind {.pure.} = enum
    none, minor, major
  
  ContentKind {.pure.} = enum
    boolean, text, call, concat, list
  
  Param = object
    name: string
    value: Content
  
  Content = ref object
    case kind: ContentKind
    of ContentKind.boolean:
      boolVal: bool
    of ContentKind.text:
      textContent: string
    of ContentKind.call:
      name: string
      params: seq[Param]
      sections: seq[Content]
    of ContentKind.concat:
      values: seq[tuple[whitespace: bool, node: Content]]
    of ContentKind.list:
      items: seq[Content]
  
  SymbolKind {.pure.} = enum
    emerald, injected
    
  InjectedSymbol = proc(context: Context): Content

  ParamKind {.pure.} = enum
    atom, list, listCollector, mapCollector, varDef, section

  ParamDef = object
    kind: ParamKind
    name: string
    default: Content

  Symbol = ref object
    params: seq[ParamDef]
    case kind: SymbolKind
    of SymbolKind.emerald:
      content: Content
    of SymbolKind.injected:
      impl: InjectedSymbol
  
  EnclosedProc = ref object
    opening: string
    closing: string
    param: string
    impl: Content
  
  ItemizeProc = ref object
    bullet: string
    param: string
    itemImpl: Content
    enclosingImpl: Content

  Filter = ref object
    param: string
    impl: Content
  
  Context = ref object
    symbols: Table[string, Symbol]
    whitespaceProcessing: bool
    emeraldChar: char
    parent: Context
    enclosed: seq[EnclosedProc]
    itemized: seq[ItemizeProc]
    filter: Filter

  BulletItem = object
    markup: string
    indent: int

  Interpreter = ref object
    lex: BaseLexer
    indent: seq[int]
    curIndent: int
    curWhitespace: WhitespaceKind
    curMarkupSequence: string
    expectedClosing: seq[string]
    curBulletItems: seq[BulletItem]

const markupSymbols = {'!', '\"', '#', '$', '%', '&', '\'', '(', ')', '*', '+',
                       '-', ',', '.', '/', ':', ';', '<', '>', '=', '?', '@',
                       '[', ']', '^', '_', '`', '{', '|', '}', '~'}

proc toString(val: Content, indent: int): string
  
proc toString(val: Param, indent: int): string =
  result = repeat(' ', indent)
  if isNil(val.name):
    result.add("param:\n")
  else:
    result.add("param(" & val.name & "):\n")
  result.add(toString(val.value, indent + 2))

proc toString(val: Content, indent: int): string =
  result = repeat(' ', indent)
  case val.kind
  of ContentKind.boolean:
    result.add("bool: " & $val.boolVal & "\n")
  of ContentKind.text:
    result.add("text:\n" &
        repeat(' ', indent + 2) & '\"' & val.textContent & "\"\n")
  of ContentKind.call:
    result.add("call(" & val.name & "):\n")
    for param in val.params:
      result.add(toString(param, indent + 2))
    for section in val.sections:
      result.add(repeat(' ', indent + 2) & "section:\n")
      result.add(toString(section, indent + 4))
  of ContentKind.concat:
    result.add("concat:\n")
    for value in val.values:
      result.add(toString(value.node, indent + 2))
  of ContentKind.list:
    result.add("list:\n")
    for item in val.items:
      result.add(toString(item, indent + 2))
    
proc `$`*(val: Content): string = val.toString(0)

proc newText(content: string = ""): Content =
  Content(kind: ContentKind.text, textContent: content)

proc addListItem(o: Content, item: Content) =
  assert o.kind == ContentKind.list
  if item.kind notin {ContentKind.list, ContentKind.concat} or
      (item.kind == ContentKind.list and item.items.len > 0) or
      (item.kind == ContentKind.concat and item.values.len > 0):
    o.items.add(item)

proc addConcatItem(o: Content, whitespace: bool, item: Content) =
  assert o.kind == ContentKind.concat
  if item.kind notin {ContentKind.list, ContentKind.concat} or
      (item.kind == ContentKind.list and item.items.len > 0) or
      (item.kind == ContentKind.concat and item.values.len > 0):
    o.values.add((whitespace: whitespace, node: item))
  else:
    echo "discarding ", item.kind

proc newList(items: seq[Content] = newSeq[Content]()): Content =
  result = Content(kind: ContentKind.list, items: newSeq[Content]())
  for item in items:
    result.addListItem(item)

proc newConcat(first: Content = nil): Content =
  result = Content(kind: ContentKind.concat,
                   values: newSeq[tuple[whitespace: bool, node: Content]]())
  if first != nil:
    result.addConcatItem(false, first)

proc newSymbol(content: Content): Symbol =
  Symbol(params: newSeq[ParamDef](), kind: SymbolKind.emerald, content: content)

proc childContext(source: Context): Context =
  Context(symbols: initTable[string, Symbol](),
          whitespaceProcessing: source.whitespaceProcessing,
          emeraldChar: source.emeraldChar, parent: source,
          enclosed: newSeq[EnclosedProc](),
          itemized: newSeq[ItemizeProc]())

proc indentation(lex: var BaseLexer): int =
  result = 0
  while lex.buf[lex.bufpos] == ' ':
    inc(result)
    inc(lex.bufpos)

proc findContentStart(lex: var BaseLexer): int =
  result = lex.indentation()
  while true:
    case lex.buf[lex.bufpos]
    of '\l': lex.bufpos = lex.handleLF(lex.bufpos)
    of '\c': lex.bufpos = lex.handleCR(lex.bufpos)
    else: break
    result = lex.indentation()

proc skipWhitespace(lex: var BaseLexer) =
  while true:
    case lex.buf[lex.bufpos]
    of ' ', '\t': inc(lex.bufpos)
    of '\l': lex.bufpos = lex.handleLF(lex.bufpos)
    of '\c': lex.bufpos = lex.handleCR(lex.bufpos)
    else: break

proc processString(lex: var BaseLexer): Content =
  assert lex.buf[lex.bufpos] == '\"'
  result = Content(kind: ContentKind.text, textContent: "")
  inc(lex.bufpos)
  while lex.buf[lex.bufpos] notin {'\l', '\c', EndOfFile, '\"'}:
    result.textContent.add(lex.buf[lex.bufpos])
    inc(lex.bufpos)
  if lex.buf[lex.bufpos] != '\"':
    raise newException(Exception, "Unclosed string")

proc processSection(iprt: var Interpreter, context: Context): Content

proc executeCall(call: Content, context: Context): Content

proc processCall(iprt: var Interpreter, context: Context): Content

proc callItem(lex: var BaseLexer): string =
  result = ""
  while true:
    while lex.buf[lex.bufpos] notin
        {',', '=', ')', ' ', '\t', '\l', '\c', EndOfFile}:
      result.add(lex.buf[lex.bufpos])
      inc(lex.bufpos)
    var whitespace = false
    while lex.buf[lex.bufpos] in {' ', '\t'}:
      whitespace = true
      inc(lex.bufpos)
    if lex.buf[lex.bufpos] in {'\l', '\c', '=', ',', ')', EndOfFile}:
      break
    if whitespace: result.add(' ')

proc processCallParams(iprt: var Interpreter, params: var seq[Param],
                       context: Context) =
  assert iprt.lex.buf[iprt.lex.bufpos] == '('
  inc(iprt.lex.bufpos)
  iprt.lex.skipWhitespace()
  if iprt.lex.buf[iprt.lex.bufpos] == ')': return
  while true:
    var paramName: string = nil
    var itemName: string = nil
    if iprt.lex.buf[iprt.lex.bufpos] != context.emeraldChar:
      itemName = iprt.lex.callItem()
      if iprt.lex.buf[iprt.lex.bufpos] == '=':
        if itemName.len == 0:
          raise newException(Exception, "Missing parameter name in front of '='")
        paramName = itemName
        itemName = nil
        inc(iprt.lex.bufpos)
        iprt.lex.skipWhitespace()
        if iprt.lex.buf[iprt.lex.bufpos] != context.emeraldChar:
          itemName = iprt.lex.callItem()
    if isNil(itemName):
      params.add(Param(name: paramName, value:
          executeCall(iprt.processCall(context), context)))
    else:
      params.add(Param(name: paramName, value:
          Content(kind: ContentKind.text, textContent: itemName)))
    if iprt.lex.buf[iprt.lex.bufpos] notin {',', ')'}:
      raise newException(Exception,
          "Invalid content: '" & iprt.lex.buf[iprt.lex.bufpos] & "'")
    if iprt.lex.buf[iprt.lex.bufpos] == ')': break
    inc(iprt.lex.bufpos)
    iprt.lex.skipWhitespace()

proc skipUntilNextContent(iprt: var Interpreter, firstLinebreakIsMajor: bool) =
  while iprt.lex.buf[iprt.lex.bufpos] in {' ', '\t'}:
    iprt.curWhitespace = WhitespaceKind.minor
    inc(iprt.lex.bufpos)
  var firstLinebreak = not firstLinebreakIsMajor
  while true:
    case iprt.lex.buf[iprt.lex.bufpos]
    of '\l': iprt.lex.bufpos = iprt.lex.handleLF(iprt.lex.bufpos)
    of '\c': iprt.lex.bufpos = iprt.lex.handleCR(iprt.lex.bufpos)
    else: break
    if firstLinebreak:
      iprt.curWhitespace = WhitespaceKind.minor
      firstLinebreak = false
    else:
      iprt.curWhitespace = WhitespaceKind.major
    iprt.curIndent = iprt.lex.indentation()

proc execute(subject: Content, context: Context): Content =
  result = newList()
  case subject.kind
  of ContentKind.text, ContentKind.boolean:
    result.items.add(subject)
  of ContentKind.call:
    result.addListItem(executeCall(subject, context))
  of ContentKind.concat:
    var target = newConcat()
    for value in subject.values:
      target.addConcatItem(value.whitespace, execute(value.node, context))
    result.addListItem(target)
  of ContentKind.list:
    var target = newList()
    for item in subject.items:
      target.addListItem(execute(item, context))
    result.addListItem(target)
  if result.items.len == 1:
    result = result.items[0]

proc executeCall(call: Content, context: Context): Content =
  assert call.kind == ContentKind.call
  var curContext = context
  var sym: Symbol
  while true:
    try:
      sym = curContext.symbols[call.name]
      break
    except KeyError:
      if curContext.parent == nil:
        return call
      curContext = curContext.parent
    
  # map parameters and setup context
  var callContext = childContext(context)
  
  if sym.params.len == 0:
    if call.params.len > 0:
      raise newException(Exception, "Call takes no parameters")
  else:
    var
      paramMapping = repeat(-1, sym.params.len)
      paramIndex = 0
      listParams = newSeq[int]()
      mapParams = newSeq[int]()
    for i in 0..call.params.high:
      block searchParam:
        if not isNil(call.params[i].name):
          block searchNamedParam:
            for j in 0..sym.params.high:
              if sym.params[j].name == call.params[i].name:
                paramMapping[j] = i
                if j == paramIndex: break searchNamedParam
                else: break searchParam
            mapParams.add(i)
        elif paramIndex > paramMapping.high:
          listParams.add(i)
        else:
          paramMapping[paramIndex] = i
        while paramIndex < paramMapping.high and (
            paramMapping[paramIndex] != -1 or
            sym.params[paramIndex].kind in
                {ParamKind.listCollector, ParamKind.mapCollector}):
          inc(paramIndex)
    for i in 0 .. call.sections.high:
      block searchSectionParam:
        for j in 0 .. sym.params.high:
          if sym.params[j].kind == ParamKind.section and paramMapping[j] == -1:
            paramMapping[j] = -2 - i
            break searchSectionParam
        raise newException(Exception, "Cannot map section to a parameter")
    for i in 0 .. paramMapping.high:
      if paramMapping[i] == -1:
        case sym.params[i].kind
        of ParamKind.listCollector:
          var collectedList = newList()
          for j in listParams:
            let value = call.params[j].value
            if value.kind == ContentKind.call:
              collectedList.addListItem(executeCall(value, context))
            else:
              collectedList.addListItem(value)
          callContext.symbols[sym.params[i].name] = newSymbol(collectedList)
          listParams.setLen(0)
        of ParamKind.mapCollector:
          var collectedMap = newList()
          for j in mapParams:
            let value = call.params[j].value
            var pair = newList(@[newText(call.params[j].name)])
            if value.kind == ContentKind.call:
              pair.items.add(executeCall(value, context))
            else:
              pair.items.add(value)
            collectedMap.items.add(pair)
          callContext.symbols[sym.params[i].name] = Symbol(
              kind: SymbolKind.emerald, params: newSeq[ParamDef](),
              content: collectedMap)
          mapParams.setLen(0)
        of ParamKind.atom, ParamKind.list, ParamKind.section:
          if sym.params[i].default == nil:
            raise newException(Exception,
                "Missing required parameter: " & sym.params[i].name)
          else:
            assert sym.params[i].default.kind == ContentKind.text
            callContext.symbols[sym.params[i].name] =
                Symbol(kind: SymbolKind.emerald, params: newSeq[ParamDef](),
                       content: sym.params[i].default)
        of ParamKind.varDef:
          raise newException(Exception,
              "Missing required parameter: " & sym.params[i].name)
      elif paramMapping[i] <= -2:
        callContext.symbols[sym.params[i].name] =
            Symbol(kind: SymbolKind.emerald, params: newSeq[ParamDef](),
                   content: call.sections[paramMapping[i] * -1 - 2])
      else:
        var node: Content
        let param = call.params[paramMapping[i]].value
        case sym.params[i].kind
        of ParamKind.atom:
          if param.kind == ContentKind.call:
            node = executeCall(param, context)
          else:
            node = param
        of ParamKind.list, ParamKind.section:
          if param.kind == ContentKind.call:
            node = executeCall(param, context)
          else:
            node = param
          if node.kind == ContentKind.text:
            raise newException(Exception, "Expected list as param value")
        of ParamKind.varDef:
          if param.kind != ContentKind.call:
            raise newException(Exception, "Expected a call for " & 
                sym.params[i].name)
          elif param.params.len + param.sections.len != 0:
            raise newException(Exception, "Expected a call without params")
          node = param
        else: assert false
        callContext.symbols[sym.params[i].name] =
            Symbol(kind: SymbolKind.emerald, params: newSeq[ParamDef](),
                   content: node)
    if listParams.len + mapParams.len != 0:
      raise newException(Exception, "Unknown parameter(s)!")

  # execute call
  if sym.kind == SymbolKind.emerald:
    result = execute(sym.content, callContext)
  else:
    result = sym.impl(callContext)
  

proc processCall(iprt: var Interpreter, context: Context): Content =
  assert iprt.lex.buf[iprt.lex.bufpos] == context.emeraldChar
  result = Content(kind: ContentKind.call, name: "",
                   params: newSeq[Param](), sections: newSeq[Content]())
  iprt.curWhitespace = WhitespaceKind.none
  inc(iprt.lex.bufpos)
  while iprt.lex.buf[iprt.lex.bufpos] in {'A'..'Z', 'a'..'z'}:
    result.name.add(iprt.lex.buf[iprt.lex.bufpos])
    inc(iprt.lex.bufpos)
  if result.name.len == 0:
    raise newException(Exception, "Missing call name")
  while iprt.lex.buf[iprt.lex.bufpos] in {' ', '\t'}:
    iprt.curWhitespace = WhitespaceKind.minor
    inc(iprt.lex.bufpos)
  if iprt.lex.buf[iprt.lex.bufpos] == '(':
    iprt.curWhitespace = WhitespaceKind.none
    iprt.processCallParams(result.params, context)
    inc(iprt.lex.bufpos)
    while iprt.lex.buf[iprt.lex.bufpos] in {' ', '\t'}:
      iprt.curWhitespace = WhitespaceKind.minor
      inc(iprt.lex.bufpos)
  if iprt.lex.buf[iprt.lex.bufpos] != ':':
    iprt.skipUntilNextContent(false)
  while iprt.lex.buf[iprt.lex.bufpos] == ':':
    iprt.curWhitespace = WhitespaceKind.none
    inc(iprt.lex.bufpos)
    iprt.skipUntilNextContent(true)
    if iprt.curWhitespace != WhitespaceKind.major:
      raise newException(Exception, "No content allowed in line after ':'")
    if iprt.curIndent <= iprt.indent[iprt.indent.high]:
      raise newException(Exception, "Missing section content")
    iprt.indent.add(iprt.curIndent)
    iprt.curWhitespace = WhitespaceKind.none
    result.sections.add(iprt.processSection(childContext(context)))
    discard iprt.indent.pop()
    
proc processText(iprt: var Interpreter, context: Context): Content =
  result = newText("")
  iprt.curWhitespace = WhitespaceKind.none
  while true:
    while iprt.lex.buf[iprt.lex.bufpos] notin
        {' ', '\t', '\l', '\c', EndOfFile, context.emeraldChar}:
      if iprt.lex.buf[iprt.lex.bufpos] in markupSymbols:
        iprt.curMarkupSequence.add(iprt.lex.buf[iprt.lex.bufpos])
        inc(iprt.lex.bufpos)
        if iprt.expectedClosing.len > 0 and iprt.curMarkupSequence ==
            iprt.expectedClosing[iprt.expectedClosing.high]:
          return result
        while iprt.lex.buf[iprt.lex.bufpos] in markupSymbols:
          iprt.curMarkupSequence.add(iprt.lex.buf[iprt.lex.bufpos])
          inc(iprt.lex.bufpos)
          if iprt.expectedClosing.len > 0 and iprt.curMarkupSequence ==
              iprt.expectedClosing[iprt.expectedClosing.high]:
            return result
        for itemized in context.itemized:
          if iprt.curMarkupSequence == itemized.bullet:
            return result
        for enclosed in context.enclosed:
          if iprt.curMarkupSequence == enclosed.opening:
            return result
        result.textContent.add(iprt.curMarkupSequence)
        iprt.curMarkupSequence.setLen(0)
      else:
        result.textContent.add(iprt.lex.buf[iprt.lex.bufpos])
        inc(iprt.lex.bufpos)
    while iprt.lex.buf[iprt.lex.bufpos] in {' ', '\t'}:
      iprt.curWhitespace = WhitespaceKind.minor
      inc(iprt.lex.bufpos)
    case iprt.lex.buf[iprt.lex.bufpos]
    of EndOfFile: break
    of '\l':
      iprt.lex.bufpos = iprt.lex.handleLF(iprt.lex.bufpos)
    of '\c':
      iprt.lex.bufpos = iprt.lex.handleCR(iprt.lex.bufpos)
    else:
      if iprt.lex.buf[iprt.lex.bufpos] == context.emeraldChar: break
      if iprt.curWhitespace == WhitespaceKind.minor:
        result.textContent.add(' ')
        iprt.curWhitespace = WhitespaceKind.none
      continue
    iprt.curWhitespace = WhitespaceKind.minor
    iprt.curIndent = iprt.lex.indentation()
    while true:
      case iprt.lex.buf[iprt.lex.bufpos]
      of '\l':
        iprt.curWhitespace = WhitespaceKind.major
        iprt.lex.bufpos = iprt.lex.handleLF(iprt.lex.bufpos)
      of '\c':
        iprt.curWhitespace = WhitespaceKind.major
        iprt.lex.bufpos = iprt.lex.handleCR(iprt.lex.bufpos)
      else: break
      iprt.curIndent = iprt.lex.indentation()
    if iprt.lex.buf[iprt.lex.bufpos] in {context.emeraldChar, EndOfFile} or
        iprt.curIndent < iprt.indent[iprt.indent.high] or
        iprt.curWhitespace == WhitespaceKind.major: break
    result.textContent.add(' ')
  if context.filter != nil:
    var filterContext = childContext(context)
    filterContext.symbols[context.filter.param] = newSymbol(result)
    result = execute(context.filter.impl, filterContext)

proc processSection(iprt: var Interpreter, context: Context): Content =
  result = newList()
  var current: Content
  while iprt.curIndent >= iprt.indent[iprt.indent.high] and
      (iprt.curBulletItems.len == 0 or
       iprt.curIndent >= iprt.curBulletItems[iprt.curBulletItems.high].indent):
    if iprt.curWhitespace == WhitespaceKind.major:
      if current != nil:
        result.addListItem(current)
        current = nil
    let whitespace = iprt.curWhitespace == WhitespaceKind.minor
    var node: Content
    if iprt.curMarkupSequence.len > 0:
      if iprt.expectedClosing.len > 0 and iprt.curMarkupSequence ==
          iprt.expectedClosing[iprt.expectedClosing.high]:
        break
      for enclosed in context.enclosed:
        if enclosed.opening == iprt.curMarkupSequence:
          iprt.expectedClosing.add(enclosed.closing)
          iprt.curMarkupSequence.setLen(0)
          var markupContext = childContext(context)
          markupContext.symbols[enclosed.param] =
              newSymbol(iprt.processSection(context))
          node = execute(enclosed.impl, markupContext)
          if iprt.curMarkupSequence != enclosed.closing:
            raise newException(Exception,
                "Missing markup end: " & enclosed.closing)
          iprt.curMarkupSequence.setLen(0)
          discard iprt.expectedClosing.pop()
      for itemized in context.itemized:
        if itemized.bullet == iprt.curMarkupSequence:
          inc(iprt.curIndent)
          let item = BulletItem(markup: iprt.curMarkupSequence,
                                indent: iprt.curIndent)
          iprt.curBulletItems.add(item)
          iprt.curMarkupSequence.setLen(0)
          var markupContext = childContext(context)
          markupContext.symbols[itemized.param] =
              newSymbol(iprt.processSection(context))
          var inner = newList()
          inner.addListItem(execute(itemized.itemImpl, markupContext))
          while iprt.curIndent == item.indent - item.markup.len:
            if iprt.curMarkupSequence.len == 0: break
            if iprt.curMarkupSequence  != item.markup: break
            iprt.curMarkupSequence.setLen(0)
            iprt.curIndent = item.indent
            markupContext.symbols[itemized.param] =
                newSymbol(iprt.processSection(context))
            inner.addListItem(execute(itemized.itemImpl, markupContext))
          markupContext.symbols[itemized.param] = newSymbol(inner)
          node = execute(itemized.enclosingImpl, markupContext)
          discard iprt.curBulletItems.pop()
          break
    elif iprt.lex.buf[iprt.lex.bufpos] == context.emeraldChar:
      node = executeCall(iprt.processCall(context), context)
    else:
      node = iprt.processText(context)
    if current == nil: current = node
    elif node.kind notin {ContentKind.concat, ContentKind.list} or
        (node.kind == ContentKind.concat and node.values.len > 0) or
        (node.kind == ContentKind.list and node.items.len > 0):
      if current.kind != ContentKind.concat:
        current = newConcat(current)
      current.values.add((whitespace: whitespace, node: node))
    if iprt.lex.buf[iprt.lex.bufpos] == EndOfFile: break
  if current != nil:
    result.addListItem(current)

proc emeraldDefine(context: Context): Content =
  result = newList()
  var newSym = Symbol(params: newSeq[ParamDef](), kind: SymbolKind.emerald,
                      content: context.symbols[":content"].content)
  assert context.parent != nil
  let params = context.symbols[":params"].content
  assert params.kind == ContentKind.list
  for param in params.items:
    assert param.kind == ContentKind.list
    assert param.items.len == 2
    assert param.items[0].kind == ContentKind.text
    assert param.items[1].kind == ContentKind.text
    var def = ParamDef(name: param.items[0].textContent)
    case param.items[1].textContent
    of "atom":
      def.kind = ParamKind.atom
    of "list":
      def.kind = ParamKind.list
    of "mapC":
      def.kind = ParamKind.mapCollector
    of "listC":
      def.kind = ParamKind.listCollector
    of "section":
      def.kind = ParamKind.section
    else:
      raise newException(Exception, "Invalid param type: " &
          param.items[1].textContent)
    newSym.params.add(def)
  assert context.symbols[":name"].content.kind == ContentKind.text
  context.parent.symbols[context.symbols[":name"].content.textContent] = newSym

proc emeraldFor(context: Context): Content =
  result = newList()
  let
    variable = context.symbols[":var"].content
    iterable = context.symbols[":iterable"].content
    content = context.symbols[":section"].content
  assert variable.kind == ContentKind.call
  if iterable.kind == ContentKind.call:
    result = Content(kind: ContentKind.call, name: "for", params: @[
        Param(name: ":var", value: variable),
        Param(name: ":iterable", value: iterable),
        Param(name: ":section", value: content)],
        sections: newSeq[Content]())
  else:
    result = newList()
    for item in iterable.items:
      context.symbols[variable.name] = newSymbol(item)
      result.addListItem(execute(content, context))

proc emeraldMarkup(context: Context): Content =
  let
    command = context.symbols["command"].content
    content = context.symbols["content"].content
    section = context.symbols["section"].content
    opening = context.symbols["opening"].content
  assert command.kind == ContentKind.text
  assert content.kind == ContentKind.call
  assert context.parent != nil
  assert opening.kind == ContentKind.text
  case command.textContent
  of "enclosed":
    let closing = context.symbols["closing"].content
    assert closing.kind == ContentKind.text
    context.parent.enclosed.add(EnclosedProc(
        opening: opening.textContent, closing: closing.textContent,
        param: content.name, impl: section))
  of "itemized":
    let section2 = context.symbols["section2"].content
    context.parent.itemized.add(ItemizeProc(
        bullet: opening.textContent, param: content.name, itemImpl: section,
        enclosingImpl: section2))
  else:
    raise newException(Exception,
        "Unknown markup commando: " & command.textContent)

proc emeraldIf(context: Context): Content =
  let
    condition = context.symbols["condition"].content
    thenBranch = context.symbols["then"].content
    elseBranch = context.symbols["else"].content
  if condition.kind == ContentKind.call:
    result = Content(kind: ContentKind.call, name: "if", params: @[
        Param(name: "condition", value: condition),
        Param(name: "then", value: thenBranch),
        Param(name: "else", value: elseBranch)],
        sections: newSeq[Content]())
  else:
    if condition.boolVal: result = thenBranch
    else: result = elseBranch

proc emeraldEscapeHtml(context: Context): Content =
  let text = context.symbols["text"].content
  echo $text
  if text.kind == ContentKind.call:
    result = Content(kind: ContentKind.call, name: "escapeHtml", params: @[
        Param(name: "text", value: text)],
        sections: newSeq[Content]())
  else:
    assert text.kind == ContentKind.text
    result = newText("")
    for c in text.textContent:
      case c
      of '<': result.textContent.add("&lt;")
      of '>': result.textContent.add("&gt;")
      of '&': result.textContent.add("&amp;")
      else: result.textContent.add(c)

proc emeraldFilter(context: Context): Content =
  let
    content = context.symbols["content"].content
    section = context.symbols["section"].content
  assert content.kind == ContentKind.call
  assert context.parent != nil
  context.parent.filter = Filter(param: content.name, impl: section)
  result = newList()

proc writeResultTree(output: Stream, tree: Content) =
  case tree.kind
  of ContentKind.call:
    raise newException(Exception, "Unresolved call to \"" & tree.name & "\"")
  of ContentKind.concat:
    var first = true
    for value in tree.values:
      if first: first = false
      elif value.whitespace: output.write(' ')
      writeResultTree(output, value.node)
  of ContentKind.list:
    var first = true
    for item in tree.items:
      if first: first = false
      else: output.write("\n")
      writeResultTree(output, item)
  of ContentKind.text:
    output.write(tree.textContent)
  of ContentKind.boolean:
    output.write($tree.boolVal)

proc contentFromJson(node: JsonNode): Content =
  case node.kind
  of JString: result = newText(node.str)
  of JInt: result = newText($node.num)
  of JFloat: result = newText($node.fnum)
  of JArray:
    result = newList()
    for elem in node.elems:
      result.addListItem(contentFromJson(elem))
  of JObject:
    result = newList()
    for key, value in node.fields.pairs():
      result.addListItem(newList(@[newText(key), contentFromJson(value)]))
  of JBool:
    result = Content(kind: ContentKind.boolean, boolVal: node.bval)
  else:
    raise newException(Exception, "Unsupported JSON node kind: " & $node.kind)

proc render*(input: Stream, output: Stream, params: JsonNode) =
  var root = Context(symbols: initTable[string, Symbol](),
                     whitespaceProcessing: true,
                     emeraldChar: '\\', enclosed: newSeq[EnclosedProc](),
                     itemized: newSeq[ItemizeProc]())
  assert params.kind == JObject
  for key, value in params.pairs():
    root.symbols[key] = newSymbol(contentFromJson(value))
      
  root.symbols["define"] =
      Symbol(params: @[ParamDef(name: ":name", kind: ParamKind.atom),
                       ParamDef(name: ":params", kind: ParamKind.mapCollector),
                       ParamDef(name: ":content", kind: ParamKind.section)],
             kind: SymbolKind.injected, impl: emeraldDefine)
  root.symbols["for"] =
      Symbol(params: @[ParamDef(name: ":var", kind: ParamKind.varDef),
                       ParamDef(name: ":iterable", kind: ParamKind.list),
                       ParamDef(name: ":section", kind: ParamKind.section)],
             kind: SymbolKind.injected, impl: emeraldFor)
  root.symbols["markup"] =
      Symbol(params: @[ParamDef(name: "command", kind: ParamKind.atom),
                       ParamDef(name: "opening", kind: ParamKind.atom),
                       ParamDef(name: "content", kind: ParamKind.varDef),
                       ParamDef(name: "closing", kind: ParamKind.atom,
                                default: newText()),
                       ParamDef(name: "section", kind: ParamKind.section),
                       ParamDef(name: "section2", kind: ParamKind.section,
                                default: newText())],
              kind: SymbolKind.injected, impl: emeraldMarkup)
  root.symbols["if"] =
      Symbol(params: @[ParamDef(name: "condition", kind: ParamKind.atom),
                       ParamDef(name: "then", kind: ParamKind.section),
                       ParamDef(name: "else", kind: ParamKind.section,
                                default: newText())],
             kind: SymbolKind.injected, impl: emeraldIf)
  root.symbols["escapeHtml"] =
      Symbol(params: @[ParamDef(name: "text", kind: ParamKind.atom)],
             kind: SymbolKind.injected, impl: emeraldEscapeHtml)
  root.symbols["filter"] =
      Symbol(params: @[ParamDef(name: "content", kind: ParamKind.varDef),
                       ParamDef(name: "section", kind: ParamKind.section)],
             kind: SymbolKind.injected, impl: emeraldFilter)
  var iprt = Interpreter(indent: newSeq[int](),
                         curWhitespace: WhitespaceKind.none,
                         curMarkupSequence: "",
                         expectedClosing: newSeq[string](),
                         curBulletItems: newSeq[BulletItem]())
  iprt.lex.open(input)
  iprt.curIndent = iprt.lex.findContentStart()
  if iprt.lex.buf[iprt.lex.bufpos] != EndOfFile:
    iprt.indent.add(iprt.curIndent)
    let content = iprt.processSection(root)
    assert content.kind == ContentKind.list
    writeResultTree(output, content)

let args = commandLineParams()
if args.len < 1 or args.len > 2:
  echo "Usage:\n  ", paramStr(0), " <template> [<params>]"
  quit 1

var input = newFileStream(args[0])
var params = %* {}
if args.len == 2:
  params = parseJson(newFileStream(args[1]), args[1])

var output: Stream = newFileStream(stdout)

render(input, output, params)
