///|
/// Children to render: an HTML template's children live in its contents
/// fragment.
fn markdown_children(node : @dom.Node) -> Array[@dom.Node] {
  match node.template_contents {
    Some(contents) => contents.children
    None => node.children
  }
}

///|
fn markdown_walk_pre(node : @dom.Node, builder : MarkdownBuilder) -> Unit {
  let code = markdown_collect_text(node)
  let body = markdown_code_block_body(code)
  let fence = markdown_backtick_fence(code, 3)
  builder.ensure_newlines(2)
  builder.raw(fence)
  builder.newline(1)
  if code != "" {
    builder.raw(body)
    builder.newline(1)
  }
  builder.raw(fence)
  builder.ensure_newlines(2)
}

///|
/// Start a Markdown list: separate it from preceding output and schedule one
/// `ListItem` task per `<li>` child followed by the closing blank line.
fn MarkdownWalker::start_list(
  self : MarkdownWalker,
  node : @dom.Node,
  builder : MarkdownBuilder,
  ordered : Bool,
  list_depth : Int,
) -> Unit {
  if !builder.is_empty() {
    builder.ensure_newlines(2)
  }
  self.tasks.push(EnsureNewlines(2))
  let items = markdown_children(node).filter(child => {
    child.kind == Element && child.name.to_lower() == "li"
  })
  for index = items.length() - 1; index >= 0; index = index - 1 {
    self.tasks.push(
      ListItem(items[index], ordered, index + 1, index == 0, list_depth),
    )
  }
}
