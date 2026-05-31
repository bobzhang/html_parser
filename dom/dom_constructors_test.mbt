// Blackbox snapshot tests for the DOM constructors and basic inspection
// methods. Snapshots show kind/name/data tuples rather than entire
// Nodes because Node has parent back-pointers and source-location
// metadata that would clutter every dump.

///|
test "element constructor sets kind, name, and attrs" {
  let p = @dom.element("p", attrs={
    "class": Some("intro"),
    "id": Some("first"),
  })
  debug_inspect(
    (p.kind(), p.name(), p.attrs()),
    content=(
      #|(Element, "p", { "class": Some("intro"), "id": Some("first") })
    ),
  )
}

///|
test "text constructor produces a Text node with data" {
  let node = @dom.text("hello")
  debug_inspect(
    (node.kind(), node.data()),
    content=(
      #|(Text, "hello")
    ),
  )
}

///|
test "comment constructor produces a Comment node with data" {
  let node = @dom.comment(" hi ")
  debug_inspect(
    (node.kind(), node.data()),
    content=(
      #|(Comment, " hi ")
    ),
  )
}

///|
test "doctype constructor defaults name to html" {
  let node = @dom.doctype()
  debug_inspect(
    (node.kind(), node.name()),
    content=(
      #|(Doctype, "#doctype")
    ),
  )
}

///|
test "doctype constructor accepts public and system identifiers" {
  let node = @dom.doctype(
    public_id="-//W3C//DTD HTML 4.01//EN",
    system_id="http://www.w3.org/TR/html4/strict.dtd",
    force_quirks=true,
  )
  debug_inspect(
    (node.public_id, node.system_id, node.force_quirks),
    content=(
      #|(
      #|  Some("-//W3C//DTD HTML 4.01//EN"),
      #|  Some("http://www.w3.org/TR/html4/strict.dtd"),
      #|  true,
      #|)
    ),
  )
}

///|
test "fragment vs document have distinct kinds" {
  let f = @dom.fragment()
  let d = @dom.document()
  debug_inspect(
    (f.kind(), d.kind()),
    content=(
      #|(Fragment, Document)
    ),
  )
}

///|
test "element accepts a namespace" {
  let svg = @dom.element("svg", ns="http://www.w3.org/2000/svg")
  debug_inspect(
    (svg.name(), svg.namespace_uri()),
    content=(
      #|("svg", Some("http://www.w3.org/2000/svg"))
    ),
  )
}
