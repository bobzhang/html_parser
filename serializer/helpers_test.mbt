// Blackbox snapshot tests for the standalone serializer helpers:
// `to_text`, `to_test_format`, and `is_void_element`.

///|
test "to_text strips tags and joins text nodes" {
  let node = @dom.element("div", children=[
    @dom.element("p", children=[
      @dom.text("Hello "),
      @dom.element("b", children=[@dom.text("MoonBit")]),
    ]),
    @dom.element("p", children=[@dom.text("Second line")]),
  ])
  inspect(
    @serializer.to_text(node),
    content=(
      #|Hello MoonBit Second line
    ),
  )
}

///|
test "to_text strip=true collapses surrounding whitespace" {
  let node = @dom.element("p", children=[@dom.text("  hello   world  ")])
  let raw = @serializer.to_text(node, strip=false)
  let stripped = @serializer.to_text(node, strip=true)
  debug_inspect(
    (raw, stripped),
    content=(
      #|("  hello   world  ", "hello   world")
    ),
  )
}

///|
test "to_text separator joins block-level children" {
  let node = @dom.fragment(children=[
    @dom.element("p", children=[@dom.text("one")]),
    @dom.element("p", children=[@dom.text("two")]),
    @dom.element("p", children=[@dom.text("three")]),
  ])
  inspect(
    @serializer.to_text(node, separator=" | ", separator_blocks_only=true),
    content=(
      #|one | two | three
    ),
  )
}

///|
test "is_void_element knows the HTML5 void element list" {
  let void_tags = ["br", "hr", "img", "meta", "input", "link", "wbr", "area"]
  let block_tags = ["div", "p", "span", "section"]
  let void_results = void_tags.map(t => @serializer.is_void_element(t))
  let block_results = block_tags.map(t => @serializer.is_void_element(t))
  debug_inspect(
    (void_results, block_results),
    content=(
      #|(
      #|  [true, true, true, true, true, true, true, true],
      #|  [false, false, false, false],
      #|)
    ),
  )
}

///|
test "to_test_format dumps a tree in html5lib test format" {
  // This is the format the upstream html5lib test fixtures use; the
  // parser uses it for fixture comparisons and it makes structural
  // diffs easy to read.
  let node = @dom.element("p", attrs={ "class": Some("intro") }, children=[
    @dom.text("hi"),
  ])
  inspect(
    @serializer.to_test_format(node),
    content=(
      #|| <p>
      #||   class="intro"
      #||   "hi"
    ),
  )
}
