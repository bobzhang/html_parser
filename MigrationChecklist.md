# JustHTML to MoonBit Migration Checklist

This checklist tracks the remaining feature-parity work against the Python
reference implementation in `.repos/justhtml`.

## Current Baseline

- [x] DOM node model and builders
- [x] HTML serialization and text extraction
- [x] CSS-style DOM queries for common selectors and pseudo classes
- [x] Token data structures and tokenizer coverage for the ported states
- [x] Document and fragment parsing with source locations
- [x] Byte input parsing with BOM, transport label, and meta charset sniffing
- [x] Named and numeric entity handling
- [x] Raw text, RCDATA, script escaping, and comment scanner coverage
- [x] Foreign-content namespace adjustment and sanitizer hardening
- [x] Default sanitizer policy, URL rules, CSS URL filtering, and unsafe handling
- [x] Initial Markdown conversion
- [x] Mooncakes package metadata, GitHub repository, and CI

## Remaining Feature Work

- [ ] Linkify core text scanner
  - [x] Public `LinkMatch` and `LinkifyConfig` API
  - [x] Scheme, protocol-relative, `www.`, fuzzy domain, fuzzy IP, and email detection
  - [ ] `linkify-it` fixture coverage
  - [ ] IDNA/punycode handling parity
- [ ] Linkify DOM transform
  - [ ] Wrap text-node matches in `<a href=...>`
  - [ ] Skip existing anchors and preformatted text by default
  - [ ] Preserve template content behavior
- [ ] General transform pipeline
  - [ ] Transform specs: `Drop`, `Unwrap`, `Escape`, `Empty`, `Edit`, `EditDocument`
  - [ ] Attribute transforms: `EditAttrs`, `DropAttrs`, `AllowlistAttrs`, `MergeAttrs`
  - [ ] Utility transforms: `CollapseWhitespace`, `DropComments`, `DropDoctype`
  - [ ] URL/style transform specs and sanitizer transform integration
  - [ ] Compiled stages, selector limits, and deterministic application order
- [ ] Streaming API
  - [ ] `StreamSink` equivalent
  - [ ] Incremental token/tree event delivery
  - [ ] Tests ported from `tests/test_stream.py`
- [ ] CLI parity
  - [ ] Argument compatibility with Python `justhtml`
  - [ ] Parse/tokenize/sanitize/transform output modes
  - [ ] File and stdin handling
  - [ ] Tests ported from `tests/test_cli.py`
- [ ] Markdown parity sweep
  - [ ] Remaining escaping, code span, fence, list, and block edge cases
  - [ ] Tests ported from Python Markdown coverage
- [ ] Full conformance harness
  - [ ] Import or translate tokenizer fixtures
  - [ ] Import or translate tree-builder fixtures
  - [ ] Import or translate encoding fixtures
  - [ ] Regression harness for JustHTML-specific `.dat` and `.test` files
- [ ] Documentation and warning cleanup
  - [ ] Public API docs for warning 74
  - [ ] Remove unnecessary annotations for warning 73
  - [ ] Remove unnecessary view conversions for warning 75
  - [ ] Qualify README checked examples for warning 25

## Working Rule

Port one feature slice at a time. Each slice should add focused tests, run the
MoonBit validation loop, and land in a small commit before the next slice.
