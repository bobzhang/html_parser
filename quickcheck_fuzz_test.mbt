///|
/// Fragment contexts the robustness properties parse under.
///
/// Each one starts the tree builder in a different insertion mode or tokenizer
/// state, so the same input takes a different path through each.
fn fuzz_contexts() -> Array[@html_parser.FragmentContext?] {
  [
    None,
    Some(FragmentContext("table")),
    Some(FragmentContext("tr")),
    Some(FragmentContext("select")),
    Some(FragmentContext("textarea")),
    Some(FragmentContext("script")),
    Some(FragmentContext("template")),
    Some(FragmentContext("html")),
    Some(FragmentContext("svg", ns="svg")),
    Some(FragmentContext("math", ns="math")),
  ]
}

///|
/// Serialize, treating the serializer's name guard (issue #113) as out of
/// scope: it raises rather than emitting something wrong, and is tracked
/// separately.
fn fuzz_to_html(node : @dom.Node, pretty? : Bool = false) -> String? raise {
  Some(@html_parser.to_html(node, pretty~)) catch {
    InvalidSerialization(_) => None
    error => raise error
  }
}

///|
/// Parse a fragment in the given context.
fn fuzz_parse_fragment(
  src : String,
  context : @html_parser.FragmentContext?,
  sanitize? : Bool = false,
  scripting_enabled? : Bool = true,
) -> @html_parser.ParsedHtml raise {
  match context {
    None => @html_parser.parse_fragment(src, sanitize~, scripting_enabled~)
    Some(context) =>
      @html_parser.parse_fragment(src, context~, sanitize~, scripting_enabled~)
  }
}

///|
/// Merge adjacent text events, which carry no meaning of their own.
fn merge_stream_text(
  events : Array[@html_parser.StreamEvent],
) -> Array[@html_parser.StreamEvent] {
  let out : Array[@html_parser.StreamEvent] = []
  for event in events {
    match (out.last(), event) {
      (Some(StreamText(previous)), StreamText(next)) =>
        out[out.length() - 1] = StreamText(previous + next)
      _ => out.push(event)
    }
  }
  out
}

///|
test "property: every entry point accepts arbitrary markup" {
  // `parse` and friends are documented to accept any input; the only error a
  // non-strict call may raise is the serializer's name guard (issue #113).
  @qc.check(
    (input : MarkupFuzz) => {
      let src = input.source()
      for scripting in [true, false] {
        let doc = @html_parser.parse(
          src,
          collect_errors=true,
          scripting_enabled=scripting,
          track_node_locations=true,
        )
        ignore(fuzz_to_html(doc.root))
        ignore(fuzz_to_html(doc.root, pretty=true))
        ignore(doc.to_text(separator_blocks_only=true))
        ignore(@html_parser.to_markdown(doc.root)) catch {
          InvalidSerialization(_) => ()
          error => raise error
        }
        ignore(@html_parser.sanitize_dom(doc.root.clone_node(deep=true)))
        ignore(@html_parser.linkify_dom(doc.root.clone_node(deep=true)))
      }
      ignore(@html_parser.parse(src, xml_coercion=true, iframe_srcdoc=true))
      ignore(@html_parser.parse(src, sanitize=true))
      for context in fuzz_contexts() {
        let frag = fuzz_parse_fragment(src, context)
        ignore(fuzz_to_html(frag.root))
        ignore(fuzz_parse_fragment(src, context, sanitize=true))
      }
      ignore(@html_parser.tokenize(src, collect_errors=true, xml_coercion=true))
      // How text is split into events is not part of the contract, so the
      // two streams are compared with adjacent text events merged.
      //
      // A leading U+FEFF is skipped: the byte decoder strips a BOM and the
      // string entry point strips another, so a doubled BOM is a known
      // divergence between the two paths, reported separately.
      src.has_prefix("\u{FEFF}") ||
      merge_stream_text(@html_parser.stream(src)) ==
      merge_stream_text(
        @html_parser.stream_bytes(@utf8.encode(src), encoding="utf-8"),
      )
    },
    count=600,
    seed=20260901,
    observe=fuzz_observations,
  )
}

///|
test "property: diagnostics and location tracking do not change the tree" {
  @qc.check(
    (input : MarkupFuzz) => {
      let src = input.source()
      let plain = @html_parser.to_test_format(@html_parser.parse(src).root)
      let tracked = @html_parser.parse(
        src,
        collect_errors=true,
        track_node_locations=true,
      )
      plain == @html_parser.to_test_format(tracked.root)
    },
    count=800,
    seed=20260902,
  )
}

///|
/// Check that a tracked node's recorded line and column agree with its offset.
///
/// Offsets are UTF-16 code units. Lines are 1-based and counted by line feeds
/// before the offset; columns are 1-based and count code points, as
/// `@syn.line_col_at` documents.
fn origin_is_consistent(src : String, node : @dom.Node) -> Bool {
  guard node.origin_offset() is Some(offset) else { return true }
  guard offset >= 0 && offset <= src.length() else { return false }
  let mut line = 1
  let mut line_start = 0
  for index in 0..<offset {
    if src.code_unit_at(index) == '\n' {
      line += 1
      line_start = index + 1
    }
  }
  let col = src.view(start_offset=line_start, end_offset=offset).char_length() +
    1
  if node.origin_line() != Some(line) || node.origin_col() != Some(col) {
    return false
  }
  // A comment or an element made from a tag records where its `<` was.
  match node.kind() {
    Element | Comment =>
      offset < src.length() && src.code_unit_at(offset) == '<'
    _ => true
  }
}

///|
test "property: tracked node origins are in bounds and self-consistent" {
  @qc.check(
    (input : MarkupFuzz) => {
      // Carriage returns are normalized before tokenizing, which shifts
      // offsets; the property is about the positions the tree records.
      //
      // The parser drops one leading byte order mark before it starts
      // counting, so offsets are relative to the input without it.
      let src = input.source().replace_all(old="\r", new="")
      let src = if src.has_prefix("\u{FEFF}") {
        src.view(start_offset=1).to_owned()
      } else {
        src
      }
      let doc = @html_parser.parse(src, track_node_locations=true)
      for node in collect_all_nodes(doc.root) {
        if !origin_is_consistent(src, node) {
          return false
        }
      }
      let frag = @html_parser.parse_fragment(src, track_node_locations=true)
      for node in collect_all_nodes(frag.root) {
        if !origin_is_consistent(src, node) {
          return false
        }
      }
      true
    },
    count=800,
    seed=20260903,
  )
}

///|
/// Return whether `node` has an element ancestor called `name`.
fn has_ancestor_named(node : @dom.Node, name : String) -> Bool {
  let mut current = node.parent()
  while current is Some(parent) {
    if parent.kind() is Element && parent.name() == name {
      return true
    }
    current = parent.parent()
  }
  false
}

///|
/// Return whether `node` has an SVG or MathML ancestor.
fn has_foreign_ancestor(node : @dom.Node) -> Bool {
  let mut current = node.parent()
  while current is Some(parent) {
    if parent.kind() is Element &&
      parent.namespace_uri() is Some("svg" | "math") {
      return true
    }
    current = parent.parent()
  }
  false
}

///|
/// Return whether HTML can express `tree` stably at all.
///
/// The shapes excluded are limits of HTML serialization, or trade-offs the
/// serializer documents, rather than bugs. Nothing closes `plaintext`, so the end tag the
/// serializer must emit for it reparses as text. `noscript` content, and raw
/// text nested in it, is escaped deliberately because the serializer cannot
/// know whether the output will be reparsed with scripting enabled; with
/// scripting on it gains a layer of escaping per pass. And script text that
/// opens a double escape (`<!--` then `<script`) has no serialization at all:
/// the closing `</script>` the serializer adds is read as the end of the
/// double escape, so each pass appends another copy of the tail.
fn reserialization_can_settle(tree : @dom.Node, html : String) -> Bool {
  if html.contains("<plaintext") || html.contains("<noscript") {
    return false
  }
  for element in collect_elements(tree) {
    // An `a` inside an `a` cannot be written down: reparsing runs the
    // adoption agency, whose spec-mandated iteration limits move only a few
    // levels per pass, so deep nests take several passes to settle.
    if element.name() == "a" && has_ancestor_named(element, "a") {
      return false
    }
    // Raw text under a foreign ancestor (an `iframe` in a `foreignObject`) is
    // escaped on purpose: the serializer does not credit integration points,
    // so the content gains a layer of escaping per pass.
    if element.namespace_uri() is (None | Some("html")) &&
      element.name()
      is ("iframe" | "noembed" | "noframes" | "script" | "style" | "xmp") &&
      has_foreign_ancestor(element) {
      return false
    }
    if element.name() == "script" {
      let text = element.text().to_lower()
      if text.find("<!--") is Some(open) &&
        text.view(start_offset=open).contains("<script") {
        return false
      }
    }
  }
  true
}

///|
test "property: reserializing arbitrary markup settles after one reparse" {
  // Soup is not round-trippable on the first pass (the tree builder builds
  // shapes such as a `p` inside a `p` that its own serialization cannot
  // express), but the output of that first pass is ordinary markup, and must
  // then be a fixpoint.
  @qc.check(
    (input : MarkupFuzz) => {
      let src = input.source()
      let parse = (html : String) => @html_parser.parse(html)
      let tree = parse(src).root
      guard fuzz_to_html(tree) is Some(first) else { return true }
      if !reserialization_can_settle(tree, first) {
        return true
      }
      let second = parse(first).to_html(pretty=false)
      let third = parse(second).to_html(pretty=false)
      second == third
    },
    count=1500,
    seed=20260904,
    observe=input => {
      let src = input.source().to_lower()
      [
        @qc.classify(
          src.contains("<noscript") || src.contains("<plaintext"),
          "may be excluded (noscript/plaintext)",
        ),
        @qc.classify(src.contains("<script"), "script"),
        @qc.classify(src.contains("<table"), "table"),
      ]
    },
  )
}

///|
test "property: text extraction modes agree" {
  @qc.check(
    (input : MarkupFuzz) => {
      let root = @html_parser.parse(input.source()).root
      let raw = root.text()
      // With no separator and no stripping every mode is plain concatenation.
      raw == @html_parser.to_text(root, separator="", strip=false) &&
      raw ==
      @html_parser.to_text(
        root,
        separator="",
        strip=false,
        separator_blocks_only=true,
      ) &&
      // With a single-space separator, block boundaries and node boundaries
      // are both a single space once stripped.
      @html_parser.to_text(root, separator=" ", strip=true) ==
      @html_parser.to_text(
        root,
        separator=" ",
        strip=true,
        separator_blocks_only=true,
      )
    },
    count=1000,
    seed=20260905,
  )
}

///|
test "property: arbitrary text survives escaping and reparsing" {
  @qc.check(
    (input : AnyText) => {
      let text = input.text()
      for parent in ["p", "td", "li", "span", "option", "pre"] {
        // `pre` drops a leading newline when parsed, so the text is placed
        // after a sentinel character.
        let node = @html_parser.element(parent, children=[
          @html_parser.text("."),
          @html_parser.text(text),
        ])
        let html = @html_parser.to_html(node, pretty=false)
        let back = @html_parser.parse_fragment(html).root.text()
        // The tree builder maps form feed to a space in all DOM text, a
        // documented normalization inherited from the reference parser.
        if back != "." + text.replace_all(old="\u{000C}", new=" ") {
          return false
        }
      }
      true
    },
    count=1500,
    seed=20260906,
  )
}

///|
test "property: arbitrary attribute values survive escaping and reparsing" {
  @qc.check(
    (input : AnyText) => {
      let value = input.text()
      for quote in ['"', '\''] {
        let node = @html_parser.element("span", attrs={
          "title": Some(value),
          "data-x": Some(value),
        })
        let html = @html_parser.to_html(node, pretty=false, quote~)
        guard @html_parser.parse_fragment(html).root.children() is [span, ..] else {
          return false
        }
        // An empty value serializes as a bare attribute name, which parses
        // back as a valueless attribute: the same attribute in HTML.
        let expected = if value.is_empty() { None } else { Some(value) }
        if span.attrs().get("title") != Some(expected) ||
          span.attrs().get("data-x") != Some(expected) {
          return false
        }
      }
      true
    },
    count=1500,
    seed=20260907,
  )
}

///|
/// The code point a numeric character reference decodes to, per the HTML
/// "numeric character reference end state".
fn numeric_reference_model(code : Int64) -> Char {
  if code == 0L || code > 0x10FFFFL || (code >= 0xD800L && code <= 0xDFFFL) {
    return '\u{FFFD}'
  }
  let c1 : Map[Int64, Int] = {
    0x80: 0x20AC,
    0x82: 0x201A,
    0x83: 0x0192,
    0x84: 0x201E,
    0x85: 0x2026,
    0x86: 0x2020,
    0x87: 0x2021,
    0x88: 0x02C6,
    0x89: 0x2030,
    0x8A: 0x0160,
    0x8B: 0x2039,
    0x8C: 0x0152,
    0x8E: 0x017D,
    0x91: 0x2018,
    0x92: 0x2019,
    0x93: 0x201C,
    0x94: 0x201D,
    0x95: 0x2022,
    0x96: 0x2013,
    0x97: 0x2014,
    0x98: 0x02DC,
    0x99: 0x2122,
    0x9A: 0x0161,
    0x9B: 0x203A,
    0x9C: 0x0153,
    0x9E: 0x017E,
    0x9F: 0x0178,
  }
  match c1.get(code) {
    Some(mapped) => mapped.unsafe_to_char()
    None => code.to_int().unsafe_to_char()
  }
}

///|
/// A code point for a numeric reference, drawn from the special ranges and
/// from everywhere else.
struct RefCode {
  code : Int64
}

///|
impl Debug for RefCode with fn to_repr(self) {
  Repr(self.code.to_string())
}

///|
impl @qc.Arbitrary for RefCode with fn arbitrary(_size, state) {
  let code : Int64 = match state.next_positive_int() % 5 {
    0 | 1 => pick(fuzz_code_points, state).to_int64()
    2 => (0x80 + state.next_positive_int() % 0x20).to_int64()
    3 => (state.next_positive_int() % 0x110000).to_int64()
    _ =>
      // Values far past the last code point, which must not overflow into a
      // valid one.
      0x110000L + state.next_int64().abs() % 0x7FFFFFFFFFFFL
  }
  { code, }
}

///|
impl @shrink.Shrink for RefCode with fn shrink(_self) {
  Iter::empty()
}

///|
test "property: numeric character references decode per the spec model" {
  @qc.check(
    (input : RefCode) => {
      let expected = "a" + numeric_reference_model(input.code).to_string() + "b"
      let forms = [
        "&#\{input.code};",
        "&#x\{input.code.to_string(radix=16)};",
        "&#X\{input.code.to_string(radix=16).to_upper()};",
        // Without the semicolon the reference ends at the first non-digit.
        "&#\{input.code}",
      ]
      for form in forms {
        let in_text = @html_parser.parse_fragment("<p>a\{form}b</p>").root.text()
        if in_text != expected {
          return false
        }
        let tag = @html_parser.parse_fragment("<p title=\"a\{form}b\">").root.children()
        guard tag is [p, ..] && p.attrs().get("title") is Some(Some(value)) else {
          return false
        }
        if value != expected {
          return false
        }
      }
      true
    },
    count=2000,
    seed=20260908,
    observe=input => {
      [
        @qc.classify(input.code >= 0x80L && input.code <= 0x9FL, "c1"),
        @qc.classify(
          input.code >= 0xD800L && input.code <= 0xDFFFL,
          "surrogate",
        ),
        @qc.classify(input.code > 0x10FFFFL, "out of range"),
      ]
    },
  )
}

///|
/// Legacy named references (ones that decode without a semicolon) and their
/// values. None of them is a prefix of another legacy name, so the longest
/// match is always the name itself.
let legacy_references : Array[(String, String)] = [
  ("amp", "&"),
  ("AMP", "&"),
  ("lt", "<"),
  ("LT", "<"),
  ("gt", ">"),
  ("quot", "\""),
  ("copy", "\u{00A9}"),
  ("REG", "\u{00AE}"),
  ("nbsp", "\u{00A0}"),
  ("not", "\u{00AC}"),
  ("Aacute", "\u{00C1}"),
  ("eacute", "\u{00E9}"),
  ("yen", "\u{00A5}"),
]

///|
/// A legacy reference followed by one character.
struct LegacyRef {
  reference : (String, String)
  next : Char
}

///|
impl Debug for LegacyRef with fn to_repr(self) {
  Repr("&\{self.reference.0}\{self.next}z")
}

///|
impl @qc.Arbitrary for LegacyRef with fn arbitrary(_size, state) {
  {
    reference: pick(legacy_references, state),
    next: pick(
      ['a', 'Z', '0', '9', '=', ';', ' ', '&', '-', '_', '#', '"', '\u{00E9}'],
      state,
    ),
  }
}

///|
impl @shrink.Shrink for LegacyRef with fn shrink(_self) {
  Iter::empty()
}

///|
test "property: legacy references follow the attribute-value special case" {
  // In text a legacy reference decodes even without its semicolon. In an
  // attribute value it stays literal when the next character is alphanumeric
  // or `=`, so query strings such as `?a=1&copy=2` survive unchanged.
  @qc.check(
    (input : LegacyRef) => {
      let (name, value) = input.reference
      let next = input.next
      let source = "&\{name}\{next}z"
      let decoded = if next == ';' { "\{value}z" } else { "\{value}\{next}z" }
      let in_text = @html_parser.parse_fragment("<p>\{source}</p>").root.text()
      let attr_source = source.replace_all(old="\"", new="&quot;")
      guard @html_parser.parse_fragment("<p title=\"\{attr_source}\">").root.children()
        is [p, ..] &&
        p.attrs().get("title") is Some(Some(in_attr)) else {
        return false
      }
      let expected_attr = if next.is_ascii_alphabetic() ||
        next.is_ascii_digit() ||
        next == '=' {
        source
      } else {
        decoded
      }
      in_text == decoded && in_attr == expected_attr
    },
    count=500,
    seed=20260909,
  )
}

///|
/// An `an+b` selector argument and a sibling count.
struct NthCase {
  a : Int64
  b : Int64
  count : Int
}

///|
impl Debug for NthCase with fn to_repr(self) {
  Repr(":nth-child(\{nth_argument(self.a, self.b)}) over \{self.count} items")
}

///|
/// Spell `a` and `b` as an `an+b` argument.
fn nth_argument(a : Int64, b : Int64) -> String {
  let sign = if b < 0L { "-" } else { "+" }
  "\{a}n\{sign}\{b.abs()}"
}

///|
/// A coefficient: mostly small, sometimes past the range of `Int`.
fn nth_coefficient(state : @splitmix.RandomState) -> Int64 {
  match state.next_positive_int() % 12 {
    0 => (1L << 32) + (state.next_positive_int() % 5).to_int64()
    1 => -((1L << 32) + (state.next_positive_int() % 5).to_int64())
    2 => 99999999999L
    // the edges of `Int`: -2147483648 is in range, 2147483648 is not
    3 =>
      [-2147483649L, -2147483648L, 2147483647L, 2147483648L][state.next_positive_int() %
      4]
    _ => (state.next_positive_int() % 13 - 6).to_int64()
  }
}

///|
/// Whether a coefficient fits in `Int`.
fn nth_in_int_range(x : Int64) -> Bool {
  x >= -2147483648L && x <= 2147483647L
}

///|
impl @qc.Arbitrary for NthCase with fn arbitrary(_size, state) {
  {
    a: nth_coefficient(state),
    b: nth_coefficient(state),
    count: state.next_positive_int() % 9,
  }
}

///|
impl @shrink.Shrink for NthCase with fn shrink(_self) {
  Iter::empty()
}

///|
test "property: nth-child agrees with the an+b formula" {
  // Reference model: the 1-based position `i` matches when `i = a*n + b` for
  // some `n >= 0`. A coefficient outside the range of `Int` matches nothing,
  // as in browsers, rather than wrapping around to a small number.
  @qc.check(
    (input : NthCase) => {
      let items = StringBuilder()
      for index in 1..<=input.count {
        items.write_string("<li>\{index}</li>")
      }
      let root = @html_parser.parse_fragment("<ul>\{items}</ul>").root
      let selector = "li:nth-child(\{nth_argument(input.a, input.b)})"
      let actual = @html_parser.query(root, selector).map(node => node.text())
      let expected = []
      if nth_in_int_range(input.a) && nth_in_int_range(input.b) {
        for index in 1..<=input.count {
          let diff = index.to_int64() - input.b
          let matched = if input.a == 0L {
            diff == 0L
          } else {
            diff % input.a == 0L && diff / input.a >= 0L
          }
          if matched {
            expected.push(index.to_string())
          }
        }
      }
      actual == expected
    },
    count=2000,
    seed=20260917,
    observe=input => {
      [
        @qc.classify(
          !(nth_in_int_range(input.a) && nth_in_int_range(input.b)),
          "out of range",
        ),
        @qc.classify(
          input.a == -2147483648L || input.b == -2147483648L,
          "Int.MIN_VALUE",
        ),
        @qc.classify(input.a < 0L, "negative a"),
      ]
    },
  )
}

///|
/// A port number for a link, sometimes past the range of `Int`.
struct LinkPort {
  port : Int64
}

///|
impl Debug for LinkPort with fn to_repr(self) {
  Repr(self.port.to_string())
}

///|
impl @qc.Arbitrary for LinkPort with fn arbitrary(_size, state) {
  let port = match state.next_positive_int() % 4 {
    0 => (state.next_positive_int() % 70000).to_int64()
    1 => 65535L + (state.next_positive_int() % 3).to_int64()
    2 => (1L << 32) + (state.next_positive_int() % 70000).to_int64()
    _ => state.next_int64() & 0xFFFFFFFFFFL
  }
  { port, }
}

///|
impl @shrink.Shrink for LinkPort with fn shrink(_self) {
  Iter::empty()
}

///|
test "property: linkify accepts exactly the valid port numbers" {
  @qc.check(
    (input : LinkPort) => {
      let links = @html_parser.find_links(
        "see http://example.com:\{input.port}/x now",
      )
      links.is_empty() == (input.port > 65535L)
    },
    count=1000,
    seed=20260918,
    observe=input => [@qc.classify(input.port > 65535L, "invalid port")],
  )
}
