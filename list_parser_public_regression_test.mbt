///|
test "parser closes open list items before repeated li starts" {
  let fragment = @html_parser.parse_fragment(
    "<ul><li>one<li><p>two<li>three</ul>",
  )
  assert_eq(
    fragment.to_html(pretty=false),
    "<ul><li>one</li><li><p>two</p></li><li>three</li></ul>",
  )
  let loose = @html_parser.parse_fragment("<li>loose<li>item")
  assert_eq(loose.to_html(pretty=false), "<li>loose</li><li>item</li>")
  let nested_inline = @html_parser.parse_fragment(
    "<ul><li><span>one<li>two</ul>",
    collect_errors=true,
  )
  assert_eq(
    nested_inline.to_html(pretty=false),
    "<ul><li><span>one</span></li><li>two</li></ul>",
  )
  assert_eq(nested_inline.errors.length(), 0)
}
