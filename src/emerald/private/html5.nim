import tables, sets, hashes, macros
import tagdef

tag_list:
    global:
        attributes = (accesskey, class, contenteditable, contextmenu, data, dir,
                      draggable, dropzone, hidden, id, itemid, itemprop,
                      itemref, itemscope, itemtype, lang, spellcheck, style,
                      tabindex, title,
                      onabort, onautocomplete, onautocompleteerror, onblur,
                      oncancel, oncanplay, oncanplaythrough, onchange, onclick,
                      onclose, oncontextmenu, oncuechange, ondblclick, ondrag,
                      ondragend, ondragenter, ondragexit, ondragleave,
                      ondragover, ondragstart, ondrop, ondurationchange,
                      onemptied, onended, onerror, onfocus, oninput, oninvalid,
                      onkeydown, onkeypress, onkeyup, onload, onloadeddata,
                      onloadedmetadata, onloadstart, onmousedown, onmouseenter,
                      onmouseleave, onmousemove, onmouseout, onmouseover,
                      onmouseup, onmousewheel, onpause, onplay, onplaying,
                      onprogress, onratechange, onreset, onresize, onscroll,
                      onseeked, onseeking, onselect, onshow, onsort, onstalled,
                      onsubmit, onsuspend, ontimeupdate, ontoggle,
                      onvolumechange, onwaiting)
        booleans = (checked, compact, declare, `defer`, disabled, ismap,
                    multiple, nohref, noresize, noshade, nowrap, readonly,
                    selected)
    
    a:
        content_categories = (flow_content, phrasing_content,
                              interactive_content)
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
        content_categories = (flow_content, embedded_content,
                              interactive_content)
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
        content_categories = (flow_content, phrasing_content,
                              interactive_content)
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
        required_attrs = lang
        optional_attrs = manifest
        prepend        = "<!DOCTYPE html>"
        injected_attrs:
            xmlns = "http://www.w3.org/1999/xhtml"
            "xml:lang" = lang
            
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
        optional_attrs     = (async, src, `type`, `defer`, charset)
    select:
        content_categories = (flow_content, phrasing_content,
                              interactive_content)
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
        permitted_tags     = (caption, colgroup, thead, tbody, tfoot, tr)
    (tbody, tfoot, thead):
        permitted_tags = tr
    (td, th):
        permitted_content = flow_content
        optional_attrs    = (colspan, headers, rowspan)
    `template`:
        content_categories = (metadata_content, flow_content, phrasing_content)
        permitted_content  = any_content
    textarea:
        content_categories = (flow_content, phrasing_content,
                              interactive_content)
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
        content_categories = (flow_content, phrasing_content, embedded_content,
                              interactive_content)
        permitted_content  = transparent
        permitted_tags     = track
        forbidden_tags     = (audio, video)
        optional_attrs     = (autoplay, buffered, controls, crossorigin,
                              height, loop, muted, played, preload, poster,
                              src, width)