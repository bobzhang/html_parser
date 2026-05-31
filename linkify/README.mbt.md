# `@linkify`

Detect URLs and email addresses inside plain text — and optionally wrap
them in `<a>` elements inside an existing DOM tree.

The examples below are `mbt check` blocks and run as part of
`moon test linkify`.

## Finding links in a string

`find_links` returns an array of `LinkMatch` records. `start` and `end`
are UTF-16 code-unit offsets into the input; `text` is the matched
substring with trailing punctuation trimmed; `href` is the URL the
linker would emit (with an `http://` or `mailto:` scheme synthesized
when needed).

```mbt check
///|
test "readme find_links basic" {
  debug_inspect(
    @linkify.find_links("Visit https://example.com today."),
    content=(
      #|[
      #|  {
      #|    start: 6,
      #|    end: 25,
      #|    text: "https://example.com",
      #|    href: "https://example.com",
      #|    kind: "url",
      #|  },
      #|]
    ),
  )
}
```

Bare domains, emails, and protocol-relative URLs all work:

```mbt check
///|
test "readme find_links variants" {
  debug_inspect(
    @linkify.find_links(
      "see example.com or mail me@example.org or //cdn.example/x",
    ),
    content=(
      #|[
      #|  {
      #|    start: 4,
      #|    end: 15,
      #|    text: "example.com",
      #|    href: "http://example.com",
      #|    kind: "url",
      #|  },
      #|  {
      #|    start: 24,
      #|    end: 38,
      #|    text: "me@example.org",
      #|    href: "mailto:me@example.org",
      #|    kind: "email",
      #|  },
      #|  {
      #|    start: 42,
      #|    end: 57,
      #|    text: "//cdn.example/x",
      #|    href: "//cdn.example/x",
      #|    kind: "url",
      #|  },
      #|]
    ),
  )
}
```

## Customizing the matcher

`LinkifyConfig` gates two opt-ins: `fuzzy_ip` recognizes bare IPv4
addresses as URLs, and `extra_tlds` extends the list of recognized
top-level domains for fuzzy (no-scheme) matches.

```mbt check
///|
test "readme find_links_with_config extra_tlds" {
  // `internal` isn't a real TLD; default matcher ignores it.
  let plain = @linkify.find_links("site.internal")
  let custom = @linkify.find_links_with_config(
    "site.internal",
    @linkify.LinkifyConfig::with_extra_tlds(["internal"]),
  )
  debug_inspect(
    (plain.length(), custom.length()),
    content=(
      #|(0, 1)
    ),
  )
}
```

## Linkifying a DOM tree

`linkify_dom` walks a DOM node and wraps every link-like substring in
its text descendants with an `<a>` element. Text inside an existing
anchor, `<code>`, `<pre>`, `<script>`, `<style>`, or `<textarea>` is
skipped by default.

```mbt check
///|
test "readme linkify_dom basic" {
  let fragment = @dom.fragment(children=[
    @dom.text("Email me@example.com or visit example.com"),
  ])
  let linked = @linkify.linkify_dom(fragment)
  inspect(
    @ser.to_html(linked, pretty=false),
    content=(
      #|Email <a href="mailto:me@example.com">me@example.com</a> or visit <a href="http://example.com">example.com</a>
    ),
  )
}
```

The default skip list:

```mbt check
///|
test "readme linkify_default_dom_skip_tags" {
  debug_inspect(
    @linkify.linkify_default_dom_skip_tags(),
    content=(
      #|["a", "code", "pre", "script", "style", "textarea"]
    ),
  )
}
```

Override it by passing `skip_tags`:

```mbt check
///|
test "readme linkify_dom custom skip_tags" {
  let kbd = @dom.element("kbd", children=[@dom.text("press example.com")])
  let linked = @linkify.linkify_dom(@dom.fragment(children=[kbd]), skip_tags=[
    "kbd",
  ])
  inspect(
    @ser.to_html(linked, pretty=false),
    content=(
      #|<kbd>press example.com</kbd>
    ),
  )
}
```
