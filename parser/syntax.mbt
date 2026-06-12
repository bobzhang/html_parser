///|
fn line_col_at(input : StringView, target : Int) -> (Int, Int) {
  @syn.line_col_at(input, target)
}

///|
fn strip_leading_bom(input : StringView) -> StringView {
  @syn.strip_leading_bom(input)
}

///|
fn normalize_newlines(input : StringView) -> StringView {
  // The common case has no carriage returns: the input view passes
  // through unchanged without the copy @syn.normalize_newlines makes.
  if !input.contains_char('\r') {
    return input
  }
  @syn.normalize_newlines(input)[:]
}

///|
fn normalize_bogus_comment_data(input : StringView) -> String {
  @syn.normalize_bogus_comment_data(input)
}

///|
fn starts_with_case_insensitive(
  input : StringView,
  pos : Int,
  prefix : StringView,
) -> Bool {
  @syn.starts_with_case_insensitive(input, pos, prefix)
}
