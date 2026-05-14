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

///|
test "parser closes open definition items before repeated dt and dd starts" {
  let fragment = @html_parser.parse_fragment(
    "<dl><dt>term<dt>next<dd><p>def<dd>again</dl>",
  )
  assert_eq(
    fragment.to_html(pretty=false),
    "<dl><dt>term</dt><dt>next</dt><dd><p>def</p></dd><dd>again</dd></dl>",
  )
  let loose = @html_parser.parse_fragment("<dt>term<dd>def<dt>next")
  assert_eq(
    loose.to_html(pretty=false),
    "<dt>term</dt><dd>def</dd><dt>next</dt>",
  )
  let nested_terms = @html_parser.parse_fragment(
    "<dl><dt>A<dl><dt>B</dt></dl></dt><dt>C</dt></dl>",
    collect_errors=true,
  )
  assert_eq(
    nested_terms.to_html(pretty=false),
    "<dl><dt>A<dl><dt>B</dt></dl></dt><dt>C</dt></dl>",
  )
  assert_eq(nested_terms.errors.length(), 0)
  let nested_definitions = @html_parser.parse_fragment(
    "<dl><dd>A<dl><dd>B</dd></dl></dd><dd>C</dd></dl>",
    collect_errors=true,
  )
  assert_eq(
    nested_definitions.to_html(pretty=false),
    "<dl><dd>A<dl><dd>B</dd></dl></dd><dd>C</dd></dl>",
  )
  assert_eq(nested_definitions.errors.length(), 0)
  let nested_mixed = @html_parser.parse_fragment(
    "<dl><dt>A<dl><dd>B</dd></dl></dt><dd>C</dd></dl>",
    collect_errors=true,
  )
  assert_eq(
    nested_mixed.to_html(pretty=false),
    "<dl><dt>A<dl><dd>B</dd></dl></dt><dd>C</dd></dl>",
  )
  assert_eq(nested_mixed.errors.length(), 0)
}
