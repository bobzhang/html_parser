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
test "selector text fast path matches the general walk" {
  let rng = DeepTestRng::{ state: 99UL, }
  for _ in 0..<3000 {
    let nodes = random_selector_graph(rng)
    for node in nodes {
      assert_eq(selector_text_content(node), general_text_content(node))
    }
  }
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
