///|
test "document parser ignores col starts outside tables" {
  let paragraph = @html_parser.parse(
    "<!doctype html><p>a<col>b</p>",
    collect_errors=true,
  )
  assert_eq(
    paragraph.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p>ab</p></body></html>",
  )
  assert_eq(paragraph.errors.length(), 1)
  assert_eq(paragraph.errors[0].code, "unexpected-start-tag-ignored")
  let root = @html_parser.parse(
    "<!doctype html><col>x</col>",
    collect_errors=true,
  )
  assert_eq(
    root.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body>x</body></html>",
  )
  assert_eq(root.errors.length(), 2)
  assert_eq(root.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(root.errors[1].code, "unexpected-end-tag")
  let select_col = @html_parser.parse(
    "<!doctype html><select><col>x</col></select>",
    collect_errors=true,
  )
  assert_eq(
    select_col.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><select></select>x</body></html>",
  )
  assert_eq(select_col.errors.length(), 4)
  assert_eq(select_col.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(select_col.errors[1].code, "unexpected-start-tag-ignored")
  assert_eq(select_col.errors[2].code, "unexpected-end-tag")
  assert_eq(select_col.errors[3].code, "unexpected-end-tag")
}

///|
test "fragment parser keeps col starts outside tables" {
  let paragraph = @html_parser.parse_fragment(
    "<p>a<col>b</p>",
    collect_errors=true,
  )
  assert_eq(paragraph.to_html(pretty=false), "<p>a<col>b</p>")
  assert_eq(paragraph.errors.length(), 0)
  let root = @html_parser.parse_fragment("<col>x</col>", collect_errors=true)
  assert_eq(root.to_html(pretty=false), "<col>x")
  assert_eq(root.errors.length(), 1)
  assert_eq(root.errors[0].code, "unexpected-end-tag")
}

///|
test "parser inserts basic table row groups and rows" {
  let rows = @html_parser.parse_fragment("<table><tr><td>x</td></tr></table>")
  assert_eq(
    rows.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  let cells = @html_parser.parse_fragment("<table><td>x<td>y</table>")
  assert_eq(
    cells.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><td>y</td></tr></tbody></table>",
  )
  let after_head = @html_parser.parse_fragment(
    "<table><thead><tr><td>h</td></tr></thead><tr><td>b</td></tr></table>",
  )
  assert_eq(
    after_head.to_html(pretty=false),
    "<table><thead><tr><td>h</td></tr></thead><tbody><tr><td>b</td></tr></tbody></table>",
  )
  let section_cells = @html_parser.parse_fragment(
    "<table><tbody><td>x<th>y</tbody></table>",
  )
  assert_eq(
    section_cells.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><th>y</th></tr></tbody></table>",
  )
}

///|
test "parser reports cells started directly in table body context" {
  let table_cell = @html_parser.parse_fragment(
    "<table><td>x<td>y</table>",
    collect_errors=true,
  )
  assert_eq(
    table_cell.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><td>y</td></tr></tbody></table>",
  )
  assert_eq(table_cell.errors.length(), 1)
  assert_eq(table_cell.errors[0].code, "unexpected-cell-in-table-body")
  let section_cell = @html_parser.parse_fragment(
    "<table><tbody><td>x<th>y</tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    section_cell.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><th>y</th></tr></tbody></table>",
  )
  assert_eq(section_cell.errors.length(), 1)
  assert_eq(section_cell.errors[0].code, "unexpected-cell-in-table-body")
  let head_cell = @html_parser.parse_fragment(
    "<table><thead><td>x</td></thead></table>",
    collect_errors=true,
  )
  assert_eq(
    head_cell.to_html(pretty=false),
    "<table><thead><tr><td>x</td></tr></thead></table>",
  )
  assert_eq(head_cell.errors.length(), 1)
  assert_eq(head_cell.errors[0].code, "unexpected-cell-in-table-body")
  let row_cell = @html_parser.parse_fragment(
    "<table><tr><td>x<th>y</table>",
    collect_errors=true,
  )
  assert_eq(
    row_cell.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><th>y</th></tr></tbody></table>",
  )
  assert_eq(row_cell.errors.length(), 0)
  let open_cell = @html_parser.parse_fragment(
    "<table><tbody><td>x</table>",
    collect_errors=true,
  )
  assert_eq(
    open_cell.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(open_cell.errors.length(), 1)
  assert_eq(open_cell.errors[0].code, "unexpected-cell-in-table-body")
}

///|
test "parser closes row groups before table structure starts" {
  let nested_body = @html_parser.parse_fragment(
    "<table><tbody><tbody><tr><td>x</td></tr></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    nested_body.to_html(pretty=false),
    "<table><tbody></tbody><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(nested_body.errors.length(), 0)
  let head = @html_parser.parse_fragment(
    "<table><tbody><thead><tr><td>x</td></tr></thead></table>",
    collect_errors=true,
  )
  assert_eq(
    head.to_html(pretty=false),
    "<table><tbody></tbody><thead><tr><td>x</td></tr></thead></table>",
  )
  assert_eq(head.errors.length(), 0)
  let caption = @html_parser.parse_fragment(
    "<table><tbody><caption>x</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><tbody></tbody><caption>x</caption></table>",
  )
  assert_eq(caption.errors.length(), 0)
  let colgroup = @html_parser.parse_fragment(
    "<table><tbody><colgroup><col></colgroup></table>",
    collect_errors=true,
  )
  assert_eq(
    colgroup.to_html(pretty=false),
    "<table><tbody></tbody><colgroup><col></colgroup></table>",
  )
  assert_eq(colgroup.errors.length(), 0)
}
