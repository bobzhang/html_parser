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
  raw_text_element_name(node.name) &&
  !node_in_foreign_context(node) &&
  !node_under_special_text(node)
}

///|
/// Return whether `name` is a raw-text element name.
///
/// Matched case-insensitively: the tokenizer folds tag names, while the public
/// builder keeps whatever case the caller wrote, and `element("XMP", …)` still
/// emits a tag the parser reads as raw text.
fn raw_text_element_name(name : StringView) -> Bool {
  for
    candidate in [
      "iframe", "noembed", "noframes", "plaintext", "script", "style", "xmp",
    ] {
    if name.compare_ignore_ascii_case(candidate) == 0 {
      return true
    }
  }
  false
}

///|
/// Return whether any ancestor has its content tokenized as text.
///
/// Only HTML elements count: an SVG `title` is an integration point whose
/// content really is parsed as markup, not the RCDATA element of the same name.
///
/// The parser never nests an element inside `textarea`, `title` or a raw-text
/// element — their content is already text by the time the tree builder sees
/// it — so such a tree was built by hand. Emitting a descendant's text
/// literally there would let it close the ancestor: an `xmp` inside a
/// `textarea` whose text opens with `</textarea>` breaks out into live markup.
fn node_under_special_text(node : @dom.Node) -> Bool {
  let mut current = node.parent
  while current is Some(ancestor) {
    if ancestor.kind is Element &&
      ancestor.ns is (None | Some("html")) &&
      special_text_element(ancestor.name) {
      return true
    }
    current = ancestor.parent
  }
  false
}

///|
/// Element names whose content the tokenizer scans as text rather than markup.
///
/// Matched case-insensitively, because the tokenizer folds tag names while the
/// public builder preserves whatever case the caller wrote.
///
/// `noscript` is included even though it is only text when scripting is
/// enabled. The serializer cannot know the parse mode, and output normally
/// crosses modes: a tree parsed with `scripting_enabled=false` can hold
/// `<noscript><xmp></noscript>…</xmp></noscript>`, and emitting that literally
/// goes live the moment anything reparses it with scripting on — which is the
/// default here and always true in a browser. The cost is that a `<script>`
/// inside a `<noscript>` parsed with scripting disabled stays escaped. That
/// matches how this serializer already treats `noscript`'s own content, and
/// trades an escape level for an injection.
fn special_text_element(name : StringView) -> Bool {
  for
    candidate in [
      "iframe", "noembed", "noframes", "noscript", "plaintext", "script", "style",
      "textarea", "title", "xmp",
    ] {
    if name.compare_ignore_ascii_case(candidate) == 0 {
      return true
    }
  }
  false
}

///|
/// Return whether a node's text would be reparsed as foreign content.
///
/// The parser is the authority on namespaces, so this trusts `ns` rather than
/// re-deriving the tree builder's foreign-content rules: the node and every
/// ancestor must be HTML.
///
/// Foreign ancestors are rejected outright rather than excepting integration
/// points. `to_html` can be called on any subtree, and an ancestor that
/// justifies literal emission may not appear in the emitted markup: serializing
/// the SVG `title` of `<svg><title><xmp></title>…</xmp></title></svg>` on its
/// own reparses as HTML RCDATA, where the text closes the `title` and what
/// follows becomes live markup. Every ancestor consulted here now only ever
/// makes the decision more conservative, which holds for any serialization
/// root. The cost is that raw text inside an integration point stays escaped.
///
/// A tree can also be built by hand, where `ns` need not agree with the tag
/// name: `element("svg", …)` defaults to the HTML namespace but still emits
/// `<svg>`, which opens SVG content on the next parse. Reconstructing what such
/// a tree reparses to means reimplementing the tree builder, and getting it
/// subtly wrong turns escaped text into live markup — so a tree that
/// contradicts itself is treated as foreign instead, which is the safe
/// direction. Every shape this gives up on is one the parser cannot produce.
fn node_in_foreign_context(node : @dom.Node) -> Bool {
  if !(node.ns is (None | Some("html"))) {
    return true
  }
  let mut current = node.parent
  while current is Some(ancestor) {
    if ancestor.kind is Element {
      if !(ancestor.ns is (None | Some("html"))) {
        return true
      }
      if namespace_contradicts_name(ancestor) {
        return true
      }
    }
    current = ancestor.parent
  }
  false
}

///|
/// Return whether an element's namespace contradicts its tag name.
///
/// `svg` and `math` open foreign content on a reparse whatever namespace the
/// node claims, so an element carrying one of those names outside the matching
/// namespace means the tree cannot be taken at face value. This only applies
/// to elements emitted from HTML content: inside foreign content a nested
/// `math` legitimately stays in the enclosing namespace, because the tree
/// builder only switches namespace from HTML.
fn namespace_contradicts_name(node : @dom.Node) -> Bool {
  if node.name.compare_ignore_ascii_case("svg") == 0 {
    return !(node.ns is Some("svg"))
  }
  if node.name.compare_ignore_ascii_case("math") == 0 {
    return !(node.ns is Some("math"))
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
  if name.compare_ignore_ascii_case("plaintext") == 0 {
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
  for
    candidate in [
      "iframe", "listing", "noembed", "noframes", "plaintext", "pre", "script", "style",
      "textarea", "xmp",
    ] {
    if node.name.compare_ignore_ascii_case(candidate) == 0 {
      return true
    }
  }
  false
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
