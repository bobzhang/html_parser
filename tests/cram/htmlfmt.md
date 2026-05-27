# HtmlFmt Example CLI

These Moon Cram tests exercise the compiled `examples/cmd/htmlfmt` formatter.

## Pretty Fragment

```mooncram
$ "$HTMLFMT_CLI" '<article><p>Hello <b>MoonBit</b></p></article>'
<article>
  <p>Hello <b>MoonBit</b></p>
</article>
```

## Compact Fragment

```mooncram
$ "$HTMLFMT_CLI" --compact '<p class="intro">Hello <b>MoonBit</b></p>'
<p class="intro">Hello <b>MoonBit</b></p>
```
