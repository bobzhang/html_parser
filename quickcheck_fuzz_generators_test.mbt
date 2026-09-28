///|
/// Element names the fuzz generator opens and closes.
///
/// Unlike `html_chunks`, which is a fixed corpus of whole constructs, these are
/// combined with generated attributes, case changes and terminators, so the
/// tokenizer sees tags in shapes no corpus lists. Names are drawn from every
/// insertion mode the tree builder has: document structure, tables, lists,
/// forms, raw text, RCDATA, foreign content and its integration points, the
/// legacy elements with special parsing rules, and names the sanitizer must
/// refuse whatever their case.
let fuzz_tag_names : Array[String] = [
  "html", "head", "body", "title", "p", "div", "span", "a", "img", "b", "i", "u",
  "em", "strong", "s", "code", "pre", "h1", "h6", "blockquote", "br", "hr", "wbr",
  "table", "thead", "tbody", "tfoot", "tr", "td", "th", "caption", "col", "colgroup",
  "ul", "ol", "li", "dl", "dt", "dd", "form", "input", "button", "select", "option",
  "optgroup", "textarea", "label", "fieldset", "legend", "script", "style", "iframe",
  "noscript", "noembed", "noframes", "xmp", "plaintext", "template", "svg", "math",
  "foreignObject", "desc", "mi", "mtext", "annotation-xml", "mglyph", "malignmark",
  "object", "embed", "param", "video", "audio", "source", "frameset", "frame", "base",
  "link", "meta", "nobr", "applet", "marquee", "listing", "ruby", "rt", "rp", "image",
  "isindex", "keygen", "menu", "details", "summary", "area", "map", "font", "center",
  "custom-el", "x", "SCRIPT", "sCrIpT", "Svg", "IMG", "A",
]

///|
/// Attribute names, weighted towards the ones a sanitizer has to police.
let fuzz_attr_names : Array[String] = [
  "href", "src", "action", "formaction", "onclick", "onerror", "ONLOAD", "onmouseover",
  "style", "class", "id", "title", "lang", "dir", "srcset", "xlink:href", "xmlns",
  "xmlns:xlink", "background", "poster", "data", "lowsrc", "ping", "target", "rel",
  "width", "height", "alt", "colspan", "rowspan", "type", "name", "value", "definitionurl",
  "encoding", "color", "face", "size", "loading", "decoding", "HREF", "Src", "data-x",
]

///|
/// Attribute values, most of them trying to smuggle a script URL or a CSS
/// resource load past a naive check.
let fuzz_attr_values : Array[String] = [
  "", "x", "plain value", "javascript:alert(1)", "JaVaScRiPt:alert(1)", " javascript:alert(1)",
  "java\tscript:alert(1)", "java\nscript:alert(1)", "java&#x09;script:alert(1)",
  "&#106;avascript:alert(1)", "&#x6A;avascript:alert(1)", "jav&#97;script:alert(1)",
  "javascript&colon;alert(1)", "&#1;javascript:alert(1)", "\u{0001}javascript:alert(1)",
  "vbscript:msgbox(1)", "data:text/html,<script>alert(1)</script>", "data:image/png;base64,AAAA",
  "http://example.com/", "https://example.com/a?b=c#d", "HTTPS://EXAMPLE.COM", "//evil.example/x",
  "/relative/path", "relative", "#fragment", "?query", "mailto:a@example.com", "tel:+123",
  "ftp://example.com/", "file:///etc/passwd", "blob:https://x/y", "\\\\evil.example",
  "x.png 1x, javascript:alert(1) 2x", "a.png 1x, b.png 2x", "color: red", "color:red;background:url(javascript:alert(1))",
  "background-image: url(http://x/y)", "width: expression(alert(1))", "color: red; -moz-binding: url(x)",
  "b\\61 ckground: url(x)", "color: red /* c */; font-weight: bold", "@import 'x'",
  "font-size: 12px", "\"quoted\"", "'apos'", "a&b", "a<b>c", "&amp;&lt;&gt;&quot;",
  "\u{4F60}\u{597D}", "\u{1F600}", "noopener", "_blank",
]

///|
/// Text runs, covering what the serializer escapes, what the tokenizer treats
/// specially, whitespace the tree builder cares about, and characters that
/// stress UTF-16 handling or that the sanitizer strips as invisible.
let fuzz_text_runs : Array[String] = [
  "a", "hello world", " ", "  ", "\n", "\t", "\u{000C}", "\r\n", "\r", "&", "<",
  ">", "\"", "'", "=", "`", "/", "]]>", "--", "-->", "<!", "</", "\u{0000}", "\u{00A0}",
  "\u{00AD}", "\u{200B}", "\u{200E}", "\u{202E}", "\u{2028}", "\u{2066}", "\u{FEFF}",
  "\u{FFFD}", "\u{FFFE}", "\u{4F60}\u{597D}", "\u{1F600}", "\u{10FFFF}", "\u{E0041}",
  "\u{0085}", "\u{0080}", "\u{007F}", "\u{0001}", "e\u{0301}", "http://example.com/x",
  "www.example.com", "a@example.com",
]

///|
/// Standalone markup constructs that are not tags: declarations, comments in
/// their malformed spellings, processing instructions, CDATA, and fragments of
/// all of them cut short.
let fuzz_constructs : Array[String] = [
  "<!doctype html>", "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\">", "<!doctype>",
  "<!DOCTYPE html SYSTEM \"about:legacy-compat\">", "<!doctype x", "<!-- c -->",
  "<!---->", "<!-->", "<!--->", "<!-- a --!>", "<!-- a -- b -->", "<!-- unclosed",
  "<!--<!-- -->", "<?xml version=\"1.0\"?>", "<?", "<![CDATA[x<y]]>", "<![CDATA[",
  "<!x>", "</>", "</ >", "</3>", "<3", "<", "</", "<a", "<a ", "<a b", "<a b=", "<a b='",
  "<a b=\"", "<a/", "&", "&#", "&#x", "&#;", "&#x;", "&;",
]

///|
/// Named character references, including legacy ones that decode without a
/// semicolon, prefixes of longer names, and names that do not exist.
let fuzz_entity_names : Array[String] = [
  "amp", "AMP", "lt", "LT", "gt", "quot", "apos", "nbsp", "copy", "COPY", "not",
  "notin", "noti", "Aacute", "aacute", "ampx", "ltx", "reg", "euro", "hellip", "NotEqualTilde",
  "bogus", "zwnj", "zwj", "lrm", "rlm", "colon", "Tab", "NewLine", "lowast", "b.",
]

///|
/// Code points for numeric character references: every range the spec treats
/// specially (NUL, C1 controls remapped through windows-1252, surrogates,
/// noncharacters, out-of-range values) plus ordinary ones.
let fuzz_code_points : Array[Int] = [
  0, 1, 9, 10, 13, 32, 38, 60, 62, 65, 127, 128, 129, 130, 141, 143, 144, 150, 157,
  159, 160, 173, 0x2028, 0xD7FF, 0xD800, 0xDBFF, 0xDC00, 0xDFFF, 0xE000, 0xFDD0,
  0xFFFE, 0xFFFF, 0x1F600, 0x10FFFF, 0x110000, 0x7FFFFFFF,
]

///|
/// Single characters for the raw-noise generator.
let fuzz_noise_chars : Array[Char] = [
  '<', '<', '<', '>', '>', '/', '/', '&', '&', '#', ';', '=', '"', '\'', '`', '!',
  '-', '-', '?', '[', ']', ' ', '\n', '\t', '\r', '\u{0000}', '\u{000C}', '\u{0001}',
  '\u{007F}', '\u{0080}', '\u{009F}', 'a', 'b', 'p', 'x', 's', 'v', 'g', 'X', '0',
  '1', '9', 'x', '\u{00A0}', '\u{200B}', '\u{FEFF}', '\u{FFFD}', '\u{FFFF}', '\u{4F60}',
  '\u{1F600}', '\u{10FFFF}',
]

///|
/// Apply a case transformation to a tag or attribute name.
///
/// HTML names are ASCII case-insensitive, so every name-based decision — raw
/// text switching, allowlists, `on*` checks — must survive a change of case.
fn fuzz_case(name : String, state : @splitmix.RandomState) -> String {
  match state.next_positive_int() % 4 {
    0 => name.to_upper()
    1 => {
      let out = StringBuilder()
      for index, ch in name {
        out.write_char(
          if index % 2 == 0 {
            ch.to_ascii_uppercase()
          } else {
            ch
          },
        )
      }
      out.to_string()
    }
    _ => name
  }
}

///|
/// Generate one attribute, in any of the syntaxes the tokenizer accepts.
fn fuzz_attribute(state : @splitmix.RandomState) -> String {
  let name = fuzz_case(pick(fuzz_attr_names, state), state)
  let value = pick(fuzz_attr_values, state)
  let separator = pick([" ", " ", " ", "\t", "\n", "/", "\u{000C}"], state)
  match state.next_positive_int() % 6 {
    0 => "\{separator}\{name}"
    1 => "\{separator}\{name}='\{value}'"
    2 => {
      // Unquoted values end at whitespace, so only the first word survives.
      let word = value.split(" ").next().unwrap_or("").to_owned()
      "\{separator}\{name}=\{word}"
    }
    _ => "\{separator}\{name}=\"\{value}\""
  }
}

///|
/// Generate a start tag with attributes and one of several terminators,
/// including none at all.
fn fuzz_start_tag(state : @splitmix.RandomState) -> String {
  let out = StringBuilder()
  out.write_char('<')
  out.write_string(fuzz_case(pick(fuzz_tag_names, state), state))
  let count = match state.next_positive_int() % 5 {
    0 | 1 => 0
    2 | 3 => 1
    _ => state.next_positive_int() % 4 + 1
  }
  for _ in 0..<count {
    out.write_string(fuzz_attribute(state))
  }
  out.write_string(pick([">", ">", ">", ">", "/>", " >", " />", ""], state))
  out.to_string()
}

///|
/// Generate a character reference, named or numeric, with or without its
/// terminating semicolon.
fn fuzz_reference(state : @splitmix.RandomState) -> String {
  let semicolon = if state.next_positive_int() % 4 == 0 { "" } else { ";" }
  match state.next_positive_int() % 4 {
    0 | 1 => "&\{pick(fuzz_entity_names, state)}\{semicolon}"
    2 => "&#\{pick(fuzz_code_points, state)}\{semicolon}"
    _ => {
      let prefix = pick(["x", "X"], state)
      "&#\{prefix}\{pick(fuzz_code_points, state).to_string(radix=16)}\{semicolon}"
    }
  }
}

///|
/// Generate a short run of raw noise characters.
fn fuzz_noise(length : Int, state : @splitmix.RandomState) -> String {
  let out = StringBuilder()
  for _ in 0..<length {
    out.write_char(pick(fuzz_noise_chars, state))
  }
  out.to_string()
}

///|
/// Generate one chunk of structured-but-random markup.
fn fuzz_chunk(state : @splitmix.RandomState) -> String {
  match state.next_positive_int() % 20 {
    0 | 1 | 2 | 3 | 4 | 5 => fuzz_start_tag(state)
    6 | 7 | 8 => "</\{fuzz_case(pick(fuzz_tag_names, state), state)}>"
    9 | 10 | 11 => pick(fuzz_text_runs, state)
    12 =>
      "<!--\{pick(fuzz_text_runs, state)}\{pick(["-->", "--!>", "->", ""], state)}"
    13 | 14 => fuzz_reference(state)
    15 | 16 => pick(fuzz_constructs, state)
    17 => fuzz_noise(state.next_positive_int() % 8 + 1, state)
    18 => pick(html_chunks, state)
    _ => {
      // A burst of nesting. The depth is kept moderate: the tree builder's
      // scope checks are linear in the stack depth, so very deep documents are
      // covered by their own deterministic tests instead.
      let tag = pick(
        ["div", "b", "span", "table", "ul", "svg", "a", "p", "td"],
        state,
      )
      "<\{tag}>".repeat(state.next_positive_int() % 60 + 1)
    }
  }
}

///|
/// Generated markup: structured chunks, or raw noise, kept as the chunk list it
/// was built from so shrinking removes whole meaningful pieces.
struct MarkupFuzz {
  pieces : Array[String]
}

///|
/// Assemble the pieces into an input string.
fn MarkupFuzz::source(self : MarkupFuzz) -> String {
  let out = StringBuilder()
  for chunk in self.pieces {
    out.write_string(chunk)
  }
  out.to_string()
}

///|
impl Debug for MarkupFuzz with fn to_repr(self) {
  Repr(self.source())
}

///|
impl @qc.Arbitrary for MarkupFuzz with fn arbitrary(size, state) {
  // One input in eight is unstructured noise, one character per chunk so a
  // counterexample shrinks to the characters that matter.
  if state.next_positive_int() % 8 == 0 {
    let length = state.next_positive_int() % (size * 3 + 1) + 1
    let pieces = Array(capacity=length)
    for _ in 0..<length {
      pieces.push(fuzz_noise(1, state))
    }
    return { pieces, }
  }
  let count = state.next_positive_int() % (size + 1) + 1
  let pieces = Array(capacity=count)
  for _ in 0..<count {
    pieces.push(fuzz_chunk(state))
  }
  { pieces, }
}

///|
impl @shrink.Shrink for MarkupFuzz with fn shrink(self) {
  let length = self.pieces.length()
  if length <= 1 {
    return Iter::empty()
  }
  let candidates = [
    { pieces: self.pieces[:length / 2].to_owned(), },
    { pieces: self.pieces[length / 2:].to_owned(), },
  ]
  for skip in 0..<length {
    let rest = Array(capacity=length - 1)
    for index in 0..<length {
      if index != skip {
        rest.push(self.pieces[index])
      }
    }
    candidates.push({ pieces: rest, })
  }
  candidates.iter()
}

///|
/// Classify a generated input by the constructs it contains, so the
/// observation table shows the generator reaches every interesting path.
fn fuzz_observations(input : MarkupFuzz) -> Array[@qc.Observation] {
  let src = input.source().to_lower()
  [
    @qc.classify(src.contains("<table"), "table"),
    @qc.classify(src.contains("<svg") || src.contains("<math"), "foreign"),
    @qc.classify(src.contains("<template"), "template"),
    @qc.classify(src.contains("<script") || src.contains("<style"), "raw text"),
    @qc.classify(src.contains("<!--"), "comment"),
    @qc.classify(src.contains("&#"), "numeric ref"),
    @qc.classify(src.contains("javascript"), "script url"),
    @qc.classify(src.contains("\u{0000}"), "nul"),
    @qc.classify(
      src.contains("\u{1F600}") || src.contains("\u{10FFFF}"),
      "astral",
    ),
    @qc.classify(src.contains(" on"), "event attr"),
    @qc.classify(src.length() > 400, "long"),
  ]
}

///|
/// Plain text for escaping round trips, drawn from the whole of Unicode.
///
/// The characters the input stream preprocessor rewrites are excluded:
/// carriage returns are normalized to line feeds and U+0000 is dropped or
/// replaced, so neither can survive a serialize/parse round trip, by design.
struct AnyText {
  chars : Array[Char]
}

///|
fn AnyText::text(self : AnyText) -> String {
  String::from_array(self.chars)
}

///|
impl Debug for AnyText with fn to_repr(self) {
  Repr(self.text())
}

///|
/// Pick a character from a distribution weighted towards the ones the
/// serializer and tokenizer treat specially.
fn any_text_char(state : @splitmix.RandomState) -> Char {
  let code = match state.next_positive_int() % 10 {
    0 | 1 | 2 =>
      pick(
        [
          '&', '<', '>', '"', '\'', ';', '#', '=', '/', '!', '-', ' ', '\n', '\t',
          '\u{000C}', '\u{00A0}', ']',
        ],
        state,
      ).to_int()
    3 | 4 | 5 => 0x20 + state.next_positive_int() % 0x5F
    6 => 1 + state.next_positive_int() % 0x9F
    7 => 0xA0 + state.next_positive_int() % (0xD800 - 0xA0)
    8 => 0xE000 + state.next_positive_int() % (0x10000 - 0xE000)
    _ => 0x10000 + state.next_positive_int() % (0x110000 - 0x10000)
  }
  if code == 0x0D {
    'x'
  } else {
    code.unsafe_to_char()
  }
}

///|
impl @qc.Arbitrary for AnyText with fn arbitrary(size, state) {
  let length = state.next_positive_int() % (size + 1)
  let chars = Array(capacity=length)
  for _ in 0..<length {
    chars.push(any_text_char(state))
  }
  { chars, }
}

///|
impl @shrink.Shrink for AnyText with fn shrink(self) {
  let length = self.chars.length()
  let candidates = []
  for skip in 0..<length {
    let rest = Array(capacity=length - 1)
    for index in 0..<length {
      if index != skip {
        rest.push(self.chars[index])
      }
    }
    candidates.push({ chars: rest, })
  }
  candidates.iter()
}
