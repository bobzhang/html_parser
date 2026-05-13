///|
fn cli_selector_is_valid(selector : StringView) -> Bool {
  @sel.is_valid(selector)
}

///|
fn cli_selected_nodes(
  root : @dom.Node,
  options : CliOptions,
) -> Array[@dom.Node]? {
  let nodes = match options.selector {
    Some(selector) => {
      if !cli_selector_is_valid(selector) {
        return None
      }
      @sel.query(root, selector)
    }
    None => [root]
  }
  if nodes.is_empty() {
    Some([])
  } else if options.first {
    Some([nodes[0]])
  } else {
    Some(nodes)
  }
}
