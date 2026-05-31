// Blackbox snapshot tests for attribute-shaping transforms.

///|
test "drop_attrs removes the listed attributes" {
  let frag = @dom.fragment(children=[
    @dom.element(
      "a",
      attrs={
        "href": Some("/x"),
        "onclick": Some("alert(1)"),
        "data-keep": Some("yes"),
      },
      children=[@dom.text("link")],
    ),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::drop_attrs("a", ["onclick"]),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<a href="/x" data-keep="yes">link</a>
    ),
  )
}

///|
test "set_attrs forces specific attributes onto every match" {
  let frag = @dom.fragment(children=[
    @dom.element("a", attrs={ "href": Some("https://example.com") }, children=[
      @dom.text("link"),
    ]),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::set_attrs("a", {
      "rel": Some("noopener noreferrer"),
      "target": Some("_blank"),
    }),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<a href="https://example.com" rel="noopener noreferrer" target="_blank">link</a>
    ),
  )
}

///|
test "allowlist_attrs keeps only the listed attributes" {
  let frag = @dom.fragment(children=[
    @dom.element("img", attrs={
      "src": Some("/x.png"),
      "alt": Some("hi"),
      "onerror": Some("alert(1)"),
    }),
  ])
  // For each tag, listed keys survive. Values present in the allowlist
  // map's array act as a value allowlist (empty = any value).
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::allowlist_attrs("img", { "src": [], "alt": [] }),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<img>
    ),
  )
}

///|
test "edit_attrs runs a callback that returns new attributes" {
  let frag = @dom.fragment(children=[
    @dom.element("a", attrs={ "href": Some("HTTP://EXAMPLE.com/X") }, children=[
      @dom.text("link"),
    ]),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::edit_attrs("a", node => {
      match node.attrs().get("href") {
        Some(Some(href)) => Some({ "href": Some(href.to_string().to_lower()) })
        _ => None
      }
    }),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<a href="http://example.com/x">link</a>
    ),
  )
}

///|
test "merge_attrs adds tokens to a token-list attribute" {
  let frag = @dom.fragment(children=[
    @dom.element("a", attrs={ "rel": Some("nofollow") }, children=[
      @dom.text("link"),
    ]),
    @dom.element("a", children=[@dom.text("plain")]),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::merge_attrs("a", attr="rel", tokens=[
      "noopener", "noreferrer",
    ]),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<a rel="nofollow noopener noreferrer">link</a><a rel="noopener noreferrer">plain</a>
    ),
  )
}
