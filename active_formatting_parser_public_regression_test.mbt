///|
test "parser reconstructs active formatting across paragraph recovery" {
  let split = @html_parser.parse_fragment(
    "<p><b>one<p>two</b>",
    track_node_locations=true,
  )
  assert_eq(split.to_html(pretty=false), "<p><b>one</b></p><p><b>two</b></p>")
  let split_bold = split.root.query("b")
  guard split_bold.length() == 2 else { fail("expected reconstructed bold") }
  assert_node_origin(split_bold[0], 3, 1, 4)
  assert_node_origin(split_bold[1], 3, 1, 4)
  let trailing = @html_parser.parse_fragment(
    "<p><b>one</p>two",
    track_node_locations=true,
  )
  assert_eq(trailing.to_html(pretty=false), "<p><b>one</b></p><b>two</b>")
  let trailing_bold = trailing.root.query("b")
  guard trailing_bold.length() == 2 else {
    fail("expected trailing reconstructed bold")
  }
  assert_node_origin(trailing_bold[0], 3, 1, 4)
  assert_node_origin(trailing_bold[1], 3, 1, 4)
  let inline_start = @html_parser.parse_fragment(
    "<p><b>one</p><span>two</span>",
    track_node_locations=true,
  )
  assert_eq(
    inline_start.to_html(pretty=false),
    "<p><b>one</b></p><b><span>two</span></b>",
  )
  let inline_bold = inline_start.root.query("b")
  guard inline_bold.length() == 2 else {
    fail("expected inline reconstructed bold")
  }
  assert_node_origin(inline_bold[0], 3, 1, 4)
  assert_node_origin(inline_bold[1], 3, 1, 4)
  let block_start = @html_parser.parse_fragment(
    "<p><b>one</p><div>two</div>",
    track_node_locations=true,
  )
  assert_eq(
    block_start.to_html(pretty=false),
    "<p><b>one</b></p><div><b>two</b></div>",
  )
  let block_bold = block_start.root.query("b")
  guard block_bold.length() == 2 else {
    fail("expected block reconstructed bold")
  }
  assert_node_origin(block_bold[0], 3, 1, 4)
  assert_node_origin(block_bold[1], 3, 1, 4)
}

///|
test "parser adoption agency preserves formatting origins" {
  let inline = @html_parser.parse_fragment(
    "<b><i>1</b>2</i>",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(inline.to_html(pretty=false), "<b><i>1</i></b><i>2</i>")
  assert_eq(inline.errors.length(), 1)
  assert_eq(inline.errors[0].code, "adoption-agency-1.3")
  let inline_bold = inline.root.query("b")
  guard inline_bold.length() == 1 else { fail("expected one inline bold") }
  assert_node_origin(inline_bold[0], 0, 1, 1)
  let inline_italic = inline.root.query("i")
  guard inline_italic.length() == 2 else { fail("expected replacement italic") }
  assert_node_origin(inline_italic[0], 3, 1, 4)
  assert_node_origin(inline_italic[1], 3, 1, 4)
  let block = @html_parser.parse_fragment(
    "<b><p>1</b>2",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(block.to_html(pretty=false), "<b></b><p><b>1</b>2</p>")
  assert_eq(block.errors.length(), 1)
  assert_eq(block.errors[0].code, "adoption-agency-1.3")
  let block_bold = block.root.query("b")
  guard block_bold.length() == 2 else {
    fail("expected block replacement bold")
  }
  assert_node_origin(block_bold[0], 0, 1, 1)
  assert_node_origin(block_bold[1], 0, 1, 1)
  let nested = @html_parser.parse_fragment(
    "<b><i><p>1</b>2</i>",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<b><i></i></b><i></i><p><i><b>1</b>2</i></p>",
  )
  assert_eq(nested.errors.length(), 2)
  assert_eq(nested.errors[0].code, "adoption-agency-1.3")
  assert_eq(nested.errors[1].code, "adoption-agency-1.3")
  let nested_bold = nested.root.query("b")
  guard nested_bold.length() == 2 else {
    fail("expected nested replacement bold")
  }
  assert_node_origin(nested_bold[0], 0, 1, 1)
  assert_node_origin(nested_bold[1], 0, 1, 1)
  let nested_italic = nested.root.query("i")
  guard nested_italic.length() == 3 else {
    fail("expected nested replacement italic")
  }
  assert_node_origin(nested_italic[0], 3, 1, 4)
  assert_node_origin(nested_italic[1], 3, 1, 4)
  assert_node_origin(nested_italic[2], 3, 1, 4)
}
