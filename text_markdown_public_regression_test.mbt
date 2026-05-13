///|
test "public text extraction modes stay stable" {
  let doc = @html_parser.parse_fragment(
    "<article><h1>Title</h1><p>Alpha <strong>Beta</strong><br> Gamma</p><p>  Delta  </p></article>",
    sanitize=false,
  )
  assert_eq(
    doc.to_text(separator="|", strip=true),
    "Title|Alpha|Beta|Gamma|Delta",
  )
  assert_eq(
    doc.to_text(separator="|", strip=true, separator_blocks_only=true),
    "Title|Alpha Beta|Gamma|Delta",
  )
  assert_eq(
    doc.to_text(separator="|", strip=false, separator_blocks_only=true),
    "Title|Alpha Beta| Gamma|  Delta  ",
  )
}

///|
test "public markdown document workflow stays stable" {
  let doc = @html_parser.parse_fragment(
    "<article><h1>Title</h1><p>Hello <strong>MoonBit</strong> &amp; <code>x`y</code></p><blockquote><p>Quote</p><p>More</p></blockquote><ol><li>One</li><li>Two <a href='https://example.com/a b'>link</a></li></ol></article>",
    sanitize=false,
  )
  assert_eq(
    doc.to_markdown(),
    "# Title\n\nHello **MoonBit** &amp; ``x`y``\n\n> Quote\n> \n> More\n\n1. One\n2. Two [link](<https://example.com/a%20b>)",
  )
}

///|
test "public markdown passthrough mode stays stable" {
  let doc = @html_parser.parse_fragment(
    "<p>Before</p><table><tr><td>A</td></tr></table><script data-x='1&2'>if (a < b) alert(1)</script><p>After</p>",
    sanitize=false,
  )
  assert_eq(
    doc.to_markdown(),
    "Before\n\n<table><tbody><tr><td>A</td></tr></tbody></table>\n\nAfter",
  )
  assert_eq(
    doc.to_markdown(html_passthrough=true),
    "Before\n\n<table><tbody><tr><td>A</td></tr></tbody></table>\n\n<script data-x=\"1&amp;2\">if (a < b) alert(1)</script>\n\nAfter",
  )
}
