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

///|
test "parser reports select common element starts and ends" {
  let div = @html_parser.parse_fragment(
    "<select><div>x</div>y</select>",
    collect_errors=true,
  )
  assert_eq(div.to_html(pretty=false), "<select><div>x</div>y</select>")
  assert_eq(div.errors.length(), 2)
  assert_eq(div.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(div.errors[1].code, "unexpected-end-tag-in-select")
  let button = @html_parser.parse_fragment(
    "<select><button>x</button>y</select>",
    collect_errors=true,
  )
  assert_eq(
    button.to_html(pretty=false),
    "<select><button>x</button>y</select>",
  )
  assert_eq(button.errors.length(), 2)
  assert_eq(button.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(button.errors[1].code, "unexpected-end-tag-in-select")
  let menuitem = @html_parser.parse_fragment(
    "<select><menuitem>x</menuitem>y</select>",
    collect_errors=true,
  )
  assert_eq(
    menuitem.to_html(pretty=false),
    "<select><menuitem>xy</menuitem></select>",
  )
  assert_eq(menuitem.errors.length(), 2)
  assert_eq(menuitem.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(menuitem.errors[1].code, "unexpected-end-tag")
  let shell = @html_parser.parse_fragment(
    "<select><body>x</body><head>y</head></select>",
    collect_errors=true,
  )
  assert_eq(shell.to_html(pretty=false), "<select>xy</select>")
  assert_eq(shell.errors.length(), 4)
  assert_eq(shell.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(shell.errors[1].code, "unexpected-end-tag")
  assert_eq(shell.errors[2].code, "unexpected-start-tag-in-select")
  assert_eq(shell.errors[3].code, "unexpected-end-tag")
}

///|
test "parser ignores sectioning starts in select mode" {
  let aside = @html_parser.parse(
    "<select><aside>text</aside></select>",
    collect_errors=true,
  )
  assert_eq(
    aside.to_html(pretty=false),
    "<html><head></head><body><select>text</select></body></html>",
  )
  assert_eq(aside.errors.length(), 3)
  assert_eq(aside.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(aside.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(aside.errors[2].code, "unexpected-end-tag")
}

///|
test "parser tracks origins for select helper start tags" {
  let div = @html_parser.parse_fragment(
    "<select><div>x</div>y</select>",
    track_node_locations=true,
  )
  guard div.query_one("div") is Some(div_node) else {
    fail("expected select div")
  }
  assert_node_origin(div_node, 8, 1, 9)
  let div_children = div_node.children()
  assert_eq(div_children.length(), 1)
  assert_node_origin(div_children[0], 13, 1, 14)
  let br = @html_parser.parse_fragment(
    "<select><br>x</select>",
    track_node_locations=true,
  )
  guard br.query_one("br") is Some(br_node) else { fail("expected select br") }
  assert_node_origin(br_node, 8, 1, 9)
  let plain = @html_parser.parse_fragment(
    "<select><plaintext>x</select>y",
    track_node_locations=true,
  )
  guard plain.query_one("plaintext") is Some(plaintext) else {
    fail("expected select plaintext")
  }
  assert_node_origin(plaintext, 8, 1, 9)
  let plain_children = plaintext.children()
  assert_eq(plain_children.length(), 1)
  assert_node_origin(plain_children[0], 19, 1, 20)
}

///|
test "parser reports select plaintext start and keeps current container" {
  let plain = @html_parser.parse_fragment(
    "<select><plaintext>x</select>y",
    collect_errors=true,
  )
  assert_eq(
    plain.to_html(pretty=false),
    "<select><plaintext>x&lt;/select&gt;y</plaintext></select>",
  )
  assert_eq(plain.errors.length(), 2)
  assert_eq(plain.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(plain.errors[1].code, "expected-closing-tag-but-got-eof")
  let in_p = @html_parser.parse_fragment(
    "<select><p>x<plaintext>y</select>z",
    collect_errors=true,
  )
  assert_eq(
    in_p.to_html(pretty=false),
    "<select><p>x<plaintext>y&lt;/select&gt;z</plaintext></p></select>",
  )
  assert_eq(in_p.errors.length(), 3)
  assert_eq(in_p.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(in_p.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(in_p.errors[2].code, "expected-closing-tag-but-got-eof")
}

///|
test "parser closes repeated option and select optgroup starts" {
  let options = @html_parser.parse_fragment(
    "<select><option>one<option>two</select>",
  )
  assert_eq(
    options.to_html(pretty=false),
    "<select><option>one</option><option>two</option></select>",
  )
  let groups = @html_parser.parse_fragment(
    "<select><optgroup><option>one<optgroup><option>two</select>",
  )
  assert_eq(
    groups.to_html(pretty=false),
    "<select><optgroup><option>one</option></optgroup><optgroup><option>two</option></optgroup></select>",
  )
  let nested_select = @html_parser.parse_fragment(
    "<select><select><option>x</select>",
    collect_errors=true,
  )
  assert_eq(
    nested_select.to_html(pretty=false),
    "<select></select><option>x</option>",
  )
  assert_eq(nested_select.errors.length(), 2)
  assert_eq(nested_select.errors[0].code, "unexpected-select-in-select")
  assert_eq(nested_select.errors[1].code, "unexpected-end-tag")
  let stray_group = @html_parser.parse_fragment(
    "<select><option>1</option></optgroup></select>",
    collect_errors=true,
  )
  assert_eq(
    stray_group.to_html(pretty=false),
    "<select><option>1</option></select>",
  )
  assert_eq(stray_group.errors.length(), 1)
  assert_eq(stray_group.errors[0].code, "unexpected-end-tag-in-select")
  let stray_option = @html_parser.parse_fragment(
    "<select></option></select>",
    collect_errors=true,
  )
  assert_eq(stray_option.to_html(pretty=false), "<select></select>")
  assert_eq(stray_option.errors.length(), 1)
  assert_eq(stray_option.errors[0].code, "unexpected-end-tag-in-select")
  let input = @html_parser.parse_fragment(
    "<select><input name=x></select>",
    collect_errors=true,
  )
  assert_eq(input.to_html(pretty=false), "<select></select><input name=\"x\">")
  assert_eq(input.errors.length(), 2)
  assert_eq(input.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(input.errors[1].code, "unexpected-end-tag")
  let textarea = @html_parser.parse_fragment(
    "<select><textarea>hi</textarea></select>",
    collect_errors=true,
  )
  assert_eq(
    textarea.to_html(pretty=false),
    "<select></select><textarea>hi</textarea>",
  )
  assert_eq(textarea.errors.length(), 2)
  assert_eq(textarea.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(textarea.errors[1].code, "unexpected-end-tag")
  let table = @html_parser.parse_fragment(
    "<select><table><tr><td>x</td></tr></table></select>",
    collect_errors=true,
  )
  assert_eq(
    table.to_html(pretty=false),
    "<select></select><table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(table.errors.length(), 2)
  assert_eq(table.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(table.errors[1].code, "unexpected-end-tag")
  let table_cell = @html_parser.parse_fragment(
    "<select><td>x</td></select>",
    collect_errors=true,
  )
  assert_eq(table_cell.to_html(pretty=false), "<select></select>x")
  assert_eq(table_cell.errors.length(), 4)
  assert_eq(table_cell.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(table_cell.errors[1].code, "unexpected-start-tag-ignored")
  assert_eq(table_cell.errors[2].code, "unexpected-end-tag")
  assert_eq(table_cell.errors[3].code, "unexpected-end-tag")
  let table_col = @html_parser.parse_fragment(
    "<select><col>x</col></select>",
    collect_errors=true,
  )
  assert_eq(table_col.to_html(pretty=false), "<select></select><col>x")
  assert_eq(table_col.errors.length(), 3)
  assert_eq(table_col.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(table_col.errors[1].code, "unexpected-end-tag")
  assert_eq(table_col.errors[2].code, "unexpected-end-tag")
  let outside_select = @html_parser.parse_fragment(
    "</optgroup></option></menuitem>",
    collect_errors=true,
  )
  assert_eq(outside_select.to_html(pretty=false), "")
  assert_eq(outside_select.errors.length(), 3)
  for error in outside_select.errors {
    assert_eq(error.code, "unexpected-end-tag")
  }
}

///|
test "parser populates selectedcontent from selected option" {
  let no_options = @html_parser.parse_fragment(
    "<select><selectedcontent></selectedcontent></select>",
    collect_errors=true,
  )
  assert_eq(
    no_options.to_html(pretty=false),
    "<select><selectedcontent></selectedcontent></select>",
  )
  assert_eq(no_options.errors.length(), 2)
  assert_eq(no_options.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(no_options.errors[1].code, "unexpected-end-tag-in-select")
  let first = @html_parser.parse_fragment(
    "<select><option>one</option><option>two</option><selectedcontent></selectedcontent></select>",
    collect_errors=true,
  )
  assert_eq(
    first.to_html(pretty=false),
    "<select><option>one</option><option>two</option><selectedcontent>one</selectedcontent></select>",
  )
  assert_eq(first.errors.length(), 2)
  assert_eq(first.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(first.errors[1].code, "unexpected-end-tag-in-select")
  let selected = @html_parser.parse_fragment(
    "<select><option>one</option><option selected>two <b>bold</b></option><selectedcontent></selectedcontent></select>",
    collect_errors=true,
  )
  assert_eq(
    selected.to_html(pretty=false),
    "<select><option>one</option><option selected>two <b>bold</b></option><selectedcontent>two <b>bold</b></selectedcontent></select>",
  )
  assert_eq(selected.errors.length(), 2)
  let existing = @html_parser.parse_fragment(
    "<select><option selected>one</option><selectedcontent>old</selectedcontent></select>",
    collect_errors=true,
  )
  assert_eq(
    existing.to_html(pretty=false),
    "<select><option selected>one</option><selectedcontent>oldone</selectedcontent></select>",
  )
  assert_eq(existing.errors.length(), 2)
  let nested = @html_parser.parse_fragment(
    "<select><optgroup><option selected><span>x</span></option></optgroup><selectedcontent></selectedcontent></select>",
    collect_errors=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<select><optgroup><option selected><span>x</span></option></optgroup><selectedcontent><span>x</span></selectedcontent></select>",
  )
  assert_eq(nested.errors.length(), 4)
  assert_eq(nested.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(nested.errors[1].code, "unexpected-end-tag-in-select")
  assert_eq(nested.errors[2].code, "unexpected-start-tag-in-select")
  assert_eq(nested.errors[3].code, "unexpected-end-tag-in-select")
  let two_selects = @html_parser.parse_fragment(
    "<select><option selected>a</option><selectedcontent></selectedcontent></select><select><option>b</option><selectedcontent></selectedcontent></select>",
    collect_errors=true,
  )
  assert_eq(
    two_selects.to_html(pretty=false),
    "<select><option selected>a</option><selectedcontent>a</selectedcontent></select><select><option>b</option><selectedcontent>b</selectedcontent></select>",
  )
  assert_eq(two_selects.errors.length(), 4)
}
