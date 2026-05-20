///|
#coverage.skip
async fn main {
  let all_args = @env.args()
  let args = if all_args.is_empty() { all_args[:] } else { all_args[1:] }
  let result = run_native_cli(args)
  emit_cli_result(result)
}

///|
#coverage.skip
async fn run_native_cli(args : ArrayView[String]) -> @html_parser.CliResult {
  match @html_parser.cli_read_plan(args) {
    CliImmediate(result) => result
    CliReadPath(path) => {
      let input = read_cli_input(path) catch {
        error => return cli_read_failure(error.to_string())
      }
      @html_parser.run_cli_bytes(args, input)
    }
  }
}

///|
#coverage.skip
fn cli_read_failure(message : String) -> @html_parser.CliResult {
  cli_immediate(2, stderr="failed to read input: \{message}\n")
}

///|
#coverage.skip
fn cli_immediate(
  code : Int,
  stdout? : String = "",
  stderr? : String = "",
) -> @html_parser.CliResult {
  {
    exit_code: code,
    stdout,
    stderr,
    file_output_path: None,
    file_output_content: None,
  }
}

///|
#coverage.skip
async fn read_cli_input(path : String) -> Bytes {
  if path == "-" {
    @stdio.stdin.read_all().binary()
  } else {
    @fs.read_file(path).binary()
  }
}

///|
#coverage.skip
async fn emit_cli_result(result : @html_parser.CliResult) -> Unit {
  match (result.file_output_path, result.file_output_content) {
    (Some(path), Some(content)) =>
      @fs.write_file(path, content, create_mode=CreateOrTruncate)
    _ => ()
  }
  if !result.stdout.is_empty() {
    @stdio.stdout.write(result.stdout)
  }
  if !result.stderr.is_empty() {
    @stdio.stderr.write(result.stderr)
  }
  if result.exit_code != 0 {
    exit_process(result.exit_code)
  }
}

///|
#coverage.skip
extern "C" fn exit_process(code : Int) = "exit"
