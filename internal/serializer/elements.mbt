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
/// The check is context-sensitive, not just name-based. A foreign element that
/// merely shares a local name — an SVG `xmp`, say — holds ordinary parsed
/// content, and so does an HTML-namespace one placed under a foreign parent
/// programmatically: a reparse reads both as foreign content, where
/// `<img src=x onerror=1>` breaks out into a live element.
fn raw_text_element(node : @dom.Node) -> Bool {
  if !(node.kind is Element) || node_in_foreign_context(node) {
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
/// Return whether a node would be reparsed as foreign content.
///
/// True when the node itself or any ancestor is outside the HTML namespace.
/// Only raw-text candidates reach this, so the ancestor walk is rare.
fn node_in_foreign_context(node : @dom.Node) -> Bool {
  let mut current = Some(node)
  while current is Some(element) {
    if element.kind is Element && !(element.ns is (None | Some("html"))) {
      return true
    }
    current = element.parent
  }
  false
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
  raw_text_payload(raw.to_string(), node.name)
}

///|
/// Apply the end-tag guard appropriate to a raw-text element.
///
/// `plaintext` is exempt: it consumes to end of file and never recognizes an
/// end tag, so there is no boundary to protect and rewriting the `<` would only
/// corrupt content that is already there legitimately — `<plaintext>a</plaintext>b`
/// parses to the text `a</plaintext>b`.
fn raw_text_payload(value : StringView, name : StringView) -> String {
  if name == "plaintext" {
    value.to_owned()
  } else {
    neutralize_rawtext_end_tag_sequences(value, name)
  }
}

///|
/// Return whether pretty printing must keep an element's text as written.
///
/// This is deliberately name-based and independent of `raw_text_element`.
/// Whether content is emitted literally is a parsing-context question; whether
/// its whitespace is significant is not. A foreign `style` or `script` still
/// has its text escaped, but collapsing the runs inside a CSS `content` value
/// or a JavaScript string literal would change what it means.
fn pretty_text_preserves_whitespace(node : @dom.Node) -> Bool {
  node.name
  is ("iframe"
  | "listing"
  | "noembed"
  | "noframes"
  | "plaintext"
  | "pre"
  | "script"
  | "style"
  | "textarea"
  | "xmp")
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
