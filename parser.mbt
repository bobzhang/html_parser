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
  self.errors.push(self.make_error_at(code, pos))
}

///|
fn Parser::make_error_at(self : Parser, code : String, pos : Int) -> ParseError {
  let (line, column) = line_col_at(self.input, pos)
  ParseError::new(code, line~, column~)
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
        } else if self.starts_with("<!") {
          self.parse_markup_declaration()
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
fn view_starts_with_at(
  input : StringView,
  pos : Int,
  prefix : StringView,
) -> Bool {
  let end = pos + prefix.length()
  match input.get_view(start=pos, end~) {
    Some(view) => view == prefix
    None => false
  }
}

///|
fn find_markup_close(input : StringView, start : Int) -> Int? {
  let mut pos = start
  while pos < input.length() {
    match input.get_char(pos) {
      Some('>') => return Some(pos)
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  None
}

///|
fn find_comment_close(input : StringView, start : Int) -> Int? {
  let scan = scan_comment_data(input, start + "<!--".length())
  if scan.eof {
    None
  } else {
    Some(scan.end)
  }
}

///|
fn Parser::report_initial_doctype_error(self : Parser) -> ParseError? {
  let mut pos = 0
  let mut defer_doctype = false
  while pos < self.input.length() {
    match self.input.get_char(pos) {
      Some(ch) if ch.is_ascii_whitespace() => pos += ch.utf16_len()
      Some('<') if view_starts_with_at(self.input, pos, "<!--") =>
        match find_comment_close(self.input, pos) {
          Some(end) => pos = end
          None =>
            return Some(self.make_error_at_eof("expected-doctype-but-got-eof"))
        }
      Some('<') if starts_with_case_insensitive(self.input, pos, "<!doctype") =>
        return None
      Some('<') if view_starts_with_at(self.input, pos, "<!") => {
        defer_doctype = true
        match find_markup_close(self.input, pos) {
          Some(close) => pos = close + 1
          None =>
            return Some(self.make_error_at_eof("expected-doctype-but-got-eof"))
        }
      }
      Some('<') if view_starts_with_at(self.input, pos, "</") =>
        match find_markup_close(self.input, pos) {
          Some(close) => {
            let malformed = match self.input.get_char(pos + 2) {
              Some(ch) if ch == '>' || !is_tag_name_start(ch) => true
              _ => false
            }
            if malformed {
              defer_doctype = true
              pos = close + 1
            } else {
              let error = self.make_error_at(
                "expected-doctype-but-got-end-tag", close,
              )
              if defer_doctype {
                return Some(error)
              }
              self.errors.push(error)
              return None
            }
          }
          None =>
            return Some(self.make_error_at_eof("expected-doctype-but-got-eof"))
        }
      Some('<') =>
        match self.input.get_char(pos + 1) {
          Some(ch) if is_tag_name_start(ch) =>
            match find_markup_close(self.input, pos) {
              Some(close) => {
                let error = self.make_error_at(
                  "expected-doctype-but-got-start-tag", close,
                )
                if defer_doctype {
                  return Some(error)
                }
                self.errors.push(error)
                return None
              }
              None =>
                return Some(
                  self.make_error_at_eof("expected-doctype-but-got-eof"),
                )
            }
          Some('?') => {
            defer_doctype = true
            match find_markup_close(self.input, pos) {
              Some(close) => pos = close + 1
              None =>
                return Some(
                  self.make_error_at_eof("expected-doctype-but-got-eof"),
                )
            }
          }
          _ => {
            let error = self.make_error_at(
              "expected-doctype-but-got-chars", pos,
            )
            if defer_doctype {
              return Some(error)
            }
            self.errors.push(error)
            return None
          }
        }
      Some(_) => {
        let error = self.make_error_at("expected-doctype-but-got-chars", pos)
        if defer_doctype {
          return Some(error)
        }
        self.errors.push(error)
        return None
      }
      None => ()
    }
  }
  let error = self.make_error_at_eof("expected-doctype-but-got-eof")
  if defer_doctype {
    Some(error)
  } else {
    self.errors.push(error)
    None
  }
}

///|
fn Parser::eof_error_pos(self : Parser) -> Int {
  eof_error_pos(self.input)
}

///|
fn eof_error_pos(input : StringView) -> Int {
  let mut pos = 0
  let mut last = 0
  while pos < input.length() {
    last = pos
    match input.get_char(pos) {
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  last
}

///|
fn Parser::error_at_eof(self : Parser, code : String) -> Unit {
  self.errors.push(self.make_error_at_eof(code))
}

///|
fn Parser::make_error_at_eof(self : Parser, code : String) -> ParseError {
  if self.input.is_empty() {
    ParseError::new(code, line=1, column=0)
  } else {
    self.make_error_at(code, self.eof_error_pos())
  }
}

///|
fn eof_allows_unclosed_element(name : StringView) -> Bool {
  match name {
    "body"
    | "dd"
    | "dt"
    | "head"
    | "html"
    | "li"
    | "optgroup"
    | "option"
    | "p"
    | "rb"
    | "rp"
    | "rt"
    | "rtc"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr" => true
    _ => false
  }
}

///|
fn Parser::report_eof_tree_errors(self : Parser) -> Unit {
  if self.has_open_element("table") {
    self.error_at("eof-in-table", self.eof_error_pos())
    return
  }
  for node in self.stack {
    if node.kind == Element && !eof_allows_unclosed_element(node.name) {
      self.error_at("expected-closing-tag-but-got-eof", self.eof_error_pos())
      return
    }
  }
}

///|
fn Parser::parse_comment(self : Parser) -> Unit {
  self.pos += 4
  let scan = scan_comment_data(self.input, self.pos)
  for error in scan.errors {
    self.error_at(error.code, error.offset)
  }
  self.pos = scan.end
  self.current_node().append_child(comment(scan.data))
}

///|
fn Parser::parse_bogus_comment(self : Parser) -> Unit {
  let data_start = self.pos
  while !self.is_eof() && self.current() != Some('>') {
    ignore(self.advance_char())
  }
  match self.input.get_view(start=data_start, end=self.pos) {
    Some(view) =>
      self
      .current_node()
      .append_child(comment(normalize_bogus_comment_data(view)))
    None => ()
  }
  if self.current() == Some('>') {
    ignore(self.advance_char())
  }
}

///|
fn Parser::parse_markup_declaration(self : Parser) -> Unit {
  self.pos += 2
  if self.starts_with("[CDATA[") {
    self.error_at("cdata-in-html-content", self.pos + "[CDATA[".length() - 1)
  } else {
    self.error_at("incorrectly-opened-comment", self.pos - 1)
  }
  self.parse_bogus_comment()
}

///|
fn Parser::parse_doctype(self : Parser) -> Unit {
  self.pos += "<!doctype".length()
  let missing_before_name = match self.current() {
    Some('>') | None => None
    Some(ch) if ch.is_ascii_whitespace() => {
      self.skip_ascii_whitespace()
      None
    }
    _ => Some(self.pos)
  }
  let name_start = self.pos
  while !self.is_eof() {
    match self.current() {
      Some('>') => break
      Some(ch) if ch.is_ascii_whitespace() => break
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  let (name, name_errors) = parse_lower_name_value_replacing_nulls(
    self.input,
    name_start,
    self.pos,
  )
  let ids_start = self.pos
  while !self.is_eof() && !self.starts_with(">") {
    ignore(self.advance_char())
  }
  let external = match self.input.get_view(start=ids_start, end=self.pos) {
    Some(view) => parse_doctype_external(view, self.starts_with(">"))
    None =>
      DoctypeExternalParse::{
        public_id: None,
        system_id: None,
        errors: [],
        force_quirks: false,
      }
  }
  let public_id = external.public_id
  let system_id = external.system_id
  let has_external_error = !external.errors.is_empty()
  let eof_doctype = name != "" && !has_external_error && !self.starts_with(">")
  let error_pos = if self.starts_with(">") {
    self.pos
  } else {
    self.eof_error_pos()
  }
  let force_quirks = name == "" || external.force_quirks || eof_doctype
  match missing_before_name {
    Some(pos) => self.error_at("missing-whitespace-before-doctype-name", pos)
    None => ()
  }
  for error in name_errors {
    self.error_at(error.code, error.offset)
  }
  if name == "" {
    if self.starts_with(">") {
      self.error_at("expected-doctype-name-but-got-right-bracket", error_pos)
    } else {
      self.error_at_eof("eof-in-doctype")
    }
  } else {
    for error in external.errors {
      self.error_at(error.code, ids_start + error.offset)
    }
  }
  if eof_doctype {
    self.error_at_eof("eof-in-doctype")
  }
  if self.starts_with(">") {
    self.pos += 1
  }
  if self.root.kind == Fragment {
    self.error_at("unexpected-doctype", error_pos)
    return
  }
  if !self.document_doctype_is_initial() {
    self.error_at("unexpected-doctype", error_pos)
    return
  }
  if !is_known_doctype(name, public_id, system_id) {
    self.error_at("unknown-doctype", error_pos)
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
      force_quirks,
      [],
    ),
  )
}

///|
fn Parser::parse_end_tag(self : Parser) -> Unit {
  let start = self.pos
  self.pos += 2
  match self.current() {
    Some('>') => {
      self.error_at("empty-end-tag", self.pos)
      ignore(self.advance_char())
      return
    }
    Some(ch) if !is_tag_name_start(ch) => {
      self.error_at("invalid-first-character-of-tag-name", self.pos)
      self.parse_bogus_comment()
      return
    }
    None => {
      self.error_at_eof("eof-before-tag-name")
      self.current_node().append_child(text("</"))
      return
    }
    _ => ()
  }
  let name_start = self.pos
  while !self.is_eof() {
    match self.current() {
      Some('>') => break
      Some('/') => break
      Some(ch) if ch.is_ascii_whitespace() => break
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  let (name, name_errors) = parse_lower_name_value_replacing_nulls(
    self.input,
    name_start,
    self.pos,
  )
  for error in name_errors {
    self.error_at(error.code, error.offset)
  }
  if name == "" {
    self.error_at("missing-end-tag-name", start)
  }
  let attrs : Map[String, String?] = {}
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
        if self.current() == Some('>') {
          ignore(self.advance_char())
          closed = true
          break
        } else {
          self.error_at("unexpected-character-after-solidus-in-tag", self.pos)
        }
      }
      Some(_) => self.parse_attribute(attrs)
      None => ()
    }
  }
  if !closed {
    self.error_at_eof("eof-in-tag")
    return
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
fn Parser::close_open_table_cell(self : Parser) -> Unit {
  if self.has_open_element("td") {
    ignore(self.close_open_element("td"))
  } else if self.has_open_element("th") {
    ignore(self.close_open_element("th"))
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
          Some(ch) if !is_tag_name_end(ch) => ignore(self.advance_char())
          _ => break
        }
      }
      let (name, name_errors) = parse_lower_name_value_replacing_nulls(
        self.input,
        name_start,
        self.pos,
      )
      for error in name_errors {
        self.error_at(error.code, error.offset)
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
            if self.current() == Some('>') {
              ignore(self.advance_char())
              self_closing = true
              closed = true
              break
            } else {
              self.error_at(
                "unexpected-character-after-solidus-in-tag",
                self.pos,
              )
            }
          }
          Some(_) => self.parse_attribute(attrs)
          None => ()
        }
      }
      if !closed {
        self.error_at_eof("eof-in-tag")
        return
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
      } else if name == "td" || name == "th" {
        self.close_open_table_cell()
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
      let self_closes_tree = self_closing && is_void_element(adjusted_name)
      if !self_closes_tree && self.is_special_text_element(adjusted_name) {
        self.consume_special_element_content(node, adjusted_name)
      } else if !self_closes_tree && !is_void_element(adjusted_name) {
        self.stack.push(node)
        if start_tag_ignores_initial_lf(adjusted_name) {
          self.skip_one_initial_lf()
        }
      }
    }
    _ =>
      if self.current() is None {
        self.error_at_eof("eof-before-tag-name")
        self.current_node().append_child(text("<"))
      } else if self.current() == Some('?') {
        self.error_at("unexpected-question-mark-instead-of-tag-name", self.pos)
        self.parse_bogus_comment()
      } else {
        self.parse_invalid_tag_open_as_text(start)
      }
  }
}

///|
fn Parser::parse_invalid_tag_open_as_text(self : Parser, start : Int) -> Unit {
  self.error_at("invalid-first-character-of-tag-name", self.pos)
  while !self.is_eof() && !self.starts_with("<") {
    ignore(self.advance_char())
  }
  match self.input.get_view(start~, end=self.pos) {
    Some(view) => self.append_text(view, start)
    None => ()
  }
}

///|
fn Parser::parse_attribute(self : Parser, attrs : Map[String, String?]) -> Unit {
  let name_start = self.pos
  if self.current() == Some('=') {
    self.error_at("unexpected-equals-sign-before-attribute-name", self.pos)
    ignore(self.advance_char())
  }
  while !self.is_eof() {
    match self.current() {
      Some(ch) if ch.is_ascii_whitespace() ||
        ch == '=' ||
        ch == '/' ||
        ch == '>' => break
      Some('<') | Some('"') | Some('\'') => {
        self.error_at("unexpected-character-in-attribute-name", self.pos)
        ignore(self.advance_char())
      }
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  let (name, name_errors) = parse_lower_name_value_replacing_nulls(
    self.input,
    name_start,
    self.pos,
  )
  for error in name_errors {
    self.error_at(error.code, error.offset)
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
  let missing_value = self.current() == Some('>')
  if missing_value {
    self.error_at("missing-attribute-value", self.pos)
  }
  let value = match self.current() {
    Some('"') => self.parse_quoted_attribute_value('"')
    Some('\'') => self.parse_quoted_attribute_value('\'')
    _ => {
      let start = self.pos
      while !self.is_eof() {
        match self.current() {
          Some(ch) if ch.is_ascii_whitespace() || ch == '>' => break
          Some('\u{0000}') => {
            self.error_at("unexpected-null-character", self.pos)
            ignore(self.advance_char())
          }
          Some('"') | Some('\'') | Some('<') | Some('=') | Some('`') => {
            self.error_at(
              "unexpected-character-in-unquoted-attribute-value",
              self.pos,
            )
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
    attrs[name] = if missing_value { None } else { Some(value) }
  }
}

///|
fn Parser::parse_quoted_attribute_value(self : Parser, quote : Char) -> String {
  ignore(self.advance_char())
  let start = self.pos
  while !self.is_eof() && self.current() != Some(quote) {
    if self.current() == Some('\u{0000}') {
      self.error_at("unexpected-null-character", self.pos)
    }
    ignore(self.advance_char())
  }
  let raw = match self.input.get_view(start~, end=self.pos) {
    Some(view) => decode_attribute_value(view)
    None => ""
  }
  if self.current() == Some(quote) {
    ignore(self.advance_char())
    match self.current() {
      Some(ch) if !ch.is_ascii_whitespace() && ch != '>' && ch != '/' =>
        self.error_at("missing-whitespace-between-attributes", self.pos)
      _ => ()
    }
  }
  raw
}

///|
fn is_tag_name_start(ch : Char) -> Bool {
  ch.is_ascii_alphabetic()
}

///|
fn is_tag_name_end(ch : Char) -> Bool {
  ch.is_ascii_whitespace() || ch == '/' || ch == '>'
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
fn Parser::decoded_special_text(
  self : Parser,
  name : StringView,
  raw : StringView,
  start : Int,
  closed : Bool,
) -> String {
  let (raw, offset) = if name == "textarea" {
    strip_one_initial_lf_with_offset(raw)
  } else {
    (raw, 0)
  }
  if name == "script" {
    let (text, errors) = decode_script_text(raw, start + offset, closed)
    for error in errors {
      self.error_at(error.code, error.offset)
    }
    text
  } else {
    let raw = self.replace_null_characters(raw, start + offset)
    if special_text_decodes_entities(name) {
      decode_entities(raw, in_attribute=false)
    } else {
      normalize_newlines(raw)
    }
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
fn parse_quoted_doctype_value_at(
  input : StringView,
  start : Int,
  errors : Array[DoctypeExternalError],
) -> (String?, Int, Bool) {
  match input.get_char(start) {
    Some('"') | Some('\'') as quote_opt => {
      guard quote_opt is Some(quote)
      let mut pos = start + quote.utf16_len()
      let value_start = pos
      while pos < input.length() && input.get_char(pos) != Some(quote) {
        match input.get_char(pos) {
          Some(ch) => pos += ch.utf16_len()
          None => break
        }
      }
      let mut closed = false
      let value = Some(normalize_doctype_value(input, value_start, pos, errors))
      if input.get_char(pos) == Some(quote) {
        pos += quote.utf16_len()
        closed = true
      }
      (value, pos, closed)
    }
    _ => (None, start, false)
  }
}

///|
fn skip_ascii_whitespace_in_view(input : StringView, start : Int) -> Int {
  let mut pos = start
  while pos < input.length() {
    match input.get_char(pos) {
      Some(ch) if ch.is_ascii_whitespace() => pos += ch.utf16_len()
      _ => break
    }
  }
  pos
}

///|
fn view_has_prefix_case_insensitive_at(
  input : StringView,
  start : Int,
  prefix : StringView,
) -> Bool {
  let end = start + prefix.length()
  if end > input.length() {
    false
  } else {
    match input.get_view(start~, end~) {
      Some(view) => view.compare_ignore_ascii_case(prefix) == 0
      None => false
    }
  }
}

///|
fn normalize_doctype_value(
  input : StringView,
  start : Int,
  end : Int,
  errors : Array[DoctypeExternalError],
) -> String {
  let out = StringBuilder::new(size_hint=end - start)
  let mut pos = start
  while pos < end {
    match input.get_char(pos) {
      Some('\u{0000}') => {
        push_doctype_external_error(errors, "unexpected-null-character", pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some('\r') => {
        out.write_char('\n')
        pos += 1
        if pos < end && input.get_char(pos) == Some('\n') {
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
fn parse_lower_name_value_replacing_nulls(
  input : StringView,
  start : Int,
  end : Int,
) -> (String, Array[DoctypeExternalError]) {
  let errors : Array[DoctypeExternalError] = []
  if start >= end {
    return ("", errors)
  }
  let out = StringBuilder::new(size_hint=end - start)
  let mut pos = start
  while pos < end {
    match input.get_char(pos) {
      Some('\u{0000}') => {
        push_doctype_external_error(errors, "unexpected-null-character", pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some(ch) => {
        if ch.is_ascii_uppercase() {
          out.write_char(ch.to_ascii_lowercase())
        } else {
          out.write_char(ch)
        }
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  (out.to_string(), errors)
}

///|
fn view_last_char_offset(input : StringView) -> Int {
  let mut last = 0
  let mut pos = 0
  while pos < input.length() {
    last = pos
    match input.get_char(pos) {
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  last
}

///|
priv struct DoctypeExternalError {
  code : String
  offset : Int
}

///|
priv struct DoctypeExternalParse {
  public_id : String?
  system_id : String?
  errors : Array[DoctypeExternalError]
  force_quirks : Bool
}

///|
fn push_doctype_external_error(
  errors : Array[DoctypeExternalError],
  code : String,
  offset : Int,
) -> Unit {
  errors.push(DoctypeExternalError::{ code, offset })
}

///|
fn doctype_after_system_identifier(
  input : StringView,
  after_system : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> Bool {
  let next = skip_ascii_whitespace_in_view(input, after_system)
  if next >= input.length() {
    if closed {
      false
    } else {
      push_doctype_external_error(
        errors,
        "eof-in-doctype",
        view_last_char_offset(input),
      )
      true
    }
  } else {
    push_doctype_external_error(
      errors, "unexpected-character-after-doctype-system-identifier", next,
    )
    false
  }
}

///|
fn parse_doctype_system_identifier_at(
  input : StringView,
  quote_pos : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> (String?, Bool) {
  let (system_id, after_system, system_closed) = parse_quoted_doctype_value_at(
    input, quote_pos, errors,
  )
  if !system_closed {
    if closed {
      push_doctype_external_error(
        errors,
        "abrupt-doctype-system-identifier",
        input.length(),
      )
    } else {
      push_doctype_external_error(
        errors,
        "eof-in-doctype-system-identifier",
        view_last_char_offset(input),
      )
    }
    (system_id, true)
  } else {
    (
      system_id,
      doctype_after_system_identifier(input, after_system, closed, errors),
    )
  }
}

///|
fn parse_doctype_system_after_keyword(
  input : StringView,
  after_keyword : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> (String?, Bool) {
  match input.get_char(after_keyword) {
    None =>
      if closed {
        push_doctype_external_error(
          errors,
          "missing-doctype-system-identifier",
          input.length(),
        )
        (None, true)
      } else {
        push_doctype_external_error(
          errors,
          "missing-quote-before-doctype-system-identifier",
          after_keyword - 1,
        )
        (None, true)
      }
    Some(ch) if ch.is_ascii_whitespace() => {
      let id_pos = skip_ascii_whitespace_in_view(input, after_keyword)
      if id_pos >= input.length() {
        push_doctype_external_error(
          errors,
          "missing-doctype-system-identifier",
          if closed {
            input.length()
          } else {
            view_last_char_offset(input)
          },
        )
        (None, true)
      } else {
        match input.get_char(id_pos) {
          Some('"') | Some('\'') =>
            parse_doctype_system_identifier_at(input, id_pos, closed, errors)
          _ => {
            push_doctype_external_error(
              errors, "missing-quote-before-doctype-system-identifier", id_pos,
            )
            (None, true)
          }
        }
      }
    }
    Some('"') | Some('\'') => {
      push_doctype_external_error(
        errors, "missing-whitespace-after-doctype-public-identifier", after_keyword,
      )
      parse_doctype_system_identifier_at(input, after_keyword, closed, errors)
    }
    _ => {
      push_doctype_external_error(
        errors, "unexpected-character-after-doctype-system-keyword", after_keyword,
      )
      (None, true)
    }
  }
}

///|
fn parse_doctype_after_public_identifier(
  input : StringView,
  after_public : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> (String?, Bool) {
  match input.get_char(after_public) {
    None =>
      if closed {
        (None, false)
      } else {
        push_doctype_external_error(
          errors,
          "missing-whitespace-between-doctype-public-and-system-identifiers",
          view_last_char_offset(input),
        )
        (None, true)
      }
    Some(ch) if ch.is_ascii_whitespace() => {
      let system_pos = skip_ascii_whitespace_in_view(input, after_public)
      if system_pos >= input.length() {
        if closed {
          (None, false)
        } else {
          push_doctype_external_error(
            errors,
            "missing-quote-before-doctype-system-identifier",
            view_last_char_offset(input),
          )
          (None, true)
        }
      } else {
        match input.get_char(system_pos) {
          Some('"') | Some('\'') =>
            parse_doctype_system_identifier_at(
              input, system_pos, closed, errors,
            )
          _ => {
            push_doctype_external_error(
              errors, "missing-quote-before-doctype-system-identifier", system_pos,
            )
            (None, true)
          }
        }
      }
    }
    Some('"') | Some('\'') => {
      push_doctype_external_error(
        errors, "missing-whitespace-between-doctype-public-and-system-identifiers",
        after_public,
      )
      parse_doctype_system_identifier_at(input, after_public, closed, errors)
    }
    _ => {
      push_doctype_external_error(
        errors, "unexpected-character-after-doctype-public-identifier", after_public,
      )
      (None, true)
    }
  }
}

///|
fn parse_doctype_public_after_keyword(
  input : StringView,
  after_keyword : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> (String?, String?, Bool) {
  let mut force_quirks = false
  let public_pos = match input.get_char(after_keyword) {
    None =>
      if closed {
        push_doctype_external_error(
          errors,
          "missing-doctype-public-identifier",
          input.length(),
        )
        force_quirks = true
        None
      } else {
        push_doctype_external_error(
          errors,
          "missing-quote-before-doctype-public-identifier",
          after_keyword - 1,
        )
        force_quirks = true
        None
      }
    Some(ch) if ch.is_ascii_whitespace() => {
      let id_pos = skip_ascii_whitespace_in_view(input, after_keyword)
      if id_pos >= input.length() {
        push_doctype_external_error(
          errors,
          "missing-doctype-public-identifier",
          if closed {
            input.length()
          } else {
            view_last_char_offset(input)
          },
        )
        force_quirks = true
        None
      } else {
        match input.get_char(id_pos) {
          Some('"') | Some('\'') => Some(id_pos)
          _ => {
            push_doctype_external_error(
              errors, "missing-quote-before-doctype-public-identifier", id_pos,
            )
            force_quirks = true
            None
          }
        }
      }
    }
    Some('"') | Some('\'') => {
      push_doctype_external_error(
        errors, "missing-whitespace-before-doctype-public-identifier", after_keyword,
      )
      Some(after_keyword)
    }
    _ => {
      push_doctype_external_error(
        errors, "unexpected-character-after-doctype-public-keyword", after_keyword,
      )
      force_quirks = true
      None
    }
  }
  match public_pos {
    None => (None, None, force_quirks)
    Some(pos) => {
      let (public_id, after_public, public_closed) = parse_quoted_doctype_value_at(
        input, pos, errors,
      )
      if !public_closed {
        if closed {
          push_doctype_external_error(
            errors,
            "abrupt-doctype-public-identifier",
            input.length(),
          )
        } else {
          push_doctype_external_error(
            errors,
            "eof-in-doctype-public-identifier",
            view_last_char_offset(input),
          )
        }
        (public_id, None, true)
      } else {
        let (system_id, system_force_quirks) = parse_doctype_after_public_identifier(
          input, after_public, closed, errors,
        )
        (public_id, system_id, force_quirks || system_force_quirks)
      }
    }
  }
}

///|
fn parse_doctype_external(
  input : StringView,
  closed : Bool,
) -> DoctypeExternalParse {
  let errors : Array[DoctypeExternalError] = []
  let mut public_id : String? = None
  let mut system_id : String? = None
  let mut force_quirks = false
  match input.get_char(0) {
    Some(ch) if ch.is_ascii_whitespace() => {
      let start = ch.utf16_len()
      if view_has_prefix_case_insensitive_at(input, start, "public") {
        let (parsed_public, parsed_system, force) = parse_doctype_public_after_keyword(
          input,
          start + 6,
          closed,
          errors,
        )
        public_id = parsed_public
        system_id = parsed_system
        force_quirks = force
      } else if view_has_prefix_case_insensitive_at(input, start, "system") {
        let (parsed_system, force) = parse_doctype_system_after_keyword(
          input,
          start + 6,
          closed,
          errors,
        )
        system_id = parsed_system
        force_quirks = force
      } else {
        let unexpected = skip_ascii_whitespace_in_view(input, start)
        if unexpected < input.length() {
          push_doctype_external_error(
            errors, "missing-whitespace-after-doctype-name", unexpected,
          )
          force_quirks = true
        }
      }
    }
    _ => ()
  }
  DoctypeExternalParse::{ public_id, system_id, errors, force_quirks }
}

///|
fn is_known_doctype(
  name : StringView,
  public_id : String?,
  system_id : String?,
) -> Bool {
  if name != "html" {
    return false
  }
  match (public_id, system_id) {
    (None, None) => true
    (None, Some("about:legacy-compat")) => true
    (Some("-//W3C//DTD HTML 4.0//EN"), None) => true
    (
      Some("-//W3C//DTD HTML 4.0//EN"),
      Some("http://www.w3.org/TR/REC-html40/strict.dtd"),
    ) => true
    (Some("-//W3C//DTD HTML 4.01//EN"), None) => true
    (
      Some("-//W3C//DTD HTML 4.01//EN"),
      Some("http://www.w3.org/TR/html4/strict.dtd"),
    ) => true
    (
      Some("-//W3C//DTD XHTML 1.0 Strict//EN"),
      Some("http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"),
    ) => true
    (
      Some("-//W3C//DTD XHTML 1.1//EN"),
      Some("http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"),
    ) => true
    _ => false
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
        Some('/') => return Some(pos)
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
          text(self.decoded_special_text(name, view, content_start, false)),
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
            text(self.decoded_special_text(name, view, content_start, true)),
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
            text(self.decoded_special_text(name, view, content_start, false)),
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
fn normalize_bogus_comment_data(input : StringView) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  let mut pos = 0
  while pos < input.length() {
    match input.get_char(pos) {
      Some('\u{0000}') => {
        out.write_char('\u{FFFD}')
        pos += 1
      }
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
  let deferred_initial_doctype_error = parser.report_initial_doctype_error()
  parser.parse_all()
  match deferred_initial_doctype_error {
    Some(error) => parser.errors.push(error)
    None => ()
  }
  parser.report_eof_tree_errors()
  scaffold_document(root)
  normalize_tables(root)
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
fn merge_missing_attrs(target : Node, source : Node) -> Unit {
  for name, value in source.attrs {
    if !target.attrs.contains(name) {
      target.attrs[name] = value
    }
  }
}

///|
fn append_body_node_contents(
  body_node : Node,
  source : Node,
  body_children : Array[Node],
) -> Unit {
  merge_missing_attrs(body_node, source)
  let existing = source.children.copy()
  source.children.clear()
  for child in existing {
    if child.kind == Element && child.name == "body" {
      append_body_node_contents(body_node, child, body_children)
    } else {
      body_children.push(child)
    }
  }
}

///|
fn append_html_node_contents(
  html_node : Node,
  source : Node,
  html_children : Array[Node],
) -> Unit {
  merge_missing_attrs(html_node, source)
  let existing = source.children.copy()
  source.children.clear()
  for child in existing {
    if child.kind == Element && child.name == "html" {
      append_html_node_contents(html_node, child, html_children)
    } else {
      html_children.push(child)
    }
  }
}

///|
fn Parser::document_doctype_is_initial(self : Parser) -> Bool {
  for child in self.root.children {
    if child.kind == Comment {
      ()
    } else if child.kind == Text && is_whitespace_text_node(child) {
      ()
    } else {
      return false
    }
  }
  true
}

///|
fn absorb_root_html_siblings(root : Node, html : Node) -> Unit {
  let original = root.children.copy()
  root.children.clear()
  let mut saw_html = false
  for child in original {
    if child.kind == Element && child.name == "html" {
      if saw_html {
        append_html_node_contents(html, child, html.children)
      } else {
        root.append_child(child)
        saw_html = true
      }
    } else {
      root.append_child(child)
    }
  }
}

///|
fn scaffold_existing_html_element(html : Node) -> Unit {
  let raw_original = html.children.copy()
  html.children.clear()
  let original : Array[Node] = []
  for child in raw_original {
    if child.kind == Element && child.name == "html" {
      append_html_node_contents(html, child, original)
    } else {
      original.push(child)
    }
  }
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
      append_body_node_contents(child, child, body_children)
    } else if child.kind == Element && child.name == "body" {
      match body {
        Some(body_node) =>
          append_body_node_contents(body_node, child, body_children)
        None => body_children.push(child)
      }
      body_started = true
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
      absorb_root_html_siblings(root, html)
      scaffold_existing_html_element(html)
      return
    }
    None => ()
  }
  let original = root.children.copy()
  root.children.clear()
  let mut head : Node? = None
  let mut body : Node? = None
  let head_children : Array[Node] = []
  let body_children : Array[Node] = []
  let mut body_started = false
  for child in original {
    if child.kind == Doctype {
      root.append_child(child)
    } else if child.kind == Element &&
      child.name == "head" &&
      head is None &&
      !body_started {
      head = Some(child)
    } else if child.kind == Element && child.name == "body" && body is None {
      body = Some(child)
      body_started = true
      append_body_node_contents(child, child, body_children)
    } else if child.kind == Element && child.name == "body" {
      match body {
        Some(body_node) =>
          append_body_node_contents(body_node, child, body_children)
        None => body_children.push(child)
      }
      body_started = true
    } else if child.kind == Comment && !body_started && head_children.is_empty() {
      root.append_child(child)
    } else if child.kind == Element && child.name == "head" {
      let existing = child.children.copy()
      for grandchild in existing {
        body_children.push(grandchild)
      }
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
  let head_node = head.unwrap_or(element("head"))
  let body_node = body.unwrap_or(element("body"))
  html.append_child(head_node)
  append_children_to(head_node, head_children)
  append_children_to(body_node, body_children)
  html.append_child(body_node)
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
  parser.report_eof_tree_errors()
  normalize_tables(root)
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
