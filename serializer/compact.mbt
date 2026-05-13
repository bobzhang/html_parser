///|
fn node_to_html_compact(
  node : @dom.Node,
  quote : Char,
) -> String raise @core.HtmlError {
  match node.kind {
    Text if node.sanitize_escape_only => ""
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
        validate_serializable_tag_name(node.data)
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
