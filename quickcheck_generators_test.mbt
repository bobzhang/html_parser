///|
/// Markup chunks the HTML source generator samples from.
///
/// The corpus deliberately mixes well-formed markup with the shapes that drive
/// the tree builder's recovery paths: unmatched end tags, implied end tags,
/// table and list scoping, raw-text and escapable-raw-text elements, foreign
/// content roots, form controls, templates, and malformed markup declarations.
let html_chunks : Array[String] = [
  // Ordinary flow content.
  "<p>", "</p>", "<div>", "</div>", "<span>", "</span>", "<section>", "</section>",
  "<h1>", "</h1>", "<br>", "<hr>", "<img src=\"a.png\" alt=\"a\">",
  // Formatting elements, which exercise the active formatting list.
   "<b>", "</b>", "<i>", "</i>", "<em>", "</em>", "<a href=\"/x\">", "</a>", "<nobr>",
  "<font color=\"red\">", "</font>",
  // Tables and lists, which exercise scoping and foster parenting.
   "<table>", "</table>", "<tbody>", "<tr>", "</tr>", "<td>", "</td>", "<th>", "<caption>",
  "</caption>", "<colgroup>", "<col>", "<ul>", "</ul>", "<ol>", "<li>", "</li>",
  "<dl>", "<dt>", "<dd>",
  // Escapable raw text, whose content is entity-decoded on the way in.
   "<textarea>", "</textarea>", "<title>t</title>", "<pre>", "\npre body", "</pre>",
  // Raw text, whose content is never entity-decoded.
   "<script>var x = 1 < 2;</script>", "<style>p { color: red }</style>", "<xmp>x</xmp>",
  "<iframe>i</iframe>", "<noembed>n</noembed>", "<noframes>", "</noframes>", "<noscript>",
  "</noscript>", "<plaintext>",
  // Foreign content.
   "<svg>", "</svg>", "<math>", "</math>", "<foreignObject>", "</foreignObject>",
  "<svg viewBox=\"0 0 1 1\"><circle cx=\"1\"/></svg>", "<![CDATA[cdata]]>",
  // Sectioning roots, templates and form controls.
   "<template>", "</template>", "<form>", "</form>", "<input name=\"q\">", "<select>",
  "<option>", "</select>", "<button>", "</button>", "<fieldset>",
  // Document structure, often in the wrong place on purpose.
   "<!doctype html>", "<html>", "<head>", "</head>", "<body>", "</body>", "</html>",
  "<frameset>", "<frame>", "<base href=\"/\">", "<meta charset=\"utf-8\">",
  // Comments, entities and text.
   "<!-- comment -->", "<!--> ", "<!---->", "&amp;", "&lt;", "&#38;", "&#x26;", "&notanentity",
  "&", "text", "more text", " ", "\n", "\t", "\u{00A0}", "\u{4F60}\u{597D}",
  // Markup that the tokenizer must recover from.
   "<", ">", "</>", "</ >", "<p", "<p/", "<3", "<!x>", "<?pi>", "</p attr>", "<p id='a' id='b'>",
  "<p =v>", "<p a=>", "<p a=\"unclosed>", "<//>",
  // Unmatched end tags for elements that were never opened.
   "</div>", "</table>", "</span>", "</b>", "</svg>", "</template>",
  // Constructs the sanitizer must remove. Without these the sanitizer
  // property's rejection branches would be unreachable, and so vacuously true.
  // Every branch it asserts needs a chunk that can reach it.
   "<p onclick=\"alert(1)\">", "<img src=x onerror=alert(1)>", "<div ONMOUSEOVER=alert(1)>",
  "<a href=\"javascript:alert(1)\">", "<a href=\" JavaScript:alert(1)\">", "<form action=javascript:alert(1)>",
  // Schemes obfuscated with the control characters browsers ignore when they
  // resolve a URL, which a naive prefix test would read as safe.
   "<a href=\"java&#x09;script:alert(1)\">", "<a href=\"java&#x0A;script:alert(1)\">",
  "<a href=\"&#x01;JavaScript:alert(1)\">",
  // Markup carried *inside* text-tokenized elements. Without these the
  // properties that serialize individual nodes have no inert payload to watch,
  // since the payload has to start life as text rather than as an element.
   "<xmp><img data-qc-payload=? src=x onerror=1></xmp>", "<textarea><img data-qc-payload=? src=x onerror=1></textarea>",
  "<title><img data-qc-payload=? src=x onerror=1></title>", "<iframe><img data-qc-payload=? src=x onerror=1></iframe>",
  "<noscript><img data-qc-payload=? src=x onerror=1></noscript>", "<script><img data-qc-payload=? src=x onerror=1></script>",
  "<noembed><img data-qc-payload=? src=x onerror=1></noembed>",
  // A raw-text element inside a `noscript`, which only exists when scripting is
  // disabled. Its text carries a `</noscript>`, so serializing it literally
  // would go live as soon as anything reparsed with scripting enabled.
   "<noscript><xmp></noscript><img data-qc-payload=? src=x onerror=1></xmp></noscript>",
  "<noscript><textarea></noscript><img data-qc-payload=? src=x onerror=1></textarea></noscript>",
  // Active embedding elements.
   "<object data=x>", "</object>", "<embed src=x>",
]

///|
/// A generated HTML source document, kept as the chunk list it was built from.
///
/// Shrinking works on the chunk list rather than on the raw string, so a
/// counterexample reduces to a minimal sequence of meaningful markup pieces
/// instead of an arbitrarily truncated string.
struct HtmlSource {
  chunks : Array[String]
}

///|
/// Assemble the generated chunks into an HTML source string.
fn HtmlSource::source(self : HtmlSource) -> String {
  let out = StringBuilder()
  let mut next_id = 0
  for chunk in self.chunks {
    // Each injected payload gets its own id, so a property can tell one
    // occurrence going live from another going inert rather than netting them
    // against each other.
    if chunk.contains(DOM_PAYLOAD_PLACEHOLDER) {
      out.write_string(
        chunk.replace_all(
          old=DOM_PAYLOAD_PLACEHOLDER,
          new="\{DOM_PAYLOAD_ATTR}=\{next_id}",
        ),
      )
      next_id += 1
    } else {
      out.write_string(chunk)
    }
  }
  out.to_string()
}

///|
/// Report a counterexample as its HTML source rather than as a chunk list.
impl Debug for HtmlSource with fn to_repr(self) {
  Repr(self.source())
}

///|
impl @qc.Arbitrary for HtmlSource with fn arbitrary(size, state) {
  let count = if size <= 0 { 1 } else { size % 24 + 1 }
  let chunks = Array::new(capacity=count)
  for _ in 0..<count {
    chunks.push(html_chunks[state.next_positive_int() % html_chunks.length()])
  }
  { chunks, }
}

///|
impl @shrink.Shrink for HtmlSource with fn shrink(self) {
  let length = self.chunks.length()
  if length <= 1 {
    return Iter::empty()
  }
  // Halving converges quickly on long inputs; dropping single chunks then
  // removes whatever the halves could not.
  let candidates = [
    { chunks: self.chunks[:length / 2].to_owned(), },
    { chunks: self.chunks[length / 2:].to_owned(), },
  ]
  for skip in 0..<length {
    let rest = Array::new(capacity=length - 1)
    for index in 0..<length {
      if index != skip {
        rest.push(self.chunks[index])
      }
    }
    candidates.push({ chunks: rest, })
  }
  candidates.iter()
}

///|
/// Character runs the plain-text generator samples from.
///
/// The runs cover the characters the serializer must escape, characters the
/// tokenizer treats specially inside text, and non-ASCII text that has to
/// survive UTF-16 handling unchanged.
let text_runs : Array[String] = [
  "a", "hello world", "&", "<", ">", "\"", "'", "&amp;", "&lt;", "&#38;", "&notanentity",
  "<p>", "</p>", "<!--", "-->", "<![CDATA[", "]]>", " ", "\t", "\u{00A0}", "\u{4F60}\u{597D}",
  "\u{1F600}", "\u{FFFD}",
]

///|
/// A generated plain-text string, used for escaping round-trip properties.
///
/// Carriage returns and null characters are excluded on purpose: the input
/// stream preprocessor normalizes them, so they are not expected to survive a
/// round trip through the parser.
struct PlainText {
  runs : Array[String]
}

///|
/// Assemble the generated runs into a plain-text string.
fn PlainText::text(self : PlainText) -> String {
  let out = StringBuilder()
  for run in self.runs {
    out.write_string(run)
  }
  out.to_string()
}

///|
impl Debug for PlainText with fn to_repr(self) {
  Repr(self.text())
}

///|
impl @qc.Arbitrary for PlainText with fn arbitrary(size, state) {
  let count = if size <= 0 { 1 } else { size % 12 + 1 }
  let runs = Array::new(capacity=count)
  for _ in 0..<count {
    runs.push(text_runs[state.next_positive_int() % text_runs.length()])
  }
  { runs, }
}

///|
impl @shrink.Shrink for PlainText with fn shrink(self) {
  let length = self.runs.length()
  if length <= 1 {
    return Iter::empty()
  }
  let candidates = []
  for skip in 0..<length {
    let rest = Array::new(capacity=length - 1)
    for index in 0..<length {
      if index != skip {
        rest.push(self.runs[index])
      }
    }
    candidates.push({ runs: rest, })
  }
  candidates.iter()
}
