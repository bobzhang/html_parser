///|
/// Format an HTML fragment as readable, indented markup.
///
/// The fragment is parsed with the library's default fragment context and then
/// serialized with pretty printing enabled. `indent_size` controls the number
/// of spaces used for each nested element level.
pub fn pretty_fragment(input : String, indent_size? : Int = 2) -> String raise {
  @html_parser.parse_fragment(input).to_html(pretty=true, indent_size~)
}

///|
/// Format an HTML fragment as compact markup.
///
/// This parses the same fragment input as `pretty_fragment`, but serializes it
/// without layout whitespace so the result is suitable for golden-output checks
/// or CLI output that should stay on one line.
pub fn compact_fragment(input : String) -> String raise {
  @html_parser.parse_fragment(input).to_html(pretty=false)
}
