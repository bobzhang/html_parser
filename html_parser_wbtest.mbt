// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "dom insert_child_before moves appends and rejects cycles" {
  let parent = element("div")
  let first = element("p", children=[text("first")])
  let second = element("span", children=[text("second")])
  parent.append_child(first)
  parent.append_child(second)
  let inserted = element("em", children=[text("mid")])
  parent.insert_child_before(inserted, second)
  assert_eq(
    parent.to_html(pretty=false),
    "<div><p>first</p><em>mid</em><span>second</span></div>",
  )
  let fallback = element("strong", children=[text("end")])
  parent.insert_child_before(fallback, element("missing"))
  assert_eq(
    parent.to_html(pretty=false),
    "<div><p>first</p><em>mid</em><span>second</span><strong>end</strong></div>",
  )
  let other = element("section")
  other.append_child(inserted)
  assert_eq(
    parent.to_html(pretty=false),
    "<div><p>first</p><span>second</span><strong>end</strong></div>",
  )
  assert_eq(other.to_html(pretty=false), "<section><em>mid</em></section>")
  inserted.append_child(other)
  assert_eq(inserted.to_html(pretty=false), "<em>mid</em>")
  let non_container = comment("x")
  non_container.insert_child_before(text("ignored"), first)
  assert_eq(non_container.children().length(), 0)
  non_container.remove_child(first)
  assert_eq(first.to_html(pretty=false), "<p>first</p>")
}

///|
test "append_child clears stale parent links" {
  let parent = element("div")
  let child = element("span")
  child.parent = Some(comment("stale"))
  parent.append_child(child)
  assert_eq(parent.children.length(), 1)
  assert_true(physical_equal(parent.children[0], child))
  guard child.parent is Some(actual_parent) else {
    fail("expected adopted child parent")
  }
  assert_true(physical_equal(actual_parent, parent))
}

///|
test "query deduplicates shared nodes and ignores traversal cycles" {
  let shared_root = element("div")
  let shared = element("span", attrs={ "class": Some("target") })
  shared_root.append_child(shared)
  shared_root.children.push(shared)
  assert_eq(shared_root.query("span").length(), 1)
  assert_eq(shared_root.query(".target").length(), 1)
  assert_eq(shared_root.query("*").length(), 1)
  let cyclic_root = element("div")
  let child = element("span", attrs={ "class": Some("cycle") })
  cyclic_root.append_child(child)
  child.children.push(cyclic_root)
  child.children.push(text("needle"))
  cyclic_root.parent = Some(child)
  assert_eq(cyclic_root.query("span").length(), 1)
  assert_eq(cyclic_root.query(".cycle").length(), 1)
  assert_eq(cyclic_root.query("*").length(), 1)
  assert_true(matches(child, "div span"))
  assert_eq(matches(child, "em span"), false)
  assert_eq(matches(cyclic_root, "div:contains(needle)"), false)
  assert_eq(matches(child, "span:contains(needle)"), false)
  assert_eq(cyclic_root.query("div span").length(), 1)
  assert_eq(cyclic_root.query("em span").length(), 0)
  assert_eq(cyclic_root.query("span:contains(needle)").length(), 0)
}

///|
test "parser cursor helpers use utf16 offsets and safe fallbacks" {
  let parser = Parser::new(
    "😀",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  guard parser.advance_char() is Some(first) else {
    fail("expected first character")
  }
  assert_eq(first.to_string(), "😀")
  assert_eq(parser.pos, 2)
  assert_true(parser.advance_char() is None)
  assert_eq(parser.pos, 2)
  let root = parser.root
  ignore(parser.stack.pop())
  assert_true(physical_equal(parser.current_node(), root))
  parser.append_text("", 0)
  assert_eq(root.children.length(), 0)
  let source_parser = Parser::new(
    "<p😀>",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_eq(source_parser.source_tag_slice(0, 4), "<p😀>")
  source_parser.append_sanitize_escape_source_text(0, 4)
  assert_eq(source_parser.root.children.length(), 1)
  assert_eq(source_parser.root.children[0].data, "<p😀")
  let text_parser = Parser::new(
    "a😀\u{0000}b",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_eq(text_parser.remove_null_characters("a😀\u{0000}b", 0), "a😀b")
  assert_eq(text_parser.errors.length(), 1)
  assert_eq(
    text_parser.replace_null_characters("x\u{0000}😀", 0),
    "x\u{FFFD}😀",
  )
  assert_eq(text_parser.errors.length(), 2)
  assert_eq(eof_error_pos("a😀"), 1)
  guard text_node_without_leading_ascii_whitespace(text(" \t😀body"))
    is Some(stripped) else {
    fail("expected stripped text node")
  }
  assert_eq(stripped.data, "😀body")
  let (leading, rest) = split_text_node_leading_ascii_whitespace(
    text(" \t😀body"),
  )
  guard leading is Some(leading_node) else {
    fail("expected leading whitespace node")
  }
  guard rest is Some(rest_node) else { fail("expected rest text node") }
  assert_eq(leading_node.data, " \t")
  assert_eq(rest_node.data, "😀body")
  assert_eq(normalize_newlines("a\r\n😀\rb"), "a\n😀\nb")
  assert_eq(
    normalize_bogus_comment_data("a\u{0000}\r\n😀"),
    "a\u{FFFD}\n😀",
  )
  let (line, col) = line_col_at("a😀\nb", 4)
  assert_eq(line, 2)
  assert_eq(col, 1)
  let (eof_line, eof_col) = @syn.eof_line_col("a😀\n")
  assert_eq(eof_line, 2)
  assert_eq(eof_col, 0)
}

///|
test "entity helpers preserve unresolved names and attribute boundaries" {
  assert_true(
    consume_named_entity_with_errors("&unknown;", 0, in_attribute=false) is None,
  )
  assert_true(
    consume_named_entity_with_errors("&unknown", 0, in_attribute=false) is None,
  )
  guard consume_named_entity_with_errors("&copy.", 0, in_attribute=true)
    is Some(decoded_attr) else {
    fail("expected punctuation-delimited legacy attribute entity")
  }
  assert_eq(decoded_attr.value, "\u{00A9}")
  assert_eq(decoded_attr.next, 5)
  assert_eq(decoded_attr.errors.length(), 1)
  assert_true(
    legacy_entity_blocked_in_attribute("&copyx", 5, in_attribute=true),
  )
  assert_true(
    legacy_entity_blocked_in_attribute("&copy0", 5, in_attribute=true),
  )
  assert_true(
    legacy_entity_blocked_in_attribute("&copy=", 5, in_attribute=true),
  )
  assert_eq(
    legacy_entity_blocked_in_attribute("&copyx", 5, in_attribute=false),
    false,
  )
  assert_eq(
    legacy_entity_blocked_in_attribute("&copy.", 5, in_attribute=true),
    false,
  )
  let unresolved = tokenize("&unknown; &unknown", collect_errors=true)
  guard unresolved.tokens[0] is Characters("&unknown; &unknown") else {
    fail("expected unresolved named references to stay literal")
  }
  assert_eq(unresolved.errors.length(), 0)
}

///|
test "doctype helpers keep empty eof and unquoted identifiers distinct" {
  assert_eq(eof_error_pos(""), 0)
  assert_eq(doctype_eof_error_offset(""), 0)
  let errors : Array[DoctypeExternalError] = []
  let (value, next, closed) = parse_quoted_doctype_value_at(
    "identifier", 0, errors,
  )
  assert_true(value is None)
  assert_eq(next, 0)
  assert_eq(closed, false)
  assert_eq(errors.length(), 0)
  let external = parse_doctype_external("", true)
  assert_true(external.public_id is None)
  assert_true(external.system_id is None)
  assert_eq(external.force_quirks, false)
  assert_eq(external.errors.length(), 0)
}

///|
test "parser insertion helpers keep omitted origins optional" {
  let parser = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  parser.insert_element_without_push("hr", {})
  parser.insert_element_maybe_push("span", { "id": Some("x") }, true)
  assert_eq(parser.root.children.length(), 2)
  let hr = parser.root.children[0]
  let span = parser.root.children[1]
  assert_eq(hr.name, "hr")
  assert_true(hr.origin_offset() is None)
  assert_eq(span.name, "span")
  guard span.attrs["id"] is Some("x") else {
    fail("expected helper-inserted attrs")
  }
  assert_true(span.origin_offset() is None)
  guard parser.stack.last() is Some(last) else {
    fail("expected pushed helper node")
  }
  assert_true(physical_equal(last, span))
  assert_true(parser.has_open_html_element("span"))
}

///|
test "parser private defensive branches keep no-op behavior" {
  let template_parser = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let template = element("template")
  template_parser.stack.push(template)
  assert_true(template_parser.handle_template_end_tag("template", 0))
  assert_true(template.source_end_tag is None)
  assert_eq(template_parser.stack.length(), 1)

  let attr_parser = Parser::new(
    ">",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let attrs : Map[String, String?] = {}
  attr_parser.parse_attribute(attrs)
  assert_eq(attr_parser.pos, 1)
  assert_eq(attrs.length(), 0)
}

///|
test "detached recovery helpers ignore stale parser state" {
  let parser = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let div = element("div")
  parser.stack.push(div)
  parser.foreign_table_row_recovery_mode = true
  parser.report_foreign_table_row_recovery_text("x", 0)
  assert_eq(parser.errors.length(), 0)

  let parent = element("frameset")
  let stale = element("div")
  let child = element("frame")
  child.parent = Some(stale)
  detach_removed_frameset_replacement_child(parent, child)
  guard child.parent is Some(actual_parent) else {
    fail("expected stale parent link to stay attached")
  }
  assert_true(physical_equal(actual_parent, stale))
}

///|
test "document scaffold text helpers preserve whitespace boundaries" {
  assert_true(text_node_without_leading_ascii_whitespace(text(" \t\n")) is None)
  guard text_node_without_leading_ascii_whitespace(text(" \tbody"))
    is Some(stripped) else {
    fail("expected stripped body text")
  }
  assert_eq(stripped.data, "body")
  let body = text("body")
  let (no_leading, unchanged) = split_text_node_leading_ascii_whitespace(body)
  assert_true(no_leading is None)
  guard unchanged is Some(actual) else { fail("expected original body text") }
  assert_true(physical_equal(actual, body))
  let (all_leading, empty_rest) = split_text_node_leading_ascii_whitespace(
    text(" \n"),
  )
  guard all_leading is Some(leading_only) else {
    fail("expected all-whitespace leading node")
  }
  assert_eq(leading_only.data, " \n")
  assert_true(empty_rest is None)
  let (leading, rest) = split_text_node_leading_ascii_whitespace(
    text(" \nBody"),
  )
  guard leading is Some(leading_node) else {
    fail("expected leading whitespace node")
  }
  assert_eq(leading_node.data, " \n")
  guard rest is Some(rest_node) else {
    fail("expected non-whitespace rest node")
  }
  assert_eq(rest_node.data, "Body")
}

///|
test "document scaffold merges repeated html helper trees" {
  let primary = element("html", attrs={ "lang": Some("en") }, children=[
    element("head", children=[element("title", children=[text("T")])]),
    element("body", children=[text("A")]),
  ])
  let sibling = element(
    "html",
    attrs={ "dir": Some("ltr"), "lang": Some("fr") },
    children=[
      element("html", attrs={ "data-root": Some("sibling") }, children=[
        element("body", attrs={ "id": Some("merged") }, children=[text("B")]),
      ]),
    ],
  )
  let root = document(children=[primary, sibling])
  scaffold_document(root)
  assert_eq(root.children.length(), 1)
  let html = root.children[0]
  assert_true(physical_equal(html, primary))
  guard html.attrs["lang"] is Some("en") else {
    fail("expected first html lang to win")
  }
  guard html.attrs["dir"] is Some("ltr") else {
    fail("expected sibling html dir to merge")
  }
  guard html.attrs["data-root"] is Some("sibling") else {
    fail("expected nested html attrs to merge")
  }
  assert_eq(html.children.length(), 2)
  let body = html.children[1]
  guard body.attrs["id"] is Some("merged") else {
    fail("expected nested body attrs to merge")
  }
  assert_eq(body.to_html(pretty=false), "<body id=\"merged\">AB</body>")
}

///|
test "fragment context unwrap helper preserves sibling nodes" {
  let leading = comment("before")
  let wrapper_child = element("tbody", children=[
    element("tr", children=[element("td", children=[text("x")])]),
  ])
  let wrapper = element("table", children=[wrapper_child])
  let trailing = text("after")
  let root = fragment(children=[leading, wrapper, trailing])
  unwrap_fragment_context_element(root, wrapper)
  assert_eq(root.children.length(), 3)
  assert_true(physical_equal(root.children[0], leading))
  assert_true(physical_equal(root.children[1], wrapper_child))
  assert_true(physical_equal(root.children[2], trailing))
  assert_true(wrapper.parent is None)
  assert_eq(wrapper.children.length(), 0)
}

///|
test "document and fragment helpers tolerate missing shells" {
  let parser = Parser::new(
    "",
    document(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  parser.pending_document_html_attrs["lang"] = Some("en")
  parser.apply_pending_document_html_attrs()
  assert_eq(parser.root.children.length(), 0)
  let html = element("html", attrs={ "dir": Some("ltr") })
  parser.root.append_child(html)
  parser.apply_pending_document_html_attrs()
  guard html.attrs["lang"] is Some("en") else {
    fail("expected pending html attrs to survive missing shell")
  }
  guard html.attrs["dir"] is Some("ltr") else {
    fail("expected existing html attrs to survive pending merge")
  }
  let root = document(children=[comment("tail")])
  let paragraph = element("p", children=[text("x")])
  append_post_body_html_children(root, [paragraph])
  assert_eq(root.to_html(pretty=false), "<!--tail--><p>x</p>")
  guard paragraph.parent() is Some(parent) else {
    fail("expected appended post-body child parent")
  }
  assert_true(physical_equal(parent, root))
  let nested_before_body = element("html", children=[
    comment("c"),
    element("html", children=[element("meta", attrs={ "name": Some("x") })]),
  ])
  assert_true(html_fragment_child_is_before_body(nested_before_body))
  let nested_after_body = element("html", children=[
    element("html", children=[element("body")]),
  ])
  assert_eq(html_fragment_child_is_before_body(nested_after_body), false)
  let fragment_parser = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  fragment_parser.insert_html_fragment_body_marker({}, None)
  assert_eq(fragment_parser.root.children.length(), 0)
  assert_eq(
    fragment_parser.handle_html_fragment_shell_start_tag("p", {}, 0),
    false,
  )
}

///|
test "document head helpers tolerate detached parser stacks" {
  let document_parser = Parser::new(
    "",
    document(children=[element("html")]),
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_true(document_parser.document_has_element_child())
  let head = element("head")
  let head_parser = Parser::new(
    "",
    head,
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_eq(head_parser.current_is_document_head(), false)
  let shell = fragment()
  shell.append_child(head)
  head_parser.stack.clear()
  assert_true(head_parser.current_is_document_head())
  assert_eq(head_parser.close_current_document_head_for_start("p", 0), false)
  assert_eq(head_parser.stack.length(), 0)

  let noscript_parser = Parser::new(
    "",
    fragment(),
    scripting_enabled=false,
    xml_coercion=false,
  )
  let body = element("body")
  let noscript = element("noscript")
  noscript_parser.stack.push(body)
  noscript_parser.stack.push(noscript)
  noscript_parser.pop_disabled_head_noscript_for_reprocess()
  guard noscript_parser.stack.last() is Some(last) else {
    fail("expected non-head parent to remain after noscript pop")
  }
  assert_true(physical_equal(last, body))
}

///|
test "document frameset helpers preserve reprocess state" {
  let explicit_html = element("html", children=[
    element("head"),
    element("body"),
  ])
  let explicit_root = document(children=[explicit_html])
  let blocked = Parser::new(
    "",
    explicit_root,
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_eq(blocked.prepare_document_frameset_replacement(), false)
  assert_true(
    blocked.handle_document_frameset_start_tag("frameset", {}, false, 0, 9),
  )
  assert_eq(blocked.errors.length(), 1)
  assert_eq(blocked.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(
    explicit_root.to_html(pretty=false),
    "<html><head></head><body></body></html>",
  )
  let html = element("html")
  let frameset = element("frameset")
  html.append_child(frameset)
  let root = document(children=[html])
  let parser = Parser::new("", root, scripting_enabled=true, xml_coercion=false)
  parser.stack.clear()
  parser.stack.push(root)
  parser.stack.push(html)
  parser.stack.push(frameset)
  parser.frameset_reprocesses_in_body_mode = true
  assert_true(
    parser.handle_document_frameset_start_tag(
      "html",
      { "lang": Some("en") },
      false,
      0,
      5,
    ),
  )
  assert_eq(parser.errors.length(), 1)
  assert_eq(parser.errors[0].code, "unexpected-start-tag")
  guard html.attrs["lang"] is Some("en") else {
    fail("expected reprocessed html attrs to merge onto root html")
  }
  assert_eq(
    parser.handle_document_frameset_start_tag("p", {}, false, 6, 8),
    false,
  )
  assert_eq(parser.errors.length(), 1)
}

///|
test "active formatting helpers respect marker boundaries" {
  let parser = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  parser.append_active_formatting_entry(comment("ignored"))
  assert_eq(parser.active_formatting.length(), 0)
  let before_marker = element("a", attrs={ "href": Some("x") })
  parser.append_active_formatting_entry(before_marker)
  parser.push_active_formatting_marker()
  let after_marker = element("b", attrs={ "class": Some("fresh") })
  parser.append_active_formatting_entry(after_marker)
  assert_eq(parser.active_formatting.length(), 3)
  assert_eq(parser.active_formatting_index("a"), -1)
  assert_eq(parser.active_formatting_index("b"), 2)
  parser.remove_last_active_formatting_by_name("a")
  assert_eq(parser.active_formatting.length(), 3)
  parser.remove_last_active_formatting_by_name("b")
  assert_eq(parser.active_formatting.length(), 2)
  assert_eq(parser.active_formatting_orphan_anchor_index(), -1)
  let orphan_anchor = element("a", attrs={ "href": Some("later") })
  parser.active_formatting.push({
    marker: false,
    name: "a",
    ns: "html",
    attrs: orphan_anchor.attrs.copy(),
    node: orphan_anchor,
  })
  assert_eq(parser.active_formatting_orphan_anchor_index(), 2)
  parser.clear_active_formatting_to_marker()
  assert_eq(parser.active_formatting.length(), 1)
  assert_eq(parser.active_formatting_index("a"), 0)
  let transient = element("span")
  parser.stack.push(transient)
  parser.remove_last_open_element_by_name("span")
  assert_eq(parser.stack.length(), 1)
  let parent = element("div")
  parser.root.append_child(parent)
  parser.stack.push(parent)
  let orphan_strong = element("strong", attrs={ "id": Some("orphan") })
  parser.active_formatting.clear()
  parser.active_formatting.push({
    marker: false,
    name: "em",
    ns: "html",
    attrs: {},
    node: parent,
  })
  parser.active_formatting.push({
    marker: false,
    name: "strong",
    ns: "html",
    attrs: orphan_strong.attrs.copy(),
    node: orphan_strong,
  })
  parser.reconstruct_active_formatting_elements()
  assert_eq(
    parent.to_html(pretty=false),
    "<div><strong id=\"orphan\"></strong></div>",
  )
  assert_eq(parser.stack.length(), 3)
  guard parser.stack.last() is Some(last) else {
    fail("expected reconstructed formatting node on stack")
  }
  assert_eq(last.name, "strong")

  let current_only = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let current_b = element("b")
  current_only.stack.push(current_b)
  current_only.adoption_agency("b", 4)
  assert_eq(current_only.stack.length(), 1)
  assert_eq(current_only.errors.length(), 0)

  let scoped = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let scoped_b = element("b")
  scoped.stack.push(scoped_b)
  scoped.stack.push(element("table"))
  scoped.active_formatting.push({
    marker: false,
    name: "b",
    ns: "html",
    attrs: {},
    node: scoped_b,
  })
  scoped.adoption_agency("b", 7)
  assert_eq(scoped.errors.length(), 1)
  assert_eq(scoped.errors[0].code, "adoption-agency-1.3")
  assert_eq(scoped.stack.length(), 3)
  assert_eq(scoped.active_formatting.length(), 1)
}

///|
test "adoption agency removes non-formatting inner stack nodes" {
  let parser = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let original_b = element("b", attrs={ "data-origin": Some("start") })
  let loose_span = element("span")
  let furthest_block = element("p")
  parser.stack.push(original_b)
  parser.stack.push(loose_span)
  parser.stack.push(furthest_block)
  parser.active_formatting.push({
    marker: false,
    name: "b",
    ns: "html",
    attrs: original_b.attrs.copy(),
    node: original_b,
  })
  parser.adoption_agency("b", 0)
  assert_eq(parser.errors.length(), 1)
  assert_eq(parser.errors[0].code, "adoption-agency-1.3")
  assert_eq(parser.stack_index_by_node(loose_span), -1)
  assert_eq(parser.stack_index_by_node(original_b), -1)
  assert_eq(parser.stack.length(), 2)
  assert_eq(parser.stack_index_by_node(furthest_block), 1)
  assert_eq(
    parser.root.to_html(pretty=false),
    "<p><b data-origin=\"start\"></b></p>",
  )
  assert_eq(parser.active_formatting.length(), 0)
  guard furthest_block.children.length() == 1 else {
    fail("expected replacement formatting child")
  }
  let replacement_b = furthest_block.children[0]
  assert_eq(replacement_b.name, "b")
  assert_true(!physical_equal(replacement_b, original_b))
  guard replacement_b.parent is Some(parent) else {
    fail("expected replacement formatting node to be under furthest block")
  }
  assert_true(physical_equal(parent, furthest_block))
}

///|
test "adoption agency prunes late active inner nodes" {
  let parser = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let original_b = element("b", attrs={ "data-origin": Some("start") })
  let late_i = element("i", attrs={ "data-late": Some("drop") })
  let loose_one = element("span")
  let loose_two = element("span")
  let top_em = element("em", attrs={ "data-top": Some("keep") })
  let furthest_block = element("p")
  parser.stack.push(original_b)
  parser.stack.push(late_i)
  parser.stack.push(loose_one)
  parser.stack.push(loose_two)
  parser.stack.push(top_em)
  parser.stack.push(furthest_block)
  parser.active_formatting.push({
    marker: false,
    name: "b",
    ns: "html",
    attrs: original_b.attrs.copy(),
    node: original_b,
  })
  parser.active_formatting.push({
    marker: false,
    name: "i",
    ns: "html",
    attrs: late_i.attrs.copy(),
    node: late_i,
  })
  parser.active_formatting.push({
    marker: false,
    name: "em",
    ns: "html",
    attrs: top_em.attrs.copy(),
    node: top_em,
  })
  parser.adoption_agency("b", 0)
  assert_eq(parser.errors.length(), 1)
  assert_eq(parser.errors[0].code, "adoption-agency-1.3")
  assert_eq(parser.stack_index_by_node(late_i), -1)
  assert_eq(parser.stack_index_by_node(loose_one), -1)
  assert_eq(parser.stack_index_by_node(loose_two), -1)
  assert_eq(parser.stack_index_by_node(original_b), -1)
  assert_eq(
    parser.root.to_html(pretty=false),
    "<em data-top=\"keep\"><p><b data-origin=\"start\"></b></p></em>",
  )
  assert_eq(parser.active_formatting.length(), 1)
  let remaining = parser.active_formatting[0]
  assert_eq(remaining.name, "em")
  assert_true(!physical_equal(remaining.node, top_em))
}

///|
test "table foster helpers handle detached helper state" {
  let root = fragment()
  let parser = Parser::new("", root, scripting_enabled=true, xml_coercion=false)
  let table = element("table")
  let tbody = element("tbody")
  parser.stack.clear()
  parser.stack.push(root)
  parser.stack.push(table)
  parser.stack.push(tbody)
  assert_true(parser.foster_parent_table_text("x", 0))
  assert_eq(root.to_html(pretty=false), "x")
  assert_eq(parser.errors.length(), 1)
  assert_eq(parser.errors[0].code, "foster-parenting-character")
  parser.report_foster_parented_table_context_text("z", 1)
  assert_eq(parser.errors.length(), 1)
  parser.insert_node_before_open_table(text("y"), 1)
  assert_eq(root.to_html(pretty=false), "xy")

  let blocked = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let blocked_table = element("table")
  let div = element("div")
  blocked.stack.clear()
  blocked.stack.push(blocked.root)
  blocked.stack.push(blocked_table)
  blocked.stack.push(div)
  assert_eq(blocked.handle_nested_table_start_tag("table", 0), false)
  assert_eq(blocked.table_start_foster_mode("p"), 0)

  let open_section = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let section_table = element("table")
  let section = element("tbody")
  open_section.stack.push(section_table)
  open_section.stack.push(section)
  assert_eq(
    open_section.handle_table_context_ignored_end_tag("tbody", 0),
    false,
  )
  assert_true(open_section.handle_table_structural_end_tag("tbody"))
  guard open_section.stack.last() is Some(last) else {
    fail("expected table to remain open after row-group close")
  }
  assert_true(physical_equal(last, section_table))
}

///|
fn stale_template_column_group_parser() -> (Parser, Node) {
  let parser = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let template = element("template")
  let table = element("table")
  parser.root.append_child(template)
  template.append_child(table)
  parser.stack.push(template)
  parser.enable_template_column_group_mode()
  parser.stack.push(table)
  (parser, table)
}

///|
test "template column group mode drops stale inner table state" {
  let (text_parser, text_table) = stale_template_column_group_parser()
  assert_true(text_parser.template_column_group_mode_active())
  assert_eq(text_parser.handle_template_column_group_text("x", 0), false)
  assert_eq(text_parser.template_column_group_mode_active(), false)
  assert_eq(text_parser.errors.length(), 0)
  assert_eq(text_table.children.length(), 0)

  let (start_parser, start_table) = stale_template_column_group_parser()
  assert_eq(
    start_parser.handle_template_column_group_start_tag("col", {}, 0),
    false,
  )
  assert_eq(start_parser.template_column_group_mode_active(), false)
  assert_eq(start_table.children.length(), 0)

  let (end_parser, end_table) = stale_template_column_group_parser()
  assert_eq(end_parser.handle_template_column_group_end_tag("tbody", 0), false)
  assert_eq(end_parser.template_column_group_mode_active(), false)
  assert_eq(end_table.children.length(), 0)

  let detached = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  detached.enable_template_column_group_mode()
  detached.disable_current_template_column_group_mode()
  assert_eq(detached.template_column_group_templates.length(), 0)
}

///|
test "tokenizer eof helper reports empty input origin" {
  let tokenizer = SourceTokenizer::new(
    "",
    collect_errors=true,
    xml_coercion=false,
  )
  assert_true(tokenizer.advance_char() is None)
  assert_eq(tokenizer.pos, 0)
  assert_eq(tokenizer.step(), true)
  tokenizer.parse_characters()
  assert_eq(tokenizer.tokens.length(), 0)
  tokenizer.error_at_eof("eof-before-tag-name")
  assert_eq(tokenizer.errors.length(), 1)
  assert_eq(tokenizer.errors[0].code, "eof-before-tag-name")
  guard tokenizer.errors[0].line is Some(1) else {
    fail("expected empty input EOF line")
  }
  guard tokenizer.errors[0].column is Some(0) else {
    fail("expected empty input EOF column")
  }
}

///|
test "tokenizer attribute helper tolerates delimiter at eof" {
  let tokenizer = SourceTokenizer::new(
    ">",
    collect_errors=true,
    xml_coercion=false,
  )
  let attrs : Map[String, String?] = {}
  tokenizer.parse_attribute(attrs)
  assert_eq(attrs.length(), 0)
  assert_eq(tokenizer.pos, 1)
  assert_eq(tokenizer.errors.length(), 0)
}

///|
test "byte decoder helper falls back to windows1252 for unknown labels" {
  let (decoded, encoding) = decode_supported_html_encoding(
    b"<p>\x80</p>", "x-unknown",
  )
  assert_eq(encoding, "windows-1252")
  assert_eq(decoded, "<p>\u{20AC}</p>")
}

///|
test "text chunk helpers initialize empty chunk arrays" {
  let breaks : Array[Array[String]] = []
  text_chunk_break(breaks)
  assert_eq(breaks.length(), 1)
  assert_eq(breaks[0].length(), 0)
  text_chunk_break(breaks)
  assert_eq(breaks.length(), 1)
  let chunks : Array[Array[String]] = []
  let current = current_text_chunk(chunks)
  assert_eq(chunks.length(), 1)
  current.push("A")
  assert_eq(text_chunks_to_string(chunks, "|", true), "A")
  text_chunk_break(chunks)
  assert_eq(chunks.length(), 2)
  current_text_chunk(chunks).push("B")
  assert_eq(text_chunks_to_string(chunks, "|", true), "A|B")
}

///|
test "pretty text helpers keep empty elements out of text-only path" {
  assert_eq(element_has_only_text_children(element("div")), false)
  let pre = element("pre", children=[text("  a\n<b>&c  ")])
  assert_true(element_has_only_text_children(pre))
  assert_eq(compact_pretty_text_children(pre, '"'), "  a\n&lt;b&gt;&amp;c  ")
  let paragraph = element("p", children=[text("  a\n"), text("  b  ")])
  assert_true(element_has_only_text_children(paragraph))
  assert_eq(compact_pretty_text_children(paragraph, '"'), "a b")
}

///|
test "pretty serializer skips escape-only sentinels inside inline runs" {
  let hidden_text = text("hidden")
  hidden_text.mark_sanitize_escape_only()
  assert_eq(node_to_html_pretty(hidden_text, 0, 2, '"'), "")

  let hidden_run = text("hidden")
  hidden_run.mark_sanitize_escape_only()
  let inline = element("div", children=[hidden_run, text("\n"), text("shown")])
  guard node_to_html_pretty_inline_runs(inline, 0, 2, '"') is Some(rendered) else {
    fail("expected inline run rendering")
  }
  assert_eq(rendered, "<div>\n  shown\n</div>")

  let hidden_only = text("hidden")
  hidden_only.mark_sanitize_escape_only()
  let empty_inline = element("div", children=[hidden_only, text("\n")])
  assert_true(node_to_html_pretty_inline_runs(empty_inline, 0, 2, '"') is None)
}

///|
test "pseudo matcher rejects unknown and blank contains pseudos" {
  let note = comment("note")
  assert_eq(pseudo_selector_matches(note, "hover"), false)
  assert_eq(pseudo_selector_matches(note, "hover(2)"), false)
  assert_eq(pseudo_selector_matches(note, "contains(   )"), false)
}

///|
test "limited selector matcher keeps pseudo parity" {
  let root = fragment(children=[
    comment("note"),
    element("section", children=[
      element("h1", children=[text("Title")]),
      element("p", attrs={ "class": Some("first") }, children=[text("alpha")]),
      element("p", attrs={ "class": Some("second"), "disabled": None }, children=[
        text("needle"),
      ]),
    ]),
  ])
  let note = root.children[0]
  let section = root.children[1]
  let heading = section.children[0]
  let first = section.children[1]
  let second = section.children[2]
  let empty = element("span", children=[text("  "), comment("blank")])
  let limits = default_selector_limits()
  assert_true(matches_selector_list_with_limits(note, ":comment", limits))
  assert_true(matches_selector_list_with_limits(note, ":comment(any)", limits))
  assert_eq(
    matches_selector_list_with_limits(note, ":not(:comment)", limits),
    false,
  )
  assert_true(
    matches_selector_list_with_limits(heading, "h1:first-child", limits),
  )
  assert_true(matches_selector_list_with_limits(second, "p:last-child", limits))
  assert_eq(
    matches_selector_list_with_limits(first, "p:first-child", limits),
    false,
  )
  assert_eq(
    matches_selector_list_with_limits(second, "p:only-child", limits),
    false,
  )
  assert_true(
    matches_selector_list_with_limits(first, "p:first-of-type", limits),
  )
  assert_true(
    matches_selector_list_with_limits(second, "p:last-of-type", limits),
  )
  assert_true(
    matches_selector_list_with_limits(heading, "h1:only-of-type", limits),
  )
  assert_eq(
    matches_selector_list_with_limits(first, "p:only-of-type", limits),
    false,
  )
  assert_true(matches_selector_list_with_limits(second, "*.second", limits))
  assert_true(
    matches_selector_list_with_limits(second, "p.second[disabled]", limits),
  )
  assert_true(matches_selector_list_with_limits(empty, "span:empty", limits))
  assert_true(
    matches_selector_list_with_limits(section, "section:root", limits),
  )
  assert_eq(matches_selector_list_with_limits(second, "*foo", limits), false)
  assert_true(
    matches_selector_list_with_limits(
      second, "section > p:nth-of-type(2)", limits,
    ),
  )
  assert_true(
    matches_selector_list_with_limits(
      second,
      "p:contains(needle)",
      SelectorLimits::new(max_match_bytes=1000),
    ),
  )
  let context = SelectorMatchContext::new(limits)
  context.tick(steps=0)
  assert_eq(
    pseudo_selector_matches_with_context(second, "hover(2)", context, 0),
    false,
  )
  assert_eq(
    pseudo_selector_matches_with_context(second, "hover", context, 0),
    false,
  )
}

///|
test "limited selector context fails closed on malformed branches" {
  let root = fragment(children=[
    element("section", children=[
      element("p", attrs={ "class": Some("first") }, children=[text("alpha")]),
      element("p", attrs={ "id": Some("second") }, children=[text("beta")]),
    ]),
  ])
  let section = root.children[0]
  let first = section.children[0]
  let second = section.children[1]
  let context = SelectorMatchContext::new(default_selector_limits())
  assert_eq(matches_simple_selector_with_context(second, "", context, 0), false)
  assert_eq(
    matches_simple_selector_with_context(second, "*foo", context, 0),
    false,
  )
  assert_eq(
    matches_simple_selector_with_context(second, "p[href]*", context, 0),
    false,
  )
  assert_eq(
    matches_simple_selector_with_context(second, "p[", context, 0),
    false,
  )
  assert_eq(
    matches_simple_selector_with_context(second, "p[id]*", context, 0),
    false,
  )
  assert_eq(
    matches_simple_selector_with_context(second, "p.", context, 0),
    false,
  )
  assert_eq(
    matches_complex_selector_with_context(second, "", context, 0),
    false,
  )
  assert_eq(
    matches_complex_selector_with_context(section, "main > section", context, 0),
    false,
  )
  assert_eq(
    matches_complex_selector_with_context(
      element("section"),
      "main > section",
      context,
      0,
    ),
    false,
  )
  assert_eq(
    matches_complex_selector_with_context(first, "h1 + p", context, 0),
    false,
  )
  let cyclic_root = element("div")
  let cyclic_child = element("span")
  cyclic_root.append_child(cyclic_child)
  cyclic_child.children.push(cyclic_root)
  cyclic_root.parent = Some(cyclic_child)
  assert_eq(
    matches_complex_selector_with_context(cyclic_child, "em span", context, 0),
    false,
  )
  selector_validate_simple_parse_depth("", default_selector_limits(), 0)
  assert_eq(
    previous_element_sibling_with_context(element("p"), context) is None,
    true,
  )
  assert_eq(
    previous_matching_sibling_with_context(element("p"), "p", context, 0)
    is None,
    true,
  )
  let depth_result = try? matches_complex_selector_with_context(
    second,
    "p",
    SelectorMatchContext::new(SelectorLimits::new(max_match_depth=0)),
    1,
  )
  match depth_result {
    Err(SelectorError(message)) =>
      assert_eq(message, "Selector nesting is too deep")
    _ => fail("expected selector match depth error")
  }
}

///|
test "nth selector helpers reject empty signed integer fragments" {
  assert_true(parse_signed_int_view("") is None)
  guard parse_signed_int_view("+12") is Some(positive) else {
    fail("expected signed positive integer")
  }
  assert_eq(positive, 12)
  guard parse_signed_int_view("-3") is Some(negative) else {
    fail("expected signed negative integer")
  }
  assert_true(negative == -3)
  assert_true(parse_nth_expression("") is None)
  assert_true(parse_nth_expression("2n+") is None)
  guard parse_nth_expression("n") is Some((plain_a, plain_b)) else {
    fail("expected plain n formula")
  }
  assert_eq(plain_a, 1)
  assert_eq(plain_b, 0)
  guard parse_nth_expression("-n+3") is Some((a, b)) else {
    fail("expected negative nth coefficient")
  }
  assert_true(a == -1)
  assert_eq(b, 3)
}

///|
test "serializer hex digit helper keeps defensive fallback" {
  assert_eq(hex_digit_upper(0), '0')
  assert_eq(hex_digit_upper(15), 'F')
  assert_eq(hex_digit_upper(16), '0')
}

///|
test "transform private helpers keep defensive no-op behavior" {
  assert_eq(decide_action_label(Keep), "keep")
  assert_eq(
    node_has_foreign_namespace(
      make_node(Element, "p", None, {}, "", None, None, false, []),
    ),
    false,
  )
  assert_eq(prune_empty_node_is_effectively_empty(text("x"), true), false)
  let text_root = text("x")
  apply_prune_empty_transform(
    text_root,
    TransformSpec::prune_empty("*"),
    default_selector_limits(),
  )
  assert_eq(text_root.data, "x")
  ignore(
    apply_transform(
      fragment(children=[element("p")]),
      TransformSpec::prune_empty("p"),
      default_selector_limits(),
    ),
  )
  ignore(
    apply_transform(
      fragment(children=[element("p")]),
      TransformSpec::stage([TransformSpec::drop("p")]),
      default_selector_limits(),
    ),
  )
  assert_true(
    decide_transform_action(element("p"), make_transform_spec(DecideNode))
    is Keep,
  )
  apply_edit_document_transform(
    fragment(),
    make_transform_spec(EditDocumentRoot),
  )
  apply_edit_transform(element("p"), make_transform_spec(EditElement))
  assert_eq(
    apply_edit_attrs_transform(
      element("p"),
      make_transform_spec(EditAttributes),
    ),
    false,
  )
  assert_eq(
    apply_set_attrs_transform(element("p"), make_transform_spec(SetAttributes)),
    false,
  )
  let mixed = fragment(children=[text("x")])
  apply_drop_kind_transform(mixed, Text, TransformSpec::drop_comments())
  assert_eq(mixed.children.length(), 0)
  let unmatched_kind = fragment(children=[element("p")])
  transform_children(
    unmatched_kind,
    make_transform_spec(SanitizeTree, selector="p"),
    default_selector_limits(),
  )
  assert_eq(unmatched_kind.children.length(), 1)
}

///|
test "selector helper fragments fail closed on malformed syntax" {
  let node = element("div", attrs={
    "class": Some("alpha beta"),
    "href": Some("http://example.com"),
    "id": Some("main"),
  })
  assert_eq(attribute_selector_matches(node, ""), false)
  assert_eq(attribute_selector_matches(node, "href!=http://example.com"), false)
  assert_eq(
    attribute_selector_matches(node, "href=http://example.com bad"),
    false,
  )
  assert_eq(matches_simple_selector(node, ""), false)
  assert_eq(matches_simple_selector(node, "*div"), false)
  assert_eq(matches_simple_selector(node, "div["), false)
  assert_eq(matches_simple_selector(node, "div."), false)
  assert_eq(matches_simple_selector(node, "div[href]*"), false)
  assert_eq(simple_selector_is_valid(""), false)
  assert_eq(simple_selector_is_valid("div["), false)
  assert_eq(simple_selector_is_valid("div[href]*"), false)
  assert_true(split_complex_selector("") is None)
  assert_eq(matches_complex_selector(node, ""), false)
}

///|
test "url scheme helpers ignore C0 characters in scheme prefixes" {
  guard extract_url_scheme("\tHTTPS:") is Some(tabbed_scheme) else {
    fail("expected tabbed URL scheme")
  }
  assert_eq(tabbed_scheme, "https")
  guard extract_url_scheme("h ttps:") is Some(spaced_scheme) else {
    fail("expected spaced URL scheme")
  }
  assert_eq(spaced_scheme, "https")
  assert_true(extract_url_scheme(" \t:relative") is None)
  assert_true(url_scheme_prefix_is_valid("h ttps:relative", 6))
  assert_eq(url_scheme_prefix_is_valid(" \t:relative", 2), false)
  assert_eq(has_invalid_scheme_like_prefix("h ttps:relative"), false)
  assert_true(has_invalid_scheme_like_prefix("ht^tps:relative"))
}

///|
test "url authority helpers reject empty hosts" {
  assert_true(extract_authority_host("https://", 8, 8) is None)
  assert_true(extract_named_authority_host("https://", 8, 8) is None)
  assert_true(extract_absolute_url_host("https://") is None)
}

///|
test "url authority helpers fail closed on surrogate-split offsets" {
  let host = "x😀"
  let mid_surrogate = 2
  assert_eq(url_authority_end("x😀/", mid_surrogate), 4)
  assert_eq(authority_host_start(host, mid_surrogate, host.length()), 2)
  assert_true(
    extract_authority_host(host, mid_surrogate, host.length()) is None,
  )
  assert_true(
    extract_named_authority_host(host, mid_surrogate, host.length()) is None,
  )
  assert_true(extract_bracketed_authority_host("x😀]", 1, 4) is None)
}

///|
test "sanitize_dom clears mixed-case style rawtext resource loads" {
  let policy = SanitizationPolicy::new(
    ["style"],
    allowed_attributes={ "style": [] },
    drop_content_tags=[],
  )
  let style = make_node(
    Element,
    "StYlE",
    Some("html"),
    {},
    "",
    None,
    None,
    false,
    [text("@import 'https://evil.example/x.css';")],
  )
  let clean = sanitize_dom(style, policy~)
  assert_eq(clean.to_html(pretty=false), "<StYlE></StYlE>")
  assert_eq(clean.children.length(), 0)
}

///|
test "math text integration child exceptions require math elements" {
  assert_eq(is_math_text_integration_child_exception(text("x")), false)
  assert_eq(is_math_text_integration_child_exception(comment("x")), false)
  assert_true(
    is_math_text_integration_child_exception(element("mglyph", ns="math")),
  )
  assert_true(
    is_math_text_integration_child_exception(element("malignmark", ns="math")),
  )
  assert_eq(
    is_math_text_integration_child_exception(element("mglyph", ns="html")),
    false,
  )
  assert_eq(
    is_math_text_integration_child_exception(element("malignmark", ns="html")),
    false,
  )
  assert_eq(
    is_math_text_integration_child_exception(element("mi", ns="math")),
    false,
  )
}

///|
fn assert_script_scan(
  value : StringView,
  expected : String,
  end_start : Int?,
) -> Unit raise {
  let scan = scan_script_text(value, 0)
  assert_eq(scan.data, expected)
  match end_start {
    Some(expected_end) => {
      guard scan.end_start is Some(actual_end) else {
        fail("expected script end tag")
      }
      assert_eq(actual_end, expected_end)
    }
    None => assert_true(scan.end_start is None)
  }
  assert_eq(scan.errors.length(), 0)
}

///|
test "script text scanner covers escaped and double escaped edge states" {
  assert_script_scan("<!---x</script>", "<!---x", Some(6))
  assert_script_scan("<!---<x</script>", "<!---<x", Some(7))
  assert_script_scan("<!----x</script>", "<!----x", Some(7))
  assert_script_scan("<!-----x</script>", "<!-----x", Some(8))
  assert_script_scan("<!----<x</script>", "<!----<<x", Some(8))
  assert_script_scan("<!--</not</script>", "<!--</not", Some(9))
  assert_script_scan("<!--<!</script>", "<!--<!", Some(6))
  assert_script_scan("abc</script x", "abc", Some(3))
  assert_script_scan(
    "<!--<script>-x</script>z</script>",
    "<!--<script>-x</script>z",
    Some(24),
  )
  assert_script_scan(
    "<!--<script>-<!x</script>tail</script>",
    "<!--<script>-<!x</script>tail",
    Some(29),
  )
  assert_script_scan("<!--<script>--></script>", "<!--<script>-->", Some(15))
  assert_script_scan(
    "<!--<script>---x</script>tail</script>",
    "<!--<script>---x</script>tail",
    Some(29),
  )
  assert_script_scan(
    "<!--<script>--<x</script>tail</script>",
    "<!--<script>--<x",
    Some(16),
  )
  assert_script_scan(
    "<!--<script>--x</script>tail</script>",
    "<!--<script>--x</script>tail",
    Some(28),
  )
  assert_script_scan(
    "<!--<script><!x</script>tail</script>",
    "<!--<script><!x</script>tail",
    Some(28),
  )
  assert_script_scan(
    "<!--<script></not</script>z</script>",
    "<!--<script></not</script>z",
    Some(27),
  )
  assert_script_scan(
    "<!--<script></style x</script>tail</script>",
    "<!--<script></style x</script>tail",
    Some(34),
  )
  assert_script_scan(
    "<!--<script><x</script>z</script>",
    "<!--<script><x",
    Some(14),
  )
  assert_script_scan(
    "<!--<script x</script>tail</script>",
    "<!--<script x</script>tail",
    Some(26),
  )
  assert_script_scan(
    "<!--<script\tx</script>tail</script>",
    "<!--<script\tx</script>tail",
    Some(26),
  )
  assert_script_scan(
    "<!--<script\u{000C}>x</script>tail</script>",
    "<!--<script\u{000C}>x</script>tail",
    Some(27),
  )
  assert_script_scan(
    "<!--<script/>x</script>tail</script>",
    "<!--<script/>x</script>tail",
    Some(27),
  )
  assert_script_scan(
    "<!--<scriptx>x</script>tail</script>",
    "<!--<scriptx>x",
    Some(14),
  )
  assert_script_scan("<!--<script><", "<!--<script><", None)
}

///|
test "scanner helpers fail closed on surrogate-split offsets" {
  let value = "x😀>"
  let mid_surrogate = 2
  let comment_scan = scan_comment_data(value, mid_surrogate)
  assert_eq(comment_scan.data, "")
  assert_eq(comment_scan.end, value.length())
  assert_true(comment_scan.eof)
  assert_eq(comment_scan.errors.length(), 1)
  assert_eq(comment_scan.errors[0].code, "eof-in-comment")

  let normalized = StringBuilder::new()
  assert_eq(
    write_normalized_char(value, mid_surrogate, normalized),
    mid_surrogate,
  )
  assert_eq(normalized.to_string(), "")

  let script_out = StringBuilder::new()
  let script_errors : Array[SpecialTextError] = []
  assert_eq(
    write_script_text_char(value, mid_surrogate, script_out, script_errors),
    mid_surrogate,
  )
  assert_eq(script_out.to_string(), "")
  assert_eq(script_errors.length(), 0)

  assert_true(find_markup_close(value, mid_surrogate) is None)
  assert_true(
    find_matching_end_tag("x😀</script>", mid_surrogate, "script") is None,
  )
  assert_eq(
    matching_end_tag_error_pos("x😀</script>", mid_surrogate),
    eof_error_pos("x😀</script>"),
  )

  let doctype_errors : Array[DoctypeExternalError] = []
  assert_eq(
    normalize_doctype_value(
      value,
      mid_surrogate,
      value.length(),
      doctype_errors,
    ),
    "",
  )
  assert_eq(doctype_errors.length(), 0)
  let (name, name_errors) = parse_lower_name_value_replacing_nulls(
    value,
    mid_surrogate,
    value.length(),
  )
  assert_eq(name, "")
  assert_eq(name_errors.length(), 0)
}

///|
fn assert_svg_tag_adjustment(
  input : StringView,
  expected : String,
) -> Unit raise {
  assert_eq(adjusted_svg_tag_name(input), expected)
}

///|
fn assert_svg_attr_adjustment(
  input : StringView,
  expected : String,
) -> Unit raise {
  assert_eq(adjusted_svg_attribute_name(input), expected)
}

///|
fn assert_foreign_attr_adjustment(
  input : StringView,
  expected : String,
) -> Unit raise {
  assert_eq(adjusted_foreign_attribute_name(input), expected)
}

///|
test "foreign adjustment helper tables match spec names" {
  assert_svg_tag_adjustment("clippath", "clipPath")
  assert_svg_tag_adjustment("feblend", "feBlend")
  assert_svg_tag_adjustment("fecolormatrix", "feColorMatrix")
  assert_svg_tag_adjustment("fecomponenttransfer", "feComponentTransfer")
  assert_svg_tag_adjustment("fecomposite", "feComposite")
  assert_svg_tag_adjustment("feconvolvematrix", "feConvolveMatrix")
  assert_svg_tag_adjustment("fediffuselighting", "feDiffuseLighting")
  assert_svg_tag_adjustment("fedisplacementmap", "feDisplacementMap")
  assert_svg_tag_adjustment("fedistantlight", "feDistantLight")
  assert_svg_tag_adjustment("feflood", "feFlood")
  assert_svg_tag_adjustment("fefunca", "feFuncA")
  assert_svg_tag_adjustment("fefuncb", "feFuncB")
  assert_svg_tag_adjustment("fefuncg", "feFuncG")
  assert_svg_tag_adjustment("fefuncr", "feFuncR")
  assert_svg_tag_adjustment("fegaussianblur", "feGaussianBlur")
  assert_svg_tag_adjustment("fespotlight", "feSpotLight")
  assert_svg_tag_adjustment("fetile", "feTile")
  assert_svg_tag_adjustment("feturbulence", "feTurbulence")
  assert_svg_tag_adjustment("unknown", "unknown")
  assert_svg_attr_adjustment("diffuseconstant", "diffuseConstant")
  assert_svg_attr_adjustment("edgemode", "edgeMode")
  assert_svg_attr_adjustment("filterunits", "filterUnits")
  assert_svg_attr_adjustment("glyphref", "glyphRef")
  assert_svg_attr_adjustment("keysplines", "keySplines")
  assert_svg_attr_adjustment("keytimes", "keyTimes")
  assert_svg_attr_adjustment("lengthadjust", "lengthAdjust")
  assert_svg_attr_adjustment("limitingconeangle", "limitingConeAngle")
  assert_svg_attr_adjustment("markerheight", "markerHeight")
  assert_svg_attr_adjustment("markerunits", "markerUnits")
  assert_svg_attr_adjustment("markerwidth", "markerWidth")
  assert_svg_attr_adjustment("maskcontentunits", "maskContentUnits")
  assert_svg_attr_adjustment("maskunits", "maskUnits")
  assert_svg_attr_adjustment("numoctaves", "numOctaves")
  assert_svg_attr_adjustment("pathlength", "pathLength")
  assert_svg_attr_adjustment("patterncontentunits", "patternContentUnits")
  assert_svg_attr_adjustment("patterntransform", "patternTransform")
  assert_svg_attr_adjustment("patternunits", "patternUnits")
  assert_svg_attr_adjustment("pointsatx", "pointsAtX")
  assert_svg_attr_adjustment("pointsaty", "pointsAtY")
  assert_svg_attr_adjustment("pointsatz", "pointsAtZ")
  assert_svg_attr_adjustment("preservealpha", "preserveAlpha")
  assert_svg_attr_adjustment("preserveaspectratio", "preserveAspectRatio")
  assert_svg_attr_adjustment("primitiveunits", "primitiveUnits")
  assert_svg_attr_adjustment("refx", "refX")
  assert_svg_attr_adjustment("refy", "refY")
  assert_svg_attr_adjustment("repeatcount", "repeatCount")
  assert_svg_attr_adjustment("repeatdur", "repeatDur")
  assert_svg_attr_adjustment("requiredextensions", "requiredExtensions")
  assert_svg_attr_adjustment("requiredfeatures", "requiredFeatures")
  assert_svg_attr_adjustment("specularconstant", "specularConstant")
  assert_svg_attr_adjustment("specularexponent", "specularExponent")
  assert_svg_attr_adjustment("spreadmethod", "spreadMethod")
  assert_svg_attr_adjustment("startoffset", "startOffset")
  assert_svg_attr_adjustment("stddeviation", "stdDeviation")
  assert_svg_attr_adjustment("stitchtiles", "stitchTiles")
  assert_svg_attr_adjustment("surfacescale", "surfaceScale")
  assert_svg_attr_adjustment("systemlanguage", "systemLanguage")
  assert_svg_attr_adjustment("tablevalues", "tableValues")
  assert_svg_attr_adjustment("targetx", "targetX")
  assert_svg_attr_adjustment("targety", "targetY")
  assert_svg_attr_adjustment("textlength", "textLength")
  assert_svg_attr_adjustment("viewbox", "viewBox")
  assert_svg_attr_adjustment("viewtarget", "viewTarget")
  assert_svg_attr_adjustment("xchannelselector", "xChannelSelector")
  assert_svg_attr_adjustment("ychannelselector", "yChannelSelector")
  assert_svg_attr_adjustment("zoomandpan", "zoomAndPan")
  assert_svg_attr_adjustment("plain", "plain")
  assert_foreign_attr_adjustment("xlink:title", "xlink:title")
  assert_foreign_attr_adjustment("xlink:type", "xlink:type")
  assert_foreign_attr_adjustment("xml:lang", "xml:lang")
  assert_foreign_attr_adjustment("xml:space", "xml:space")
  assert_foreign_attr_adjustment("xmlns", "xmlns")
  assert_foreign_attr_adjustment("xmlns:xlink", "xmlns:xlink")
  assert_foreign_attr_adjustment("plain", "plain")
  let custom = prepare_foreign_attrs("custom", {
    "plain": Some("p"),
    "xlink:title": Some("t"),
  })
  guard custom["plain"] is Some("p") else {
    fail("expected custom namespace attr to stay unchanged")
  }
  guard custom["xlink:title"] is Some("t") else {
    fail("expected foreign attr to be preserved")
  }
  let parser = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  parser.stack.push(element("svg", ns="svg"))
  assert_eq(parser.start_tag_namespace("g"), "svg")
}

///|
fn assert_markdown_line_start_escape(
  value : StringView,
  replacement : String,
  consumed : Int,
) -> Unit raise {
  guard markdown_escape_line_start(value) is Some((actual, actual_consumed)) else {
    fail("expected markdown line-start escape")
  }
  assert_eq(actual, replacement)
  assert_eq(actual_consumed, consumed)
}

///|
test "markdown helper edge cases match reference" {
  assert_true(markdown_escape_line_start("") is None)
  assert_markdown_line_start_escape("# heading", "\\#", 1)
  assert_true(markdown_escape_line_start("#heading") is None)
  assert_markdown_line_start_escape("> quote", "\\>", 1)
  assert_markdown_line_start_escape("- item", "\\-", 1)
  assert_true(markdown_escape_line_start("-x") is None)
  assert_markdown_line_start_escape("+ item", "\\+", 1)
  assert_true(markdown_escape_line_start("+item") is None)
  assert_markdown_line_start_escape("1. item", "1\\.", 2)
  assert_markdown_line_start_escape("2) item", "2\\)", 2)
  assert_markdown_line_start_escape("12. item", "12\\.", 3)
  assert_markdown_line_start_escape("~~~", "\\~", 1)
  assert_true(markdown_escape_line_start("~~") is None)
  assert_markdown_line_start_escape("```", "\\`", 1)
  assert_true(markdown_escape_line_start("``") is None)
  assert_markdown_line_start_escape("---", "\\-", 1)
  assert_markdown_line_start_escape("===", "\\=", 1)
  assert_true(markdown_escape_line_start("=x") is None)
  assert_true(markdown_escape_line_start("plain text") is None)
  assert_eq(
    markdown_thematic_or_setext_line("   ", '-', minimum_markers=3),
    false,
  )
  assert_true(markdown_thematic_or_setext_line("- - -", '-', minimum_markers=3))
  assert_eq(
    markdown_thematic_or_setext_line("- - x", '-', minimum_markers=3),
    false,
  )
  assert_eq(markdown_link_destination(""), "")
  assert_eq(markdown_link_destination("   "), "")
  assert_eq(markdown_link_destination("https://e.com/x"), "https://e.com/x")
  assert_eq(
    markdown_link_destination("https://e.com/a b"),
    "<https://e.com/a%20b>",
  )
  assert_eq(
    markdown_link_destination("https://e.com/a\tb"),
    "<https://e.com/a%09b>",
  )
  assert_eq(
    markdown_link_destination("https://e.com/a\nb"),
    "<https://e.com/a%0Ab>",
  )
  assert_eq(
    markdown_link_destination("https://e.com/a\rb"),
    "<https://e.com/a%0Db>",
  )
  assert_eq(
    markdown_link_destination("https://e.com/a\u{000C}b"),
    "https://e.com/a\u{000C}b",
  )
  assert_eq(
    markdown_link_destination("https://e.com/a\u{000B}b"),
    "https://e.com/a\u{000B}b",
  )
  assert_eq(
    markdown_collect_text(
      element("code", children=[comment("skip"), text("x"), doctype()]),
    ),
    "x",
  )
  let builder = MarkdownBuilder::new()
  builder.raw("a\n\n\n")
  assert_eq(builder.newline_count, 2)
  assert_eq(builder.pending_space, false)
  assert_eq(builder.finish(), "a")
  let leading_space = MarkdownBuilder::new()
  leading_space.text("   a")
  assert_eq(leading_space.finish(), "a")
  let raw_after_pending_space = MarkdownBuilder::new()
  raw_after_pending_space.text("a ")
  raw_after_pending_space.raw("**")
  raw_after_pending_space.raw("b")
  assert_eq(raw_after_pending_space.finish(), "a **b")
  let raw_newline_after_pending_space = MarkdownBuilder::new()
  raw_newline_after_pending_space.text("a ")
  raw_newline_after_pending_space.raw("\n")
  assert_eq(raw_newline_after_pending_space.finish(), "a")
}
