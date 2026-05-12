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
- [x] Initial public transform pipeline shell with structural, callback,
      utility, deterministic attribute, URL/style, and `Sanitize` DOM transforms

## Migration Roadmap

1. Finish the general transform pipeline: callback/report hooks, explicit
   stages, selector limits, and remaining transform edge-case tests.
2. Port the streaming API and `tests/test_stream.py` behavior.
3. Port CLI compatibility and `tests/test_cli.py` behavior.
4. Sweep Markdown parity against the remaining Python tests.
5. Add broader html5lib/JustHTML conformance fixture harnesses.
6. Clean up public docs and warning baselines.

## Remaining Feature Work

- [x] Linkify core text scanner
  - [x] Public `LinkMatch` and `LinkifyConfig` API
  - [x] Scheme, protocol-relative, `www.`, fuzzy domain, fuzzy IP, and email detection
  - [x] Representative `linkify-it` fixture smoke tests
  - [x] Full `linkify-it` fixture coverage
  - [x] IDNA/punycode handling parity
- [x] Linkify DOM transform
  - [x] Wrap text-node matches in `<a href=...>`
  - [x] Skip existing anchors and preformatted text by default
  - [x] Preserve template content behavior
- [x] General transform pipeline
  - [x] Public `TransformSpec` and `apply_transforms` API shell
  - [x] Structural transform specs: `Drop`, `Unwrap`, `Escape`, `Empty`
  - [x] Callback transform specs: `Edit`, `EditDocument`, `Decide`
  - [x] Attribute transforms: `SetAttrs`, `DropAttrs`, `AllowlistAttrs`, `MergeAttrs`
  - [x] Callback attribute transform: `EditAttrs`
  - [x] Utility transforms: `CollapseWhitespace`, `DropComments`, `DropDoctype`,
        `DropForeignNamespaces`
  - [x] Post-order utility transform: `PruneEmpty`
  - [x] Linkify transform integration and order-sensitive smoke tests
  - [x] `Sanitize` transform integration and order-sensitive smoke tests
  - [x] URL/style transform specs: `DropUrlAttrs`, `AllowStyleAttrs`
  - [x] Transform enabled flags
  - [x] Basic callback/report hooks for selector, edit, attribute, URL/style,
        comment, and doctype transforms
  - [x] Hook/report forwarding for `Linkify` and `CollapseWhitespace`
  - [x] Hook/report forwarding for `Sanitize`
  - [x] Hook/report forwarding for stage-level transforms
  - [x] Python-exact detailed report messages for sanitizer transforms
    - [x] Tag, attribute, URL, style, and meta-refresh sanitizer reports
    - [x] Comment and doctype drops as structural reports, not unsafe findings
    - [x] Invisible-Unicode attribute reports and unsafe-handling behavior
  - [x] Deterministic stage ordering, nested stage flattening, and implicit
        leading/trailing stage coverage
  - [x] Selector `Unwrap` moved-node walk marker parity
  - [x] Sanitizer policy selector `max_length` and `max_match_bytes`
        transform coverage
  - [x] Selector parse-depth, match-depth, and step-budget transform coverage
  - [x] Remaining compiled-walk marker edge cases
- [x] Streaming API
  - [x] Public string `stream` event API
  - [x] String tests ported from `tests/test_stream.py`
  - [x] Byte input stream decoding
  - [x] Incremental `StreamSink` equivalent
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
