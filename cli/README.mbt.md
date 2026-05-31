# `@cli`

The CLI runner used by the `justhtml` binary in `cmd/justhtml`,
exposed as a library so callers can drive the same logic from inside
their own process — useful for tests and for embedding the CLI in
other tools.

The examples below are `mbt check` blocks and run as part of
`moon test cli`.

## `run_cli_bytes` — direct byte input

The simplest entry point: hand the runner the same argv it would see
on the command line plus the raw bytes for `-` (stdin). Get back a
`CliResult` with exit code, stdout, stderr, and an optional file
output.

```mbt check
///|
test "readme cli run_cli_bytes" {
  let result = @cli.run_cli_bytes(
    ["-", "--format", "text"],
    b"<p>Hello <b>MoonBit</b></p>",
  )
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
```

## `run_cli_with_reader` — pluggable input source

When the path is something other than `-`, the runner calls your
reader callback. This is what real IO drivers (`cmd/justhtml`)
wire up; tests can substitute an in-memory map.

```mbt check
///|
test "readme cli reader callback" {
  let paths : Array[String] = []
  let result = @cli.run_cli_with_reader(["page.html", "--format", "markdown"], path => {
    paths.push(path)
    @utf8.encode("<h1>Title</h1><p>body</p>")
  })
  // The reader saw the requested path, and stdout has rendered Markdown.
  debug_inspect(
    (paths, result.stdout),
    content=(
      #|(["page.html"], "# Title\n\nbody\n")
    ),
  )
}
```

## `cli_read_plan` — what would the CLI do?

Decide-before-doing variant: parse argv and return either an immediate
result (help text, usage error) or the path the runner would read
next. Useful when you want to short-circuit IO based on the plan.

```mbt check
///|
test "readme cli read plan" {
  // Stdin: ready to read.
  debug_inspect(
    @cli.cli_read_plan(["-"]),
    content=(
      #|CliReadPath("-")
    ),
  )
}
```

## `cli_help` — the help text the CLI emits

The same string `--help` would print to stdout — useful for diff
tests that want to detect inadvertent CLI changes.
