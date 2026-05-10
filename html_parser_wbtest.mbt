// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "dom insert_child_before moves appends and rejects cycles" {
  let parent = element("div")
  let first = element("p", children=[text("first")])
  let second = element("span", children=[text("second")])
  parent.append_child(first)
  parent.append_child(second)
  let inserted = element("em", children=[text("mid")])
  parent.insert_child_before(inserted, second)
  assert_eq(
    parent.to_html(pretty=false),
    "<div><p>first</p><em>mid</em><span>second</span></div>",
  )
  let fallback = element("strong", children=[text("end")])
  parent.insert_child_before(fallback, element("missing"))
  assert_eq(
    parent.to_html(pretty=false),
    "<div><p>first</p><em>mid</em><span>second</span><strong>end</strong></div>",
  )
  let other = element("section")
  other.append_child(inserted)
  assert_eq(
    parent.to_html(pretty=false),
    "<div><p>first</p><span>second</span><strong>end</strong></div>",
  )
  assert_eq(other.to_html(pretty=false), "<section><em>mid</em></section>")
  inserted.append_child(other)
  assert_eq(inserted.to_html(pretty=false), "<em>mid</em>")
  let non_container = comment("x")
  non_container.insert_child_before(text("ignored"), first)
  assert_eq(non_container.children().length(), 0)
  non_container.remove_child(first)
  assert_eq(first.to_html(pretty=false), "<p>first</p>")
}

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
    markdown_collect_text(
      element("code", children=[comment("skip"), text("x"), doctype()]),
    ),
    "x",
  )
  let builder = MarkdownBuilder::new()
  builder.raw("a\n\n\n")
  assert_eq(builder.newline_count, 2)
  assert_eq(builder.pending_space, false)
  assert_eq(builder.finish(), "a")
}
