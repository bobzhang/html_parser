///|
priv struct Parser {
  input : StringView
  scripting_enabled : Bool
  xml_coercion : Bool
  track_node_locations : Bool
  mut pos : Int
  errors : Array[@core.ParseError]
  root : @dom.Node
  stack : Array[@dom.Node]
  mut form_element : @dom.Node?
  mut frameset_ok : Bool
  mut frameset_reprocesses_in_body_mode : Bool
  mut detached_frameset_mode : Bool
  mut before_html_phase : Bool
  mut after_frameset : Bool
  mut document_after_body : Bool
  mut select_insertion_mode : Bool
  mut foreign_table_row_recovery_mode : Bool
  foster_parented_start_error_nodes : Array[@dom.Node]
  mut fragment_context_table : @dom.Node?
  mut fragment_context_table_section : @dom.Node?
  mut fragment_context_table_row : @dom.Node?
  mut fragment_context_table_cell : @dom.Node?
  mut fragment_context_caption : Bool
  mut fragment_context_colgroup : Bool
  mut fragment_context_html : Bool
  mut fragment_context_html_root : @dom.Node?
  mut fragment_context_html_after_body : Bool
  mut fragment_context_foreign : @dom.Node?
  template_column_group_templates : Array[@dom.Node]
  template_table_context_templates : Array[@dom.Node]
  mut template_table_context_detached_mode : Bool
  mut template_detached_column_group_mode : Bool
  mut deferred_initial_doctype_error : @core.ParseError?
  mut duplicate_head_element : @dom.Node?
  mut repeated_document_html_shell : Bool
  pending_document_html_attrs : Map[String, String?]
  mut pending_table_view_implied_end_tag : Bool
  post_body_html_children : Array[@dom.Node]
  active_formatting : Array[FormattingEntry]
}

///|
priv struct FormattingEntry {
  marker : Bool
  name : String
  ns : String
  attrs : Map[String, String?]
  node : @dom.Node
}

///|
fn Parser::new(
  input : StringView,
  root : @dom.Node,
  scripting_enabled~ : Bool,
  xml_coercion~ : Bool,
  track_node_locations? : Bool = false,
) -> Parser {
  let input = strip_leading_bom(input)
  {
    input,
    scripting_enabled,
    xml_coercion,
    track_node_locations,
    pos: 0,
    errors: [],
    root,
    stack: [root],
    form_element: None,
    frameset_ok: root.kind == Document,
    frameset_reprocesses_in_body_mode: false,
    detached_frameset_mode: false,
    before_html_phase: root.kind == Document,
    after_frameset: false,
    document_after_body: false,
    select_insertion_mode: false,
    foreign_table_row_recovery_mode: false,
    foster_parented_start_error_nodes: [],
    fragment_context_table: None,
    fragment_context_table_section: None,
    fragment_context_table_row: None,
    fragment_context_table_cell: None,
    fragment_context_caption: false,
    fragment_context_colgroup: false,
    fragment_context_html: false,
    fragment_context_html_root: None,
    fragment_context_html_after_body: false,
    fragment_context_foreign: None,
    template_column_group_templates: [],
    template_table_context_templates: [],
    template_table_context_detached_mode: false,
    template_detached_column_group_mode: false,
    deferred_initial_doctype_error: None,
    duplicate_head_element: None,
    repeated_document_html_shell: false,
    pending_document_html_attrs: {},
    pending_table_view_implied_end_tag: false,
    post_body_html_children: [],
    active_formatting: [],
  }
}

///|
fn mark_node_parsed_from_source(node : @dom.Node) -> Unit {
  node.parsed_from_source = true
}

///|
fn set_node_origin(
  node : @dom.Node,
  offset : Int,
  line : Int,
  col : Int,
) -> Unit {
  node.origin_offset = Some(offset)
  node.origin_line = Some(line)
  node.origin_col = Some(col)
}

///|
fn set_node_source_start_tag(node : @dom.Node, value : String) -> Unit {
  node.source_start_tag = Some(value)
}

///|
fn set_node_source_end_tag(node : @dom.Node, value : String) -> Unit {
  node.source_end_tag = Some(value)
}

///|
fn mark_node_sanitize_escape_only(node : @dom.Node) -> Unit {
  node.sanitize_escape_only = true
}

///|
fn copy_node_origin_from(node : @dom.Node, source : @dom.Node) -> Unit {
  node.parsed_from_source = source.parsed_from_source
  node.source_start_tag = source.source_start_tag
  node.source_end_tag = source.source_end_tag
  node.sanitize_escape_only = source.sanitize_escape_only
  node.origin_offset = source.origin_offset
  node.origin_line = source.origin_line
  node.origin_col = source.origin_col
}

///|
fn Parser::node_with_origin(
  self : Parser,
  node : @dom.Node,
  offset : Int,
) -> @dom.Node {
  mark_node_parsed_from_source(node)
  if self.track_node_locations {
    let (line, col) = line_col_at(self.input, offset)
    set_node_origin(node, offset, line, col)
  }
  node
}

///|
fn Parser::source_tag_slice(
  self : Parser,
  start : Int,
  tag_close_pos : Int,
) -> String {
  self.input[start:tag_close_pos + 1].to_owned()
}

///|
fn Parser::node_with_start_tag_source(
  self : Parser,
  node : @dom.Node,
  offset : Int,
  tag_close_pos : Int,
) -> @dom.Node {
  let node = self.node_with_origin(node, offset)
  set_node_source_start_tag(node, self.source_tag_slice(offset, tag_close_pos))
  node
}

///|
fn Parser::append_sanitize_escape_source_text(
  self : Parser,
  start : Int,
  end : Int,
) -> Unit {
  if self.root.kind != Fragment {
    return
  }
  let view = self.input[start:end]
  let node = self.text_at(view, start)
  mark_node_sanitize_escape_only(node)
  self.current_node().append_child(node)
}

///|
fn Parser::text_at(self : Parser, data : StringView, offset : Int) -> @dom.Node {
  self.node_with_origin(@dom.text(data), offset)
}

///|
fn Parser::comment_at(
  self : Parser,
  data : StringView,
  offset : Int,
) -> @dom.Node {
  self.node_with_origin(@dom.comment(data), offset)
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
fn Parser::current_node(self : Parser) -> @dom.Node {
  match self.stack.last() {
    Some(node) => node
    None => self.root
  }
}
