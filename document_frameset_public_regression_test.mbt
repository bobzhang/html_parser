///|
test "document parser scaffolds framesets outside body" {
  let frameset = @html_parser.parse(
    "<!doctype html><html><head></head><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    frameset.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(frameset.errors.length(), 0)
  let nested = @html_parser.parse(
    "<!doctype html><frameset><frame src=x><frameset></frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset><frame src=\"x\"></frame><frameset></frameset></frameset></html>",
  )
  assert_eq(nested.errors.length(), 0)
  let inner_tag = @html_parser.parse(
    "<!doctype html><frameset><p>x</p><frame src=y></frameset>",
    collect_errors=true,
  )
  assert_eq(
    inner_tag.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset><frame src=\"y\"></frame></frameset></html>",
  )
  assert_eq(inner_tag.errors.length(), 2)
  assert_eq(inner_tag.errors[0].code, "unexpected-token-in-frameset")
  assert_eq(inner_tag.errors[1].code, "unexpected-token-in-frameset")
  let html_inside = @html_parser.parse(
    "<!doctype html><frameset><html id=x><frame src=y></frameset>",
    collect_errors=true,
  )
  assert_eq(
    html_inside.to_html(pretty=false),
    "<!DOCTYPE html><html id=\"x\"><head></head><frameset></frameset></html>",
  )
  assert_eq(html_inside.errors.length(), 2)
  assert_eq(html_inside.errors[0].code, "unexpected-start-tag")
  assert_eq(html_inside.errors[1].code, "unexpected-start-tag-ignored")
  guard html_inside.errors[0].column is Some(36) else {
    fail("expected html-in-frameset error at close bracket")
  }
  guard html_inside.errors[1].column is Some(49) else {
    fail("expected ignored frame after html-in-frameset at close bracket")
  }
  let html_inside_stray_p_end = @html_parser.parse(
    "<!doctype html><frameset><html id=x></p></frameset>",
    collect_errors=true,
  )
  assert_eq(
    html_inside_stray_p_end.to_html(pretty=false),
    "<!DOCTYPE html><html id=\"x\"><head></head><frameset><p></p></frameset></html>",
  )
  assert_eq(html_inside_stray_p_end.errors.length(), 2)
  assert_eq(html_inside_stray_p_end.errors[0].code, "unexpected-start-tag")
  assert_eq(html_inside_stray_p_end.errors[1].code, "unexpected-end-tag")
  guard html_inside_stray_p_end.errors[0].column is Some(36) else {
    fail("expected html-in-frameset reprocess error at close bracket")
  }
  guard html_inside_stray_p_end.errors[1].column is Some(40) else {
    fail("expected reprocessed paragraph end error at close bracket")
  }
  let explicit_html_inside = @html_parser.parse(
    "<!doctype html><html><frameset><html id=x><frame src=y></frameset>",
    collect_errors=true,
  )
  assert_eq(
    explicit_html_inside.to_html(pretty=false),
    "<!DOCTYPE html><html id=\"x\"><head></head><frameset></frameset></html>",
  )
  assert_eq(explicit_html_inside.errors.length(), 2)
  assert_eq(explicit_html_inside.errors[0].code, "unexpected-start-tag")
  assert_eq(explicit_html_inside.errors[1].code, "unexpected-start-tag-ignored")
  guard explicit_html_inside.errors[0].column is Some(42) else {
    fail("expected explicit html-in-frameset error at close bracket")
  }
  guard explicit_html_inside.errors[1].column is Some(55) else {
    fail("expected explicit ignored frame after html-in-frameset")
  }
  let trailing_space = @html_parser.parse(
    "<!doctype html><frameset></frameset>   ",
    collect_errors=true,
  )
  assert_eq(
    trailing_space.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset>   </html>",
  )
  assert_eq(trailing_space.errors.length(), 0)
  let noframes = @html_parser.parse(
    "<!doctype html><frameset><noframes><p>x</p></noframes></frameset>",
    collect_errors=true,
  )
  assert_eq(
    noframes.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset><noframes>&lt;p&gt;x&lt;/p&gt;</noframes></frameset></html>",
  )
  assert_eq(noframes.errors.length(), 0)
}

///|
test "document parser replaces implicit body before frameset" {
  let discarded_body = @html_parser.parse(
    "<!doctype html><meta name=x>  <p><b></b></p><!--drop--><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    discarded_body.to_html(pretty=false),
    "<!DOCTYPE html><html><head><meta name=\"x\">  </head><frameset></frameset></html>",
  )
  assert_eq(discarded_body.errors.length(), 0)
  let preserved_head_comment = @html_parser.parse(
    "<!doctype html><meta name=x>  <!--keep--><figure></figure><!--drop--><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    preserved_head_comment.to_html(pretty=false),
    "<!DOCTYPE html><html><head><meta name=\"x\">  <!--keep--></head><frameset></frameset></html>",
  )
  assert_eq(preserved_head_comment.errors.length(), 0)
  let text_blocks_frameset = @html_parser.parse(
    "<!doctype html><meta name=x>  <p>x</p><!--keep--><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    text_blocks_frameset.to_html(pretty=false),
    "<!DOCTYPE html><html><head><meta name=\"x\">  </head><body><p>x</p><!--keep--></body></html>",
  )
  assert_eq(text_blocks_frameset.errors.length(), 2)
  assert_eq(text_blocks_frameset.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(text_blocks_frameset.errors[1].code, "unexpected-end-tag")
}
