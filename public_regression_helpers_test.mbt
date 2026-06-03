///|
fn[T] html_result(
  body : () -> T raise @html_parser.HtmlError,
) -> Result[T, @html_parser.HtmlError] {
  try body() catch {
    error => Err(error)
  } noraise {
    value => Ok(value)
  }
}

///|
fn assert_node_origin(
  node : @html_parser.Node,
  offset : Int,
  line : Int,
  col : Int,
) -> Unit raise {
  guard node.origin_offset() is Some(actual_offset) && actual_offset == offset else {
    fail("unexpected origin offset")
  }
  guard node.origin_line() is Some(actual_line) && actual_line == line else {
    fail("unexpected origin line")
  }
  guard node.origin_col() is Some(actual_col) && actual_col == col else {
    fail("unexpected origin column")
  }
  guard node.origin_location() is Some((actual_line, actual_col)) &&
    actual_line == line &&
    actual_col == col else {
    fail("unexpected origin location")
  }
}

///|
fn repeat_for_test(value : String, count : Int) -> String {
  let out = StringBuilder(size_hint=value.length() * count)
  for _ in 0..<count {
    out.write_string(value)
  }
  out.to_string()
}
