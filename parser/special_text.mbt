///|
fn Parser::is_special_text_element(self : Parser, name : StringView) -> Bool {
  if name == "noscript" {
    self.scripting_enabled
  } else {
    is_special_text_element(name)
  }
}

///|
fn is_special_text_element(name : StringView) -> Bool {
  match name {
    "iframe"
    | "noembed"
    | "noframes"
    | "noscript"
    | "plaintext"
    | "script"
    | "style"
    | "title"
    | "textarea"
    | "xmp" => true
    _ => false
  }
}

///|
fn special_text_eof_error_code(name : StringView) -> String {
  match name {
    "noframes" | "script" | "style" | "title" | "xmp" =>
      "expected-named-closing-tag-but-got-eof"
    _ => "expected-closing-tag-but-got-eof"
  }
}

///|
fn Parser::error_at_special_text_eof(self : Parser, name : StringView) -> Unit {
  self.error_at(special_text_eof_error_code(name), self.eof_error_pos())
}

///|
fn Parser::decoded_special_text(
  self : Parser,
  name : StringView,
  raw : StringView,
  start : Int,
  error_pos : Int,
) -> StringView {
  let (raw, offset) = if name == "textarea" {
    strip_one_initial_lf_with_offset(raw)
  } else {
    (raw, 0)
  }
  let raw = self.replace_null_characters(raw, start + offset)
  let data = if @tok.special_text_decodes_entities(name) {
    let decoded = @tok.decode_entities_with_errors(raw, in_attribute=false)
    for error in decoded.errors {
      self.error_at(error.code, error_pos)
    }
    decoded.data
  } else {
    normalize_newlines(raw)
  }
  let data = normalize_tree_builder_text(data)
  if self.xml_coercion {
    coerce_text_for_xml(data)[:]
  } else {
    data
  }
}

///|
fn strip_one_initial_lf_with_offset(input : StringView) -> (StringView, Int) {
  match input.get_char(0) {
    Some('\r') =>
      if input.get_char(1) is Some('\n') {
        (input[2:], 2)
      } else {
        (input[1:], 1)
      }
    Some('\n') => (input[1:], 1)
    _ => (input, 0)
  }
}

///|
fn Parser::skip_one_initial_lf(self : Parser) -> Unit {
  match self.current() {
    Some('\r') => {
      self.pos += 1
      if self.current() is Some('\n') {
        self.pos += 1
      }
    }
    Some('\n') => self.pos += 1
    _ => ()
  }
}

///|
fn start_tag_ignores_initial_lf(name : StringView) -> Bool {
  match name {
    "pre" | "listing" => true
    _ => false
  }
}

///|
fn Parser::skip_matching_end_tag(self : Parser) -> Unit {
  self.pos += 2
  while !self.is_eof() {
    if self.current().unwrap() == '>' {
      break
    } else {
      ignore(self.advance_char())
    }
  }
  if self.current() is Some('>') {
    ignore(self.advance_char())
  }
}

///|
fn Parser::consume_matching_special_end_tag(self : Parser) -> Bool {
  self.pos += 2
  while !self.is_eof() {
    guard self.current() is Some(ch) else { break }
    match ch {
      '>' | '/' => break
      ch if ch.is_ascii_whitespace() => break
      _ => ignore(self.advance_char())
    }
  }
  let attrs : Map[String, String?] = {}
  let mut closed = false
  while !self.is_eof() {
    self.skip_ascii_whitespace()
    guard self.current() is Some(ch) else { break }
    match ch {
      '>' => {
        ignore(self.advance_char())
        closed = true
        break
      }
      '/' => {
        ignore(self.advance_char())
        if self.current() is Some('>') {
          ignore(self.advance_char())
          closed = true
          break
        } else {
          self.error_at("unexpected-character-after-solidus-in-tag", self.pos)
        }
      }
      _ => self.parse_attribute(attrs)
    }
  }
  if !closed {
    self.error_at_eof("eof-in-tag")
  }
  closed
}

///|
/// Appends raw-text content as a text node, skipping empty content: the
/// spec never creates empty text nodes for raw-text elements (for example
/// `<textarea></textarea>` or `<xmp></xmp>`).
fn Parser::append_special_text(
  self : Parser,
  parent : @dom.Node,
  data : StringView,
  content_start : Int,
) -> Unit {
  if !data.is_empty() {
    parent.append_child(self.text_at(data, content_start))
  }
}

///|
fn Parser::consume_special_element_content(
  self : Parser,
  parent : @dom.Node,
  name : String,
) -> Unit {
  let content_start = self.pos
  if name == "plaintext" {
    let view = self.input[content_start:self.input.length()]
    let decoded = self.decoded_special_text(
      name,
      view,
      content_start,
      eof_error_pos(self.input),
    )
    // Plaintext characters are ordinary in-body tokens: active
    // formatting reconstructs inside the plaintext element when
    // characters are actually inserted.
    let mut target = parent
    if !decoded.is_empty() {
      let stack_before = self.stack.length()
      self.push_open_element(parent)
      self.reconstruct_active_formatting_elements()
      target = self.current_node()
      while self.stack.length() > stack_before {
        ignore(self.pop_open_element())
      }
    }
    self.append_special_text(target, decoded, content_start)
    self.error_at_special_text_eof(name)
    self.pos = self.input.length()
    return
  }
  if name == "script" {
    let scan = @tok.scan_script_text(self.input, self.pos)
    for error in scan.errors {
      self.error_at(error.code, error.offset)
    }
    if !scan.data.is_empty() {
      let scan_data = normalize_tree_builder_text(scan.data)
      let data = if self.xml_coercion {
        coerce_text_for_xml(scan_data)[:]
      } else {
        scan_data
      }
      parent.append_child(self.text_at(data, content_start))
    }
    match scan.end_start {
      Some(end_start) => {
        self.pos = end_start
        if !self.consume_matching_special_end_tag() {
          self.error_at_special_text_eof(name)
        }
      }
      None => {
        self.error_at_special_text_eof(name)
        self.pos = self.input.length()
      }
    }
    return
  }
  match @tok.find_matching_end_tag(self.input, self.pos, name) {
    Some(end_start) => {
      let error_pos = @tok.matching_end_tag_error_pos(self.input, end_start)
      let view = self.input[content_start:end_start]
      self.append_special_text(
        parent,
        self.decoded_special_text(name, view, content_start, error_pos),
        content_start,
      )
      self.pos = end_start
      if !self.consume_matching_special_end_tag() {
        self.error_at_special_text_eof(name)
      }
    }
    None => {
      let error_pos = eof_error_pos(self.input)
      let view = self.input[content_start:self.input.length()]
      self.append_special_text(
        parent,
        self.decoded_special_text(name, view, content_start, error_pos),
        content_start,
      )
      self.error_at_special_text_eof(name)
      self.pos = self.input.length()
    }
  }
}
