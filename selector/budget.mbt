///|
fn selector_uses_byte_scanned_match(selector : StringView) -> Bool {
  string_view_contains(selector, "*=") ||
  string_view_contains(@syn.lower_ascii(selector), ":contains")
}

///|
fn selector_match_byte_cost(node : @dom.Node, include_text : Bool) -> Int {
  let mut cost = 0
  for _, value in node.attrs {
    match value {
      Some(raw) => cost += raw.length()
      None => ()
    }
  }
  if include_text {
    cost += selector_text_content(node).length()
  }
  cost
}

///|
fn selector_check_match_budget(
  node : @dom.Node,
  selector : StringView,
  limits : SelectorLimits,
) -> Unit raise @core.HtmlError {
  if limits.max_match_bytes < 0 {
    raise SelectorError("Selector match byte budget exceeded")
  }
  if selector_uses_byte_scanned_match(selector) {
    let include_text = string_view_contains(
      @syn.lower_ascii(selector),
      ":contains",
    )
    if selector_match_byte_cost(node, include_text) > limits.max_match_bytes {
      raise SelectorError("Selector match byte budget exceeded")
    }
  }
}

///|
priv struct SelectorMatchContext {
  limits : SelectorLimits
  mut remaining_steps : Int
}

///|
fn SelectorMatchContext::SelectorMatchContext(
  limits : SelectorLimits,
) -> SelectorMatchContext {
  { limits, remaining_steps: limits.max_match_steps }
}

///|
fn SelectorMatchContext::tick(
  self : SelectorMatchContext,
  steps? : Int = 1,
) -> Unit raise @core.HtmlError {
  if steps <= 0 {
    return
  }
  self.remaining_steps -= steps
  if self.remaining_steps < 0 {
    raise SelectorError("Selector match budget exceeded")
  }
}
