///|
fn main {
  let all_args = @env.args()
  let args = if all_args.is_empty() { all_args[:] } else { all_args[1:] }
  emit_cli_result(run_native_cli(args))
}

///|
fn run_native_cli(args : ArrayView[String]) -> @html_parser.CliResult {
  let command = native_cli_command()
  let matches = command.parse(argv=args, env={}) catch {
    error => return cli_parse_failure(error.to_string())
  }
  if cli_flag(matches, "help") {
    return cli_immediate(0, stdout=@html_parser.cli_help())
  }
  if cli_flag(matches, "version") {
    return @html_parser.run_cli_with_reader(["--version"], read_cli_input)
  }
  let path = match cli_value(matches, "path") {
    Some(path) => path
    None => return cli_immediate(1, stderr=@html_parser.cli_help())
  }
  if path.has_prefix("-") && path != "-" {
    return cli_arg_error("unknown option: \{path}")
  }
  let normalized = cli_normalized_args(matches, path)
  @html_parser.run_cli_with_reader(normalized[:], read_cli_input)
}

///|
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
fn native_cli_option(name : String) -> @argparse.OptionArg {
  OptionArg(name, action=Append, allow_hyphen_values=true)
}

///|
fn cli_normalized_args(
  matches : @argparse.Matches,
  path : String,
) -> Array[String] {
  let normalized : Array[String] = []
  cli_push_option(normalized, matches, "format", "--format")
  cli_push_option(normalized, matches, "output", "--output")
  cli_push_option(normalized, matches, "selector", "--selector")
  cli_push_option(normalized, matches, "allow-tags", "--allow-tags")
  cli_push_option(normalized, matches, "separator", "--separator")
  cli_push_flag(normalized, matches, "unsafe", "--unsafe")
  cli_push_flag(normalized, matches, "cleanup", "--cleanup")
  cli_push_flag(normalized, matches, "first", "--first")
  cli_push_flag(normalized, matches, "fragment", "--fragment")
  cli_push_flag(normalized, matches, "strict", "--strict")
  cli_push_flag(
    normalized, matches, "separator-blocks-only", "--separator-blocks-only",
  )
  cli_push_flag(normalized, matches, "strip", "--strip")
  cli_push_flag(normalized, matches, "no-strip", "--no-strip")
  normalized.push(path)
  normalized
}

///|
fn cli_push_option(
  normalized : Array[String],
  matches : @argparse.Matches,
  name : String,
  option : String,
) -> Unit {
  match cli_value(matches, name) {
    Some(value) => {
      normalized.push(option)
      normalized.push(value)
    }
    None => ()
  }
}

///|
fn cli_push_flag(
  normalized : Array[String],
  matches : @argparse.Matches,
  name : String,
  flag : String,
) -> Unit {
  if cli_flag(matches, name) {
    normalized.push(flag)
  }
}

///|
fn cli_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) if values.length() > 0 => Some(values[values.length() - 1])
    _ => None
  }
}

///|
fn cli_flag(matches : @argparse.Matches, name : String) -> Bool {
  matches.flags.get(name).unwrap_or(false)
}

///|
fn cli_parse_failure(message : String) -> @html_parser.CliResult {
  let first_line = cli_first_line(message)
  cli_immediate(2, stderr="\{first_line}\n\n\{@html_parser.cli_help()}")
}

///|
fn cli_first_line(message : String) -> String {
  let lines = [ for line in message.split("\n") => line ]
  if lines.length() == 0 {
    "error: failed to parse arguments"
  } else {
    lines[0].to_owned()
  }
}

///|
fn cli_arg_error(message : String) -> @html_parser.CliResult {
  cli_immediate(2, stderr="error: \{message}\n\n\{@html_parser.cli_help()}")
}

///|
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
