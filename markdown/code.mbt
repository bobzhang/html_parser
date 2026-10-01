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
    "\{fence} \{value} \{fence}"
  } else {
    "\{fence}\{value}\{fence}"
  }
}

///|
/// Concatenate the text descendants of `node` in document order (template
/// contents included), using an explicit stack so deep trees cannot
/// overflow the call stack.
fn markdown_collect_text(node : @dom.Node) -> String {
  let out = StringBuilder()
  let stack = [node]
  while stack.pop() is Some(current) {
    match current.kind {
      Text =>
        if !current.sanitize_escape_only {
          out.write_string(current.data)
        }
      Comment | Doctype => ()
      _ => {
        let children = markdown_children(current)
        for index = children.length() - 1; index >= 0; index = index - 1 {
          stack.push(children[index])
        }
      }
    }
  }
  out.to_string()
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
