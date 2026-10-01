///|
/// Per-node facts the pretty printer needs about whole subtrees, computed once
/// up front so each element's layout decision is constant time.
///
/// Nodes are numbered in preorder over `serialized_children`, so a node's
/// first child is at `index + 1` and each next sibling follows the previous
/// sibling's subtree (`sizes`).
priv struct PrettyIndex {
  /// Number of nodes in each subtree, the node included.
  sizes : Array[Int]
  /// Whether the subtree holds a layout-block element (the node included).
  contains_layout_block : Array[Bool]
  /// For documents and fragments: whether pretty printing emits any line.
  /// Unused for other kinds.
  fragment_has_line : Array[Bool]
}

///|
fn PrettyIndex::new(root : @dom.Node) -> PrettyIndex {
  let nodes : Array[@dom.Node] = []
  let parents : Array[Int] = []
  let stack : Array[(@dom.Node, Int)] = [(root, -1)]
  while stack.pop() is Some((node, parent)) {
    let index = nodes.length()
    nodes.push(node)
    parents.push(parent)
    let children = serialized_children(node)
    for i = children.length() - 1; i >= 0; i = i - 1 {
      stack.push((children[i], index))
    }
  }
  let count = nodes.length()
  let sizes = Array::make(count, 1)
  let contains_layout_block = Array::makei(count, index => {
    let node = nodes[index]
    node.kind == Element && layout_block_element_name(node.name)
  })
  let fragment_has_line = Array::make(count, false)
  // Reverse preorder visits every descendant before its ancestor, so each
  // child's facts are final by the time they are folded into its parent.
  for index = count - 1; index > 0; index = index - 1 {
    let parent = parents[index]
    sizes[parent] += sizes[index]
    if contains_layout_block[index] {
      contains_layout_block[parent] = true
    }
    if nodes[parent].kind is (Document | Fragment) && !fragment_has_line[parent] {
      let node = nodes[index]
      let has_line = match node.kind {
        Text => pretty_text_line(node, 0) is Some(_)
        Document | Fragment => fragment_has_line[index]
        _ => true
      }
      if has_line {
        fragment_has_line[parent] = true
      }
    }
  }
  { sizes, contains_layout_block, fragment_has_line, }
}

///|
/// Return the preorder indices of `node`'s serialized children, given the
/// node's own `index`.
fn PrettyIndex::child_indices(
  self : PrettyIndex,
  node : @dom.Node,
  index : Int,
) -> Array[Int] {
  let indices : Array[Int] = []
  let mut child_index = index + 1
  for _ in serialized_children(node) {
    indices.push(child_index)
    child_index += self.sizes[child_index]
  }
  indices
}

///|
/// Whether a child emits a line of its own when pretty printed in a line
/// context (a block element's or a fragment's children).
fn PrettyIndex::child_has_line(
  self : PrettyIndex,
  node : @dom.Node,
  index : Int,
) -> Bool {
  match node.kind {
    Text => pretty_text_line(node, 0) is Some(_)
    Document | Fragment => self.fragment_has_line[index]
    _ => true
  }
}

///|
/// A text node's pretty-printed line: formatting whitespace normalized and
/// trimmed, escaped, and indented. `None` when nothing visible remains.
fn pretty_text_line(node : @dom.Node, indent : Int) -> String? {
  if node.sanitize_escape_only {
    return None
  }
  let normalized = normalize_formatting_whitespace(node.data)
  let trimmed = normalized[:].trim()
  if trimmed.is_empty() {
    None
  } else {
    Some(" ".repeat(indent) + escape_text(trimmed))
  }
}

///|
fn element_has_only_text_children(node : @dom.Node) -> Bool {
  if serialized_children(node).is_empty() {
    return false
  }
  for child in serialized_children(node) {
    if child.kind != Text {
      return false
    }
  }
  true
}

///|
/// Serialize the children of an element whose children are all text nodes.
fn compact_pretty_text_children(node : @dom.Node) -> String {
  let out = StringBuilder()
  if raw_text_element(node) {
    let raw = StringBuilder()
    for child in serialized_children(node) {
      if !child.sanitize_escape_only {
        raw.write_string(child.data)
      }
    }
    out.write_string(raw_text_payload(raw.to_string(), node.name))
  } else if pretty_text_preserves_whitespace(node) {
    for child in serialized_children(node) {
      out.write_string(compact_text_html(child))
    }
  } else {
    let raw = StringBuilder()
    for child in serialized_children(node) {
      if !child.sanitize_escape_only {
        raw.write_string(child.data)
      }
    }
    out.write_string(escape_text(collapse_html_whitespace(raw.to_string())))
  }
  out.to_string()
}

///|
fn PrettyIndex::element_has_compact_inline_children(
  self : PrettyIndex,
  node : @dom.Node,
  index : Int,
) -> Bool {
  let mut has_visible_text = false
  let mut has_inline_element = false
  let mut child_index = index + 1
  for child in serialized_children(node) {
    match child.kind {
      Text => if text_has_visible_char(child.data) { has_visible_text = true }
      Element => {
        if !inline_pretty_element_name(child.name) ||
          self.contains_layout_block[child_index] {
          return false
        }
        has_inline_element = true
      }
      _ => return false
    }
    child_index += self.sizes[child_index]
  }
  has_visible_text ||
  (has_inline_element && !layout_block_element_name(node.name))
}

///|
fn element_has_comment_child(node : @dom.Node) -> Bool {
  for child in serialized_children(node) {
    if child.kind == Comment {
      return true
    }
  }
  false
}

///|
fn node_is_pretty_formatting_separator(node : @dom.Node) -> Bool {
  node.kind == Text &&
  !text_has_visible_char(node.data) &&
  compact_pretty_whitespace_separator(node.data)
}

///|
/// How a text node inside an inline run is written.
fn pretty_inline_run_text(node : @dom.Node) -> String {
  if node.sanitize_escape_only {
    return ""
  }
  let data = node.data[:]
  if text_has_visible_char(data) {
    escape_text(normalize_formatting_whitespace(data))
  } else {
    escape_text(data)
  }
}

///|
/// Pretty-print a layout block whose inline children are separated by
/// formatting whitespace: each run goes on its own indented line.
///
/// Returns `false`, having scheduled nothing, when the element does not have
/// that shape. Only called for elements with at least one non-text child.
fn HtmlWriter::pretty_inline_runs(
  self : HtmlWriter,
  node : @dom.Node,
  compact_inline : Bool,
  indent : Int,
) -> Bool raise @core.HtmlError {
  if !layout_block_element_name(node.name) || !compact_inline {
    return false
  }
  let runs : Array[Array[@dom.Node]] = []
  let mut current : Array[@dom.Node] = []
  let mut saw_separator = false
  for child in serialized_children(node) {
    if node_is_pretty_formatting_separator(child) {
      saw_separator = true
      if !current.is_empty() {
        runs.push(current)
        current = []
      }
    } else {
      current.push(child)
    }
  }
  if !current.is_empty() {
    runs.push(current)
  }
  if !saw_separator || runs.is_empty() {
    return false
  }
  let indent_text = " ".repeat(indent)
  let start_tag = serialize_start_tag(node, self.quote)
  let child_prefix = " ".repeat(indent + self.indent_size)
  // Compact inline children are only text and inline elements, and an
  // element always serializes to something, so a run renders empty exactly
  // when all its text renders empty.
  let tasks : Array[HtmlTask] = []
  for run in runs {
    let run_tasks : Array[HtmlTask] = []
    let mut empty = true
    for child in run {
      match child.kind {
        Text => {
          let text = pretty_inline_run_text(child)
          if !text.is_empty() {
            empty = false
            run_tasks.push(Write(text))
          }
        }
        _ => {
          empty = false
          run_tasks.push(Compact(child))
        }
      }
    }
    if !empty {
      tasks.push(Write("\n\{child_prefix}"))
      tasks.append(run_tasks)
    }
  }
  // Callers only get here for an element with a non-text child, and compact
  // inline children are text or elements, so at least one run holds an
  // element and `tasks` is not empty.
  self.write("\{indent_text}\{start_tag}")
  tasks.push(Write("\n\{indent_text}</\{node.name}>"))
  self.push_in_order(tasks)
  true
}

///|
/// Pretty-print an element on one line: its start tag, its children with
/// formatting whitespace normalized, and its end tag.
fn HtmlWriter::pretty_compact_children(
  self : HtmlWriter,
  pretty_index : PrettyIndex,
  node : @dom.Node,
  index : Int,
) -> Unit raise @core.HtmlError {
  self.write(serialize_start_tag(node, self.quote))
  let children = serialized_children(node)
  let child_indices = pretty_index.child_indices(node, index)
  let child_count = children.length()
  let tasks : Array[HtmlTask] = []
  for position in 0..<child_count {
    let child = children[position]
    match child.kind {
      Text => {
        if child.sanitize_escape_only {
          continue
        }
        let data = child.data[:]
        let has_visible = text_has_visible_char(data)
        if !has_visible && (position == 0 || position + 1 == child_count) {
          ()
        } else if !has_visible && compact_pretty_whitespace_separator(data) {
          tasks.push(Write(" "))
        } else {
          let normalized = normalize_formatting_whitespace(data)
          tasks.push(Write(escape_text(normalized)))
        }
      }
      Document | Fragment =>
        tasks.push(Pretty(child, index=child_indices[position], indent=0))
      _ => tasks.push(Compact(child))
    }
  }
  tasks.push(Write("</\{node.name}>"))
  self.push_in_order(tasks)
}

///|
fn HtmlWriter::pretty(
  self : HtmlWriter,
  node : @dom.Node,
  index : Int,
  indent : Int,
) -> Unit raise @core.HtmlError {
  // `Pretty` tasks are only scheduled by a writer built with `pretty=true`.
  let pretty_index = self.pretty_index.unwrap()
  match node.kind {
    Document | Fragment => {
      let child_indices = pretty_index.child_indices(node, index)
      let tasks : Array[HtmlTask] = []
      for position, child in serialized_children(node) {
        let child_index = child_indices[position]
        if pretty_index.child_has_line(child, child_index) {
          if !tasks.is_empty() {
            tasks.push(Write("\n"))
          }
          tasks.push(Pretty(child, index=child_index, indent~))
        }
      }
      self.push_in_order(tasks)
    }
    Text => if pretty_text_line(node, indent) is Some(line) { self.write(line) }
    Comment | Doctype => {
      self.write(" ".repeat(indent))
      self.compact(node)
    }
    Element => {
      let compact_inline = pretty_index.element_has_compact_inline_children(
        node, index,
      )
      if serialized_children(node).is_empty() ||
        is_void_element(node.name) ||
        pretty_text_preserves_whitespace(node) {
        self.write(" ".repeat(indent))
        self.tasks.push(Compact(node))
      } else if element_has_only_text_children(node) {
        let indent_text = " ".repeat(indent)
        let start_tag = serialize_start_tag(node, self.quote)
        let children = compact_pretty_text_children(node)
        self.out() <+ "\{indent_text}\{start_tag}\{children}</\{node.name}>"
      } else if self.pretty_inline_runs(node, compact_inline, indent) {
        ()
      } else if compact_inline || element_has_comment_child(node) {
        self.write(" ".repeat(indent))
        self.pretty_compact_children(pretty_index, node, index)
      } else {
        let indent_text = " ".repeat(indent)
        let start_tag = serialize_start_tag(node, self.quote)
        let child_indent = indent + self.indent_size
        let child_indices = pretty_index.child_indices(node, index)
        let tasks : Array[HtmlTask] = []
        for position, child in serialized_children(node) {
          let child_index = child_indices[position]
          if pretty_index.child_has_line(child, child_index) {
            tasks.push(Write("\n"))
            tasks.push(Pretty(child, index=child_index, indent=child_indent))
          }
        }
        if tasks.is_empty() {
          self.write(" ".repeat(indent))
          self.pretty_compact_children(pretty_index, node, index)
        } else {
          self.write("\{indent_text}\{start_tag}")
          tasks.push(Write("\n\{indent_text}</\{node.name}>"))
          self.push_in_order(tasks)
        }
      }
    }
  }
}
