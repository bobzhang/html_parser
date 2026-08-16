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
/// Literal emission is only correct in HTML content, so the check is
/// context-sensitive rather than name-based. An SVG `xmp` holds ordinary parsed
/// content, and so does anything under one: a reparse reads it as foreign
/// content, where `<img src=x onerror=1>` breaks out into a live element.
///
/// The name is matched first so that ordinary elements never pay for the
/// context walk.
fn raw_text_element(node : @dom.Node) -> Bool {
  if !(node.kind is Element) {
    return false
  }
  let candidate = match node.name {
    "iframe"
    | "noembed"
    | "noframes"
    | "plaintext"
    | "script"
    | "style"
    | "xmp" => true
    _ => false
  }
  candidate && !node_in_foreign_context(node)
}

///|
/// The content mode a reparse would be in at some point in the tree.
priv enum SerializedContext {
  HtmlContent
  SvgContent
  MathContent
}

///|
/// Return whether a node's text would be reparsed as foreign content.
///
/// The question is what a parser does with the markup about to be emitted, so
/// this replays the tree builder's namespace transitions over the ancestor tag
/// *names* rather than trusting the stored namespaces. Those two disagree
/// exactly where it matters: `element("svg", …)` defaults to the HTML namespace
/// but still emits `<svg>`, which enters SVG content on the next parse.
///
/// Only raw-text candidates reach this, so walking the ancestor chain is rare.
fn node_in_foreign_context(node : @dom.Node) -> Bool {
  let ancestors = []
  let mut current = node.parent
  while current is Some(ancestor) {
    if ancestor.kind is Element {
      ancestors.push(ancestor)
    }
    current = ancestor.parent
  }
  // `ancestors` runs upwards; the transitions have to be replayed downwards.
  let mut context = HtmlContent
  for index = ancestors.length() - 1; index >= 0; index = index - 1 {
    context = context_within(context, ancestors[index])
  }
  !(context is HtmlContent)
}

///|
/// Return the content mode inside `element`, entered from `outer`.
///
/// From HTML content an `svg` or `math` tag opens foreign content. Within it,
/// an integration point returns to HTML content, and so does a breakout tag:
/// the tree builder pops out of foreign content before handling one.
fn context_within(
  outer : SerializedContext,
  element : @dom.Node,
) -> SerializedContext {
  match outer {
    HtmlContent =>
      match element.name {
        "svg" => SvgContent
        "math" => MathContent
        _ => HtmlContent
      }
    SvgContent =>
      if element.name is ("foreignObject" | "desc" | "title") ||
        foreign_breakout_name(element.name) {
        HtmlContent
      } else {
        SvgContent
      }
    MathContent =>
      if element.name is ("mi" | "mo" | "mn" | "ms" | "mtext") ||
        (element.name == "annotation-xml" && annotation_xml_holds_html(element)) ||
        foreign_breakout_name(element.name) {
        HtmlContent
      } else {
        MathContent
      }
  }
}

///|
/// Return whether a start tag pops the tree builder out of foreign content.
///
/// Mirrors `parser`'s list, which cannot be shared because `parser` depends on
/// this package. `font` is deliberately absent: it only breaks out when it
/// carries `color`, `face` or `size`, and treating it as staying foreign errs
/// towards escaping.
fn foreign_breakout_name(name : StringView) -> Bool {
  match name {
    "b"
    | "big"
    | "blockquote"
    | "body"
    | "br"
    | "center"
    | "code"
    | "dd"
    | "div"
    | "dl"
    | "dt"
    | "em"
    | "embed"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "head"
    | "hr"
    | "i"
    | "img"
    | "li"
    | "listing"
    | "menu"
    | "meta"
    | "nobr"
    | "ol"
    | "p"
    | "pre"
    | "ruby"
    | "s"
    | "small"
    | "span"
    | "strong"
    | "strike"
    | "sub"
    | "sup"
    | "table"
    | "tt"
    | "u"
    | "ul"
    | "var" => true
    _ => false
  }
}

///|
/// Return whether an `annotation-xml` declares an HTML encoding.
fn annotation_xml_holds_html(node : @dom.Node) -> Bool {
  for name, value in node.attrs {
    if name.to_lower() == "encoding" && value is Some(encoding) {
      let lowered = encoding.to_lower()
      return lowered == "text/html" || lowered == "application/xhtml+xml"
    }
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
