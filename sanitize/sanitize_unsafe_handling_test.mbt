// Blackbox snapshot tests for the `UnsafeHandling` enum — what the
// sanitizer does when it encounters content the policy refuses.

///|
test "UnsafeHandling Strip is the silent default" {
  let policy = @sanitize.SanitizationPolicy::new(
    ["p"],
    disallowed_tag_handling=Drop,
    unsafe_handling=Strip,
  )
  let frag = @dom.fragment(children=[
    @dom.element("script", children=[@dom.text("evil")]),
    @dom.element("p", children=[@dom.text("ok")]),
  ])
  let clean = @sanitize.sanitize_dom(frag, policy~)
  debug_inspect(
    (
      @ser.to_html(clean, pretty=false),
      policy.collected_security_errors().length(),
    ),
    content=(
      #|("<p>ok</p>", 0)
    ),
  )
}

///|
test "UnsafeHandling Collect retains diagnostics on the policy" {
  let policy = @sanitize.SanitizationPolicy::new(
    ["p"],
    disallowed_tag_handling=Drop,
    unsafe_handling=Collect,
  )
  let frag = @dom.fragment(children=[
    @dom.element("script", children=[@dom.text("evil")]),
    @dom.element("p", children=[@dom.text("ok")]),
  ])
  let clean = @sanitize.sanitize_dom(frag, policy~)
  debug_inspect(
    (
      @ser.to_html(clean, pretty=false),
      policy.collected_security_errors().length() > 0,
    ),
    content=(
      #|("<p>ok</p>", true)
    ),
  )
}

///|
test "UnsafeHandling Raise stops sanitization on the first unsafe construct" {
  let policy = @sanitize.SanitizationPolicy::new(
    ["p"],
    disallowed_tag_handling=Drop,
    unsafe_handling=Raise,
  )
  let frag = @dom.fragment(children=[
    @dom.element("script", children=[@dom.text("evil")]),
  ])
  try @sanitize.sanitize_dom(frag, policy~) catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|UnsafeHtml("Unsafe tag 'script' (dropped content)")
        ),
      )
  } noraise {
    _ => fail("expected UnsafeHtml error")
  }
}

///|
test "reset_collected_security_errors clears the buffer" {
  let policy = @sanitize.SanitizationPolicy::new(["p"], unsafe_handling=Collect)
  let frag = @dom.fragment(children=[
    @dom.element("script", children=[@dom.text("evil")]),
  ])
  let _ = @sanitize.sanitize_dom(frag, policy~)
  let before = policy.collected_security_errors().length()
  policy.reset_collected_security_errors()
  let after = policy.collected_security_errors().length()
  debug_inspect(
    (before > 0, after),
    content=(
      #|(true, 0)
    ),
  )
}
