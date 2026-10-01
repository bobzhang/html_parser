///|
/// One unit of pending work for the Markdown walker.
///
/// The walker keeps an explicit work stack instead of recursing once per
/// nesting level, so arbitrarily deep DOM trees cannot overflow the native
/// call stack. `Walk` and `LinkText` visit a node (in normal Markdown mode and
/// in link-text mode respectively); the `Finish*` tasks are the "on exit"
/// continuations of constructs that render their children into a nested
/// `MarkdownBuilder` and post-process the rendered inner output.
priv enum MarkdownTask {
  /// Render a node in normal Markdown mode at the given list depth.
  Walk(@dom.Node, Int)
  /// Render a node inside link text (`[...]`).
  LinkText(@dom.Node)
  /// Render one `<li>` of a Markdown list: the list item node, whether the
  /// list is ordered, its 1-based index, whether it is the first rendered
  /// item, and the list depth of the enclosing list.
  ListItem(@dom.Node, Bool, Int, Bool, Int)
  /// Render one `<li>` of a list flattened into link text.
  LinkListItem(@dom.Node)
  /// `ensure_newlines(count)` on the current builder.
  EnsureNewlines(Int)
  /// Emit a collapsible space (`text(" ")`) on the current builder.
  SpaceText
  /// Close the nested builder of an emphasis/strong element. The opening
  /// marker was already written to the parent speculatively; the snapshot
  /// restores the parent when the trimmed inner output is empty.
  FinishWrapped(String, MarkdownSnapshot)
  /// Close the nested builder of a heading (its prefix is already written).
  FinishHeading
  /// Close the nested builder of a blockquote. The separating newlines and
  /// `QuoteOpen` were already written to the parent speculatively; the
  /// snapshot restores the parent when the trimmed inner output is empty.
  FinishBlockquote(MarkdownSnapshot)
  /// Close the nested builder of this link's text (`[` is already written).
  FinishLink(@dom.Node)
}

///|
priv struct MarkdownWalker {
  tasks : Array[MarkdownTask]
  /// Builder stack; the last builder receives output. The first builder is
  /// the root output and is never popped. Nested builders share the root's
  /// parts array (see `MarkdownBuilder::nested`).
  builders : Array[MarkdownBuilder]
  html_passthrough : Bool
}

///|
fn markdown_render(
  node : @dom.Node,
  html_passthrough : Bool,
) -> String raise @core.HtmlError {
  let root = MarkdownBuilder()
  let walker : MarkdownWalker = {
    tasks: [Walk(node, 0)],
    builders: [root],
    html_passthrough,
  }
  while walker.tasks.pop() is Some(task) {
    walker.step(task)
  }
  root.finish()
}

///|
fn MarkdownWalker::current(self : MarkdownWalker) -> MarkdownBuilder {
  self.builders[self.builders.length() - 1]
}

///|
/// Push `finish` and start rendering into a fresh nested builder. The caller
/// schedules the children afterwards, so `finish` runs once they are done.
fn MarkdownWalker::open_builder(
  self : MarkdownWalker,
  finish : MarkdownTask,
) -> Unit {
  self.tasks.push(finish)
  self.builders.push(self.current().nested())
}

///|
fn MarkdownWalker::close_builder(self : MarkdownWalker) -> MarkdownBuilder {
  guard self.builders.pop() is Some(builder) else {
    abort("markdown builder stack underflow")
  }
  builder
}

///|
/// Open a nested builder whose trimmed output is wrapped in `marker`.
///
/// The recursive formulation wrote `marker`, the inner string and `marker`
/// to the parent only once the inner string was known to be non-empty. The
/// parent is untouched while the children render, so the opening marker is
/// written up front instead and rolled back if the output ends up empty;
/// this lets the inner parts stay in place rather than being copied.
fn MarkdownWalker::open_wrapped(self : MarkdownWalker, marker : String) -> Unit {
  let parent = self.current()
  let finish = FinishWrapped(marker, parent.snapshot())
  parent.raw(marker)
  self.open_builder(finish)
}

///|
/// Open a nested builder for a blockquote body.
///
/// The recursive formulation rendered the body to a string, prefixed each of
/// its lines with `> `, and then wrote blank-line separators and the quoted
/// string to the parent, all only when the body was non-empty. Here the
/// leading separator and a `QuoteOpen` marker are written up front and rolled
/// back if the body ends up empty; the prefixes are applied by `finish`.
fn MarkdownWalker::open_blockquote(self : MarkdownWalker) -> Unit {
  let parent = self.current()
  let finish = FinishBlockquote(parent.snapshot())
  parent.ensure_newlines(2)
  parent.parts.push(QuoteOpen)
  self.open_builder(finish)
}

///|
/// Schedule `children` in document order in normal Markdown mode.
fn MarkdownWalker::push_children(
  self : MarkdownWalker,
  children : Array[@dom.Node],
  list_depth : Int,
) -> Unit {
  for index = children.length() - 1; index >= 0; index = index - 1 {
    self.tasks.push(Walk(children[index], list_depth))
  }
}

///|
/// Schedule `children` in document order in link-text mode.
fn MarkdownWalker::push_link_children(
  self : MarkdownWalker,
  children : Array[@dom.Node],
) -> Unit {
  for index = children.length() - 1; index >= 0; index = index - 1 {
    self.tasks.push(LinkText(children[index]))
  }
}

///|
fn MarkdownWalker::step(
  self : MarkdownWalker,
  task : MarkdownTask,
) -> Unit raise @core.HtmlError {
  match task {
    Walk(node, list_depth) => self.walk(node, list_depth)
    LinkText(node) => self.walk_link_text(node)
    ListItem(item, ordered, index, first, list_depth) => {
      let builder = self.current()
      if !first {
        builder.newline(1)
      }
      builder.raw("  ".repeat(list_depth))
      if ordered {
        builder.raw(index.to_string())
        builder.raw(". ")
      } else {
        builder.raw("- ")
      }
      self.push_children(markdown_children(item), list_depth + 1)
    }
    LinkListItem(item) => {
      self.current().raw(" ")
      self.push_link_children(item.children)
    }
    EnsureNewlines(count) => self.current().ensure_newlines(count)
    SpaceText => self.current().text(" ")
    // Adopting a trimmed, non-empty inner output in place is what `raw` of
    // the inner string did: it ends with non-whitespace, so the parent is
    // left with no newline run and no pending space. The prefix written
    // before the children (a marker, `# `, `[` or a blank line) already put
    // the parent in that state.
    FinishWrapped(marker, snapshot) => {
      let inner = self.close_builder()
      let parent = self.current()
      if inner.trim_in_place() {
        parent.raw(marker)
      } else {
        parent.restore(snapshot)
      }
    }
    FinishHeading => {
      ignore(self.close_builder().trim_in_place())
      self.current().ensure_newlines(2)
    }
    FinishBlockquote(snapshot) => {
      let inner = self.close_builder()
      let parent = self.current()
      if inner.trim_in_place() {
        parent.parts.push(QuoteClose)
        parent.newline_count = 0
        parent.pending_space = false
        parent.ensure_newlines(2)
      } else {
        parent.restore(snapshot)
      }
    }
    FinishLink(link) => {
      ignore(self.close_builder().trim_in_place())
      markdown_emit_link_tail(link, self.current())
    }
  }
}

///|
fn markdown_heading_level(name : StringView) -> Int {
  match name {
    "h1" => 1
    "h2" => 2
    "h3" => 3
    "h4" => 4
    "h5" => 5
    "h6" => 6
    _ => 0
  }
}

///|
fn markdown_block_container_name(name : StringView) -> Bool {
  match name {
    "div"
    | "section"
    | "article"
    | "header"
    | "footer"
    | "main"
    | "nav"
    | "aside"
    | "li" => true
    _ => false
  }
}

///|
/// Visit `node` in normal Markdown mode. Children are scheduled on the work
/// stack rather than rendered recursively.
fn MarkdownWalker::walk(
  self : MarkdownWalker,
  node : @dom.Node,
  list_depth : Int,
) -> Unit raise @core.HtmlError {
  let builder = self.current()
  match node.kind {
    Text =>
      if !node.sanitize_escape_only {
        builder.text(markdown_escape_text(node.data))
      }
    Comment | Doctype => ()
    Document | Fragment =>
      self.push_children(markdown_children(node), list_depth)
    Element => {
      let tag = node.name.to_lower()
      let level = markdown_heading_level(tag)
      if markdown_should_skip_head_or_title(node, tag) {
        ()
      } else if level > 0 {
        // The heading prefix is unconditional and the parent is untouched
        // while the children render, so it is written before them.
        builder.ensure_newlines(2)
        builder.raw("#".repeat(level))
        builder.raw(" ")
        self.open_builder(FinishHeading)
        self.push_children(markdown_children(node), list_depth)
      } else {
        match tag {
          "html" | "body" | "span" =>
            self.push_children(markdown_children(node), list_depth)
          "p" => {
            builder.ensure_newlines(2)
            self.tasks.push(EnsureNewlines(2))
            self.push_children(markdown_children(node), list_depth)
          }
          "br" => builder.newline(1)
          "b" | "strong" => {
            self.open_wrapped("**")
            self.push_children(markdown_children(node), list_depth)
          }
          "i" | "em" => {
            self.open_wrapped("*")
            self.push_children(markdown_children(node), list_depth)
          }
          "code" => builder.raw(markdown_code_span(markdown_collect_text(node)))
          "pre" => markdown_walk_pre(node, builder)
          "a" => {
            builder.raw("[")
            self.open_builder(FinishLink(node))
            self.push_link_children(markdown_children(node))
          }
          "ul" => self.start_list(node, builder, false, list_depth)
          "ol" => self.start_list(node, builder, true, list_depth)
          "blockquote" => {
            self.open_blockquote()
            self.push_children(markdown_children(node), list_depth)
          }
          "hr" => {
            builder.ensure_newlines(2)
            builder.raw("---")
            builder.ensure_newlines(2)
          }
          "script" | "style" | "textarea" => {
            builder.ensure_newlines(2)
            if self.html_passthrough {
              builder.raw(@ser.to_html(node, pretty=false))
            }
            builder.ensure_newlines(2)
          }
          "img" => builder.raw(@ser.to_html(node, pretty=false))
          "table" => {
            builder.ensure_newlines(2)
            builder.raw(@ser.to_html(node, pretty=false))
            builder.ensure_newlines(2)
          }
          _ => {
            if markdown_block_container_name(tag) {
              self.tasks.push(EnsureNewlines(2))
            }
            self.push_children(markdown_children(node), list_depth)
          }
        }
      }
    }
  }
}

///|
fn markdown_should_skip_head_or_title(
  node : @dom.Node,
  tag : StringView,
) -> Bool {
  match tag {
    "head" | "title" =>
      !(node.parsed_from_source && markdown_node_inside_fragment(node))
    _ => false
  }
}

///|
fn markdown_node_inside_fragment(node : @dom.Node) -> Bool {
  let mut current = node
  while true {
    match current.parent {
      Some(parent) => current = parent
      None => return current.kind == Fragment
    }
  }
  false
}
