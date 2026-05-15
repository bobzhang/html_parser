///|
test "parser handles nested tags attributes comments and doctype" {
  let doc = @html_parser.parse(
    "<!doctype html><p id='x' class=\"intro lead\">Hi &amp; bye<!--ok--></p>",
    collect_errors=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p id=\"x\" class=\"intro lead\">Hi &amp; bye<!--ok--></p></body></html>",
  )
  assert_eq(doc.errors.length(), 0)
  assert_eq(doc.to_text(separator="", strip=false), "Hi & bye")
}

///|
test "parser cursor advances by unicode character length" {
  let doc = @html_parser.parse_fragment("<p>😀 &lt; ok</p>")
  assert_eq(doc.to_html(pretty=false), "<p>😀 &lt; ok</p>")
  assert_eq(doc.to_text(separator="", strip=false), "😀 < ok")
}

///|
test "parser creates empty paragraph for stray p end tags" {
  let root = @html_parser.parse_fragment("</p>after", collect_errors=true)
  assert_eq(root.to_html(pretty=false), "<p></p>after")
  assert_eq(root.errors.length(), 1)
  assert_eq(root.errors[0].code, "unexpected-end-tag")
  let nested = @html_parser.parse_fragment("<div></p>after</div>")
  assert_eq(nested.to_html(pretty=false), "<div><p></p>after</div>")
}

///|
test "parser reports early ancestor end tags after implied end tags" {
  let implied = @html_parser.parse_fragment(
    "<div><p>x</div>after",
    collect_errors=true,
  )
  assert_eq(implied.to_html(pretty=false), "<div><p>x</p></div>after")
  assert_eq(implied.errors.length(), 0)
  let early = @html_parser.parse_fragment(
    "<div><span>x</div>after",
    collect_errors=true,
  )
  assert_eq(early.to_html(pretty=false), "<div><span>x</span></div>after")
  assert_eq(early.errors.length(), 1)
  assert_eq(early.errors[0].code, "end-tag-too-early")
}

///|
test "parser closes current heading before another heading start" {
  let fragment = @html_parser.parse_fragment("<p>intro<h1>head<h2>next")
  assert_eq(
    fragment.to_html(pretty=false),
    "<p>intro</p><h1>head</h1><h2>next</h2>",
  )
  let nested_block = @html_parser.parse_fragment("<h1>head<div>body</div>")
  assert_eq(nested_block.to_html(pretty=false), "<h1>head<div>body</div></h1>")
}

///|
test "parser closes open headings for mismatched heading end tags" {
  let doc = @html_parser.parse_fragment(
    "<h1><span>one</h2>after",
    collect_errors=true,
  )
  assert_eq(doc.to_html(pretty=false), "<h1><span>one</span></h1>after")
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "end-tag-too-early")
  let stray = @html_parser.parse_fragment("</h1>after", collect_errors=true)
  assert_eq(stray.to_html(pretty=false), "after")
  assert_eq(stray.errors[0].code, "unexpected-end-tag")
}

///|
test "parser treats br end tags as recovered br elements" {
  let paragraph = @html_parser.parse_fragment(
    "<p>one</br>two",
    collect_errors=true,
  )
  assert_eq(paragraph.to_html(pretty=false), "<p>one</p><br>two")
  assert_eq(paragraph.errors.length(), 1)
  assert_eq(paragraph.errors[0].code, "unexpected-end-tag")
  let loose = @html_parser.parse_fragment("a</br>b")
  assert_eq(loose.to_html(pretty=false), "a<br>b")
}

///|
test "parser tracks origins for end-tag recovery elements" {
  let before_html = @html_parser.parse("</br>", track_node_locations=true)
  guard before_html.query_one("br") is Some(before_br) else {
    fail("expected before-html br")
  }
  assert_node_origin(before_br, 0, 1, 1)
  let paragraph = @html_parser.parse_fragment(
    "<p>one</br>two",
    track_node_locations=true,
  )
  guard paragraph.query_one("br") is Some(br) else { fail("expected br") }
  assert_node_origin(br, 6, 1, 7)
  let stray_p = @html_parser.parse_fragment(
    "<div></p>after</div>",
    track_node_locations=true,
  )
  guard stray_p.query_one("p") is Some(p) else { fail("expected recovered p") }
  assert_node_origin(p, 5, 1, 6)
}

///|
test "parser treats image start tags as img elements" {
  let doc = @html_parser.parse_fragment(
    "<p>a<image src=x>b</p>",
    collect_errors=true,
  )
  assert_eq(doc.to_html(pretty=false), "<p>a<img src=\"x\">b</p>")
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "image-start-tag")
  let loose = @html_parser.parse_fragment("<image>text</image>")
  assert_eq(loose.to_html(pretty=false), "<img>text")
}

///|
test "parser ignores self closing slash on non void html elements" {
  let div = @html_parser.parse_fragment("<div/>x")
  assert_eq(div.to_html(pretty=false), "<div>x</div>")
  let paragraph = @html_parser.parse_fragment("<p/>x")
  assert_eq(paragraph.to_html(pretty=false), "<p>x</p>")
  let script = @html_parser.parse_fragment("<script/>x</script>")
  assert_eq(script.to_html(pretty=false), "<script>x</script>")
  let voids = @html_parser.parse_fragment("<br/>x<img/>")
  assert_eq(voids.to_html(pretty=false), "<br>x<img>")
}

///|
test "parser closes open paragraphs before paragraph and block starts" {
  let fragment = @html_parser.parse_fragment("<p>one<p>two<div>three</div>")
  assert_eq(
    fragment.to_html(pretty=false),
    "<p>one</p><p>two</p><div>three</div>",
  )
  let doc = @html_parser.parse("<p>one<div>two</div>")
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head></head><body><p>one</p><div>two</div></body></html>",
  )
}

///|
test "parser reconstructs active formatting across paragraph recovery" {
  let split = @html_parser.parse_fragment(
    "<p><b>one<p>two</b>",
    track_node_locations=true,
  )
  assert_eq(split.to_html(pretty=false), "<p><b>one</b></p><p><b>two</b></p>")
  let split_bold = split.root.query("b")
  guard split_bold.length() == 2 else { fail("expected reconstructed bold") }
  assert_node_origin(split_bold[0], 3, 1, 4)
  assert_node_origin(split_bold[1], 3, 1, 4)
  let trailing = @html_parser.parse_fragment(
    "<p><b>one</p>two",
    track_node_locations=true,
  )
  assert_eq(trailing.to_html(pretty=false), "<p><b>one</b></p><b>two</b>")
  let trailing_bold = trailing.root.query("b")
  guard trailing_bold.length() == 2 else {
    fail("expected trailing reconstructed bold")
  }
  assert_node_origin(trailing_bold[0], 3, 1, 4)
  assert_node_origin(trailing_bold[1], 3, 1, 4)
  let inline_start = @html_parser.parse_fragment(
    "<p><b>one</p><span>two</span>",
    track_node_locations=true,
  )
  assert_eq(
    inline_start.to_html(pretty=false),
    "<p><b>one</b></p><b><span>two</span></b>",
  )
  let inline_bold = inline_start.root.query("b")
  guard inline_bold.length() == 2 else {
    fail("expected inline reconstructed bold")
  }
  assert_node_origin(inline_bold[0], 3, 1, 4)
  assert_node_origin(inline_bold[1], 3, 1, 4)
  let block_start = @html_parser.parse_fragment(
    "<p><b>one</p><div>two</div>",
    track_node_locations=true,
  )
  assert_eq(
    block_start.to_html(pretty=false),
    "<p><b>one</b></p><div><b>two</b></div>",
  )
  let block_bold = block_start.root.query("b")
  guard block_bold.length() == 2 else {
    fail("expected block reconstructed bold")
  }
  assert_node_origin(block_bold[0], 3, 1, 4)
  assert_node_origin(block_bold[1], 3, 1, 4)
}

///|
test "parser adoption agency preserves formatting origins" {
  let inline = @html_parser.parse_fragment(
    "<b><i>1</b>2</i>",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(inline.to_html(pretty=false), "<b><i>1</i></b><i>2</i>")
  assert_eq(inline.errors.length(), 1)
  assert_eq(inline.errors[0].code, "adoption-agency-1.3")
  let inline_bold = inline.root.query("b")
  guard inline_bold.length() == 1 else { fail("expected one inline bold") }
  assert_node_origin(inline_bold[0], 0, 1, 1)
  let inline_italic = inline.root.query("i")
  guard inline_italic.length() == 2 else { fail("expected replacement italic") }
  assert_node_origin(inline_italic[0], 3, 1, 4)
  assert_node_origin(inline_italic[1], 3, 1, 4)
  let block = @html_parser.parse_fragment(
    "<b><p>1</b>2",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(block.to_html(pretty=false), "<b></b><p><b>1</b>2</p>")
  assert_eq(block.errors.length(), 1)
  assert_eq(block.errors[0].code, "adoption-agency-1.3")
  let block_bold = block.root.query("b")
  guard block_bold.length() == 2 else {
    fail("expected block replacement bold")
  }
  assert_node_origin(block_bold[0], 0, 1, 1)
  assert_node_origin(block_bold[1], 0, 1, 1)
  let nested = @html_parser.parse_fragment(
    "<b><i><p>1</b>2</i>",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<b><i></i></b><i></i><p><i><b>1</b>2</i></p>",
  )
  assert_eq(nested.errors.length(), 2)
  assert_eq(nested.errors[0].code, "adoption-agency-1.3")
  assert_eq(nested.errors[1].code, "adoption-agency-1.3")
  let nested_bold = nested.root.query("b")
  guard nested_bold.length() == 2 else {
    fail("expected nested replacement bold")
  }
  assert_node_origin(nested_bold[0], 0, 1, 1)
  assert_node_origin(nested_bold[1], 0, 1, 1)
  let nested_italic = nested.root.query("i")
  guard nested_italic.length() == 3 else {
    fail("expected nested replacement italic")
  }
  assert_node_origin(nested_italic[0], 3, 1, 4)
  assert_node_origin(nested_italic[1], 3, 1, 4)
  assert_node_origin(nested_italic[2], 3, 1, 4)
}

///|
test "parser handles active formatting duplicate starts" {
  let anchors = @html_parser.parse_fragment(
    "<a><a>x</a>y</a>",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(anchors.to_html(pretty=false), "<a></a><a>x</a>y")
  assert_eq(anchors.errors.length(), 2)
  assert_eq(anchors.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(anchors.errors[1].code, "adoption-agency-1.3")
  let anchor_nodes = anchors.root.query("a")
  guard anchor_nodes.length() == 2 else { fail("expected repeated anchors") }
  assert_node_origin(anchor_nodes[0], 0, 1, 1)
  assert_node_origin(anchor_nodes[1], 3, 1, 4)
  let nobr = @html_parser.parse_fragment(
    "<nobr><nobr>x</nobr>y</nobr>",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(nobr.to_html(pretty=false), "<nobr></nobr><nobr>x</nobr>y")
  assert_eq(nobr.errors.length(), 1)
  assert_eq(nobr.errors[0].code, "adoption-agency-1.3")
  let nobr_nodes = nobr.root.query("nobr")
  guard nobr_nodes.length() == 2 else { fail("expected repeated nobr") }
  assert_node_origin(nobr_nodes[0], 0, 1, 1)
  assert_node_origin(nobr_nodes[1], 6, 1, 7)
  let repeated = @html_parser.parse_fragment(
    "<p><b><b><b><b>x</p>y",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    repeated.to_html(pretty=false),
    "<p><b><b><b><b>x</b></b></b></b></p><b><b><b>y</b></b></b>",
  )
  let repeated_bold = repeated.root.query("b")
  guard repeated_bold.length() == 7 else {
    fail("expected capped reconstructed bold entries")
  }
  assert_node_origin(repeated_bold[0], 3, 1, 4)
  assert_node_origin(repeated_bold[1], 6, 1, 7)
  assert_node_origin(repeated_bold[2], 9, 1, 10)
  assert_node_origin(repeated_bold[3], 12, 1, 13)
  assert_node_origin(repeated_bold[4], 6, 1, 7)
  assert_node_origin(repeated_bold[5], 9, 1, 10)
  assert_node_origin(repeated_bold[6], 12, 1, 13)
  let repeated_attrs = @html_parser.parse_fragment(
    "<p><b class=x><b class=x><b class=x><b class=x>z</p>tail",
  )
  assert_eq(
    repeated_attrs.to_html(pretty=false),
    "<p><b class=\"x\"><b class=\"x\"><b class=\"x\"><b class=\"x\">z</b></b></b></b></p><b class=\"x\"><b class=\"x\"><b class=\"x\">tail</b></b></b>",
  )
  let mixed_attrs = @html_parser.parse_fragment(
    "<p><b class=x><b class=x id=y><b class=x id=y><b class=x id=y><b class=x id=y>z</p>tail",
  )
  assert_eq(
    mixed_attrs.to_html(pretty=false),
    "<p><b class=\"x\"><b class=\"x\" id=\"y\"><b class=\"x\" id=\"y\"><b class=\"x\" id=\"y\"><b class=\"x\" id=\"y\">z</b></b></b></b></b></p><b class=\"x\"><b class=\"x\" id=\"y\"><b class=\"x\" id=\"y\"><b class=\"x\" id=\"y\">tail</b></b></b></b>",
  )
  let mismatched_attrs = @html_parser.parse_fragment(
    "<p><b class=x><b class=y><b class=x><b class=y><b class=x>z</p>tail",
  )
  assert_eq(
    mismatched_attrs.to_html(pretty=false),
    "<p><b class=\"x\"><b class=\"y\"><b class=\"x\"><b class=\"y\"><b class=\"x\">z</b></b></b></b></b></p><b class=\"x\"><b class=\"y\"><b class=\"x\"><b class=\"y\"><b class=\"x\">tail</b></b></b></b></b>",
  )
}

///|
test "parser clears active formatting at applet-like markers" {
  let stray = @html_parser.parse_fragment("</applet>", collect_errors=true)
  assert_eq(stray.to_html(pretty=false), "")
  assert_eq(stray.errors.length(), 1)
  assert_eq(stray.errors[0].code, "unexpected-end-tag")
  guard stray.errors[0].column is Some(9) else {
    fail("expected stray applet end tag error at tag close")
  }
  let nested_stray = @html_parser.parse_fragment(
    "<p>x</object>y",
    collect_errors=true,
  )
  assert_eq(nested_stray.to_html(pretty=false), "<p>xy</p>")
  assert_eq(nested_stray.errors.length(), 1)
  assert_eq(nested_stray.errors[0].code, "unexpected-end-tag")
  guard nested_stray.errors[0].column is Some(13) else {
    fail("expected stray object end tag error at tag close")
  }
  let object = @html_parser.parse_fragment(
    "<p><object><b>x</object>y",
    track_node_locations=true,
  )
  assert_eq(object.to_html(pretty=false), "<p><object><b>x</b></object>y</p>")
  let object_bold = object.root.query("b")
  guard object_bold.length() == 1 else {
    fail("expected object-local bold only")
  }
  assert_node_origin(object_bold[0], 11, 1, 12)
  let marquee = @html_parser.parse_fragment(
    "<p><marquee><b>x</marquee>y",
    track_node_locations=true,
  )
  assert_eq(
    marquee.to_html(pretty=false),
    "<p><marquee><b>x</b></marquee>y</p>",
  )
  let marquee_bold = marquee.root.query("b")
  guard marquee_bold.length() == 1 else {
    fail("expected marquee-local bold only")
  }
  assert_node_origin(marquee_bold[0], 12, 1, 13)
  let mixed = @html_parser.parse_fragment(
    "<p><b>before<object><i>in</object>after</p>tail",
    track_node_locations=true,
  )
  assert_eq(
    mixed.to_html(pretty=false),
    "<p><b>before<object><i>in</i></object>after</b></p><b>tail</b>",
  )
  let mixed_bold = mixed.root.query("b")
  guard mixed_bold.length() == 2 else {
    fail("expected outer bold reconstruction")
  }
  assert_node_origin(mixed_bold[0], 3, 1, 4)
  assert_node_origin(mixed_bold[1], 3, 1, 4)
  let mixed_italic = mixed.root.query("i")
  guard mixed_italic.length() == 1 else {
    fail("expected object-local italic only")
  }
  assert_node_origin(mixed_italic[0], 20, 1, 21)
}

///|
test "parser clears active formatting at caption and template markers" {
  let template = @html_parser.parse_fragment(
    "<template><b>x</template>y",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(template.to_html(pretty=false), "<template><b>x</b></template>y")
  assert_eq(template.errors.length(), 0)
  let template_bold = template.root.query("b")
  guard template_bold.length() == 1 else {
    fail("expected template-local bold only")
  }
  assert_node_origin(template_bold[0], 10, 1, 11)
  let template_outer = @html_parser.parse_fragment(
    "<b>before<template><i>in</template>after",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    template_outer.to_html(pretty=false),
    "<b>before<template><i>in</i></template>after</b>",
  )
  assert_eq(template_outer.errors.length(), 1)
  assert_eq(template_outer.errors[0].code, "expected-closing-tag-but-got-eof")
  let template_outer_bold = template_outer.root.query("b")
  guard template_outer_bold.length() == 1 else {
    fail("expected outer template bold only")
  }
  assert_node_origin(template_outer_bold[0], 0, 1, 1)
  let template_italic = template_outer.root.query("i")
  guard template_italic.length() == 1 else {
    fail("expected template-local italic only")
  }
  assert_node_origin(template_italic[0], 19, 1, 20)
  let caption = @html_parser.parse_fragment(
    "<table><caption><b>x</caption></table>y",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><caption><b>x</b></caption></table>y",
  )
  assert_eq(caption.errors.length(), 0)
  let caption_bold = caption.root.query("b")
  guard caption_bold.length() == 1 else {
    fail("expected caption-local bold only")
  }
  assert_node_origin(caption_bold[0], 16, 1, 17)
  let caption_outer = @html_parser.parse_fragment(
    "<b>before<table><caption><i>cap</caption></table>after",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    caption_outer.to_html(pretty=false),
    "<b>before<table><caption><i>cap</i></caption></table>after</b>",
  )
  assert_eq(caption_outer.errors.length(), 1)
  assert_eq(caption_outer.errors[0].code, "expected-closing-tag-but-got-eof")
  let caption_outer_bold = caption_outer.root.query("b")
  guard caption_outer_bold.length() == 1 else {
    fail("expected outer caption bold only")
  }
  assert_node_origin(caption_outer_bold[0], 0, 1, 1)
  let caption_italic = caption_outer.root.query("i")
  guard caption_italic.length() == 1 else {
    fail("expected caption-local italic only")
  }
  assert_node_origin(caption_italic[0], 25, 1, 26)
}

///|
test "parser reports implied active formatting end in table view" {
  let row = @html_parser.parse_fragment(
    "<table><a><tr>x</table></a>",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<a></a><a>x</a><table><tbody><tr></tr></tbody></table>",
  )
  assert_eq(row.errors.length(), 3)
  assert_eq(row.errors[0].code, "foster-parenting-start-tag")
  assert_eq(row.errors[1].code, "unexpected-implied-end-tag-in-table-view")
  assert_eq(row.errors[2].code, "adoption-agency-1.3")
  let links = row.root.query("a")
  guard links.length() == 2 else {
    fail("expected original and reconstructed links")
  }
  assert_node_origin(links[0], 7, 1, 8)
  assert_node_origin(links[1], 7, 1, 8)
  guard row.root.query_one("tr") is Some(tr) else {
    fail("expected implied row")
  }
  assert_node_origin(tr, 10, 1, 11)
}

///|
test "parser tracks origins for foreign table recovery helpers" {
  let cell = @html_parser.parse(
    "<!><svg><th><title><n><select><td>",
    track_node_locations=true,
  )
  guard cell.root.query("td").get(0) is Some(td) else {
    fail("expected recovered td")
  }
  assert_node_origin(td, 30, 1, 31)
  let row = @html_parser.parse(
    "<svg><tr><title><section\n><math><p><tr>>",
    track_node_locations=true,
  )
  let trs = row.root.query("tr")
  guard trs.length() == 2 else { fail("expected foreign and recovered tr") }
  assert_node_origin(trs[1], 35, 2, 11)
}

///|
test "fragment table contexts foster active formatting text" {
  let row = @html_parser.parse_fragment(
    "<a><tr>x</tr></a>",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<a></a><tbody><tr><a>x</a></tr></tbody>",
  )
  assert_eq(row.errors.length(), 3)
  assert_eq(row.errors[0].code, "foster-parenting-start-tag")
  assert_eq(row.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(row.errors[2].code, "adoption-agency-1.3")
  let row_links = row.root.query("a")
  guard row_links.length() == 2 else {
    fail("expected fostered and reconstructed links")
  }
  assert_node_origin(row_links[0], 0, 1, 1)
  assert_node_origin(row_links[1], 0, 1, 1)
  let text_row = @html_parser.parse_fragment(
    "<a>x<tr></tr></a>",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(text_row.to_html(pretty=false), "<a>x</a><tbody><tr></tr></tbody>")
  assert_eq(text_row.errors.length(), 4)
  assert_eq(text_row.errors[0].code, "foster-parenting-start-tag")
  assert_eq(text_row.errors[1].code, "foster-parenting-character")
  assert_eq(text_row.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(text_row.errors[3].code, "adoption-agency-1.3")
  let text_only = @html_parser.parse_fragment(
    "<a>x</a>",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(text_only.to_html(pretty=false), "<a>x</a>")
  assert_eq(text_only.errors.length(), 3)
  assert_eq(text_only.errors[0].code, "foster-parenting-start-tag")
  assert_eq(text_only.errors[1].code, "foster-parenting-character")
  assert_eq(text_only.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "parser closes open paragraphs before plaintext and xmp starts" {
  let xmp = @html_parser.parse_fragment("<p>a<xmp>b</xmp>c")
  assert_eq(xmp.to_html(pretty=false), "<p>a</p><xmp>b</xmp>c")
  let plaintext = @html_parser.parse_fragment(
    "<p>a<plaintext>b</plaintext>c",
    collect_errors=true,
  )
  assert_eq(
    plaintext.to_html(pretty=false),
    "<p>a</p><plaintext>b&lt;/plaintext&gt;c</plaintext>",
  )
  assert_eq(plaintext.errors.length(), 1)
  assert_eq(plaintext.errors[0].code, "expected-closing-tag-but-got-eof")
  let textarea = @html_parser.parse_fragment("<p>a<textarea>b</textarea>c")
  assert_eq(textarea.to_html(pretty=false), "<p>a<textarea>b</textarea>c</p>")
  let title = @html_parser.parse_fragment("<p>a<title>b</title>c")
  assert_eq(title.to_html(pretty=false), "<p>a<title>b</title>c</p>")
}

///|
test "parser closes open buttons before repeated button starts" {
  let nested = @html_parser.parse_fragment(
    "<button>one<button>two</button>three</button>",
    collect_errors=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<button>one</button><button>two</button>three",
  )
  assert_eq(nested.errors.length(), 2)
  assert_eq(nested.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(nested.errors[1].code, "unexpected-end-tag")
  let with_formatting = @html_parser.parse_fragment(
    "<button><b>one</b><button>two</button></button>",
    collect_errors=true,
  )
  assert_eq(
    with_formatting.to_html(pretty=false),
    "<button><b>one</b></button><button>two</button>",
  )
  assert_eq(with_formatting.errors.length(), 2)
  assert_eq(
    with_formatting.errors[0].code,
    "unexpected-start-tag-implies-end-tag",
  )
  assert_eq(with_formatting.errors[1].code, "unexpected-end-tag")
  let through_table_header = @html_parser.parse_fragment(
    "<button>outer<table><tr><th><button>inner</button></th></tr></table></button>",
    collect_errors=true,
  )
  assert_eq(
    through_table_header.to_html(pretty=false),
    "<button>outer<table><tbody><tr><th><button>inner</button></th></tr></tbody></table></button>",
  )
  assert_eq(through_table_header.errors.length(), 0)
}

///|
test "parser ignores nested form starts and clears form element on end" {
  let nested = @html_parser.parse_fragment(
    "<form><form>x</form>y</form>",
    collect_errors=true,
  )
  assert_eq(nested.to_html(pretty=false), "<form>x</form>y")
  assert_eq(nested.errors.length(), 2)
  assert_eq(nested.errors[0].code, "unexpected-start-tag")
  assert_eq(nested.errors[1].code, "unexpected-end-tag")
  let paragraph = @html_parser.parse_fragment(
    "<form><p>a<form>b</form>",
    collect_errors=true,
  )
  assert_eq(paragraph.to_html(pretty=false), "<form><p>ab</p></form>")
  assert_eq(paragraph.errors.length(), 1)
  assert_eq(paragraph.errors[0].code, "unexpected-start-tag")
}

///|
test "parser handles form end tags through stored form element" {
  let closes_p = @html_parser.parse_fragment("<p>a<form>b</form>c")
  assert_eq(closes_p.to_html(pretty=false), "<p>a</p><form>b</form>c")
  let stray = @html_parser.parse_fragment("</form>x", collect_errors=true)
  assert_eq(stray.to_html(pretty=false), "x")
  assert_eq(stray.errors.length(), 1)
  assert_eq(stray.errors[0].code, "unexpected-end-tag")
  let removed_by_ancestor = @html_parser.parse_fragment(
    "<div><form><p>x</div>after</form>",
    collect_errors=true,
  )
  assert_eq(
    removed_by_ancestor.to_html(pretty=false),
    "<div><form><p>x</p></form></div>after",
  )
  assert_eq(removed_by_ancestor.errors.length(), 2)
  assert_eq(removed_by_ancestor.errors[0].code, "end-tag-too-early")
  assert_eq(removed_by_ancestor.errors[1].code, "unexpected-end-tag")
}

///|
test "parser generates implied ruby annotation end tags" {
  let repeated_base = @html_parser.parse_fragment(
    "<ruby><rb>a<rb>b</ruby>",
    collect_errors=true,
  )
  assert_eq(
    repeated_base.to_html(pretty=false),
    "<ruby><rb>a</rb><rb>b</rb></ruby>",
  )
  assert_eq(repeated_base.errors.length(), 1)
  assert_eq(repeated_base.errors[0].code, "end-tag-too-early")
  let repeated_text = @html_parser.parse_fragment(
    "<ruby><rb>a<rt>b<rt>c</ruby>",
    collect_errors=true,
  )
  assert_eq(
    repeated_text.to_html(pretty=false),
    "<ruby><rb>a</rb><rt>b</rt><rt>c</rt></ruby>",
  )
  assert_eq(repeated_text.errors.length(), 1)
  assert_eq(repeated_text.errors[0].code, "end-tag-too-early")
  let rp_rt = @html_parser.parse_fragment(
    "<ruby><rp>(<rt>a<rp>)</ruby>",
    collect_errors=true,
  )
  assert_eq(
    rp_rt.to_html(pretty=false),
    "<ruby><rp>(</rp><rt>a</rt><rp>)</rp></ruby>",
  )
  assert_eq(rp_rt.errors.length(), 1)
  assert_eq(rp_rt.errors[0].code, "end-tag-too-early")
}

///|
test "parser handles ruby annotation start exclusions" {
  let rtc_text = @html_parser.parse_fragment(
    "<ruby><rtc>a<rt>b</ruby>",
    collect_errors=true,
  )
  assert_eq(
    rtc_text.to_html(pretty=false),
    "<ruby><rtc>a<rt>b</rt></rtc></ruby>",
  )
  assert_eq(rtc_text.errors.length(), 1)
  assert_eq(rtc_text.errors[0].code, "end-tag-too-early")
  let paragraph_rt = @html_parser.parse_fragment("<p>a<rt>b")
  assert_eq(paragraph_rt.to_html(pretty=false), "<p>a</p><rt>b</rt>")
  let paragraph_rb = @html_parser.parse_fragment("<p>a<rb>b")
  assert_eq(paragraph_rb.to_html(pretty=false), "<p>a<rb>b</rb></p>")
  let loose = @html_parser.parse_fragment("<rb>a<rt>b<rtc>c<rb>d")
  assert_eq(
    loose.to_html(pretty=false),
    "<rb>a</rb><rt>b</rt><rtc>c</rtc><rb>d</rb>",
  )
  let special = @html_parser.parse_fragment(
    "<ruby><div>x</ruby>y</div>",
    collect_errors=true,
  )
  assert_eq(special.to_html(pretty=false), "<ruby><div>xy</div></ruby>")
  assert_eq(special.errors.length(), 2)
  assert_eq(special.errors[0].code, "unexpected-end-tag")
  assert_eq(special.errors[1].code, "expected-closing-tag-but-got-eof")
  let inline = @html_parser.parse_fragment(
    "<ruby><span>x</ruby>y</span>",
    collect_errors=true,
  )
  assert_eq(inline.to_html(pretty=false), "<ruby><span>x</span></ruby>y")
  assert_eq(inline.errors.length(), 2)
  assert_eq(inline.errors[0].code, "end-tag-too-early")
  assert_eq(inline.errors[1].code, "unexpected-end-tag")
  let stray = @html_parser.parse_fragment("x</ruby>y", collect_errors=true)
  assert_eq(stray.to_html(pretty=false), "xy")
  assert_eq(stray.errors.length(), 1)
  assert_eq(stray.errors[0].code, "unexpected-end-tag")
}

///|
test "parser assigns namespaces and adjusted names for foreign content" {
  let svg = @html_parser.parse_fragment(
    "<svg><lineargradient><stop/></lineargradient><feimage attributename='href'></feimage></svg>",
    collect_errors=true,
  )
  assert_eq(
    svg.to_html(pretty=false),
    "<svg><linearGradient><stop></stop></linearGradient><feImage attributeName=\"href\"></feImage></svg>",
  )
  assert_eq(svg.errors.length(), 0)
  guard svg.query_one("svg") is Some(svg_node) else { fail("expected svg") }
  assert_true(svg_node.namespace_uri() is Some("svg"))
  let svg_children = svg_node.children()
  assert_eq(svg_children.length(), 2)
  assert_eq(svg_children[0].name(), "linearGradient")
  assert_true(svg_children[0].namespace_uri() is Some("svg"))
  let gradient_children = svg_children[0].children()
  assert_eq(gradient_children.length(), 1)
  assert_eq(gradient_children[0].name(), "stop")
  assert_true(gradient_children[0].namespace_uri() is Some("svg"))
  assert_eq(svg_children[1].name(), "feImage")
  assert_true(svg_children[1].namespace_uri() is Some("svg"))
  let image_attrs = svg_children[1].attrs()
  guard image_attrs["attributeName"] is Some("href") else {
    fail("expected adjusted SVG attribute")
  }
  let math = @html_parser.parse_fragment(
    "<math><mi definitionurl='x'>y</mi></math>",
    collect_errors=true,
  )
  assert_eq(
    math.to_html(pretty=false),
    "<math><mi definitionURL=\"x\">y</mi></math>",
  )
  assert_eq(math.errors.length(), 0)
  guard math.query_one("math") is Some(math_node) else { fail("expected math") }
  assert_true(math_node.namespace_uri() is Some("math"))
  let math_children = math_node.children()
  assert_eq(math_children.length(), 1)
  assert_true(math_children[0].namespace_uri() is Some("math"))
  let mi_attrs = math_children[0].attrs()
  guard mi_attrs["definitionURL"] is Some("x") else {
    fail("expected adjusted MathML attribute")
  }
  let breakout = @html_parser.parse_fragment(
    "<svg><font color='red'>text</font></svg>",
    collect_errors=true,
  )
  assert_eq(
    breakout.to_html(pretty=false),
    "<svg></svg><font color=\"red\">text</font>",
  )
  assert_eq(breakout.errors.length(), 2)
  assert_eq(
    breakout.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(breakout.errors[1].code, "unexpected-end-tag")
  guard breakout.query_one("font") is Some(font_node) else {
    fail("expected breakout font")
  }
  assert_true(font_node.namespace_uri() is Some("html"))
  let integrated = @html_parser.parse_fragment(
    "<math><annotation-xml encoding='text/html'><div>x</div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    integrated.to_html(pretty=false),
    "<math><annotation-xml encoding=\"text/html\"><div>x</div></annotation-xml></math>",
  )
  assert_eq(integrated.errors.length(), 0)
  guard integrated.query_one("div") is Some(integrated_div) else {
    fail("expected integrated div")
  }
  assert_true(integrated_div.namespace_uri() is Some("html"))
  let plain_encoding = @html_parser.parse_fragment(
    "<math><annotation-xml encoding='text/plain'><div></div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    plain_encoding.to_html(pretty=false),
    "<math><annotation-xml encoding=\"text/plain\"></annotation-xml></math><div></div>",
  )
  assert_eq(plain_encoding.errors.length(), 3)
  assert_eq(
    plain_encoding.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(plain_encoding.errors[1].code, "unexpected-end-tag")
  assert_eq(plain_encoding.errors[2].code, "unexpected-end-tag")
  let missing_encoding = @html_parser.parse_fragment(
    "<math><annotation-xml><div>test</div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    missing_encoding.to_html(pretty=false),
    "<math><annotation-xml></annotation-xml></math><div>test</div>",
  )
  assert_eq(missing_encoding.errors.length(), 3)
  assert_eq(
    missing_encoding.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(missing_encoding.errors[1].code, "unexpected-end-tag")
  assert_eq(missing_encoding.errors[2].code, "unexpected-end-tag")
  let empty_encoding = @html_parser.parse_fragment(
    "<math><annotation-xml encoding><div>x</div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    empty_encoding.to_html(pretty=false),
    "<math><annotation-xml encoding></annotation-xml></math><div>x</div>",
  )
  assert_eq(empty_encoding.errors.length(), 3)
  assert_eq(
    empty_encoding.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(empty_encoding.errors[1].code, "unexpected-end-tag")
  assert_eq(empty_encoding.errors[2].code, "unexpected-end-tag")
}

///|
test "public parser fragment contexts stay stable" {
  let table = @html_parser.parse_fragment(
    "<tr><td>A</td></tr>",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(table.to_html(pretty=false), "<tbody><tr><td>A</td></tr></tbody>")
  assert_eq(table.errors.length(), 0)

  let textarea = @html_parser.parse_fragment(
    "<b>x</b>&lt;",
    context=@html_parser.FragmentContext::new("textarea"),
  )
  assert_eq(textarea.to_html(pretty=false), "&lt;b&gt;x&lt;/b&gt;&amp;lt;")
  assert_eq(textarea.to_text(separator="", strip=false), "<b>x</b>&lt;")
  assert_eq(textarea.query("b").length(), 0)

  let svg = @html_parser.parse_fragment(
    "<lineargradient><stop/></lineargradient>",
    context=@html_parser.FragmentContext::new("svg", ns="svg"),
    collect_errors=true,
  )
  assert_eq(
    svg.to_html(pretty=false),
    "<linearGradient><stop></stop></linearGradient>",
  )
  assert_eq(svg.errors.length(), 1)
  assert_eq(svg.errors[0].code, "expected-closing-tag-but-got-eof")
  guard svg.query_one("stop") is Some(stop) else {
    fail("expected SVG stop child")
  }
  assert_true(stop.namespace_uri() is Some("svg"))
}

///|
test "nodes expose empty origin metadata by default" {
  let text = @html_parser.text("hello")
  assert_true(text.origin_offset() is None)
  assert_true(text.origin_line() is None)
  assert_true(text.origin_col() is None)
  assert_true(text.origin_location() is None)
  let parent = @html_parser.element("p", children=[text])
  assert_true(parent.origin_offset() is None)
  assert_true(parent.origin_location() is None)
  let clone = parent.clone_node(deep=true)
  assert_true(clone.origin_offset() is None)
  assert_true(clone.origin_location() is None)
  let doc = @html_parser.parse_fragment("<p>hi</p>")
  guard doc.query_one("p") is Some(parsed_p) else {
    fail("expected parsed paragraph")
  }
  assert_true(parsed_p.origin_offset() is None)
  assert_true(parsed_p.origin_location() is None)
  let parsed_children = parsed_p.children()
  assert_eq(parsed_children.length(), 1)
  assert_true(parsed_children[0].origin_location() is None)
}

///|
test "parser tracks simple element and text origins when requested" {
  let doc = @html_parser.parse_fragment("<p>hi</p>", track_node_locations=true)
  guard doc.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  assert_node_origin(paragraph, 0, 1, 1)
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  assert_eq(children[0].data(), "hi")
  assert_node_origin(children[0], 3, 1, 4)
  let multiline = @html_parser.parse_fragment(
    "lead\n<p>x</p>",
    track_node_locations=true,
  )
  guard multiline.query_one("p") is Some(multiline_p) else {
    fail("expected multiline paragraph")
  }
  assert_node_origin(multiline_p, 5, 2, 1)
  let multiline_children = multiline_p.children()
  assert_eq(multiline_children.length(), 1)
  assert_node_origin(multiline_children[0], 8, 2, 4)
}

///|
test "parser tracks comment and doctype origins when requested" {
  let fragment = @html_parser.parse_fragment(
    "<!--x--><p><!--y--></p>",
    track_node_locations=true,
  )
  let root_children = fragment.root.children()
  assert_eq(root_children.length(), 2)
  assert_true(root_children[0].kind() is Comment)
  assert_node_origin(root_children[0], 0, 1, 1)
  guard fragment.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  assert_node_origin(paragraph, 8, 1, 9)
  let paragraph_children = paragraph.children()
  assert_eq(paragraph_children.length(), 1)
  assert_true(paragraph_children[0].kind() is Comment)
  assert_node_origin(paragraph_children[0], 11, 1, 12)
  let doc = @html_parser.parse(
    "<!doctype html><p>x</p>",
    track_node_locations=true,
  )
  let doc_children = doc.root.children()
  assert_true(doc_children[0].kind() is Doctype)
  assert_node_origin(doc_children[0], 0, 1, 1)
}

///|
test "parse_bytes forwards node origin tracking" {
  let doc = @html_parser.parse_bytes(b"<p>x</p>", track_node_locations=true)
  guard doc.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  assert_node_origin(paragraph, 0, 1, 1)
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  assert_node_origin(children[0], 3, 1, 4)
}

///|
test "public parser source locations and scripting mode stay stable" {
  let located = @html_parser.parse_fragment(
    "lead\n<p id=x>Hi</p>",
    track_node_locations=true,
  )
  guard located.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  guard paragraph.origin_offset() is Some(5) else {
    fail("expected paragraph origin offset")
  }
  guard paragraph.origin_line() is Some(2) else {
    fail("expected paragraph origin line")
  }
  guard paragraph.origin_col() is Some(1) else {
    fail("expected paragraph origin column")
  }
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  guard children[0].origin_location() is Some((2, 9)) else {
    fail("expected text child origin location")
  }

  let enabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=true,
  )
  assert_eq(
    enabled.to_html(pretty=false),
    "<noscript>&lt;b&gt;Hi&lt;/b&gt;</noscript>",
  )
  assert_eq(enabled.query("b").length(), 0)
  let disabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=false,
  )
  assert_eq(disabled.to_html(pretty=false), "<noscript><b>Hi</b></noscript>")
  assert_eq(disabled.query("b").length(), 1)
}

///|
test "parser honors scripting enabled for noscript text mode" {
  let enabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=true,
  )
  assert_eq(
    enabled.to_html(pretty=false),
    "<noscript>&lt;b&gt;Hi&lt;/b&gt;</noscript>",
  )
  assert_eq(enabled.query("b").length(), 0)
  let disabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=false,
  )
  assert_eq(disabled.to_html(pretty=false), "<noscript><b>Hi</b></noscript>")
  assert_eq(disabled.query("b").length(), 1)
}

///|
test "parser handles disabled scripting noscript in head" {
  let doctype = @html_parser.parse(
    "<head><noscript><!DOCTYPE html></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    doctype.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(doctype.errors.length(), 2)
  assert_eq(doctype.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doctype.errors[1].code, "unexpected-doctype")
  let stray_end = @html_parser.parse(
    "<head><noscript></p></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_end.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(stray_end.errors.length(), 2)
  assert_eq(stray_end.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_end.errors[1].code, "unexpected-end-tag")
  let stray_head = @html_parser.parse(
    "<head><noscript><head></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_head.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(stray_head.errors.length(), 2)
  assert_eq(stray_head.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_head.errors[1].code, "unexpected-start-tag")
  let stray_br = @html_parser.parse(
    "<head><noscript></br>x",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_br.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body><br>x</body></html>",
  )
  assert_eq(stray_br.errors.length(), 3)
  assert_eq(stray_br.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_br.errors[1].code, "unexpected-end-tag")
  assert_eq(stray_br.errors[2].code, "unexpected-end-tag")
  let paragraph = @html_parser.parse(
    "<head><noscript><p>x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    paragraph.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body><p>x</p></body></html>",
  )
  assert_eq(paragraph.errors.length(), 3)
  assert_eq(paragraph.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(paragraph.errors[1].code, "unexpected-start-tag")
  assert_eq(paragraph.errors[2].code, "unexpected-end-tag")
  let text = @html_parser.parse(
    "<head><noscript>x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    text.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body>x</body></html>",
  )
  assert_eq(text.errors.length(), 3)
  assert_eq(text.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(text.errors[1].code, "unexpected-start-tag")
  assert_eq(text.errors[2].code, "unexpected-end-tag")
  let leading_space = @html_parser.parse(
    "<head><noscript> x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    leading_space.to_html(pretty=false),
    "<html><head><noscript></noscript> </head><body>x</body></html>",
  )
  assert_eq(leading_space.errors.length(), 3)
  assert_eq(leading_space.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(leading_space.errors[1].code, "unexpected-start-tag")
  assert_eq(leading_space.errors[2].code, "unexpected-end-tag")
  let coerced_leading_space = @html_parser.parse(
    "<head><noscript>\u{000C} x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
    xml_coercion=true,
  )
  assert_eq(
    coerced_leading_space.to_html(pretty=false),
    "<html><head><noscript></noscript>  </head><body>x</body></html>",
  )
  assert_eq(coerced_leading_space.errors.length(), 3)
  assert_eq(
    coerced_leading_space.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(coerced_leading_space.errors[1].code, "unexpected-start-tag")
  assert_eq(coerced_leading_space.errors[2].code, "unexpected-end-tag")
  let allowed = @html_parser.parse(
    "<head><noscript><link rel=x></noscript><p>y",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    allowed.to_html(pretty=false),
    "<html><head><noscript><link rel=\"x\"></noscript></head><body><p>y</p></body></html>",
  )
  assert_eq(allowed.errors.length(), 1)
  assert_eq(allowed.errors[0].code, "expected-doctype-but-got-start-tag")
}

///|
test "parser matches end tags before self closing solidus" {
  let div = @html_parser.parse_fragment("<div>x</div/>y", collect_errors=true)
  assert_eq(div.to_html(pretty=false), "<div>x</div>y")
  assert_eq(div.errors.length(), 0)
  let script = @html_parser.tokenize("<script>x</script/>after")
  guard script.tokens[1] is Characters("x") else {
    fail("expected script text before slash end tag")
  }
  guard script.tokens[2] is Tag(end_script) else {
    fail("expected script end tag before slash")
  }
  assert_true(end_script.kind is EndTag)
  assert_eq(end_script.name, "script")
  assert_eq(end_script.self_closing, true)
  guard script.tokens[3] is Characters("after") else {
    fail("expected text after slash end tag")
  }
}

///|
test "parser recovers malformed ordinary end tags" {
  let solidus = @html_parser.parse_fragment(
    "<div>x</div/foo>y",
    collect_errors=true,
  )
  assert_eq(solidus.to_html(pretty=false), "<div>x</div>y")
  assert_eq(solidus.errors.length(), 1)
  assert_eq(solidus.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard solidus.errors[0].column is Some(13) else {
    fail("expected ordinary end-tag bad solidus at recovered attr")
  }
  let eof = @html_parser.parse_fragment("<div>x</div/foo", collect_errors=true)
  assert_eq(eof.to_html(pretty=false), "<div>x</div>")
  assert_eq(eof.errors.length(), 3)
  assert_eq(eof.errors[0].code, "unexpected-character-after-solidus-in-tag")
  assert_eq(eof.errors[1].code, "eof-in-tag")
  assert_eq(eof.errors[2].code, "expected-closing-tag-but-got-eof")
  guard eof.errors[1].column is Some(15) else {
    fail("expected EOF in malformed ordinary end tag at final name char")
  }
  guard eof.errors[2].column is Some(15) else {
    fail("expected tree EOF after malformed ordinary end tag")
  }
  let null_name = @html_parser.parse_fragment(
    "<div>x</d\u{0000}iv>y",
    collect_errors=true,
  )
  assert_eq(null_name.to_html(pretty=false), "<div>xy</div>")
  assert_eq(null_name.errors.length(), 3)
  assert_eq(null_name.errors[0].code, "unexpected-null-character")
  assert_eq(null_name.errors[1].code, "unexpected-end-tag")
  assert_eq(null_name.errors[2].code, "expected-closing-tag-but-got-eof")
  guard null_name.errors[0].column is Some(10) else {
    fail("expected null in ordinary end tag at column 10")
  }
  guard null_name.errors[1].column is Some(13) else {
    fail("expected mismatched null end tag at the tag close")
  }
  guard null_name.errors[2].column is Some(14) else {
    fail("expected EOF for still-open element after null end tag")
  }
}

///|
test "parser replaces nulls in bogus comment data" {
  let question = @html_parser.parse_fragment(
    "<?a\u{0000}b>",
    collect_errors=true,
  )
  assert_eq(question.to_html(pretty=false), "<!--?a\u{FFFD}b-->")
  assert_eq(question.errors.length(), 1)
  assert_eq(
    question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  let declaration = @html_parser.parse_fragment(
    "<!a\u{0000}b>",
    collect_errors=true,
  )
  assert_eq(declaration.to_html(pretty=false), "<!--a\u{FFFD}b-->")
  assert_eq(declaration.errors.length(), 1)
  assert_eq(declaration.errors[0].code, "incorrectly-opened-comment")
}

///|
test "parser reports abrupt closing of empty comments" {
  let simple = @html_parser.parse_fragment("<!-->", collect_errors=true)
  assert_eq(simple.to_html(pretty=false), "<!---->")
  assert_eq(simple.errors.length(), 1)
  assert_eq(simple.errors[0].code, "abrupt-closing-of-empty-comment")
  guard simple.errors[0].column is Some(5) else {
    fail("expected abrupt empty comment at >")
  }
  let dash = @html_parser.parse_fragment("<!--->", collect_errors=true)
  assert_eq(dash.to_html(pretty=false), "<!---->")
  assert_eq(dash.errors.length(), 1)
  assert_eq(dash.errors[0].code, "abrupt-closing-of-empty-comment")
  guard dash.errors[0].column is Some(6) else {
    fail("expected abrupt empty dash comment at >")
  }
}

///|
test "parser reports incorrectly closed comments" {
  let bang = @html_parser.parse_fragment("<!--x--!>", collect_errors=true)
  assert_eq(bang.to_html(pretty=false), "<!--x-->")
  assert_eq(bang.errors.length(), 1)
  assert_eq(bang.errors[0].code, "incorrectly-closed-comment")
  guard bang.errors[0].column is Some(9) else {
    fail("expected bang close error at >")
  }
  let text = @html_parser.parse_fragment("<!--x--y-->", collect_errors=true)
  assert_eq(text.to_html(pretty=false), "<!--x- -y-->")
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "incorrectly-closed-comment")
  guard text.errors[0].column is Some(8) else {
    fail("expected comment close error at reconsumed text")
  }
}

///|
test "parser reports missing attribute value after equals only" {
  let bare = @html_parser.parse_fragment("<div attr>", collect_errors=true)
  assert_eq(bare.to_html(pretty=false), "<div attr></div>")
  assert_eq(bare.errors.length(), 1)
  assert_eq(bare.errors[0].code, "expected-closing-tag-but-got-eof")
  let missing = @html_parser.parse_fragment("<div attr=>", collect_errors=true)
  assert_eq(missing.to_html(pretty=false), "<div attr></div>")
  assert_eq(missing.errors.length(), 2)
  assert_eq(missing.errors[0].code, "missing-attribute-value")
  assert_eq(missing.errors[1].code, "expected-closing-tag-but-got-eof")
  guard missing.errors[0].column is Some(11) else {
    fail("expected missing value at column 11")
  }
}

///|
test "parser keeps first duplicate attribute value" {
  let doc = @html_parser.parse_fragment(
    "<p id=first id=second class=a class=b>text</p>",
    collect_errors=true,
  )
  assert_eq(doc.to_html(pretty=false), "<p id=\"first\" class=\"a\">text</p>")
  assert_eq(doc.errors.length(), 2)
  assert_eq(doc.errors[0].code, "duplicate-attribute")
  assert_eq(doc.errors[1].code, "duplicate-attribute")
}

///|
test "parser reports attribute name fixture errors" {
  let equals = @html_parser.parse_fragment("<div =abc>", collect_errors=true)
  guard equals.query_one("div") is Some(eq_node) else { fail("expected div") }
  assert_true(eq_node.attrs().contains("=abc"))
  assert_eq(equals.errors.length(), 2)
  assert_eq(
    equals.errors[0].code,
    "unexpected-equals-sign-before-attribute-name",
  )
  assert_eq(equals.errors[1].code, "expected-closing-tag-but-got-eof")
  guard equals.errors[0].column is Some(6) else {
    fail("expected equals attr error at column 6")
  }
  let bad_char = @html_parser.parse_fragment("<div a\"b>", collect_errors=true)
  guard bad_char.query_one("div") is Some(bad_node) else {
    fail("expected div")
  }
  assert_true(bad_node.attrs().contains("a\"b"))
  assert_eq(bad_char.errors.length(), 2)
  assert_eq(bad_char.errors[0].code, "unexpected-character-in-attribute-name")
  assert_eq(bad_char.errors[1].code, "expected-closing-tag-but-got-eof")
  guard bad_char.errors[0].column is Some(7) else {
    fail("expected quote attr error at column 7")
  }
}

///|
test "parser reports unquoted attribute value fixture errors" {
  let less = @html_parser.parse_fragment("<div a=b<c>", collect_errors=true)
  assert_eq(less.to_html(pretty=false), "<div a=\"b&lt;c\"></div>")
  assert_eq(less.errors.length(), 2)
  assert_eq(
    less.errors[0].code,
    "unexpected-character-in-unquoted-attribute-value",
  )
  assert_eq(less.errors[1].code, "expected-closing-tag-but-got-eof")
  guard less.errors[0].column is Some(9) else {
    fail("expected unquoted attr value error at column 9")
  }
  let numeric = @html_parser.parse_fragment(
    "<p title=&#x80>x</p>",
    collect_errors=true,
  )
  assert_eq(numeric.to_html(pretty=false), "<p title=\"\u{20AC}\">x</p>")
  assert_eq(numeric.errors.length(), 2)
  assert_eq(
    numeric.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(numeric.errors[1].code, "control-character-reference")
  assert_eq(numeric.errors[0].category, "tokenizer")
  assert_eq(numeric.errors[1].category, "tokenizer")
  guard numeric.errors[0].column is Some(15) else {
    fail("expected unquoted attr entity error at tag close")
  }
  guard numeric.errors[1].column is Some(15) else {
    fail("expected unquoted attr control error at tag close")
  }
  guard numeric.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  guard paragraph.attrs()["title"] is Some("\u{20AC}") else {
    fail("expected decoded unquoted attribute value")
  }
}

///|
test "parser reports missing whitespace after quoted attribute value" {
  let result = @html_parser.parse_fragment(
    "<div a=\"b\"c=d>",
    collect_errors=true,
  )
  assert_eq(result.to_html(pretty=false), "<div a=\"b\" c=\"d\"></div>")
  assert_eq(result.errors.length(), 2)
  assert_eq(result.errors[0].code, "missing-whitespace-between-attributes")
  assert_eq(result.errors[1].code, "expected-closing-tag-but-got-eof")
  guard result.errors[0].column is Some(11) else {
    fail("expected missing whitespace at adjacent attr name")
  }
}

///|
test "parser recovers invalid self closing start tag fixture case" {
  let fragment = @html_parser.parse_fragment("<div /a>", collect_errors=true)
  assert_eq(fragment.to_html(pretty=false), "<div a></div>")
  assert_eq(fragment.errors.length(), 2)
  assert_eq(
    fragment.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(fragment.errors[1].code, "expected-closing-tag-but-got-eof")
}

///|
test "parser start tag solidus does not skip following whitespace" {
  let fragment = @html_parser.parse_fragment("<div/ >", collect_errors=true)
  assert_eq(fragment.to_html(pretty=false), "<div></div>")
  assert_eq(fragment.errors.length(), 2)
  assert_eq(
    fragment.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(fragment.errors[1].code, "expected-closing-tag-but-got-eof")
  guard fragment.errors[0].column is Some(6) else {
    fail("expected parser whitespace after solidus at column 6")
  }
}

///|
test "parser reports CRLF comment EOF before missing doctype EOF" {
  let parsed_crlf_eof = @html_parser.parse("<!----!\r\n", collect_errors=true)
  assert_eq(parsed_crlf_eof.errors.length(), 2)
  assert_eq(parsed_crlf_eof.errors[0].code, "eof-in-comment")
  assert_eq(parsed_crlf_eof.errors[1].code, "expected-doctype-but-got-eof")
  guard parsed_crlf_eof.errors[0].column is Some(0) else {
    fail("expected parser comment EOF error at column 0")
  }
  guard parsed_crlf_eof.errors[1].column is Some(0) else {
    fail("expected parser doctype EOF error at column 0")
  }
}

///|
test "parser normalizes leading BOM and CRLF in text comment and attr" {
  let doc = @html_parser.parse_fragment(
    "\u{FEFF}<p title='a\rb'>a\r\nb<!--x\ry--></p>",
  )
  assert_eq(doc.to_html(pretty=false), "<p title=\"a\nb\">a\nb<!--x\ny--></p>")
  assert_eq(doc.to_text(separator="", strip=false), "a\nb")
}

///|
test "parser handles null characters in text attributes and text modes" {
  let text = @html_parser.parse_fragment("a\u{0000}b", collect_errors=true)
  assert_eq(text.to_html(pretty=false), "ab")
  assert_eq(text.to_text(separator="", strip=false), "ab")
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "unexpected-null-character")
  guard text.errors[0].column is Some(2) else {
    fail("expected text null at column 2")
  }
  let attr = @html_parser.parse_fragment(
    "<div title=\"a\u{0000}b\">x</div>",
    collect_errors=true,
  )
  assert_eq(attr.to_html(pretty=false), "<div title=\"a�b\">x</div>")
  assert_eq(attr.errors.length(), 1)
  assert_eq(attr.errors[0].code, "unexpected-null-character")
  let unquoted_attr = @html_parser.parse_fragment(
    "<div title=a\u{0000}b>x</div>",
    collect_errors=true,
  )
  assert_eq(unquoted_attr.to_html(pretty=false), "<div title=\"a�b\">x</div>")
  assert_eq(unquoted_attr.errors.length(), 1)
  assert_eq(unquoted_attr.errors[0].code, "unexpected-null-character")
  let attr_name = @html_parser.parse_fragment(
    "<div a\u{0000}b='c'>x</div>",
    collect_errors=true,
  )
  let attr_name_children = attr_name.root.children()
  assert_eq(attr_name_children.length(), 1)
  assert_eq(attr_name_children[0].name(), "div")
  guard attr_name_children[0].attrs()["a\u{FFFD}b"] is Some("c") else {
    fail("expected parser replacement char in attr name")
  }
  assert_eq(attr_name.to_text(separator="", strip=false), "x")
  assert_eq(attr_name.errors.length(), 1)
  assert_eq(attr_name.errors[0].code, "unexpected-null-character")
  let tag_name = @html_parser.parse_fragment(
    "<a\u{0000}b id=x>y</a\u{0000}b>",
    collect_errors=true,
  )
  let tag_name_children = tag_name.root.children()
  assert_eq(tag_name_children.length(), 1)
  assert_eq(tag_name_children[0].name(), "a\u{FFFD}b")
  guard tag_name_children[0].attrs()["id"] is Some("x") else {
    fail("expected attr on null-mutated start tag")
  }
  assert_eq(tag_name_children[0].text(), "y")
  assert_eq(tag_name.to_text(separator="", strip=false), "y")
  assert_eq(tag_name.errors.length(), 2)
  assert_eq(tag_name.errors[0].code, "unexpected-null-character")
  assert_eq(tag_name.errors[1].code, "unexpected-null-character")
  let raw = @html_parser.parse_fragment(
    "<script>a\u{0000}b</script><title>a\u{0000}b</title>",
    collect_errors=true,
  )
  assert_eq(
    raw.to_html(pretty=false),
    "<script>a�b</script><title>a�b</title>",
  )
  assert_eq(raw.errors.length(), 2)
  assert_eq(raw.errors[0].code, "unexpected-null-character")
  assert_eq(raw.errors[1].code, "unexpected-null-character")
  let textarea = @html_parser.parse_fragment(
    "<textarea>\n\u{0000}b</textarea>",
    collect_errors=true,
  )
  assert_eq(textarea.to_html(pretty=false), "<textarea>�b</textarea>")
  assert_eq(textarea.errors[0].code, "unexpected-null-character")
}

///|
test "parser reports noncharacters in input stream" {
  let fragment = @html_parser.parse_fragment(
    "ab\u{FDD0}cd",
    collect_errors=true,
  )
  assert_eq(fragment.to_html(pretty=false), "ab\u{FDD0}cd")
  assert_eq(fragment.errors.length(), 1)
  assert_eq(fragment.errors[0].code, "noncharacter-in-input-stream")
  let invalid_fragment = @html_parser.parse_fragment(
    "<\u{FDD0}",
    collect_errors=true,
  )
  assert_eq(invalid_fragment.to_html(pretty=false), "&lt;\u{FDD0}")
  assert_eq(invalid_fragment.errors.length(), 3)
  assert_eq(invalid_fragment.errors[0].code, "noncharacter-in-input-stream")
  assert_eq(
    invalid_fragment.errors[1].code,
    "invalid-first-character-of-tag-name",
  )
  assert_eq(invalid_fragment.errors[2].code, "noncharacter-in-input-stream")
  let invalid_entity = @html_parser.parse_fragment(
    "<&notit",
    collect_errors=true,
  )
  assert_eq(invalid_entity.to_html(pretty=false), "&lt;¬it")
  assert_eq(invalid_entity.errors.length(), 2)
  assert_eq(
    invalid_entity.errors[0].code,
    "invalid-first-character-of-tag-name",
  )
  assert_eq(
    invalid_entity.errors[1].code,
    "missing-semicolon-after-character-reference",
  )
  let invalid_xml = @html_parser.parse_fragment(
    "<\u{000C}\u{FDD0}&lt;",
    collect_errors=true,
    xml_coercion=true,
  )
  assert_eq(invalid_xml.to_html(pretty=false), "&lt; �&lt;")
  assert_eq(invalid_xml.errors.length(), 2)
  assert_eq(invalid_xml.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_xml.errors[1].code, "noncharacter-in-input-stream")
}

///|
test "parser treats script style title textarea content as text" {
  let doc = @html_parser.parse_fragment(
    "<script><!--a--<b</script><title>a &lt; b</title>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<script><!--a--<<b</script><title>a &lt; b</title>",
  )
  assert_eq(doc.query("b").length(), 0)
  assert_eq(doc.to_text(separator="|", strip=false), "<!--a--<<b|a < b")
  let escaped_end = @html_parser.parse_fragment("<script><!--a--</script>")
  assert_eq(escaped_end.to_html(pretty=false), "<script><!--a--<</script>")
  let comment_end = @html_parser.parse_fragment("<script><!--a--></script>")
  assert_eq(comment_end.to_html(pretty=false), "<script><!--a--></script>")
  let raw_after_comment = @html_parser.parse_fragment(
    "<script><!--a-->x--</script>",
  )
  assert_eq(
    raw_after_comment.to_html(pretty=false),
    "<script><!--a-->x--</script>",
  )
  let double_escaped = @html_parser.parse_fragment(
    "<script><!--<script>x</script>y</script>",
  )
  assert_eq(
    double_escaped.to_text(separator="|", strip=false),
    "<!--<script>x</script>y",
  )
  let dash_dash_less_than = @html_parser.parse_fragment(
    "<script><!----<x</script>",
  )
  assert_eq(
    dash_dash_less_than.to_html(pretty=false),
    "<script><!----<<x</script>",
  )
  let double_escaped_dash = @html_parser.parse_fragment(
    "<script><!--<script>---x</script>tail</script>",
  )
  assert_eq(
    double_escaped_dash.to_html(pretty=false),
    "<script><!--<script>---x&lt;/script>tail</script>",
  )
  let non_script_double_escape_end = @html_parser.parse_fragment(
    "<script><!--<script></style x</script>tail</script>",
  )
  assert_eq(
    non_script_double_escape_end.to_html(pretty=false),
    "<script><!--<script></style x&lt;/script>tail</script>",
  )
}

///|
test "parser ignores one initial newline in pre listing and textarea" {
  let pre = @html_parser.parse_fragment(
    "<pre>\r\nline</pre><listing>\nitem</listing>",
  )
  assert_eq(pre.to_html(pretty=false), "<pre>line</pre><listing>item</listing>")
  let pre_cr = @html_parser.parse_fragment("<pre>\rline</pre>")
  assert_eq(pre_cr.to_html(pretty=false), "<pre>line</pre>")
  let listing_cr = @html_parser.parse_fragment("<listing>\rline</listing>")
  assert_eq(listing_cr.to_html(pretty=false), "<listing>line</listing>")
  let textarea = @html_parser.parse_fragment("<textarea>\nline</textarea>")
  assert_eq(textarea.to_html(pretty=false), "<textarea>line</textarea>")
  let textarea_cr = @html_parser.parse_fragment("<textarea>\rline</textarea>")
  assert_eq(textarea_cr.to_html(pretty=false), "<textarea>line</textarea>")
  let textarea_crlf = @html_parser.parse_fragment(
    "<textarea>\r\nline</textarea>",
  )
  assert_eq(textarea_crlf.to_html(pretty=false), "<textarea>line</textarea>")
  let title = @html_parser.parse_fragment("<title>\nline</title>")
  assert_eq(title.to_html(pretty=false), "<title>\nline</title>")
  let title_cr = @html_parser.parse_fragment("<title>\rline</title>")
  assert_eq(title_cr.to_html(pretty=false), "<title>\nline</title>")
}

///|
test "parser treats xmp and plaintext content as text" {
  let xmp = @html_parser.parse_fragment("<xmp><b>x</b></xmp>after")
  assert_eq(xmp.to_html(pretty=false), "<xmp>&lt;b&gt;x&lt;/b&gt;</xmp>after")
  assert_eq(xmp.query("b").length(), 0)
  let plaintext = @html_parser.parse_fragment(
    "<plaintext><b>x</b></plaintext>after",
    collect_errors=true,
  )
  assert_eq(
    plaintext.to_html(pretty=false),
    "<plaintext>&lt;b&gt;x&lt;/b&gt;&lt;/plaintext&gt;after</plaintext>",
  )
  assert_eq(plaintext.errors[0].code, "expected-closing-tag-but-got-eof")
}

///|
fn assert_script_fragment_eof(
  source : StringView,
  expected_html : String,
  expected_column : Int,
) -> Unit raise {
  let doc = @html_parser.parse_fragment(source, collect_errors=true)
  assert_eq(doc.to_html(pretty=false), expected_html)
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-named-closing-tag-but-got-eof")
  guard doc.errors[0].line is Some(line) else {
    fail("expected script EOF line")
  }
  assert_eq(line, 1)
  guard doc.errors[0].column is Some(column) else {
    fail("expected script EOF column")
  }
  assert_eq(column, expected_column)
}

///|
test "parser reports special text EOF like tree builder" {
  let script = @html_parser.parse_fragment("<script>x", collect_errors=true)
  assert_eq(script.to_html(pretty=false), "<script>x</script>")
  assert_eq(script.errors.length(), 1)
  assert_eq(script.errors[0].code, "expected-named-closing-tag-but-got-eof")
  guard script.errors[0].column is Some(9) else {
    fail("expected script EOF at final text column")
  }
  let textarea = @html_parser.parse_fragment(
    "<textarea>\nx",
    collect_errors=true,
  )
  assert_eq(textarea.to_html(pretty=false), "<textarea>x</textarea>")
  assert_eq(textarea.errors.length(), 1)
  assert_eq(textarea.errors[0].code, "expected-closing-tag-but-got-eof")
  guard textarea.errors[0].line is Some(2) else {
    fail("expected textarea EOF on second line")
  }
  guard textarea.errors[0].column is Some(1) else {
    fail("expected textarea EOF at final text column")
  }
  let xmp = @html_parser.parse_fragment("<xmp>x", collect_errors=true)
  assert_eq(xmp.errors[0].code, "expected-named-closing-tag-but-got-eof")
  let iframe = @html_parser.parse_fragment("<iframe>x", collect_errors=true)
  assert_eq(iframe.errors[0].code, "expected-closing-tag-but-got-eof")
  assert_script_fragment_eof("<script><!--", "<script><!--</script>", 12)
  assert_script_fragment_eof("<script><!---", "<script><!---</script>", 13)
  assert_script_fragment_eof("<script><!--a--", "<script><!--a--</script>", 15)
  assert_script_fragment_eof(
    "<script><!--<script>x", "<script><!--<script>x</script>", 21,
  )
  assert_script_fragment_eof(
    "<script><!--<script>--", "<script><!--<script>--</script>", 22,
  )
  assert_script_fragment_eof(
    "<script><!--<script>--<", "<script><!--<script>--<</script>", 23,
  )
}

///|
test "parser matches malformed special text end tags after solidus" {
  let title = @html_parser.parse(
    "<title>a</title/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    title.to_html(pretty=false),
    "<html><head><title>a</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title.errors.length(), 2)
  assert_eq(title.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(title.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard title.errors[1].column is Some(17) else {
    fail("expected title solidus recovery at column 17")
  }
  let title_attr = @html_parser.parse(
    "<title>a</title foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    title_attr.to_html(pretty=false),
    "<html><head><title>a</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title_attr.errors.length(), 1)
  assert_eq(title_attr.errors[0].code, "expected-doctype-but-got-start-tag")
  let title_self_closing = @html_parser.parse(
    "<title>a</title/><p>b",
    collect_errors=true,
  )
  assert_eq(
    title_self_closing.to_html(pretty=false),
    "<html><head><title>a</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title_self_closing.errors.length(), 1)
  assert_eq(
    title_self_closing.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  let title_eof = @html_parser.parse("<title>a</title/foo", collect_errors=true)
  assert_eq(
    title_eof.to_html(pretty=false),
    "<html><head><title>a</title></head><body></body></html>",
  )
  assert_eq(title_eof.errors.length(), 4)
  assert_eq(title_eof.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    title_eof.errors[1].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(title_eof.errors[2].code, "eof-in-tag")
  assert_eq(title_eof.errors[3].code, "expected-named-closing-tag-but-got-eof")
  guard title_eof.errors[2].column is Some(19) else {
    fail("expected title EOF-in-tag at column 19")
  }
  guard title_eof.errors[3].column is Some(19) else {
    fail("expected title tree-builder EOF at column 19")
  }
  let textarea = @html_parser.parse(
    "<textarea>a</textarea/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    textarea.to_html(pretty=false),
    "<html><head></head><body><textarea>a</textarea><p>b</p></body></html>",
  )
  assert_eq(textarea.errors.length(), 2)
  assert_eq(textarea.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    textarea.errors[1].code,
    "unexpected-character-after-solidus-in-tag",
  )
  guard textarea.errors[1].column is Some(23) else {
    fail("expected textarea solidus recovery at column 23")
  }
  let style = @html_parser.parse(
    "<style>a</style/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    style.to_html(pretty=false),
    "<html><head><style>a</style></head><body><p>b</p></body></html>",
  )
  assert_eq(style.errors.length(), 2)
  assert_eq(style.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(style.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard style.errors[1].column is Some(17) else {
    fail("expected style solidus recovery at column 17")
  }
  let xmp = @html_parser.parse("<xmp>a</xmp/foo><p>b", collect_errors=true)
  assert_eq(
    xmp.to_html(pretty=false),
    "<html><head></head><body><xmp>a</xmp><p>b</p></body></html>",
  )
  assert_eq(xmp.errors.length(), 2)
  assert_eq(xmp.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(xmp.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard xmp.errors[1].column is Some(13) else {
    fail("expected xmp solidus recovery at column 13")
  }
  let script = @html_parser.parse(
    "<script>a</script/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    script.to_html(pretty=false),
    "<html><head><script>a</script></head><body><p>b</p></body></html>",
  )
  assert_eq(script.errors.length(), 2)
  assert_eq(script.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(script.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard script.errors[1].column is Some(19) else {
    fail("expected script solidus recovery at column 19")
  }
  let script_eof = @html_parser.parse(
    "<script>a</script/foo",
    collect_errors=true,
  )
  assert_eq(
    script_eof.to_html(pretty=false),
    "<html><head><script>a</script></head><body></body></html>",
  )
  assert_eq(script_eof.errors.length(), 4)
  assert_eq(script_eof.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    script_eof.errors[1].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(script_eof.errors[2].code, "eof-in-tag")
  assert_eq(script_eof.errors[3].code, "expected-named-closing-tag-but-got-eof")
  guard script_eof.errors[2].column is Some(21) else {
    fail("expected script EOF-in-tag at column 21")
  }
  guard script_eof.errors[3].column is Some(21) else {
    fail("expected script tree-builder EOF at column 21")
  }
}

///|
test "parser treats similarly named special end tags as text" {
  let title = @html_parser.parse(
    "<title>a</titlex></title><p>b",
    collect_errors=true,
  )
  assert_eq(
    title.to_html(pretty=false),
    "<html><head><title>a&lt;/titlex&gt;</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title.errors.length(), 1)
  assert_eq(title.errors[0].code, "expected-doctype-but-got-start-tag")
  let textarea = @html_parser.parse(
    "<textarea>a</textareax></textarea><p>b",
    collect_errors=true,
  )
  assert_eq(
    textarea.to_html(pretty=false),
    "<html><head></head><body><textarea>a&lt;/textareax&gt;</textarea><p>b</p></body></html>",
  )
  assert_eq(textarea.errors.length(), 1)
  assert_eq(textarea.errors[0].code, "expected-doctype-but-got-start-tag")
  let xmp = @html_parser.parse("<xmp>a</xmpx></xmp><p>b", collect_errors=true)
  assert_eq(
    xmp.to_html(pretty=false),
    "<html><head></head><body><xmp>a&lt;/xmpx&gt;</xmp><p>b</p></body></html>",
  )
  assert_eq(xmp.errors.length(), 1)
  assert_eq(xmp.errors[0].code, "expected-doctype-but-got-start-tag")
}

///|
test "tree builder finishes deeply nested parsed HTML without recursion" {
  let html = repeat_for_test("<div>", 1200) +
    "x" +
    repeat_for_test("</div>", 1200)
  let doc = @html_parser.parse(html)
  assert_eq(doc.to_text(separator="", strip=false), "x")
  guard doc.query_one("div") is Some(first_div) else {
    fail("expected parsed deep div")
  }
  assert_eq(first_div.to_text(separator="", strip=false), "x")
}
