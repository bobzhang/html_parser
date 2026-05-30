# HtmlFmt Example CLI

These Moon Cram tests exercise the compiled `examples/cmd/htmlfmt` formatter.

## Pretty Fragment

```mooncram
$ htmlfmt.exe '<article><p>Hello <b>MoonBit</b></p></article>'
<article>
  <p>Hello <b>MoonBit</b></p>
</article>
```

## Compact Fragment

```mooncram
$ htmlfmt.exe --compact '<p class="intro">Hello <b>MoonBit</b></p>'
<p class="intro">Hello <b>MoonBit</b></p>
```
