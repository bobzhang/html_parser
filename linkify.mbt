///|
/// Find URL and email-like spans in plain text using the default configuration.
pub fn find_links(text : StringView) -> Array[LinkMatch] {
  @link.find_links(text)
}

///|
/// Find URL and email-like spans in plain text using an explicit configuration.
pub fn find_links_with_config(
  text : StringView,
  config : LinkifyConfig,
) -> Array[LinkMatch] {
  @link.find_links_with_config(text, config)
}

///|
/// Linkify URL and email text inside a DOM subtree.
///
/// The transform mutates and returns `node`.
pub fn linkify_dom(
  node : Node,
  config? : LinkifyConfig,
  skip_tags? : Array[String],
) -> Node {
  match (config, skip_tags) {
    (Some(config), Some(skip_tags)) =>
      @link.linkify_dom(node, config~, skip_tags~)
    (Some(config), None) => @link.linkify_dom(node, config~)
    (None, Some(skip_tags)) => @link.linkify_dom(node, skip_tags~)
    (None, None) => @link.linkify_dom(node)
  }
}

///|
fn linkify_default_dom_skip_tags() -> Array[String] {
  @link.linkify_default_dom_skip_tags()
}

///|
fn linkify_text_child_at_matches(
  parent : Node,
  index : Int,
  child : Node,
  matches : Array[LinkMatch],
) -> Int {
  @link.linkify_text_child_at_matches(parent, index, child, matches)
}
