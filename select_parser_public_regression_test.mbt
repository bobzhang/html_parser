///|
test "parser reports select hr br and img starts" {
  let hr = @html_parser.parse_fragment(
    "<select><option>a<hr>b</option></select>",
    collect_errors=true,
  )
  assert_eq(
    hr.to_html(pretty=false),
    "<select><option>a</option><hr>b</select>",
  )
  assert_eq(hr.errors.length(), 2)
  assert_eq(hr.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(hr.errors[1].code, "unexpected-end-tag-in-select")
  let group_hr = @html_parser.parse_fragment(
    "<select><optgroup><option>a<hr>b</optgroup>c</select>",
    collect_errors=true,
  )
  assert_eq(
    group_hr.to_html(pretty=false),
    "<select><optgroup><option>a</option></optgroup><hr>bc</select>",
  )
  assert_eq(group_hr.errors.length(), 2)
  assert_eq(group_hr.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(group_hr.errors[1].code, "unexpected-end-tag-in-select")
  let br = @html_parser.parse_fragment(
    "<select><br>x</select>",
    collect_errors=true,
  )
  assert_eq(br.to_html(pretty=false), "<select><br>x</select>")
  assert_eq(br.errors.length(), 1)
  assert_eq(br.errors[0].code, "unexpected-start-tag-in-select")
  let img = @html_parser.parse_fragment(
    "<select><img src=x>x</select>",
    collect_errors=true,
  )
  assert_eq(img.to_html(pretty=false), "<select><img src=\"x\">x</select>")
  assert_eq(img.errors.length(), 1)
  assert_eq(img.errors[0].code, "unexpected-start-tag-in-select")
}
