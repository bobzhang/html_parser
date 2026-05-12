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

1. [x] Finish the general transform pipeline: callback/report hooks, explicit
   stages, selector limits, and remaining transform edge-case tests.
2. [x] Port the streaming API and `tests/test_stream.py` behavior.
3. [x] Port CLI compatibility and `tests/test_cli.py` behavior.
4. [x] Sweep Markdown parity against the remaining Python tests.
5. [x] Add broader html5lib/JustHTML conformance fixture harnesses.
6. [x] Clean up public docs and warning baselines.

## Remaining Feature Work

- [x] Linkify core text scanner
  - [x] Public `LinkMatch` and `LinkifyConfig` API
  - [x] Scheme, protocol-relative, `www.`, fuzzy domain, fuzzy IP, and email detection
  - [x] Representative `linkify-it` fixture smoke tests
  - [x] Full `linkify-it` fixture coverage
  - [x] IDNA/punycode handling parity
  - [x] Explicit mailto, IPv6 host preservation, and IDNA mapping regressions
  - [x] Internal validation and punctuation-run regression parity
- [x] Linkify DOM transform
  - [x] Wrap text-node matches in `<a href=...>`
  - [x] Skip existing anchors and preformatted text by default
  - [x] Preserve template content behavior
  - [x] Standalone text, exact-match text, no-link text, and leaf-node no-op behavior
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
- [x] CLI parity
  - [x] Argument compatibility with Python `justhtml`
  - [x] HTML, text, Markdown, sanitizer, and cleanup transform output modes
  - [x] File, stdin, and output-file handling
  - [x] Tests ported from `tests/test_cli.py`
- [x] Markdown parity sweep
  - [x] Remaining escaping, code span, fence, list, and block edge cases
    - [x] Orphan `li` block handling and link-text flattening
    - [x] Fragment `head`/`title` Markdown parity
    - [x] Link destination wrap triggers and control-character coverage
    - [x] Mixed-case programmatic tag dispatch
    - [x] Whitespace-only `<pre>` code block parity
    - [x] Whitespace-only `href` Markdown destination parity
    - [x] Newline-only `<pre>` code block parity
    - [x] Line-start non-trigger and spaced thematic marker coverage
    - [x] List non-`li` child skipping parity
    - [x] Builder leading-whitespace and raw-newline accounting coverage
    - [x] Public blockquote marker, multi-digit ordered marker, and two-item
          list parity
  - [x] Tests ported from Python Markdown coverage
    - [x] Deep programmatic tree, document-container, and builder edge tests
    - [x] Raw-text passthrough, empty `<br>`, and unknown-container tests
    - [x] Sanitized `<textarea>` Markdown passthrough breakout regression
    - [x] Explicit `Sanitize` transform boundary Markdown regression
    - [x] Foreign-namespace mXSS Markdown passthrough regression
    - [x] Public-API regressions for private Markdown builder branch tests
    - [x] Final audit against `.repos/justhtml/tests/test_node.py` Markdown
          tests
- [x] Full conformance harness
  - [x] Import or translate tokenizer fixtures
    - [x] `coverage_gaps.test`, `entities.test`, and
      `xml_coercion_coverage.test` token fixture rows
    - [x] `tokenizer_edge_cases.test` token fixture rows
  - [x] Import or translate tree-builder fixtures
    - [x] `iframe_srcdoc.dat` and `xml_coercion.dat` tree rows
    - [x] `treebuilder_coverage.dat` tree rows
    - [x] `branch_coverage.dat` tree rows
    - [x] `empty_stack_edge_cases.dat` tree rows
  - [x] Import or translate encoding fixtures
    - [x] Reference `test_encoding.py` byte decode and meta-prescan cases
  - [x] Regression harness for JustHTML-specific `.dat` and `.test` files
    - [x] Static tokenizer, tree-builder, and encoding fixture table runners
    - [x] Fixture row-count guards for translated vendored rows
- [x] Documentation and warning cleanup
  - [x] Public API docs for warning 74
    - [x] `tokens.mbt` tokenizer API docs
    - [x] `transforms.mbt` decide action docs
    - [x] `markdown.mbt` Markdown conversion docs
    - [x] `cli.mbt` embeddable CLI API docs
    - [x] `parser.mbt` parser entry point docs
    - [x] `serialize.mbt` serialization and selector docs
    - [x] `types.mbt` core model docs
    - [x] `stream.mbt` streaming API docs
    - [x] `sanitize.mbt` sanitizer policy docs
    - [x] `dom.mbt` public DOM API docs
  - [x] Remove unnecessary annotations for warning 73
    - [x] `comment_scan.mbt` constructor annotations
    - [x] `script_text.mbt` constructor annotations
    - [x] `tokens.mbt` constructor annotations
    - [x] `types.mbt` constructor annotations
    - [x] `markdown.mbt` constructor annotation
    - [x] `parser.mbt` helper constructor annotations
    - [x] `html_parser_test.mbt` enum constructor annotations
  - [x] Remove unnecessary view conversions for warning 75
    - [x] `foreign_content.mbt` view conversions
    - [x] `tokens.mbt` XML coercion view conversions
    - [x] `transforms.mbt` transform helper view conversions
    - [x] `serialize.mbt` serializer and selector view conversions
    - [x] `html_parser_wbtest.mbt` whitebox helper view conversions
    - [x] `parser.mbt` tree-builder helper view conversions
    - [x] `sanitize.mbt` sanitizer policy view conversions
  - [x] Qualify README checked examples for warning 25

## Post-Completion Audits

- [x] Ported the Wikipedia Markdown regression as a native CLI fixture smoke in
      CI, including title/body ordering, safe-mode protocol-relative link
      normalization, and footer project links.
- [x] Translated focused sanitizer JSON fixture rows for URL proxy handling,
      URL filters, protocol-relative URL validation, malformed scheme
      normalization, and template-content sanitization.
- [x] Translated sanitizer JSON fixture rows for forced `rel` deduplication,
      fragment/relative URL blocking, host allowlist checks, boolean attribute
      preservation, and foreign-namespace policy toggles.
- [x] Translated sanitizer JSON fixture rows for default document sanitization,
      subtree dropping, unsafe attribute filtering, inline style filtering, and
      default forced-link `rel` behavior.
- [x] Translated sanitizer JSON escaped-token fixture rows, including raw source
      spelling for disallowed start/end tags and malformed tag-like text.
- [x] Accounted for the sanitizer JSON `style`-with-empty-CSS-allowlist error
      row with MoonBit's non-raising constructor and safe style-drop behavior.
- [x] Added CLI parser regressions for equals-form options, missing option
      values, invalid formats, strip/no-strip conflicts, unknown options,
      duplicate input paths, and strict valid input.
- [x] Added CLI regressions for no-path option parsing, empty equals-form
      selectors, and custom fragment cleanup policy handling.
- [x] Added selector-limit regressions for list size, complex selector part
      count, compound simple-selector count, negative byte budgets, and
      `:contains(...)` text byte accounting.
- [x] Added transform no-op regressions for empty attribute patterns,
      empty-attribute nodes, blank attribute names, boolean merge attributes,
      root text/comment leaves, and root preformatted text skips.
- [x] Added transform traversal regressions for nested stage selector limits,
      nested document fragments, `Decide(Escape)` fragment unwrapping,
      text-collapse recursion, linkify recursion, and prune-empty recursion.
- [x] Added sanitizer/transform observer regressions for escape-only source
      text outside escape mode, hook-only/report-only callbacks, and void
      element escaping.
- [x] Added linkify public-edge regressions for malformed `mailto:` addresses,
      fuzzy underscore hosts, invalid ports, leading-dot email domains,
      empty protocol-relative hosts, and punycode TLDs.
- [x] Added linkify DOM whitebox regressions for empty replacement lists and
      UTF-16 boundary fallback paths in internal text splicing.
- [x] Added punycode whitebox regressions for private href passthrough,
      prefixless Unicode hosts, IPv6 passthrough, and all-ASCII IDNA mappings.
- [x] Added tokenizer whitebox regressions for EOF stepping and delimiter-only
      attribute helper parsing.

## Working Rule

Port one feature slice at a time. Each slice should add focused tests, run the
MoonBit validation loop, and land in a small commit before the next slice.
