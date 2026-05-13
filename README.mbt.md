# bobzhang/html_parser

MoonBit port of the JustHTML parser, ported from the Python reference
implementation in `.repos/justhtml`.

The port currently provides:

- Public DOM node builders.
- Compact and simple pretty HTML serialization.
- Text extraction.
- Tokenization, document parsing, fragment parsing, and HTML5-style recovery
  coverage from vendored tokenizer/tree-builder fixtures.
- Document-mode scaffolding with `html/head/body`, table/foreign-content
  recovery, template handling, source locations, and strict-mode errors.
- CSS-style DOM queries for tag, class, id, attributes, combinators, selector
  lists, and common pseudo selectors.
- Byte input parsing with supported transport labels, BOM sniffing, and
  meta-charset prescan.
- Default-policy DOM sanitization with tag/attribute allowlists, comment and
  doctype handling, unsafe attribute filtering, basic URL checks, and explicit
  parse-time sanitization via `sanitize=true`. Custom policies can unwrap,
  drop, or escape disallowed tags, force hardened anchor `rel` tokens, and
  allowlist simple inline CSS properties while stripping invisible Unicode and
  hardening allowed raw-text, foreign text-integration, active foreign contents,
  foreign URL-function attributes, meta refresh contents, and base URL rewrites.
  URL-like attributes require exact URL policy rules. Policies can keep the
  default strip behavior, collect security findings, or raise on the first
  unsafe construct, and can define exact tag/attribute URL rules for schemes,
  hosts, fragments, relative URLs, protocol-relative rewrites, and allow/strip
  handling while rejecting malformed host values and backslashes. URL handling
  can also rewrite or drop URLs through `UrlFilter`, then proxy validated URLs
  through a policy-level or per-rule `UrlProxy`, including single URL
  attributes, simple `srcset`/`imagesrcset` candidate lists,
  `ping`/`attributionsrc` URL-token lists, and plain CSS `url(...)` values on
  allowlisted inline-style properties. Use
  `css_preset_text()` for the conservative text-style property allowlist from
  the reference sanitizer.
- Transform helpers for sanitize, drop/unwrap/escape, pruning, linkification,
  attribute edits, and transform observers.
- Linkify, streaming parse events, Markdown conversion, and an embeddable CLI
  runner plus native CLI wrapper.

## Install

```sh
moon add bobzhang/html_parser
```

Then import the package from the `moon.pkg` that uses it:

```moonbit nocheck
import {
  "bobzhang/html_parser"
}
```

## Library Examples

The examples below are `mbt check` doctests and are run by `moon test`.

```mbt check
///|
test "readme parse fragment example" {
  let doc = @html_parser.parse_fragment(
    "<p class='intro'>Hello <b>MoonBit</b></p>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<p class=\"intro\">Hello <b>MoonBit</b></p>",
  )
  assert_eq(doc.to_text(separator="", strip=false), "Hello MoonBit")
  assert_eq(doc.to_markdown(), "Hello **MoonBit**")
  assert_eq(doc.query("p.intro").length(), 1)
  let tokens = @html_parser.tokenize("<p>Hello</p>").tokens
  assert_eq(tokens.length(), 4)
}
```

```mbt check
///|
test "readme parse bytes example" {
  let bytes = @utf8.encode("<meta charset=utf-8><p>\u{20AC}</p>")
  let doc = @html_parser.parse_bytes(bytes)
  guard doc.encoding is Some("utf-8") else { fail("expected utf-8 encoding") }
  assert_eq(doc.to_text(separator="", strip=false), "\u{20AC}")
}
```

```mbt check
///|
test "readme sanitize dom example" {
  let doc = @html_parser.parse(
    "<!DOCTYPE html><!--x--><p onclick=alert(1)>ok</p><script>alert(1)</script>",
    sanitize=false,
  )
  let clean = @html_parser.sanitize_dom(
    doc.root,
    policy=@html_parser.default_sanitization_policy(),
  )
  assert_eq(@html_parser.to_html(clean, pretty=false), "<p>ok</p>")
  let fragment = @html_parser.parse_fragment(
    "<p onclick=alert(1)>ok</p><script>alert(1)</script>",
    sanitize=true,
  )
  assert_eq(fragment.to_html(pretty=false), "<p>ok</p>")
}
```

```mbt check
///|
test "readme CLI reader example" {
  let paths : Array[String] = []
  let result = @html_parser.run_cli_with_reader(["-", "--format", "text"], fn(
    path,
  ) {
    paths.push(path)
    @utf8.encode("<p>Hello <b>MoonBit</b></p>")
  })
  assert_eq(paths, ["-"])
  assert_eq(result.exit_code, 0)
  assert_eq(result.stdout, "Hello MoonBit\n")
}
```

## Native CLI

The native CLI wrapper lives in `cmd/main` and uses a small C stub for raw
stdin/file IO. Build it from this repository with:

```sh
moon run --target native --release --build-only cmd/main
```

The executable is written to `_build/native/release/build/cmd/main/main.exe`.
For example:

```sh
printf '<p>Hello <b>MoonBit</b></p>' \
  | _build/native/release/build/cmd/main/main.exe - --format text
```

## Development Checks

Run the same validation entrypoint used by CI:

```sh
bash scripts/check_ci.sh --skip-without-credentials
```

Drop `--skip-without-credentials` when logged in locally and checking the full
Mooncakes dry-run path. The script checks release-version consistency,
validation-script syntax and argument smoke paths, helper suffix/shebang
conventions, validation-inventory wiring, GitHub workflow drift and tracked
workflow inventory including the Copilot setup workflow, source layout,
test-name inventory, migration docs, local Git hook wiring, vendored fixture sync when
`.repos/justhtml` is present, vendored fixture manifest hashes, package
metadata, formatting, generated interfaces, all supported targets,
default/JS/native tests with a count floor, coverage, native CLI smoke
behavior, Mooncakes package validation, and dynamic Mooncakes archive
inventory/content checks.
