# `@sanitize`

Policy-driven DOM sanitization. The library ships a conservative
default policy that matches the upstream JustHTML defaults, plus a
builder API for constructing custom policies covering tag/attribute
allowlists, URL schemes, CSS properties, and content-removal modes.

The examples below are `mbt check` blocks and run as part of
`moon test sanitize`.

## The default policy

`default_sanitization_policy()` is the right starting point for
anything resembling user-submitted HTML. It strips disallowed
elements (unwrapping them so their text survives), removes unsafe
attributes, drops `javascript:` URLs, and removes comments.

```mbt check
///|
test "readme sanitize default policy" {
  let frag = @dom.fragment(children=[
    @dom.element(
      "a",
      attrs={ "href": Some("javascript:alert(1)"), "onclick": Some("x") },
      children=[@dom.text("bad link")],
    ),
    @dom.element("script", children=[@dom.text("evil")]),
    @dom.element("p", children=[@dom.text("kept")]),
  ])
  let clean = @sanitize.sanitize_dom(frag)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<a>bad link</a><p>kept</p>
    ),
  )
}
```

## Building a custom policy

`SanitizationPolicy::SanitizationPolicy` takes the allowed tag list and a host of
keyword arguments controlling tag/attribute handling, URL policy,
CSS allowlist, comment/doctype handling, and unsafe-construct
reporting.

```mbt check
///|
test "readme sanitize custom policy" {
  let policy = @sanitize.SanitizationPolicy(
    ["p", "a"],
    allowed_attributes={ "a": ["href"] },
    disallowed_tag_handling=Drop,
  )
  let frag = @dom.fragment(children=[
    @dom.element("p", children=[@dom.text("keep")]),
    @dom.element(
      "a",
      attrs={ "href": Some("/x"), "onclick": Some("alert(1)") },
      children=[@dom.text("link")],
    ),
    @dom.element("script", children=[@dom.text("evil")]),
  ])
  let clean = @sanitize.sanitize_dom(frag, policy~)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<p>keep</p><a href="/x">link</a>
    ),
  )
}
```

## Disallowed-tag handling

Three modes:

```mbt nocheck
///|
pub(all) enum DisallowedTagHandling {
  Unwrap // remove tag, keep children (default)
  Drop // remove tag and children
  Escape // serialize the tag to HTML-escaped text
}
```

## Reporting modes

`UnsafeHandling` controls what the sanitizer does when it refuses
content: silently strip, collect diagnostics on the policy for
later inspection, or raise immediately.

```mbt check
///|
test "readme sanitize unsafe handling collect" {
  let policy = @sanitize.SanitizationPolicy(
    ["p"],
    disallowed_tag_handling=Drop,
    unsafe_handling=Collect,
  )
  let _ = @sanitize.sanitize_dom(
    @dom.fragment(children=[
      @dom.element("script", children=[@dom.text("evil")]),
    ]),
    policy~,
  )
  // collected_security_errors() returns a list of ParseError records
  // describing each refusal. Use this to surface a warning UI.
  debug_inspect(
    policy.collected_security_errors().length() > 0,
    content=(
      #|true
    ),
  )
}
```

## URL policy

By default no URL attribute survives — to allow `href="/x"` or
`src="https://example.com/img.png"`, register `UrlPolicyRule`s under
`UrlPolicy(allow_rules=...)`.

```mbt check
///|
test "readme sanitize url policy" {
  let url_policy = @sanitize.UrlPolicy(allow_rules=[
    @sanitize.UrlPolicyRule(
      "a",
      "href",
      @sanitize.UrlRule(allowed_schemes=["https"], allowed_hosts=["example.com"]),
    ),
  ])
  let policy = @sanitize.SanitizationPolicy(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let frag = @dom.fragment(children=[
    @dom.element("a", attrs={ "href": Some("https://example.com/x") }, children=[
      @dom.text("ok"),
    ]),
    @dom.element("a", attrs={ "href": Some("http://other.example/x") }, children=[
      @dom.text("blocked"),
    ]),
  ])
  let clean = @sanitize.sanitize_dom(frag, policy~)
  // Only the example.com / https link kept its href; the other one
  // had its href stripped but the anchor element survived.
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<a href="https://example.com/x">ok</a><a>blocked</a>
    ),
  )
}
```

## Rewriting URLs with a filter

`UrlFilter` runs after policy validation; return `None` to strip,
`Some(new_value)` to rewrite.

```mbt nocheck
@sanitize.UrlFilter((tag, attr, value) =>
  if value.starts_with("https://old.example/") {
    Some(value.replace("old.example", "new.example"))
  } else {
    Some(value)
  })
```
