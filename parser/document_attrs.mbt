///|
fn merge_missing_attrs(target : @dom.Node, source : @dom.Node) -> Unit {
  merge_missing_attrs_from_map(target, source.attrs)
}

///|
fn merge_missing_attrs_into_map(
  target : Map[String, String?],
  attrs : Map[String, String?],
) -> Unit {
  for name, value in attrs {
    if !target.contains(name) {
      target[name] = value
    }
  }
}

///|
fn merge_missing_attrs_from_map(
  target : @dom.Node,
  attrs : Map[String, String?],
) -> Unit {
  for name, value in attrs {
    if !target.attrs.contains(name) {
      target.attrs[name] = value
    }
  }
}

///|
fn Parser::merge_document_html_attrs(
  self : Parser,
  attrs : Map[String, String?],
) -> Unit {
  match self.open_html_element() {
    Some(html) => merge_missing_attrs_from_map(html, attrs)
    None =>
      merge_missing_attrs_into_map(self.pending_document_html_attrs, attrs)
  }
}

///|
fn Parser::apply_pending_document_html_attrs(self : Parser) -> Unit {
  if self.pending_document_html_attrs.length() == 0 {
    return
  }
  match document_html_element(self.root) {
    Some(html) =>
      merge_missing_attrs_from_map(html, self.pending_document_html_attrs)
    None => ()
  }
}
