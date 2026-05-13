///|
test "golden serializer corpus keeps mixed content output stable" {
  let doc = @html_parser.parse_fragment(
    "<section><p>A <em>B</em></p><pre>x\n  y</pre><img src=x><script>if (a < b) { c(); }</script></section>",
    sanitize=false,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<section><p>A <em>B</em></p><pre>x\n  y</pre><img src=\"x\"><script>if (a < b) { c(); }</script></section>",
  )
  assert_eq(
    doc.to_html(pretty=true, indent_size=2),
    "<section>\n  <p>A <em>B</em></p>\n  <pre>x\n  y</pre>\n  <img src=\"x\">\n  <script>if (a < b) { c(); }</script>\n</section>",
  )
}

///|
test "golden markdown corpus keeps block and inline output stable" {
  let doc = @html_parser.parse_fragment(
    "<article><h2>Title</h2><p>A <strong>bold</strong> &amp; <code>x`y</code></p><blockquote><p>Q</p><p>R</p></blockquote><ul><li>One</li><li>Two <a href=\"/x\">X</a></li></ul></article>",
    sanitize=false,
  )
  assert_eq(
    doc.to_markdown(),
    "## Title\n\nA **bold** &amp; ``x`y``\n\n> Q\n> \n> R\n\n- One\n- Two [X](/x)",
  )
  assert_eq(
    doc.to_markdown(html_passthrough=true),
    "## Title\n\nA **bold** &amp; ``x`y``\n\n> Q\n> \n> R\n\n- One\n- Two [X](/x)",
  )
}

///|
test "golden CLI corpus keeps end-user output modes stable" {
  let html = b"<article><h2>Title</h2><p>A <strong>bold</strong> &amp; <code>x`y</code></p></article>"
  let common_args = [
    "-", "--fragment", "--selector", "article", "--allow-tags", "article,h2,p,strong,code",
  ]

  let markdown = @html_parser.run_cli_bytes(
    common_args + ["--format", "markdown"],
    html,
  )
  assert_eq(markdown.exit_code, 0)
  assert_eq(markdown.stdout, "## Title\n\nA **bold** &amp; ``x`y``\n")
  assert_eq(markdown.stderr, "")

  let text = @html_parser.run_cli_bytes(
    common_args + ["--format", "text", "--separator", "|"],
    html,
  )
  assert_eq(text.exit_code, 0)
  assert_eq(text.stdout, "Title|A|bold|&|x`y\n")
  assert_eq(text.stderr, "")

  let serialized = @html_parser.run_cli_bytes(
    common_args + ["--format", "html"],
    html,
  )
  assert_eq(serialized.exit_code, 0)
  assert_eq(
    serialized.stdout,
    "<article>\n  <h2>Title</h2>\n  <p>A <strong>bold</strong> &amp; <code>x`y</code></p>\n</article>\n",
  )
  assert_eq(serialized.stderr, "")
}
