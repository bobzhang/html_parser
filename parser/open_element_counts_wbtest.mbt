///|
// Whitebox checks for the parser's open-element bookkeeping and for
// `append_new_node`, the direct append used at hot insertion sites.
//
// `open_element_counts` (and the template/table/select counters next to it)
// are maintained incrementally by the stack wrappers in stack.mbt, and
// `has_open_element` answers from them without scanning `stack`. These tests
// recount `stack` after every top-level parse step over a broad corpus, so a
// stack mutation that bypasses the wrappers shows up as a mismatch.

///|
/// Recount the open-element bookkeeping from `stack` and compare it with the
/// incrementally maintained counters. Zero entries in `open_element_counts`
/// are allowed (names whose elements have all been popped).
fn Parser::open_element_counts_match_stack(self : Parser) -> Bool {
  let expected : Map[String, Int] = Map([])
  let mut templates = 0
  let mut tables = 0
  let mut selects = 0
  for node in self.stack {
    if node.kind != Element {
      continue
    }
    expected[node.name] = expected.get(node.name).unwrap_or(0) + 1
    if node.name == "template" && (node.ns is None || node.ns is Some("html")) {
      templates += 1
    } else if node.name == "table" {
      tables += 1
    } else if node.name == "select" && node.ns is Some("html") {
      selects += 1
    }
  }
  for name, count in self.open_element_counts {
    if count != expected.get(name).unwrap_or(0) {
      return false
    }
  }
  for name, count in expected {
    if self.open_element_counts.get(name).unwrap_or(0) != count {
      return false
    }
  }
  templates == self.open_template_count &&
  tables == self.open_table_count &&
  selects == self.open_select_count
}

///|
fn assert_open_element_counts(
  parser : Parser,
  input : String,
  where_ : String,
) -> Unit raise {
  if !parser.open_element_counts_match_stack() {
    fail("open-element counts diverged from stack \{where_} for \{repr(input)}")
  }
}

///|
/// Mirror `parse` up to (not including) its post-parse passes, checking the
/// counters after every top-level step of the parse loop.
fn check_document_counts(
  input : String,
  scripting_enabled~ : Bool,
) -> Unit raise {
  let parser = Parser(
    input,
    @dom.document(),
    scripting_enabled~,
    xml_coercion=false,
  )
  parser.deferred_initial_doctype_error = parser.report_initial_doctype_error()
  assert_open_element_counts(parser, input, "at start")
  while !parser.is_eof() {
    let pos = parser.pos
    parser.parse_next()
    assert_open_element_counts(parser, input, "after step at \{pos}")
  }
  parser.flush_pending_text()
  parser.flush_deferred_initial_doctype_error()
  parser.report_eof_tree_errors()
  assert_open_element_counts(parser, input, "at end")
}

///|
/// Mirror `parse_fragment`. Contexts with a dedicated setup run their own
/// `parse_all`, so those are checked once the context returns; the generic
/// path is stepped like a document.
fn check_fragment_counts(
  input : String,
  context : FragmentContext?,
) -> Unit raise {
  let parser = Parser(
    input,
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let handled = match context {
    Some(fragment_context) => parser.parse_fragment_context(fragment_context)
    None => false
  }
  if !handled {
    while !parser.is_eof() {
      let pos = parser.pos
      parser.parse_next()
      assert_open_element_counts(parser, input, "after step at \{pos}")
    }
    parser.flush_pending_text()
  }
  parser.report_eof_tree_errors()
  assert_open_element_counts(parser, input, "at end")
}

///|
/// Every child's parent pointer names the node whose child list holds it,
/// template contents point back at their template, and no node is reached
/// twice. Walks with an explicit stack so deep trees are fine.
fn assert_tree_links_consistent(root : @dom.Node, input : String) -> Unit raise {
  let pending = [root]
  while pending.pop() is Some(node) {
    for index, child in node.children {
      guard child.parent is Some(parent) && physical_equal(parent, node) else {
        fail(
          "child \{index} of <\{node.name}> has a stale parent for \{repr(input)}",
        )
      }
      for earlier in node.children[:index] {
        if physical_equal(earlier, child) {
          fail("<\{node.name}> lists a child twice for \{repr(input)}")
        }
      }
      pending.push(child)
    }
    if node.template_contents is Some(contents) {
      guard contents.parent is Some(parent) && physical_equal(parent, node) else {
        fail(
          "template contents of <\{node.name}> lost their parent for \{repr(input)}",
        )
      }
      pending.push(contents)
    }
  }
}

///|
/// Inputs aimed at every place the stack of open elements changes shape:
/// the adoption agency (including the Noah's-ark clause and the outer and
/// inner loop limits), foster parenting, templates, select, frameset,
/// foreign content and the fragment contexts.
let open_element_count_corpus : Array[String] = [
  "", "x", "<div>", "<!DOCTYPE html><html><head><title>t</title></head><body><p>x",
  // adoption agency
   "<b><p>x</b>y</p>", "<a><table><a>", "<a><p><a>x</a>", "<b><i><p>x</b>y</i>z",
  "<p><b><div><i>x</b>y</i>", "<a href=1><div><a href=2>x</div></a>", "<b><b><b><b><b><b><b><b>x</b></b>",
  "<b class=x><b class=x><b class=x><b class=x><p>t", "<font><font><font><font><font><div>x</font>",
  "<a><b><c><d><e><f><g><h><i><j><k><div>x</a>", "<b><div><div><div><div><div><div><div><div><div>x</b>y",
  "<i><b><u><s><div>x</i>y</b>z</u>w</s>", "<nobr><nobr>x<nobr>", "<b><table><td></b><i></table>x",
  "<a><svg><a>x</a></svg></a>", "<b><marquee><b>x</marquee>y</b>", "<em><p>a<em>b</p>c</em>",
  "<p><a><p>x</a>", "<li><b><li>x", "<code><code><code><code><code>x</code>", "<b>1<p>2</b>3<b>4<p>5</b>6",
  "<a><button><a>x</a></button></a>", "</b></a></i>x<b>",
  // foster parenting and tables
   "<table>x<b>y</b>z<tr><td>a</table>", "<table><tr>x<td>y</td>z</tr></table>",
  "<table><b><tr><td>x</td></tr>y</table>z", "<table><caption><b>x</caption>y</table>",
  "<table><colgroup><col><template>x</template></colgroup></table>", "<table><td><table><td>x</td></table></td></table>",
  "<table><form><input type=hidden><tr>", "<table><tbody><tr><th>x<td>y</tbody></table>",
  "<table><select><option>x</table>", "<div><table><tr><td><div>x</table></div>",
  "<table><tr><td>x</p></td></tr></table>", "<table></tbody></thead></tfoot></tr></td></th></caption></colgroup></table>",
  // templates
   "<template><tr><td>x</template>", "<template><template><b>x</template></template>y",
  "<table><template><td>x</template></table>", "<template><select><option>x</select></template>",
  "<template><frameset></template>", "<head><template><meta></template></head>",
  "<template><col><div>x</template>", "<template></div></template>", "<body><template>x</body>y",
  // select
   "<select><option>a<option>b<optgroup><option>c</select>", "<select><select>x",
  "<select><input>x", "<select><table><tr>", "<select><b>x</b></select>", "<select><button><selectedcontent></selectedcontent></button><option>x</select>",
  "<select><svg>x</svg></select>", "<select><hr><keygen>",
  // frameset
   "<frameset><frame></frameset>", "<frameset><frameset><frame></frameset></frameset>x",
  "<html><frameset></frameset><noframes>x</noframes></html>", "<div><frameset>",
  "<p>x<frameset>", "<body><frameset>", "<frameset></frameset></html><frame>",
  // foreign content
   "<svg><foreignObject><div>x</div></foreignObject></svg>", "<math><mi><b>x</b></mi></math>",
  "<svg><desc><svg><title>x</title></svg></desc></svg>", "<svg><p>x</svg>", "<math><annotation-xml encoding=text/html><div>x</div></annotation-xml></math>",
  "<svg><font color=red>x</font></svg>", "<svg></p>x", "<math><mtext><table><td>x</table></mtext>",
  // misc tree-construction edges
   "<p><p><p>x", "<ul><li>a<li>b<ol><li>c</ul>", "<dl><dt>a<dd>b<dt>c</dl>", "<h1><h2>x</h1>",
  "<pre>\nx</pre>", "<textarea>x</textarea>", "<button><button>x", "<form><form>x</form>",
  "<ruby><rb>a<rt>b<rtc>c<rp>d</ruby>", "<plaintext><b>x", "<noscript><p>x</noscript>",
  "<html><body></body></html><p>x", "</html><!--c--><p>", "<head></head><p>x</head>",
  "<isindex><image>", "<object><p>x</object>", "<applet><b>x</applet>", "<option><optgroup>x",
  "</br></p>", "<body><body><html>", "<search><p>x</search>", "<menu><li>x</menu>",
]

///|
let open_element_count_contexts : Array[FragmentContext?] = [
  None,
  Some(FragmentContext("div")),
  Some(FragmentContext("body")),
  Some(FragmentContext("html")),
  Some(FragmentContext("table")),
  Some(FragmentContext("tbody")),
  Some(FragmentContext("tr")),
  Some(FragmentContext("td")),
  Some(FragmentContext("caption")),
  Some(FragmentContext("colgroup")),
  Some(FragmentContext("select")),
  Some(FragmentContext("template")),
  Some(FragmentContext("textarea")),
  Some(FragmentContext("svg", ns="svg")),
  Some(FragmentContext("math", ns="math")),
]

///|
/// Token alphabet for generated tag soup: formatting elements, block and
/// table structure, templates, select, frameset and foreign content.
let open_element_count_tokens : Array[String] = [
  "<a>", "</a>", "<b>", "</b>", "<i>", "</i>", "<font>", "</font>", "<nobr>", "</nobr>",
  "<p>", "</p>", "<div>", "</div>", "<span>", "</span>", "<li>", "<ul>", "</ul>",
  "<dd>", "<table>", "</table>", "<tr>", "</tr>", "<td>", "</td>", "<th>", "<tbody>",
  "<caption>", "</caption>", "<colgroup>", "<col>", "<template>", "</template>",
  "<select>", "</select>", "<option>", "<optgroup>", "<button>", "</button>", "<form>",
  "</form>", "<input>", "<h1>", "</h1>", "<frameset>", "</frameset>", "<frame>",
  "<body>", "</body>", "<html>", "</html>", "<head>", "</head>", "<svg>", "</svg>",
  "<math>", "</math>", "<mi>", "<foreignObject>", "</foreignObject>", "<desc>", "<marquee>",
  "</marquee>", "<hr>", "<br>", "</br>", "<textarea>x</textarea>", "<title>t</title>",
  "x", " ", "<!--c-->", "<!DOCTYPE html>",
]

///|
/// Deterministic tag soup built from `open_element_count_tokens`.
fn generated_tag_soup(count : Int) -> Array[String] {
  let inputs : Array[String] = []
  let mut state : UInt = 0x9E3779B9
  let alphabet = open_element_count_tokens.length().reinterpret_as_uint()
  for _ in 0..<count {
    state = state * 1664525 + 1013904223
    let length = ((state >> 16) % 40).reinterpret_as_int() + 1
    let builder = StringBuilder()
    for _ in 0..<length {
      state = state * 1664525 + 1013904223
      builder.write_string(
        open_element_count_tokens[((state >> 8) % alphabet).reinterpret_as_int()],
      )
    }
    inputs.push(builder.to_string())
  }
  inputs
}

///|
fn open_element_count_inputs() -> Array[String] {
  let inputs = open_element_count_corpus.copy()
  // Deep enough to pass the Noah's-ark limit and the adoption agency's
  // outer and inner loop limits many times over.
  inputs.push("<b>".repeat(40) + "<p>x" + "</b>".repeat(5) + "y")
  inputs.push("<a><div>".repeat(20) + "x</a>")
  inputs.push("<table>".repeat(20) + "x" + "<td>".repeat(20))
  inputs.push("<template>".repeat(15) + "<tr><td>x" + "</template>".repeat(15))
  inputs.append(generated_tag_soup(600))
  inputs
}

///|
test "open-element counts match the stack after every parse step" {
  for input in open_element_count_inputs() {
    check_document_counts(input, scripting_enabled=true)
    check_document_counts(input, scripting_enabled=false)
  }
}

///|
test "open-element counts match the stack across fragment contexts" {
  let inputs = open_element_count_inputs()
  for context in open_element_count_contexts {
    for input in inputs {
      check_fragment_counts(input, context)
    }
  }
}

///|
test "open-element counts follow every stack wrapper" {
  let parser = Parser(
    "",
    @dom.document(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let b1 = @dom.element("b")
  let b2 = @dom.element("b")
  let table = @dom.element("table")
  let template = @dom.element("template")
  let select = @dom.element("select")
  let svg_select = @dom.element("select", ns="svg")
  parser.push_open_element(b1)
  parser.push_open_element(@dom.text("not counted"))
  parser.push_open_element(table)
  parser.insert_open_element_at(1, b2)
  parser.push_open_element(template)
  parser.push_open_element(select)
  parser.push_open_element(svg_select)
  assert_true(parser.open_element_counts_match_stack())
  assert_true(parser.has_open_element("b"))
  assert_true(parser.has_open_element("select"))
  assert_eq(parser.open_select_count, 1)
  // Replacing an entry moves its count to the replacement's name.
  parser.replace_open_element_at(1, @dom.element("i"))
  assert_true(parser.open_element_counts_match_stack())
  assert_true(parser.has_open_element("i"))
  ignore(parser.remove_open_element_at(2))
  assert_true(parser.open_element_counts_match_stack())
  ignore(parser.remove_open_node(table))
  assert_true(parser.open_element_counts_match_stack())
  assert_false(parser.has_open_element("table"))
  ignore(parser.pop_open_element())
  ignore(parser.pop_open_element())
  assert_true(parser.open_element_counts_match_stack())
  assert_false(parser.has_open_element("select"))
  assert_eq(parser.open_select_count, 0)
  // A count that has dropped to zero stays in the map without reading as open.
  assert_eq(parser.open_element_counts.get("select"), Some(0))
  parser.clear_open_elements()
  assert_true(parser.open_element_counts_match_stack())
  assert_false(parser.has_open_element("b"))
  assert_false(parser.has_open_element("i"))
  assert_false(parser.has_open_element("template"))
}

///|
test "button-scope early-out agrees with the full scope walk" {
  // The early-out answers false only when no element of that name is open;
  // when one is, the scope walk still decides.
  let parser = Parser(
    "",
    @dom.document(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_false(parser.has_open_element_in_button_scope("p"))
  assert_false(parser.has_open_element_in_default_scope("p"))
  parser.push_open_element(@dom.element("p"))
  assert_true(parser.has_open_element_in_button_scope("p"))
  assert_true(parser.has_open_element_in_default_scope("p"))
  parser.push_open_element(@dom.element("button"))
  assert_false(parser.has_open_element_in_button_scope("p"))
  assert_true(parser.has_open_element_in_default_scope("p"))
  ignore(parser.pop_open_element())
  ignore(parser.pop_open_element())
  assert_false(parser.has_open_element_in_button_scope("p"))
}

///|
test "append_new_node matches append_child for each kind of parent" {
  let parents : Array[() -> @dom.Node] = [
    () => @dom.document(),
    () => @dom.fragment(),
    () => @dom.element("div"),
    () => @dom.element("template"),
    () => @dom.element("template", ns="svg"),
    () => @dom.element("p", children=[@dom.text("existing")]),
  ]
  for make_parent in parents {
    let fast_parent = make_parent()
    let slow_parent = make_parent()
    for
      make_child in [
        () => @dom.element("span"),
        () => @dom.text("t"),
        () => @dom.comment("c"),
      ] {
      let fast_child = make_child()
      let slow_child = make_child()
      append_new_node(fast_parent, fast_child)
      slow_parent.append_child(slow_child)
      assert_eq(
        @ser.to_test_format(fast_parent),
        @ser.to_test_format(slow_parent),
      )
      assert_eq(fast_child.parent is None, slow_child.parent is None)
      // Each child lands where append_child put its twin: either directly
      // under the parent or under the template contents.
      let fast_holder = fast_child.parent.unwrap()
      let slow_holder = slow_child.parent.unwrap()
      assert_eq(
        physical_equal(fast_holder, fast_parent),
        physical_equal(slow_holder, slow_parent),
      )
      assert_eq(fast_holder.children.length(), slow_holder.children.length())
      assert_true(
        physical_equal(fast_holder.children.last().unwrap(), fast_child),
      )
    }
  }
}

///|
test "append_new_node falls back to append_child for nodes that are not new" {
  // A node that already has a parent is moved, not duplicated.
  let first = @dom.element("div")
  let second = @dom.element("div")
  let moved = @dom.element("span")
  first.append_child(moved)
  append_new_node(second, moved)
  assert_eq(first.children.length(), 0)
  assert_true(second.children[0] is node && physical_equal(node, moved))
  assert_true(moved.parent is Some(parent) && physical_equal(parent, second))
  // A node with children may be an ancestor, so the cycle check still runs.
  let outer = @dom.element("div")
  let inner = @dom.element("span")
  outer.append_child(inner)
  append_new_node(inner, outer)
  assert_eq(inner.children.length(), 0)
  assert_true(outer.parent is None)
  // Appending a node to itself is rejected.
  let lone = @dom.element("div")
  append_new_node(lone, lone)
  assert_eq(lone.children.length(), 0)
}

///|
test "parsed trees keep parent pointers consistent with child lists" {
  for input in open_element_count_inputs() {
    let doc = parse(input) catch { _ => continue }
    assert_tree_links_consistent(doc.root, input)
    for context in open_element_count_contexts {
      let fragment = parse_fragment(input, context?) catch { _ => continue }
      assert_tree_links_consistent(fragment.root, input)
    }
  }
}
