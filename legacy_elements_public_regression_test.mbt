///|
test "parser inserts keygen and fragment frame as empty non-void elements" {
  let keygen = @html_parser.parse_fragment(
    "<p>a<keygen>b</p><keygen>x</keygen>",
    collect_errors=true,
  )
  assert_eq(
    keygen.to_html(pretty=false),
    "<p>a<keygen></keygen>b</p><keygen></keygen>x",
  )
  assert_eq(keygen.errors.length(), 1)
  assert_eq(keygen.errors[0].code, "unexpected-end-tag")
  let self_closing_keygen = @html_parser.parse_fragment("<keygen/>x")
  assert_eq(self_closing_keygen.to_html(pretty=false), "<keygen></keygen>x")
  let frame = @html_parser.parse_fragment(
    "<p>a<frame>b</p><frame>x</frame>",
    collect_errors=true,
  )
  assert_eq(
    frame.to_html(pretty=false),
    "<p>a<frame></frame>b</p><frame></frame>x",
  )
  assert_eq(frame.errors.length(), 1)
  assert_eq(frame.errors[0].code, "unexpected-end-tag")
}

///|
test "document parser ignores frame starts in body mode" {
  let paragraph = @html_parser.parse(
    "<!doctype html><p>a<frame>b</p>",
    collect_errors=true,
  )
  assert_eq(
    paragraph.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p>ab</p></body></html>",
  )
  assert_eq(paragraph.errors.length(), 1)
  assert_eq(paragraph.errors[0].code, "unexpected-start-tag-ignored")
  let root = @html_parser.parse(
    "<!doctype html><frame>x</frame>",
    collect_errors=true,
  )
  assert_eq(
    root.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body>x</body></html>",
  )
  assert_eq(root.errors.length(), 2)
  assert_eq(root.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(root.errors[1].code, "unexpected-end-tag")
}

///|
test "parser handles keygen and frame starts in select mode" {
  let keygen = @html_parser.parse_fragment(
    "<select><keygen>x</keygen></select>",
    collect_errors=true,
  )
  assert_eq(keygen.to_html(pretty=false), "<select><keygen></keygen>x</select>")
  assert_eq(keygen.errors.length(), 1)
  assert_eq(keygen.errors[0].code, "unexpected-end-tag")
  let frame = @html_parser.parse_fragment(
    "<select><frame>x</frame></select>",
    collect_errors=true,
  )
  assert_eq(frame.to_html(pretty=false), "<select>x</select>")
  assert_eq(frame.errors.length(), 2)
  assert_eq(frame.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(frame.errors[1].code, "unexpected-end-tag")
}

///|
test "parser treats legacy raw text elements as text" {
  let doc = @html_parser.parse_fragment(
    "<iframe><b>x</b></iframe><noembed><i>y</i></noembed><noscript><em>z</em></noscript>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<iframe>&lt;b&gt;x&lt;/b&gt;</iframe><noembed>&lt;i&gt;y&lt;/i&gt;</noembed><noscript>&lt;em&gt;z&lt;/em&gt;</noscript>",
  )
  assert_eq(doc.query("b").length(), 0)
  assert_eq(doc.query("i").length(), 0)
  assert_eq(doc.query("em").length(), 0)
}
