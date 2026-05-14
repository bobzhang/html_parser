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
