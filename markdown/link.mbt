///|
fn markdown_link_destination(value : StringView) -> String {
  let trimmed = value.trim()
  if trimmed.is_empty() {
    return ""
  }
  if markdown_link_destination_needs_wrap(trimmed) {
    "<\{markdown_percent_encode_link_destination(trimmed)}>"
  } else {
    trimmed.to_owned()
  }
}

///|
fn markdown_link_destination_needs_wrap(value : StringView) -> Bool {
  for ch in value {
    if markdown_link_destination_wrap_trigger(ch) {
      return true
    }
  }
  false
}

///|
fn markdown_link_destination_wrap_trigger(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '(' | ')' | '<' | '>' => true
    _ => false
  }
}

///|
fn markdown_percent_encode_link_destination(value : StringView) -> String {
  let bytes = @utf8.encode(value)
  let out = StringBuilder(size_hint=bytes.length())
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    if markdown_link_destination_byte_is_safe(byte) {
      out.write_char(byte.to_char())
    } else {
      @seri.write_percent_encoded_byte(out, byte)
    }
  }
  out.to_string()
}

///|
fn markdown_link_destination_byte_is_safe(byte : Byte) -> Bool {
  match byte {
    b'A'..=b'Z'
    | b'a'..=b'z'
    | b'0'..=b'9'
    | b':'
    | b'/'
    | b'?'
    | b'#'
    | b'['
    | b']'
    | b'@'
    | b'!'
    | b'$'
    | b'&'
    | b'\''
    | b'*'
    | b'+'
    | b','
    | b';'
    | b'='
    | b'%'
    | b'-'
    | b'.'
    | b'_'
    | b'~'
    | b'('
    | b')' => true
    _ => false
  }
}

///|
fn attribute_value_by_name(node : @dom.Node, attr_name : StringView) -> String? {
  let wanted = @syn.lower_ascii(attr_name)
  for name, value in node.attrs {
    if @syn.lower_ascii(name) == wanted {
      return Some(value.unwrap_or(""))
    }
  }
  None
}

///|
/// Close a link whose `[` and text have already been written: emit `]` and
/// the destination, if any.
fn markdown_emit_link_tail(node : @dom.Node, builder : MarkdownBuilder) -> Unit {
  builder.raw("]")
  match attribute_value_by_name(node, "href") {
    Some(href) => {
      let destination = markdown_link_destination(href)
      if href != "" {
        builder.raw("(")
        builder.raw(destination)
        builder.raw(")")
      }
    }
    None => ()
  }
}

///|
/// Visit `node` inside link text. Block structure is flattened to spaces;
/// children are scheduled on the work stack rather than rendered recursively.
fn MarkdownWalker::walk_link_text(
  self : MarkdownWalker,
  node : @dom.Node,
) -> Unit raise @core.HtmlError {
  let builder = self.current()
  match node.kind {
    Text =>
      if !node.sanitize_escape_only {
        builder.text(markdown_escape_text(node.data))
      }
    Comment | Doctype => ()
    Document | Fragment => self.push_link_children(markdown_children(node))
    Element => {
      let tag = node.name.to_lower()
      if markdown_should_skip_head_or_title(node, tag) || tag == "hr" {
        ()
      } else if markdown_heading_level(tag) > 0 {
        self.push_link_children(markdown_children(node))
      } else {
        match tag {
          "br" => builder.text(" ")
          "html" | "body" | "span" | "blockquote" =>
            self.push_link_children(markdown_children(node))
          "p" => {
            self.tasks.push(SpaceText)
            self.push_link_children(markdown_children(node))
          }
          "b" | "strong" => {
            self.open_wrapped("**")
            self.push_link_children(markdown_children(node))
          }
          "i" | "em" => {
            self.open_wrapped("*")
            self.push_link_children(markdown_children(node))
          }
          "code" | "pre" =>
            builder.raw(markdown_code_span(markdown_collect_text(node)))
          "ul" | "ol" => {
            let items = markdown_children(node).filter(child => {
              child.kind == Element && child.name.to_lower() == "li"
            })
            for index = items.length() - 1; index >= 0; index = index - 1 {
              self.tasks.push(LinkListItem(items[index]))
            }
          }
          "table" => builder.raw(@ser.to_html(node, pretty=false))
          "script" | "style" | "textarea" =>
            if self.html_passthrough {
              builder.raw(@ser.to_html(node, pretty=false))
            }
          "img" => builder.raw(@ser.to_html(node, pretty=false))
          _ => {
            if markdown_block_container_name(tag) {
              self.tasks.push(SpaceText)
            }
            self.push_link_children(markdown_children(node))
          }
        }
      }
    }
  }
}
