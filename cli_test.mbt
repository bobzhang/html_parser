///|
fn cli_run(args : Array[String], html : String) -> @html_parser.CliResult {
  @html_parser.run_cli_bytes(args, @utf8.encode(html))
}

///|
test "CLI help version and read plan" {
  let help = @html_parser.run_cli_bytes(["--help"], b"")
  assert_eq(help.exit_code, 0)
  assert_true(help.stdout.contains("usage: justhtml"))
  assert_true(help.stdout.contains("--selector"))
  assert_true(help.stderr.is_empty())
  let no_args = @html_parser.run_cli_bytes([], b"")
  assert_eq(no_args.exit_code, 1)
  assert_true(no_args.stderr.contains("usage: justhtml"))
  let version = @html_parser.run_cli_bytes(["--version"], b"")
  assert_eq(version.exit_code, 0)
  assert_true(version.stdout.has_prefix("justhtml "))
  guard @html_parser.cli_read_plan(["-", "--selector", "p", "--format", "text"])
    is CliReadPath("-") else {
    fail("expected CLI to ask for stdin input")
  }
}

///|
test "CLI renders stdin document and fragment HTML" {
  let doc = cli_run(["-"], "<p>Hello <b>world</b></p>")
  assert_eq(doc.exit_code, 0)
  assert_true(doc.stdout.contains("<p>"))
  assert_true(doc.stdout.contains("Hello"))
  assert_true(doc.stdout.contains("world"))
  assert_eq(doc.stderr, "")
  let fragment = cli_run(["-", "--fragment"], "<li>Hi</li>")
  assert_eq(fragment.exit_code, 0)
  assert_eq(fragment.stdout, "<li>Hi</li>\n")
  let pre = cli_run(
    ["-", "--format", "html"],
    "<pre><code>a</code>-&gt;<code>b</code></pre>",
  )
  assert_eq(pre.exit_code, 0)
  assert_true(pre.stdout.contains("</code>-&gt;<code>"))
}

///|
test "CLI text output selector first and whitespace options" {
  let selected = cli_run(
    ["-", "--selector", "p", "--format", "text"],
    "<article><p>Hi <b>there</b></p><p>Bye</p></article>",
  )
  assert_eq(selected.exit_code, 0)
  assert_eq(selected.stdout, "Hi there\nBye\n")
  let first = cli_run(
    ["-", "--selector", "p", "--format", "text", "--first"],
    "<article><p>Hi <b>there</b></p><p>Bye</p></article>",
  )
  assert_eq(first.stdout, "Hi there\n")
  let separator = cli_run(
    ["-", "--format", "text", "--separator", "|"],
    "<p>Hello <b>world</b></p>",
  )
  assert_eq(separator.stdout, "Hello|world\n")
  let no_strip = cli_run(
    ["-", "--format", "text", "--separator", "|", "--no-strip"],
    "<p>  Hello  <b>world</b>  </p>",
  )
  assert_eq(no_strip.stdout, "  Hello  |world|  \n")
  let no_strip_default_separator = cli_run(
    ["-", "--format", "text", "--no-strip"],
    "<p>Hello<b>world</b></p>",
  )
  assert_eq(no_strip_default_separator.stdout, "Hello world\n")
  let blocks_only = cli_run(
    ["-", "--format", "text", "--separator", "\n", "--separator-blocks-only"],
    "<p>hi</p><p>Hello <b>world</b></p>",
  )
  assert_eq(blocks_only.stdout, "hi\nHello world\n")
}

///|
test "CLI sanitizes by default and unsafe preserves script text" {
  let non_utf8 = @html_parser.run_cli_bytes(
    ["-", "--format", "text"],
    b"<p>Hello</p>\xfc",
  )
  assert_eq(non_utf8.exit_code, 0)
  assert_true(non_utf8.stdout.contains("Hello"))
  let safe = cli_run(
    ["-", "--format", "text"],
    "<p>Hello<script>alert(1)</script>World</p>",
  )
  assert_eq(safe.exit_code, 0)
  assert_eq(safe.stdout, "Hello World\n")
  let unsafe_text = cli_run(
    ["-", "--format", "text", "--unsafe"],
    "<p>Hello<script>alert(1)</script>World</p>",
  )
  assert_eq(unsafe_text.exit_code, 0)
  assert_eq(unsafe_text.stdout, "Hello alert(1) World\n")
}

///|
test "CLI cleanup mirrors safe and unsafe transform order" {
  let html = "<a href=\"javascript:alert(1)\">Link</a><img src=\"\">"
  let safe = cli_run(["-", "--fragment", "--cleanup"], html)
  assert_eq(safe.exit_code, 0)
  assert_eq(safe.stdout, "Link\n")
  let unsafe_cleanup = cli_run(
    ["-", "--fragment", "--cleanup", "--unsafe"],
    html,
  )
  assert_eq(unsafe_cleanup.exit_code, 0)
  assert_eq(unsafe_cleanup.stdout, "<a href=\"javascript:alert(1)\">Link</a>\n")
}

///|
test "CLI markdown allow tags no match and invalid selector" {
  let markdown = cli_run(
    [
      "-", "--selector", "article", "--allow-tags", ",, article,,", "--format", "markdown",
    ],
    "<article><p>Hello <b>world</b></p></article>",
  )
  assert_eq(markdown.exit_code, 0)
  assert_eq(markdown.stdout, "Hello **world**\n")
  let no_match = cli_run(["-", "--selector", ".does-not-exist"], "<p>Hello</p>")
  assert_eq(no_match.exit_code, 1)
  assert_eq(no_match.stdout, "")
  assert_eq(no_match.stderr, "")
  let invalid = cli_run(["-", "--selector", "["], "<p>Hello</p>")
  assert_eq(invalid.exit_code, 2)
  assert_eq(invalid.stdout, "")
  assert_true(invalid.stderr.contains("Invalid selector"))
}

///|
test "CLI markdown safe mode resolves protocol relative links" {
  let safe = cli_run(
    ["-", "--fragment", "--format", "markdown"],
    "<p><a href='//example.com/path'>Example</a></p>",
  )
  assert_eq(safe.exit_code, 0)
  assert_eq(safe.stdout, "[Example](https://example.com/path)\n")
  let unsafe_result = cli_run(
    ["-", "--fragment", "--format", "markdown", "--unsafe"],
    "<p><a href='//example.com/path'>Example</a></p>",
  )
  assert_eq(unsafe_result.exit_code, 0)
  assert_eq(unsafe_result.stdout, "[Example](//example.com/path)\n")
}

///|
test "CLI output files and strict mode are surfaced in pure result" {
  let output = cli_run(
    ["-", "--format", "text", "--output", "out.txt"],
    "<p>Hello</p>",
  )
  assert_eq(output.exit_code, 0)
  assert_eq(output.stdout, "")
  guard output.file_output_path is Some("out.txt") else {
    fail("expected file output path")
  }
  guard output.file_output_content is Some("Hello\n") else {
    fail("expected file output content")
  }
  let strict = cli_run(["-", "--strict", "--fragment"], "</b>")
  assert_eq(strict.exit_code, 2)
  assert_eq(strict.stdout, "")
  assert_true(strict.stderr.contains("Strict mode error"))
}
