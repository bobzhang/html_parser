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

## Test Porting

- Python tests often compare rich object identity and class names. MoonBit tests
  should compare stable public behavior: serialized HTML, text output, fixture
  token lists, and parse error codes/locations.
- Snapshot-style `inspect` tests are useful for complex tree output, but stable
  assertion tests are better for focused behavior.
- When porting recursive output helpers, match the reference traversal state,
  not just the final join call. For example, `to_text(separator_blocks_only)`
  needs block-level chunks with a separate inline join separator.
