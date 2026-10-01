///|
fn collect_text(root : @dom.Node, parts : Array[String], strip : Bool) -> Unit {
  let stack = [root]
  while stack.pop() is Some(node) {
    match node.kind {
      Text => {
        if node.sanitize_escape_only {
          continue
        }
        let value = if strip {
          node.data[:].trim().to_owned()
        } else {
          node.data
        }
        if value != "" {
          parts.push(value)
        }
      }
      _ => push_serialized_children_reversed(stack, node)
    }
  }
}

///|
/// Push `node`'s serialized children so that popping visits them in order.
fn push_serialized_children_reversed(
  stack : Array[@dom.Node],
  node : @dom.Node,
) -> Unit {
  let children = serialized_children(node)
  for i = children.length() - 1; i >= 0; i = i - 1 {
    stack.push(children[i])
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
/// One pending step of block-aware text extraction.
priv enum TextBlockTask {
  Visit(@dom.Node)
  /// End the current chunk after a text block element's children.
  Break
}

///|
fn collect_text_block_chunks(
  root : @dom.Node,
  chunks : Array[Array[String]],
  strip : Bool,
) -> Unit {
  let stack = [TextBlockTask::Visit(root)]
  fn push_children(node) {
    let children = serialized_children(node)
    for i = children.length() - 1; i >= 0; i = i - 1 {
      stack.push(Visit(children[i]))
    }
  }

  while stack.pop() is Some(task) {
    guard task is Visit(node) else {
      text_chunk_break(chunks)
      continue
    }
    match node.kind {
      Text => {
        if node.sanitize_escape_only {
          continue
        }
        let value = if strip {
          node.data[:].trim().to_owned()
        } else {
          node.data
        }
        if value != "" {
          current_text_chunk(chunks).push(value)
        }
      }
      Element if node.name == "br" => text_chunk_break(chunks)
      Element if is_text_block_element(node.name) => {
        text_chunk_break(chunks)
        stack.push(Break)
        push_children(node)
      }
      _ => push_children(node)
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
/// Extract descendant text from a node.
pub fn to_text(
  node : @dom.Node,
  separator? : String = " ",
  strip? : Bool = true,
  separator_blocks_only? : Bool = false,
) -> String {
  if separator_blocks_only {
    let chunks : Array[Array[String]] = [[]]
    collect_text_block_chunks(node, chunks, strip)
    return text_chunks_to_string(chunks, separator, strip)
  }
  let parts : Array[String] = []
  collect_text(node, parts, strip)
  parts.join(separator)
}
