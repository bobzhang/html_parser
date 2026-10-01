// Whitebox regressions for deeply nested trees and for the cheaper identity
// checks used by `query`, descendant combinators, and selector text: each is
// compared against the original visited-list algorithm on random trees with
// shared, cyclic, and inconsistently parented nodes.

///|
fn reference_walk_query(
  node : @dom.Node,
  selector : StringView,
  out : Array[@dom.Node],
  allow_non_elements : Bool,
  visited : Array[@dom.Node],
) -> Unit {
  if node_identity_seen(visited, node) {
    return
  }
  visited.push(node)
  if (allow_non_elements || node.kind == Element) &&
    matches_selector_list(node, selector) {
    out.push(node)
  }
  match node.template_contents {
    Some(contents) =>
      for child in contents.children {
        reference_walk_query(child, selector, out, allow_non_elements, visited)
      }
    None => ()
  }
  for child in node.children {
    reference_walk_query(child, selector, out, allow_non_elements, visited)
  }
}

///|
fn reference_query(root : @dom.Node, selector : StringView) -> Array[@dom.Node] {
  let out : Array[@dom.Node] = []
  let allow_non_elements = selector_allows_non_elements(selector)
  let visited : Array[@dom.Node] = [root]
  match root.template_contents {
    Some(contents) =>
      for child in contents.children {
        reference_walk_query(child, selector, out, allow_non_elements, visited)
      }
    None => ()
  }
  for child in root.children {
    reference_walk_query(child, selector, out, allow_non_elements, visited)
  }
  out
}

///|
/// `selector_text_content` as it was before the regular-tree fast path,
/// copied verbatim from origin/main (only renamed).
fn reference_text_content(node : @dom.Node) -> String {
  let cache_nodes : Array[@dom.Node] = []
  let cache_texts : Array[String] = []
  let visiting : Array[@dom.Node] = []
  let stack : Array[(@dom.Node, Bool)] = [(node, false)]
  while !stack.is_empty() {
    let (current, visited) = stack[stack.length() - 1]
    ignore(stack.pop())
    if node_text_cache_get(cache_nodes, cache_texts, current) is Some(_) {
      continue
    }
    if visited {
      remove_node_identity(visiting, current)
      if current.kind == Text {
        node_text_cache_set(
          cache_nodes,
          cache_texts,
          current,
          current.data[:].trim().to_owned(),
        )
      } else {
        let parts : Array[String] = []
        match current.template_contents {
          Some(contents) =>
            match node_text_cache_get(cache_nodes, cache_texts, contents) {
              Some(text) if text != "" => parts.push(text)
              _ => ()
            }
          None => ()
        }
        for child in current.children {
          match node_text_cache_get(cache_nodes, cache_texts, child) {
            Some(text) if text != "" => parts.push(text)
            _ => ()
          }
        }
        node_text_cache_set(cache_nodes, cache_texts, current, parts.join(" "))
      }
    } else if node_identity_seen(visiting, current) {
      node_text_cache_set(cache_nodes, cache_texts, current, "")
    } else {
      visiting.push(current)
      stack.push((current, true))
      let mut index = current.children.length()
      while index > 0 {
        index -= 1
        stack.push((current.children[index], false))
      }
      match current.template_contents {
        Some(contents) => stack.push((contents, false))
        None => ()
      }
    }
  }
  node_text_cache_get(cache_nodes, cache_texts, node).unwrap_or("")
}

///|
priv struct DeepTestRng {
  mut state : UInt64
}

///|
fn DeepTestRng::below(self : DeepTestRng, bound : Int) -> Int {
  self.state = self.state * 6364136223846793005UL + 1442695040888963407UL
  ((self.state >> 33).to_int() & 0x7fffffff) % bound
}

///|
fn random_selector_graph(rng : DeepTestRng) -> Array[@dom.Node] {
  let names = ["div", "b", "p", "a", "template"]
  let count = 1 + rng.below(12)
  let nodes : Array[@dom.Node] = []
  for i in 0..<count {
    let node = match rng.below(8) {
      0 => @dom.text(if rng.below(2) == 0 { " x " } else { "y" })
      1 => @dom.comment("c")
      2 => @dom.fragment()
      _ => @dom.element(names[rng.below(names.length())])
    }
    if i > 0 {
      nodes[rng.below(i)].append_child(node)
    }
    nodes.push(node)
  }
  let mutations = rng.below(5)
  for _ in 0..<mutations {
    let a = nodes[rng.below(count)]
    let b = nodes[rng.below(count)]
    match rng.below(6) {
      0 => a.children.push(b)
      1 => b.parent = Some(a)
      2 => b.parent = None
      3 => a.template_contents = Some(b)
      4 => {
        let contents = @dom.fragment()
        contents.parent = Some(a)
        a.template_contents = Some(contents)
        if !physical_equal(a, b) {
          contents.children.push(b)
          if rng.below(2) == 0 {
            b.parent = Some(contents)
          }
        }
      }
      _ => a.children.insert(0, b)
    }
  }
  nodes
}

///|
fn assert_same_nodes(
  actual : Array[@dom.Node],
  expected : Array[@dom.Node],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i, node in actual {
    assert_true(physical_equal(node, expected[i]))
  }
}

///|
test "query identity fast path matches the visited-list walk" {
  let rng = DeepTestRng::{ state: 42UL, }
  let selectors = [
    "*", "div", "div b", "b > a", "p ~ a", ":comment", "div, :comment", "template a",
  ]
  for _ in 0..<3000 {
    let nodes = random_selector_graph(rng)
    let root = nodes[rng.below(nodes.length())]
    for selector in selectors {
      assert_same_nodes(query(root, selector), reference_query(root, selector))
    }
  }
}

///|
test "ancestor repeat guard matches the visited-list scan" {
  let rng = DeepTestRng::{ state: 7UL, }
  for _ in 0..<3000 {
    let nodes = random_selector_graph(rng)
    for start in nodes {
      let guard_ = AncestorRepeatGuard::new(start)
      let visited = [start]
      let mut cursor = start.parent
      let mut index = 1
      while cursor is Some(ancestor) {
        let expected = node_identity_seen(visited, ancestor)
        assert_eq(guard_.repeats_at(index), expected)
        if expected {
          break
        }
        visited.push(ancestor)
        cursor = ancestor.parent
        index += 1
      }
    }
  }
  // Chains with a tail of `tail` nodes leading into a cycle of `cycle` nodes.
  for tail in 0..<24 {
    for cycle in 1..<24 {
      let chain = Array::makei(tail + cycle, _ => @dom.element("div"))
      for i in 0..<(tail + cycle - 1) {
        chain[i].parent = Some(chain[i + 1])
      }
      chain[tail + cycle - 1].parent = Some(chain[tail])
      let guard_ = AncestorRepeatGuard::new(chain[0])
      for index in 1..<(tail + cycle) {
        assert_eq(guard_.repeats_at(index), false)
      }
      assert_eq(guard_.repeats_at(tail + cycle), true)
    }
  }
}

///|
/// A random tree in which every node is reached exactly once: children and
/// template contents get matching `parent` links, text nodes may also carry
/// children (which text collection must not descend into), and text data
/// includes empty and whitespace-only strings.
fn random_regular_text_tree(rng : DeepTestRng) -> Array[@dom.Node] {
  let texts = ["", " ", "\n\t ", "a", " b c ", "  d", "e\n"]
  let count = 1 + rng.below(40)
  let nodes : Array[@dom.Node] = []
  for i in 0..<count {
    let node = match rng.below(6) {
      0 | 1 => @dom.text(texts[rng.below(texts.length())])
      2 => @dom.comment("c")
      3 => @dom.fragment()
      _ => @dom.element(if rng.below(4) == 0 { "template" } else { "div" })
    }
    if i > 0 {
      let parent = nodes[rng.below(i)]
      if rng.below(5) == 0 && parent.template_contents is None {
        // Wrap `node` in a contents fragment owned by `parent`.
        let contents = @dom.fragment()
        contents.parent = Some(parent)
        parent.template_contents = Some(contents)
        contents.children.push(node)
        node.parent = Some(contents)
      } else {
        parent.children.push(node)
        node.parent = Some(parent)
      }
    }
    nodes.push(node)
  }
  nodes
}

///|
test "selector text fast path matches the original algorithm" {
  let rng = DeepTestRng::{ state: 99UL, }
  for _ in 0..<3000 {
    let nodes = random_selector_graph(rng)
    for node in nodes {
      let expected = reference_text_content(node)
      assert_eq(selector_text_content(node), expected)
      assert_eq(general_text_content(node), expected)
    }
  }
  for _ in 0..<2000 {
    let nodes = random_regular_text_tree(rng)
    for node in nodes {
      assert_true(text_walk_is_regular(node))
      let expected = reference_text_content(node)
      assert_eq(regular_text_content(node), expected)
      assert_eq(selector_text_content(node), expected)
    }
  }
}

///|
test "selector text collects a deep branching chain in linear time" {
  // Each element holds a text child and then the next element. Joining text
  // per level would copy the growing suffix at every level (quadratic in the
  // depth); at this depth that would be prohibitively slow.
  let depth = 50000
  let mut current = @dom.element("b", children=[@dom.text(" x ")])
  for _ in 1..<depth {
    current = @dom.element("b", children=[@dom.text(" x "), current])
  }
  let root = @dom.element("div", children=[@dom.text("  "), current])
  let text = selector_text_content(root)
  assert_eq(text.length(), 2 * depth - 1)
  assert_true(text.has_prefix("x x "))
  assert_true(text.has_suffix(" x x"))
  assert_true(matches(root, "div:contains('x x x')"))
  // A shallow prefix of the same shape still agrees with the original.
  let mut shallow = @dom.element("b", children=[@dom.text(" x ")])
  for i in 0..<200 {
    shallow = @dom.element("b", children=[
      @dom.text(if i % 3 == 0 { " " } else { " y\n" }),
      shallow,
    ])
  }
  assert_eq(selector_text_content(shallow), reference_text_content(shallow))
}

///|
test "selectors survive deeply nested trees" {
  let depth = 30000
  let link = @dom.element("a", attrs={ "href": Some("http://e.com") }, children=[
    @dom.text("l"),
  ])
  let mut current = @dom.element("p", children=[
    @dom.text("x "),
    link,
    @dom.comment("c"),
  ])
  for i in 0..<depth {
    current = @dom.element(if i % 2 == 0 { "b" } else { "div" }, children=[
      current,
    ])
  }
  let html = @dom.element("html", children=[
    @dom.element("body", children=[current]),
  ])
  let doc = @dom.document(children=[html])
  assert_eq(query(doc, "*").length(), depth + 4)
  assert_eq(query(doc, "div b a").length(), 1)
  assert_eq(query(doc, "html a").length(), 1)
  assert_eq(query(doc, ":comment").length(), 1)
  assert_eq(query(doc, "p:contains(x)").length(), 1)
  assert_true(query_one(doc, "div > b > p") is Some(_))
  assert_true(matches(link, "html b a"))
  assert_eq(matches(link, "em a"), false)
  let limits = SelectorLimits()
  assert_true(matches_with_limits(link, "html div b a", limits))
  assert_eq(matches_with_limits(link, "em a", limits), false)
  assert_eq(selector_text_content(html), "x l")
  try
    matches_with_limits(link, "em a", SelectorLimits(max_match_steps=100))
  catch {
    SelectorError(message) =>
      assert_eq(message, "Selector match budget exceeded")
    _ => fail("expected selector match budget error")
  } noraise {
    _ => fail("expected selector match budget error")
  }
}
