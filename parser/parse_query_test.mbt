// Blackbox snapshot tests for the methods exposed on `ParsedHtml`:
// `query`, `query_one`, `to_text`, and `to_markdown`.

///|
test "parsed query returns all matching nodes" {
  let doc = @parser.parse_fragment(
    "<p class='a'>one</p><p class='a'>two</p><p>three</p>",
  )
  // length() avoids dumping every node's metadata.
  debug_inspect(
    doc.query("p.a").length(),
    content=(
      #|2
    ),
  )
}

///|
test "parsed query_one returns the first match or None" {
  let doc = @parser.parse_fragment("<p id='x'>one</p>")
  let hit = doc.query_one("#x")
  let miss = doc.query_one("#nope")
  // Show whether each lookup returned Some/None without dumping the
  // matched Node's internals.
  debug_inspect(
    (hit is Some(_), miss is Some(_)),
    content=(
      #|(true, false)
    ),
  )
}

///|
test "parsed to_text extracts text content" {
  let doc = @parser.parse_fragment("<p>Hello <b>MoonBit</b></p>")
  inspect(
    doc.to_text(separator="", strip=false),
    content=(
      #|Hello MoonBit
    ),
  )
}

///|
test "parsed to_markdown renders headings and inline formatting" {
  let doc = @parser.parse_fragment(
    "<h1>Title</h1><p>Hello <b>bold</b> and <i>italic</i></p>",
  )
  inspect(
    doc.to_markdown(),
    content=(
      #|# Title
      #|
      #|Hello **bold** and *italic*
    ),
  )
}
