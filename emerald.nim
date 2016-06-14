import lexbase, streams, strutils, tables, json, sequtils

type
  ContentKind {.pure.} = enum
    text, call, list
  
  Param = object
    name: string
    value: Content
  
  WhitespaceKind {.pure.} = enum
    none, minor, major
  
  Content = ref object
    case kind: ContentKind
    of ContentKind.text:
      textContent: string
    of ContentKind.call:
      name: string
      params: seq[Param]
      section: Content
    of ContentKind.list:
      values: seq[Content]
    before: WhitespaceKind
  
  SymbolKind {.pure.} = enum
    emerald, injected
    
  InjectedSymbol = proc(context: Context): Content

  ParamDef = object
    name: string
    default: Content

  Symbol = ref object
    params: seq[ParamDef]
    case kind: SymbolKind
    of SymbolKind.emerald:
      content: Content
    of SymbolKind.injected:
      impl: InjectedSymbol
  
  Context = ref object
    symbols: Table[string, Symbol]
    whitespaceProcessing: bool
    emeraldChar: char
    parent: Context
  
  Interpreter = ref object
    lex: BaseLexer
    indent: seq[int]
    curIndent: int
    curWhitespace: WhitespaceKind

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
  of ContentKind.text:
    result.add("text:\n" & repeat(' ', indent + 2) & val.textContent & "\n")
  of ContentKind.call:
    result.add("call(" & val.name & "):\n")
    for param in val.params:
      result.add(toString(param, indent + 2))
    if not isNil(val.section):
      result.add(repeat(' ', indent + 2) & "section:\n")
      result.add(toString(val.section, indent + 4))
  of ContentKind.list:
    for item in val.values:
      result.add(toString(item, indent))
    
proc `$`*(val: Content): string = val.toString(0)

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
  result = Content(kind: ContentKind.text, textContent: "",
                       before: WhitespaceKind.none)
  inc(lex.bufpos)
  while lex.buf[lex.bufpos] notin {'\l', '\c', EndOfFile, '\"'}:
    result.textContent.add(lex.buf[lex.bufpos])
    inc(lex.bufpos)
  if lex.buf[lex.bufpos] != '\"':
    raise newException(Exception, "Unclosed string")

proc processSection(iprt: var Interpreter, context: Context): Content

proc processCallParams(iprt: var Interpreter, params: var seq[Param]) =
  assert iprt.lex.buf[iprt.lex.bufpos] == '('
  inc(iprt.lex.bufpos)
  iprt.lex.skipWhitespace()
  if iprt.lex.buf[iprt.lex.bufpos] == ')': return
  while true:
    var itemName = ""
    while iprt.lex.buf[iprt.lex.bufpos] in {'A'..'Z', 'a'..'z'}:
      itemName.add(iprt.lex.buf[iprt.lex.bufpos])
      inc(iprt.lex.bufpos)
    iprt.lex.skipWhitespace()
    var paramName: string = nil
    if iprt.lex.buf[iprt.lex.bufpos] == '=':
      if itemName.len == 0:
        raise newException(Exception, "Missing parameter name in front of '='")
      paramName = itemName
      inc(iprt.lex.bufpos)
      itemName = ""
      while iprt.lex.buf[iprt.lex.bufpos] in {'A'..'Z', 'a'..'z'}:
        itemName.add(iprt.lex.buf[iprt.lex.bufpos])
        inc(iprt.lex.bufpos)
      iprt.lex.skipWhitespace()
    case iprt.lex.buf[iprt.lex.bufpos]
    of '(':
      if itemName.len == 0:
        raise newException(Exception, "Missing call name")
      var param = Param(name: paramName, value:
          Content(kind: ContentKind.call, name: itemName,
                      params: newSeq[Param](), before: WhitespaceKind.none))
      iprt.processCallParams(param.value.params)
      params.add(param)
      inc(iprt.lex.bufpos)
      iprt.lex.skipWhitespace()
    of '\"':
      if itemName.len != 0:
        raise newException(Exception, "Invalid content")
      params.add(Param(name: paramName, value: iprt.lex.processString()))
      inc(iprt.lex.bufpos)
      iprt.lex.skipWhitespace()
    else:
      params.add(Param(name: paramName, value:
          Content(kind: ContentKind.call, name: itemName,
                      params: newSeq[Param](), before: WhitespaceKind.none)))
    if iprt.lex.buf[iprt.lex.bufpos] notin {',', ')'}:
      raise newException(Exception, "Invalid content")
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

proc executeCall(target: Content, call: Content, context: Context)

proc execute(subject: Content, target: Content, context: Context) =
  assert target.kind == ContentKind.list
  case subject.kind
  of ContentKind.text:
    target.values.add(subject)
  of ContentKind.call:
    executeCall(target, subject, context)
  of ContentKind.list:
    for item in subject.values:
      execute(item, target, context)

proc executeCall(target: Content, call: Content, context: Context) =
  assert call.kind == ContentKind.call
  assert target.kind == ContentKind.list
  var curContext = context
  var sym: Symbol
  while true:
    try:
      sym = curContext.symbols[call.name]
      break
    except KeyError:
      if curContext.parent == nil:
        raise newException(Exception, "Unknown call target: " & call.name)
      curContext = curContext.parent
  
  # map parameters and setup context
  var callContext = Context(symbols: initTable[string, Symbol](),
      whitespaceProcessing: true, emeraldChar: context.emeraldChar,
      parent: context)
  
  if sym.params.len == 0:
    if call.params.len > 0:
      raise newException(Exception, "Call takes no parameters")
  else:
    var paramMapping = repeat(-1, sym.params.high)
    var paramIndex = 0
    for i in 0..call.params.high:
      block searchParam:
        if not isNil(call.params[i].name):
          block searchNamedParam:
            for j in 0..sym.params.high:
              if sym.params[j].name == call.params[i].name:
                paramMapping[j] = i
                if j == paramIndex: break searchNamedParam
                else: break searchParam
            raise newException(Exception,
                               "Unknown parameter: " & call.params[i].name)
        elif paramIndex > paramMapping.high:
          raise newException(Exception, "Too many parameters!")
        else:
          paramMapping[paramIndex] = i
        while paramIndex < paramMapping.high and paramMapping[paramIndex] != -1:
          inc(paramIndex)
    if call.section != nil:
      if paramMapping[paramMapping.high] != -1:
        raise newException(Exception,
            "Section given, but last param already set")
      paramMapping[paramMapping.high] = -2
    for i in 0 .. paramMapping.high:
      if paramMapping[i] == -1:
        if sym.params[i].default == nil:
          raise newException(Exception,
              "Missing required parameter: " & sym.params[i].name)
        else:
          assert sym.params[i].default.kind == ContentKind.text
          callContext.symbols[sym.params[i].name] =
              Symbol(kind: SymbolKind.emerald, params: newSeq[ParamDef](),
                     content: sym.params[i].default)
      elif paramMapping[i] == -2:
        callContext.symbols[sym.params[i].name] =
            Symbol(kind: SymbolKind.emerald, params: newSeq[ParamDef](),
                   content: call.section)
      else:
        assert call.params[paramMapping[i]].value.kind == ContentKind.text
        callContext.symbols[sym.params[i].name] =
            Symbol(kind: SymbolKind.emerald, params: newSeq[ParamDef](),
                   content: call.params[paramMapping[i]].value)
  
  # execute call
  var contentToAdd: Content
  if sym.kind == SymbolKind.emerald:
    contentToAdd = sym.content
  else:
    contentToAdd = sym.impl(callContext)
  contentToAdd.before = call.before
  execute(contentToAdd, target, callContext)

proc processCall(iprt: var Interpreter, context: Context): Content =
  assert iprt.lex.buf[iprt.lex.bufpos] == context.emeraldChar
  result = Content(kind: ContentKind.call, name: "",
                       params: newSeq[Param](), before: iprt.curWhitespace)
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
    iprt.processCallParams(result.params)
    inc(iprt.lex.bufpos)
    while iprt.lex.buf[iprt.lex.bufpos] in {' ', '\t'}:
      iprt.curWhitespace = WhitespaceKind.minor
      inc(iprt.lex.bufpos)
  if iprt.lex.buf[iprt.lex.bufpos] == ':':
    iprt.curWhitespace = WhitespaceKind.none
    inc(iprt.lex.bufpos)
    iprt.skipUntilNextContent(true)
    if iprt.curWhitespace != WhitespaceKind.major:
      raise newException(Exception, "No content allowed in line after ':'")
    if iprt.curIndent <= iprt.indent[iprt.indent.high]:
      raise newException(Exception, "Missing section content")
    iprt.indent.add(iprt.curIndent)
    result.section = iprt.processSection(
        Context(symbols: initTable[string, Symbol](),
                whitespaceProcessing: true,
                emeraldChar: context.emeraldChar, parent: context))
    discard iprt.indent.pop()
  else:
    iprt.skipUntilNextContent(false)
    
proc processText(iprt: var Interpreter, context: Context): Content =
  result = Content(kind: ContentKind.text, textContent: "",
                       before: iprt.curWhitespace)
  iprt.curWhitespace = WhitespaceKind.none
  while true:
    while iprt.lex.buf[iprt.lex.bufpos] notin
        {' ', '\t', '\l', '\c', EndOfFile, context.emeraldChar}:
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

proc processSection(iprt: var Interpreter, context: Context): Content =
  result = Content(kind: ContentKind.list, values: newSeq[Content]())
  while iprt.curIndent >= iprt.indent[iprt.indent.high]:
    if iprt.lex.buf[iprt.lex.bufpos] == context.emeraldChar:
      let call = iprt.processCall(context)
      executeCall(result, call, context)
    else:
      result.values.add(iprt.processText(context))
    if iprt.lex.buf[iprt.lex.bufpos] == EndOfFile: break

proc emeraldDefine(context: Context): Content =
  result = Content(kind: ContentKind.list, values: newSeq[Content]())

proc render*(input: var Stream, output: var Stream, params: JsonNode) =
  var root = Context(symbols: initTable[string, Symbol](),
                     whitespaceProcessing: true,
                     emeraldChar: '\\')
  assert params.kind == JObject
  for key, value in params.pairs():
    case value.kind
    of JString:
      root.symbols[key] =
          Symbol(params: newSeq[ParamDef](), kind: SymbolKind.emerald,
                 content: Content(kind: ContentKind.text,
                                    textContent: value.str))
    of JInt:
      root.symbols[key] =
          Symbol(params: newSeq[ParamDef](), kind: SymbolKind.emerald,
                 content: Content(kind: ContentKind.text,
                                    textContent: $value.num))
    of JFloat:
      root.symbols[key] =
          Symbol(params: newSeq[ParamDef](), kind: SymbolKind.emerald,
                 content: Content(kind: ContentKind.text,
                                    textContent: $value.fnum))
    else:
      raise newException(Exception, "Unsupported value kind: " & $value.kind)
  var iprt = Interpreter(indent: newSeq[int](),
                         curWhitespace: WhitespaceKind.none)
  iprt.lex.open(input)
  iprt.curIndent = iprt.lex.findContentStart()
  if iprt.lex.buf[iprt.lex.bufpos] != EndOfFile:
    iprt.indent.add(iprt.curIndent)
    let content = iprt.processSection(root)
    assert content.kind == ContentKind.list
    for c in content.values:
      assert c.kind == ContentKind.text
      case c.before
      of WhitespaceKind.none: discard
      of WhitespaceKind.minor: output.write(' ')
      of WhitespaceKind.major: output.write("\n\n")
      output.write(c.textContent)

var input: Stream = newStringStream("""This is  text
more    text

More text after empty line
\call
\another
  This is in a section
  more \with stuff
  
  even more
after section

call not enclosed\third()in whitespace
""")

var output: Stream = newFileStream(stdout)

render(input, output, %* {
  "call": "foo",
  "another": "bar",
  "third": 42,
  "with": 4.2
})
