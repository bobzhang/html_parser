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
- Error positions are still UTF-16 offsets until converted to line/column.
  Match Python's EOF conventions deliberately: EOF after a trailing newline is
  reported at the next line, column 0, while EOF after trailing non-newline text
  uses the last character offset.
- For numeric HTML entities, use `Int::to_char()` and handle `None` for
  invalid Unicode scalar values. Do not use unchecked conversion unless the
  value has already been validated. Match the Python reference error order:
  C0/C1 numeric references report `control-character-reference` before any
  replacement mapping, invalid scalars and surrogates decode to U+FFFD without
  extra errors, and digitless forms such as `&#x;` stay literal.
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
  parent list item. The same pattern applies to `<dt>`/`<dd>` in definition
  scope, where a nested `<dl>` terminates the search.
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
- Framesets are document state, not ordinary body children. Before body content
  appears, `<frameset>` scaffolds beside `<head>` instead of under `<body>`.
  `<frame>` is only kept while a frameset is open; ordinary start tags inside
  the open frameset are ignored immediately and their matching end tags report
  `unexpected-token-in-frameset` too. Non-whitespace tokens after the final
  `</frameset>` are ignored with
  `unexpected-token-after-frameset`; ordinary tags also report the reprocessed
  `unexpected-token-in-frameset`, while `<noframes>` remains allowed.
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
- The html5lib tree-test serializer is line-oriented and does not emit wrapper
  lines for `#document` or `#document-fragment`. Build it as an array of lines
  joined by `\n` so it has no trailing newline, and sort attribute lines by
  their displayed test-format names.
- DOM nodes are mutable object graphs, so port Python operations by preserving
  identity semantics instead of structural equality. Moving a node must detach
  it from its old parent, insert-before needs an identity scan with an append
  fallback, and append/insert must reject self-or-ancestor cycles.
- Clone mutable node metadata explicitly. Attribute maps should be copied on
  `attrs()` and `clone_node()`, and `override_attrs` must not become shared
  mutable state between the caller and the clone.
- Class selector matching must split class attributes on HTML whitespace
  (`space`, `tab`, `LF`, `FF`, `CR`), not just literal spaces. This matters for
  both parsed attributes and programmatically-created DOM nodes.
- Compound class selectors such as `.intro.first` and `p.intro.first` are not a
  single class token; every class fragment after `.` must match one class
  attribute token.
- The selector fast path still needs parser-like ordering rules. A limited
  compound selector can start with a tag or `*`, followed by `#id` and `.class`
  fragments in source order; tag matching is case-insensitive, while id and
  class matching are case-sensitive.
- Attribute selector names are case-insensitive in HTML, even for
  programmatically-created nodes whose attribute map may contain uppercase
  keys. Normalize names for matching, but keep exact attribute values
  case-sensitive.
- Attribute selector operators have distinct empty-value rules in the Python
  matcher: `^=`, `$=`, and `*=` do not match an empty expected value, while
  `~=` uses HTML-whitespace token matching and `|=` matches exact or
  hyphen-prefixed values.
- Selector lists should be evaluated per node, not by concatenating the results
  of separate queries. That preserves document order and prevents duplicate
  nodes for repeated entries such as `p, p`; split commas only outside
  attribute brackets and quoted attribute values.
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
  id, and normal pseudo matching element-only, but allow comment nodes to match
  exactly `:comment` so combinators such as `div > :comment` work.
- Keep `query()` and `matches()` semantics separate. Python `node.query(...)`
  searches descendants only and does not include `node` itself; use
  `matches(node, ...)` when the receiver should be tested directly.
- `:contains(...)` is a non-standard pseudo-class in the reference. It is
  case-sensitive, uses descendant text content, accepts quoted or unquoted
  arguments, and a quoted empty string matches every element.
- Quoted `:contains(...)` arguments use only minimal Python-style unescaping:
  escaped matching quotes and doubled backslashes collapse, other backslash
  sequences stay literal, and a trailing backslash remains part of the needle.
- DOM mutation must keep parent links and child arrays in sync. Only document,
  fragment, and element nodes accept children; adopting an existing child should
  detach it from its old parent, and removing a child must clear the child's
  parent link.
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
  per non-whitespace character. Non-table start tags in that context also use
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
  `noscript`, while the non-whitespace suffix is reprocessed into the body.
  A `</br>` in this mode first reports as an unexpected noscript end tag, then
  is reprocessed as the body-mode `br` recovery and reports again.
- Repeated `<html>` start tags are not normal element insertion. Once the
  document html element exists, report `unexpected-start-tag`, merge only
  missing attributes onto the existing html node, and drop the token.
- Repeated `<head>` starts are a JustHTML-specific recovery edge. A duplicate
  head start while the real head is open reports `unexpected-start-tag`, starts
  a transient duplicate head sibling, and document scaffolding later moves that
  duplicate head's children into the body. A following head element such as
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
  handling.
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
- Snapshot-style `inspect` tests are useful for complex tree output, but stable
  assertion tests are better for focused behavior.
- When porting recursive output helpers, match the reference traversal state,
  not just the final join call. For example, `to_text(separator_blocks_only)`
  needs block-level chunks with a separate inline join separator.
