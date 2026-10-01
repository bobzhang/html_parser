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
/// One pending step of HTML serialization.
///
/// The serializer walks the tree with this heap-allocated work stack instead
/// of native recursion, so the nesting depth of the input is bounded by memory
/// rather than by the call stack.
priv enum HtmlTask {
  /// Serialize a node and its subtree in compact form.
  Compact(@dom.Node)
  /// Pretty-print a node whose preorder position in the `PrettyIndex` is
  /// `index`, at `indent` spaces.
  Pretty(@dom.Node, index~ : Int, indent~ : Int)
  /// Append literal output.
  Write(String)
  /// Close a raw-text capture opened for the element named `name`: guard the
  /// joined payload and append it to the enclosing output.
  EndRawText(String)
}

///|
/// Serializer state: the work stack and the output being built.
///
/// `outputs` is a stack of builders. The bottom one receives the final
/// markup; a raw-text element pushes a builder so its whole payload can be
/// guarded at once when the matching `EndRawText` runs.
priv struct HtmlWriter {
  quote : Char
  indent_size : Int
  tasks : Array[HtmlTask]
  outputs : Array[StringBuilder]
  pretty_index : PrettyIndex?
}

///|
fn HtmlWriter::new(
  root : @dom.Node,
  pretty : Bool,
  indent_size : Int,
  quote : Char,
) -> HtmlWriter {
  {
    quote,
    indent_size,
    tasks: [],
    outputs: [StringBuilder()],
    pretty_index: if pretty {
      Some(PrettyIndex::new(root))
    } else {
      None
    },
  }
}

///|
fn HtmlWriter::out(self : HtmlWriter) -> StringBuilder {
  self.outputs[self.outputs.length() - 1]
}

///|
fn HtmlWriter::write(self : HtmlWriter, value : String) -> Unit {
  self.out().write_string(value)
}

///|
/// Schedule `tasks` so they run in array order.
fn HtmlWriter::push_in_order(
  self : HtmlWriter,
  tasks : Array[HtmlTask],
) -> Unit {
  for i = tasks.length() - 1; i >= 0; i = i - 1 {
    self.tasks.push(tasks[i])
  }
}

///|
/// Run scheduled tasks until the stack is empty and return the output.
fn HtmlWriter::finish(self : HtmlWriter) -> String raise @core.HtmlError {
  while self.tasks.pop() is Some(task) {
    match task {
      Compact(node) => self.compact(node)
      Pretty(node, index~, indent~) => self.pretty(node, index, indent)
      Write(value) => self.write(value)
      EndRawText(name) => {
        let raw = self.outputs.unsafe_pop()
        self.write(raw_text_payload(raw.to_string(), name))
      }
    }
  }
  self.outputs[0].to_string()
}

///|
/// Schedule a raw-text element's children as a single literal payload.
///
/// The end-tag guard runs over the joined content rather than over each child
/// separately, so a closing sequence split across adjacent text nodes — say
/// `"</x"` followed by `"mp><img src=x onerror=1>"` inside an `xmp` — cannot
/// slip past it and break out of the element.
fn HtmlWriter::push_raw_text_children(
  self : HtmlWriter,
  node : @dom.Node,
) -> Unit {
  let tasks : Array[HtmlTask] = []
  for child in serialized_children(node) {
    match child.kind {
      Text => if !child.sanitize_escape_only { tasks.push(Write(child.data)) }
      _ => tasks.push(Compact(child))
    }
  }
  tasks.push(EndRawText(node.name))
  self.push_in_order(tasks)
  self.outputs.push(StringBuilder())
}

///|
fn HtmlWriter::push_compact_children(
  self : HtmlWriter,
  node : @dom.Node,
) -> Unit {
  let children = serialized_children(node)
  for i = children.length() - 1; i >= 0; i = i - 1 {
    self.tasks.push(Compact(children[i]))
  }
}

///|
fn HtmlWriter::compact(
  self : HtmlWriter,
  node : @dom.Node,
) -> Unit raise @core.HtmlError {
  match node.kind {
    Text if node.sanitize_escape_only => ()
    Document | Fragment => self.push_compact_children(node)
    // A text node reached on its own is always escaped. Raw-text content is
    // emitted by its parent element, which joins and guards all the children
    // at once; reaching a text node here means the parent is not part of the
    // output, so nothing would keep the text inert once it is reparsed.
    Text => self.write(escape_text(node.data))
    Comment => self.out() <+ "<!--\{serialize_comment_data(node.data)}-->"
    Doctype => self.write(doctype_html(node))
    Element => {
      self.write(serialize_start_tag(node, self.quote))
      if !is_void_element(node.name) {
        self.tasks.push(Write("</\{node.name}>"))
        if raw_text_element(node) {
          self.push_raw_text_children(node)
        } else {
          self.push_compact_children(node)
        }
      }
    }
  }
}

///|
fn doctype_html(node : @dom.Node) -> String raise @core.HtmlError {
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

///|
/// Compact serialization of a text node, as `HtmlWriter::compact` emits it.
fn compact_text_html(node : @dom.Node) -> String {
  if node.sanitize_escape_only {
    ""
  } else {
    escape_text(node.data)
  }
}
