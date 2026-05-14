// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "parser cursor helpers use utf16 offsets and safe fallbacks" {
  let parser = Parser::new(
    "😀",
    @dom.fragment(),
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
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_eq(source_parser.source_tag_slice(0, 4), "<p😀>")
  source_parser.append_sanitize_escape_source_text(0, 4)
  assert_eq(source_parser.root.children.length(), 1)
  assert_eq(source_parser.root.children[0].data, "<p😀")
  let text_parser = Parser::new(
    "a😀\u{0000}b",
    @dom.fragment(),
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
  guard text_node_without_leading_ascii_whitespace(@dom.text(" \t😀body"))
    is Some(stripped) else {
    fail("expected stripped text node")
  }
  assert_eq(stripped.data, "😀body")
  let (leading, rest) = split_text_node_leading_ascii_whitespace(
    @dom.text(" \t😀body"),
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
test "parser insertion helpers keep omitted origins optional" {
  let parser = Parser::new(
    "",
    @dom.fragment(),
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
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let template = @dom.element("template")
  template_parser.stack.push(template)
  assert_true(template_parser.handle_template_end_tag("template", 0))
  assert_true(template.source_end_tag is None)
  assert_eq(template_parser.stack.length(), 1)

  let attr_parser = Parser::new(
    ">",
    @dom.fragment(),
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
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let div = @dom.element("div")
  parser.stack.push(div)
  parser.foreign_table_row_recovery_mode = true
  parser.report_foreign_table_row_recovery_text("x", 0)
  assert_eq(parser.errors.length(), 0)

  let parent = @dom.element("frameset")
  let stale = @dom.element("div")
  let child = @dom.element("frame")
  child.parent = Some(stale)
  detach_removed_frameset_replacement_child(parent, child)
  guard child.parent is Some(actual_parent) else {
    fail("expected stale parent link to stay attached")
  }
  assert_true(physical_equal(actual_parent, stale))
}

///|
test "document scaffold text helpers preserve whitespace boundaries" {
  assert_true(
    text_node_without_leading_ascii_whitespace(@dom.text(" \t\n")) is None,
  )
  guard text_node_without_leading_ascii_whitespace(@dom.text(" \tbody"))
    is Some(stripped) else {
    fail("expected stripped body text")
  }
  assert_eq(stripped.data, "body")
  let body = @dom.text("body")
  let (no_leading, unchanged) = split_text_node_leading_ascii_whitespace(body)
  assert_true(no_leading is None)
  guard unchanged is Some(actual) else { fail("expected original body text") }
  assert_true(physical_equal(actual, body))
  let (all_leading, empty_rest) = split_text_node_leading_ascii_whitespace(
    @dom.text(" \n"),
  )
  guard all_leading is Some(leading_only) else {
    fail("expected all-whitespace leading node")
  }
  assert_eq(leading_only.data, " \n")
  assert_true(empty_rest is None)
  let (leading, rest) = split_text_node_leading_ascii_whitespace(
    @dom.text(" \nBody"),
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
  let primary = @dom.element("html", attrs={ "lang": Some("en") }, children=[
    @dom.element("head", children=[
      @dom.element("title", children=[@dom.text("T")]),
    ]),
    @dom.element("body", children=[@dom.text("A")]),
  ])
  let sibling = @dom.element(
    "html",
    attrs={ "dir": Some("ltr"), "lang": Some("fr") },
    children=[
      @dom.element("html", attrs={ "data-root": Some("sibling") }, children=[
        @dom.element("body", attrs={ "id": Some("merged") }, children=[
          @dom.text("B"),
        ]),
      ]),
    ],
  )
  let root = @dom.document(children=[primary, sibling])
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
  assert_eq(@ser.to_html(body, pretty=false), "<body id=\"merged\">AB</body>")
}

///|
test "fragment context unwrap helper preserves sibling nodes" {
  let leading = @dom.comment("before")
  let wrapper_child = @dom.element("tbody", children=[
    @dom.element("tr", children=[@dom.element("td", children=[@dom.text("x")])]),
  ])
  let wrapper = @dom.element("table", children=[wrapper_child])
  let trailing = @dom.text("after")
  let root = @dom.fragment(children=[leading, wrapper, trailing])
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
    @dom.document(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  parser.pending_document_html_attrs["lang"] = Some("en")
  parser.apply_pending_document_html_attrs()
  assert_eq(parser.root.children.length(), 0)
  let html = @dom.element("html", attrs={ "dir": Some("ltr") })
  parser.root.append_child(html)
  parser.apply_pending_document_html_attrs()
  guard html.attrs["lang"] is Some("en") else {
    fail("expected pending html attrs to survive missing shell")
  }
  guard html.attrs["dir"] is Some("ltr") else {
    fail("expected existing html attrs to survive pending merge")
  }
  let root = @dom.document(children=[@dom.comment("tail")])
  let paragraph = @dom.element("p", children=[@dom.text("x")])
  append_post_body_html_children(root, [paragraph])
  assert_eq(@ser.to_html(root, pretty=false), "<!--tail--><p>x</p>")
  guard paragraph.parent() is Some(parent) else {
    fail("expected appended post-body child parent")
  }
  assert_true(physical_equal(parent, root))
  let nested_before_body = @dom.element("html", children=[
    @dom.comment("c"),
    @dom.element("html", children=[
      @dom.element("meta", attrs={ "name": Some("x") }),
    ]),
  ])
  assert_true(html_fragment_child_is_before_body(nested_before_body))
  let nested_after_body = @dom.element("html", children=[
    @dom.element("html", children=[@dom.element("body")]),
  ])
  assert_eq(html_fragment_child_is_before_body(nested_after_body), false)
  let fragment_parser = Parser::new(
    "",
    @dom.fragment(),
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
    @dom.document(children=[@dom.element("html")]),
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_true(document_parser.document_has_element_child())
  let head = @dom.element("head")
  let head_parser = Parser::new(
    "",
    head,
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_eq(head_parser.current_is_document_head(), false)
  let shell = @dom.fragment()
  shell.append_child(head)
  head_parser.stack.clear()
  assert_true(head_parser.current_is_document_head())
  assert_eq(head_parser.close_current_document_head_for_start("p", 0), false)
  assert_eq(head_parser.stack.length(), 0)

  let noscript_parser = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=false,
    xml_coercion=false,
  )
  let body = @dom.element("body")
  let noscript = @dom.element("noscript")
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
  let explicit_html = @dom.element("html", children=[
    @dom.element("head"),
    @dom.element("body"),
  ])
  let explicit_root = @dom.document(children=[explicit_html])
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
    @ser.to_html(explicit_root, pretty=false),
    "<html><head></head><body></body></html>",
  )
  let html = @dom.element("html")
  let frameset = @dom.element("frameset")
  html.append_child(frameset)
  let root = @dom.document(children=[html])
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
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  parser.append_active_formatting_entry(@dom.comment("ignored"))
  assert_eq(parser.active_formatting.length(), 0)
  let before_marker = @dom.element("a", attrs={ "href": Some("x") })
  parser.append_active_formatting_entry(before_marker)
  parser.push_active_formatting_marker()
  let after_marker = @dom.element("b", attrs={ "class": Some("fresh") })
  parser.append_active_formatting_entry(after_marker)
  assert_eq(parser.active_formatting.length(), 3)
  assert_eq(parser.active_formatting_index("a"), -1)
  assert_eq(parser.active_formatting_index("b"), 2)
  parser.remove_last_active_formatting_by_name("a")
  assert_eq(parser.active_formatting.length(), 3)
  parser.remove_last_active_formatting_by_name("b")
  assert_eq(parser.active_formatting.length(), 2)
  assert_eq(parser.active_formatting_orphan_anchor_index(), -1)
  let orphan_anchor = @dom.element("a", attrs={ "href": Some("later") })
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
  let transient = @dom.element("span")
  parser.stack.push(transient)
  parser.remove_last_open_element_by_name("span")
  assert_eq(parser.stack.length(), 1)
  let parent = @dom.element("div")
  parser.root.append_child(parent)
  parser.stack.push(parent)
  let orphan_strong = @dom.element("strong", attrs={ "id": Some("orphan") })
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
    @ser.to_html(parent, pretty=false),
    "<div><strong id=\"orphan\"></strong></div>",
  )
  assert_eq(parser.stack.length(), 3)
  guard parser.stack.last() is Some(last) else {
    fail("expected reconstructed formatting node on stack")
  }
  assert_eq(last.name, "strong")

  let current_only = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let current_b = @dom.element("b")
  current_only.stack.push(current_b)
  current_only.adoption_agency("b", 4)
  assert_eq(current_only.stack.length(), 1)
  assert_eq(current_only.errors.length(), 0)

  let scoped = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let scoped_b = @dom.element("b")
  scoped.stack.push(scoped_b)
  scoped.stack.push(@dom.element("table"))
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
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let original_b = @dom.element("b", attrs={ "data-origin": Some("start") })
  let loose_span = @dom.element("span")
  let furthest_block = @dom.element("p")
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
    @ser.to_html(parser.root, pretty=false),
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
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let original_b = @dom.element("b", attrs={ "data-origin": Some("start") })
  let late_i = @dom.element("i", attrs={ "data-late": Some("drop") })
  let loose_one = @dom.element("span")
  let loose_two = @dom.element("span")
  let top_em = @dom.element("em", attrs={ "data-top": Some("keep") })
  let furthest_block = @dom.element("p")
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
    @ser.to_html(parser.root, pretty=false),
    "<em data-top=\"keep\"><p><b data-origin=\"start\"></b></p></em>",
  )
  assert_eq(parser.active_formatting.length(), 1)
  let remaining = parser.active_formatting[0]
  assert_eq(remaining.name, "em")
  assert_true(!physical_equal(remaining.node, top_em))
}

///|
test "table foster helpers handle detached helper state" {
  let root = @dom.fragment()
  let parser = Parser::new("", root, scripting_enabled=true, xml_coercion=false)
  let table = @dom.element("table")
  let tbody = @dom.element("tbody")
  parser.stack.clear()
  parser.stack.push(root)
  parser.stack.push(table)
  parser.stack.push(tbody)
  assert_true(parser.foster_parent_table_text("x", 0))
  assert_eq(@ser.to_html(root, pretty=false), "x")
  assert_eq(parser.errors.length(), 1)
  assert_eq(parser.errors[0].code, "foster-parenting-character")
  parser.report_foster_parented_table_context_text("z", 1)
  assert_eq(parser.errors.length(), 1)
  parser.insert_node_before_open_table(@dom.text("y"), 1)
  assert_eq(@ser.to_html(root, pretty=false), "xy")

  let blocked = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let blocked_table = @dom.element("table")
  let div = @dom.element("div")
  blocked.stack.clear()
  blocked.stack.push(blocked.root)
  blocked.stack.push(blocked_table)
  blocked.stack.push(div)
  assert_eq(blocked.handle_nested_table_start_tag("table", 0), false)
  assert_eq(blocked.table_start_foster_mode("p"), 0)

  let open_section = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let section_table = @dom.element("table")
  let section = @dom.element("tbody")
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
fn stale_template_column_group_parser() -> (Parser, @dom.Node) {
  let parser = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let template = @dom.element("template")
  let table = @dom.element("table")
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
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  detached.enable_template_column_group_mode()
  detached.disable_current_template_column_group_mode()
  assert_eq(detached.template_column_group_templates.length(), 0)
}

///|
test "sanitize_dom clears mixed-case style rawtext resource loads" {
  let policy = @san.SanitizationPolicy::new(
    ["style"],
    allowed_attributes={ "style": [] },
    drop_content_tags=[],
  )
  let style = @dom.element("StYlE", children=[
    @dom.text("@import 'https://evil.example/x.css';"),
  ])
  let clean = @san.sanitize_dom(style, policy~)
  assert_eq(@ser.to_html(clean, pretty=false), "<StYlE></StYlE>")
  assert_eq(clean.children.length(), 0)
}
