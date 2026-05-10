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
- For numeric HTML entities, use `Int::to_char()` and handle `None` for
  invalid Unicode scalar values. Do not use unchecked conversion unless the
  value has already been validated.
- HTML input-stream preprocessing is not the same as generic string handling:
  strip a leading U+FEFF BOM and normalize CR/CRLF to LF before exposing text,
  comment, or attribute values.
- Byte-oriented parser entry points need encoding sniffing before creating the
  parser string. Do not run every `BytesView` through UTF-8 lossy decoding:
  UTF-16 BOMs must be detected first, decoded with explicit endianness, and the
  resulting `ParsedHtml.encoding` should report the detected or transport
  label.
- HTML's default byte fallback is Windows-1252, not UTF-8. Latin-1 labels such
  as `iso-8859-1` also normalize to Windows-1252, and UTF-7 labels should be
  rejected by normalizing them to Windows-1252.
- Encoding prescan works on raw bytes, not decoded text. Skip comments and
  quoted attributes in non-`meta` tags before trusting a `<meta charset=...>`
  declaration, and normalize meta-declared UTF-16 labels back to UTF-8.
- The `http-equiv="Content-Type"` path is also byte-level. Extract `charset`
  from the `content` attribute after ASCII lowercasing and whitespace
  normalization; quoted, unquoted, and invalid/unterminated charset values have
  different fallback behavior.
- Legacy single-byte encodings are not UTF-8 variants. Port them as explicit
  byte-to-code-point tables, and test non-ASCII bytes so label normalization
  and decoding are both covered.
- Invalid transport encoding labels should not become the reported encoding.
  Treat them like a missing transport label and continue with BOM/meta/default
  sniffing.
- Valid transport encoding labels take precedence over BOM and meta sniffing.
  Keep tests for this because a natural refactor is to sniff BOM first, which
  would silently change byte-entry behavior.
- Byte-level prescan edge cases are easy to accidentally "fix" by decoding
  first. Keep explicit tests for unfinished comments/tags and unterminated
  quotes so malformed sniff-only markup does not change the selected encoding.
- Raw text and RCDATA elements need parser-state-specific text handling.
  `script`/`style` contents are not entity-decoded; `title`/`textarea`
  contents are entity-decoded but still stop only at their matching end tag.
  Body-mode start handling is still tag-specific: `<xmp>` and `<plaintext>`
  close an open `<p>` first, but `<title>` and `<textarea>` do not.
- Scope-sensitive implied end tags need the same terminators as Python's tree
  builder. For example, a new `<li>` closes an earlier `<li>` only in list-item
  scope; a nested `<ul>` or `<ol>` terminates that search and must not close the
  parent list item. The same pattern applies to `<dt>`/`<dd>` in definition
  scope, where a nested `<dl>` terminates the search.
- Ruby annotation tags have their own implied-end rules. `<rp>` and `<rt>`
  generate implied end tags except for an open `<rtc>`, while `<rb>` and
  `<rtc>` only do so when the current node is already a ruby annotation. The
  later `</ruby>` follows the "any other end tag" path, so open annotations
  make it report `end-tag-too-early`.
- Not every empty tree-builder insertion is an HTML void element. `<keygen>`
  and fragment-mode `<frame>` are inserted empty but still serialize with end
  tags, while document body-mode `<frame>` is ignored with
  `unexpected-start-tag-ignored`.
- Framesets are document state, not ordinary body children. Before body content
  appears, `<frameset>` scaffolds beside `<head>` instead of under `<body>`.
  `<frame>` is only kept while a frameset is open, and non-whitespace tokens
  after the final `</frameset>` are ignored with
  `unexpected-token-after-frameset`; ordinary tags also report the reprocessed
  `unexpected-token-in-frameset`, while `<noframes>` remains allowed.
- Some start tags have their own scope rules even when they look like ordinary
  elements. A repeated `<button>` searches default scope, reports
  `unexpected-start-tag-implies-end-tag`, closes the previous button, and then
  inserts the new one instead of nesting buttons.
- `<form>` is tracked as parser state, not just as whatever is on top of the
  open-element stack. A second `<form>` start reports `unexpected-start-tag`
  and is ignored without closing an open paragraph, while `</form>` clears the
  stored form element even if another end tag already popped it from the stack.
- `<select>` parsing has its own insertion-mode errors. A nested `<select>`
  closes the current select and reports `unexpected-select-in-select`; stray
  `</option>`/`</optgroup>` inside a select use
  `unexpected-end-tag-in-select`, not the generic unexpected-end-tag code.
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
  `<plaintext>` is also inserted inside the current select subtree, reports
  `unexpected-start-tag-in-select`, and then consumes the rest of the input as
  text without first closing an open `<p>`.
- Serializing `script`/`style` text nodes has a security edge case, especially
  for programmatically-created trees: neutralize matching `</script` or
  `</style` sequences only when the tag name is followed by EOF, HTML
  whitespace, `>`, or `/`. Do not escape all `<` characters in raw text, and
  do not alter non-boundaries such as `</scriptx>`.
- URL serialization context is based on text content, not the serialized markup
  string. Match Python by trimming the text and percent-encoding its UTF-8
  bytes while preserving URL delimiter characters such as `/`, `?`, `&`, and
  `=`.
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
- Link text uses a distinct Markdown traversal. The reference flattens
  paragraphs, lists, blockquotes, and `<br>` inside `<a>` into spaces so the
  generated `[text](href)` does not contain block Markdown or blank lines.
  It still preserves inline code and raw table HTML, skips `<hr>`, and ignores
  non-`li` children when flattening lists.
- Markdown link destinations use Python `quote(..., safe=...)` semantics only
  after wrapping is required. Keep the safe-byte set explicit; printable bytes
  such as quotes and backslashes still need percent-encoding inside `<...>`.
- Attribute serialization has policy baked into the Python helper: `None`,
  empty string, and values that match the attribute name case-insensitively are
  minimized, while quoted values prefer single quotes only when that avoids
  escaping an embedded double quote.
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
- EOF inside raw/RCDATA/plaintext content is a tree-builder concern in the
  reference, not a tokenizer error. The tokenizer still emits the character
  token and EOF; the parser reports the closing-tag EOF error at the final
  source character.
- Do not apply tree-builder text tweaks in tokenizer helpers. For example, the
  tokenizer preserves a leading newline in `<textarea>` text; the parser/tree
  builder is responsible for dropping it after the start tag has been inserted.
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
  current `td`/`th`, then the same row/row-group reprocessing rules apply.
  Caption mode follows that reprocessing pattern too: starts for table
  structure close the open `caption` with
  `unexpected-start-tag-implies-end-tag`, then the token continues in table
  context. `</table>` closes the caption silently before closing the table,
  while `</tbody>`, `</tfoot>`, and `</thead>` inside a caption are just
  `unexpected-end-tag` errors and leave the caption open.
  Column-group text is another special case: report
  `unexpected-characters-in-column-group`; non-whitespace is then reprocessed as
  table text and foster-parented, while whitespace stays in the colgroup.
  Non-`col` starts inside an open `colgroup` close it before reprocessing in
  table mode; a nested `<colgroup>` additionally reports
  `unexpected-start-tag-implies-end-tag`. End tags inside a `colgroup` follow
  the same reprocessing rule except for `</col>` and `</colgroup>` themselves.

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
- Tree-builder EOF diagnostics are not one error per open stack entry. Match
  the reference by reporting the first still-open non-implied element, while
  allowing tags such as `p`, `li`, `option`, and table row/cell wrappers to
  close implicitly. Unfinished tables are a separate `eof-in-table` case.
- EOF positions still need character-boundary offsets. Do not compute the
  location of the final input character with `input.length() - 1`; that can
  land in the middle of a surrogate pair. Walk by `Char.utf16_len()` and keep
  the last valid offset.
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
  missing, and treats later or fragment doctypes as `unexpected-doctype`.
- Doctype parsing has tokenizer and tree-builder pieces. Missing names are
  tokenizer errors (`expected-doctype-name-but-got-right-bracket` or
  `eof-in-doctype`) and produce an empty-name doctype with force-quirks; the
  document tree builder then reports `unknown-doctype`. Fragment parsing keeps
  the tokenizer error but ignores the doctype node after `unexpected-doctype`.
- Malformed external IDs follow the same split. `PUBLIC>` and `SYSTEM>` report
  tokenizer errors and set force-quirks, but the serialized node can still be a
  plain `<!DOCTYPE html>` and should not automatically get `unknown-doctype`.
- Keep small state distinctions in doctype keyword recovery. `PUBLIC>` is a
  missing identifier, but `PUBLIC x>` and `PUBLIC` at EOF are missing quotes
  before the identifier; the system identifier path mirrors the public one.
- After a quoted public identifier, EOF without whitespace before a system
  identifier reports `missing-whitespace-between-doctype-public-and-system-identifiers`;
  an immediate non-quote character reports `unexpected-character-after-doctype-public-identifier`.
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
- Null-character handling is state-specific inside doctypes too. Names and
  quoted public/system identifiers report `unexpected-null-character` and store
  U+FFFD, so a helper that only lowercases or normalizes newlines will silently
  diverge from the tokenizer.
- Tag and attribute name scanning is broader than a typical identifier parser.
  After a valid tag-name start, keep consuming until whitespace, `/`, or `>`;
  U+0000 in tag or attribute names reports `unexpected-null-character` and is
  stored as U+FFFD. Stopping at an ASCII-name predicate can turn part of the tag
  name into a bogus attribute and change raw-text behavior.
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
  `unexpected-null-character` error. Keep that distinct from normal comment
  data, where NUL is itself a parse error.
- Do not normalize empty doctype names to `"html"` in serialization. The builder
  default should create `"html"`, but a parsed empty-name doctype serializes as
  `<!DOCTYPE>`.

## Test Porting

- Python tests often compare rich object identity and class names. MoonBit tests
  should compare stable public behavior: serialized HTML, text output, fixture
  token lists, and parse error codes/locations.
- Snapshot-style `inspect` tests are useful for complex tree output, but stable
  assertion tests are better for focused behavior.
- When porting recursive output helpers, match the reference traversal state,
  not just the final join call. For example, `to_text(separator_blocks_only)`
  needs block-level chunks with a separate inline join separator.
