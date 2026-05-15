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

///|
test "parser wraps table col starts in implied colgroups" {
  let single = @html_parser.parse_fragment(
    "<table><col></table>",
    collect_errors=true,
  )
  assert_eq(
    single.to_html(pretty=false),
    "<table><colgroup><col></colgroup></table>",
  )
  assert_eq(single.errors.length(), 0)
  let adjacent = @html_parser.parse_fragment(
    "<table><col><col></table>",
    collect_errors=true,
  )
  assert_eq(
    adjacent.to_html(pretty=false),
    "<table><colgroup><col><col></colgroup></table>",
  )
  assert_eq(adjacent.errors.length(), 0)
  let after_explicit = @html_parser.parse_fragment(
    "<table><colgroup><col></colgroup><col></table>",
    collect_errors=true,
  )
  assert_eq(
    after_explicit.to_html(pretty=false),
    "<table><colgroup><col></colgroup><colgroup><col></colgroup></table>",
  )
  assert_eq(after_explicit.errors.length(), 0)
  let row_group = @html_parser.parse_fragment(
    "<table><tbody><col><tr><td>x</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row_group.to_html(pretty=false),
    "<table><tbody></tbody><colgroup><col></colgroup><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(row_group.errors.length(), 0)
}

///|
test "parser handles text in column group context" {
  let explicit_text = @html_parser.parse_fragment(
    "<table><colgroup>x</colgroup></table>",
    collect_errors=true,
  )
  assert_eq(
    explicit_text.to_html(pretty=false),
    "x<table><colgroup></colgroup></table>",
  )
  assert_eq(explicit_text.errors.length(), 3)
  assert_eq(
    explicit_text.errors[0].code,
    "unexpected-characters-in-column-group",
  )
  assert_eq(explicit_text.errors[1].code, "foster-parenting-character")
  assert_eq(explicit_text.errors[2].code, "unexpected-end-tag")
  let explicit_space = @html_parser.parse_fragment(
    "<table><colgroup> </colgroup></table>",
    collect_errors=true,
  )
  assert_eq(
    explicit_space.to_html(pretty=false),
    "<table><colgroup> </colgroup></table>",
  )
  assert_eq(explicit_space.errors.length(), 2)
  assert_eq(
    explicit_space.errors[0].code,
    "unexpected-characters-in-column-group",
  )
  assert_eq(explicit_space.errors[1].code, "unexpected-end-tag")
  let implicit_text = @html_parser.parse_fragment(
    "<table><col>x</table>",
    collect_errors=true,
  )
  assert_eq(
    implicit_text.to_html(pretty=false),
    "x<table><colgroup><col></colgroup></table>",
  )
  assert_eq(implicit_text.errors.length(), 2)
  assert_eq(
    implicit_text.errors[0].code,
    "unexpected-characters-in-column-group",
  )
  assert_eq(implicit_text.errors[1].code, "foster-parenting-character")
  let implicit_space = @html_parser.parse_fragment(
    "<table><col> </table>",
    collect_errors=true,
  )
  assert_eq(
    implicit_space.to_html(pretty=false),
    "<table><colgroup><col> </colgroup></table>",
  )
  assert_eq(implicit_space.errors.length(), 1)
  assert_eq(
    implicit_space.errors[0].code,
    "unexpected-characters-in-column-group",
  )
}

///|
test "parser closes column groups before non-col starts" {
  let row = @html_parser.parse_fragment(
    "<table><colgroup><tr><td>x</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<table><colgroup></colgroup><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(row.errors.length(), 0)
  let caption = @html_parser.parse_fragment(
    "<table><colgroup><caption>x</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><colgroup></colgroup><caption>x</caption></table>",
  )
  assert_eq(caption.errors.length(), 0)
  let nested = @html_parser.parse_fragment(
    "<table><colgroup><colgroup><col></colgroup></table>",
    collect_errors=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<table><colgroup></colgroup><colgroup><col></colgroup></table>",
  )
  assert_eq(nested.errors.length(), 1)
  assert_eq(nested.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let div = @html_parser.parse_fragment(
    "<table><colgroup><div>x</div></table>",
    collect_errors=true,
  )
  assert_eq(
    div.to_html(pretty=false),
    "<div>x</div><table><colgroup></colgroup></table>",
  )
  assert_eq(div.errors.length(), 3)
  assert_eq(div.errors[0].code, "foster-parenting-start-tag")
  assert_eq(div.errors[1].code, "foster-parenting-character")
  assert_eq(div.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
  let form = @html_parser.parse_fragment(
    "<table><colgroup><form id=f></form></table>",
    collect_errors=true,
  )
  assert_eq(
    form.to_html(pretty=false),
    "<table><colgroup></colgroup><form id=\"f\"></form></table>",
  )
  assert_eq(form.errors.length(), 3)
  assert_eq(form.errors[0].code, "unexpected-form-in-table")
  assert_eq(form.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(form.errors[2].code, "unexpected-end-tag")
}

///|
test "parser closes column groups before non-colgroup end tags" {
  let div = @html_parser.parse_fragment(
    "<table><colgroup></div></table>",
    collect_errors=true,
  )
  assert_eq(div.to_html(pretty=false), "<table><colgroup></colgroup></table>")
  assert_eq(div.errors.length(), 2)
  assert_eq(div.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(div.errors[1].code, "unexpected-end-tag")
  let paragraph = @html_parser.parse_fragment(
    "<table><colgroup></p></table>",
    collect_errors=true,
  )
  assert_eq(
    paragraph.to_html(pretty=false),
    "<p></p><table><colgroup></colgroup></table>",
  )
  assert_eq(paragraph.errors.length(), 2)
  assert_eq(paragraph.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(paragraph.errors[1].code, "unexpected-end-tag")
  let row_group = @html_parser.parse_fragment(
    "<table><colgroup></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    row_group.to_html(pretty=false),
    "<table><colgroup></colgroup></table>",
  )
  assert_eq(row_group.errors.length(), 1)
  assert_eq(row_group.errors[0].code, "unexpected-end-tag")
  let table = @html_parser.parse_fragment(
    "<table><colgroup></table>",
    collect_errors=true,
  )
  assert_eq(table.to_html(pretty=false), "<table><colgroup></colgroup></table>")
  assert_eq(table.errors.length(), 0)
  let col = @html_parser.parse_fragment(
    "<table><colgroup></col></colgroup></table>",
    collect_errors=true,
  )
  assert_eq(col.to_html(pretty=false), "<table><colgroup></colgroup></table>")
  assert_eq(col.errors.length(), 1)
  assert_eq(col.errors[0].code, "unexpected-end-tag")
}

///|
test "parser closes rows before table structure starts" {
  let next_row = @html_parser.parse_fragment(
    "<table><tr><tr><td>x</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    next_row.to_html(pretty=false),
    "<table><tbody><tr></tr><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(next_row.errors.length(), 0)
  let row_group = @html_parser.parse_fragment(
    "<table><tbody><tr><tbody><tr><td>x</td></tr></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    row_group.to_html(pretty=false),
    "<table><tbody><tr></tr></tbody><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(row_group.errors.length(), 0)
  let caption = @html_parser.parse_fragment(
    "<table><tr><caption>x</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><tbody><tr></tr></tbody><caption>x</caption></table>",
  )
  assert_eq(caption.errors.length(), 0)
  let col = @html_parser.parse_fragment(
    "<table><tr><col><tr><td>x</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    col.to_html(pretty=false),
    "<table><tbody><tr></tr></tbody><colgroup><col></colgroup><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(col.errors.length(), 0)
}

///|
test "parser closes cells before table structure starts" {
  let next_row = @html_parser.parse_fragment(
    "<table><tr><td>x<tr><td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    next_row.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(next_row.errors.length(), 0)
  let row_group = @html_parser.parse_fragment(
    "<table><tbody><tr><td>x<tbody><tr><td>y</td></tr></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    row_group.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr></tbody><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(row_group.errors.length(), 0)
  let caption = @html_parser.parse_fragment(
    "<table><tr><td>x<caption>c</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr></tbody><caption>c</caption></table>",
  )
  assert_eq(caption.errors.length(), 0)
  let next_cell = @html_parser.parse_fragment(
    "<table><tr><td>x<th>y</th></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    next_cell.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><th>y</th></tr></tbody></table>",
  )
  assert_eq(next_cell.errors.length(), 0)
}

///|
test "parser closes captions before table structure starts and ends" {
  let row = @html_parser.parse_fragment(
    "<table><caption>x<tr><td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<table><caption>x</caption><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(row.errors.length(), 1)
  assert_eq(row.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let row_group = @html_parser.parse_fragment(
    "<table><caption>x<tbody><tr><td>y</td></tr></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    row_group.to_html(pretty=false),
    "<table><caption>x</caption><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(row_group.errors.length(), 1)
  assert_eq(row_group.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let caption = @html_parser.parse_fragment(
    "<table><caption>x<caption>y</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><caption>x</caption><caption>y</caption></table>",
  )
  assert_eq(caption.errors.length(), 1)
  assert_eq(caption.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let col = @html_parser.parse_fragment(
    "<table><caption>x<col></table>",
    collect_errors=true,
  )
  assert_eq(
    col.to_html(pretty=false),
    "<table><caption>x</caption><colgroup><col></colgroup></table>",
  )
  assert_eq(col.errors.length(), 1)
  assert_eq(col.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let cell = @html_parser.parse_fragment(
    "<table><caption>x<td>y</td></table>",
    collect_errors=true,
  )
  assert_eq(
    cell.to_html(pretty=false),
    "<table><caption>x</caption><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(cell.errors.length(), 2)
  assert_eq(cell.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(cell.errors[1].code, "unexpected-cell-in-table-body")
  let nested_table = @html_parser.parse_fragment(
    "<table><caption>x<table><tr><td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    nested_table.to_html(pretty=false),
    "<table><caption>x</caption></table><table><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(nested_table.errors.length(), 2)
  assert_eq(nested_table.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(nested_table.errors[1].code, "unexpected-start-tag-implies-end-tag")
  let table_end = @html_parser.parse_fragment(
    "<table><caption>x</table>",
    collect_errors=true,
  )
  assert_eq(
    table_end.to_html(pretty=false),
    "<table><caption>x</caption></table>",
  )
  assert_eq(table_end.errors.length(), 0)
  let row_group_end = @html_parser.parse_fragment(
    "<table><caption>x</tbody></caption></table>",
    collect_errors=true,
  )
  assert_eq(
    row_group_end.to_html(pretty=false),
    "<table><caption>x</caption></table>",
  )
  assert_eq(row_group_end.errors.length(), 1)
  assert_eq(row_group_end.errors[0].code, "unexpected-end-tag")
  let generic_end = @html_parser.parse_fragment(
    "<table><caption>x</div>y</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    generic_end.to_html(pretty=false),
    "<table><caption>xy</caption></table>",
  )
  assert_eq(generic_end.errors.length(), 1)
  assert_eq(generic_end.errors[0].code, "unexpected-end-tag")
}

///|
test "parser clears nested table stack before structure starts" {
  let cell_paragraph = @html_parser.parse_fragment(
    "<table><td><p>x<tr><td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    cell_paragraph.to_html(pretty=false),
    "<table><tbody><tr><td><p>x</p></td></tr><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(cell_paragraph.errors.length(), 1)
  assert_eq(cell_paragraph.errors[0].code, "unexpected-cell-in-table-body")
  let cell_div = @html_parser.parse_fragment(
    "<table><tr><td><div>x<td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    cell_div.to_html(pretty=false),
    "<table><tbody><tr><td><div>x</div></td><td>y</td></tr></tbody></table>",
  )
  assert_eq(cell_div.errors.length(), 0)
  let row_div = @html_parser.parse_fragment(
    "<table><tr><div>x<tr><td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row_div.to_html(pretty=false),
    "<div>x</div><table><tbody><tr></tr><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(row_div.errors.length(), 1)
  assert_eq(row_div.errors[0].code, "foster-parenting-character")
  let section_div = @html_parser.parse_fragment(
    "<table><tbody><div>x<tbody><tr><td>y</td></tr></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    section_div.to_html(pretty=false),
    "<div>x</div><table><tbody></tbody><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(section_div.errors.length(), 2)
  assert_eq(section_div.errors[0].code, "foster-parenting-start-tag")
  assert_eq(section_div.errors[1].code, "foster-parenting-character")
  let caption_div = @html_parser.parse_fragment(
    "<table><caption><div>x<tr><td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    caption_div.to_html(pretty=false),
    "<table><caption><div>x</div></caption><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(caption_div.errors.length(), 1)
  assert_eq(caption_div.errors[0].code, "unexpected-start-tag-implies-end-tag")
}

///|
test "parser closes current table before nested table starts" {
  let direct = @html_parser.parse_fragment(
    "<table><table><tr><td>x</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    direct.to_html(pretty=false),
    "<table></table><table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(direct.errors.length(), 1)
  assert_eq(direct.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let text = @html_parser.parse_fragment(
    "<table><table>text</table>",
    collect_errors=true,
  )
  assert_eq(text.to_html(pretty=false), "<table></table>text<table></table>")
  assert_eq(text.errors.length(), 5)
  assert_eq(text.errors[0].code, "unexpected-start-tag-implies-end-tag")
  for index in 1..<text.errors.length() {
    assert_eq(text.errors[index].code, "foster-parenting-character")
  }
  let section = @html_parser.parse_fragment(
    "<table><tbody><table><tr><td>x</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    section.to_html(pretty=false),
    "<table><tbody></tbody></table><table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(section.errors.length(), 1)
  assert_eq(section.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let cell = @html_parser.parse_fragment(
    "<table><tr><td><table>x</table></td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    cell.to_html(pretty=false),
    "<table><tbody><tr><td>x<table></table></td></tr></tbody></table>",
  )
  assert_eq(cell.errors.length(), 1)
  assert_eq(cell.errors[0].code, "foster-parenting-character")
}

///|
test "parser foster parents non-whitespace table text" {
  let direct = @html_parser.parse_fragment(
    "<table>text</table>",
    collect_errors=true,
  )
  assert_eq(direct.to_html(pretty=false), "text<table></table>")
  assert_eq(direct.errors.length(), 4)
  for error in direct.errors {
    assert_eq(error.code, "foster-parenting-character")
  }
  let spaced = @html_parser.parse_fragment(
    "<table> a b </table>",
    collect_errors=true,
  )
  assert_eq(spaced.to_html(pretty=false), " a b <table></table>")
  assert_eq(spaced.errors.length(), 2)
  for error in spaced.errors {
    assert_eq(error.code, "foster-parenting-character")
  }
  let whitespace = @html_parser.parse_fragment(
    "<table> </table>",
    collect_errors=true,
  )
  assert_eq(whitespace.to_html(pretty=false), "<table> </table>")
  assert_eq(whitespace.errors.length(), 0)
  let caption = @html_parser.parse_fragment(
    "<table><caption>text</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><caption>text</caption></table>",
  )
  assert_eq(caption.errors.length(), 0)
  let cell = @html_parser.parse_fragment(
    "<table><tr><td>text</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    cell.to_html(pretty=false),
    "<table><tbody><tr><td>text</td></tr></tbody></table>",
  )
  assert_eq(cell.errors.length(), 0)
  let section = @html_parser.parse_fragment(
    "<table><tbody>text</tbody></table>",
    collect_errors=true,
  )
  assert_eq(section.to_html(pretty=false), "text<table><tbody></tbody></table>")
  assert_eq(section.errors.length(), 4)
  for error in section.errors {
    assert_eq(error.code, "foster-parenting-character")
  }
  let doc = @html_parser.parse(
    "<!doctype html><div><table>text</table></div>",
    collect_errors=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><div>text<table></table></div></body></html>",
  )
  assert_eq(doc.errors.length(), 4)
  for error in doc.errors {
    assert_eq(error.code, "foster-parenting-character")
  }
}

///|
test "parser tracks origins for foster-parented table text" {
  let direct = @html_parser.parse_fragment(
    "<table>text</table>",
    track_node_locations=true,
  )
  let direct_children = direct.root.children()
  assert_eq(direct_children.length(), 2)
  assert_eq(direct_children[0].data(), "text")
  assert_node_origin(direct_children[0], 7, 1, 8)
  let section = @html_parser.parse_fragment(
    "<table><tbody>text</tbody></table>",
    track_node_locations=true,
  )
  let section_children = section.root.children()
  assert_eq(section_children.length(), 2)
  assert_eq(section_children[0].data(), "text")
  assert_node_origin(section_children[0], 14, 1, 15)
}

///|
test "parser foster parents table-context start tags" {
  let direct = @html_parser.parse_fragment(
    "<table><div>x</div></table>",
    collect_errors=true,
  )
  assert_eq(direct.to_html(pretty=false), "<div>x</div><table></table>")
  assert_eq(direct.errors.length(), 3)
  assert_eq(direct.errors[0].code, "foster-parenting-start-tag")
  assert_eq(direct.errors[1].code, "foster-parenting-character")
  assert_eq(direct.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
  let section = @html_parser.parse_fragment(
    "<table><tbody><div>x</div></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    section.to_html(pretty=false),
    "<div>x</div><table><tbody></tbody></table>",
  )
  assert_eq(section.errors.length(), 3)
  assert_eq(section.errors[0].code, "foster-parenting-start-tag")
  assert_eq(section.errors[1].code, "foster-parenting-character")
  assert_eq(section.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
  let row = @html_parser.parse_fragment(
    "<table><tr><div>x</div></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<div>x</div><table><tbody><tr></tr></tbody></table>",
  )
  assert_eq(row.errors.length(), 1)
  assert_eq(row.errors[0].code, "foster-parenting-character")
  let cell = @html_parser.parse_fragment(
    "<table><tr><td><div>x</div></td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    cell.to_html(pretty=false),
    "<table><tbody><tr><td><div>x</div></td></tr></tbody></table>",
  )
  assert_eq(cell.errors.length(), 0)
  let doc = @html_parser.parse(
    "<!doctype html><div><table><p>x</p></table></div>",
    collect_errors=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><div><p>x</p><table></table></div></body></html>",
  )
  assert_eq(doc.errors.length(), 3)
  assert_eq(doc.errors[0].code, "foster-parenting-start-tag")
  assert_eq(doc.errors[1].code, "foster-parenting-character")
  assert_eq(doc.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "parser handles hidden input and form starts in table context" {
  let hidden = @html_parser.parse_fragment(
    "<table><input type=hidden name=x value=y></table>",
    collect_errors=true,
  )
  assert_eq(
    hidden.to_html(pretty=false),
    "<table><input type=\"hidden\" name=\"x\" value=\"y\"></table>",
  )
  assert_eq(hidden.errors.length(), 1)
  assert_eq(hidden.errors[0].code, "unexpected-hidden-input-in-table")
  guard hidden.errors[0].column is Some(41) else {
    fail("expected hidden input table error at fragment input start close")
  }
  let uppercase_hidden = @html_parser.parse_fragment(
    "<table><input TYPE=HIDDEN></table>",
    collect_errors=true,
  )
  assert_eq(
    uppercase_hidden.to_html(pretty=false),
    "<table><input type=\"HIDDEN\"></table>",
  )
  assert_eq(uppercase_hidden.errors.length(), 1)
  assert_eq(uppercase_hidden.errors[0].code, "unexpected-hidden-input-in-table")
  let ordinary_input = @html_parser.parse_fragment(
    "<table><input name=x></table>",
    collect_errors=true,
  )
  assert_eq(
    ordinary_input.to_html(pretty=false),
    "<input name=\"x\"><table></table>",
  )
  assert_eq(ordinary_input.errors.length(), 1)
  assert_eq(ordinary_input.errors[0].code, "foster-parenting-start-tag")
  let form = @html_parser.parse_fragment(
    "<table><form id=f></form></table>",
    collect_errors=true,
  )
  assert_eq(form.to_html(pretty=false), "<table><form id=\"f\"></form></table>")
  assert_eq(form.errors.length(), 3)
  assert_eq(form.errors[0].code, "unexpected-form-in-table")
  assert_eq(form.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(form.errors[2].code, "unexpected-end-tag")
  guard form.errors[0].column is Some(18) else {
    fail("expected form table error at start tag close")
  }
  let row_form = @html_parser.parse_fragment(
    "<table><tr><form id=f></form></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row_form.to_html(pretty=false),
    "<form id=\"f\"></form><table><tbody><tr></tr></tbody></table>",
  )
  assert_eq(row_form.errors.length(), 0)
  let stray_form_end = @html_parser.parse_fragment(
    "<table></form></table>",
    collect_errors=true,
  )
  assert_eq(stray_form_end.to_html(pretty=false), "<table></table>")
  assert_eq(stray_form_end.errors.length(), 2)
  assert_eq(
    stray_form_end.errors[0].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(stray_form_end.errors[1].code, "unexpected-end-tag")
}

///|
test "parser tracks origins for hidden input and form table helpers" {
  let hidden = @html_parser.parse_fragment(
    "<table><input type=hidden name=x value=y></table>",
    track_node_locations=true,
  )
  guard hidden.query_one("input") is Some(input) else {
    fail("expected hidden input")
  }
  assert_node_origin(input, 7, 1, 8)
  let form = @html_parser.parse_fragment(
    "<table><form id=f></form></table>",
    track_node_locations=true,
  )
  guard form.query_one("form") is Some(form_node) else { fail("expected form") }
  assert_node_origin(form_node, 7, 1, 8)
}

///|
test "parser keeps style and script starts in table context" {
  let style = @html_parser.parse_fragment(
    "<table><style>x</style></table>",
    collect_errors=true,
  )
  assert_eq(style.to_html(pretty=false), "<table><style>x</style></table>")
  assert_eq(style.errors.length(), 0)
  let script = @html_parser.parse_fragment(
    "<table><script>x</script></table>",
    collect_errors=true,
  )
  assert_eq(script.to_html(pretty=false), "<table><script>x</script></table>")
  assert_eq(script.errors.length(), 0)
  let section = @html_parser.parse_fragment(
    "<table><tbody><style>x</style></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    section.to_html(pretty=false),
    "<table><tbody><style>x</style></tbody></table>",
  )
  assert_eq(section.errors.length(), 0)
  let row = @html_parser.parse_fragment(
    "<table><tr><style>x</style></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<table><tbody><tr><style>x</style></tr></tbody></table>",
  )
  assert_eq(row.errors.length(), 0)
}

///|
test "parser reports stray table-context end tags" {
  let div = @html_parser.parse_fragment(
    "<table></div></table>",
    collect_errors=true,
  )
  assert_eq(div.to_html(pretty=false), "<table></table>")
  assert_eq(div.errors.length(), 2)
  assert_eq(div.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(div.errors[1].code, "unexpected-end-tag")
  let paragraph = @html_parser.parse_fragment(
    "<table></p></table>",
    collect_errors=true,
  )
  assert_eq(paragraph.to_html(pretty=false), "<p></p><table></table>")
  assert_eq(paragraph.errors.length(), 2)
  assert_eq(paragraph.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(paragraph.errors[1].code, "unexpected-end-tag")
  let row_group = @html_parser.parse_fragment(
    "<table></tbody></table>",
    collect_errors=true,
  )
  assert_eq(row_group.to_html(pretty=false), "<table></table>")
  assert_eq(row_group.errors.length(), 1)
  assert_eq(row_group.errors[0].code, "unexpected-end-tag")
  let body = @html_parser.parse_fragment(
    "<table></body></table>",
    collect_errors=true,
  )
  assert_eq(body.to_html(pretty=false), "<table></table>")
  assert_eq(body.errors.length(), 1)
  assert_eq(body.errors[0].code, "unexpected-end-tag")
  let proper_row_group = @html_parser.parse_fragment(
    "<table><tbody></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    proper_row_group.to_html(pretty=false),
    "<table><tbody></tbody></table>",
  )
  assert_eq(proper_row_group.errors.length(), 0)
}

///|
test "parser ignores table structure starts outside table" {
  let cell = @html_parser.parse_fragment("<td>x</td>", collect_errors=true)
  assert_eq(cell.to_html(pretty=false), "x")
  assert_eq(cell.errors.length(), 2)
  assert_eq(cell.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(cell.errors[1].code, "unexpected-end-tag")
  let row = @html_parser.parse_fragment(
    "<tr><td>x</td></tr>",
    collect_errors=true,
  )
  assert_eq(row.to_html(pretty=false), "x")
  assert_eq(row.errors.length(), 4)
  assert_eq(row.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(row.errors[1].code, "unexpected-start-tag-ignored")
  assert_eq(row.errors[2].code, "unexpected-end-tag")
  assert_eq(row.errors[3].code, "unexpected-end-tag")
  let caption = @html_parser.parse_fragment(
    "<caption>x</caption>",
    collect_errors=true,
  )
  assert_eq(caption.to_html(pretty=false), "x")
  assert_eq(caption.errors.length(), 2)
  assert_eq(caption.errors[0].code, "unexpected-start-tag")
  assert_eq(caption.errors[1].code, "unexpected-end-tag")
  let colgroup = @html_parser.parse_fragment(
    "<colgroup><col></colgroup>",
    collect_errors=true,
  )
  assert_eq(colgroup.to_html(pretty=false), "<col>")
  assert_eq(colgroup.errors.length(), 2)
  assert_eq(colgroup.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(colgroup.errors[1].code, "unexpected-end-tag")
}

///|
test "parser reports EOF in unfinished tables" {
  let table = @html_parser.parse_fragment(
    "<table><tr><td>x",
    collect_errors=true,
  )
  assert_eq(
    table.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(table.errors.length(), 1)
  assert_eq(table.errors[0].code, "eof-in-table")
  guard table.errors[0].column is Some(16) else {
    fail("expected table EOF error at final input column")
  }
  let caption = @html_parser.parse_fragment(
    "<table><caption>x",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><caption>x</caption></table>",
  )
  assert_eq(caption.errors.length(), 1)
  assert_eq(caption.errors[0].code, "expected-closing-tag-but-got-eof")
  guard caption.errors[0].column is Some(17) else {
    fail("expected caption EOF to follow body-mode EOF reporting")
  }
  let nested = @html_parser.parse_fragment(
    "<table><caption><div>x",
    collect_errors=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<table><caption><div>x</div></caption></table>",
  )
  assert_eq(nested.errors.length(), 1)
  assert_eq(nested.errors[0].code, "expected-closing-tag-but-got-eof")
}
