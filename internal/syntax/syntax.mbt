///|
pub fn lower_ascii(input : StringView) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  for ch in input {
    if ch.is_ascii_uppercase() {
      out.write_char(ch.to_ascii_lowercase())
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
pub fn starts_with_case_insensitive(
  input : StringView,
  pos : Int,
  prefix : StringView,
) -> Bool {
  let end = pos + prefix.length()
  match input.get_view(start=pos, end~) {
    Some(view) => view.compare_ignore_ascii_case(prefix) == 0
    None => false
  }
}
