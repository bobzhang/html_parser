///|
test "stream emits start text end events" {
  let events = @html_parser.stream(
    "<div class=\"container\">Hello <b>World</b></div>",
  )
  assert_true(
    events ==
    [
      StreamStart({ name: "div", attrs: { "class": Some("container") } }),
      StreamText("Hello "),
      StreamStart({ name: "b", attrs: {} }),
      StreamText("World"),
      StreamEnd("b"),
      StreamEnd("div"),
    ],
  )
}

///|
test "stream emits comments doctypes void elements and unmatched end tags" {
  assert_true(
    @html_parser.stream("<!-- comment -->") == [StreamComment(" comment ")],
  )
  assert_true(
    @html_parser.stream("<!DOCTYPE html>") ==
    [StreamDoctype({ name: "html", public_id: None, system_id: None })],
  )
  assert_true(
    @html_parser.stream("<br><hr>") ==
    [
      StreamStart({ name: "br", attrs: {} }),
      StreamStart({ name: "hr", attrs: {} }),
    ],
  )
  assert_true(@html_parser.stream("</div>") == [StreamEnd("div")])
}

///|
test "stream coalesces text and preserves script raw text" {
  assert_true(@html_parser.stream("abc") == [StreamText("abc")])
  assert_true(
    @html_parser.stream("<script>console.log('<');</script>") ==
    [
      StreamStart({ name: "script", attrs: {} }),
      StreamText("console.log('<');"),
      StreamEnd("script"),
    ],
  )
}
