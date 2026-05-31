// Blackbox snapshot tests for the default sanitization policy.
// Built without going through the parser to keep inputs readable.

///|
fn fragment(children : Array[@dom.Node]) -> @dom.Node {
  @dom.fragment(children~)
}

///|
test "default policy strips disallowed tags but keeps content" {
  // <script> is dropped entirely; <p> survives.
  let frag = fragment([
    @dom.element("p", children=[@dom.text("keep me")]),
    @dom.element("script", children=[@dom.text("alert(1)")]),
  ])
  let clean = @sanitize.sanitize_dom(frag)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<p>keep me</p>
    ),
  )
}

///|
test "default policy strips disallowed attributes" {
  // onclick is unsafe and gets dropped; href is allowed.
  let frag = fragment([
    @dom.element(
      "a",
      attrs={ "href": Some("/x"), "onclick": Some("alert(1)") },
      children=[@dom.text("link")],
    ),
  ])
  let clean = @sanitize.sanitize_dom(frag)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<a href="/x">link</a>
    ),
  )
}

///|
test "default policy drops unknown elements" {
  // Custom elements have no entry in the allowlist.
  let frag = fragment([
    @dom.element("my-widget", children=[@dom.text("custom")]),
    @dom.element("p", children=[@dom.text("normal")]),
  ])
  let clean = @sanitize.sanitize_dom(frag)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|custom<p>normal</p>
    ),
  )
}

///|
test "default policy drops comment nodes" {
  // `default_sanitization_policy()` is conservative: it strips
  // comments. Use a custom policy with `drop_comments=false` to keep
  // them.
  let frag = fragment([
    @dom.comment(" hi "),
    @dom.element("p", children=[@dom.text("body")]),
  ])
  let clean = @sanitize.sanitize_dom(frag)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<p>body</p>
    ),
  )
}

///|
test "default policy strips javascript: URLs from href" {
  let frag = fragment([
    @dom.element("a", attrs={ "href": Some("javascript:alert(1)") }, children=[
      @dom.text("bad"),
    ]),
  ])
  let clean = @sanitize.sanitize_dom(frag)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<a>bad</a>
    ),
  )
}
