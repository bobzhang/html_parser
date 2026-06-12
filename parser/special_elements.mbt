///|
fn is_special_element_for_any_other_end_tag(name : StringView) -> Bool {
  match name {
    "address"
    | "applet"
    | "area"
    | "article"
    | "aside"
    | "base"
    | "basefont"
    | "bgsound"
    | "blockquote"
    | "body"
    | "br"
    | "button"
    | "caption"
    | "center"
    | "col"
    | "colgroup"
    | "dd"
    | "details"
    | "dialog"
    | "dir"
    | "div"
    | "dl"
    | "dt"
    | "embed"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "frame"
    | "frameset"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "head"
    | "header"
    | "hgroup"
    | "hr"
    | "html"
    | "iframe"
    | "img"
    | "input"
    | "keygen"
    | "li"
    | "link"
    | "listing"
    | "main"
    | "marquee"
    | "menu"
    | "menuitem"
    | "meta"
    | "nav"
    | "noembed"
    | "noframes"
    | "noscript"
    | "object"
    | "ol"
    | "p"
    | "param"
    | "plaintext"
    | "pre"
    | "script"
    | "search"
    | "section"
    | "select"
    | "source"
    | "style"
    | "summary"
    | "table"
    | "tbody"
    | "td"
    | "template"
    | "textarea"
    | "tfoot"
    | "th"
    | "thead"
    | "title"
    | "tr"
    | "track"
    | "ul"
    | "wbr" => true
    _ => false
  }
}

///|
fn Parser::close_ruby_end_tag(self : Parser, start : Int) -> Unit {
  let mut index = self.stack.length()
  while index > 1 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && node.name == "ruby" {
      if index != self.stack.length() - 1 {
        self.error_at("end-tag-too-early", start)
      }
      while self.stack.length() > index {
        ignore(self.pop_open_element())
      }
      return
    }
    if node.kind == Element &&
      is_special_element_for_any_other_end_tag(node.name) {
      self.error_at("unexpected-end-tag", start)
      return
    }
  }
  self.error_at("unexpected-end-tag", start)
}
