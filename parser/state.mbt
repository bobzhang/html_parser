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
  foster_parented_texts : Array[@dom.Node]
  after_body_nodes : Array[@dom.Node]
  mut pending_text_node : @dom.Node?
  mut pending_text_builder : StringBuilder
  mut pending_text_is_whitespace : Bool
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
fn Parser::Parser(
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
    foster_parented_texts: [],
    after_body_nodes: [],
    pending_text_node: None,
    pending_text_builder: StringBuilder(),
    pending_text_is_whitespace: true,
    post_body_html_children: [],
    active_formatting: [],
  }
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
