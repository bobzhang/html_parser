// Blackbox snapshot tests for `parse` — full HTML5 document parsing
// with implicit html/head/body scaffolding and recovery.
//
// The DOM tree is shown via `to_html(pretty=true)` rather than
// `debug_inspect` because nodes carry parent back-pointers and
// metadata that would clutter a debug dump.

///|
test "parse scaffolds implicit html, head, and body" {
  let doc = @parser.parse("<p>hi</p>")
  inspect(
    @ser.to_html(doc.root, pretty=true),
    content=(
      #|<html>
      #|  <head></head>
      #|  <body>
      #|    <p>hi</p>
      #|  </body>
      #|</html>
    ),
  )
}

///|
test "parse routes head elements into head, content into body" {
  // <meta>, <title>, <style>, <script> are head metadata; <p> is body
  // content. They get sorted into the right subtree.
  let doc = @parser.parse(
    "<meta charset=utf-8><title>T</title><style>b{}</style><p>x</p>",
  )
  inspect(
    @ser.to_html(doc.root, pretty=true),
    content=(
      #|<html>
      #|  <head>
      #|    <meta charset="utf-8">
      #|    <title>T</title>
      #|    <style>b{}</style>
      #|  </head>
      #|  <body>
      #|    <p>x</p>
      #|  </body>
      #|</html>
    ),
  )
}

///|
test "parse preserves an explicit doctype" {
  let doc = @parser.parse("<!doctype html><p>hi</p>")
  inspect(
    @ser.to_html(doc.root, pretty=false),
    content=(
      #|<!DOCTYPE html><html><head></head><body><p>hi</p></body></html>
    ),
  )
}

///|
test "parse recovers from an unclosed element" {
  // No </div> in the input; the parser still produces a well-formed tree.
  let doc = @parser.parse("<div><p>unclosed")
  inspect(
    @ser.to_html(doc.root, pretty=true),
    content=(
      #|<html>
      #|  <head></head>
      #|  <body>
      #|    <div>
      #|      <p>unclosed</p>
      #|    </div>
      #|  </body>
      #|</html>
    ),
  )
}

///|
test "parse handles mismatched end tag without dropping content" {
  let doc = @parser.parse("<p>open</span></p>")
  inspect(
    @ser.to_html(doc.root, pretty=false),
    content=(
      #|<html><head></head><body><p>open</p></body></html>
    ),
  )
}

///|
test "parse decodes character references in content" {
  let doc = @parser.parse("<p>Hi &amp; bye</p>")
  inspect(
    @ser.to_html(doc.root, pretty=false),
    content=(
      #|<html><head></head><body><p>Hi &amp; bye</p></body></html>
    ),
  )
}

///|
test "parse exposes the document encoding field" {
  // String input has no encoding to detect; encoding is None.
  let doc = @parser.parse("<p>hi</p>")
  debug_inspect(
    doc.encoding,
    content=(
      #|None
    ),
  )
}
