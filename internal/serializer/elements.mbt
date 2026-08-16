///|
/// Return whether an HTML element is void and must not serialize an end tag.
///
/// `name` is compared against the lowercase HTML void-element set.
pub fn is_void_element(name : StringView) -> Bool {
  match name {
    "area"
    | "base"
    | "br"
    | "col"
    | "embed"
    | "hr"
    | "img"
    | "input"
    | "link"
    | "meta"
    | "param"
    | "source"
    | "track"
    | "wbr" => true
    _ => false
  }
}

///|
/// Return whether an element's text children serialize literally.
///
/// These are HTML's raw-text elements: the tokenizer scans their content
/// without decoding character references, so the serializer must emit that
/// content verbatim. Escaping it would turn `&` into `&amp;` on every
/// round trip. `noscript` is deliberately absent: it is only raw text when
/// scripting is enabled, and the serializer does not know the parse mode.
///
/// The check is namespace-sensitive. A foreign element that merely shares a
/// local name — an SVG `xmp`, say — holds ordinary parsed content, so emitting
/// its text literally would turn `<img src=x onerror=1>` back into a live
/// element under foreign-content breakout rules on the next parse.
fn raw_text_element(node : @dom.Node) -> Bool {
  if !(node.kind is Element) || !(node.ns is (None | Some("html"))) {
    return false
  }
  match node.name {
    "iframe"
    | "noembed"
    | "noframes"
    | "plaintext"
    | "script"
    | "style"
    | "xmp" => true
    _ => false
  }
}

///|
/// Serialize a raw-text element's children as a single literal payload.
///
/// The end-tag guard runs over the joined content rather than over each child
/// separately, so a closing sequence split across adjacent text nodes — say
/// `"</x"` followed by `"mp><img src=x onerror=1>"` inside an `xmp` — cannot
/// slip past it and break out of the element.
fn raw_text_children_html(
  node : @dom.Node,
  quote : Char,
) -> String raise @core.HtmlError {
  let raw = StringBuilder()
  for child in serialized_children(node) {
    match child.kind {
      Text => if !child.sanitize_escape_only { raw.write_string(child.data) }
      _ => raw.write_string(node_to_html_compact(child, quote))
    }
  }
  neutralize_rawtext_end_tag_sequences(raw.to_string(), node.name)
}

///|
fn pretty_text_preserves_whitespace(node : @dom.Node) -> Bool {
  raw_text_element(node) || node.name is ("pre" | "textarea" | "listing")
}

///|
fn layout_block_element_name(name : StringView) -> Bool {
  match name {
    "address"
    | "article"
    | "aside"
    | "blockquote"
    | "body"
    | "caption"
    | "center"
    | "dd"
    | "details"
    | "dialog"
    | "dir"
    | "div"
    | "dl"
    | "dt"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "header"
    | "hgroup"
    | "hr"
    | "html"
    | "iframe"
    | "li"
    | "listing"
    | "main"
    | "marquee"
    | "menu"
    | "nav"
    | "noframes"
    | "noscript"
    | "ol"
    | "p"
    | "plaintext"
    | "pre"
    | "search"
    | "section"
    | "summary"
    | "table"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr"
    | "ul" => true
    _ => false
  }
}

///|
fn inline_pretty_element_name(name : StringView) -> Bool {
  match name {
    "a"
    | "abbr"
    | "b"
    | "bdi"
    | "bdo"
    | "cite"
    | "code"
    | "data"
    | "del"
    | "dfn"
    | "em"
    | "i"
    | "ins"
    | "kbd"
    | "label"
    | "mark"
    | "q"
    | "rp"
    | "rt"
    | "ruby"
    | "s"
    | "samp"
    | "small"
    | "span"
    | "strong"
    | "sub"
    | "sup"
    | "time"
    | "u"
    | "var" => true
    _ => false
  }
}

///|
fn is_text_block_element(name : StringView) -> Bool {
  match name {
    "address"
    | "article"
    | "aside"
    | "blockquote"
    | "body"
    | "dd"
    | "div"
    | "dl"
    | "dt"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "header"
    | "hr"
    | "html"
    | "li"
    | "main"
    | "nav"
    | "ol"
    | "p"
    | "pre"
    | "section"
    | "table"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr"
    | "ul" => true
    _ => false
  }
}
