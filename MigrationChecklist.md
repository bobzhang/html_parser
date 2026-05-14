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
- [x] Added CLI rendering regression for unsafe recovered tag names that parse
      successfully but fail serializer validation.
- [x] Added CLI whitebox error formatter regression for sanitizer, selector,
      and serialization error message preservation.
- [x] Added selector-limit regressions for list size, complex selector part
      count, compound simple-selector count, negative byte budgets, and
      `:contains(...)` text byte accounting.
- [x] Added selector-transform no-match regressions for descendant, child,
      adjacent-sibling, general-sibling, class, ID, and malformed selectors.
- [x] Added limited selector matcher regressions for transform `nth-of-type`
      parity, element/comment pseudos, `*.class`, unknown functional pseudos,
      type-position pseudos, and valueless attributes in byte-budget accounting.
- [x] Added limited selector context regressions for `:empty`, `:root`,
      malformed simple-selector fail-closed branches, detached siblings, and
      direct match-depth budget errors.
- [x] Added transform no-op regressions for empty attribute patterns,
      empty-attribute nodes, blank attribute names, boolean merge attributes,
      empty merge configs, root text/comment leaves, and root preformatted
      text skips.
- [x] Added transform debug regression to keep node, attrs, decide, and report
      callback wrappers opaque in derived `TransformSpec` output.
- [x] Added transform traversal regressions for nested stage selector limits,
      nested document fragments, `Decide(Escape)` fragment unwrapping,
      text-collapse recursion, linkify recursion, and prune-empty recursion.
- [x] Added transform edge regressions for repeated `DropAttrs` glob stars and
      `Decide(Escape)` on non-element children.
- [x] Added sanitizer/transform observer regressions for escape-only source
      text outside escape mode, hook-only/report-only callbacks, and void
      element escaping.
- [x] Added sanitizer helper regressions for dangerous allowlisted attributes
      and generic dropped-attribute report messages.
- [x] Added serializer regressions ensuring parser escape-only sentinels stay
      hidden in compact HTML, pretty HTML, Markdown, and text output.
- [x] Added serializer whitebox regressions for escape-only text nodes inside
      pretty inline runs and all-hidden pretty inline run fallbacks.
- [x] Refactored HTML serialization context dispatch so `Url`, `Html`,
      `JsString`, and `HtmlAttrValue` are handled as explicit enum arms without
      an unreachable inner fallback.
- [x] Refactored class-token selector scanning to use Unicode-safe
      `StringView` iteration while preserving UTF-16 token offsets.
- [x] Split basic selector tag, id, and class matching helpers into
      `selector/basic.mbt`.
- [x] Split attribute selector parsing and matching helpers into
      `selector/attributes.mbt`.
- [x] Split structural pseudo selector helpers into `selector/structural.mbt`.
- [x] Split text pseudo selector argument parsing and text-content helpers into
      `selector/text.mbt`.
- [x] Split pseudo selector dispatch and validation into `selector/pseudo.mbt`.
- [x] Split simple selector matching and validation into `selector/simple.mbt`.
- [x] Split selector-list and complex-selector parsing into
      `selector/parse.mbt`.
- [x] Split normal selector traversal and selector-list matching into
      `selector/traversal.mbt`.
- [x] Split selector limit validation helpers into `selector/validation.mbt`.
- [x] Split selector match budget context into `selector/budget.mbt`.
- [x] Split context-aware selector matching into `selector/limited.mbt`.
- [x] Split shared selector node identity checks into `selector/identity.mbt`.
- [x] Split selector query traversal into `selector/query.mbt`.
- [x] Split serializer escaping and percent-encoding helpers into
      `serializer/escape.mbt`.
- [x] Split serializer start-tag validation and construction into
      `serializer/start_tag.mbt`.
- [x] Split serializer comment and raw-text guards into
      `serializer/rawtext.mbt`.
- [x] Split serializer whitespace normalization and predicates into
      `serializer/whitespace.mbt`.
- [x] Split serializer element-name policies into `serializer/elements.mbt`.
- [x] Split serializer text extraction into `serializer/text.mbt`.
- [x] Split serializer test-format rendering into `serializer/test_format.mbt`.
- [x] Split serializer compact HTML rendering into `serializer/compact.mbt`.
- [x] Split serializer pretty HTML rendering into `serializer/pretty.mbt`.
- [x] Split linkify public match/config types into `linkify/config.mbt`.
- [x] Split shared linkify string and character helpers into
      `linkify/syntax.mbt`.
- [x] Split linkify TLD policy helpers into `linkify/tld.mbt`.
- [x] Split linkify host and IPv4 helpers into `linkify/host.mbt`.
- [x] Split linkify href and scheme helpers into `linkify/href.mbt`.
- [x] Split linkify candidate validation into `linkify/validate.mbt`.
- [x] Split linkify candidate scanning helpers into `linkify/scan.mbt`.
- [x] Split Markdown builder and text escaping helpers into
      `markdown/builder.mbt`.
- [x] Split Markdown code-span and text-collection helpers into
      `markdown/code.mbt`.
- [x] Split Markdown link destination and anchor rendering helpers into
      `markdown/link.mbt`.
- [x] Split Markdown pre/list/blockquote block walkers into
      `markdown/blocks.mbt`.
- [x] Split Markdown recursive walking and tag-classification helpers into
      `markdown/walk.mbt`.
- [x] Split CLI result, option model, help, and result-construction helpers
      into `cli/model.mbt`.
- [x] Split CLI option parsing and read-plan helpers into `cli/args.mbt`.
- [x] Split CLI sanitize policy and cleanup helpers into `cli/safety.mbt`.
- [x] Split CLI selector validation and selection helpers into
      `cli/select.mbt`.
- [x] Split CLI render, output, and HTML error formatting helpers into
      `cli/render.mbt`.
- [x] Split CLI input-byte document parsing into `cli/parse.mbt`.
- [x] Split CLI post-parse pipeline orchestration into `cli/pipeline.mbt`.
- [x] Added linkify public-edge regressions for malformed `mailto:` addresses,
      fuzzy underscore hosts, invalid ports, leading-dot email domains,
      empty protocol-relative hosts, and punycode TLDs.

## Semantics-Preserving Modular Refactor

- [x] Extract diagnostics into `core`.
- [x] Extract shared syntax helpers into `internal/syntax`.
- [x] Extract shared source-position and newline normalization helpers into
      `internal/syntax`.
- [x] Extract shared XML character/coercion helpers into `internal/syntax`.
- [x] Add free `Node` feature APIs for serializer, selector, text, and Markdown
      operations.
- [x] Remove public feature methods from the root `Node` API.
- [x] Extract DOM node types, builders, and DOM methods into `dom`, with root
      compatibility builders and `pub using @dom { type Node }`.
- [x] Extract tokenizer data structures.
- [x] Move tokenizer comment scanner into `tokenizer`.
- [x] Move tokenizer doctype external-id helpers into `tokenizer`.
- [x] Move tokenizer entity decoding helpers into `tokenizer`.
- [x] Move tokenizer special-text scanners into `tokenizer`.
- [x] Move tokenizer implementation into `tokenizer`.
- [x] Extract shared byte decoder into `internal/encoding`.
- [x] Extract stream event API and sink.
- [x] Move string stream facade into `stream`.
- [x] Move stream byte facade into `stream`.
- [x] Extract selector parsing and matching.
- [x] Extract HTML serializer and text extraction.
- [x] Extract Markdown conversion.
- [x] Extract sanitizer policy and DOM sanitizer.
- [x] Extract linkify scanner and DOM linkifier.
- [x] Extract transform pipeline.
- [x] Extract parser package.
- [x] Extract CLI package.
- [x] Split parser public entrypoints and `ParsedHtml` result methods into a
      focused `parser/api.mbt` file.
- [x] Split tokenizer attribute name and value scanners into
      `tokenizer/attributes.mbt`.
- [x] Split tokenizer special-text token emission helpers into
      `tokenizer/special_text_tokens.mbt`.
- [x] Split tokenizer plain text token scanners into `tokenizer/text.mbt`.
- [x] Split tokenizer comment and markup-declaration token emission into
      `tokenizer/comments.mbt`.
- [x] Split tokenizer doctype token emission into
      `tokenizer/doctype_tokens.mbt`.
- [x] Split tokenizer doctype value normalization and EOF helpers into
      `tokenizer/doctype_values.mbt`.
- [x] Split tokenizer doctype system-identifier parsing into
      `tokenizer/doctype_system.mbt`.
- [x] Split tokenizer doctype public-identifier parsing into
      `tokenizer/doctype_public.mbt`.
- [x] Split tokenizer start/end tag token emission into `tokenizer/tags.mbt`.
- [x] Split tokenizer state, cursor helpers, and tokenizer diagnostics into
      `tokenizer/state.mbt`.
- [x] Split tokenizer dispatch loop into `tokenizer/driver.mbt`.
- [x] Split tokenizer named entity lookup tables into
      `tokenizer/named_entities.mbt`.
- [x] Split tokenizer numeric entity parsing and replacement helpers into
      `tokenizer/numeric_entities.mbt`.
- [x] Split parser attribute scanners into `parser/attributes.mbt`.
- [x] Split document scaffolding and selected-content helpers into
      `parser/scaffold.mbt`.
- [x] Split parser existing-document scaffold merge helpers into
      `parser/scaffold_existing.mbt`.
- [x] Split parser scaffold text/whitespace helpers into
      `parser/scaffold_text.mbt`.
- [x] Split parser selected-content population helpers into
      `parser/selected_content.mbt`.
- [x] Split parser state, cursor helpers, and node-origin helpers into
      `parser/state.mbt`.
- [x] Split parser syntax-adapter helpers into `parser/syntax.mbt`.
- [x] Split parser diagnostics and EOF error helpers into
      `parser/diagnostics.mbt`.
- [x] Split parser text insertion, normalization, and null-character helpers
      into `parser/text.mbt`.
- [x] Split parser comment, markup declaration, CDATA, and doctype scanners
      into `parser/markup.mbt`.
- [x] Split parser special text, raw-text, RCDATA, and initial-LF helpers into
      `parser/special_text.mbt`.
- [x] Split parser fragment-context parsing and wrapper unwrapping into
      `parser/fragment_context.mbt`.
- [x] Moved parser foreign table recovery helpers into
      `parser/foreign_content.mbt`.
- [x] Split parser foreign table recovery helpers into
      `parser/foreign_table_recovery.mbt`.
- [x] Split parser foreign namespace and integration-point helpers into
      `parser/foreign_namespace.mbt`.
- [x] Split parser tree-builder scope and open-element helpers into
      `parser/scope.mbt`.
- [x] Split parser select insertion-mode helpers and select tag handling into
      `parser/select.mbt`.
- [x] Split parser template context mode bookkeeping into
      `parser/template_context.mbt`.
- [x] Moved parser template end-tag handling into `parser/template_context.mbt`.
- [x] Split parser special-element and ruby end-tag helpers into
      `parser/special_elements.mbt`.
- [x] Split parser form end-tag helpers into `parser/form.mbt`.
- [x] Moved parser form start-tag bookkeeping into `parser/form.mbt`.
- [x] Moved parser select reprocessing helpers into `parser/select.mbt`.
- [x] Split parser generic stack and insertion helpers into
      `parser/stack.mbt`.
- [x] Moved remaining parser stack lookup/removal helpers into
      `parser/stack.mbt`.
- [x] Split parser document frameset helpers into `parser/frameset.mbt`.
- [x] Split parser implicit frameset replacement helpers into
      `parser/frameset_replacement.mbt`.
- [x] Split parser active-formatting and adoption-agency helpers into
      `parser/active_formatting.mbt`.
- [x] Split parser active-formatting entry bookkeeping into
      `parser/active_formatting_entries.mbt`.
- [x] Split parser adoption-agency algorithm into
      `parser/adoption_agency.mbt`.
- [x] Split parser body tag classification and heading/table cell helpers into
      `parser/body_tags.mbt`.
- [x] Split parser table start-tag closure helpers into
      `parser/table_start_closure.mbt`.
- [x] Split parser document shell and head-handling helpers into
      `parser/document_shell.mbt`.
- [x] Moved parser document/fragment end-tag shell helpers into
      `parser/document_shell.mbt`.
- [x] Split parser fragment shell start/end handlers into
      `parser/fragment_shell.mbt`.
- [x] Split parser disabled head `noscript` handlers into
      `parser/head_noscript.mbt`.
- [x] Split parser document-head recovery helpers into
      `parser/document_head.mbt`.
- [x] Split parser document attribute merge helpers into
      `parser/document_attrs.mbt`.
- [x] Split parser end-tag scanner and remaining body end-tag helpers into
      `parser/end_tags.mbt`.
- [x] Split parser start-tag scanner and invalid-start fallback into
      `parser/start_tags.mbt`.
- [x] Split parser foreign SVG/MathML tag and attribute adjustment helpers into
      `parser/foreign_adjustments.mbt`.
- [x] Moved parser fragment shell start-tag helpers into
      `parser/document_shell.mbt`.
- [x] Split parser table-context and foster-parenting helpers into
      `parser/table_context.mbt`.
- [x] Split parser foster-parenting helpers into `parser/table_foster.mbt`.
- [x] Split parser column-group helpers into `parser/column_group.mbt`.
- [x] Split parser template column-group handlers into
      `parser/template_column_group.mbt`.
- [x] Split parser normal start-tag tree insertion into
      `parser/start_tag_insertion.mbt`.
- [x] Split parser parsed start-tag dispatch into
      `parser/start_tag_dispatch.mbt`.
- [x] Split parser caption helpers into `parser/caption.mbt`.
- [x] Split parser template-table-context handlers into
      `parser/template_table_context.mbt`.
- [x] Split parser table end-tag and fragment-table guards into
      `parser/table_end_tags.mbt`.
- [x] Split parser table-fragment context guards into
      `parser/table_fragment_context.mbt`.
- [x] Split sanitizer policy/data type declarations into
      `sanitize/types.mbt`.
- [x] Split sanitizer policy constructors and default policy builders into
      `sanitize/policy.mbt`.
- [x] Split sanitizer URL attribute normalization and validation helpers into
      `sanitize/url.mbt`.
- [x] Split sanitizer URL proxy encoding and rewrite helpers into
      `sanitize/url_proxy.mbt`.
- [x] Split sanitizer `srcset` and URL-list attribute sanitation helpers into
      `sanitize/url_lists.mbt`.
- [x] Split sanitizer URL host and authority extraction helpers into
      `sanitize/url_host.mbt`.
- [x] Split sanitizer URL scheme normalization and prefix helpers into
      `sanitize/url_scheme.mbt`.
- [x] Split sanitizer CSS/style value sanitation helpers into
      `sanitize/css.mbt`.
- [x] Split sanitizer element-attribute sanitation helpers into
      `sanitize/attributes.mbt`.
- [x] Split sanitizer observer/reporting helpers into
      `sanitize/observer.mbt`.
- [x] Split sanitizer DOM node mutation and escaping helpers into
      `sanitize/nodes.mbt`.
- [x] Split sanitizer invisible-Unicode text helpers into
      `sanitize/text.mbt`.
- [x] Split sanitizer rawtext and foreign integration child sanitizers into
      `sanitize/content.mbt`.
- [x] Split sanitizer shared syntax helpers into `sanitize/syntax.mbt`.
- [x] Split sanitizer namespace and node-name classifiers into
      `sanitize/namespaces.mbt`.
- [x] Split transform spec types and callback wrappers into
      `transform/spec.mbt`.
- [x] Split transform public builder methods into
      `transform/builders.mbt`.
- [x] Split transform execution pipeline and top-level dispatcher into
      `transform/pipeline.mbt`.
- [x] Split transform reporting and sanitizer observer glue into
      `transform/reporting.mbt`.
- [x] Split transform normalization and whitespace predicates into
      `transform/normalization.mbt`.
- [x] Split transform decide traversal and action helpers into
      `transform/decide.mbt`.
- [x] Split transform selector traversal and match dispatch into
      `transform/selectors.mbt`.
- [x] Split transform attribute edit/drop/allowlist/merge helpers into
      `transform/attributes.mbt`.
- [x] Split transform URL and inline-style attribute helpers into
      `transform/url_style.mbt`.
- [x] Split transform node edit and escape helpers into
      `transform/node_edit.mbt`.
- [x] Split transform node-kind and foreign-namespace drop helpers into
      `transform/node_drop.mbt`.
- [x] Split transform whitespace collapse helpers into
      `transform/whitespace.mbt`.
- [x] Split transform prune-empty post-order helpers into
      `transform/prune.mbt`.
- [x] Split transform linkify DOM helpers into `transform/linkify.mbt` and
      remove the empty legacy `transform/transform.mbt` catch-all.
- [x] Split selector public limit type and constructor into
      `selector/limits.mbt`.
- [x] Split selector syntax predicates and shared StringView helpers into
      `selector/syntax.mbt`.
- [x] Added linkify helper whitebox regressions for trailing bracket trimming,
      broken-scheme contexts, edge-dot TLD splitting, and empty numeric hosts.
- [x] Added linkify DOM whitebox regressions for empty replacement lists and
      UTF-16 boundary fallback paths in internal text splicing.
- [x] Added punycode whitebox regressions for private href passthrough,
      prefixless Unicode hosts, IPv6 passthrough, and all-ASCII IDNA mappings.
- [x] Added tokenizer whitebox regressions for EOF stepping and delimiter-only
      attribute helper parsing.
- [x] Refactored linkify's last-character scan to use Unicode-safe
      `StringView` iteration while retaining UTF-16 result offsets.
- [x] Refactored linkify host-prefix scanning to use Unicode-safe
      `StringView` iteration before slicing at URL delimiters.
- [x] Refactored linkify balanced-punctuation counting to iterate over scanner
      produced `StringView` slices instead of manual cursor fallback branches.
- [x] Refactored linkify broad/fuzzy candidate-end scans to iterate over
      scanner-produced `StringView` slices while retaining UTF-16 offsets.
- [x] Refactored linkify substring search to advance with Unicode-safe
      `StringView` iteration while retaining fixed-width `get_view` checks.
- [x] Refactored linkify embedded-scheme recovery scanning to iterate over
      scanner-bounded `StringView` slices.
- [x] Refactored linkify host/userinfo/domain helpers to use direct
      boundary-safe `StringView` slices after offsets produced by internal scans.
- [x] Refactored linkify punycode host/tail splitting to use Unicode-safe
      `StringView` iteration before slicing at URL delimiters.
- [x] Refactored linkify punycode label splitting to use Unicode-safe
      `StringView` iteration while preserving final/trailing labels.
- [x] Refactored linkify validation prefix and TLD split helpers to use direct
      boundary-safe `StringView` slices from known scanner offsets.
- [x] Refactored linkify IPv4 validation to split with Unicode-safe
      `StringView` iteration and direct part slices.
- [x] Refactored linkify punycode href prefix, userinfo, and tail splitting to
      use direct `StringView` slices from known-valid offsets.
- [x] Simplified linkify punycode label encoding around MoonBit scalar-value
      `Char` iteration and documented the Python surrogate fallback difference.
- [x] Refactored Markdown builder and helper trimming slices to use direct
      `StringView` slices after local scans produce valid offsets.
- [x] Refactored CLI equals-form option parsing to use direct slices and added
      whitebox coverage for no-path read plans.
- [x] Refactored deep DOM clone traversal to unwrap stack pops after the
      non-empty loop guard.
- [x] Refactored foreign-content text cleanup to iterate by `Char` with UTF-16
      offsets and unwrap namespace after the foreign-start guard.
- [x] Refactored covered script-text scanner states to unwrap characters after
      the loop/boundary invariant instead of carrying repeated `None` arms.
- [x] Refactored linkify current-position checks to use scanner boundary
      invariants while keeping the astral-safe previous-boundary fallback.
- [x] Refactored tokenizer doctype/start/end tag cursor loops to use scanner
      boundary invariants and direct `StringView` slices.
- [x] Added tokenizer EOF-after-whitespace tag regressions and refactored
      character/invalid-open/comment text extraction to direct `StringView`
      slices.
- [x] Refactored tokenizer attribute value slices and special-text null cleanup
      to rely on scanner-owned UTF-16 boundaries and Unicode-safe iteration.
- [x] Added linkify astral-left-boundary coverage to lock fuzzy-link UTF-16
      offsets after surrogate-pair characters.
- [x] Simplified CLI read-plan handling after parser-owned path validation.
- [x] Refactored serializer raw-text and selector scanner helpers to use
      direct `StringView` slices and guarded UTF-16 cursor unwraps.
- [x] Refactored serializer simple-selector match/validation paths to reuse
      prior selector validity and scanner-boundary invariants.
- [x] Added limited-selector whitebox regressions for malformed attribute
      selectors, parentless child combinators, and cyclic ancestor walks.
- [x] Covered the serializer percent-encoding hex fallback to keep the helper
      total for defensive private calls.
- [x] Refactored transform glob and URL/style attribute scans around local
      UTF-16 cursor and map-key invariants.
- [x] Removed impossible transform escape/linkify inserted-count fallbacks and
      added whitebox coverage for defensive transform helper/constructor no-ops.
- [x] Refactored sanitizer URL, CSS, srcset, style, and token-list scanners to
      use direct `StringView` slices and guarded UTF-16 cursor unwraps, with
      astral-character boundary coverage for URL/style/token splitting.
- [x] Refactored parser source-slice, text-cleanup, entity, scaffold, and
      charset helper scans around scanner-owned UTF-16 boundaries, with
      astral-character whitebox coverage for the touched text helpers.
- [x] Refactored parser tag/attribute, special-text, doctype, line/column, and
      entity scanner loops around local cursor invariants, with newline and
      bogus-comment Unicode regressions.
- [x] Covered final parser defensive branches for omitted template end-tag
      sources and empty private attribute parses.
- [x] Cleared sanitizer, transform, serializer, and parser package coverage;
      remaining uncovered lines are CLI integration error/entrypoint branches.
- [x] Refactored the CLI post-parse pipeline for injectable sanitizer policy
      tests and covered the safe sanitize/cleanup error return paths.
- [x] Cleared root CLI package coverage; the only remaining uncovered line is
      the native `cmd/main` immediate-exit entrypoint branch.
- [x] Added a callback-based root CLI runner for host-owned input reads, made
      the native entrypoint a thin caller, and covered immediate/read plans in
      normal root-package tests.
- [x] Rechecked coverage from a clean build tree; standard `moon coverage
      analyze` now reports all source files fully covered.
- [x] Hardened CI to type-check all targets, run JS and native tests, and gate
      on the fully-covered `moon coverage analyze` result.
- [x] Prepared the next Mooncakes patch release version after `0.1.0` was
      already present on the registry, and locked the CLI version output to it.
- [x] Adjusted the Mooncakes CI dry-run gate so published versions keep passing
      after package validation reports the expected duplicate-version response.
- [x] Prepared `0.1.2` so the published package includes the post-release CI
      and README installation-documentation updates.
- [x] Added a CI release-version consistency check tying `moon.mod.json`,
      CLI `--version`, and the exact CLI version test together.
- [x] Moved the release-version consistency check into a reusable local script
      and kept CI calling that single source of truth.
- [x] Moved Mooncakes package dry-run verification into a reusable local script
      that also handles already-published versions.
- [x] Moved native CLI release smoke coverage into a reusable local script and
      kept CI calling it.
- [x] Moved the full-coverage gate into a reusable local script and kept CI
      calling it.
- [x] Moved generated-interface validation into a reusable local script and
      kept CI calling it.
- [x] Added a single local CI entrypoint that runs the repository validation
      gates and made GitHub Actions call it.
- [x] Added GitHub Actions log grouping to the local CI entrypoint so hosted
      failures remain easy to inspect.
- [x] Added a package metadata consistency check for Mooncakes fields and README
      install/import snippets.
- [x] Ignored Python bytecode directories produced by local validation helpers.
- [x] Extended package metadata checks to keep GitHub `README.md` aligned with
      the configured Mooncakes README file.
- [x] Tightened Mooncakes verification script argument handling and made
      accepted already-published versions explicit in the logs.
- [x] Added a validation-script self-check for Bash syntax, Python helper
      syntax, and fast argument smoke paths.
- [x] Added a vendored fixture sync check against `.repos/justhtml` for the
      copied JustHTML and linkify fixture files.
- [x] Added fixture-sync script smoke coverage for absent-reference and
      bad-argument paths.
- [x] Generalized generated-interface validation to discover all tracked
      `pkg.generated.mbti` files instead of hard-coding package paths.
- [x] Added native CLI package layout checks for `cmd/main`, its native target
      settings, and the C stub symbols used by the entrypoint.
- [x] Added GitHub workflow drift checks so hosted CI keeps invoking the shared
      local validation entrypoint instead of duplicating Moon commands.
- [x] Added source-layout checks for tracked package directories, generated
      interfaces, root implementation modules, and vendored fixture coverage.
- [x] Added migration-doc checks for the Python-to-MoonBit gotchas, fixture
      workflow notes, native CLI constraints, and release validation docs.
- [x] Added Mooncakes archive-content checks for critical packaged source,
      fixture, docs, native CLI, generated interface, and forbidden path rules.
- [x] Added a shared test runner that enforces the default, JS, and native
      MoonBit test-count floor so fixture coverage cannot silently shrink.
- [x] Added a `.gitignore` guard for local generated output, Mooncakes state,
      the optional reference checkout, Python bytecode, and macOS metadata.
- [x] Updated the optional pre-commit hook to call the shared local CI entrypoint
      and added a guard to keep hook documentation and behavior aligned.
- [x] Added a MoonBit block-style guard and brought the placeholder root source
      file under the project-wide `///|` separator convention.
- [x] Standardized argument validation across local validation helpers and
      extended script smoke coverage for their bad-option paths.
- [x] Added a validation inventory guard so local CI, script smoke checks, and
      Mooncakes archive checks stay wired into the shared validation graph.
- [x] Added a vendored fixture manifest with size and SHA-256 checks so CI can
      catch fixture truncation or accidental edits without `.repos/justhtml`.
- [x] Tightened the validation inventory guard so it covers itself and fails on
      any tracked validation helper missing from the inventory.
- [x] Added validation-helper convention checks for tracked `scripts/*`
      suffixes and interpreter shebangs.
- [x] Extended GitHub workflow validation to inventory every tracked workflow
      and guard the Copilot MoonBit setup workflow.
- [x] Generalized Mooncakes archive checks to require every tracked published
      source, test, fixture, documentation, and validation-helper file.
- [x] Extended migration-document validation so README's development-checks
      summary covers the newer inventory and convention guards.
- [x] Added Git hook inventory checks so tracked hook files stay covered by the
      local hook validation guard.
- [x] Extended source-layout validation to cover all root implementation
      modules split out during the port.
- [x] Extended source-layout validation to cover all split root test modules.
- [x] Extended source-layout validation to reject all tracked local/generated
      paths covered by `.gitignore`.
- [x] Added a Mooncakes archive duplicate-path guard so packaged files cannot
      appear more than once.
- [x] Added a MoonBit test-name inventory guard so refactors cannot silently
      delete, rename, or skip tracked test declarations.
- [x] Added public API golden regression tests for parse/query/render,
      sanitize-plus-linkify transforms, and bytes/stream workflows.
- [x] Added golden output regression tests for mixed HTML serialization,
      Markdown conversion, and CLI end-user output modes.
- [x] Added public sanitizer security-policy regression tests for default
      stripping, URL proxy rules, and collect/raise unsafe handling modes.
- [x] Added public DOM graph regression tests for mutation invariants, detached
      clones, child/attribute copies, and UTF-16 source-location metadata.
- [x] Added public token/stream regression tests for structured tokens,
      malformed-token diagnostics, streaming events, and stream-sink copying.
- [x] Added public selector regression tests for combinators, attribute
      operators, selector lists, pseudos, `query_one`, and `matches`.
- [x] Added public linkify regression tests for mixed URL/email/domain matches,
      UTF-16 offsets, configurable TLD/IP matching, and DOM skip tags.
- [x] Added public CLI regression tests for read plans, reader/file output,
      cleanup security modes, strict errors, and argument diagnostics.
- [x] Added public byte-decoding regression tests for transport labels,
      meta-charset sniffing, UTF-16 BOMs, and fail-closed prescan behavior.
- [x] Added public transform regression tests for structural pipelines,
      attribute policy transforms, and callback/report event ordering.
- [x] Added public serializer regression tests for pretty HTML, escaping
      contexts, URL context output, and invalid programmatic serialization.
- [x] Added public text/Markdown regression tests for text extraction modes,
      common Markdown output, and raw HTML passthrough behavior.
- [x] Added public parser regression tests for document error modes, fragment
      contexts, source locations, and scripting-dependent `noscript` parsing.
- [x] Added public builder/accessor regression tests for node constructors,
      test-format output, namespace aliases, and invalid mutation no-ops.
- [x] Extended public sanitizer policy regressions for collect/reset copying,
      URL filter callback order, document policy shell preservation, and CSS
      preset copy semantics.
- [x] Added public constructor/default regressions for parse errors, fragment
      contexts, selector limits, and linkify configuration copying.
- [x] Extended public serializer regressions for doctype edge output,
      top-level `to_html`, single-quote serialization, and context-sensitive
      quote validation.
- [x] Extended public CLI regressions for immediate help/version plans,
      selector no-match/first-match behavior, and text whitespace options.
- [x] Split tokenizer script raw-text scanning into `tokenizer/script_text.mbt`.
- [x] Split tokenizer named-entity scanning into `tokenizer/entity_named.mbt`.
- [x] Split tokenizer comment scanner helpers into
      `tokenizer/comment_scan_helpers.mbt`.
- [x] Split tokenizer script text helpers into
      `tokenizer/script_text_helpers.mbt`.
- [x] Split tokenizer script text data/state definitions into
      `tokenizer/script_text_types.mbt`.
- [x] Split shared tokenizer tag-tail scanning into
      `tokenizer/tag_tail.mbt`.
- [x] Split private tokenizer doctype helper utilities into
      `tokenizer/doctype_helpers.mbt`.
- [x] Split tokenizer doctype public data definitions into
      `tokenizer/doctype_types.mbt`.
- [x] Split tokenizer comment scanner public data definitions into
      `tokenizer/comment_scan_types.mbt`.
- [x] Split tokenizer entity public data definitions into
      `tokenizer/entity_types.mbt`.

## Working Rule

Port one feature slice at a time. Each slice should add focused tests, run the
MoonBit validation loop, and land in a small commit before the next slice.
