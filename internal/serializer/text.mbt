///|
fn collect_text(node : @dom.Node, parts : Array[String], strip : Bool) -> Unit {
  match node.kind {
    Text => {
      if node.sanitize_escape_only {
        return
      }
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
  node : @dom.Node,
  chunks : Array[Array[String]],
  strip : Bool,
) -> Unit {
  match node.kind {
    Text => {
      if node.sanitize_escape_only {
        return
      }
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
