///|
test "template content keeps table structural children" {
  let row = @html_parser.parse_fragment(
    "<template><tr><td>x</td></tr></template>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<template><tr><td>x</td></tr></template>",
  )
  assert_eq(row.errors.length(), 1)
  assert_eq(row.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  let implicit_row_end = @html_parser.parse_fragment(
    "<template><tr><td>x</td></template>",
    collect_errors=true,
  )
  assert_eq(
    implicit_row_end.to_html(pretty=false),
    "<template><tr><td>x</td></tr></template>",
  )
  assert_eq(implicit_row_end.errors.length(), 0)
  let cells = @html_parser.parse_fragment(
    "<template><td>x</td><td>y</td></template>",
    collect_errors=true,
  )
  assert_eq(
    cells.to_html(pretty=false),
    "<template><td>x</td><td>y</td></template>",
  )
  assert_eq(cells.errors.length(), 0)
  let colgroup = @html_parser.parse_fragment(
    "<template><colgroup><col></colgroup></template>",
    collect_errors=true,
  )
  assert_eq(
    colgroup.to_html(pretty=false),
    "<template><colgroup><col></colgroup></template>",
  )
  assert_eq(colgroup.errors.length(), 1)
  assert_eq(colgroup.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  let document = @html_parser.parse(
    "<template><tr><td>x</td></tr></template><p>y</p>",
    collect_errors=true,
  )
  assert_eq(
    document.to_html(pretty=false),
    "<html><head><template><tr><td>x</td></tr></template></head><body><p>y</p></body></html>",
  )
  assert_eq(document.errors.length(), 2)
  assert_eq(document.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(document.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "template table context defers structural end recovery to template end" {
  let row = @html_parser.parse_fragment(
    "<template><tr><td>x</td></tr></template>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<template><tr><td>x</td></tr></template>",
  )
  assert_eq(row.errors.length(), 1)
  assert_eq(row.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  let section = @html_parser.parse_fragment(
    "<template><tbody><tr><td>x</td></tr></tbody></template>",
    collect_errors=true,
  )
  assert_eq(
    section.to_html(pretty=false),
    "<template><tbody><tr><td>x</td></tr></tbody></template>",
  )
  assert_eq(section.errors.length(), 2)
  assert_eq(section.errors[0].code, "unexpected-end-tag")
  assert_eq(section.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
  let direct_cell = @html_parser.parse_fragment(
    "<template><tbody><td>x</td></tbody></template>",
    collect_errors=true,
  )
  assert_eq(
    direct_cell.to_html(pretty=false),
    "<template><tbody><tr><td>x</td></tr></tbody></template>",
  )
  assert_eq(direct_cell.errors.length(), 3)
  assert_eq(direct_cell.errors[0].code, "unexpected-cell-in-table-body")
  assert_eq(direct_cell.errors[1].code, "unexpected-end-tag")
  assert_eq(
    direct_cell.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  let colgroup = @html_parser.parse_fragment(
    "<template><colgroup> x</colgroup></template>",
    collect_errors=true,
  )
  assert_eq(
    colgroup.to_html(pretty=false),
    "<template><colgroup> </colgroup>x</template>",
  )
  assert_eq(colgroup.errors.length(), 4)
  assert_eq(colgroup.errors[0].code, "unexpected-characters-in-column-group")
  assert_eq(colgroup.errors[1].code, "foster-parenting-character")
  assert_eq(colgroup.errors[2].code, "unexpected-end-tag")
  assert_eq(colgroup.errors[3].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "template table row contexts foster non-whitespace text" {
  let row = @html_parser.parse_fragment(
    "<template><tr>x<td>y</td></tr></template>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<template><tr><td>y</td></tr>x</template>",
  )
  assert_eq(row.errors.length(), 2)
  assert_eq(row.errors[0].code, "foster-parenting-character")
  assert_eq(row.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
  let section = @html_parser.parse_fragment(
    "<template><tbody>x<tr><td>y</td></tr></tbody></template>",
    collect_errors=true,
  )
  assert_eq(
    section.to_html(pretty=false),
    "<template><tbody><tr><td>y</td></tr></tbody>x</template>",
  )
  assert_eq(section.errors.length(), 3)
  assert_eq(section.errors[0].code, "foster-parenting-character")
  assert_eq(section.errors[1].code, "unexpected-end-tag")
  assert_eq(section.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "parser tracks origins for template table helper starts" {
  let caption = @html_parser.parse_fragment(
    "<template><caption>x</caption></template>",
    track_node_locations=true,
  )
  guard caption.query_one("caption") is Some(caption_node) else {
    fail("expected caption")
  }
  assert_node_origin(caption_node, 10, 1, 11)
  let caption_children = caption_node.children()
  assert_eq(caption_children.length(), 1)
  assert_node_origin(caption_children[0], 19, 1, 20)
  let row = @html_parser.parse_fragment(
    "<template><tr><td>x</td></tr></template>",
    track_node_locations=true,
  )
  guard row.query_one("tr") is Some(row_node) else { fail("expected row") }
  assert_node_origin(row_node, 10, 1, 11)
  guard row.query_one("td") is Some(row_cell) else { fail("expected cell") }
  assert_node_origin(row_cell, 14, 1, 15)
  let direct_cell = @html_parser.parse_fragment(
    "<template><td>x</td></template>",
    track_node_locations=true,
  )
  guard direct_cell.query_one("td") is Some(cell) else { fail("expected td") }
  assert_node_origin(cell, 10, 1, 11)
  let section = @html_parser.parse_fragment(
    "<template><tbody><tr><td>x</td></tr></tbody></template>",
    track_node_locations=true,
  )
  guard section.query_one("tbody") is Some(section_node) else {
    fail("expected section")
  }
  assert_node_origin(section_node, 10, 1, 11)
}

///|
test "template caption structural starts close caption and reprocess" {
  let row = @html_parser.parse_fragment(
    "<template><caption>x<tr><td>y</td></tr></caption></template>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<template><caption>x</caption><tbody><tr><td>y</td></tr></tbody></template>",
  )
  assert_eq(row.errors.length(), 3)
  assert_eq(row.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(row.errors[1].code, "unexpected-end-tag")
  assert_eq(row.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
  let nested_table = @html_parser.parse_fragment(
    "<template><caption>x<table><tr><td>y</td></tr></table></caption></template>",
    collect_errors=true,
  )
  assert_eq(
    nested_table.to_html(pretty=false),
    "<template><caption>x</caption><tbody><tr><td>y</td></tr></tbody></template>",
  )
  assert_eq(nested_table.errors.length(), 6)
  assert_eq(nested_table.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(nested_table.errors[1].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(nested_table.errors[2].code, "unexpected-end-tag")
  assert_eq(nested_table.errors[3].code, "unexpected-end-tag")
  assert_eq(nested_table.errors[4].code, "unexpected-end-tag")
  assert_eq(
    nested_table.errors[5].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  let colgroup = @html_parser.parse_fragment(
    "<template><caption>x<colgroup><col></colgroup></caption></template>",
    collect_errors=true,
  )
  assert_eq(
    colgroup.to_html(pretty=false),
    "<template><caption>x</caption><colgroup><col></colgroup></template>",
  )
  assert_eq(colgroup.errors.length(), 3)
  assert_eq(colgroup.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(colgroup.errors[1].code, "unexpected-end-tag")
  assert_eq(colgroup.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "template caption end defers recovery to template end" {
  let caption = @html_parser.parse_fragment(
    "<template><caption>x</caption></template>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<template><caption>x</caption></template>",
  )
  assert_eq(caption.errors.length(), 1)
  assert_eq(caption.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  let nested_caption = @html_parser.parse_fragment(
    "<template><caption>x<caption>y</caption></caption></template>",
    collect_errors=true,
  )
  assert_eq(
    nested_caption.to_html(pretty=false),
    "<template><caption>x</caption><caption>y</caption></template>",
  )
  assert_eq(nested_caption.errors.length(), 3)
  assert_eq(
    nested_caption.errors[0].code,
    "unexpected-start-tag-implies-end-tag",
  )
  assert_eq(nested_caption.errors[1].code, "unexpected-end-tag")
  assert_eq(
    nested_caption.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
}
