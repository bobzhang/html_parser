///|
fn is_void_element(name : StringView) -> Bool {
  match name {
    "area"
    | "base"
    | "br"
    | "col"
    | "embed"
    | "hr"
    | "img"
    | "input"
    | "link"
    | "meta"
    | "param"
    | "source"
    | "track"
    | "wbr" => true
    _ => false
  }
}

///|
fn escape_text(value : StringView) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn escape_attr_value(value : StringView, quote : Char) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' if quote == '"' => out.write_string("&quot;")
      '\'' if quote == '\'' => out.write_string("&#39;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn escape_js_string(value : StringView, quote : Char) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    match ch {
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      '\u{0008}' => out.write_string("\\b")
      '\u{000C}' => out.write_string("\\f")
      '"' if quote == '"' => out.write_string("\\\"")
      '\'' if quote == '\'' => out.write_string("\\'")
      '<' => out.write_string("\\u003c")
      '>' => out.write_string("\\u003e")
      '\u{2028}' => out.write_string("\\u2028")
      '\u{2029}' => out.write_string("\\u2029")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn percent_encode_url(value : StringView) -> String {
  let bytes = @utf8.encode(value)
  let out = StringBuilder::new(size_hint=bytes.length())
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    if is_url_safe_byte(byte) {
      out.write_char(byte.to_char())
    } else {
      write_percent_encoded_byte(out, byte)
    }
  }
  out.to_string()
}

///|
fn is_url_safe_byte(byte : Byte) -> Bool {
  let value = byte.to_int()
  (value >= 0x41 && value <= 0x5A) ||
  (value >= 0x61 && value <= 0x7A) ||
  (value >= 0x30 && value <= 0x39) ||
  value == 0x2F ||
  value == 0x3A ||
  value == 0x40 ||
  value == 0x3F ||
  value == 0x26 ||
  value == 0x3D ||
  value == 0x23 ||
  value == 0x2B ||
  value == 0x2D ||
  value == 0x2E ||
  value == 0x5F ||
  value == 0x7E
}

///|
fn write_percent_encoded_byte(out : StringBuilder, byte : Byte) -> Unit {
  let value = byte.to_int()
  out.write_char('%')
  out.write_char(hex_digit_upper(value / 16))
  out.write_char(hex_digit_upper(value % 16))
}

///|
fn hex_digit_upper(value : Int) -> Char {
  match value {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'A'
    11 => 'B'
    12 => 'C'
    13 => 'D'
    14 => 'E'
    15 => 'F'
    _ => '0'
  }
}

///|
fn serialize_comment_data(value : StringView) -> String {
  let mut out = value.replace_all(old="--", new="- -").to_owned()
  if out.has_prefix(">") || out.has_prefix("->") {
    out = " " + out
  }
  if out.has_suffix("<!-") || out.has_suffix("-") {
    out = out + " "
  }
  out
}

///|
fn neutralize_rawtext_end_tag_sequences(
  value : StringView,
  tag_name : StringView,
) -> String {
  let needle = "</" + tag_name.to_owned()
  let out = StringBuilder::new(size_hint=value.length())
  let mut pos = 0
  while pos < value.length() {
    if rawtext_end_tag_sequence_at(value, pos, needle) {
      out.write_string("&lt;")
      pos += 1
    } else {
      match value.get_char(pos) {
        Some(ch) => {
          out.write_char(ch)
          pos += ch.utf16_len()
        }
        None => break
      }
    }
  }
  out.to_string()
}

///|
fn rawtext_end_tag_sequence_at(
  value : StringView,
  pos : Int,
  needle : StringView,
) -> Bool {
  if starts_with_case_insensitive(value, pos, needle) {
    rawtext_end_tag_boundary(value.get_char(pos + needle.length()))
  } else {
    false
  }
}

///|
fn rawtext_end_tag_boundary(ch : Char?) -> Bool {
  match ch {
    None | Some('>') | Some('/') => true
    Some(ch) if is_html_whitespace_char(ch) => true
    _ => false
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
fn string_contains_char(value : StringView, needle : Char) -> Bool {
  for ch in value {
    if ch == needle {
      return true
    }
  }
  false
}

///|
fn serialize_start_tag(node : Node, quote : Char) -> String {
  let out = StringBuilder::new()
  out.write_char('<')
  out.write_string(node.name)
  for name, value in node.attrs {
    out.write_char(' ')
    out.write_string(name)
    match value {
      Some(v) if attr_value_should_minimize(name, v) => ()
      Some(v) => {
        let attr_quote = choose_attr_quote(v, quote)
        out.write_char('=')
        out.write_char(attr_quote)
        out.write_string(escape_attr_value(v, attr_quote))
        out.write_char(attr_quote)
      }
      None => ()
    }
  }
  out.write_char('>')
  out.to_string()
}

///|
fn node_to_html_compact(node : Node, quote : Char) -> String {
  match node.kind {
    Document | Fragment => {
      let out = StringBuilder::new()
      for child in node.children {
        out.write_string(node_to_html_compact(child, quote))
      }
      out.to_string()
    }
    Text =>
      match node.parent {
        Some(parent) if parent.name == "script" || parent.name == "style" =>
          neutralize_rawtext_end_tag_sequences(node.data, parent.name)
        _ => escape_text(node.data)
      }
    Comment => "<!--" + serialize_comment_data(node.data) + "-->"
    Doctype => {
      let out = StringBuilder::new()
      out.write_string("<!DOCTYPE")
      if node.data != "" {
        out.write_char(' ')
        out.write_string(node.data)
      }
      match node.public_id {
        Some(value) => {
          out.write_string(" PUBLIC \"")
          out.write_string(escape_attr_value(value, '"'))
          out.write_char('"')
        }
        None => ()
      }
      match node.system_id {
        Some(value) => {
          if node.public_id is None {
            out.write_string(" SYSTEM")
          }
          out.write_string(" \"")
          out.write_string(escape_attr_value(value, '"'))
          out.write_char('"')
        }
        None => ()
      }
      out.write_char('>')
      out.to_string()
    }
    Element => {
      let out = StringBuilder::new()
      out.write_string(serialize_start_tag(node, quote))
      if !is_void_element(node.name) {
        for child in node.children {
          out.write_string(node_to_html_compact(child, quote))
        }
        out.write_string("</")
        out.write_string(node.name)
        out.write_char('>')
      }
      out.to_string()
    }
  }
}

///|
fn node_to_html_pretty(
  node : Node,
  indent : Int,
  indent_size : Int,
  quote : Char,
) -> String {
  match node.kind {
    Document | Fragment => {
      let parts : Array[String] = []
      for child in node.children {
        parts.push(node_to_html_pretty(child, indent, indent_size, quote))
      }
      parts.join("\n")
    }
    Text | Comment | Doctype =>
      " ".repeat(indent) + node_to_html_compact(node, quote)
    Element =>
      if node.children.is_empty() || is_void_element(node.name) {
        " ".repeat(indent) + node_to_html_compact(node, quote)
      } else {
        let out = StringBuilder::new()
        out.write_string(" ".repeat(indent))
        out.write_string(serialize_start_tag(node, quote))
        let child_indent = indent + indent_size
        for child in node.children {
          out.write_char('\n')
          out.write_string(
            node_to_html_pretty(child, child_indent, indent_size, quote),
          )
        }
        out.write_char('\n')
        out.write_string(" ".repeat(indent))
        out.write_string("</")
        out.write_string(node.name)
        out.write_char('>')
        out.to_string()
      }
  }
}

///|
pub fn Node::to_html(
  self : Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String {
  match context {
    Url => percent_encode_url(self.to_text().trim())
    _ => {
      let quote_char = if quote == '\'' { '\'' } else { '"' }
      let html = if pretty {
        node_to_html_pretty(self, 0, indent_size, quote_char)
      } else {
        node_to_html_compact(self, quote_char)
      }
      match context {
        Html => html
        JsString => escape_js_string(html, quote_char)
        HtmlAttrValue => escape_attr_value(html, quote_char)
        Url => html
      }
    }
  }
}

///|
pub fn to_html(
  node : Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String {
  node.to_html(pretty~, indent_size~, context~, quote~)
}

///|
fn collect_text(node : Node, parts : Array[String], strip : Bool) -> Unit {
  match node.kind {
    Text => {
      let value = if strip { node.data[:].trim().to_owned() } else { node.data }
      if value != "" {
        parts.push(value)
      }
    }
    _ =>
      for child in node.children {
        collect_text(child, parts, strip)
      }
  }
}

///|
fn is_text_block_element(name : StringView) -> Bool {
  match name {
    "address"
    | "article"
    | "aside"
    | "blockquote"
    | "body"
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
    | "hr"
    | "html"
    | "li"
    | "main"
    | "nav"
    | "ol"
    | "p"
    | "pre"
    | "section"
    | "table"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr"
    | "ul" => true
    _ => false
  }
}

///|
fn text_chunk_break(chunks : Array[Array[String]]) -> Unit {
  match chunks.last() {
    Some(chunk) if !chunk.is_empty() => chunks.push([])
    None => chunks.push([])
    _ => ()
  }
}

///|
fn current_text_chunk(chunks : Array[Array[String]]) -> Array[String] {
  match chunks.last() {
    Some(chunk) => chunk
    None => {
      let chunk : Array[String] = []
      chunks.push(chunk)
      chunk
    }
  }
}

///|
fn collect_text_block_chunks(
  node : Node,
  chunks : Array[Array[String]],
  strip : Bool,
) -> Unit {
  match node.kind {
    Text => {
      let value = if strip { node.data[:].trim().to_owned() } else { node.data }
      if value != "" {
        current_text_chunk(chunks).push(value)
      }
    }
    Element if node.name == "br" => text_chunk_break(chunks)
    Element if is_text_block_element(node.name) => {
      text_chunk_break(chunks)
      for child in node.children {
        collect_text_block_chunks(child, chunks, strip)
      }
      text_chunk_break(chunks)
    }
    _ =>
      for child in node.children {
        collect_text_block_chunks(child, chunks, strip)
      }
  }
}

///|
fn text_chunks_to_string(
  chunks : Array[Array[String]],
  separator : String,
  strip : Bool,
) -> String {
  let texts : Array[String] = []
  let intra_sep = if strip { " " } else { "" }
  for chunk in chunks {
    if !chunk.is_empty() {
      texts.push(chunk.join(intra_sep))
    }
  }
  texts.join(separator)
}

///|
pub fn Node::to_text(
  self : Node,
  separator? : String = " ",
  strip? : Bool = true,
  separator_blocks_only? : Bool = false,
) -> String {
  if separator_blocks_only {
    let chunks : Array[Array[String]] = [[]]
    collect_text_block_chunks(self, chunks, strip)
    return text_chunks_to_string(chunks, separator, strip)
  }
  let parts : Array[String] = []
  collect_text(self, parts, strip)
  parts.join(separator)
}

///|
fn class_contains(value : StringView, needle : StringView) -> Bool {
  if needle.is_empty() {
    return false
  }
  let mut token_start = 0
  let mut pos = 0
  while pos < value.length() {
    match value.get_char(pos) {
      Some(ch) if is_html_whitespace_char(ch) => {
        if class_token_matches(value, token_start, pos, needle) {
          return true
        }
        pos += ch.utf16_len()
        token_start = pos
      }
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  class_token_matches(value, token_start, value.length(), needle)
}

///|
fn class_token_matches(
  value : StringView,
  start : Int,
  end : Int,
  needle : StringView,
) -> Bool {
  if end <= start {
    false
  } else {
    match value.get_view(start~, end~) {
      Some(part) => part == needle
      None => false
    }
  }
}

///|
fn is_html_whitespace_char(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '\u{000C}' => true
    _ => false
  }
}

///|
fn next_simple_selector_marker(selector : StringView, start : Int) -> Int {
  let mut pos = start
  let mut paren_depth = 0
  while pos < selector.length() {
    match selector.get_char(pos) {
      Some(ch) => {
        if ch == '(' {
          paren_depth += 1
        } else if ch == ')' && paren_depth > 0 {
          paren_depth -= 1
        } else if paren_depth == 0 &&
          (ch == '.' || ch == '#' || ch == '[' || ch == ':') {
          return pos
        }
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  selector.length()
}

///|
fn find_attribute_selector_end(selector : StringView, start : Int) -> Int? {
  let mut pos = start + 1
  let mut quote : Char? = None
  while pos < selector.length() {
    match selector.get_char(pos) {
      Some(ch) => {
        match quote {
          Some(q) => if ch == q { quote = None }
          None =>
            if ch == '"' || ch == '\'' {
              quote = Some(ch)
            } else if ch == ']' {
              return Some(pos)
            }
        }
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  None
}

///|
fn tag_selector_matches(node : Node, tag : StringView) -> Bool {
  tag == "*" || node.name[:] == tag.to_lower()
}

///|
fn id_selector_matches(node : Node, id : StringView) -> Bool {
  match node.attrs.get("id") {
    Some(Some(value)) => value[:] == id
    _ => false
  }
}

///|
fn class_selector_matches(node : Node, class_name : StringView) -> Bool {
  match node.attrs.get("class") {
    Some(Some(value)) => class_contains(value, class_name)
    _ => false
  }
}

///|
fn attribute_value_by_name(node : Node, attr_name : StringView) -> String? {
  let wanted = lower_ascii(attr_name)
  for name, value in node.attrs {
    if lower_ascii(name[:]) == wanted {
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
  if name.is_empty() {
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
  if name.is_empty() {
    return None
  }
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
  } else {
    Some((name, AttrExact))
  }
}

///|
fn quoted_attribute_selector_value(value : StringView) -> StringView? {
  let value = value.trim()
  if value.length() < 2 {
    return Some(value)
  }
  let end = value.length() - 1
  match (value.get_char(0), value.get_char(end)) {
    (Some('"'), Some('"')) | (Some('\''), Some('\'')) =>
      value.get_view(start=1, end~)
    _ => Some(value)
  }
}

///|
fn string_view_contains(haystack : StringView, needle : StringView) -> Bool {
  if needle.is_empty() || needle.length() > haystack.length() {
    return false
  }
  let mut pos = 0
  while pos + needle.length() <= haystack.length() {
    match haystack.get_view(start=pos, end=pos + needle.length()) {
      Some(part) if part == needle => return true
      _ => ()
    }
    match haystack.get_char(pos) {
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  false
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
fn attribute_selector_matches(node : Node, selector : StringView) -> Bool {
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
        Some(actual) => attribute_value_matches(actual[:], operator, expected)
        None => false
      }
    }
    None =>
      !selector.is_empty() && attribute_value_by_name(node, selector) is Some(_)
  }
}

///|
fn is_first_element_child(node : Node) -> Bool {
  match node.parent {
    Some(parent) => {
      for child in parent.children {
        if child.kind == Element {
          return physical_equal(child, node)
        }
      }
      false
    }
    None => false
  }
}

///|
fn is_last_element_child(node : Node) -> Bool {
  match node.parent {
    Some(parent) => {
      let mut last : Node? = None
      for child in parent.children {
        if child.kind == Element {
          last = Some(child)
        }
      }
      match last {
        Some(child) => physical_equal(child, node)
        None => false
      }
    }
    None => false
  }
}

///|
fn is_only_element_child(node : Node) -> Bool {
  is_first_element_child(node) && is_last_element_child(node)
}

///|
fn is_empty_for_selector(node : Node) -> Bool {
  for child in node.children {
    match child.kind {
      Element => return false
      Text if !child.data[:].trim().is_empty() => return false
      _ => ()
    }
  }
  true
}

///|
fn is_root_for_selector(node : Node) -> Bool {
  match node.parent {
    Some(parent) => parent.kind == Document || parent.kind == Fragment
    None => false
  }
}

///|
fn is_first_of_type(node : Node) -> Bool {
  match node.parent {
    Some(parent) => {
      for child in parent.children {
        if child.kind == Element && child.name == node.name {
          return physical_equal(child, node)
        }
      }
      false
    }
    None => false
  }
}

///|
fn is_last_of_type(node : Node) -> Bool {
  match node.parent {
    Some(parent) => {
      let mut last : Node? = None
      for child in parent.children {
        if child.kind == Element && child.name == node.name {
          last = Some(child)
        }
      }
      match last {
        Some(child) => physical_equal(child, node)
        None => false
      }
    }
    None => false
  }
}

///|
fn is_only_of_type(node : Node) -> Bool {
  is_first_of_type(node) && is_last_of_type(node)
}

///|
fn element_child_index(node : Node) -> Int? {
  match node.parent {
    Some(parent) => {
      let mut index = 0
      for child in parent.children {
        if child.kind == Element {
          index += 1
          if physical_equal(child, node) {
            return Some(index)
          }
        }
      }
      None
    }
    None => None
  }
}

///|
fn element_type_index(node : Node) -> Int? {
  match node.parent {
    Some(parent) => {
      let mut index = 0
      for child in parent.children {
        if child.kind == Element && child.name == node.name {
          index += 1
          if physical_equal(child, node) {
            return Some(index)
          }
        }
      }
      None
    }
    None => None
  }
}

///|
fn normalize_nth_expression(expr : StringView) -> String {
  let out = StringBuilder::new(size_hint=expr.length())
  for ch in expr {
    if !ch.is_ascii_whitespace() {
      if ch.is_ascii_uppercase() {
        out.write_char(ch.to_ascii_lowercase())
      } else {
        out.write_char(ch)
      }
    }
  }
  out.to_string()
}

///|
fn parse_signed_int_view(expr : StringView) -> Int? {
  if expr.is_empty() {
    return None
  }
  let mut sign = 1
  let mut pos = 0
  match expr.get_char(pos) {
    Some('+') => pos += 1
    Some('-') => {
      sign = -1
      pos += 1
    }
    _ => ()
  }
  if pos >= expr.length() {
    return None
  }
  let mut value = 0
  while pos < expr.length() {
    match expr.get_char(pos) {
      Some(ch) if ch.is_digit(10) => {
        value = value * 10 + ch.to_int() - ('0' : Int)
        pos += ch.utf16_len()
      }
      _ => return None
    }
  }
  Some(sign * value)
}

///|
fn parse_nth_expression(expr : StringView) -> (Int, Int)? {
  let normalized = normalize_nth_expression(expr)
  let expr = normalized[:]
  if expr.is_empty() {
    return None
  }
  if expr == "odd" {
    return Some((2, 1))
  }
  if expr == "even" {
    return Some((2, 0))
  }
  match expr.split_once("n") {
    Some((a_part, b_part)) => {
      if string_view_contains(b_part, "n") {
        return None
      }
      let a = if a_part.is_empty() || a_part == "+" {
        Some(1)
      } else if a_part == "-" {
        Some(-1)
      } else {
        parse_signed_int_view(a_part)
      }
      guard a is Some(a) else { return None }
      let b = if b_part.is_empty() {
        Some(0)
      } else {
        parse_signed_int_view(b_part)
      }
      guard b is Some(b) else { return None }
      Some((a, b))
    }
    None =>
      match parse_signed_int_view(expr) {
        Some(b) => Some((0, b))
        None => None
      }
  }
}

///|
fn nth_formula_matches(index : Int, a : Int, b : Int) -> Bool {
  if a == 0 {
    index == b
  } else {
    let diff = index - b
    if a > 0 {
      diff >= 0 && diff % a == 0
    } else {
      diff <= 0 && diff % a == 0
    }
  }
}

///|
fn is_nth_child(node : Node, expr : StringView) -> Bool {
  guard parse_nth_expression(expr) is Some((a, b)) else { return false }
  match element_child_index(node) {
    Some(index) => nth_formula_matches(index, a, b)
    None => false
  }
}

///|
fn is_nth_of_type(node : Node, expr : StringView) -> Bool {
  guard parse_nth_expression(expr) is Some((a, b)) else { return false }
  match element_type_index(node) {
    Some(index) => nth_formula_matches(index, a, b)
    None => false
  }
}

///|
fn functional_pseudo_parts(name : StringView) -> (StringView, StringView)? {
  match name.split_once("(") {
    Some((pseudo_name, rest)) => {
      if !rest.has_suffix(")") {
        return None
      }
      let end = rest.length() - 1
      guard rest.get_view(start=0, end~) is Some(arg) else { return None }
      Some((pseudo_name, arg))
    }
    None => None
  }
}

///|
fn pseudo_selector_matches(node : Node, name : StringView) -> Bool {
  match name {
    "first-child" => is_first_element_child(node)
    "last-child" => is_last_element_child(node)
    "only-child" => is_only_element_child(node)
    "empty" => is_empty_for_selector(node)
    "root" => is_root_for_selector(node)
    "first-of-type" => is_first_of_type(node)
    "last-of-type" => is_last_of_type(node)
    "only-of-type" => is_only_of_type(node)
    _ =>
      match functional_pseudo_parts(name) {
        Some(("nth-child", arg)) => is_nth_child(node, arg)
        Some(("nth-of-type", arg)) => is_nth_of_type(node, arg)
        _ => false
      }
  }
}

///|
fn matches_simple_selector(node : Node, selector : StringView) -> Bool {
  if node.kind != Element {
    return false
  }
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  let mut pos = 0
  match selector.get_char(pos) {
    Some('*') => {
      pos += 1
      if pos < selector.length() {
        match selector.get_char(pos) {
          Some('.') | Some('#') | Some('[') | Some(':') => ()
          _ => return false
        }
      }
    }
    Some('.') | Some('#') | Some('[') | Some(':') => ()
    Some(_) => {
      let end = next_simple_selector_marker(selector, pos)
      guard selector.get_view(start=pos, end~) is Some(tag) else {
        return false
      }
      if tag.is_empty() || !tag_selector_matches(node, tag) {
        return false
      }
      pos = end
    }
    None => return false
  }
  while pos < selector.length() {
    guard selector.get_char(pos) is Some(marker) else { return false }
    if marker == '[' {
      guard find_attribute_selector_end(selector, pos) is Some(end) else {
        return false
      }
      guard selector.get_view(start=pos + 1, end~) is Some(attribute) else {
        return false
      }
      if !attribute_selector_matches(node, attribute) {
        return false
      }
      pos = end + 1
      continue
    }
    if marker == ':' {
      let start = pos + marker.utf16_len()
      let end = next_simple_selector_marker(selector, start)
      guard selector.get_view(start~, end~) is Some(name) else { return false }
      if name.is_empty() || !pseudo_selector_matches(node, name) {
        return false
      }
      pos = end
      continue
    }
    if marker != '.' && marker != '#' {
      return false
    }
    let start = pos + marker.utf16_len()
    let end = next_simple_selector_marker(selector, start)
    guard selector.get_view(start~, end~) is Some(name) else { return false }
    if name.is_empty() {
      return false
    }
    if marker == '.' {
      if !class_selector_matches(node, name) {
        return false
      }
    } else if !id_selector_matches(node, name) {
      return false
    }
    pos = end
  }
  true
}

///|
fn selector_list_part(
  selector : StringView,
  start : Int,
  end : Int,
) -> StringView? {
  match selector.get_view(start~, end~) {
    Some(part) => {
      let part = part.trim()
      if part.is_empty() {
        None
      } else {
        Some(part)
      }
    }
    None => None
  }
}

///|
priv enum SelectorCombinator {
  DescendantCombinator
  ChildCombinator
  AdjacentSiblingCombinator
  GeneralSiblingCombinator
} derive(Eq)

///|
fn push_complex_selector_part(
  parts : Array[StringView],
  combinators : Array[SelectorCombinator],
  part : StringView,
  pending : SelectorCombinator,
) -> Unit {
  if !parts.is_empty() {
    combinators.push(pending)
  }
  parts.push(part)
}

///|
fn split_complex_selector(
  selector : StringView,
) -> (Array[StringView], Array[SelectorCombinator])? {
  let selector = selector.trim()
  if selector.is_empty() {
    return None
  }
  let parts : Array[StringView] = []
  let combinators : Array[SelectorCombinator] = []
  let mut start = 0
  let mut pos = 0
  let mut bracket_depth = 0
  let mut paren_depth = 0
  let mut quote : Char? = None
  let mut pending = DescendantCombinator
  while pos < selector.length() {
    match selector.get_char(pos) {
      Some(ch) => {
        match quote {
          Some(q) => if ch == q { quote = None }
          None =>
            if bracket_depth > 0 && (ch == '"' || ch == '\'') {
              quote = Some(ch)
            } else if ch == '[' {
              bracket_depth += 1
            } else if ch == ']' && bracket_depth > 0 {
              bracket_depth -= 1
            } else if bracket_depth == 0 && ch == '(' {
              paren_depth += 1
            } else if bracket_depth == 0 && ch == ')' && paren_depth > 0 {
              paren_depth -= 1
            } else if bracket_depth == 0 &&
              paren_depth == 0 &&
              is_html_whitespace_char(ch) {
              match selector_list_part(selector, start, pos) {
                Some(part) => {
                  push_complex_selector_part(parts, combinators, part, pending)
                  pending = DescendantCombinator
                }
                None => ()
              }
              start = pos + ch.utf16_len()
            } else if bracket_depth == 0 &&
              paren_depth == 0 &&
              (ch == '>' || ch == '+' || ch == '~') {
              match selector_list_part(selector, start, pos) {
                Some(part) =>
                  push_complex_selector_part(parts, combinators, part, pending)
                None =>
                  if parts.is_empty() || pending != DescendantCombinator {
                    return None
                  }
              }
              pending = if ch == '>' {
                ChildCombinator
              } else if ch == '+' {
                AdjacentSiblingCombinator
              } else {
                GeneralSiblingCombinator
              }
              start = pos + ch.utf16_len()
            }
        }
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  match selector_list_part(selector, start, selector.length()) {
    Some(part) => push_complex_selector_part(parts, combinators, part, pending)
    None => return None
  }
  if parts.is_empty() {
    None
  } else {
    Some((parts, combinators))
  }
}

///|
fn previous_element_sibling(node : Node) -> Node? {
  match node.parent {
    Some(parent) => {
      let mut previous : Node? = None
      for child in parent.children {
        if physical_equal(child, node) {
          return previous
        }
        if child.kind == Element {
          previous = Some(child)
        }
      }
      None
    }
    None => None
  }
}

///|
fn previous_matching_sibling(node : Node, selector : StringView) -> Node? {
  match node.parent {
    Some(parent) => {
      let mut previous_match : Node? = None
      for child in parent.children {
        if physical_equal(child, node) {
          return previous_match
        }
        if child.kind == Element && matches_simple_selector(child, selector) {
          previous_match = Some(child)
        }
      }
      None
    }
    None => None
  }
}

///|
fn matches_complex_selector(node : Node, selector : StringView) -> Bool {
  guard split_complex_selector(selector) is Some((parts, combinators)) else {
    return false
  }
  let last_index = parts.length() - 1
  if !matches_simple_selector(node, parts[last_index]) {
    return false
  }
  let mut needed = last_index - 1
  let mut current = node
  while needed >= 0 {
    let wanted = parts[needed]
    match combinators[needed] {
      DescendantCombinator => {
        let mut cursor = current.parent
        let mut found = false
        while !found {
          match cursor {
            Some(ancestor) => {
              cursor = ancestor.parent
              if matches_simple_selector(ancestor, wanted) {
                current = ancestor
                found = true
              }
            }
            None => return false
          }
        }
      }
      ChildCombinator =>
        match current.parent {
          Some(ancestor) => {
            if !matches_simple_selector(ancestor, wanted) {
              return false
            }
            current = ancestor
          }
          None => return false
        }
      AdjacentSiblingCombinator =>
        match previous_element_sibling(current) {
          Some(sibling) => {
            if !matches_simple_selector(sibling, wanted) {
              return false
            }
            current = sibling
          }
          None => return false
        }
      GeneralSiblingCombinator =>
        match previous_matching_sibling(current, wanted) {
          Some(sibling) => current = sibling
          None => return false
        }
    }
    needed -= 1
  }
  true
}

///|
fn matches_selector_list(node : Node, selector : StringView) -> Bool {
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  let mut matched = false
  let mut start = 0
  let mut pos = 0
  let mut bracket_depth = 0
  let mut paren_depth = 0
  let mut quote : Char? = None
  while pos < selector.length() {
    match selector.get_char(pos) {
      Some(ch) => {
        match quote {
          Some(q) => if ch == q { quote = None }
          None =>
            if bracket_depth > 0 && (ch == '"' || ch == '\'') {
              quote = Some(ch)
            } else if ch == '[' {
              bracket_depth += 1
            } else if ch == ']' && bracket_depth > 0 {
              bracket_depth -= 1
            } else if bracket_depth == 0 && ch == '(' {
              paren_depth += 1
            } else if bracket_depth == 0 && ch == ')' && paren_depth > 0 {
              paren_depth -= 1
            } else if ch == ',' && bracket_depth == 0 && paren_depth == 0 {
              guard selector_list_part(selector, start, pos) is Some(part) else {
                return false
              }
              if matches_complex_selector(node, part) {
                matched = true
              }
              start = pos + ch.utf16_len()
            }
        }
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  guard selector_list_part(selector, start, selector.length()) is Some(part) else {
    return false
  }
  matched || matches_complex_selector(node, part)
}

///|
fn walk_query(node : Node, selector : StringView, out : Array[Node]) -> Unit {
  if matches_selector_list(node, selector) {
    out.push(node)
  }
  for child in node.children {
    walk_query(child, selector, out)
  }
}

///|
pub fn Node::query(self : Node, selector : StringView) -> Array[Node] {
  let out : Array[Node] = []
  walk_query(self, selector, out)
  out
}

///|
pub fn Node::query_one(self : Node, selector : StringView) -> Node? {
  let matches = self.query(selector)
  matches.get(0)
}

///|
pub fn matches(node : Node, selector : StringView) -> Bool {
  matches_selector_list(node, selector)
}

///|
pub fn query(root : Node, selector : StringView) -> Array[Node] {
  root.query(selector)
}

///|
pub fn to_test_format(node : Node) -> String {
  let out = StringBuilder::new()
  write_test_format(node, out, 0)
  out.to_string()
}

///|
fn write_test_format(node : Node, out : StringBuilder, indent : Int) -> Unit {
  let pad = " ".repeat(indent)
  match node.kind {
    Document => out.write_string("#document\n")
    Fragment => out.write_string("#document-fragment\n")
    Element => out.write_string(pad + "| <" + node.name + ">\n")
    Text => out.write_string(pad + "| \"" + node.data + "\"\n")
    Comment => out.write_string(pad + "| <!-- " + node.data + " -->\n")
    Doctype => out.write_string(pad + "| <!DOCTYPE " + node.data + ">\n")
  }
  for child in node.children {
    write_test_format(child, out, indent + 2)
  }
}
