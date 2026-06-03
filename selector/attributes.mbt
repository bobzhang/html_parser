///|
fn attribute_value_by_name(node : @dom.Node, attr_name : StringView) -> String? {
  let wanted = @syn.lower_ascii(attr_name)
  for name, value in node.attrs {
    if @syn.lower_ascii(name) == wanted {
      return Some(
        match value {
          Some(text) => text
          None => ""
        },
      )
    }
  }
  None
}

///|
priv enum AttributeSelectorOperator {
  AttrExact
  AttrWord
  AttrHyphen
  AttrPrefix
  AttrSuffix
  AttrContains
}

///|
fn attribute_name_with_operator(
  name : StringView,
  operator : AttributeSelectorOperator,
) -> (StringView, AttributeSelectorOperator)? {
  let end = name.length() - 1
  guard name.get_view(start=0, end~) is Some(name) else { return None }
  let name = name.trim()
  if !selector_identifier_is_valid(name) {
    None
  } else {
    Some((name, operator))
  }
}

///|
fn attribute_name_and_operator(
  name : StringView,
) -> (StringView, AttributeSelectorOperator)? {
  let name = name.trim()
  if name.has_suffix("~") {
    attribute_name_with_operator(name, AttrWord)
  } else if name.has_suffix("|") {
    attribute_name_with_operator(name, AttrHyphen)
  } else if name.has_suffix("^") {
    attribute_name_with_operator(name, AttrPrefix)
  } else if name.has_suffix("$") {
    attribute_name_with_operator(name, AttrSuffix)
  } else if name.has_suffix("*") {
    attribute_name_with_operator(name, AttrContains)
  } else if selector_identifier_is_valid(name) {
    Some((name, AttrExact))
  } else {
    None
  }
}

///|
fn quoted_attribute_selector_value(value : StringView) -> String? {
  let value = value.trim()
  if value.length() < 2 {
    return Some(value.to_owned())
  }
  let end = value.length() - 1
  match (value.get_char(0), value.get_char(end)) {
    (Some('"'), Some('"')) | (Some('\''), Some('\'')) =>
      Some(unescape_quoted_attribute_selector_value(value[1:end]))
    _ =>
      if string_view_has_html_whitespace(value) {
        None
      } else {
        Some(value.to_owned())
      }
  }
}

///|
fn unescape_quoted_attribute_selector_value(value : StringView) -> String {
  let out = StringBuilder(size_hint=value.length())
  let mut escaped = false
  for ch in value {
    if escaped {
      out.write_char(ch)
      escaped = false
    } else if ch == '\\' {
      escaped = true
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn attribute_hyphen_matches(actual : StringView, expected : StringView) -> Bool {
  if actual == expected {
    return true
  }
  if actual.length() <= expected.length() || !actual.has_prefix(expected) {
    return false
  }
  match actual.get_char(expected.length()) {
    Some('-') => true
    _ => false
  }
}

///|
fn attribute_value_matches(
  actual : StringView,
  operator : AttributeSelectorOperator,
  expected : StringView,
) -> Bool {
  match operator {
    AttrExact => actual == expected
    AttrWord => class_contains(actual, expected)
    AttrHyphen => attribute_hyphen_matches(actual, expected)
    AttrPrefix => !expected.is_empty() && actual.has_prefix(expected)
    AttrSuffix => !expected.is_empty() && actual.has_suffix(expected)
    AttrContains => string_view_contains(actual, expected)
  }
}

///|
fn attribute_selector_matches(node : @dom.Node, selector : StringView) -> Bool {
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  match selector.split_once("=") {
    Some((name, expected)) => {
      guard attribute_name_and_operator(name) is Some((name, operator)) else {
        return false
      }
      guard quoted_attribute_selector_value(expected) is Some(expected) else {
        return false
      }
      match attribute_value_by_name(node, name) {
        Some(actual) => attribute_value_matches(actual, operator, expected)
        None => false
      }
    }
    None =>
      selector_identifier_is_valid(selector) &&
      attribute_value_by_name(node, selector) is Some(_)
  }
}

///|
fn attribute_selector_is_valid(selector : StringView) -> Bool {
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  match selector.split_once("=") {
    Some((name, expected)) =>
      attribute_name_and_operator(name) is Some(_) &&
      quoted_attribute_selector_value(expected) is Some(_)
    None => selector_identifier_is_valid(selector)
  }
}
