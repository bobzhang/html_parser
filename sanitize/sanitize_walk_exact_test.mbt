// Exact-output tests for the sanitizer's DOM walk: final tree shape (including
// template contents and parent pointers), the full observer event sequence,
// and which error `Raise` reports first. They pin the behaviour of the
// explicit-stack walk to that of the former recursive walk, including when
// observer or URL-filter callbacks mutate the tree mid-walk.

///|
/// Render `node` and its subtree (including template contents) one node per
/// line. A node whose `parent` does not point at the node it is listed under
/// is marked with `!parent`.
fn walk_dump(node : @dom.Node) -> String {
  let sb = StringBuilder()
  walk_dump_into(sb, node, None, 0)
  sb.to_string()
}

///|
fn walk_dump_into(
  sb : StringBuilder,
  node : @dom.Node,
  expected_parent : @dom.Node?,
  depth : Int,
) -> Unit {
  for _ in 0..<depth {
    sb.write_string("  ")
  }
  match node.kind {
    Element => {
      sb.write_string("<\{node.name}")
      if node.ns is Some(ns) && ns != "html" {
        sb.write_string(" ns=\{ns}")
      }
      for key, value in node.attrs {
        sb.write_string(" \{key}=\{Repr(value)}")
      }
      sb.write_string(">")
    }
    Text => sb.write_string("#text \{walk_visible(node.data)}")
    Comment => sb.write_string("#comment \{walk_visible(node.data)}")
    Doctype => sb.write_string("#doctype \{node.name}")
    Document => sb.write_string("#document")
    Fragment => sb.write_string("#fragment")
  }
  match (expected_parent, node.parent) {
    (None, _) => ()
    (Some(expected), Some(actual)) if physical_equal(expected, actual) => ()
    _ => sb.write_string(" !parent")
  }
  sb.write_string("\n")
  for child in node.children {
    walk_dump_into(sb, child, Some(node), depth + 1)
  }
  if node.template_contents is Some(contents) {
    for _ in 0..<(depth + 1) {
      sb.write_string("  ")
    }
    sb.write_string("[template contents]\n")
    for child in contents.children {
      walk_dump_into(sb, child, Some(contents), depth + 2)
    }
  }
}

///|
/// Quote `data`, spelling out zero-width spaces so snapshots stay readable.
fn walk_visible(data : String) -> String {
  "\"" + data.replace_all(old="\u{200B}", new="<ZWSP>") + "\""
}

///|
/// Short label for a node in event logs.
fn walk_node_label(node : @dom.Node) -> String {
  match node.kind {
    Element => "<\{node.name}>"
    Text => "#text \{walk_visible(node.data)}"
    Comment => "#comment \{walk_visible(node.data)}"
    Doctype => "#doctype"
    Document => "#document"
    Fragment => "#fragment"
  }
}

///|
/// An observer that records every hook and report call, in order.
fn walk_recording_observer(
  log : Array[String],
) -> @sanitize.SanitizeTransformObserver {
  SanitizeTransformObserver(
    Some(node => log.push("hook \{walk_node_label(node)}")),
    Some((message, node) => {
      let label = match node {
        Some(node) => walk_node_label(node)
        None => "-"
      }
      log.push("report \{message} @ \{label}")
    }),
  )
}

///|
/// Siblings around two levels of disallowed elements, with comments, invisible
/// Unicode, a dropped-content element, and a void disallowed element.
fn walk_sibling_fixture() -> @dom.Node {
  @dom.fragment(children=[
    @dom.text("head\u{200B}"),
    @dom.element("b", children=[@dom.text("bold")]),
    @dom.element("custom", attrs={ "data-x": Some("1\u{200B}") }, children=[
      @dom.text("c1"),
      @dom.comment("inner"),
      @dom.element("i", children=[@dom.text("it")]),
      @dom.element("other", children=[
        @dom.text("deep"),
        @dom.element("script", children=[@dom.text("evil()")]),
        @dom.element("b", children=[@dom.text("x")]),
      ]),
      @dom.element("br"),
      @dom.text("c2"),
    ]),
    @dom.comment("between"),
    @dom.element("i", children=[@dom.text("tail")]),
    @dom.text("end"),
  ])
}

///|
fn walk_run(
  handling : @sanitize.DisallowedTagHandling,
  root : @dom.Node,
) -> (String, Array[String]) raise {
  let log : Array[String] = []
  let policy = @sanitize.SanitizationPolicy(
    ["b", "i", "template"],
    disallowed_tag_handling=handling,
  )
  let out = @sanitize.sanitize_dom_with_observer(
    root,
    Some(policy),
    Some(walk_recording_observer(log)),
  )
  (walk_dump(out), log)
}

///|
test "sanitize walk unwraps disallowed elements in place between siblings" {
  let (tree, log) = walk_run(Unwrap, walk_sibling_fixture())
  inspect(
    tree,
    content=(
      #|#fragment
      #|  #text "head"
      #|  <b>
      #|    #text "bold"
      #|  #text "c1"
      #|  <i>
      #|    #text "it"
      #|  #text "deep"
      #|  <b>
      #|    #text "x"
      #|  #text "c2"
      #|  <i>
      #|    #text "tail"
      #|  #text "end"
      #|
    ),
  )
  debug_inspect(
    log,
    content=(
      #|[
      #|  "hook #text \"head<ZWSP>\"",
      #|  "report Stripped invisible Unicode from text node @ #text \"head<ZWSP>\"",
      #|  "hook <custom>",
      #|  "report Unsafe tag 'custom' (not allowed) @ <custom>",
      #|  "hook #comment \"inner\"",
      #|  "report Dropped comment @ #comment \"inner\"",
      #|  "hook <other>",
      #|  "report Unsafe tag 'other' (not allowed) @ <other>",
      #|  "hook <script>",
      #|  "report Unsafe tag 'script' (dropped content) @ <script>",
      #|  "hook <br>",
      #|  "report Unsafe tag 'br' (not allowed) @ <br>",
      #|  "hook #comment \"between\"",
      #|  "report Dropped comment @ #comment \"between\"",
      #|]
    ),
  )
}

///|
test "sanitize walk escapes disallowed elements in place between siblings" {
  let (tree, log) = walk_run(Escape, walk_sibling_fixture())
  inspect(
    tree,
    content=(
      #|#fragment
      #|  #text "head"
      #|  <b>
      #|    #text "bold"
      #|  #text "<custom data-x="1">"
      #|  #text "c1"
      #|  <i>
      #|    #text "it"
      #|  #text "<other>"
      #|  #text "deep"
      #|  <b>
      #|    #text "x"
      #|  #text "</other>"
      #|  #text "<br>"
      #|  #text "c2"
      #|  #text "</custom>"
      #|  <i>
      #|    #text "tail"
      #|  #text "end"
      #|
    ),
  )
  debug_inspect(
    log,
    content=(
      #|[
      #|  "hook #text \"head<ZWSP>\"",
      #|  "report Stripped invisible Unicode from text node @ #text \"head<ZWSP>\"",
      #|  "hook <custom>",
      #|  "report Unsafe tag 'custom' (not allowed) @ <custom>",
      #|  "hook #comment \"inner\"",
      #|  "report Dropped comment @ #comment \"inner\"",
      #|  "hook <other>",
      #|  "report Unsafe tag 'other' (not allowed) @ <other>",
      #|  "hook <script>",
      #|  "report Unsafe tag 'script' (dropped content) @ <script>",
      #|  "hook <br>",
      #|  "report Unsafe tag 'br' (not allowed) @ <br>",
      #|  "hook #comment \"between\"",
      #|  "report Dropped comment @ #comment \"between\"",
      #|]
    ),
  )
}

///|
test "sanitize walk drops disallowed elements in place between siblings" {
  let (tree, log) = walk_run(Drop, walk_sibling_fixture())
  inspect(
    tree,
    content=(
      #|#fragment
      #|  #text "head"
      #|  <b>
      #|    #text "bold"
      #|  <i>
      #|    #text "tail"
      #|  #text "end"
      #|
    ),
  )
  debug_inspect(
    log,
    content=(
      #|[
      #|  "hook #text \"head<ZWSP>\"",
      #|  "report Stripped invisible Unicode from text node @ #text \"head<ZWSP>\"",
      #|  "hook <custom>",
      #|  "report Unsafe tag 'custom' (not allowed) @ <custom>",
      #|  "hook #comment \"between\"",
      #|  "report Dropped comment @ #comment \"between\"",
      #|]
    ),
  )
}

///|
/// An allowed template whose contents hold a nested template, and a
/// disallowed element carrying template-like contents next to it.
fn walk_template_fixture() -> @dom.Node {
  let inner = @dom.element("template")
  inner.append_child(@dom.element("custom", children=[@dom.text("in\u{200B}")]))
  inner.append_child(@dom.comment("c"))
  let outer = @dom.element("template")
  outer.append_child(@dom.text("t1"))
  outer.append_child(@dom.element("other", children=[@dom.text("o")]))
  outer.append_child(inner)
  outer.append_child(@dom.element("b", children=[@dom.text("t2")]))
  let disallowed = @dom.element("custom")
  disallowed.children.push(@dom.text("kid"))
  let contents = @dom.fragment(children=[
    @dom.element("i", children=[@dom.text("tc")]),
    @dom.comment("tc-comment"),
  ])
  contents.parent = Some(disallowed)
  disallowed.template_contents = Some(contents)
  @dom.fragment(children=[
    @dom.text("before"),
    outer,
    disallowed,
    @dom.text("after"),
  ])
}

///|
test "sanitize walk handles template contents under each handling" {
  let handlings : Array[@sanitize.DisallowedTagHandling] = [
    Unwrap,
    Escape,
    Drop,
  ]
  let results = handlings.map(handling => {
    let (tree, log) = walk_run(handling, walk_template_fixture())
    "\{Repr(handling)}\n\{tree}\{log.join("\n")}\n"
  })
  inspect(
    results.join("\n"),
    content=(
      #|Unwrap
      #|#fragment
      #|  #text "before"
      #|  <template>
      #|    [template contents]
      #|      #text "t1"
      #|      #text "o"
      #|      <template>
      #|        [template contents]
      #|          #text "in"
      #|      <b>
      #|        #text "t2"
      #|  #text "kid"
      #|  <i>
      #|    #text "tc"
      #|  #text "after"
      #|hook <other>
      #|report Unsafe tag 'other' (not allowed) @ <other>
      #|hook <custom>
      #|report Unsafe tag 'custom' (not allowed) @ <custom>
      #|hook #text "in<ZWSP>"
      #|report Stripped invisible Unicode from text node @ #text "in<ZWSP>"
      #|hook #comment "c"
      #|report Dropped comment @ #comment "c"
      #|hook <custom>
      #|report Unsafe tag 'custom' (not allowed) @ <custom>
      #|hook #comment "tc-comment"
      #|report Dropped comment @ #comment "tc-comment"
      #|
      #|Escape
      #|#fragment
      #|  #text "before"
      #|  <template>
      #|    [template contents]
      #|      #text "t1"
      #|      #text "<other>"
      #|      #text "o"
      #|      #text "</other>"
      #|      <template>
      #|        [template contents]
      #|          #text "<custom>"
      #|          #text "in"
      #|          #text "</custom>"
      #|      <b>
      #|        #text "t2"
      #|  #text "<custom>"
      #|  #text "kid"
      #|  <i>
      #|    #text "tc"
      #|  #text "</custom>"
      #|  #text "after"
      #|hook <other>
      #|report Unsafe tag 'other' (not allowed) @ <other>
      #|hook <custom>
      #|report Unsafe tag 'custom' (not allowed) @ <custom>
      #|hook #text "in<ZWSP>"
      #|report Stripped invisible Unicode from text node @ #text "in<ZWSP>"
      #|hook #comment "c"
      #|report Dropped comment @ #comment "c"
      #|hook <custom>
      #|report Unsafe tag 'custom' (not allowed) @ <custom>
      #|hook #comment "tc-comment"
      #|report Dropped comment @ #comment "tc-comment"
      #|
      #|Drop
      #|#fragment
      #|  #text "before"
      #|  <template>
      #|    [template contents]
      #|      #text "t1"
      #|      <template>
      #|        [template contents]
      #|      <b>
      #|        #text "t2"
      #|  #text "after"
      #|hook <other>
      #|report Unsafe tag 'other' (not allowed) @ <other>
      #|hook <custom>
      #|report Unsafe tag 'custom' (not allowed) @ <custom>
      #|hook #comment "c"
      #|report Dropped comment @ #comment "c"
      #|hook <custom>
      #|report Unsafe tag 'custom' (not allowed) @ <custom>
      #|
    ),
  )
}

///|
test "sanitize walk observer event sequence is exact" {
  let log : Array[String] = []
  let svg = @dom.element("svg", ns="svg", children=[
    @dom.element("set", ns="svg"),
  ])
  let doc = @dom.document(children=[
    @dom.doctype(name="html"),
    @dom.comment("top"),
    @dom.element("html", children=[
      @dom.element("body", children=[
        @dom.element(
          "p",
          attrs={ "onclick": Some("x()"), "title": Some("t") },
          children=[
            @dom.text("a\u{200B}b"),
            @dom.element("a", attrs={ "href": Some("javascript:alert(1)") }, children=[
              @dom.text("link"),
            ]),
            svg,
            @dom.element("script", children=[@dom.text("evil()")]),
            @dom.element("blink", children=[
              @dom.comment("in-blink"),
              @dom.text("kept"),
            ]),
          ],
        ),
      ]),
    ]),
  ])
  let out = @sanitize.sanitize_dom_with_observer(
    doc,
    None,
    Some(walk_recording_observer(log)),
  )
  inspect(
    walk_dump(out),
    content=(
      #|#document
      #|  #doctype #doctype
      #|  <html>
      #|    <body>
      #|      <p title=Some("t")>
      #|        #text "ab"
      #|        <a>
      #|          #text "link"
      #|        #text "kept"
      #|
    ),
  )
  debug_inspect(
    log,
    content=(
      #|[
      #|  "hook #comment \"top\"",
      #|  "report Dropped comment @ #comment \"top\"",
      #|  "hook <p>",
      #|  "report Unsafe attribute 'onclick' (matched forbidden pattern 'on*') @ <p>",
      #|  "hook #text \"a<ZWSP>b\"",
      #|  "report Stripped invisible Unicode from text node @ #text \"a<ZWSP>b\"",
      #|  "hook <a>",
      #|  "report Unsafe URL in attribute 'href' @ <a>",
      #|  "hook <svg>",
      #|  "report Unsafe tag 'svg' (foreign namespace) @ <svg>",
      #|  "hook <script>",
      #|  "report Unsafe tag 'script' (dropped content) @ <script>",
      #|  "hook <blink>",
      #|  "report Unsafe tag 'blink' (not allowed) @ <blink>",
      #|  "hook #comment \"in-blink\"",
      #|  "report Dropped comment @ #comment \"in-blink\"",
      #|]
    ),
  )
}

///|
/// Sanitize a fresh `build()` tree under a `Raise` policy and render the raised
/// error with the partially sanitized tree, then the full order of unsafe
/// reports for the same input under `Collect`.
fn walk_raise(
  build : () -> @dom.Node,
  allowed : Array[String],
  handling : @sanitize.DisallowedTagHandling,
) -> String raise {
  let policy = @sanitize.SanitizationPolicy(
    allowed,
    allowed_attributes={ "a": ["href"] },
    disallowed_tag_handling=handling,
    unsafe_handling=Raise,
  )
  let root = build()
  let result = try @sanitize.sanitize_dom(root, policy~) catch {
    err => "raised \{Repr(err)}"
  } noraise {
    _ => "no error"
  }
  let collect = @sanitize.SanitizationPolicy(
    allowed,
    allowed_attributes={ "a": ["href"] },
    disallowed_tag_handling=handling,
    unsafe_handling=Collect,
  )
  ignore(@sanitize.sanitize_dom(build(), policy=collect))
  let order = collect.collected_security_errors().map(err => err.message)
  "\{result}\n\{walk_dump(root)}collect order: \{Repr(order)}\n"
}

///|
/// A template element with `children` in its child list and `contents` in its
/// template contents.
fn walk_template_with(
  children : Array[@dom.Node],
  contents : Array[@dom.Node],
) -> @dom.Node {
  // `@dom.element` and `append_child` would route children into the
  // contents, so set up the child list directly.
  let template = @dom.element("template")
  for child in children {
    child.parent = Some(template)
    template.children.push(child)
  }
  let fragment = @dom.fragment(children=contents)
  fragment.parent = Some(template)
  template.template_contents = Some(fragment)
  template
}

///|
test "sanitize walk raises the first unsafe construct in document order" {
  let cases = [
    // An unsafe attribute is reported before the element's children.
    walk_raise(
      () => {
        @dom.fragment(children=[
          @dom.element("a", attrs={ "href": Some("javascript:x") }, children=[
            @dom.element("script"),
          ]),
        ])
      },
      ["a", "b"],
      Unwrap,
    ),
    // Depth first: a dropped-content element nested in allowed elements comes
    // before a foreign sibling of the outer element.
    walk_raise(
      () => {
        @dom.fragment(children=[
          @dom.element("b", children=[
            @dom.element("i", children=[
              @dom.element("style", children=[@dom.text("x")]),
            ]),
          ]),
          @dom.element("svg", ns="svg"),
        ])
      },
      ["b", "i"],
      Drop,
    ),
    // A disallowed element is reported before anything inside it.
    walk_raise(
      () => {
        @dom.fragment(children=[
          @dom.element("custom", children=[@dom.element("script")]),
          @dom.element("math", ns="math"),
        ])
      },
      ["b"],
      Escape,
    ),
    // An allowed template: its child list, then its contents, then the
    // following sibling.
    walk_raise(
      () => {
        @dom.fragment(children=[
          walk_template_with([@dom.element("math", ns="math")], [
            @dom.element("script"),
          ]),
          @dom.element("svg", ns="svg"),
        ])
      },
      ["template"],
      Unwrap,
    ),
    walk_raise(
      () => {
        @dom.fragment(children=[
          walk_template_with([], [@dom.element("script")]),
          @dom.element("svg", ns="svg"),
        ])
      },
      ["template"],
      Unwrap,
    ),
  ]
  inspect(
    cases.join("\n"),
    content=(
      #|raised UnsafeHtml("Unsafe URL in attribute 'href'")
      #|#fragment
      #|  <a href=Some("javascript:x")>
      #|    <script>
      #|collect order: [
      #|  "Unsafe URL in attribute 'href'",
      #|  "Unsafe tag 'script' (dropped content)",
      #|]
      #|
      #|raised UnsafeHtml("Unsafe tag 'style' (dropped content)")
      #|#fragment
      #|  <b>
      #|    <i>
      #|      <style>
      #|        #text "x"
      #|  <svg ns=svg>
      #|collect order: [
      #|  "Unsafe tag 'style' (dropped content)",
      #|  "Unsafe tag 'svg' (foreign namespace)",
      #|]
      #|
      #|raised UnsafeHtml("Unsafe tag 'custom' (not allowed)")
      #|#fragment
      #|  <custom>
      #|    <script>
      #|  <math ns=math>
      #|collect order: [
      #|  "Unsafe tag 'custom' (not allowed)",
      #|  "Unsafe tag 'script' (dropped content)",
      #|  "Unsafe tag 'math' (foreign namespace)",
      #|]
      #|
      #|raised UnsafeHtml("Unsafe tag 'math' (foreign namespace)")
      #|#fragment
      #|  <template>
      #|    <math ns=math>
      #|    [template contents]
      #|      <script>
      #|  <svg ns=svg>
      #|collect order: [
      #|  "Unsafe tag 'math' (foreign namespace)",
      #|  "Unsafe tag 'script' (dropped content)",
      #|  "Unsafe tag 'svg' (foreign namespace)",
      #|]
      #|
      #|raised UnsafeHtml("Unsafe tag 'script' (dropped content)")
      #|#fragment
      #|  <template>
      #|    [template contents]
      #|      <script>
      #|  <svg ns=svg>
      #|collect order: [
      #|  "Unsafe tag 'script' (dropped content)",
      #|  "Unsafe tag 'svg' (foreign namespace)",
      #|]
      #|
    ),
  )
}

///|
test "sanitize walk sees an observer reparenting the root under svg" {
  // Codex review repro: the comment observer moves the fragment under an
  // externally held `svg` element while the walk is in progress. The `<a>`
  // after the comment is then foreign content and must be dropped.
  let svg = @dom.element("svg", ns="svg")
  let frag = @dom.fragment(children=[
    @dom.element("span", children=[@dom.text("s")]),
    @dom.comment("move"),
    @dom.element("a", attrs={ "href": Some("https://example.com/") }, children=[
      @dom.text("link"),
    ]),
  ])
  let log : Array[String] = []
  let observer = @sanitize.SanitizeTransformObserver(
    None,
    Some((message, node) => {
      let label = match node {
        Some(node) => walk_node_label(node)
        None => "-"
      }
      log.push("\{message} @ \{label}")
      if message == "Dropped comment" {
        svg.append_child(frag)
      }
    }),
  )
  let policy = @sanitize.SanitizationPolicy(["span", "a"], allowed_attributes={
    "a": ["href"],
  })
  let out = @sanitize.sanitize_dom_with_observer(
    frag,
    Some(policy),
    Some(observer),
  )
  inspect(
    walk_dump(out),
    content=(
      #|#fragment
      #|  <span>
      #|    #text "s"
      #|
    ),
  )
  debug_inspect(
    log,
    content=(
      #|[
      #|  "Dropped comment @ #comment \"move\"",
      #|  "Unsafe tag 'a' (foreign namespace) @ <a>",
      #|]
    ),
  )
  inspect(
    walk_dump(svg),
    content=(
      #|<svg ns=svg>
      #|  #fragment
      #|    <span>
      #|      #text "s"
      #|
    ),
  )
}

///|
test "sanitize walk sees a URL filter reparenting the root under svg" {
  // The URL filter moves the fragment under an externally held `svg` element
  // the first time it runs. With foreign namespaces dropped, every later
  // element is foreign content.
  let svg = @dom.element("svg", ns="svg")
  let frag = @dom.fragment()
  let calls : Array[String] = []
  let filter = @sanitize.UrlFilter((tag, attr, value) => {
    calls.push("\{tag} \{attr} \{value}")
    if calls.length() == 1 {
      svg.append_child(frag)
    }
    Some(value)
  })
  let url_policy = @sanitize.UrlPolicy(
    allow_rules=[UrlPolicyRule("a", "href", UrlRule(allowed_schemes=["https"]))],
    url_filter=filter,
  )
  let build = () => {
    frag.children.clear()
    let kids = [
      @dom.element("a", attrs={ "href": Some("https://one.example/") }, children=[
        @dom.text("one"),
      ]),
      @dom.element("b", children=[@dom.text("bold")]),
      @dom.element("a", attrs={ "href": Some("https://two.example/") }, children=[
        @dom.text("two"),
      ]),
    ]
    for kid in kids {
      frag.append_child(kid)
    }
  }
  build()
  let policy = @sanitize.SanitizationPolicy(
    ["a", "b"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let log : Array[String] = []
  let out = @sanitize.sanitize_dom_with_observer(
    frag,
    Some(policy),
    Some(walk_recording_observer(log)),
  )
  inspect(
    walk_dump(out),
    content=(
      #|#fragment
      #|  <a href=Some("https://one.example/")>
      #|    #text "one"
      #|
    ),
  )
  debug_inspect(
    log,
    content=(
      #|[
      #|  "hook <b>",
      #|  "report Unsafe tag 'b' (foreign namespace) @ <b>",
      #|  "hook <a>",
      #|  "report Unsafe tag 'a' (foreign namespace) @ <a>",
      #|]
    ),
  )
  debug_inspect(
    calls,
    content=(
      #|["a href https://one.example/"]
    ),
  )
  // Without an observer, the URL filter alone must still force live checks.
  // Keep foreign namespaces: once the filter has moved the fragment under
  // `svg`, the trailing `<set>` is active foreign content and is dropped.
  svg.children.clear()
  frag.parent = None
  calls.clear()
  build()
  frag.append_child(@dom.element("set"))
  let keep_foreign = @sanitize.SanitizationPolicy(
    ["a", "b", "set"],
    allowed_attributes={ "a": ["href"] },
    drop_foreign_namespaces=false,
    url_policy~,
  )
  let kept = @sanitize.sanitize_dom(frag, policy=keep_foreign)
  inspect(
    walk_dump(kept),
    content=(
      #|#fragment
      #|  <a href=Some("https://one.example/")>
      #|    #text "one"
      #|  <b>
      #|    #text "bold"
      #|  <a href=Some("https://two.example/")>
      #|    #text "two"
      #|
    ),
  )
  debug_inspect(
    calls,
    content=(
      #|["a href https://one.example/", "a href https://two.example/"]
    ),
  )
}
