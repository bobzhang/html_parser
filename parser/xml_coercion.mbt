///|
fn is_xml_noncharacter(ch : Char) -> Bool {
  @syn.is_xml_noncharacter(ch)
}

///|
fn coerce_text_for_xml(input : StringView) -> String {
  @syn.coerce_text_for_xml(input)
}

///|
fn coerce_comment_for_xml(input : StringView) -> String {
  @syn.coerce_comment_for_xml(input)
}
