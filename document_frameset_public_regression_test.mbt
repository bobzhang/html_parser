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

///|
test "parser tracks origins for frameset helper insertions" {
  let doc = @html_parser.parse(
    "<!doctype html><frameset><frame src=x><frameset></frameset></frameset>",
    track_node_locations=true,
  )
  let framesets = doc.root.query("frameset")
  guard framesets.length() == 2 else { fail("expected nested framesets") }
  assert_node_origin(framesets[0], 15, 1, 16)
  assert_node_origin(framesets[1], 38, 1, 39)
  guard doc.query_one("frame") is Some(frame) else { fail("expected frame") }
  assert_node_origin(frame, 25, 1, 26)
}

///|
test "document parser ignores tokens after frameset" {
  let text = @html_parser.parse(
    "<!DOCTYPE html><html><head></head><frameset></frameset>abc",
    collect_errors=true,
  )
  assert_eq(
    text.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "unexpected-token-after-frameset")
  guard text.errors[0].column is Some(58) else {
    fail("expected post-frameset text error at final text column")
  }
  let paired = @html_parser.parse(
    "<!doctype html><frameset></frameset><p>x</p>",
    collect_errors=true,
  )
  assert_eq(
    paired.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(paired.errors.length(), 3)
  assert_eq(paired.errors[0].code, "unexpected-token-after-frameset")
  assert_eq(paired.errors[1].code, "unexpected-token-in-frameset")
  assert_eq(paired.errors[2].code, "unexpected-token-in-frameset")
  let extra_end = @html_parser.parse(
    "<!doctype html><frameset></frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    extra_end.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(extra_end.errors.length(), 1)
  assert_eq(extra_end.errors[0].code, "unexpected-token-after-frameset")
  let stray_end = @html_parser.parse(
    "<!doctype html><frameset></p></frameset>",
    collect_errors=true,
  )
  assert_eq(
    stray_end.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(stray_end.errors.length(), 1)
  assert_eq(stray_end.errors[0].code, "unexpected-token-in-frameset")
  let after_stray_end = @html_parser.parse(
    "<!doctype html><frameset></frameset></p>",
    collect_errors=true,
  )
  assert_eq(
    after_stray_end.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(after_stray_end.errors.length(), 2)
  assert_eq(after_stray_end.errors[0].code, "unexpected-token-after-frameset")
  assert_eq(after_stray_end.errors[1].code, "unexpected-token-in-frameset")
  let void_start = @html_parser.parse(
    "<!doctype html><frameset></frameset><br>",
    collect_errors=true,
  )
  assert_eq(
    void_start.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(void_start.errors.length(), 2)
  assert_eq(void_start.errors[0].code, "unexpected-token-after-frameset")
  assert_eq(void_start.errors[1].code, "unexpected-token-in-frameset")
  let noframes = @html_parser.parse(
    "<!doctype html><frameset></frameset><noframes>x</noframes>",
    collect_errors=true,
  )
  assert_eq(
    noframes.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset><noframes>x</noframes></html>",
  )
  assert_eq(noframes.errors.length(), 0)
  let body = @html_parser.parse(
    "<!doctype html><body>x</body><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    body.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body>x</body></html>",
  )
  assert_eq(body.errors.length(), 2)
  assert_eq(body.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(body.errors[1].code, "unexpected-end-tag")
}

///|
test "document parser reprocesses starts after frameset" {
  let sibling_frameset = @html_parser.parse(
    "<!doctype html><frameset></frameset><frameset><frame></frameset>",
    collect_errors=true,
  )
  assert_eq(
    sibling_frameset.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset><frameset><frame></frame></frameset></html>",
  )
  assert_eq(sibling_frameset.errors.length(), 1)
  assert_eq(sibling_frameset.errors[0].code, "unexpected-token-after-frameset")
  guard sibling_frameset.errors[0].column is Some(46) else {
    fail("expected post-frameset sibling frameset error at close bracket")
  }
  let sibling_frame = @html_parser.parse(
    "<!doctype html><frameset></frameset><frame>x",
    collect_errors=true,
  )
  assert_eq(
    sibling_frame.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset><frame></frame></html>",
  )
  assert_eq(sibling_frame.errors.length(), 1)
  assert_eq(sibling_frame.errors[0].code, "unexpected-token-after-frameset")
  guard sibling_frame.errors[0].column is Some(43) else {
    fail("expected post-frameset frame error at close bracket")
  }
  let nested_reprocessed = @html_parser.parse(
    "<!doctype html><frameset></frameset><div><frameset></frameset></div>",
    collect_errors=true,
  )
  assert_eq(
    nested_reprocessed.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset><frameset></frameset></html>",
  )
  assert_eq(nested_reprocessed.errors.length(), 4)
  assert_eq(
    nested_reprocessed.errors[0].code,
    "unexpected-token-after-frameset",
  )
  assert_eq(nested_reprocessed.errors[1].code, "unexpected-token-in-frameset")
  assert_eq(
    nested_reprocessed.errors[2].code,
    "unexpected-token-after-frameset",
  )
  assert_eq(nested_reprocessed.errors[3].code, "unexpected-token-in-frameset")
  let detached_end = @html_parser.parse(
    "<!doctype html><frameset></frameset><div></frameset>",
    collect_errors=true,
  )
  assert_eq(
    detached_end.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(detached_end.errors.length(), 3)
  assert_eq(detached_end.errors[0].code, "unexpected-token-after-frameset")
  assert_eq(detached_end.errors[1].code, "unexpected-token-in-frameset")
  assert_eq(detached_end.errors[2].code, "unexpected-end-tag")
  guard detached_end.errors[2].column is Some(52) else {
    fail("expected detached frameset end error at close bracket")
  }
  let detached_html = @html_parser.parse(
    "<!doctype html><frameset></frameset><div><html id=x><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    detached_html.to_html(pretty=false),
    "<!DOCTYPE html><html id=\"x\"><head></head><frameset></frameset></html>",
  )
  assert_eq(detached_html.errors.length(), 5)
  assert_eq(detached_html.errors[0].code, "unexpected-token-after-frameset")
  assert_eq(detached_html.errors[1].code, "unexpected-token-in-frameset")
  assert_eq(detached_html.errors[2].code, "unexpected-start-tag")
  assert_eq(detached_html.errors[3].code, "unexpected-start-tag-ignored")
  assert_eq(detached_html.errors[4].code, "unexpected-end-tag")
  let repeated_html = @html_parser.parse(
    "<!doctype html><frameset></frameset><html id=x><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    repeated_html.to_html(pretty=false),
    "<!DOCTYPE html><html id=\"x\"><head></head><frameset></frameset></html>",
  )
  assert_eq(repeated_html.errors.length(), 3)
  assert_eq(repeated_html.errors[0].code, "unexpected-start-tag")
  assert_eq(repeated_html.errors[1].code, "unexpected-start-tag-ignored")
  assert_eq(repeated_html.errors[2].code, "unexpected-end-tag")
}
