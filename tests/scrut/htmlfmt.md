# HtmlFmt Example CLI

These Scrut tests exercise the compiled `examples/cmd/htmlfmt` formatter.

## Pretty Fragment

```scrut
$ "$HTMLFMT_CLI" '<article><p>Hello <b>MoonBit</b></p></article>'
<article>
  <p>Hello <b>MoonBit</b></p>
</article>
```

## Compact Fragment

```scrut
$ "$HTMLFMT_CLI" --compact '<p class="intro">Hello <b>MoonBit</b></p>'
<p class="intro">Hello <b>MoonBit</b></p>
```
