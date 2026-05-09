///|
priv struct Parser {
  input : StringView
  scripting_enabled : Bool
  mut pos : Int
  errors : Array[ParseError]
  root : Node
  stack : Array[Node]
}

///|
fn Parser::new(
  input : StringView,
  root : Node,
  scripting_enabled~ : Bool,
) -> Parser {
  let input = strip_leading_bom(input)
  Parser::{ input, scripting_enabled, pos: 0, errors: [], root, stack: [root] }
}

///|
fn Parser::current(self : Parser) -> Char? {
  self.input.get_char(self.pos)
}

///|
fn Parser::is_eof(self : Parser) -> Bool {
  self.pos >= self.input.length()
}

///|
fn Parser::advance_char(self : Parser) -> Char? {
  match self.current() {
    Some(ch) => {
      self.pos += ch.utf16_len()
      Some(ch)
    }
    None => None
  }
}

///|
fn Parser::starts_with(self : Parser, prefix : StringView) -> Bool {
  let end = self.pos + prefix.length()
  match self.input.get_view(start=self.pos, end~) {
    Some(view) => view == prefix
    None => false
  }
}

///|
fn Parser::skip_ascii_whitespace(self : Parser) -> Unit {
  while !self.is_eof() {
    match self.current() {
      Some(ch) if ch.is_ascii_whitespace() => ignore(self.advance_char())
      _ => return
    }
  }
}

///|
fn Parser::current_node(self : Parser) -> Node {
  match self.stack.last() {
    Some(node) => node
    None => self.root
  }
}

///|
fn Parser::append_text(self : Parser, raw : StringView, start : Int) -> Unit {
  if raw.is_empty() {
    return
  }
  let cleaned = self.remove_null_characters(raw, start)
  if cleaned.is_empty() {
    return
  }
  self
  .current_node()
  .append_child(text(decode_entities(cleaned, in_attribute=false)))
}

///|
fn Parser::remove_null_characters(
  self : Parser,
  raw : StringView,
  start : Int,
) -> String {
  let out = StringBuilder::new(size_hint=raw.length())
  let mut pos = 0
  while pos < raw.length() {
    match raw.get_char(pos) {
      Some('\u{0000}') => {
        self.error_at("unexpected-null-character", start + pos)
        pos += 1
      }
      Some(ch) => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  out.to_string()
}

///|
fn Parser::replace_null_characters(
  self : Parser,
  raw : StringView,
  start : Int,
) -> String {
  let out = StringBuilder::new(size_hint=raw.length())
  let mut pos = 0
  while pos < raw.length() {
    match raw.get_char(pos) {
      Some('\u{0000}') => {
        self.error_at("unexpected-null-character", start + pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some(ch) => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  out.to_string()
}

///|
fn Parser::error_at(self : Parser, code : String, pos : Int) -> Unit {
  let (line, column) = line_col_at(self.input, pos)
  self.errors.push(ParseError::new(code, line~, column~))
}

///|
fn Parser::parse_all(self : Parser) -> Unit {
  while !self.is_eof() {
    let start = self.pos
    match self.current() {
      Some('<') =>
        if self.starts_with("<!--") {
          self.parse_comment()
        } else if self.starts_with("</") {
          self.parse_end_tag()
        } else if starts_with_case_insensitive(
            self.input,
            self.pos,
            "<!doctype",
          ) {
          self.parse_doctype()
        } else {
          self.parse_start_tag_or_text()
        }
      Some(_) => {
        while !self.is_eof() && !self.starts_with("<") {
          ignore(self.advance_char())
        }
        match self.input.get_view(start~, end=self.pos) {
          Some(view) => self.append_text(view, start)
          None => ()
        }
      }
      None => ()
    }
  }
}

///|
fn Parser::parse_comment(self : Parser) -> Unit {
  let start = self.pos
  self.pos += 4
  let data_start = self.pos
  while !self.is_eof() && !self.starts_with("-->") {
    ignore(self.advance_char())
  }
  if self.is_eof() {
    self.error_at("eof-in-comment", start)
    match self.input.get_view(start=data_start, end=self.pos) {
      Some(view) =>
        self.current_node().append_child(comment(normalize_newlines(view)))
      None => ()
    }
  } else {
    match self.input.get_view(start=data_start, end=self.pos) {
      Some(view) =>
        self.current_node().append_child(comment(normalize_newlines(view)))
      None => ()
    }
    self.pos += 3
  }
}

///|
fn Parser::parse_doctype(self : Parser) -> Unit {
  self.pos += "<!doctype".length()
  self.skip_ascii_whitespace()
  let name_start = self.pos
  while !self.is_eof() {
    match self.current() {
      Some('>') => break
      Some(ch) if ch.is_ascii_whitespace() => break
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  let name = match self.input.get_view(start=name_start, end=self.pos) {
    Some(view) if !view.is_empty() => lower_ascii(view)
    _ => "html"
  }
  let ids_start = self.pos
  while !self.is_eof() && !self.starts_with(">") {
    ignore(self.advance_char())
  }
  let (public_id, system_id) = match
    self.input.get_view(start=ids_start, end=self.pos) {
    Some(view) => parse_doctype_external_ids(view)
    None => (None, None)
  }
  if self.starts_with(">") {
    self.pos += 1
  }
  self.root.append_child(
    make_node(
      Doctype,
      "#doctype",
      None,
      {},
      name,
      public_id,
      system_id,
      false,
      [],
    ),
  )
}

///|
fn Parser::parse_end_tag(self : Parser) -> Unit {
  let start = self.pos
  self.pos += 2
  self.skip_ascii_whitespace()
  let name_start = self.pos
  while !self.is_eof() {
    match self.current() {
      Some('>') => break
      Some(ch) if ch.is_ascii_whitespace() => break
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  let name = match self.input.get_view(start=name_start, end=self.pos) {
    Some(view) => lower_ascii(self.replace_null_characters(view, name_start))
    None => ""
  }
  if name == "" {
    self.error_at("missing-end-tag-name", start)
  }
  while !self.is_eof() && !self.starts_with(">") {
    ignore(self.advance_char())
  }
  if self.starts_with(">") {
    self.pos += 1
  } else {
    self.error_at("eof-in-tag", start)
  }
  if name == "br" {
    self.error_at("unexpected-end-tag", start)
    self.close_open_p_element()
    self.current_node().append_child(element("br"))
    return
  }
  if name == "p" {
    if !self.close_open_element("p") {
      self.error_at("unexpected-end-tag", start)
      self.current_node().append_child(element("p"))
    }
    return
  }
  if is_heading_element_name(name) {
    self.close_open_heading_element(name, start)
    return
  }
  if name != "" {
    self.pop_until(name, start)
  }
}

///|
fn Parser::pop_until(self : Parser, name : String, pos : Int) -> Unit {
  let mut found = false
  for node in self.stack {
    if node.kind == Element && node.name == name {
      found = true
    }
  }
  if !found {
    self.error_at("unexpected-end-tag", pos)
    return
  }
  while self.stack.length() > 1 {
    match self.stack.last() {
      Some(node) if node.kind == Element &&
        node.name != name &&
        is_implied_end_tag_name(node.name) => ignore(self.stack.pop())
      _ => break
    }
  }
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == name => ()
    _ => self.error_at("end-tag-too-early", pos)
  }
  while self.stack.length() > 1 {
    match self.stack.pop() {
      Some(node) if node.kind == Element && node.name == name => break
      Some(_) => ()
      None => break
    }
  }
}

///|
fn is_implied_end_tag_name(name : StringView) -> Bool {
  match name {
    "dd"
    | "dt"
    | "li"
    | "option"
    | "optgroup"
    | "p"
    | "rb"
    | "rp"
    | "rt"
    | "rtc" => true
    _ => false
  }
}

///|
fn Parser::close_open_element(self : Parser, name : String) -> Bool {
  let mut found = false
  for node in self.stack {
    if node.kind == Element && node.name == name {
      found = true
    }
  }
  if !found {
    return false
  }
  while self.stack.length() > 1 {
    match self.stack.pop() {
      Some(node) if node.kind == Element && node.name == name => break
      Some(_) => ()
      None => break
    }
  }
  true
}

///|
fn Parser::close_open_p_element(self : Parser) -> Unit {
  ignore(self.close_open_element("p"))
}

///|
fn Parser::close_open_definition_item(self : Parser, name : String) -> Unit {
  if name == "dd" {
    ignore(self.close_open_element("dd"))
    ignore(self.close_open_element("dt"))
  } else {
    ignore(self.close_open_element("dt"))
    ignore(self.close_open_element("dd"))
  }
}

///|
fn Parser::has_open_element(self : Parser, name : String) -> Bool {
  for node in self.stack {
    if node.kind == Element && node.name == name {
      return true
    }
  }
  false
}

///|
fn Parser::close_current_element_if_name(self : Parser, name : String) -> Unit {
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == name =>
      ignore(self.stack.pop())
    _ => ()
  }
}

///|
fn Parser::close_open_select_item(self : Parser, name : String) -> Unit {
  self.close_current_element_if_name("option")
  if name == "optgroup" && self.has_open_element("select") {
    self.close_current_element_if_name("optgroup")
  }
}

///|
fn is_heading_element_name(name : StringView) -> Bool {
  match name {
    "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => true
    _ => false
  }
}

///|
fn Parser::close_current_heading_element(self : Parser) -> Unit {
  match self.stack.last() {
    Some(node) if node.kind == Element && is_heading_element_name(node.name) =>
      ignore(self.stack.pop())
    _ => ()
  }
}

///|
fn Parser::close_open_heading_element(
  self : Parser,
  name : String,
  pos : Int,
) -> Unit {
  let mut found = false
  for node in self.stack {
    if node.kind == Element && is_heading_element_name(node.name) {
      found = true
    }
  }
  if !found {
    self.error_at("unexpected-end-tag", pos)
    return
  }
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == name => ()
    _ => self.error_at("end-tag-too-early", pos)
  }
  while self.stack.length() > 1 {
    match self.stack.pop() {
      Some(node) if node.kind == Element && is_heading_element_name(node.name) =>
        break
      Some(_) => ()
      None => break
    }
  }
}

///|
fn start_tag_closes_p(name : StringView) -> Bool {
  match name {
    "address"
    | "article"
    | "aside"
    | "blockquote"
    | "center"
    | "details"
    | "dialog"
    | "dir"
    | "dd"
    | "div"
    | "dl"
    | "dt"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "header"
    | "hgroup"
    | "hr"
    | "li"
    | "main"
    | "menu"
    | "nav"
    | "ol"
    | "p"
    | "pre"
    | "search"
    | "section"
    | "table"
    | "ul" => true
    _ => false
  }
}

///|
fn Parser::parse_start_tag_or_text(self : Parser) -> Unit {
  let start = self.pos
  self.pos += 1
  match self.current() {
    Some(ch) if is_tag_name_start(ch) => {
      let name_start = self.pos
      while !self.is_eof() {
        match self.current() {
          Some(ch) if is_tag_name_char(ch) => ignore(self.advance_char())
          _ => break
        }
      }
      let name = match self.input.get_view(start=name_start, end=self.pos) {
        Some(view) => lower_ascii(view)
        None => ""
      }
      let attrs : Map[String, String?] = {}
      let mut self_closing = false
      let mut closed = false
      while !self.is_eof() {
        self.skip_ascii_whitespace()
        match self.current() {
          Some('>') => {
            ignore(self.advance_char())
            closed = true
            break
          }
          Some('/') => {
            ignore(self.advance_char())
            self.skip_ascii_whitespace()
            if self.current() == Some('>') {
              ignore(self.advance_char())
              self_closing = true
              closed = true
              break
            } else {
              self.error_at("unexpected-solidus-in-tag", self.pos)
            }
          }
          Some(_) => self.parse_attribute(attrs)
          None => ()
        }
      }
      if !closed {
        self.error_at("eof-in-tag", start)
      }
      if start_tag_closes_p(name) {
        self.close_open_p_element()
      }
      if name == "li" {
        ignore(self.close_open_element("li"))
      } else if name == "dd" || name == "dt" {
        self.close_open_definition_item(name)
      } else if name == "option" || name == "optgroup" {
        self.close_open_select_item(name)
      }
      if is_heading_element_name(name) {
        self.close_current_heading_element()
      }
      let adjusted_name = if name == "image" {
        self.error_at("image-start-tag", start)
        "img"
      } else {
        name
      }
      let node = element(adjusted_name, attrs~)
      self.current_node().append_child(node)
      if !self_closing && self.is_special_text_element(adjusted_name) {
        self.consume_special_element_content(node, adjusted_name)
      } else if !self_closing && !is_void_element(adjusted_name) {
        self.stack.push(node)
        if start_tag_ignores_initial_lf(adjusted_name) {
          self.skip_one_initial_lf()
        }
      }
    }
    _ => {
      self.error_at("eof-before-tag-name", start)
      self.current_node().append_child(text("<"))
    }
  }
}

///|
fn Parser::parse_attribute(self : Parser, attrs : Map[String, String?]) -> Unit {
  let name_start = self.pos
  while !self.is_eof() {
    match self.current() {
      Some(ch) if ch.is_ascii_whitespace() ||
        ch == '=' ||
        ch == '/' ||
        ch == '>' => break
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  let name = match self.input.get_view(start=name_start, end=self.pos) {
    Some(view) => lower_ascii(self.replace_null_characters(view, name_start))
    None => ""
  }
  if name == "" {
    ignore(self.advance_char())
    return
  }
  let duplicate = attrs.contains(name)
  if duplicate {
    self.error_at("duplicate-attribute", name_start)
  }
  self.skip_ascii_whitespace()
  if self.current() != Some('=') {
    if !duplicate {
      attrs[name] = None
    }
    return
  }
  ignore(self.advance_char())
  self.skip_ascii_whitespace()
  let value = match self.current() {
    Some('"') => {
      ignore(self.advance_char())
      let start = self.pos
      while !self.is_eof() && self.current() != Some('"') {
        if self.current() == Some('\u{0000}') {
          self.error_at("unexpected-null-character", self.pos)
        }
        ignore(self.advance_char())
      }
      let raw = match self.input.get_view(start~, end=self.pos) {
        Some(view) => decode_attribute_value(view)
        None => ""
      }
      if self.current() == Some('"') {
        ignore(self.advance_char())
      }
      raw
    }
    Some('\'') => {
      ignore(self.advance_char())
      let start = self.pos
      while !self.is_eof() && self.current() != Some('\'') {
        if self.current() == Some('\u{0000}') {
          self.error_at("unexpected-null-character", self.pos)
        }
        ignore(self.advance_char())
      }
      let raw = match self.input.get_view(start~, end=self.pos) {
        Some(view) => decode_attribute_value(view)
        None => ""
      }
      if self.current() == Some('\'') {
        ignore(self.advance_char())
      }
      raw
    }
    _ => {
      let start = self.pos
      while !self.is_eof() {
        match self.current() {
          Some(ch) if ch.is_ascii_whitespace() || ch == '>' => break
          Some('\u{0000}') => {
            self.error_at("unexpected-null-character", self.pos)
            ignore(self.advance_char())
          }
          Some(_) => ignore(self.advance_char())
          None => ()
        }
      }
      match self.input.get_view(start~, end=self.pos) {
        Some(view) => decode_attribute_value(view)
        None => ""
      }
    }
  }
  if !duplicate {
    attrs[name] = Some(value)
  }
}

///|
fn is_tag_name_start(ch : Char) -> Bool {
  ch.is_ascii_alphabetic()
}

///|
fn is_tag_name_char(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() ||
  ch.is_ascii_digit() ||
  ch == '-' ||
  ch == '_' ||
  ch == ':'
}

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
fn special_text_decodes_entities(name : StringView) -> Bool {
  match name {
    "title" | "textarea" => true
    _ => false
  }
}

///|
fn decoded_special_text(name : StringView, raw : StringView) -> String {
  let raw = if name == "textarea" { strip_one_initial_lf(raw) } else { raw }
  if special_text_decodes_entities(name) {
    decode_entities(raw, in_attribute=false)
  } else {
    normalize_newlines(raw)
  }
}

///|
fn Parser::decoded_special_text(
  self : Parser,
  name : StringView,
  raw : StringView,
  start : Int,
) -> String {
  let (raw, offset) = if name == "textarea" {
    strip_one_initial_lf_with_offset(raw)
  } else {
    (raw, 0)
  }
  let raw = self.replace_null_characters(raw, start + offset)
  if special_text_decodes_entities(name) {
    decode_entities(raw, in_attribute=false)
  } else {
    normalize_newlines(raw)
  }
}

///|
fn strip_one_initial_lf_with_offset(input : StringView) -> (StringView, Int) {
  match input.get_char(0) {
    Some('\r') =>
      if input.get_char(1) == Some('\n') {
        (input[2:], 2)
      } else {
        (input[1:], 1)
      }
    Some('\n') => (input[1:], 1)
    _ => (input, 0)
  }
}

///|
fn strip_one_initial_lf(input : StringView) -> StringView {
  let (view, _) = strip_one_initial_lf_with_offset(input)
  view
}

///|
fn Parser::skip_one_initial_lf(self : Parser) -> Unit {
  match self.current() {
    Some('\r') => {
      self.pos += 1
      if self.current() == Some('\n') {
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
fn view_has_prefix_case_insensitive(
  input : StringView,
  prefix : StringView,
) -> Bool {
  if input.length() < prefix.length() {
    false
  } else {
    match input.get_view(end=prefix.length()) {
      Some(view) => view.compare_ignore_ascii_case(prefix) == 0
      None => false
    }
  }
}

///|
fn parse_quoted_doctype_value(input : StringView) -> (String?, StringView) {
  let input = input.trim_start()
  match input.get_char(0) {
    Some('"') | Some('\'') as quote_opt => {
      guard quote_opt is Some(quote)
      let mut pos = quote.utf16_len()
      let value_start = pos
      while pos < input.length() && input.get_char(pos) != Some(quote) {
        match input.get_char(pos) {
          Some(ch) => pos += ch.utf16_len()
          None => break
        }
      }
      let value = match input.get_view(start=value_start, end=pos) {
        Some(view) => Some(normalize_newlines(view))
        None => Some("")
      }
      if input.get_char(pos) == Some(quote) {
        pos += quote.utf16_len()
      }
      let rest = match input.get_view(start=pos) {
        Some(view) => view
        None => ""
      }
      (value, rest)
    }
    _ => (None, input)
  }
}

///|
fn parse_doctype_external_ids(input : StringView) -> (String?, String?) {
  let rest = input.trim_start()
  if view_has_prefix_case_insensitive(rest, "public") {
    let rest = rest[6:].trim_start()
    let (public_id, rest) = parse_quoted_doctype_value(rest)
    let (system_id, _) = parse_quoted_doctype_value(rest)
    (public_id, system_id)
  } else if view_has_prefix_case_insensitive(rest, "system") {
    let rest = rest[6:].trim_start()
    let (system_id, _) = parse_quoted_doctype_value(rest)
    (None, system_id)
  } else {
    (None, None)
  }
}

///|
fn find_matching_end_tag(
  input : StringView,
  start : Int,
  name : StringView,
) -> Int? {
  let needle = "</" + name.to_owned()
  let mut pos = start
  while pos < input.length() {
    if starts_with_case_insensitive(input, pos, needle) {
      let after_name = pos + needle.length()
      match input.get_char(after_name) {
        Some('>') => return Some(pos)
        Some(ch) if ch.is_ascii_whitespace() => return Some(pos)
        _ => ()
      }
    }
    match input.get_char(pos) {
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  None
}

///|
fn Parser::skip_matching_end_tag(self : Parser) -> Unit {
  self.pos += 2
  while !self.is_eof() {
    match self.current() {
      Some('>') => break
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  if self.current() == Some('>') {
    ignore(self.advance_char())
  }
}

///|
fn Parser::consume_special_element_content(
  self : Parser,
  parent : Node,
  name : String,
) -> Unit {
  let content_start = self.pos
  if name == "plaintext" {
    match self.input.get_view(start=content_start, end=self.input.length()) {
      Some(view) =>
        parent.append_child(
          text(self.decoded_special_text(name, view, content_start)),
        )
      None => ()
    }
    self.error_at("eof-in-text-element", content_start)
    self.pos = self.input.length()
    return
  }
  match find_matching_end_tag(self.input, self.pos, name) {
    Some(end_start) => {
      match self.input.get_view(start=content_start, end=end_start) {
        Some(view) =>
          parent.append_child(
            text(self.decoded_special_text(name, view, content_start)),
          )
        None => ()
      }
      self.pos = end_start
      self.skip_matching_end_tag()
    }
    None => {
      match self.input.get_view(start=content_start, end=self.input.length()) {
        Some(view) =>
          parent.append_child(
            text(self.decoded_special_text(name, view, content_start)),
          )
        None => ()
      }
      self.error_at("eof-in-text-element", content_start)
      self.pos = self.input.length()
    }
  }
}

///|
fn is_fragment_raw_text_context(name : StringView) -> Bool {
  match name {
    "style" | "textarea" | "title" => true
    _ => false
  }
}

///|
fn is_fragment_plain_text_context(name : StringView) -> Bool {
  match name {
    "plaintext" | "script" => true
    _ => false
  }
}

///|
fn Parser::append_fragment_context_text(
  self : Parser,
  raw : StringView,
  start : Int,
) -> Unit {
  if raw.is_empty() {
    return
  }
  let raw = self.replace_null_characters(raw, start)
  self.root.append_child(text(normalize_newlines(raw)))
}

///|
fn Parser::parse_fragment_context(
  self : Parser,
  context : FragmentContext,
) -> Bool {
  if context.ns is Some(_) {
    return false
  }
  let name = context.tag_name
  if is_fragment_plain_text_context(name) {
    match self.input.get_view(start=0, end=self.input.length()) {
      Some(view) => self.append_fragment_context_text(view, 0)
      None => ()
    }
    self.pos = self.input.length()
    return true
  }
  if is_fragment_raw_text_context(name) {
    match find_matching_end_tag(self.input, 0, name) {
      Some(end_start) => {
        match self.input.get_view(start=0, end=end_start) {
          Some(view) => self.append_fragment_context_text(view, 0)
          None => ()
        }
        self.pos = end_start
        self.skip_matching_end_tag()
        self.error_at("unexpected-end-tag", end_start)
        self.parse_all()
      }
      None => {
        match self.input.get_view(start=0, end=self.input.length()) {
          Some(view) => self.append_fragment_context_text(view, 0)
          None => ()
        }
        self.pos = self.input.length()
      }
    }
    return true
  }
  false
}

///|
fn line_col_at(input : StringView, target : Int) -> (Int, Int) {
  let mut offset = 0
  let mut line = 1
  let mut col = 1
  while offset < target && offset < input.length() {
    match input.get_char(offset) {
      Some('\r') => {
        line += 1
        col = 1
        offset += 1
        if offset < target && input.get_char(offset) == Some('\n') {
          offset += 1
        }
      }
      Some('\n') => {
        line += 1
        col = 1
        offset += 1
      }
      Some(ch) => {
        col += 1
        offset += ch.utf16_len()
      }
      None => break
    }
  }
  (line, col)
}

///|
fn strip_leading_bom(input : StringView) -> StringView {
  if input.has_prefix("\u{FEFF}") {
    input[1:]
  } else {
    input
  }
}

///|
fn normalize_newlines(input : StringView) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  let mut pos = 0
  while pos < input.length() {
    match input.get_char(pos) {
      Some('\r') => {
        out.write_char('\n')
        pos += 1
        if input.get_char(pos) == Some('\n') {
          pos += 1
        }
      }
      Some(ch) => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  out.to_string()
}

///|
fn write_normalized_char(
  input : StringView,
  pos : Int,
  out : StringBuilder,
) -> Int {
  match input.get_char(pos) {
    Some('\r') => {
      out.write_char('\n')
      let next = pos + 1
      if input.get_char(next) == Some('\n') {
        next + 1
      } else {
        next
      }
    }
    Some(ch) => {
      out.write_char(ch)
      pos + ch.utf16_len()
    }
    None => pos
  }
}

///|
fn decode_entities(input : StringView, in_attribute~ : Bool) -> String {
  ignore(in_attribute)
  let out = StringBuilder::new(size_hint=input.length())
  let mut pos = 0
  while pos < input.length() {
    match input.get_char(pos) {
      Some('&') =>
        match consume_entity(input, pos) {
          Some((value, next)) => {
            out.write_string(value)
            pos = next
          }
          None => {
            out.write_char('&')
            pos += 1
          }
        }
      Some(_) => pos = write_normalized_char(input, pos, out)
      None => break
    }
  }
  out.to_string()
}

///|
fn decode_attribute_value(input : StringView) -> String {
  let decoded = decode_entities(input, in_attribute=true)
  decoded.replace_all(old="\u{0000}", new="\u{FFFD}")
}

///|
fn starts_with_case_insensitive(
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

///|
fn consume_entity(input : StringView, start : Int) -> (String, Int)? {
  let rest = input[start:]
  if rest.has_prefix("&amp;") {
    Some(("&", start + 5))
  } else if rest.has_prefix("&amp") {
    Some(("&", start + 4))
  } else if rest.has_prefix("&lt;") {
    Some(("<", start + 4))
  } else if rest.has_prefix("&lt") {
    Some(("<", start + 3))
  } else if rest.has_prefix("&gt;") {
    Some((">", start + 4))
  } else if rest.has_prefix("&gt") {
    Some((">", start + 3))
  } else if rest.has_prefix("&quot;") {
    Some(("\"", start + 6))
  } else if rest.has_prefix("&apos;") {
    Some(("'", start + 6))
  } else if rest.has_prefix("&nbsp;") {
    Some((" ", start + 6))
  } else if rest.has_prefix("&not;") {
    Some(("¬", start + 5))
  } else if rest.has_prefix("&not") {
    Some(("¬", start + 4))
  } else if rest.has_prefix("&#") {
    consume_numeric_entity(input, start)
  } else {
    None
  }
}

///|
fn consume_numeric_entity(input : StringView, start : Int) -> (String, Int)? {
  let mut pos = start + 2
  let mut base = 10
  if pos < input.length() {
    match input.get_char(pos) {
      Some('x') | Some('X') => {
        base = 16
        pos += 1
      }
      _ => ()
    }
  }
  let digits_start = pos
  let mut value = 0
  while pos < input.length() {
    match input.get_char(pos) {
      Some(ch) => {
        let digit = digit_value(ch)
        if digit < 0 || digit >= base {
          break
        }
        value = value * base + digit
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  if pos == digits_start {
    return None
  }
  if pos < input.length() && input.get_char(pos) == Some(';') {
    pos += 1
  }
  match html_numeric_entity_replacement(value).to_char() {
    Some(ch) => Some((ch.to_string(), pos))
    None => Some(("\u{FFFD}", pos))
  }
}

///|
fn html_numeric_entity_replacement(value : Int) -> Int {
  match value {
    0 => 0xFFFD
    0x80 => 0x20AC
    0x82 => 0x201A
    0x83 => 0x0192
    0x84 => 0x201E
    0x85 => 0x2026
    0x86 => 0x2020
    0x87 => 0x2021
    0x88 => 0x02C6
    0x89 => 0x2030
    0x8A => 0x0160
    0x8B => 0x2039
    0x8C => 0x0152
    0x8E => 0x017D
    0x91 => 0x2018
    0x92 => 0x2019
    0x93 => 0x201C
    0x94 => 0x201D
    0x95 => 0x2022
    0x96 => 0x2013
    0x97 => 0x2014
    0x98 => 0x02DC
    0x99 => 0x2122
    0x9A => 0x0161
    0x9B => 0x203A
    0x9C => 0x0153
    0x9E => 0x017E
    0x9F => 0x0178
    _ => value
  }
}

///|
fn digit_value(ch : Char) -> Int {
  if ch >= '0' && ch <= '9' {
    ch.to_int() - ('0' : Int)
  } else if ch >= 'a' && ch <= 'f' {
    ch.to_int() - ('a' : Int) + 10
  } else if ch >= 'A' && ch <= 'F' {
    ch.to_int() - ('A' : Int) + 10
  } else {
    -1
  }
}

///|
pub fn parse(
  html : StringView,
  sanitize? : Bool = true,
  collect_errors? : Bool = false,
  strict? : Bool = false,
  scripting_enabled? : Bool = true,
) -> ParsedHtml raise HtmlError {
  ignore(sanitize)
  let root = document()
  let parser = Parser::new(html, root, scripting_enabled~)
  parser.parse_all()
  scaffold_document(root)
  let errors = if collect_errors || strict { parser.errors } else { [] }
  if strict && !parser.errors.is_empty() {
    raise HtmlError::StrictMode(parser.errors[0])
  }
  ParsedHtml::{ root, errors, encoding: None }
}

///|
fn document_html_element(root : Node) -> Node? {
  for child in root.children {
    if child.kind == Element && child.name == "html" {
      return Some(child)
    }
  }
  None
}

///|
fn is_document_head_element_name(name : StringView) -> Bool {
  match name {
    "base"
    | "basefont"
    | "bgsound"
    | "link"
    | "meta"
    | "noframes"
    | "script"
    | "style"
    | "title" => true
    _ => false
  }
}

///|
fn is_whitespace_text_node(node : Node) -> Bool {
  if node.kind != Text {
    return false
  }
  for ch in node.data {
    if !ch.is_ascii_whitespace() {
      return false
    }
  }
  true
}

///|
fn append_children_to(target : Node, children : Array[Node]) -> Unit {
  for child in children {
    target.append_child(child)
  }
}

///|
fn scaffold_existing_html_element(html : Node) -> Unit {
  let original = html.children.copy()
  html.children.clear()
  let mut head : Node? = None
  let mut body : Node? = None
  let head_children : Array[Node] = []
  let body_children : Array[Node] = []
  let mut body_started = false
  for child in original {
    if child.kind == Element &&
      child.name == "head" &&
      head is None &&
      !body_started {
      head = Some(child)
    } else if child.kind == Element && child.name == "body" && body is None {
      body = Some(child)
      body_started = true
      let existing = child.children.copy()
      child.children.clear()
      for grandchild in existing {
        body_children.push(grandchild)
      }
    } else if child.kind == Element && child.name == "head" {
      let existing = child.children.copy()
      for grandchild in existing {
        body_children.push(grandchild)
      }
    } else if child.kind == Element &&
      is_document_head_element_name(child.name) &&
      !body_started {
      head_children.push(child)
    } else if is_whitespace_text_node(child) && !body_started {
      ()
    } else {
      body_started = true
      body_children.push(child)
    }
  }
  let head_node = head.unwrap_or(element("head"))
  let body_node = body.unwrap_or(element("body"))
  html.append_child(head_node)
  append_children_to(head_node, head_children)
  append_children_to(body_node, body_children)
  html.append_child(body_node)
}

///|
fn scaffold_document(root : Node) -> Unit {
  match document_html_element(root) {
    Some(html) => {
      scaffold_existing_html_element(html)
      return
    }
    None => ()
  }
  let original = root.children.copy()
  root.children.clear()
  let head_children : Array[Node] = []
  let body_children : Array[Node] = []
  let mut body_started = false
  for child in original {
    if child.kind == Doctype {
      root.append_child(child)
    } else if child.kind == Comment && !body_started && head_children.is_empty() {
      root.append_child(child)
    } else if child.kind == Element &&
      is_document_head_element_name(child.name) &&
      !body_started {
      head_children.push(child)
    } else if child.kind == Comment && !body_started {
      head_children.push(child)
    } else if is_whitespace_text_node(child) && !body_started {
      ()
    } else {
      body_started = true
      body_children.push(child)
    }
  }
  let html = element("html")
  html.append_child(element("head", children=head_children))
  html.append_child(element("body", children=body_children))
  root.append_child(html)
}

///|
pub fn parse_fragment(
  html : StringView,
  context? : FragmentContext,
  sanitize? : Bool = true,
  collect_errors? : Bool = false,
  strict? : Bool = false,
  scripting_enabled? : Bool = true,
) -> ParsedHtml raise HtmlError {
  ignore(sanitize)
  let root = fragment()
  let parser = Parser::new(html, root, scripting_enabled~)
  match context {
    Some(fragment_context) =>
      if !parser.parse_fragment_context(fragment_context) {
        parser.parse_all()
      }
    None => parser.parse_all()
  }
  let errors = if collect_errors || strict { parser.errors } else { [] }
  if strict && !parser.errors.is_empty() {
    raise HtmlError::StrictMode(parser.errors[0])
  }
  ParsedHtml::{ root, errors, encoding: None }
}

///|
pub fn parse_bytes(
  input : BytesView,
  encoding? : String,
  sanitize? : Bool = true,
  collect_errors? : Bool = false,
  strict? : Bool = false,
  scripting_enabled? : Bool = true,
) -> ParsedHtml raise HtmlError {
  let decoded = @utf8.decode_lossy(input, ignore_bom=true)
  let parsed = parse(
    decoded,
    sanitize~,
    collect_errors~,
    strict~,
    scripting_enabled~,
  )
  ParsedHtml::{
    root: parsed.root,
    errors: parsed.errors,
    encoding: Some(encoding.unwrap_or("utf-8")),
  }
}

///|
pub fn ParsedHtml::to_html(
  self : ParsedHtml,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String {
  self.root.to_html(pretty~, indent_size~, context~, quote~)
}

///|
pub fn ParsedHtml::to_text(
  self : ParsedHtml,
  separator? : String = " ",
  strip? : Bool = true,
  separator_blocks_only? : Bool = false,
) -> String {
  self.root.to_text(separator~, strip~, separator_blocks_only~)
}

///|
pub fn ParsedHtml::to_markdown(
  self : ParsedHtml,
  html_passthrough? : Bool = false,
) -> String {
  ignore(html_passthrough)
  self.to_text(separator="\n\n", strip=true)
}

///|
pub fn ParsedHtml::query(
  self : ParsedHtml,
  selector : StringView,
) -> Array[Node] {
  self.root.query(selector)
}

///|
pub fn ParsedHtml::query_one(self : ParsedHtml, selector : StringView) -> Node? {
  self.root.query_one(selector)
}
