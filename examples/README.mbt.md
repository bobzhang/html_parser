# HTML Parser Examples

This workspace module contains runnable examples for `bobzhang/html_parser`.
From the repository root, the `moon.work` workspace makes the examples use the
local parser checkout.

## HTML Formatter

The `examples/cmd/htmlfmt` command formats an HTML fragment with the public
parser and serializer API:

```sh
moon run --target native examples/cmd/htmlfmt -- "<article><p>Hello <b>MoonBit</b></p></article>"
```

It prints:

```html
<article>
  <p>Hello <b>MoonBit</b></p>
</article>
```

Pass `--compact` to serialize without pretty-printing:

```sh
moon run --target native examples/cmd/htmlfmt -- --compact "<p class='intro'>Hello <b>MoonBit</b></p>"
```

The formatting helper can also be used directly from MoonBit:

```mbt check
///|
test "examples readme formats a fragment" {
  assert_eq(
    @html_parser_examples.pretty_fragment(
      "<article><p>Hello <b>MoonBit</b></p></article>",
    ),
    "<article>\n  <p>Hello <b>MoonBit</b></p>\n</article>",
  )
  assert_eq(
    @html_parser_examples.compact_fragment(
      "<p class='intro'>Hello <b>MoonBit</b></p>",
    ),
    "<p class=\"intro\">Hello <b>MoonBit</b></p>",
  )
}
```

The same parser backs the CLI command:

```mbt check
///|
test "examples readme runs htmlfmt" {
  let result = @html_parser_examples.run_htmlfmt([
    "--compact", "<p class='intro'>Hello <b>MoonBit</b></p>",
  ])
  assert_eq(result.exit_code, 0)
  assert_eq(result.stdout, "<p class=\"intro\">Hello <b>MoonBit</b></p>")
}
```
