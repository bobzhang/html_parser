///|
fn is_html_whitespace_char(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '\u{000C}' => true
    _ => false
  }
}

///|
fn normalize_transform_strings(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    let normalized = @syn.lower_ascii(value.trim())
    if normalized != "" && !out.contains(normalized) {
      out.push(normalized)
    }
  }
  out.sort()
  out
}

///|
fn copy_allowed_attrs_map(
  allowed : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let out : Map[String, Array[String]] = {}
  for tag, attrs in allowed {
    out[tag] = attrs.copy()
  }
  out
}

///|
fn normalize_allowed_attrs_map(
  allowed : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let out : Map[String, Array[String]] = {}
  for tag, attrs in allowed {
    let normalized_tag = @syn.lower_ascii(tag[:].trim())
    if normalized_tag != "" {
      out[normalized_tag] = normalize_transform_strings(attrs)
    }
  }
  out
}
