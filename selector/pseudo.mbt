///|
fn functional_pseudo_parts(name : StringView) -> (StringView, StringView)? {
  match name.split_once("(") {
    Some((pseudo_name, rest)) => {
      let mut depth = 1
      let mut pos = 0
      while pos < rest.length() {
        guard rest.get_char(pos) is Some(ch) else { return None }
        if ch == '(' {
          depth += 1
        } else if ch == ')' {
          depth -= 1
          if depth == 0 {
            if pos + ch.utf16_len() != rest.length() {
              return None
            }
            return Some((pseudo_name, rest[0:pos]))
          }
        }
        pos += ch.utf16_len()
      }
      None
    }
    None => None
  }
}

///|
fn pseudo_selector_matches(node : @dom.Node, name : StringView) -> Bool {
  let lower_name = @syn.lower_ascii(name)
  match lower_name[:] {
    "comment" => node.kind == Comment
    "first-child" => is_first_element_child(node)
    "last-child" => is_last_element_child(node)
    "only-child" => is_only_element_child(node)
    "empty" => is_empty_for_selector(node)
    "root" => is_root_for_selector(node)
    "first-of-type" => is_first_of_type(node)
    "last-of-type" => is_last_of_type(node)
    "only-of-type" => is_only_of_type(node)
    _ =>
      match functional_pseudo_parts(name) {
        Some((pseudo_name, arg)) =>
          match @syn.lower_ascii(pseudo_name)[:] {
            "nth-child" => is_nth_child(node, arg)
            "nth-of-type" => is_nth_of_type(node, arg)
            "not" => !matches_selector_list(node, arg)
            "contains" => contains_text(node, arg)
            "comment" => node.kind == Comment
            _ => false
          }
        _ => false
      }
  }
}

///|
fn pseudo_selector_is_valid(name : StringView) -> Bool {
  let lower_name = @syn.lower_ascii(name)
  match lower_name[:] {
    "comment"
    | "first-child"
    | "last-child"
    | "only-child"
    | "empty"
    | "root"
    | "first-of-type"
    | "last-of-type"
    | "only-of-type" => true
    _ =>
      match functional_pseudo_parts(name) {
        Some((pseudo_name, arg)) =>
          match @syn.lower_ascii(pseudo_name)[:] {
            "nth-child" | "nth-of-type" | "not" | "comment" => true
            "contains" => !arg.trim().is_empty()
            _ => false
          }
        None => false
      }
  }
}

///|
fn pseudo_selector_matches_with_context(
  node : @dom.Node,
  name : StringView,
  context : SelectorMatchContext,
  depth : Int,
) -> Bool raise @core.HtmlError {
  let lower_name = @syn.lower_ascii(name)
  match lower_name[:] {
    "comment" => node.kind == Comment
    "first-child" => is_first_element_child(node)
    "last-child" => is_last_element_child(node)
    "only-child" => is_only_element_child(node)
    "empty" => is_empty_for_selector(node)
    "root" => is_root_for_selector(node)
    "first-of-type" => is_first_of_type(node)
    "last-of-type" => is_last_of_type(node)
    "only-of-type" => is_only_of_type(node)
    _ =>
      match functional_pseudo_parts(name) {
        Some((pseudo_name, arg)) =>
          match @syn.lower_ascii(pseudo_name)[:] {
            "nth-child" => is_nth_child(node, arg)
            "nth-of-type" => is_nth_of_type(node, arg)
            "not" =>
              !matches_selector_list_with_context(node, arg, context, depth + 1)
            "contains" => contains_text(node, arg)
            "comment" => node.kind == Comment
            _ => false
          }
        _ => false
      }
  }
}
