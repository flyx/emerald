import tagdef, tables, sets

proc escapeHtml*(value : string, escapeQuotes: bool = false): string =
    result = newStringOfCap(if value.len < 32: 64 else: value.len * 2)
    for c in value:
        case c:
        of '&': result.add("&amp;")
        of '<': result.add("&lt;")
        of '>': result.add("&gt;")
        of '"':
            if escapeQuotes: result.add("&quot;")
            else: result.add('"')
        of '\'':
            if escapeQuotes: result.add("&#39;")
            else: result.add('\'')
        else:
            result.add(c)

proc html5tags*(): TTagList {.compileTime, tagdef.} =
    a:
        content_categories = (flow_content, phrasing_content, interactive_content)
        permitted_content  = transparent
        optional_attrs     = (download, href, media, ping, rel, target,
                              hreflang, `type`)
    (abbr, b, bdi, bdo, cite, code, em, h1, h2, h3, h4, h5, h6, i, kbd, mark,
     samp, small, span, strong, sub, sup, u, `var`):
        content_categories = (flow_content, phrasing_content)
        permitted_content  = phrasing_content
    address:
        content_categories = flow_content
        permitted_content  = flow_content
        forbidden_content  = (heading_content, sectioning_content)
        forbidden_tags     = (address, header, footer)
    area:
        content_categories = (flow_content, phrasing_content)
        optional_attrs     = (alt, coords, download, href, hreflang, media,
                              rel, shape, target, `type`)
    (article, aside, nav, section):
        content_categories = (flow_content, sectioning_content)
        permitted_content  = flow_content
        forbidden_tags     = main
    audio:
        content_categories = (flow_content, embedded_content, interactive_content)
        permitted_content  = transparent
        permitted_tags     = (track, source)
    base:
        content_categories = metadata_content
        tag_omission       = true
        optional_attrs     = (href, target)
    blockquote:
        content_categories = flow_content
        permitted_content  = flow_content
        optional_attrs     = cite
    body:
        permitted_content  = flow_content
        optional_attrs     = (onafterprint, onbeforeprint, onbeforeunload,
                              onblur, onerror, onfocus, onhashchange, onload,
                              onmessage, onoffline, ononline, onpopstate,
                              onredo, onresize, onstorage, onundo, onunload)
    (br, wbr):
        content_categories = (flow_content, phrasing_content)
        tag_omission       = true
    button:
        content_categories = (flow_content, phrasing_content, interactive_content)
        permitted_content  = phrasing_content
        optional_attrs     = (autofocus, disabled, form, formaction,
                              formenctype, formmethod, formnovalidate,
                              formtarget, name, `type`, value)
    canvas:
        content_categories = (flow_content, phrasing_content, embedded_content)
        permitted_content  = transparent
        forbidden_content  = interactive_content
        forbidden_tags     = (a, button)
        optional_attrs     = (width, height)
    caption:
        permitted_content  = flow_content
    col:
        tag_omission = true
        optional_attrs = span
    colgroup:
        permitted_tags = col
        optional_attrs = span
    content:
        content_categories = transparent
    data:
        content_categories = (flow_content, phrasing_content)
        permitted_content  = phrasing_content
        required_attrs     = value
    datalist:
        content_categories = (flow_content, phrasing_content)
        permitted_content  = phrasing_content
        permitted_tags     = option
    dd:
        permitted_content = flow_content      
    (del, ins):
        content_categories = (flow_content, phrasing_content)
        permitted_content  = transparent
        optional_attrs     = (cite, datetime)
    details:
        content_categories = (flow_content, interactive_content)
        permitted_content  = flow_content
        permitted_tags     = summary
        optional_attrs     = open
    dfn:
        content_categories = (flow_content, phrasing_content)
        permitted_content  = phrasing_content
        forbidden_tags     = dfn
    `div`:
        content_categories = flow_content
        permitted_content  = flow_content
    dl:
        content_categories = flow_content
        permitted_tags     = (dt, dd)
    dt:
        permitted_content  = flow_content
        forbidden_content  = (sectioning_content, heading_content)
        forbidden_tags     = (header, footer)
    element:
        content_categories = transparent
    embed:
        content_categories = (flow_content, phrasing_content)
        tag_omission       = true
        optional_attrs     = (src, `type`, width, height)
    fieldset:
        content_categories = flow_content
        permitted_content  = flow_content
        permitted_tags     = legend
        optional_attrs     = (disabled, form, name)
    figcaption:
        permitted_content = flow_content
    figure:
        content_categories = flow_content
        permitted_content  = flow_content
        permitted_tags     = figcaption
    (footer, header):
        content_categories = flow_content
        permitted_content  = flow_content
        forbidden_tags     = (header, footer, main)
    form:
        content_categories = flow_content
        permitted_content  = flow_content
        forbidden_tags     = form
        optional_attrs     = (accept_charset, action, autocomplete, enctype,
                              `method`, name, novalidate, target)
    head:
        permitted_content  = metadata_content
    hr:
        content_categories = flow_content
        tag_omission       = true
    html:
        permitted_tags = (head, body)
        optional_attrs = manifest
    iframe:
        content_categories = (flow_content, phrasing_content)
        optional_attrs     = (src, srcdoc, name, sandbox, seamless,
                              allowfullscreen, width, height)
    img:
        content_categories = (flow_content, phrasing_content)
        tag_omission       = true
        optional_attrs     = (alt, crossorigin, height, ismap, srcset, width,
                              usemap)
        required_attrs     = src
    input:
        content_categories = (flow_content, phrasing_content)
        tag_omission       = true
        optional_attrs     = (`type`, accept, autocomplete, autofocus,
                              autosave, checked, disabled, form, formaction,
                              formenctype, formmethod, formnovalidate,
                              formtarget, height, inputmode, list, max,
                              maxlength, min, minlength, multiple, name,
                              pattern, placeholder, readonly, required,
                              selectionDirection, size, spellcheck, src,
                              step, value, width)
    keygen:
        content_categories = (flow_content, phrasing_content)
        tag_omission       = true
        optional_attrs     = (autofocus, challenge, disabled, form, keytype,
                              name)
    label:
        content_categories = (flow_content, phrasing_content,
                              interactive_content)
        permitted_content  = phrasing_content
        forbidden_tags     = label
        optional_attrs     = (accesskey, `for`, form)
    legend:
        permitted_content  = phrasing_content
    li:
        permitted_content = flow_content
        optional_attrs    = value
    link:
        content_categories = (metadata_content, flow_content, phrasing_content)
        tag_omission       = true
        optional_attrs     = (crossorigin, href, hreflang, media, rel, sizes,
                              `type`)
    main:
        content_categories = flow_content
        permitted_content  = flow_content
    map:
        content_categories = (flow_content, phrasing_content)
        permitted_content  = transparent
        required_attrs     = name
    menu:
        content_categories = flow_content
        permitted_content  = flow_content
        permitted_tags     = (li, menuitem)
        optional_attrs     = (`type`, label)
    menuitem:
        tag_omission   = true
        optional_attrs = (checked, command, default, disabled, icon, label,
                          radiogroup, `type`)
    meta:
        content_categories = (metadata_content, flow_content, phrasing_content)
        tag_omission       = true
        optional_attrs     = (charset, content, http_equiv, name)
    meter:
        content_categories = (flow_content, phrasing_content)
        permitted_content  = phrasing_content
        forbidden_tags     = meter
        optional_attrs     = (value, min, max, `low`, `high`, optimum, form)
    noscript:
        content_categories = (metadata_content, flow_content, phrasing_content)
        permitted_content  = transparent
        forbidden_tags     = noscript
    `object`:
        content_categories = (flow_content, phrasing_content, embedded_content,
                              interactive_content)
        permitted_tags     = param
        permitted_content  = transparent
        optional_attrs     = (data, height, name, `type`, usemap, width)
    ol:
        content_categories = flow_content
        permitted_tags     = li
        optional_attrs     = (reversed, start, `type`)
    optgroup:
        permitted_tags = option
        optional_attrs = disabled
        required_attrs = label
    option:
        permitted_content = text_content
        optional_attrs    = (disabled, label, selected, value)
    output:
        content_categories = (flow_content, phrasing_content)
        permitted_content  = phrasing_content
        optional_attrs     = (`for`, form, name)
    (p, pre):
        content_categories = flow_content
        permitted_content  = phrasing_content
    param:
        tag_omission = true
        required_attrs = (name, value)
    progress:
        content_categories = (flow_content, phrasing_content)
        permitted_content  = phrasing_content
        forbidden_tags     = progress
        optional_attrs     = (max, value)
    q:
        content_categories = (flow_content, phrasing_content)
        permitted_content  = phrasing_content
        optional_attrs     = cite
    (rp, rt):
        permitted_content = phrasing_content
    ruby:
        content_categories = (flow_content, phrasing_content)
        permitted_content  = phrasing_content
        permitted_tags     = (rp, rt)
    s:
        content_categories = (flow_content, phrasing_content)
        permitted_content  = transparent
    script:
        content_categories = (metadata_content, flow_content, phrasing_content)
        permitted_content  = text_content
        optional_attrs     = (async, src, `type`, defer)
    select:
        content_categories = (flow_content, phrasing_content, interactive_content)
        permitted_tags     = (option, optgroup)
        optional_attrs     = (autofocus, disabled, form, multiple, name,
                              required, size)
    source:
        tag_omission = true
        optional_attrs = (`type`, media)
        required_attrs = src
    style:
        content_categories = (metadata_content, flow_content)
        permitted_content  = text_content
        optional_attrs     = (`type`, media, scoped, title, disabled)
    summary:
        permitted_content = phrasing_content
    table:
        content_categories = flow_content
        permitted_tags     = (caption, colgroup, thread, tbody, tfoot, tr)
    (tbody, tfoot, thead):
        permitted_tags = tr
    (td, th):
        permitted_content = flow_content
        optional_attrs    = (colspan, headers, rowspan)
    `template`:
        content_categories = (metadata_content, flow_content, phrasing_content)
        permitted_content  = any_content
    textarea:
        content_categories = (flow_content, phrasing_content, interactive_content)
        permitted_content  = text_content
        optional_attrs     = (autocomplete, autofocus, cols, disabled, form,
                              maxlength, minlength, name, placeholder,
                              readonly, required, rows, selectionDirection,
                              selectionEnd, selectionStart, spellcheck, wrap)
    time:
        content_categories = (flow_content, phrasing_content)
        permitted_content  = phrasing_content
        forbidden_tags     = time
        optional_attrs     = datetime
    title:
        content_categories = metadata_content
        permitted_content  = text_content
    tr:
        permitted_tags = (td, th)
    track:
        tag_omission   = true
        optional_attrs = (default, kind, label, srclang)
        required_attrs = src
    ul:
        content_categories = flow_content
        permitted_tags     = (li, ol, ul)
    video:
        content_categories = (flow_content, phrasing_content, embedded_content, interactive_content)
        permitted_content  = transparent
        permitted_tags     = track
        forbidden_tags     = (audio, video)
        optional_attrs     = (autoplay, buffered, controls, crossorigin,
                              height, loop, muted, played, preload, poster,
                              src, width)

