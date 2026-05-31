// Blackbox snapshot tests for `linkify_dom` — walks a DOM tree, finds
// link-like substrings in text nodes, and wraps them in <a> elements.
//
// Snapshots are HTML strings (via `to_html`) because the resulting DOM
// nodes are large and contain back-pointers; the serialized form reads
// like a diff against the input.

///|
test "linkify_dom wraps a fuzzy domain in an anchor element" {
  let fragment = @dom.fragment(children=[@dom.text("Go to example.com now")])
  let linked = @linkify.linkify_dom(fragment)
  inspect(
    @ser.to_html(linked, pretty=false),
    content=(
      #|Go to <a href="http://example.com">example.com</a> now
    ),
  )
}

///|
test "linkify_dom wraps an email with mailto href" {
  let fragment = @dom.fragment(children=[
    @dom.text("Email me at me@example.com please"),
  ])
  let linked = @linkify.linkify_dom(fragment)
  inspect(
    @ser.to_html(linked, pretty=false),
    content=(
      #|Email me at <a href="mailto:me@example.com">me@example.com</a> please
    ),
  )
}

///|
test "linkify_dom default skip_tags excludes anchors and code-like elements" {
  // Text inside <a>, <code>, <pre>, etc. is not re-linked. The default
  // skip list keeps existing anchors intact and avoids touching code.
  debug_inspect(
    @linkify.linkify_default_dom_skip_tags(),
    content=(
      #|["a", "code", "pre", "script", "style", "textarea"]
    ),
  )
}

///|
test "linkify_dom does not double-link content inside an existing anchor" {
  let anchor = @dom.element("a", attrs={ "href": Some("/x") }, children=[
    @dom.text("see example.com inside"),
  ])
  let fragment = @dom.fragment(children=[anchor])
  let linked = @linkify.linkify_dom(fragment)
  inspect(
    @ser.to_html(linked, pretty=false),
    content=(
      #|<a href="/x">see example.com inside</a>
    ),
  )
}

///|
test "linkify_dom leaves plain text without links unchanged" {
  let fragment = @dom.fragment(children=[@dom.text("nothing link-like here")])
  let linked = @linkify.linkify_dom(fragment)
  inspect(
    @ser.to_html(linked, pretty=false),
    content=(
      #|nothing link-like here
    ),
  )
}

///|
test "linkify_dom honors custom skip_tags" {
  // Add `kbd` to the skip list and the inner text stays untouched.
  let kbd = @dom.element("kbd", children=[@dom.text("press example.com")])
  let fragment = @dom.fragment(children=[kbd])
  let linked = @linkify.linkify_dom(fragment, skip_tags=["kbd"])
  inspect(
    @ser.to_html(linked, pretty=false),
    content=(
      #|<kbd>press example.com</kbd>
    ),
  )
}

///|
test "linkify_dom config and skip_tags compose" {
  // With extra_tlds enabling `internal`, the fuzzy match works even on
  // an otherwise-unknown TLD.
  let fragment = @dom.fragment(children=[
    @dom.text("see site.internal for details"),
  ])
  let linked = @linkify.linkify_dom(
    fragment,
    config=@linkify.LinkifyConfig::with_extra_tlds(["internal"]),
  )
  inspect(
    @ser.to_html(linked, pretty=false),
    content=(
      #|see <a href="http://site.internal">site.internal</a> for details
    ),
  )
}
