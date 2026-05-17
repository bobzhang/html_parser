///|
pub fn pretty_fragment(input : String, indent_size? : Int = 2) -> String raise {
  @html_parser.parse_fragment(input).to_html(pretty=true, indent_size~)
}

///|
pub fn compact_fragment(input : String) -> String raise {
  @html_parser.parse_fragment(input).to_html(pretty=false)
}
