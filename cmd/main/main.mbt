///|
fn main {
  let all_args = @env.args()
  let args = if all_args.is_empty() { all_args[:] } else { all_args[1:] }
  emit_cli_result(@html_parser.run_cli_with_reader(args, read_cli_input))
}

///|
fn read_cli_input(path : String) -> Bytes {
  if path == "-" {
    cli_read_stdin()
  } else {
    cli_read_file(@utf8.encode(path))
  }
}

///|
fn emit_cli_result(result : @html_parser.CliResult) -> Unit {
  match (result.file_output_path, result.file_output_content) {
    (Some(path), Some(content)) =>
      cli_write_file(@utf8.encode(path), @utf8.encode(content))
    _ => ()
  }
  if !result.stdout.is_empty() {
    cli_write_stdout(@utf8.encode(result.stdout))
  }
  if !result.stderr.is_empty() {
    cli_write_stderr(@utf8.encode(result.stderr))
  }
  if result.exit_code != 0 {
    cli_exit_process(result.exit_code)
  }
}

///|
extern "C" fn cli_read_stdin() -> Bytes = "html_parser_cli_read_stdin"

///|
#borrow(path)
extern "C" fn cli_read_file(path : Bytes) -> Bytes = "html_parser_cli_read_file"

///|
#borrow(data)
extern "C" fn cli_write_stdout(data : Bytes) -> Unit = "html_parser_cli_write_stdout"

///|
#borrow(data)
extern "C" fn cli_write_stderr(data : Bytes) -> Unit = "html_parser_cli_write_stderr"

///|
#borrow(path, data)
extern "C" fn cli_write_file(path : Bytes, data : Bytes) -> Unit = "html_parser_cli_write_file"

///|
extern "C" fn cli_exit_process(code : Int) = "html_parser_cli_exit"
