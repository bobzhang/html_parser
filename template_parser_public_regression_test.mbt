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
