///|
test "example formatter produces pretty html" {
  assert_eq(
    @html_parser_examples.pretty_fragment(
      "<article><p>Hello <b>MoonBit</b></p></article>",
    ),
    "<article>\n  <p>Hello <b>MoonBit</b></p>\n</article>",
  )
}

///|
test "example formatter can produce compact html" {
  assert_eq(
    @html_parser_examples.compact_fragment(
      "<p class='intro'>Hello <b>MoonBit</b></p>",
    ),
    "<p class=\"intro\">Hello <b>MoonBit</b></p>",
  )
}
