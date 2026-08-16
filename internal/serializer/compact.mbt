///|
/// Children to serialize: an HTML template's children live in its contents
/// fragment; every other node serializes its regular children.
fn serialized_children(node : @dom.Node) -> Array[@dom.Node] {
  match node.template_contents {
    Some(contents) => contents.children
    None => node.children
  }
}

///|
fn node_to_html_compact(
  node : @dom.Node,
  quote : Char,
) -> String raise @core.HtmlError {
  match node.kind {
    Text if node.sanitize_escape_only => ""
    Document | Fragment => {
      let out = StringBuilder()
      for child in serialized_children(node) {
        out.write_string(node_to_html_compact(child, quote))
      }
      out.to_string()
    }
    // A text node reached on its own is always escaped. Raw-text content is
    // emitted by its parent element, which joins and guards all the children
    // at once; reaching a text node here means the parent is not part of the
    // output, so nothing would keep the text inert once it is reparsed.
    Text => escape_text(node.data)
    Comment => "<!--\{serialize_comment_data(node.data)}-->"
    Doctype => {
      let out = StringBuilder()
      out.write_string("<!DOCTYPE")
      if node.data != "" {
        validate_serializable_tag_name(node.data)
        out <+ " \{node.data}"
      }
      match node.public_id {
        Some(value) => {
          let escaped = escape_attr_value(value, '"')
          out <+ " PUBLIC \"\{escaped}\""
        }
        None => ()
      }
      match node.system_id {
        Some(value) => {
          if node.public_id is None {
            out.write_string(" SYSTEM")
          }
          let escaped = escape_attr_value(value, '"')
          out <+ " \"\{escaped}\""
        }
        None => ()
      }
      out.write_char('>')
      out.to_string()
    }
    Element => {
      let out = StringBuilder()
      out.write_string(serialize_start_tag(node, quote))
      if !is_void_element(node.name) {
        if raw_text_element(node) {
          out.write_string(raw_text_children_html(node, quote))
        } else {
          for child in serialized_children(node) {
            out.write_string(node_to_html_compact(child, quote))
          }
        }
        out <+ "</\{node.name}>"
      }
      out.to_string()
    }
  }
}
