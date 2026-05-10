# Python to MoonBit Porting Notes

These notes record the practical differences that matter while porting
JustHTML from Python to MoonBit.

## Strings and Unicode

- MoonBit `String` is UTF-16 encoded.
- `s[i]` returns a `UInt16` code unit, not a Unicode scalar value.
- `for ch in s` iterates Unicode-safe `Char` values.
- Prefer `StringView` for parser cursors and slices to avoid copying.
- `StringView` slices must respect UTF-16 character boundaries. If an index may
  come from arbitrary code-unit arithmetic, use `get_view(...)` and handle
  `None` instead of assuming the slice is valid.
- When a parser consumes a `Char`, advance by `ch.utf16_len()`, not by `1`.
- `StringBuilder::write_string` takes a `String`, not a `StringView`. Keep test
  fixture builders and hot parser helpers explicit about whether they are
  appending owned strings or views.
- When translating JSON fixture strings to MoonBit literals, decode the JSON
  escape first and then encode the MoonBit literal. A JSON input such as
  `"<title id\\\">"` contains both a backslash and a quote in the attribute
  name, so the MoonBit literal must preserve both as `"<title id\\\">"` and the
  expected attribute key is `"id\\\""`.
- Do not assume MoonBit's default `Array::sort()` ordering for `String` or
  tuple values matches Python's lexicographic ordering. When a fixture format
  requires stable code-point order, such as html5lib-style attribute output,
  use an explicit comparator that walks `StringView.get_char()` and advances by
  `Char::utf16_len()`.
- Error positions are still UTF-16 offsets until converted to line/column.
  Match Python's EOF conventions deliberately: EOF after a trailing newline is
  reported at the next line, column 0, while EOF after trailing non-newline text
  uses the last character offset.
- For many tree-builder start-tag parse errors, Python reports the close
  bracket, not the initial `<`. Keep both `start` and `tag_close_pos` in scope
  when dispatching state-specific handlers such as select mode, table mode, and
  foreign-content breakout.
- Character-token diagnostics can also be reported at the consumed token end
  rather than at the first character. After a closed document frameset, Python
  reports `unexpected-token-after-frameset` at the final non-whitespace
  character of the ignored text run.
- For numeric HTML entities, use `Int::to_char()` and handle `None` for
  invalid Unicode scalar values. Do not use unchecked conversion unless the
  value has already been validated. Match the Python reference error order:
  C0/C1 numeric references report `control-character-reference` before any
  replacement mapping, invalid scalars and surrogates decode to U+FFFD without
  extra errors, and digitless forms such as `&#x;` stay literal.
- C1 numeric references use the same Windows-1252 replacement table as byte
  decoding, so values such as `&#x83;` decode to U+0192 while still reporting a
  control-character-reference error for the original numeric value.
- HTML input-stream preprocessing is not the same as generic string handling:
  strip a leading U+FEFF BOM and normalize CR/CRLF to LF before exposing text,
  comment, or attribute values.
- Byte-oriented parser entry points need encoding sniffing before creating the
  parser string. Do not run every `BytesView` through UTF-8 lossy decoding:
  UTF-16 BOMs must be detected first, decoded with explicit endianness, and the
  resulting `ParsedHtml.encoding` should report the detected or transport
  label. A generic transport `utf-16` label still needs the BOM to choose byte
  order, while preserving `utf-16` as the reported label.
- HTML's default byte fallback is Windows-1252, not UTF-8. Latin-1 labels such
  as `iso-8859-1` also normalize to Windows-1252, and UTF-7 labels should be
  rejected by normalizing them to Windows-1252. ISO-8859-2 labels are a
  separate supported single-byte encoding with Central European mappings; do
  not route them through the Windows-1252 table.
- Encoding prescan works on raw bytes, not decoded text. Skip comments and
  quoted attributes in non-`meta` tags before trusting a `<meta charset=...>`
  declaration, trim the raw charset value range before label normalization, and
  normalize meta-declared UTF-16 labels back to UTF-8.
- The `http-equiv="Content-Type"` path is also byte-level. Extract `charset`
  from the `content` attribute after ASCII lowercasing and whitespace
  normalization; quoted, unquoted, and invalid/unterminated charset values have
  different fallback behavior. Raw quote bytes inside the `content` value are
  meaningful to the prescan, but valueless `http-equiv`/`content` attributes
  do not participate, and HTML entities such as `&quot;` are not decoded before
  charset extraction. Empty charset values after `charset=` still count as
  malformed content values and should fall back through the normal Windows-1252
  path instead of selecting UTF-8.
- Legacy single-byte encodings are not UTF-8 variants. Port them as explicit
  byte-to-code-point tables, and test non-ASCII bytes so label normalization
  and decoding are both covered. Include both remapped bytes and high bytes
  that map to the same Unicode code point; legacy tables often mix the two.
- Invalid transport encoding labels should not become the reported encoding.
  Treat them like a missing transport label and continue with BOM/meta/default
  sniffing.
- Valid transport encoding labels take precedence over BOM and meta sniffing.
  Keep tests for this because a natural refactor is to sniff BOM first, which
  would silently change byte-entry behavior.
- Empty or unsupported transport encoding labels behave like a missing label:
  fall back through BOM, meta prescan, and finally Windows-1252. Supported
  aliases such as `UTF16LE` should normalize the reported `ParsedHtml.encoding`
  while malformed trailing UTF-16 bytes are decoded lossily as U+FFFD, matching
  Python's forgiving byte-entry behavior.
- Byte-level prescan edge cases are easy to accidentally "fix" by decoding
  first. Keep explicit tests for unfinished comments/tags and unterminated
  quotes so malformed sniff-only markup does not change the selected encoding.
  A `<` inside a meta tag and EOF after `charset=` both make that sniff
  candidate fail.
- When the Python reference separates tokenizer and tree-builder states, a
  combined MoonBit parser still needs to preserve their error ordering. Initial
  doctype recovery after bogus markup is one example: tokenizer errors for the
  bogus token come first, then the deferred initial doctype error must be
  flushed before the real start/end tag is handled by the tree builder. The
  same ordering applies to invalid `<...` openers at the start of a document:
  report the invalid tag opener before the missing-doctype character error.
- Raw text and RCDATA elements need parser-state-specific text handling.
  `script`/`style` contents are not entity-decoded; `title`/`textarea`
  contents are entity-decoded but still stop only at their matching end tag.
  Body-mode start handling is still tag-specific: `<xmp>` and `<plaintext>`
  close an open `<p>` first, but `<title>` and `<textarea>` do not.
- Fragment contexts for literal text elements still need input-stream
  preprocessing. Even when `script`/`style`/`textarea` bypass normal tag
  insertion, normalize CR/CRLF to LF, replace U+0000 with U+FFFD and report
  `unexpected-null-character`, and let `textarea`/`title` stop before the
  matching end tag so the remainder is parsed as markup.
- `script` raw text has its own escaped and double-escaped state machine.
  Port it with direct scanner-level tests in addition to tokenizer tests: public
  token streams often hide whether `<!--`, `--`, `<script`, non-`script`
  words, and inner `</script>` boundaries took the intended branch.
  Double-escape start/end boundaries include ASCII whitespace, `>`, and `/`;
  similarly spelled names such as `<scriptx>` must stay in escaped mode. The
  dash-dash states are especially easy to flatten incorrectly: a `<` after
  `--` is emitted before the next escaped-less-than state reconsumes the
  following character, so cases such as `<!----<x` intentionally serialize with
  two `<` characters in the text.
- EOF in script escaped or double-escaped states is still tree-builder EOF
  recovery, not a tokenizer-side repair. Preserve the buffered text exactly
  (`<!--`, `<!---`, `<!--<script>--<`, etc.) and report
  `expected-named-closing-tag-but-got-eof` at the final source column.
- Scope-sensitive implied end tags need the same terminators as Python's tree
  builder. For example, a new `<li>` closes an earlier `<li>` only in list-item
  scope; a nested `<ul>` or `<ol>` terminates that search and must not close the
  parent list item. Non-terminator descendants such as `<span>` are skipped
  while searching for that earlier `<li>`. The same pattern applies to
  `<dt>`/`<dd>` in definition scope, where a nested `<dl>` terminates the
  search.
- Select insertion mode treats formatting end tags specially. `</b>` or `</a>`
  should report `unexpected-end-tag-in-select` when the matching formatting
  element is absent or was opened before the current `<select>`, but a matching
  formatting element inside the select still needs to close normally.
  Non-formatting unknown end tags keep the generic `unexpected-end-tag` path.
- Ruby annotation tags have their own implied-end rules. `<rp>` and `<rt>`
  generate implied end tags except for an open `<rtc>`, while `<rb>` and
  `<rtc>` only do so when the current node is already a ruby annotation. The
  later `</ruby>` follows the "any other end tag" path, so open annotations
  make it report `end-tag-too-early`; a stray `</ruby>` with no open ruby is
  still just a generic `unexpected-end-tag`.
- Not every empty tree-builder insertion is an HTML void element. `<keygen>`
  and fragment-mode `<frame>` are inserted empty but still serialize with end
  tags, while document body-mode `<frame>` is ignored with
  `unexpected-start-tag-ignored`.
- Foreign-content parsing is not just namespace inheritance. SVG tag and
  attribute names have spec-defined camel-case adjustments, MathML has its own
  `definitionURL` adjustment, and foreign attributes such as `xlink:actuate`
  must survive normalization. HTML integration points such as SVG
  `foreignObject`/`desc`/`title` and MathML `annotation-xml` with HTML
  encodings switch descendants back into the HTML namespace.
- Foreign-content breakout errors are reported at the offending start tag's
  close bracket in the Python reference, not at the `<`. Keep the scanner's
  `tag_close_pos` available when dispatching foreign start tags so
  `unexpected-html-element-in-foreign-content` lines up with fixtures.
- Keep fixtures for the long-tail SVG adjustment table. Names such as
  `altGlyphDef`, `animateMotion`, `animateTransform`, `feMorphology`,
  `fePointLight`, `feSpecularLighting`, `glyphRef`, and `textPath` are easy to
  miss, as are attributes such as `calcMode`, `clipPathUnits`, `keyPoints`,
  and `kernelUnitLength`. SVG `<font>` only breaks out to HTML when `color`,
  `face`, or `size` attributes are present.
- After public foreign-content fixtures prove the adjustment path reaches the
  DOM, cover the full SVG/foreign adjustment tables with whitebox helper tests.
  They keep rare spec spellings locked down without turning each table entry
  into a large parser fixture.
- MathML text integration points are mostly HTML islands, but `mglyph` and
  `malignmark` are explicit exceptions that stay in MathML. When checking
  foreign-content recovery against Python, remember to enable `collect_errors`;
  otherwise output may match while tree-builder error parity is untested.
- Sanitizer handling for foreign text integration points is stricter than
  ordinary child sanitization. SVG `title`/`desc` and MathML
  `mi`/`mn`/`mo`/`ms`/`mtext` should keep text only, with MathML `mglyph` and
  `malignmark` as the exceptions. Do this before unwrapping allowed or
  disallowed HTML descendants, or an active child can turn into surviving text.
  Keep mXSS regression tests that reparse sanitized foreign-content output;
  the serialized form must remain inert after a second parse, not merely after
  the first sanitizer pass.
- Active foreign-content tags remain unsafe even when a custom policy
  allowlists them. Drop SVG/MathML mutation or integration tags such as
  `animate`, `set`, `foreignObject`, and `annotation-xml` when the node is
  effectively foreign. "Effectively foreign" includes non-HTML namespaces and
  programmatic HTML-namespace descendants under an `svg` or `math` root; use
  that same broader predicate for `drop_foreign_namespaces`. Run this check
  before disallowed-tag unwrap/escape handling so active integration points are
  removed as whole subtrees during stabilization.
- Sanitizing a standalone non-container root can still produce a document
  fragment. If a disallowed root unwraps to multiple surviving children, match
  Python by returning the fragment wrapper instead of forcing one replacement
  node or assuming the returned node kind matches the input.
- Treat SVG paint/filter attributes as URL-capable even though they do not look
  like `href`/`src`. For effective foreign nodes, allowlisted attributes such as
  `fill`, `filter`, `mask`, and marker attributes still need conservative
  `url(...)` filtering. Use exact URL-policy rules keyed by the raw attribute
  name, such as `("rect", "fill")`; URL filters for these attributes should see
  `attr="fill"`, not a synthetic `style:<property>` key.
- `meta` refresh is a URL-bearing construct split across attributes. If
  `http-equiv` is `refresh`, drop the `content` attribute even when both names
  are policy-allowlisted; do not apply that rule to ordinary `content-type`
  metadata.
- `<base href>` is not an ordinary link URL. Drop it even when allowlisted,
  because preserving it can alter how later relative URLs resolve after
  sanitization. In `Collect` or `Raise` mode, route this through the same
  unsafe-attribute handling path as other dropped URL attributes, even when a
  `UrlPolicy` rule exists for `("base", "href")`.
- URL-bearing attributes are opt-in twice: the attribute allowlist must permit
  the name, and `UrlPolicy.allow_rules` must contain an exact tag/attribute
  rule. Missing URL rules drop even otherwise-allowlisted `href` and `src`
  values. This is stricter than ordinary attributes and prevents a custom
  allowlist from accidentally preserving navigations or network loads. Trim URL
  values before validation and drop empty results; an empty string is not a
  safe relative URL in the Python sanitizer.
- Attribute values use `String?` in the MoonBit DOM. Preserve `None` for
  allowlisted non-URL boolean attributes such as `disabled`, but drop valueless
  URL-bearing attributes (`href`, `src`, `style`, `srcset`, and similar) because
  Python treats them as unsafe; they should also go through the configured
  unsafe handling path so `Collect` and `Raise` see the drop.
- The parser lowercases HTML attribute names, but manually built DOM nodes can
  still contain mixed-case keys. Lowercase names inside the sanitizer before
  allowlist and URL-policy lookup, and serialize the normalized name when the
  attribute survives.
- `poster`, `action`, `formaction`, `data`, `cite`, and `background` are
  single URL values. Route them through the same exact-rule path as `href` and
  `src`; do not confuse object `data` with safe custom `data-*` attributes.
- `srcset` and `imagesrcset` are URL lists rather than single URL values. Port
  them as a separate attribute path: apply the exact tag/attribute rule, split
  comma-separated candidates, sanitize the first whitespace-delimited URL token
  of each non-empty candidate, preserve the descriptor, and drop the whole
  attribute if any candidate URL is unsafe.
- `ping` and `attributionsrc` are whitespace-separated URL lists. Reuse the
  exact tag/attribute rule for each token, normalize surviving tokens with a
  single space separator, and drop the whole attribute if any token is unsafe.
- URL proxying is a post-validation handling mode, not a way to bypass URL
  checks. First validate fragments, protocol-relative rewrites, schemes,
  hosts, and relative URL permission; only then rewrite the resulting URL
  through the policy-level or per-rule proxy. Encode the proxied parameter as
  UTF-8 with query-component safety only (`A-Z`, `a-z`, `0-9`, `-`, `.`, `_`,
  `~` stay unescaped), so `/`, `:`, `?`, `=`, and `#` are percent-encoded.
  In proxy mode, reject invalid scheme-like prefixes such as `1https:foo`
  before treating a value as relative; otherwise malformed navigations can be
  hidden behind the proxy rewrite.
- Python accepts a raw callable as `UrlPolicy.url_filter`; in MoonBit, wrap the
  callback with `UrlFilter::new` so `UrlPolicy` can still derive `Debug`.
  Apply the filter before validation and handling. For single URL attributes
  and CSS `url(...)`, filter each URL value with the exact tag/attribute key
  (`style:<property>` for CSS). For `srcset`/`imagesrcset`,
  `ping`/`attributionsrc`, filter the whole attribute value once before
  splitting it into candidates or tokens. If the filter returns `None`, an
  empty string, or a whitespace-only list for those attributes, drop the whole
  attribute.
- Framesets are document state, not ordinary body children. Before body content
  appears, `<frameset>` scaffolds beside `<head>` instead of under `<body>`.
  Python's `frameset_ok` flag is not simply "no start tags have appeared":
  paragraph, formatting, and block starts such as `<p>` or `<figure>` can still
  be discarded when a later `<frameset>` replaces the implicit body, while
  text, explicit `<body>`, headings, tables, forms, and most void elements make
  a later frameset ignored. If the MoonBit port defers creating the implicit
  `<body>` until scaffolding, the `<frameset>` handler must still remove those
  earlier implicit-body children and reset the stack before inserting the
  frameset.
  `<frame>` is only kept while a frameset is open; ordinary start tags inside
  the open frameset are ignored immediately and their matching end tags report
  `unexpected-token-in-frameset` too. Non-whitespace tokens after the final
  `</frameset>` are ignored with
  `unexpected-token-after-frameset`; ordinary tags also report the reprocessed
  `unexpected-token-in-frameset`, while `<noframes>` remains allowed. A start
  `<html>` inside an open frameset is another special case: Python reports
  `unexpected-start-tag` and reprocesses it through body-mode rules, so a
  following `<frameset>` or `<frame>` is ignored as a body-mode start rather
  than inserted as a nested frameset child.
- Some start tags have their own scope rules even when they look like ordinary
  elements. A repeated `<button>` searches default scope, reports
  `unexpected-start-tag-implies-end-tag`, closes the previous button, and then
  inserts the new one instead of nesting buttons. Table cells terminate default
  scope, so a `<button>` outside a table cell is not closed by another button
  started inside a later `<td>` or `<th>`.
- `<form>` is tracked as parser state, not just as whatever is on top of the
  open-element stack. A second `<form>` start reports `unexpected-start-tag`
  and is ignored without closing an open paragraph, while `</form>` clears the
  stored form element even if another end tag already popped it from the stack.
- `<select>` parsing has its own insertion-mode errors. A nested `<select>`
  closes the current select and reports `unexpected-select-in-select`; stray
  `</option>`/`</optgroup>` inside a select use
  `unexpected-end-tag-in-select`, not the generic unexpected-end-tag code.
  Outside a select, those same end tags are ordinary stray body end tags and
  must fall through to generic `unexpected-end-tag` handling.
  Some start tags such as `<input>`, `<textarea>`, and `<table>` also close the
  select with `unexpected-start-tag-in-select` and then get reprocessed in body
  mode. When table-internal tags are reprocessed outside an actual table, most
  starts are ignored while preserving text children; `<caption>` reports
  `unexpected-start-tag`, while `<td>`, `<tr>`, row groups, and `<colgroup>`
  report `unexpected-start-tag-ignored`. `<col>` is context-sensitive:
  document body mode ignores it outside tables, but fragment body mode keeps it
  as a void element.
- A select-reprocessed table cell can hit Python's "empty stack" fallback when
  a foreign-content ancestor has the name `td`/`th`. The reference's insertion
  mode reset looks at names before namespaces, drains the open-element stack
  while trying to close the non-HTML cell, and reprocesses the new `td`/`th` as
  a child of the document `html` element after `body`. Model this as a narrow
  parser recovery path; do not make ordinary table-internal starts outside a
  table insert nodes.
- Select insertion mode is parser state, not just a stack-name query. A foreign
  SVG/MathML element named `select` must not make a later HTML start tag behave
  as select-mode content. Once an HTML `<select>` has entered select mode,
  though, Python's reset logic can keep that mode alive through remaining
  foreign elements named `select`, even after the HTML select is closed.
- Foreign-content breakouts can also reset Python into table modes by name
  before namespace. A foreign SVG `<tr>` can put the reference into row mode;
  a later HTML `<tr>` drains the stack to the document shell and gets appended
  after `body`, with following non-whitespace text reporting
  `unexpected-character-implies-table-voodoo` rather than the ordinary
  `foster-parenting-character`.
- Fixture flags do not always map to public MoonBit options yet. The
  `#iframe-srcdoc` tree-builder flag changes Python's internal quirks mode, but
  the current MoonBit API does not expose quirks mode; port the observable tree
  and parse errors without adding an API flag until quirks mode itself is
  represented.
- Known-doctype checks are intentionally exact. Legacy doctypes such as HTML
  4.01 Transitional with the loose DTD still produce a doctype node, but they
  report `unknown-doctype`; do not collapse them into the accepted strict/legacy
  compatibility cases just because the name is `html`.
- Other select-mode starts report but stay inside the select: `<hr>` first
  closes the current `option`/`optgroup`, void-like starts such as `<br>` and
  `<img>` are inserted without pushing, and common containers such as `<div>`
  or `<button>` get matching `unexpected-end-tag-in-select` errors when closed.
  Fragment shell starts such as `<body>` and `<head>` are ignored in a select
  with the same `unexpected-start-tag-in-select` code, while their end tags fall
  through as generic unexpected ends. `<plaintext>` is also inserted inside the
  current select subtree, reports `unexpected-start-tag-in-select`, and then
  consumes the rest of the input as text without first closing an open `<p>`.
- Serializing `script`/`style` text nodes has a security edge case, especially
  for programmatically-created trees: neutralize matching `</script` or
  `</style` sequences only when the tag name is followed by EOF, HTML
  whitespace, `>`, or `/`. Do not escape all `<` characters in raw text, and
  do not alter non-boundaries such as `</scriptx>`.
- Sanitizing allowed raw-text elements needs a DOM-level hardening pass, not
  only serializer escaping. Join split text children before searching for
  `</script`/`</style`, drop any non-text children that were created
  programmatically, and clear allowed `<style>` contents if the CSS contains
  resource-loading constructs such as `@import`, `url(`, or `image-set(`.
  Make sanitizer decisions on normalized tag names while leaving the node's
  stored spelling alone; the MoonBit builder should preserve a programmatic
  `StYlE` node's name, the sanitizer should still clear unsafe CSS, and the
  result should serialize back as `StYlE`. Normalize policy tag collections such
  as `drop_content_tags` the same way so uppercase policy input still drops
  mixed-case programmatic roots as whole subtrees.
- The sanitizer's invisible-Unicode stripping applies to text nodes and
  attribute values before later checks. Keep the strip table aligned with the
  Python regex: zero-width/bidi controls, variation selectors, FEFF, BMP
  private-use characters, supplementary variation selectors, and supplementary
  private-use planes. In MoonBit, iterate by `Char` so ranges above U+FFFF are
  matched as scalar values rather than UTF-16 halves.
- URL serialization context is based on text content, not the serialized markup
  string. Match Python by trimming the text and percent-encoding its UTF-8
  bytes while preserving URL delimiter characters such as `/`, `?`, `&`, and
  `=`. Keep control-byte tests for the hex writer too; otherwise it is easy to
  only exercise common digits from spaces and non-ASCII examples.
- JavaScript-string serialization is not just quote and newline escaping.
  Preserve JSON/JS safety by escaping backslash, selected quote, control
  characters such as backspace/form-feed, `<`, `>`, and line/paragraph
  separators U+2028/U+2029. Match the reference context exactly: `&` is already
  HTML-escaped in the serialized markup and is not escaped again for JS.
- Python node `.text` is direct text-node data and returns an empty string for
  element/comment nodes; recursive text extraction is `to_text()`. The current
  MoonBit API already exposes `Node::text()` as a recursive convenience wrapper
  over `to_text(separator="", strip=false)`, so port Python `.text` assertions
  as `data()` for text nodes or as `to_text()` cases rather than changing that
  API casually.
- Markdown rendering needs two output paths like the Python `_MarkdownBuilder`:
  escaped text should collapse whitespace and guard line-start Markdown markers,
  while raw Markdown syntax such as `**`, link brackets, and code fences must be
  appended without escaping. A `to_text()` fallback misses both formatting and
  security-relevant escaping.
- Markdown line-start escaping for ordered lists is intentionally narrow:
  digit prefixes are escaped only for `N. ` and `N) ` forms. Similar prefixes
  such as `3x`, `4.no-space`, and `5)no-space` stay literal.
- Test Markdown through both parsed documents and direct DOM builders. The
  public `Node::to_markdown` path must ignore comments/doctypes, drop empty
  inline formatting, and escape direct text nodes exactly like parsed text.
- Fenced Markdown code blocks need delimiter selection from the raw code
  content, not a fixed triple-backtick string. Strip trailing newlines and the
  spaces/tabs that would sit immediately before the closing fence, and choose a
  fence longer than any backtick run inside the code.
- Inline code spans use the same longest-backtick-run rule, but CommonMark also
  needs a single padding space when the code content starts or ends with a
  backtick. Keep separate tests for leading and trailing backticks.
- Markdown block elements are not just tags with recursive children. Generic
  containers such as `div`, `section`, `article`, `footer`, and `aside` need
  a block-boundary newline after their rendered children, while inline/unknown
  containers can still stream their children directly. Do not insert a leading
  separator for these generic containers; Python will render `A<div>B</div>C`
  as `AB\n\nC`.
- Nested Markdown lists need the walker to carry `list_depth` into recursive
  children and render each `li` into the active builder. Rendering each list
  item through a separate string loses indentation, hides empty markers, and
  changes Python's blank-line behavior around paragraph children.
- Match the Python builder's `_rstrip_last_segment()` behavior before emitting
  a newline. Without this, list markers before block children render as `- `
  followed by a blank line instead of the reference `-` marker line.
- `script`, `style`, and `textarea` are block-like in Markdown output even when
  their content is dropped by default. Preserve surrounding text separation, and
  only emit the raw HTML itself when `html_passthrough` is enabled.
- Markdown intentionally preserves `<img>` and `<table>` subtrees as canonical
  compact HTML. Pair these tests with parser normalization because table
  serialization may include inserted row groups such as `<tbody>`.
- Some Markdown helper branches are easier to lose during a port because the
  public walker escapes text before applying line-start marker checks. Keep
  whitebox tests for helper-level cases such as `#heading` versus `# heading`,
  thematic breaks, ordered-list starts, empty link destinations, and raw
  builder newline accounting.
- Link text uses a distinct Markdown traversal. The reference flattens
  paragraphs, lists, blockquotes, and `<br>` inside `<a>` into spaces so the
  generated `[text](href)` does not contain block Markdown or blank lines.
  It still preserves inline code and raw table HTML, skips `<hr>`, and ignores
  non-`li` children when flattening lists.
- Link text is not plain text: inline formatting markers are preserved inside
  `[text](href)`, images remain compact HTML, generic block containers add a
  flattening space, and `script`/`style`/`textarea` only contribute when
  Markdown `html_passthrough` is enabled.
- Programmatic DOMs can place `Document` or `Fragment` nodes inside an element
  even when parsed HTML never would. Markdown link-text traversal still needs
  to recurse through those container node kinds so direct builders match Python.
- Markdown link destinations use Python `quote(..., safe=...)` semantics only
  after wrapping is required. Keep the safe-byte set explicit; printable bytes
  such as quotes and backslashes still need percent-encoding inside `<...>`.
- Attribute serialization has policy baked into the Python helper: `None`,
  empty string, and values that match the attribute name case-insensitively are
  minimized, while quoted values prefer single quotes only when that avoids
  escaping an embedded double quote.
- Serialization contexts re-escape the serialized HTML string. `HtmlAttrValue`
  therefore escapes existing `&gt;`/`&#39;` sequences again, while `JsString`
  applies JavaScript escapes after HTML serialization. Pretty output is a
  separate path and should be tested alongside compact output.
- Python rejects unsafe programmatic names during serialization, not at DOM
  builder time. In MoonBit this maps to `HtmlError::InvalidSerialization` from
  `to_html()`/`to_markdown()` paths that emit canonical HTML. Keep the tag name
  check ASCII-only (`[A-Za-z][A-Za-z0-9:_-]*`) and the attribute check
  `[A-Za-z_:][A-Za-z0-9:._-]*`. Invalid quote characters should raise for
  `JsString` and `HtmlAttrValue` contexts; plain HTML output may still normalize
  to the default double quote for compatibility with the earlier API.
- Pretty serialization of ordinary text-only elements collapses HTML whitespace
  and trims the result, but vertical tab is not HTML whitespace and must remain
  a normal character. Raw/preformatted text-only elements such as `script`,
  `style`, `pre`, and `textarea` should stay compact while preserving their
  text whitespace. Keep those raw/preformatted elements on the compact path
  even when a programmatic DOM gives them mixed children, because pretty
  indentation would inject new text into raw content.
- Pretty serialization has a second compact path for inline mixed content.
  Text nodes in that path normalize only formatting whitespace (`LF`, `CR`,
  `tab`, `FF`) to single spaces, preserving ordinary double spaces; elements
  with only inline element children still use multiline formatting for block
  containers unless there is visible text in the run. Inline containers can
  stay compact with only formatting-whitespace separators, but that separator
  text should become one space only when it is between children; the same
  applies to whitespace-only runs longer than two spaces. Edge whitespace is
  dropped in the compact fallback. Layout/block containers with visible inline
  mixed content have an extra smart-run path: formatting whitespace (`LF`,
  `CR`, `tab`, `FF`, or whitespace-only runs longer than two spaces) splits the
  children into indented inline runs, consecutive separators collapse, edge
  separators disappear, and ordinary spaces inside each run stay compact.
  Direct comment children also force this compact fallback, even when adjacent
  elements are block-level, because inserting indentation around comments
  changes the Python reference output. Do not compact when an inline wrapper
  contains a layout/block descendant.
  This layout-block set is broader than the text-extraction block set and
  includes names such as `caption`, `center`, `details`, `dialog`, `iframe`,
  `listing`, `marquee`, `menu`, `noframes`, `noscript`, `plaintext`, `search`,
  and `summary`. In the multiline fallback, trim rendered text-node lines and skip
  whitespace-only text nodes so indentation does not preserve source formatting
  gaps as visible text. Pretty `DocumentFragment` children need the same
  filtering: a whitespace-only fragment renders empty, and an element whose
  child lines all render empty falls back to compact children rather than
  emitting an empty multiline wrapper.
- The html5lib tree-test serializer is line-oriented and does not emit wrapper
  lines for `#document` or `#document-fragment`. Build it as an array of lines
  joined by `\n` so it has no trailing newline, and sort attribute lines by
  their displayed test-format names.
- DOM nodes are mutable object graphs, so port Python operations by preserving
  identity semantics instead of structural equality. Moving a node must detach
  it from its old parent, insert-before needs an identity scan with an append
  fallback, and append/insert must reject self-or-ancestor cycles. When exposing
  these helpers in MoonBit, prefer non-throwing results over Python exceptions:
  `replace_child` returns `None` when the old child is absent or the replacement
  would create a cycle, and `Some(old_child)` when replacement succeeds.
- Query traversal also needs identity bookkeeping. The Python selector walker
  seeds its visited set with the query root, so descendants are deduplicated by
  object identity, shared child references are returned once, and
  programmatically-created cycles cannot make `query()` recurse back into the
  root or loop forever. Descendant-combinator matching has its own ancestor
  visited set, seeded with the candidate node, so `matches()` also terminates
  on parent cycles while still allowing a real ancestor before the cycle to
  match. Text collection for `:contains(...)` uses a stack, a visiting set,
  and an identity-keyed text cache. When a child cycle reaches a node already
  being visited, Python caches that node's text as empty and skips its pending
  materialization, so text that appears elsewhere inside the cyclic subtree may
  still be ignored.
- Sanitization is easiest to port as DOM graph rewriting, not as string
  filtering. Match the reference by sanitizing children before unwrapping a
  disallowed element, then move those sanitized children into the old parent
  and update every parent pointer. Default-policy and document-policy behavior
  differ: the document policy keeps the document shell and doctype, while the
  regular default policy unwraps document scaffolding and drops doctype nodes.
  Nested `Document`/`Fragment` containers are not tags; recurse through their
  children instead of applying tag allowlists to the container itself.
  Standalone non-container roots such as `Text`, `Comment`, and `Doctype`
  still need the same policy decisions, so wrap them in a temporary fragment
  during sanitization and unwrap the result afterwards.
- Sanitizer policies contain mutable lookup tables in MoonBit (`Set`/`Map`), so
  default policy helpers should return fresh policy values rather than sharing
  one global object across tests. URL checks should inspect the normalized
  scheme while ignoring ASCII controls/whitespace in the scheme area, but keep
  the original value when it is allowed; protocol-relative links are rewritten
  only when the rule says to resolve them.
- Python's `UrlPolicy.allow_rules` uses tuple keys. In MoonBit, expose a small
  `UrlPolicyRule::new(tag, attr, rule)` wrapper and normalize it into an
  internal string-keyed map; this avoids depending on tuple-key hashing in the
  public API while still keeping exact tag/attribute rule semantics.
- Python's `UrlRule.allowed_hosts` is optional. The MoonBit constructor uses an
  empty `allowed_hosts` array to mean "no host restriction"; non-empty
  allowlists are lowercased and matched against the parsed host only, not the
  whole URL. Strip userinfo and port for matching, accept bracketed IPv6 by
  matching the inner host, and reject malformed bracket hosts or backslashes
  before applying the allowlist.
- URL attribute checks must run after attribute entity decoding. A URL that
  matches the scheme and host allowlists is still unsafe when the decoded value
  contains C0 controls, DEL, or a backslash, so reject those values before
  handling, proxying, or serializing the attribute.
- Python's `unsafe_handling` string mode maps more safely to a MoonBit enum.
  Keep `Strip` as the no-op default, make `Collect` append `ParseError` values
  with `category="security"`, and make `Raise` use a typed `HtmlError` variant
  so callers can handle sanitizer failures with `try?` instead of string
  matching. Cover standalone disallowed roots too; the wrapper used by
  `sanitize_dom` for non-container nodes must still raise on the tag rejection
  before any "return one child or fragment" cleanup can hide it.
- Python constants such as `CSS_PRESET_TEXT` often contain immutable
  collections. MoonBit `Array` values are mutable, and public uppercase values
  are not idiomatic, so expose presets as lowercase functions returning fresh
  arrays. That keeps callers from mutating shared sanitizer defaults.
- Python's parser defaults to sanitizing; this staged MoonBit port keeps parser
  defaults unsanitized while raw tree-builder parity tests are still being
  migrated. Because MoonBit optional arguments do not distinguish omitted
  booleans from explicit defaults, implement and test `sanitize=true` first,
  then flip the default only after raw parser tests consistently pass
  `sanitize=false`.
- Python's sanitizer can escape disallowed tags using original token spans.
  Until the MoonBit parser stores source-tag metadata, escape handling must
  reconstruct tag text from the normalized DOM. That keeps output safe and
  deterministic, but it cannot preserve source spelling details such as single
  quotes, self-closing slashes on non-void HTML elements, or missing end tags.
  The escaped start/end text wraps sanitized surviving children; do not drop
  children just because the disallowed element is `template`.
- `force_link_rel` is both an attribute-allowlist rule and a rewrite rule in
  the Python sanitizer. If it is non-empty, `rel` must be kept on `<a>` even
  when `allowed_attributes["a"]` does not include it, then existing rel tokens
  are split on HTML whitespace, lowercased, deduplicated in order, and merged
  with the forced tokens.
- Inline `style` sanitization is a second allowlist after attribute
  allowlisting. A policy that allows the `style` attribute but leaves
  `allowed_css_properties` empty should still drop `style`; only declarations
  with valid, explicitly allowed ASCII property names survive, and values that
  may load resources need a second URL-policy decision. Plain `url(...)` can
  be kept only with an exact `style:<property>` rule (or a wildcard tag rule
  such as `("*", "style:background-image")` in the Python API); sanitize the
  inner URL, then reserialize as `url('...')` only when the sanitized URL does
  not need CSS escaping. Keep rejecting `image-set(...)`, CSS escapes,
  obfuscated CSS comments, and legacy loader functions conservatively. The
  dedicated CSS `url(...)` sanitizer should reject any `/*` comment in the
  value, even a closed trailing comment, because it only supports plain URL
  function tokens. Treat malformed URL-function syntax as unsafe too:
  backslashes, control or DEL characters, empty URLs, missing delimiters, or
  unexpected non-separator text after `)` should drop that declaration rather
  than trying to repair it. URL filter output is still untrusted: run the
  filtered value through the same URL validation and CSS quote-safety checks
  before serializing it back into `url('...')`.
- Clone mutable node metadata explicitly. Attribute maps should be copied on
  `attrs()` and `clone_node()`, and `override_attrs` must not become shared
  mutable state between the caller and the clone. Deep clones should use an
  explicit stack rather than recursive calls so programmatically-created deep
  trees do not depend on backend stack limits. Python exposes both in-place
  `sanitize_dom` and clone-returning `sanitize`; in MoonBit, spell the clone
  path explicitly as `node.clone_node(deep=true)` followed by `sanitize_dom`,
  and test that the source tree is unchanged after sanitizing the clone. Also
  mutate returned attribute maps in tests to prove callers cannot modify node
  internals by editing an `attrs()` result or the original `override_attrs`
  map.
- Class selector matching must split class attributes on HTML whitespace
  (`space`, `tab`, `LF`, `FF`, `CR`), not just literal spaces. This matters for
  both parsed attributes and programmatically-created DOM nodes.
- Compound class selectors such as `.intro.first` and `p.intro.first` are not a
  single class token; every class fragment after `.` must match one class
  attribute token.
- The selector fast path still needs parser-like ordering rules. A limited
  compound selector can start with a tag or `*`, followed by `#id` and `.class`
  fragments in source order; tag matching is case-insensitive, while id and
  class matching are case-sensitive. A universal `*` may only be followed by
  another simple-selector marker such as `.`, `#`, `[`, or `:`; `*foo` is not a
  tag selector and should fail to match. Tag, id, and class selector names
  follow the same identifier rule as attribute selector names: malformed names
  such as `1box`, `#1id`, or `.1lead` should not match even when a
  programmatically-created DOM node has that literal name or value.
- Attribute selector names are case-insensitive in HTML, even for
  programmatically-created nodes whose attribute map may contain uppercase
  keys. Normalize names for matching, but keep exact attribute values
  case-sensitive. Selector attribute names still follow the reference tokenizer
  identifier rules: letters, `_`, `-`, non-ASCII starts, then those plus
  digits. Unsupported operators or namespace-like punctuation such as `!=` and
  `:` should not become literal attribute-name matches. The MoonBit
  `query`/`matches` API is non-throwing, so malformed attribute selectors with
  empty names, such as `[]`, `[=x]`, or `[~=x]`, should short-circuit to no
  match instead of becoming attribute lookups. Apply the same no-match rule to
  other malformed pieces such as
  unclosed attribute selectors, dangling `.`/`#` markers, unclosed functional
  pseudos, and leading, repeated, or trailing combinators.
- Attribute selector operators have distinct empty-value rules in the Python
  matcher: `^=`, `$=`, and `*=` do not match an empty expected value, while
  `~=` uses HTML-whitespace token matching and `|=` matches exact or
  hyphen-prefixed values.
- Quoted attribute selector values consume backslash escapes like the Python
  tokenizer: the backslash is dropped and the following character is literal.
  Keep the same escape awareness in the selector-list and combinator splitters
  so escaped quotes do not terminate the attribute selector early.
- Unquoted attribute selector values end at CSS whitespace in Python, after
  which `]` must follow. In MoonBit's non-throwing API, selectors such as
  `[data-name=example item]` should no-match instead of treating the whole
  whitespace-containing text as the expected value.
- Selector lists should be evaluated per node, not by concatenating the results
  of separate queries. That preserves document order and prevents duplicate
  nodes for repeated entries such as `p, p`; split commas only outside
  attribute brackets and quoted attribute values. Python's parser ignores empty
  selector-list entries after a valid first selector (`p,`, `p,,a`), but a
  leading comma is still an empty selector and should no-match in MoonBit's
  non-throwing API. Malformed non-empty entries such as `p, p[` or `p, > a`
  should invalidate the whole selector list; otherwise the non-throwing port
  would accidentally return the earlier valid selector's matches instead of
  preserving Python's parse-before-match behavior.
- Descendant selector matching is easiest to implement right-to-left: first
  match the target node, then walk parent links to satisfy each ancestor
  selector. Split descendant whitespace only outside attribute brackets and
  quoted attribute values.
- Child combinators use the same right-to-left shape, but the next selector to
  the left must match the immediate parent. Whitespace around `>` is syntax,
  not a descendant combinator, and `>` inside quoted attribute values must be
  ignored by the splitter.
- Adjacent sibling matching needs object identity, not structural equality.
  MoonBit can use `physical_equal` while scanning `parent.children`; remember
  CSS sibling combinators use previous element siblings, skipping text and
  comments.
- General sibling matching is the same scan as adjacent sibling, but keeps the
  latest previous element that matches the selector to the left. When matching
  right-to-left, set the current node to that sibling so earlier combinators
  continue from the correct place.
- Pseudo-class parsing starts as another simple-selector marker. For
  `:first-child` and `:last-child`, scan only element children under the parent;
  whitespace text nodes created by parsing must not affect child positions.
- Pseudo-class names are case-insensitive in the Python matcher, but their
  arguments are not normalized wholesale. Lowercase only the pseudo name before
  dispatching so `:Nth-Child(odd)` works without changing case-sensitive
  arguments such as `:contains("Click")`.
- `:only-child` should reuse the same element-only child semantics, not raw
  child-array length, because parser-inserted text nodes are not element
  siblings.
- The Python `:empty` behavior treats whitespace-only text as empty, ignores
  comments, and treats child elements or non-whitespace text as content.
- `:root` is still an element selector in the Python matcher: the document node
  itself does not match, but an element whose parent is the document or fragment
  root does.
- Type-position pseudo-classes such as `:first-of-type` and `:last-of-type`
  use the node's normalized element name and ignore non-element siblings.
- `:only-of-type` should be implemented from the same type-filtered sibling
  semantics as first/last-of-type, not from the total element child count.
- Functional pseudo-class arguments affect the selector tokenizer too:
  combinators, commas, and whitespace inside parentheses such as
  `:nth-child(2n + 1)` are argument text, not selector separators.
- Python's functional pseudo tokenizer tracks nested parentheses but does not
  make quoted pseudo arguments special. A `)` inside `:contains('a)b')` closes
  the function early and leaves trailing junk, while `:contains('a(b')` never
  balances; in MoonBit's non-throwing selector API, both should no-match.
- `:nth-of-type(...)` reuses the An+B formula parser from `:nth-child(...)`,
  but the 1-based index counts only element siblings with the same normalized
  tag name.
- `:nth-*` formulas should be normalized before parsing: remove whitespace and
  lowercase ASCII so `ODD`, `+n`, `-2n+5`, and spaced forms behave like the
  Python reference, while malformed signed pieces such as `+`, `2n+`, or
  repeated `n` fragments simply fail to match.
- `:not(...)` can reuse the selector-list matcher recursively. Keep the outer
  splitter parenthesis-aware so commas and markers inside `:not(.a, .b)` stay
  inside the argument.
- `:comment` is an explicit non-element selector. Keep universal, tag, class,
  id, and attribute matching element-only. Direct `matches(comment, ...)` still
  evaluates pseudo selectors such as `:empty`, `:not(...)`, and
  `:comment(...)`, but `query(...)` should only consider non-elements when an
  outer compound selector contains `:comment`; otherwise queries such as
  `:empty` should not return text or comment nodes.
- Keep `query()` and `matches()` semantics separate. Python `node.query(...)`
  searches descendants only and does not include `node` itself; use
  `matches(node, ...)` when the receiver should be tested directly.
- `:contains(...)` is a non-standard pseudo-class in the reference. It is
  case-sensitive, uses descendant text content, accepts quoted or unquoted
  arguments, and a quoted empty string matches every element.
- The reference's selector text content is not the same as MoonBit
  `to_text(separator="")`: it strips each text node and joins non-empty
  descendant chunks with spaces, so adjacent children `<span>a</span><span>b</span>`
  match `:contains("a b")`, not `:contains("ab")`.
- Quoted `:contains(...)` arguments use only minimal Python-style unescaping:
  escaped matching quotes and doubled backslashes collapse, other backslash
  sequences stay literal, and a trailing backslash remains part of the needle.
- DOM mutation must keep parent links and child arrays in sync. Only document,
  fragment, and element nodes accept children; adopting an existing child should
  detach it from its old parent, and removing a child must clear the child's
  parent link. If a programmatically-created node has a stale parent pointer
  that does not actually contain it, adoption should still replace that pointer;
  do not rely on the old parent's child list as the only source of truth.
- Some Python DOM mutation paths raise `ValueError` for invalid references or
  unsupported containers. This MoonBit port generally exposes total builder
  helpers instead: `remove_child` ignores missing children, invalid append/insert
  operations are no-ops, and `replace_child` reports failure with `None`.
- Python has a `track_node_locations` option with per-node `origin_offset`,
  `origin_line`, and `origin_col` fields. MoonBit exposes matching origin
  accessors that default to `None`, and the parser now threads source starts for
  ordinary parsed elements, text, comments, doctypes, special-text children,
  fragment raw-text wrappers, select-insertion helper starts, table column-group
  helpers, template table helpers, hidden input/form table helpers, foreign
  table recovery helpers, end-tag recovery elements, frameset helper insertions,
  html-fragment body markers, basic active-formatting reconstruction,
  adoption-agency replacement nodes, repeated formatting starts, the
  duplicate-entry cap, applet-like/template/caption active-formatting markers,
  and foster-parented table text when
  `track_node_locations=true`. The remaining risky paths are recovery-generated
  or relocated nodes in broader table/fragment insertion-mode helpers.
  Duplicated or reconstructed nodes should copy the original formatting node's
  origin rather than inventing a new one.
- `script` text is not just generic raw text. After `<!--`, the tokenizer can
  enter script escaped states: `--<` emits an extra literal `<`, `--</script>`
  leaves a literal `<` before the end tag, and `-->` returns to normal raw text.
  A `<script` token inside escaped script text can also enter double-escaped
  states where an inner `</script>` remains character data. Keep these states
  explicit instead of trying to repair the serialized output afterwards.
- A plausible script end tag can still fail while consuming the closing tag
  itself. For example, `</script/foo` first ends the script text, then reports
  `unexpected-character-after-solidus-in-tag`, `eof-in-tag`, and finally the
  named closing-tag EOF error; do not collapse this into ordinary text.
- EOF inside raw/RCDATA/plaintext content is a tree-builder concern in the
  reference, not a tokenizer error. The tokenizer still emits the character
  token and EOF; the parser reports the closing-tag EOF error at the final
  source character.
- Do not apply tree-builder text tweaks in tokenizer helpers. For example, the
  tokenizer preserves a leading newline in `<textarea>` text; the parser/tree
  builder is responsible for dropping it after the start tag has been inserted.
  The dropped initial newline includes CR and CRLF after input-stream
  normalization; `<title>` normalizes those newlines but does not drop them.
- Tokenizer recovery states still need the same text post-processing as normal
  data states. Invalid tag-open text decodes character references and honors
  XML coercion, while empty raw/RCDATA/plaintext content should emit no
  character token at all.
- Literal U+0000 handling depends on the tokenizer/parser state. Normal text
  data reports `unexpected-null-character` and drops the character, while
  attribute values and raw/RCDATA text report the same error and replace it
  with U+FFFD. Keep source offsets in UTF-16 code units when reporting the
  error location.

## Mutation and Object Shape

- Python classes freely attach mutable fields. In MoonBit, mutable record fields
  must be declared with `mut`.
- Arrays and Maps are mutable reference-like values. Pushing to an array does
  not require the array binding itself to be `mut`; rebinding the variable does.
- Keep public structs narrow. Internal tree-building state can be mutable, but
  callers should use methods instead of writing DOM fields directly.

## Package Shape

- Files inside one MoonBit package are compiled together. A private helper in
  `parser.mbt` is still visible to `tokens.mbt` when both files are in the same
  directory/package. This is useful for shared parsing tables such as raw-text
  element names, but it also means a "local" helper can silently affect several
  implementation files.
- Python modules often make boundaries obvious through imports. In MoonBit,
  file names are organizational only; use cohesive helper names and focused
  tests to make shared behavior explicit.
- Prefer one shared predicate/table for parser and tokenizer state categories
  when the HTML standard uses the same set. Duplicating lists such as raw-text
  element names quickly causes parser/tokenizer drift.
- If an early port uses a post-parse scaffolding pass, keep it stateful enough
  to mirror insertion modes. Document head elements belong in `<head>` only
  until body content or an explicit `<body>` has started; after that, the same
  tags remain in `<body>`.
- Fragment parsing does not reuse the document shell scaffolding rules. In body
  mode, `<html>`, `<body>`, and `<head>` starts are reported and ignored, their
  children stay in the current insertion location, and `</head>` is still an
  unexpected end tag.
- `FragmentContext("html")` is the exception to ordinary body-fragment parsing.
  The reference seeds a synthetic `<html>` element, starts before the head, then
  unwraps that synthetic root at finish. That means fragments return `<head>`
  and `<body>`/`<frameset>` siblings rather than an `<html>` wrapper. Head
  elements seen before body content belong in the synthetic head, a later
  `<head>` start is reported and ignored while its children continue in body
  mode, and a `<body>` start after body content only contributes missing body
  attributes. An early explicit `<html>` start is also shell-only and does not
  create or serialize a nested `<html>` node; after body content starts, the
  same `<html>` start is reported and ignored while its children remain in the
  body. Comments before an explicit `<body>` remain before the synthetic head,
  non-whitespace text before `<body>` starts body content, and a closed nested
  before-body `<html>` shell moves the reference into after-body handling, so a
  later `<body>` reports both `unexpected-token-after-body` and
  `unexpected-start-tag`. A later `<html>` shell can still be checked against
  the nested shell's before-body children: report `unexpected-start-tag`, then
  keep scaffolding head/body children normally.
- Treat an explicit HTML namespace on `FragmentContext` the same as the default
  namespace. `FragmentContext("table", namespace="html")` still uses table
  fragment insertion mode; the namespace value should not make it fall back to
  ordinary body mode.
- Frameset state still matters inside `FragmentContext("html")`: a leading
  frameset is allowed even though normal fragments reject document-shell
  behavior, whitespace after it is preserved, and non-whitespace tokens after
  the closed frameset are ignored with `unexpected-token-after-frameset`.
- Template contents are not ordinary children in the Python reference: they live
  in `Template.template_content`. A direct-child representation can serialize
  the same for early parser slices, but tree-construction rules still need a
  template-content context. Table structural tags inside `<template>` are not
  discarded by "outside table" guards, and `</template>` closes the template
  content stack without reporting generic misnesting for open descendants.
  Sanitizer code must also recurse through the chosen template-content
  representation so allowlisted template contents are preserved, and so a
  disallowed template unwraps to its sanitized content instead of dropping it.
  With a direct-child representation, clone template descendants through the
  normal child traversal; there is no separate `template_content` clone step.
  Port Python template markdown/text tests as ordinary direct-child traversal
  tests for now.
- A stray `</template>` before any document shell exists is a before-html end
  tag, but after an explicit `<head></head>` it is an ordinary after-head end
  tag. Preserve the different error codes so following text still creates the
  implicit body and lands there.
- Template table recovery stays active after a template caption/column group is
  closed. Structural starts such as `tbody` and direct `td`/`th` are reprocessed
  into table context, while `script`, `style`, and nested `template` starts are
  allowed without a foster-start error.
- The Python tree builder performs some finish-time DOM population in addition
  to token insertion. `<selectedcontent>` is parsed in select mode with normal
  select-mode parse errors, then populated after tree construction by appending
  deep clones of the selected `<option>` children, or the first option when no
  option has a `selected` attribute. Existing selectedcontent children are not
  cleared first. Guard the no-option case explicitly in MoonBit so this
  finish-time pass remains a no-op instead of indexing an empty option array.
- Document scaffolding also has to preserve explicit root-level `<head>` and
  `<body>` nodes, including attributes on `<body>`. Do not always synthesize
  fresh elements and then nest the parsed ones inside the body.
- Repeated document shell elements need merge rules, not simple nesting. Later
  `<body>` tags contribute missing attributes and their children to the first
  body element.
- The same first-wins merge applies to nested repeated `<html>` tags: merge
  missing root attributes, then process the nested html's children in order.
- Repeated shell tags can appear as siblings too, not only nested nodes. Normalize
  root-level repeated `<html>` elements before the head/body scaffolding pass.
- Finish-time document scaffolding has a few insertion-mode-shaped details:
  strip the leading whitespace prefix from the first text node that starts an
  implicit body under an explicit `<html>`, move children of a late `<head>` into
  the body, and preserve whitespace/comments that trail a valid frameset.
- Keep tokenizer flags separate from tree-builder effects. A `/>` slash should
  remain visible on the start-tag token, but in HTML tree construction only
  void elements actually self-close; non-void elements still receive later text
  and children.
- Some insertion modes can be approximated by a normalization pass while the
  port is still incremental. Keep those passes explicit and narrow: implicit
  table row groups/rows are reasonable. Foster-parenting table text is a
  separate tree-builder concern: when non-whitespace text is seen under a
  `table`/row-group/`tr` but not inside a `td`/`th`/`caption`, move the whole
  text run before the table while reporting `foster-parenting-character` once
  per non-whitespace character. One active-formatting exception is observable:
  if a misnested active `<a>` is no longer on the open-element stack, fostered
  table text reconstructs that `<a>` around the fostered text and reports
  `unexpected-implied-end-tag-in-table-view` when the table closes instead of
  the immediate character error. Non-table start tags in that context also use
  the foster-parenting insertion location; starts under `table` or row groups
  report `foster-parenting-start-tag`, and the matching end reports
  `unexpected-end-tag-implies-table-voodoo`. Table mode has narrow exceptions:
  `<input type=hidden>` and `<form>` stay inside `table`/row-group contexts
  with `unexpected-hidden-input-in-table` or `unexpected-form-in-table`, while
  row/cell/caption contexts use the normal body/table-cell behavior. `<style>`
  and `<script>` also stay in the current table context without foster-parenting
  errors. A nested `<table>` start in `table`/row-group/`tr` context is not a
  child table: report `unexpected-start-tag-implies-end-tag`, close the current
  table, and then insert the new table as the reprocessed start tag. Stray
  non-table-internal end tags in the same context first report
  `unexpected-end-tag-implies-table-voodoo` and then follow body-mode handling,
  so synthetic nodes such as the empty `<p>` from `</p>` are inserted before the
  open table instead of inside it. A direct `<td>`/`<th>` start under `table` or
  a row group still normalizes into an implied row, but it must report
  `unexpected-cell-in-table-body` once for the missing `<tr>`. The later
  `</table>` should close through any open cell/row/row-group/table frames
  without adding the generic `end-tag-too-early` error. Row-group mode also
  reprocesses structural table starts: a nested `<tbody>`, `<thead>`,
  `<tfoot>`, `<caption>`, or `<colgroup>` first closes the current row group so
  the new element becomes a table child, not a row-group child. A `<col>` start
  does the same, then table normalization must wrap contiguous `col` children in
  an implied `colgroup`; an explicit `colgroup` breaks that contiguous run. Row
  mode has the same reprocessing shape for structural starts: close the current
  `tr` first, then let row-group/table handling place the next `tr`, row group,
  caption, colgroup, col, or table at the right level. Cell mode adds one more
  layer: starts for another cell or a table structural element first close the
  current `td`/`th`, then the same row/row-group reprocessing rules apply. Do
  not only check the top stack entry for these closures: body-mode elements can
  be open inside a cell, row, row group, or caption, and the table mode must pop
  through them to the scoped table element before reprocessing the structural
  start.
  Caption mode follows that reprocessing pattern too: starts for table
  structure close the open `caption` with
  `unexpected-start-tag-implies-end-tag`, then the token continues in table
  context. `</table>` closes the caption silently before closing the table,
  while `</tbody>`, `</tfoot>`, and `</thead>` inside a caption are just
  `unexpected-end-tag` errors and leave the caption open. Generic end tags such
  as `</div>` behave the same way, so a later `</caption>` still closes the
  caption. EOF in caption mode follows body-mode EOF reporting
  (`expected-closing-tag-but-got-eof`) even though a table is open; rows, cells,
  and column groups still report `eof-in-table`.
  Column-group text is another special case: report
  `unexpected-characters-in-column-group`; non-whitespace is then reprocessed as
  table text and foster-parented, while whitespace stays in the colgroup.
  Non-`col` starts inside an open `colgroup` close it before reprocessing in
  table mode; a nested `<colgroup>` additionally reports
  `unexpected-start-tag-implies-end-tag`. End tags inside a `colgroup` follow
  the same reprocessing rule except for `</col>` and `</colgroup>` themselves.
- Fragment contexts for table elements are not ordinary body fragments. For a
  `table` context, seed a synthetic table insertion context but unwrap that
  synthetic wrapper before returning the fragment. Because there is no real
  table element in Python's fragment stack, foster-parented text and starts are
  appended at the current table-context position rather than moved before a
  visible table wrapper, and `</table>` reports `unexpected-end-tag` instead of
  closing the synthetic context. A nested `<table>` start in that mode also
  reports the failed synthetic close as `unexpected-end-tag` after
  `unexpected-start-tag-implies-end-tag`. Body-mode repairs such as `</br>`
  should insert their generated node at the synthetic table position before the
  wrapper is unwrapped, so the returned fragment contains `<br>`. `</br>` is
  also an error-order exception in table context: report its
  `unexpected-end-tag` at the opener before the table-voodoo error at the tag
  close.
- Row-group fragment contexts (`tbody`, `thead`, `tfoot`) need a synthetic
  table plus synthetic row group for insertion, then both wrappers are unwrapped
  from the returned fragment. Top-level table-structural starts other than rows
  and cells are ignored with `unexpected-start-tag`; otherwise they would be
  incorrectly inserted because the MoonBit synthetic row group is more concrete
  than Python's mode-only fragment context. A matching `</tbody>`/`</thead>`/
  `</tfoot>` also reports `unexpected-end-tag` and must not close that synthetic
  wrapper.
- A `tr` fragment context adds one more synthetic wrapper level. Direct cells
  are returned as fragment children, while top-level row/table structural starts
  are ignored with `unexpected-start-tag-implies-end-tag`. Non-table starts in
  that row context still use table foster-parenting error rules, but because the
  synthetic row is unwrapped they serialize where the row's children would have
  been.
- Cell fragment contexts (`td`, `th`) use synthetic table/row-group/row/cell
  wrappers, but the returned fragment is only the cell children. Structural
  starts that would close a real cell are ignored with
  `unexpected-start-tag-in-cell-fragment`; a nested `<table>` is still ordinary
  body content inside the cell and can produce foster-parenting text errors
  inside that nested table.
- Caption fragment context is mode-only, not a synthetic `<caption>` wrapper.
  Ordinary body content is inserted directly, but table-structural starts first
  report `unexpected-start-tag-implies-end-tag` and the failed synthetic caption
  close reports `unexpected-end-tag`. A `<table>` start is the exception: after
  those two errors it is reprocessed in body mode and future tokens no longer
  use caption insertion mode.
- Column-group fragment context is also mode-only. `<col>` starts are inserted
  as fragment children, but other starts are ignored with
  `unexpected-start-tag-in-column-group` or the nested-colgroup
  `unexpected-start-tag-implies-end-tag` error. Character tokens always report
  `unexpected-characters-in-column-group`; leading ASCII whitespace is kept,
  while the non-whitespace remainder is dropped.

## Optional Values and Defaults

- Python `None` maps naturally to `T?` in MoonBit data structures.
- Optional parameters use `name? : T`; inside the function this is `T?`.
- Optional parameters with defaults use `name? : T = default`; inside the
  function this is plain `T`.
- Avoid `name? : T?` unless a double option is intentional.
- Calls must pass optional parameters by label. After the required positional
  arguments, use `foo(value, flag=flag)` rather than `foo(value, flag)`.
- When a Python constructor carries parse options through object state, mirror
  that in the MoonBit parser record instead of accepting a public optional
  parameter and then `ignore(...)`-ing it. Flags such as `scripting_enabled`
  can affect tokenizer/tree-builder state transitions.
- Fragment-context options may need to seed parser/tokenizer state before the
  first token is read. Do not parse the input normally and try to repair the
  tree afterwards; contexts like `textarea` and `script` change whether `<` and
  `&` are markup at all.
- Disabled-scripting `<noscript>` under `<head>` is still head-mode recovery,
  not normal body parsing. Allow only head-safe start tags such as `link`,
  `meta`, and `style`; for most other starts or non-whitespace text, report the
  recovery error, pop `noscript`, and let the same token land in body mode.
  Character runs need a split: leading ASCII whitespace stays in the head after
  `noscript`, while the non-whitespace suffix is reprocessed into the body. If
  MoonBit XML coercion is enabled, coerce that preserved whitespace before
  appending it to the head. A `</br>` in this mode first reports as an
  unexpected noscript end tag, then is reprocessed as the body-mode `br`
  recovery and reports again.
- Repeated `<html>` start tags are not normal element insertion. Once the
  document html element exists, report `unexpected-start-tag`, merge only
  missing attributes onto the existing html node, and drop the token. Keep
  enough state for the following `<body>` or extra `</html>` to report the
  after-body/repeated-shell errors even though the DOM merge already happened.
- Repeated `<head>` starts are a JustHTML-specific recovery edge. A duplicate
  head start while the real head is open reports `unexpected-start-tag`, starts
  a transient duplicate head sibling, and either pops that duplicate when a
  body-mode start such as `<p>` arrives or lets document scaffolding later move
  the duplicate head's children into the body. A following head element such as
  `<title>` must therefore not be pulled back into the real head.
- Foreign-content integration points depend on attributes, not just tag names.
  MathML `annotation-xml` integrates HTML only for `encoding` values like
  `text/html`; missing or other values still break HTML starts out of MathML.
  Valueless attributes arrive as `None` in MoonBit maps, so compare them as an
  empty value rather than treating the attribute as absent.
- Select insertion mode has element-specific recovery. Some starts, such as
  `aside`, are parse-error tokens that should be ignored while their following
  text still belongs to the open `select`.
- Before the html element exists, end tags use different error codes from
  normal body-mode end tags. Ignore `</html>`, `</head>`, and `</body>` after
  the initial doctype error; recover `</br>` as a `br`; report
  `unexpected-end-tag-before-html` for other names.
- A function receiving an already optional value, such as a stored `String?`,
  should usually take a normal `arg : String?` parameter. Do not use an
  optional labeled parameter when the caller needs to pass `None` or `Some(...)`
  through directly.

## Errors

- Python exceptions are cheap to introduce during parsing. MoonBit APIs should
  prefer explicit `ParseError` values for recoverable HTML parse errors and only
  `raise` for API misuse or strict-mode failure.
- Keep parse errors stable by code, line, and column so fixture expectations do
  not depend on message wording.
- Thread both token start and close offsets through parser handlers. Several
  tree-builder diagnostics, especially end-tag recovery such as extra
  `</frameset>`, report at the closing `>` rather than at the opening `<`.
- Treat the current Python source as the oracle when checked-in fixtures
  disagree with it. For example, table foster-parented text now reports
  `foster-parenting-character` per non-whitespace character even though an old
  coverage fixture records a single `unexpected-character-implies-table-voodoo`
  diagnostic.
- Noncharacter input-stream errors are state-sensitive. Report
  `noncharacter-in-input-stream` while scanning data-state text and invalid
  tag-open recovery, but do not put it in a low-level `advance_char` helper or
  attributes and raw-text states will over-report compared with Python.
- Character-reference decoding has two results: decoded text and recoverable
  tokenizer errors. In MoonBit, keep those together in a small result record so
  callers can add the local slice offset before turning them into `ParseError`
  line/column positions.
- Attribute character-reference errors are reported when the attribute value is
  finished, not necessarily at the character-reference offset. Attribute mode
  also blocks legacy prefix matches such as `&notit`, while text mode decodes
  the `&not` prefix and reports the missing-semicolon recovery.
- Mirror those attribute character-reference fixtures through the parser, not
  only the public tokenizer. Unquoted attribute values take the same deferred
  error cursor path, so the parse error points at the consumed tag close rather
  than at the original `&`.
- Named character references are case-sensitive and not all semicolonless
  forms are allowed. Port the Python `html.entities.html5` behavior in layers:
  exact semicolon matches, legacy semicolonless names, then text-only longest
  legacy prefix recovery. This ordering is observable: `&notin;` is an exact
  non-legacy name and must not degrade into `&not` prefix recovery. `&nbsp;` is
  U+00A0, not an ASCII space.
- RCDATA character-reference errors use the closing tag cursor in the Python
  tokenizer, not the local entity offset. Keep script/rawtext paths separate:
  they preserve `&...` literally and should not report entity errors.
- Tree-builder EOF diagnostics are not one error per open stack entry. Match
  the reference by reporting the first still-open non-implied element, while
  allowing tags such as `p`, `li`, `option`, and table row/cell wrappers to
  close implicitly. Unfinished tables are a separate `eof-in-table` case.
- EOF positions still need character-boundary offsets. Do not compute the
  location of the final input character with `input.length() - 1`; that can
  land in the middle of a surrogate pair. Walk by `Char.utf16_len()` and keep
  the last valid offset.
- EOF after a final newline is different from EOF after ordinary text. The
  Python reference reports column zero on the next line for inputs ending in
  LF, CR, or CRLF, so EOF helpers need a separate newline-ending path instead
  of always reusing the final character column.
- EOF-before-tag-name uses that final-character location too. A bare `<`
  reports on `<`, and `</` reports on `/`; do not report the cursor position
  just past the end of the string.
- Empty-input EOF diagnostics can be a special case. If the reference reports
  column zero, constructing the `ParseError` directly is clearer than forcing
  it through a normal source-position helper that is one-based for real
  characters.
- Document-mode doctype errors are tree-builder errors, not tokenizer errors.
  The initial insertion mode ignores leading whitespace and comments, accepts
  one initial doctype, reports the first real token when that doctype is
  missing, and treats later or fragment doctypes as `unexpected-doctype`. If
  the parser emits those leading comment/whitespace nodes before seeing the
  doctype, the "initial doctype" check must still skip them.
- Doctype parsing has tokenizer and tree-builder pieces. Missing names are
  tokenizer errors (`expected-doctype-name-but-got-right-bracket` or
  `eof-in-doctype`) and produce an empty-name doctype with force-quirks; the
  document tree builder then reports `unknown-doctype`. Fragment parsing keeps
  the tokenizer error but ignores the doctype node after `unexpected-doctype`.
- Malformed external IDs follow the same split. `PUBLIC>` and `SYSTEM>` report
  tokenizer errors and set force-quirks, but the serialized node can still be a
  plain `<!DOCTYPE html>` and should not automatically get `unknown-doctype`.
- Known doctype recognition includes a small legacy allowlist, not only
  `<!DOCTYPE html>` and `SYSTEM "about:legacy-compat"`. Preserve the exact
  HTML 4.0/4.01 and XHTML public/system ID pairs so compatibility doctypes do
  not regress into `unknown-doctype` errors.
- Keep small state distinctions in doctype keyword recovery. `PUBLIC>` is a
  missing identifier, but `PUBLIC x>` and `PUBLIC` at EOF are missing quotes
  before the identifier; the system identifier path mirrors the public one.
- After a quoted public identifier, EOF without whitespace before a system
  identifier reports `missing-whitespace-between-doctype-public-and-system-identifiers`;
  an immediate non-quote character reports `unexpected-character-after-doctype-public-identifier`.
  With whitespace after the public identifier, EOF or a non-quote system token
  instead reports `missing-quote-before-doctype-system-identifier`.
- Doctype external-ID recovery is not a single-error decision. The tokenizer can
  report a missing separator before a system identifier and then continue into
  the system identifier state, so keep a list of local-offset errors instead of
  returning one `String?`.
- Doctype whitespace states are not generic `trim_start()`. The tokenizer skips
  all whitespace before the name, but after the name only the one delimiter
  character has already been consumed; a second space before `PUBLIC`/`SYSTEM`
  reports `missing-whitespace-after-doctype-name` and enters bogus-doctype
  recovery instead of parsing the external IDs.
- Force-quirks is tied to the tokenizer state, not just to whether an error was
  reported. `unexpected-character-after-doctype-system-identifier` and missing
  whitespace before a quoted identifier do not force quirks, while EOF/abrupt
  identifier states and public-identifier garbage do.
- Quoted doctype identifier recovery distinguishes `>` from EOF. An unclosed
  public/system identifier ending at `>` reports `abrupt-doctype-*-identifier`
  at the close bracket; the same input without `>` reports
  `eof-in-doctype-*-identifier` at the final character.
- Quoted doctype public/system identifiers still receive input-stream newline
  normalization: CR and CRLF become LF in the stored identifier. A trailing CR
  between a public identifier and `>` is just whitespace before the close
  bracket, not a missing system identifier.
- Null-character handling is state-specific inside doctypes too. Names and
  quoted public/system identifiers report `unexpected-null-character` and store
  U+FFFD, so a helper that only lowercases or normalizes newlines will silently
  diverge from the tokenizer. Python serialization may reject the resulting
  unsafe doctype name, so assert the parsed tree/errors for these cases instead
  of relying on `to_html()`.
- Tag and attribute name scanning is broader than a typical identifier parser.
  After a valid tag-name start, keep consuming until whitespace, `/`, or `>`;
  U+0000 in tag or attribute names reports `unexpected-null-character` and is
  stored as U+FFFD. Stopping at an ASCII-name predicate can turn part of the tag
  name into a bogus attribute and change raw-text behavior. For parser tests
  involving these unsafe recovered names, inspect `Node::name()`/`Node::attrs()`
  directly instead of relying on serializer behavior.
- EOF inside an ordinary start or end tag is not a best-effort partial tag. The
  tokenizer reports `eof-in-tag` at the final input character and emits no
  partial tag token; the tree builder likewise must not create or close a node
  from the unfinished markup.
- Initial document-mode doctype checks can be deliberately deferred. If the
  first significant construct is an unfinished comment or tag, report that
  tokenizer/tree-builder EOF error first, then report
  `expected-doctype-but-got-eof` at the same EOF location.
- Python's tokenizer states sometimes reconsume the current character when
  switching recovery modes. For `<?...`, the `?` is both the error location for
  `unexpected-question-mark-instead-of-tag-name` and the first character of the
  bogus comment data.
- The same reconsume idea applies to invalid tag opens such as `<*foo>`.
  Report `invalid-first-character-of-tag-name` at the character after `<`, then
  emit the whole run from `<` through the following data characters as text
  instead of splitting out a standalone `<` token.
- End-tag-open recovery does not skip whitespace. `</>` is an `empty-end-tag`
  error, while `</ >` reports `invalid-first-character-of-tag-name` at the
  character after `/` and recovers as a bogus comment whose data starts there.
- End tags still run through attribute and self-closing states in the tokenizer.
  Preserve attributes on end-tag tokens, and treat `/` after the end-tag name as
  a valid boundary for raw text matching.
- Raw/RCDATA matching only proves that an end tag starts at that offset. Inputs
  such as `</title/foo` should still close the special text element, then run the
  end-tag parser so `unexpected-character-after-solidus-in-tag`, `eof-in-tag`,
  and tree-builder EOF diagnostics are reported at the same cursor positions as
  Python.
- The same scanner must reject prefix-only end tags: `</titlex>` and
  `</stylex>` are text, not closes. Only `>`, `/`, or ASCII whitespace after the
  matched name is a valid boundary.
- Ordinary end tags use the same recovery states after the matched name.
  `</div/foo>` closes the open `div` but reports the bad solidus at the first
  recovered attribute character; `</d\u{0000}iv>` replaces the null before tree
  matching, so it becomes an unexpected end tag rather than a close for `div`.
- A bad slash in a start tag is not a separate MoonBit-only error. `<div /a>`
  reports `unexpected-character-after-solidus-in-tag`, then reconsumes `a` in
  the before-attribute-name state so it becomes a normal empty-valued attribute.
- The self-closing start tag state does not skip whitespace after `/`.
  `<img />` is self-closing because whitespace appears before `/`, but
  `<img/ >` reports `unexpected-character-after-solidus-in-tag` at the space.
- Attribute-name diagnostics are shared by tokenizer and tree builder paths.
  A leading `=` reports `unexpected-equals-sign-before-attribute-name`, while
  `<`, `"`, and `'` inside the name report
  `unexpected-character-in-attribute-name` but stay in the stored name.
- Missing attribute value is a before-attribute-value error after `=`, not a
  bare-attribute error. `<div attr>` has no `missing-attribute-value`, while
  `<div attr=>` reports it at the closing `>`.
- Unquoted attribute values also report without dropping the offending
  character. `"`, `'`, `<`, `=`, and backtick produce
  `unexpected-character-in-unquoted-attribute-value` and remain in the decoded
  attribute value.
- XML coercion is an opt-in tokenizer option in the Python reference. Keep it
  out of default parsing, and when enabled apply it after entity decoding for
  text-like tokens: form feed becomes a space, XML noncharacters become U+FFFD,
  and comment data rewrites `--` to `- -`.
- Tree building has a separate text normalization step: appended DOM text maps
  form feed to a normal space even when XML coercion is off. Keep tokenizer
  tests separate from parser/tree-builder tests so the opt-in tokenizer behavior
  does not hide the always-on DOM text normalization.
- After a quoted attribute value, the first non-whitespace character before the
  next attribute is reconsumed. Report `missing-whitespace-between-attributes`
  at that character unless it is `>` or `/`, because `/` enters the self-closing
  recovery path instead.
- Empty comments with abrupt closers are not EOF cases. `<!-->` and `<!--->`
  both emit an empty comment and report `abrupt-closing-of-empty-comment` at the
  closing `>`.
- Comment end states are not equivalent to searching for the next `-->`.
  `--!>` closes after `incorrectly-closed-comment`, and `--x` reports the same
  error before keeping the two hyphens and `x` in the comment data.
- Markup declarations are not just normal tag-open failures. In HTML content,
  malformed `<!...>` declarations become bogus comments after
  `incorrectly-opened-comment`, and `<![CDATA[` also becomes a bogus comment
  after `cdata-in-html-content`; the bogus comment data starts after `<!`.
- Bogus comments replace NULs with U+FFFD without adding a second
  `unexpected-null-character` error, but they still run input-stream newline
  normalization so CR and CRLF become LF in the emitted comment data. Keep that
  distinct from normal comment data, where NUL is itself a parse error.
- Do not normalize empty doctype names to `"html"` in serialization. The builder
  default should create `"html"`, but a parsed empty-name doctype serializes as
  `<!DOCTYPE>`.
- Python insertion modes sometimes carry parser state that is not visible in
  the DOM stack. For example, `<col>` inside `<template>` enters column-group
  handling while the current node is still `template`: preserve leading
  whitespace, drop the rest of the character token, and report the
  template-specific column-group error. If an unrelated end tag exits that
  state, keep enough synthetic table-mode state to report the reprocessed
  table-voodoo diagnostics on following end tags.
- The same hidden template table-mode state matters after explicit structural
  closes. `</tr>` and `</colgroup>` inside `<template>` close their element but
  defer the table-voodoo error to `</template>`, while `</tbody>`, `</thead>`,
  and `</tfoot>` also report `unexpected-end-tag` at their own close.
- Foster parenting can occur even when there is no `<table>` element on the
  MoonBit stack. In Python's template table modes, text in direct template
  `<tr>` or row-group content is inserted into the template content after the
  current structural element, with `foster-parenting-character` diagnostics.
- Caption recovery inside template content also reprocesses in table mode.
  After `<template><caption>...<tr>`, close the caption, report the implicit
  close, then process the row start as an in-table token, which may insert an
  implied `tbody` rather than a bare `tr`.
- A plain `</caption>` inside template content can also leave hidden table-mode
  state behind. The caption node is closed, but the following `</template>`
  still reports table-voodoo recovery.
- While that synthetic table-mode state is active, ordinary body starts such as
  `<p>` are inserted normally into template content but still report
  `foster-parenting-start-tag`; non-whitespace character tokens beneath them
  also report `foster-parenting-character`.
- The tokenizer/parser lowercases raw tag and attribute names first, but
  foreign content needs a second adjustment step. Preserve non-HTML node names
  in `element(..., ns="svg" | "math")`, then apply SVG tag-name casing
  (`lineargradient` -> `linearGradient`) and SVG/MathML attribute casing before
  inserting the node.
- Builder namespace inputs are user-facing aliases, not always the exact
  internal namespace string. Normalize `mathml` to the internal `math`
  namespace, and lowercase known namespace names before storing them on nodes.
- Foreign content is a parser mode, not just a namespace on the node. While the
  adjusted current node is SVG/MathML, bypass ordinary HTML insertion-mode
  special cases for non-breakout starts, honor self-closing syntax for all
  foreign elements, and pop back to HTML mode before reprocessing breakout tags
  such as `<div>` or `<font color>`. If the foreign subtree is nested inside an
  ordinary HTML ancestor, only the foreign nodes are popped; the reprocessed
  breakout tag is inserted under that HTML ancestor.
- End tags in foreign content walk the stack case-insensitively against
  adjusted SVG names. If the current foreign element is not the match, report
  `unexpected-end-tag` before popping an ancestor match; if the walk reaches an
  HTML node, reprocess the token in the normal HTML path so missing foreign end
  tags can produce both foreign-mode and HTML-mode diagnostics.
- Character tokens in foreign content also have tree-builder-specific null
  handling. The tokenizer-level `unexpected-null-character` still fires, but
  direct SVG/MathML foreign text reports `invalid-codepoint-in-foreign-content`
  and inserts U+FFFD; MathML text integration points keep normal HTML text
  handling, so U+0000 is removed after the parse error and a following form
  feed is normalized to a space.
- `<![CDATA[...]]>` is only a bogus comment in HTML content. Under an
  SVG/MathML current node, port it as literal text without entity decoding;
  then apply the same foreign-text null handling for direct foreign content and
  normal HTML text null handling at MathML text integration points.
- Foreign fragment contexts need the same temporary-context trick as table
  fragments. Seed the stack with an unrendered SVG/MathML context element so
  child tags inherit the foreign namespace and CDATA is parsed as text, then
  promote the wrapper's children back to the document fragment. Keep the
  wrapper on the stack through EOF if the reference reports the context as an
  unclosed element.

## Test Porting

- Python tests often compare rich object identity and class names. MoonBit tests
  should compare stable public behavior: serialized HTML, text output, fixture
  token lists, and parse error codes/locations.
- Mirror Python's lazy error collection explicitly: parse errors are tracked
  internally so strict mode can raise, but public `errors` stays empty unless
  `collect_errors=true` or a strict parse succeeds and returns its result.
- Tree-builder parse errors for tags are usually reported at the consumed
  token's current cursor, so line/column tests need to include newlines inside
  tag whitespace and quoted attributes. Normalize CR and CRLF before computing
  those positions.
- Keep `ParseError::new`'s direct-construction category default as `"parse"`,
  but tag parser-produced errors like Python does: lexical/tag/entity/input
  stream diagnostics are `"tokenizer"`, structural insertion-mode diagnostics
  are `"treebuilder"`, and sanitizer findings stay `"security"`.
- Python's `ParseError` has `__str__`, `repr`, and `as_exception()` helpers.
  MoonBit's value type currently exposes fields and derives equality/debug, so
  port those tests as field and equality assertions instead of formatting
  checks.
- Snapshot-style `inspect` tests are useful for complex tree output, but stable
  assertion tests are better for focused behavior.
- When porting recursive output helpers, match the reference traversal state,
  not just the final join call. For example, `to_text(separator_blocks_only)`
  needs block-level chunks with a separate inline join separator.
