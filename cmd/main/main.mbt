///|
#coverage.skip
fn main {
  let all_args = @env.args()
  let args = if all_args.is_empty() { all_args[:] } else { all_args[1:] }
  emit_cli_result(run_native_cli(args))
}

///|
#coverage.skip
fn run_native_cli(args : ArrayView[String]) -> @html_parser.CliResult {
  let command = native_cli_command()
  let _ = command.parse(argv=args, env={}) catch {
    error => return cli_parse_failure(error.to_string())
  }
  @html_parser.run_cli_with_reader(args, read_cli_input)
}

///|
#coverage.skip
fn native_cli_command() -> @argparse.Command {
  Command(
    "justhtml",
    flags=[
      FlagArg("help", short='h', long="help"),
      FlagArg("version", long="version"),
      FlagArg("unsafe", long="unsafe"),
      FlagArg("cleanup", long="cleanup"),
      FlagArg("first", long="first"),
      FlagArg("fragment", long="fragment"),
      FlagArg("strict", long="strict"),
      FlagArg("separator-blocks-only", long="separator-blocks-only"),
      FlagArg("strip", long="strip"),
      FlagArg("no-strip", long="no-strip"),
    ],
    options=[
      native_cli_option("format"),
      native_cli_option("output"),
      native_cli_option("selector"),
      native_cli_option("allow-tags"),
      native_cli_option("separator"),
    ],
    positionals=[PositionArg("path")],
    disable_help_flag=true,
    disable_version_flag=true,
    disable_help_subcommand=true,
  )
}

///|
#coverage.skip
fn native_cli_option(name : String) -> @argparse.OptionArg {
  OptionArg(name, action=Append, allow_hyphen_values=true)
}

///|
#coverage.skip
fn cli_parse_failure(message : String) -> @html_parser.CliResult {
  let first_line = cli_first_line(message)
  cli_immediate(2, stderr="\{first_line}\n\n\{@html_parser.cli_help()}")
}

///|
#coverage.skip
fn cli_first_line(message : String) -> String {
  let lines = [ for line in message.split("\n") => line ]
  if lines.length() == 0 {
    "error: failed to parse arguments"
  } else {
    lines[0].to_owned()
  }
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
fn read_cli_input(path : String) -> Bytes {
  if path == "-" {
    cli_read_stdin()
  } else {
    cli_read_file(@utf8.encode(path))
  }
}

///|
#coverage.skip
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
