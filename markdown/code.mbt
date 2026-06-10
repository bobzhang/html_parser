///|
fn markdown_backtick_fence(value : StringView, minimum : Int) -> String {
  let mut longest = 0
  let mut run = 0
  for ch in value {
    if ch == '`' {
      run += 1
      if run > longest {
        longest = run
      }
    } else {
      run = 0
    }
  }
  let size = if minimum > longest + 1 { minimum } else { longest + 1 }
  "`".repeat(size)
}

///|
fn markdown_code_span(value : StringView) -> String {
  let fence = markdown_backtick_fence(value, 1)
  if value.has_prefix("`") || value.has_suffix("`") {
    fence + " " + value.to_owned() + " " + fence
  } else {
    fence + value.to_owned() + fence
  }
}

///|
fn markdown_collect_text(node : @dom.Node) -> String {
  let parts : Array[String] = []
  markdown_collect_text_into(node, parts)
  parts.join("")
}

///|
fn markdown_collect_text_into(node : @dom.Node, parts : Array[String]) -> Unit {
  match node.kind {
    Text => if !node.sanitize_escape_only { parts.push(node.data) }
    Comment | Doctype => ()
    _ =>
      for child in markdown_children(node) {
        markdown_collect_text_into(child, parts)
      }
  }
}

///|
fn markdown_code_block_body(value : StringView) -> String {
  let mut end = value.length()
  while end > 0 {
    match value.get_char(end - 1) {
      Some('\n') => end -= 1
      _ => break
    }
  }
  value[0:end].to_owned()
}
