///|
fn linkify_href_for(candidate : StringView) -> (String, String) {
  let text = candidate.to_owned()
  if @syn.starts_with_case_insensitive(candidate, 0, "mailto:") {
    return (text, "email")
  }
  if string_view_contains(candidate, "@") &&
    !linkify_is_scheme_url(candidate) &&
    !@syn.starts_with_case_insensitive(candidate, 0, "//") &&
    !@syn.starts_with_case_insensitive(candidate, 0, "www.") {
    return ("mailto:" + text, "email")
  }
  if linkify_is_scheme_url(candidate) ||
    @syn.starts_with_case_insensitive(candidate, 0, "//") {
    return (linkify_punycode_href(text), "url")
  }
  (linkify_punycode_href("http://" + text), "url")
}

///|
fn linkify_is_scheme(candidate : StringView) -> Bool {
  @syn.starts_with_case_insensitive(candidate, 0, "http://") ||
  @syn.starts_with_case_insensitive(candidate, 0, "https://") ||
  @syn.starts_with_case_insensitive(candidate, 0, "ftp://") ||
  @syn.starts_with_case_insensitive(candidate, 0, "mailto:")
}

///|
fn linkify_is_scheme_url(candidate : StringView) -> Bool {
  @syn.starts_with_case_insensitive(candidate, 0, "http://") ||
  @syn.starts_with_case_insensitive(candidate, 0, "https://") ||
  @syn.starts_with_case_insensitive(candidate, 0, "ftp://")
}
