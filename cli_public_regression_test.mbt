///|
fn cli_public_optional(value : String?) -> String {
  match value {
    Some(text) => text
    None => ""
  }
}

///|
test "public CLI read plan and reader output workflow stays stable" {
  let args : ReadOnlyArray[String] = [
    "-", "--fragment", "--selector", "article", "--allow-tags", "article,h2,p,b",
    "--format", "markdown", "--output", "out.md",
  ]
  guard @html_parser.cli_read_plan(args) is CliReadPath("-") else {
    fail("expected CLI to request stdin")
  }

  let no_path = @html_parser.cli_read_plan(["--format=text"])
  guard no_path is CliImmediate(no_path_result) else {
    fail("expected missing path to be immediate")
  }
  assert_eq(no_path_result.exit_code, 1)
  assert_eq(no_path_result.stdout, "")
  assert_true(no_path_result.stderr.has_prefix("usage: justhtml"))

  let read_paths : Array[String] = []
  let result = @html_parser.run_cli_with_reader(args, fn(path) {
    read_paths.push(path)
    b"<article><h2>T</h2><p>A <b>B</b></p></article>"
  })
  @test.assert_eq(read_paths, ["-"])
  assert_eq(result.exit_code, 0)
  assert_eq(result.stdout, "")
  assert_eq(result.stderr, "")
  assert_eq(cli_public_optional(result.file_output_path), "out.md")
  assert_eq(
    cli_public_optional(result.file_output_content),
    "## T\n\nA **B**\n",
  )
}

///|
test "public CLI cleanup security modes stay stable" {
  let html = b"<a href=\"javascript:alert(1)\">Link</a><img src=\"\"><p onclick=x>ok</p>"
  let safe = @html_parser.run_cli_bytes(["-", "--fragment", "--cleanup"], html)
  assert_eq(safe.exit_code, 0)
  assert_eq(safe.stdout, "Link\n<p>ok</p>\n")
  assert_eq(safe.stderr, "")

  let unsafe_result = @html_parser.run_cli_bytes(
    ["-", "--fragment", "--cleanup", "--unsafe"],
    html,
  )
  assert_eq(unsafe_result.exit_code, 0)
  assert_eq(
    unsafe_result.stdout,
    "<a href=\"javascript:alert(1)\">Link</a>\n<p onclick=\"x\">ok</p>\n",
  )
  assert_eq(unsafe_result.stderr, "")
}

///|
test "public CLI strict and argument errors stay stable" {
  let strict = @html_parser.run_cli_bytes(
    ["-", "--strict", "--fragment"],
    b"</b>",
  )
  assert_eq(strict.exit_code, 2)
  assert_eq(strict.stdout, "")
  assert_eq(
    strict.stderr,
    "Strict mode error: adoption-agency-1.3: adoption-agency-1.3\n",
  )

  let bad_format = @html_parser.run_cli_bytes(["-", "--format", "xml"], b"")
  assert_eq(bad_format.exit_code, 2)
  assert_eq(bad_format.stdout, "")
  assert_true(
    bad_format.stderr.has_prefix(
      "error: --format must be one of: html, text, markdown\n\nusage: justhtml",
    ),
  )
  assert_true(bad_format.stderr.contains("--selector CSS"))
}

///|
test "public CLI immediate help and version plans stay stable" {
  guard @html_parser.cli_read_plan(["--help"]) is CliImmediate(help_plan) else {
    fail("expected help to be immediate")
  }
  assert_eq(help_plan.exit_code, 0)
  assert_true(help_plan.stdout.has_prefix("usage: justhtml"))
  assert_true(help_plan.stdout.contains("--version"))
  assert_eq(help_plan.stderr, "")

  let read_paths : Array[String] = []
  let version = @html_parser.run_cli_with_reader(["--version"], fn(path) {
    read_paths.push(path)
    b"unused"
  })
  assert_eq(read_paths.length(), 0)
  assert_eq(version.exit_code, 0)
  assert_eq(version.stdout, "justhtml 0.1.4\n")
  assert_eq(version.stderr, "")
}

///|
test "public CLI selector no-match and first-match output stay stable" {
  let selected = @html_parser.run_cli_bytes(
    ["-", "--fragment", "--selector", "p", "--first", "--format", "text"],
    b"<article><p>One <b>two</b></p><p>Three</p></article>",
  )
  assert_eq(selected.exit_code, 0)
  assert_eq(selected.stdout, "One two\n")
  assert_eq(selected.stderr, "")

  let no_match = @html_parser.run_cli_bytes(
    ["-", "--fragment", "--selector", ".missing"],
    b"<p>One</p>",
  )
  assert_eq(no_match.exit_code, 1)
  assert_eq(no_match.stdout, "")
  assert_eq(no_match.stderr, "")
}

///|
test "public CLI text whitespace options stay stable" {
  let separator = @html_parser.run_cli_bytes(
    ["-", "--fragment", "--format", "text", "--separator", "|"],
    b"<p>Hello <b>world</b></p><p>Again</p>",
  )
  assert_eq(separator.exit_code, 0)
  assert_eq(separator.stdout, "Hello|world|Again\n")

  let no_strip = @html_parser.run_cli_bytes(
    ["-", "--fragment", "--format", "text", "--separator", "|", "--no-strip"],
    b"<p>  Hello  <b>world</b>  </p>",
  )
  assert_eq(no_strip.exit_code, 0)
  assert_eq(no_strip.stdout, "  Hello  |world|  \n")

  let blocks_only = @html_parser.run_cli_bytes(
    [
      "-", "--fragment", "--format", "text", "--separator", "\n", "--separator-blocks-only",
    ],
    b"<p>hi</p><p>Hello <b>world</b></p>",
  )
  assert_eq(blocks_only.exit_code, 0)
  assert_eq(blocks_only.stdout, "hi\nHello world\n")
}
