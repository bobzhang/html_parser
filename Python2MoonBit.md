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
- Raw text and RCDATA elements need parser-state-specific text handling.
  `script`/`style` contents are not entity-decoded; `title`/`textarea`
  contents are entity-decoded but still stop only at their matching end tag.
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
  table row groups/rows are reasonable, but foster parenting and full table
  error recovery should stay separate slices.

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
