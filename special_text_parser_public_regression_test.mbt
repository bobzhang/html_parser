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
