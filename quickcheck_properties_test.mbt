///|
/// Collect every element in a tree, including the root when it is an element.
///
/// A template's descendants live in its content fragment rather than in
/// `children()`, but the serializer still emits them, so they are walked too.
fn collect_elements(root : @dom.Node) -> Array[@dom.Node] {
  let out = []
  fn walk(node : @dom.Node) -> Unit {
    if node.kind() is Element {
      out.push(node)
    }
    for child in node.children() {
      walk(child)
    }
    if node.template_content() is Some(content) {
      walk(content)
    }
  }

  walk(root)
  out
}

///|
test "property: serializing a well-nested document preserves its tree" {
  @qc.check(
    (input : HtmlDocument) => {
      let parsed = @html_parser.parse(input.source())
      let reparsed = @html_parser.parse(parsed.to_html(pretty=false))
      @html_parser.to_test_format(parsed.root) ==
      @html_parser.to_test_format(reparsed.root)
    },
    count=2000,
    seed=20260816,
  )
}

///|
test "property: reserializing a well-nested document is a fixpoint" {
  @qc.check(
    (input : HtmlDocument) => {
      let once = @html_parser.parse(input.source()).to_html(pretty=false)
      let twice = @html_parser.parse(once).to_html(pretty=false)
      once == twice
    },
    count=2000,
    seed=20260817,
  )
}

///|
test "property: pretty reserialization settles after one reparse" {
  // Pretty printing is lossy: the indentation it introduces becomes text in
  // the reparsed tree, so the first pass is not itself a fixpoint. What must
  // hold is that it settles immediately afterwards rather than drifting.
  @qc.check(
    (input : HtmlDocument) => {
      let first = @html_parser.parse(input.source()).to_html(pretty=true)
      let second = @html_parser.parse(first).to_html(pretty=true)
      let third = @html_parser.parse(second).to_html(pretty=true)
      second == third
    },
    count=2000,
    seed=20260823,
  )
}

///|
test "property: parse_bytes on utf-8 agrees with parse" {
  @qc.check(
    (input : HtmlSource) => {
      let src = input.source()
      let direct = @html_parser.parse(src)
      let via_bytes = @html_parser.parse_bytes(
        @utf8.encode(src),
        encoding="utf-8",
      )
      @html_parser.to_test_format(direct.root) ==
      @html_parser.to_test_format(via_bytes.root)
    },
    count=1000,
    seed=20260818,
  )
}

///|
test "property: every queried node matches the selector that found it" {
  @qc.check(
    (input : HtmlSource) => {
      let root = @html_parser.parse(input.source()).root
      for selector in ["p", "div > p", "b i", "[href]", "table td", "*"] {
        for node in @html_parser.query(root, selector) {
          if !@html_parser.matches(node, selector) {
            return false
          }
        }
      }
      true
    },
    count=1000,
    seed=20260819,
  )
}

///|
test "property: text, stream and fragment entry points never raise" {
  @qc.check(
    (input : HtmlSource) => {
      let src = input.source()
      let doc = @html_parser.parse(src)
      ignore(doc.to_text())
      ignore(doc.to_text(separator=" ", strip=true))
      ignore(@html_parser.to_test_format(doc.root))
      ignore(@html_parser.stream(src))
      ignore(@html_parser.parse_fragment(src))
      ignore(@html_parser.tokenize(src, collect_errors=true))
      ignore(@html_parser.find_links(src))
      true
    },
    count=1000,
    seed=20260820,
  )
}

///|
/// Return whether an attribute value resolves to the `javascript:` scheme.
///
/// A plain `trim()` is not enough. Browsers strip every C0 control and space
/// while resolving a URL, so `java<tab>script:alert(1)` — which an author can
/// write as `java&#x09;script:` — runs as script even though it does not start
/// with the literal scheme. Dropping those characters first keeps the check
/// from reading an obfuscated payload as safe.
fn url_scheme_is_script(value : String) -> Bool {
  let stripped = StringBuilder::new()
  for ch in value {
    if ch > ' ' {
      stripped.write_char(ch)
    }
  }
  stripped.to_string().to_lower().has_prefix("javascript:")
}

///|
test "property: sanitized output serializes and drops unsafe constructs" {
  @qc.check(
    (input : HtmlSource) => {
      let root = @html_parser.parse(input.source(), sanitize=true).root
      // Sanitized trees always serialize; the sanitizer removes the names the
      // serializer refuses to emit.
      ignore(@html_parser.to_html(root, pretty=false))
      for element in collect_elements(root) {
        if element.name()
          is ("script" | "style" | "iframe" | "object" | "embed" | "noscript") {
          return false
        }
        for name, value in element.attrs() {
          if name.has_prefix("on") {
            return false
          }
          if value is Some(text) && url_scheme_is_script(text) {
            return false
          }
        }
      }
      true
    },
    count=2000,
    seed=20260821,
  )
}

///|
test "property: escaped text survives a fragment round trip" {
  @qc.check(
    (input : PlainText) => {
      let text = input.text()
      let html = @html_parser.to_html(@html_parser.text(text), pretty=false)
      @html_parser.parse_fragment(html).to_text(separator="", strip=false) ==
      text
    },
    count=2000,
    seed=20260822,
  )
}
