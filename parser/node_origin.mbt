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
