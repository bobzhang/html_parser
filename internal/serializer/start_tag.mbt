///|
fn serializable_ascii_alpha(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

///|
fn serializable_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn serializable_tag_name_char(ch : Char) -> Bool {
  serializable_ascii_alpha(ch) ||
  serializable_ascii_digit(ch) ||
  ch == ':' ||
  ch == '_' ||
  ch == '-'
}

///|
fn serializable_attr_name_start(ch : Char) -> Bool {
  serializable_ascii_alpha(ch) || ch == '_' || ch == ':'
}

///|
fn serializable_attr_name_char(ch : Char) -> Bool {
  serializable_attr_name_start(ch) ||
  serializable_ascii_digit(ch) ||
  ch == '-' ||
  ch == '.'
}

///|
fn validate_serializable_tag_name(
  name : StringView,
) -> Unit raise @core.HtmlError {
  match name.get_char(0) {
    Some(ch) if serializable_ascii_alpha(ch) => {
      let mut pos = ch.utf16_len()
      while pos < name.length() {
        match name.get_char(pos) {
          Some(ch) if serializable_tag_name_char(ch) => pos += ch.utf16_len()
          _ =>
            raise InvalidSerialization(
              "Unsafe element name for serialization: " + name.to_owned(),
            )
        }
      }
    }
    _ =>
      raise InvalidSerialization(
        "Unsafe element name for serialization: " + name.to_owned(),
      )
  }
}

///|
fn validate_serializable_attr_name(
  name : StringView,
) -> Unit raise @core.HtmlError {
  match name.get_char(0) {
    Some(ch) if serializable_attr_name_start(ch) => {
      let mut pos = ch.utf16_len()
      while pos < name.length() {
        match name.get_char(pos) {
          Some(ch) if serializable_attr_name_char(ch) => pos += ch.utf16_len()
          _ =>
            raise InvalidSerialization(
              "Unsafe attribute name for serialization: " + name.to_owned(),
            )
        }
      }
    }
    _ =>
      raise InvalidSerialization(
        "Unsafe attribute name for serialization: " + name.to_owned(),
      )
  }
}

///|
fn attr_value_should_minimize(name : StringView, value : StringView) -> Bool {
  value.is_empty() || value.compare_ignore_ascii_case(name) == 0
}

///|
fn choose_attr_quote(value : StringView, preferred : Char) -> Char {
  if preferred == '\'' {
    '\''
  } else if string_contains_char(value, '"') &&
    !string_contains_char(value, '\'') {
    '\''
  } else {
    '"'
  }
}

///|
pub fn validate_serialization_quote(quote : Char) -> Char raise @core.HtmlError {
  match quote {
    '"' | '\'' => quote
    _ => raise InvalidSerialization("quote must be ' or \"")
  }
}

///|
/// Serialize a start tag without validating element or attribute names.
///
/// Attribute values are escaped and may use the requested quote character, but
/// callers must ensure `node.name` and all attribute names are already safe for
/// serialization. Use the checked serializer path for untrusted names.
pub fn serialize_start_tag_unchecked(node : @dom.Node, quote : Char) -> String {
  let out = StringBuilder::StringBuilder()
  out <+ "<\{node.name}"
  for name, value in node.attrs {
    out <+ " \{name}"
    match value {
      Some(v) if attr_value_should_minimize(name, v) => ()
      Some(v) => {
        let attr_quote = choose_attr_quote(v, quote)
        out <+ "=\{attr_quote}\{escape_attr_value(v, attr_quote)}\{attr_quote}"
      }
      None => ()
    }
  }
  out.write_char('>')
  out.to_string()
}

///|
fn serialize_start_tag(
  node : @dom.Node,
  quote : Char,
) -> String raise @core.HtmlError {
  validate_serializable_tag_name(node.name)
  for name, _ in node.attrs {
    validate_serializable_attr_name(name)
  }
  serialize_start_tag_unchecked(node, quote)
}
