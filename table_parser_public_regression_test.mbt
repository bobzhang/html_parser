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
