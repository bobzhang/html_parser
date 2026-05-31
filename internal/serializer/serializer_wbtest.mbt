///|
test "text chunk helpers initialize empty chunk arrays" {
  let breaks : Array[Array[String]] = []
  text_chunk_break(breaks)
  assert_eq(breaks.length(), 1)
  assert_eq(breaks[0].length(), 0)
  text_chunk_break(breaks)
  assert_eq(breaks.length(), 1)
  let chunks : Array[Array[String]] = []
  let current = current_text_chunk(chunks)
  assert_eq(chunks.length(), 1)
  current.push("A")
  assert_eq(text_chunks_to_string(chunks, "|", true), "A")
  text_chunk_break(chunks)
  assert_eq(chunks.length(), 2)
  current_text_chunk(chunks).push("B")
  assert_eq(text_chunks_to_string(chunks, "|", true), "A|B")
}

///|
test "pretty text helpers keep empty elements out of text-only path" {
  assert_eq(element_has_only_text_children(@dom.element("div")), false)
  let pre = @dom.element("pre", children=[@dom.text("  a\n<b>&c  ")])
  assert_true(element_has_only_text_children(pre))
  assert_eq(compact_pretty_text_children(pre, '"'), "  a\n&lt;b&gt;&amp;c  ")
  let paragraph = @dom.element("p", children=[
    @dom.text("  a\n"),
    @dom.text("  b  "),
  ])
  assert_true(element_has_only_text_children(paragraph))
  assert_eq(compact_pretty_text_children(paragraph, '"'), "a b")
}

///|
test "pretty serializer skips escape-only sentinels inside inline runs" {
  let hidden_text = @dom.text("hidden")
  hidden_text.sanitize_escape_only = true
  assert_eq(node_to_html_pretty(hidden_text, 0, 2, '"'), "")

  let hidden_run = @dom.text("hidden")
  hidden_run.sanitize_escape_only = true
  let inline = @dom.element("div", children=[
    hidden_run,
    @dom.text("\n"),
    @dom.text("shown"),
  ])
  guard node_to_html_pretty_inline_runs(inline, 0, 2, '"') is Some(rendered) else {
    fail("expected inline run rendering")
  }
  assert_eq(rendered, "<div>\n  shown\n</div>")

  let hidden_only = @dom.text("hidden")
  hidden_only.sanitize_escape_only = true
  let empty_inline = @dom.element("div", children=[hidden_only, @dom.text("\n")])
  assert_true(node_to_html_pretty_inline_runs(empty_inline, 0, 2, '"') is None)
}

///|
test "serializer hex digit helper keeps defensive fallback" {
  assert_eq(hex_digit_upper(0), '0')
  assert_eq(hex_digit_upper(15), 'F')
  assert_eq(hex_digit_upper(16), '0')
}
