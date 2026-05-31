// Blackbox snapshot tests for the embedded CLI runner. `run_cli_*`
// returns a `CliResult` with exit code, stdout, stderr, and optional
// file-output capture — no actual IO happens, which makes these
// suitable for blackbox tests.

///|
test "run_cli_with_reader prints text extracted from HTML input" {
  // The reader callback fakes the file content for path "-".
  let result = @cli.run_cli_with_reader(["-", "--format", "text"], _path => {
    @utf8.encode("<p>Hello <b>MoonBit</b></p>")
  })
  debug_inspect(
    result,
    content=(
      #|{
      #|  exit_code: 0,
      #|  stdout: "Hello MoonBit\n",
      #|  stderr: "",
      #|  file_output_path: None,
      #|  file_output_content: None,
      #|}
    ),
  )
}

///|
test "run_cli_with_reader serializes to compact HTML by default" {
  let result = @cli.run_cli_with_reader(["-"], _path => {
    @utf8.encode("<p class='hi'>x</p>")
  })
  debug_inspect(
    result,
    content=(
      #|{
      #|  exit_code: 0,
      #|  stdout: "<html>\n  <head></head>\n  <body>\n    <p class=\"hi\">x</p>\n  </body>\n</html>\n",
      #|  stderr: "",
      #|  file_output_path: None,
      #|  file_output_content: None,
      #|}
    ),
  )
}

///|
test "run_cli_with_reader emits markdown when --format markdown is set" {
  let result = @cli.run_cli_with_reader(["-", "--format", "markdown"], _path => {
    @utf8.encode("<h1>Title</h1><p>body</p>")
  })
  debug_inspect(
    result,
    content=(
      #|{
      #|  exit_code: 0,
      #|  stdout: "# Title\n\nbody\n",
      #|  stderr: "",
      #|  file_output_path: None,
      #|  file_output_content: None,
      #|}
    ),
  )
}

///|
test "run_cli_bytes accepts raw bytes directly" {
  let result = @cli.run_cli_bytes(
    ["-", "--format", "text"],
    b"<p>plain bytes</p>",
  )
  debug_inspect(
    result,
    content=(
      #|{
      #|  exit_code: 0,
      #|  stdout: "plain bytes\n",
      #|  stderr: "",
      #|  file_output_path: None,
      #|  file_output_content: None,
      #|}
    ),
  )
}

///|
test "cli_read_plan with no path returns immediate help-like failure" {
  // No "-" or path argument means there is nothing to read; the plan
  // is to short-circuit with a CliResult whose stderr contains usage.
  let plan = @cli.cli_read_plan(["--format", "text"])
  match plan {
    CliImmediate(result) =>
      debug_inspect(
        (result.exit_code, result.stderr.contains("usage")),
        content=(
          #|(1, true)
        ),
      )
    CliReadPath(_) => fail("expected immediate plan with no path arg")
  }
}

///|
test "cli_read_plan with - returns a read path of -" {
  let plan = @cli.cli_read_plan(["-"])
  debug_inspect(
    plan,
    content=(
      #|CliReadPath("-")
    ),
  )
}

///|
test "cli_help returns the help text starting with usage" {
  let help = @cli.cli_help()
  // The full text is many lines; snapshot the first line as a String
  // to keep the inline literal small.
  let first_line = match help.split("\n").take(1).collect() {
    [view] => view.to_owned()
    _ => ""
  }
  inspect(
    first_line,
    content=(
      #|usage: justhtml [OPTIONS] <path|->
    ),
  )
}
