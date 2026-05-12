///|
async fn main {
  let all_args = @env.args()
  let args = if all_args.is_empty() { all_args[:] } else { all_args[1:] }
  match @html_parser.cli_read_plan(args) {
    CliImmediate(result) => emit_cli_result(result)
    CliReadPath(path) => {
      let input = read_cli_input(path) catch {
        _ => {
          @stdio.stderr.write("failed to read input: \{path}\n")
          cli_exit_process(2)
          b""
        }
      }
      emit_cli_result(@html_parser.run_cli_bytes(args, input))
    }
  }
}

///|
async fn read_cli_input(path : String) -> Bytes {
  if path == "-" {
    @stdio.stdin.read_all().binary()
  } else {
    @fs.read_file(path).binary()
  }
}

///|
async fn emit_cli_result(result : @html_parser.CliResult) -> Unit {
  match (result.file_output_path, result.file_output_content) {
    (Some(path), Some(content)) =>
      @fs.write_file(
        path,
        content,
        create_mode=CreateOrTruncate,
        permission=0o644,
      ) catch {
        _ => {
          @stdio.stderr.write("failed to write output: \{path}\n")
          cli_exit_process(2)
        }
      }
    _ => ()
  }
  if !result.stdout.is_empty() {
    @stdio.stdout.write(result.stdout)
  }
  if !result.stderr.is_empty() {
    @stdio.stderr.write(result.stderr)
  }
  if result.exit_code != 0 {
    cli_exit_process(result.exit_code)
  }
}

///|
extern "C" fn cli_exit_process(code : Int) = "exit"
