# `@dom`

The DOM data type and its constructors. Every node the parser produces
— and every node the serializer consumes — is a `@dom.Node`.

The examples below are `mbt check` blocks and run as part of
`moon test dom`.

## Node kinds

```mbt nocheck
///|
pub(all) enum NodeKind {
  Document
  Fragment
  Element
  Text
  Comment
  Doctype
}
```

## Constructors

Each kind has its own constructor; they all return a `Node`.

```mbt check
///|
test "readme dom constructors" {
  let p = @dom.element("p", attrs={ "class": Some("intro") }, children=[
    @dom.text("hi"),
  ])
  debug_inspect(
    (p.kind(), p.name(), p.attrs(), p.children().length()),
    content=(
      #|(Element, "p", { "class": Some("intro") }, 1)
    ),
  )
}
```

```mbt check
///|
test "readme dom doctype" {
  // The `data` field carries the doctype's declared name (default
  // "html"); the `name` field carries the structural label
  // "#doctype".
  let dt = @dom.doctype()
  debug_inspect(
    (dt.kind(), dt.name(), dt.data),
    content=(
      #|(Doctype, "#doctype", "html")
    ),
  )
}
```

## Tree mutation

Mutation is in-place: `append_child`, `insert_before`,
`remove_child`, and `replace_child` all update the parent links and
the `children` array.

```mbt check
///|
test "readme dom append and remove" {
  let parent = @dom.element("ul")
  let a = @dom.element("li", children=[@dom.text("one")])
  let b = @dom.element("li", children=[@dom.text("two")])
  parent.append_child(a)
  parent.append_child(b)
  parent.remove_child(a)
  // Use kind/name pairs instead of dumping every node, which would
  // include parent back-pointers.
  debug_inspect(
    parent.children().map(c => (c.kind(), c.name(), c.text())),
    content=(
      #|[(Element, "li", "two")]
    ),
  )
}
```

## Walking the tree

```mbt check
///|
test "readme dom text concatenation" {
  let node = @dom.element("p", children=[
    @dom.text("Hello "),
    @dom.element("b", children=[@dom.text("MoonBit")]),
    @dom.text("!"),
  ])
  inspect(
    node.text(),
    content=(
      #|Hello MoonBit!
    ),
  )
}
```

## Cloning

`clone_node()` makes a shallow copy by default — children are
dropped. `deep=true` mirrors the entire subtree.

```mbt check
///|
test "readme dom clone shallow vs deep" {
  let original = @dom.element("p", children=[@dom.text("hi")])
  debug_inspect(
    (
      original.clone_node().children().length(),
      original.clone_node(deep=true).children().length(),
    ),
    content=(
      #|(0, 1)
    ),
  )
}
```
