///|
fn assert_markdown_line_start_escape(
  value : StringView,
  replacement : String,
  consumed : Int,
) -> Unit raise {
  guard markdown_escape_line_start(value) is Some((actual, actual_consumed)) else {
    fail("expected markdown line-start escape")
  }
  assert_eq(actual, replacement)
  assert_eq(actual_consumed, consumed)
}

///|
test "markdown helper edge cases match reference" {
  assert_true(markdown_escape_line_start("") is None)
  assert_markdown_line_start_escape("# heading", "\\#", 1)
  assert_true(markdown_escape_line_start("#heading") is None)
  assert_markdown_line_start_escape("> quote", "\\>", 1)
  assert_markdown_line_start_escape("- item", "\\-", 1)
  assert_true(markdown_escape_line_start("-x") is None)
  assert_markdown_line_start_escape("+ item", "\\+", 1)
  assert_true(markdown_escape_line_start("+item") is None)
  assert_markdown_line_start_escape("1. item", "1\\.", 2)
  assert_markdown_line_start_escape("2) item", "2\\)", 2)
  assert_markdown_line_start_escape("12. item", "12\\.", 3)
  assert_markdown_line_start_escape("~~~", "\\~", 1)
  assert_true(markdown_escape_line_start("~~") is None)
  assert_markdown_line_start_escape("```", "\\`", 1)
  assert_true(markdown_escape_line_start("``") is None)
  assert_markdown_line_start_escape("---", "\\-", 1)
  assert_markdown_line_start_escape("===", "\\=", 1)
  assert_true(markdown_escape_line_start("=x") is None)
  assert_true(markdown_escape_line_start("plain text") is None)
  assert_eq(
    markdown_thematic_or_setext_line("   ", '-', minimum_markers=3),
    false,
  )
  assert_true(markdown_thematic_or_setext_line("- - -", '-', minimum_markers=3))
  assert_eq(
    markdown_thematic_or_setext_line("- - x", '-', minimum_markers=3),
    false,
  )
  assert_eq(markdown_link_destination(""), "")
  assert_eq(markdown_link_destination("   "), "")
  assert_eq(markdown_link_destination("https://e.com/x"), "https://e.com/x")
  assert_eq(
    markdown_link_destination("https://e.com/a b"),
    "<https://e.com/a%20b>",
  )
  assert_eq(
    markdown_link_destination("https://e.com/a\tb"),
    "<https://e.com/a%09b>",
  )
  assert_eq(
    markdown_link_destination("https://e.com/a\nb"),
    "<https://e.com/a%0Ab>",
  )
  assert_eq(
    markdown_link_destination("https://e.com/a\rb"),
    "<https://e.com/a%0Db>",
  )
  assert_eq(
    markdown_link_destination("https://e.com/a\u{000C}b"),
    "https://e.com/a\u{000C}b",
  )
  assert_eq(
    markdown_link_destination("https://e.com/a\u{000B}b"),
    "https://e.com/a\u{000B}b",
  )
  assert_eq(
    markdown_collect_text(
      @dom.element("code", children=[
        @dom.comment("skip"),
        @dom.text("x"),
        @dom.doctype(),
      ]),
    ),
    "x",
  )
  let boolean_href = @dom.element("a", attrs={ "href": None })
  assert_true(attribute_value_by_name(boolean_href, "href") is Some(""))
  let builder = MarkdownBuilder::new()
  builder.raw("a\n\n\n")
  assert_eq(builder.newline_count, 2)
  assert_eq(builder.pending_space, false)
  assert_eq(builder.finish(), "a")
  let leading_space = MarkdownBuilder::new()
  leading_space.text("   a")
  assert_eq(leading_space.finish(), "a")
  let raw_after_pending_space = MarkdownBuilder::new()
  raw_after_pending_space.text("a ")
  raw_after_pending_space.raw("**")
  raw_after_pending_space.raw("b")
  assert_eq(raw_after_pending_space.finish(), "a **b")
  let raw_newline_after_pending_space = MarkdownBuilder::new()
  raw_newline_after_pending_space.text("a ")
  raw_newline_after_pending_space.raw("\n")
  assert_eq(raw_newline_after_pending_space.finish(), "a")
}
