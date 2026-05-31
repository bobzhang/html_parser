// Blackbox snapshot tests for `SanitizationPolicy::SanitizationPolicy` — building a
// custom policy from scratch.

///|
test "minimal policy with allowed_tags only keeps the listed tags" {
  let policy = @sanitize.SanitizationPolicy(["p", "b"])
  let frag = @dom.fragment(children=[
    @dom.element("p", children=[@dom.text("hi")]),
    @dom.element("i", children=[@dom.text("dropped tag")]),
    @dom.element("b", children=[@dom.text("kept")]),
  ])
  let clean = @sanitize.sanitize_dom(frag, policy~)
  // Default `disallowed_tag_handling` is Unwrap, so <i>dropped tag</i>
  // becomes loose text rather than disappearing entirely.
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<p>hi</p>dropped tag<b>kept</b>
    ),
  )
}

///|
test "disallowed_tag_handling Drop removes node and content" {
  let policy = @sanitize.SanitizationPolicy(["p"], disallowed_tag_handling=Drop)
  let frag = @dom.fragment(children=[
    @dom.element("p", children=[@dom.text("keep")]),
    @dom.element("i", children=[@dom.text("DROP THIS")]),
  ])
  let clean = @sanitize.sanitize_dom(frag, policy~)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<p>keep</p>
    ),
  )
}

///|
test "disallowed_tag_handling Escape serializes the tag as text" {
  let policy = @sanitize.SanitizationPolicy(
    ["p"],
    disallowed_tag_handling=Escape,
  )
  let frag = @dom.fragment(children=[
    @dom.element("p", children=[@dom.text("ok")]),
    @dom.element("custom", children=[@dom.text("x")]),
  ])
  let clean = @sanitize.sanitize_dom(frag, policy~)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<p>ok</p>&lt;custom&gt;x&lt;/custom&gt;
    ),
  )
}

///|
test "allowed_attributes gates per-tag attribute names" {
  // <a> may have href; <p> may have nothing.
  let policy = @sanitize.SanitizationPolicy(["a", "p"], allowed_attributes={
    "a": ["href"],
  })
  let frag = @dom.fragment(children=[
    @dom.element(
      "a",
      attrs={ "href": Some("/x"), "data-extra": Some("nope") },
      children=[@dom.text("link")],
    ),
    @dom.element("p", attrs={ "class": Some("intro") }, children=[
      @dom.text("text"),
    ]),
  ])
  let clean = @sanitize.sanitize_dom(frag, policy~)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<a href="/x">link</a><p>text</p>
    ),
  )
}

///|
test "with_extra_allowed_tags returns a derived policy" {
  // Start from the default policy and extend it. Original is unchanged.
  let default = @sanitize.default_sanitization_policy()
  let extended = default.with_extra_allowed_tags(["custom-x"])
  let frag = @dom.fragment(children=[
    @dom.element("custom-x", children=[@dom.text("kept")]),
  ])
  let with_default = @sanitize.sanitize_dom(frag, policy=default)
  let with_extended = @sanitize.sanitize_dom(frag, policy=extended)
  debug_inspect(
    (
      @ser.to_html(with_default, pretty=false),
      @ser.to_html(with_extended, pretty=false),
    ),
    content=(
      #|("kept", "kept")
    ),
  )
}

///|
test "drop_comments=true removes comment nodes" {
  let policy = @sanitize.SanitizationPolicy(["p"], drop_comments=true)
  let frag = @dom.fragment(children=[
    @dom.element("p", children=[@dom.text("body")]),
    @dom.comment(" tracking "),
  ])
  let clean = @sanitize.sanitize_dom(frag, policy~)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<p>body</p>
    ),
  )
}
