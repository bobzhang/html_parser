///|
fn cli_command() -> @argparse.Command {
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
      cli_option("format"),
      cli_option("output"),
      cli_option("selector"),
      cli_option("allow-tags"),
      cli_option("separator"),
    ],
    positionals=[PositionArg("path", num_args=ValueRange(lower=0, upper=1))],
    disable_help_flag=true,
    disable_version_flag=true,
    disable_help_subcommand=true,
  )
}

///|
fn cli_option(name : String) -> @argparse.OptionArg {
  OptionArg(name, action=Append, allow_hyphen_values=true)
}

///|
fn cli_matches_flag(matches : @argparse.Matches, name : String) -> Bool {
  match matches.flags.get(name) {
    Some(value) => value
    None => false
  }
}

///|
fn cli_first_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) => if values.length() == 0 { None } else { Some(values[0]) }
    None => None
  }
}

///|
fn cli_last_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) => Some(values[values.length() - 1])
    None => None
  }
}

///|
fn cli_first_line(message : String) -> String {
  let lines = [ for line in message.split("\n") => line ]
  lines[0].to_owned()
}

///|
fn cli_argparse_error(message : String) -> CliResult {
  cli_exit(2, stderr="\{cli_first_line(message)}\n\n\{cli_help()}")
}

///|
fn cli_parse_format(value : String) -> CliFormat? {
  match value {
    "html" => Some(CliHtml)
    "text" => Some(CliText)
    "markdown" => Some(CliMarkdown)
    _ => None
  }
}

///|
fn cli_strip_conflict_message(args : ArrayView[String]) -> String {
  for arg in args {
    match arg {
      "--strip" => return "--no-strip conflicts with --strip"
      "--no-strip" => return "--strip conflicts with --no-strip"
      _ => ()
    }
  }
  "--strip conflicts with --no-strip"
}

///|
fn cli_parse_args(args : ArrayView[String]) -> CliParseResult {
  if args.length() == 0 {
    return CliParseExit(cli_exit(1, stderr=cli_help()))
  }
  let command = cli_command()
  let matches = command.parse(argv=args, env={}) catch {
    error => return CliParseExit(cli_argparse_error(error.to_string()))
  }
  if cli_matches_flag(matches, "help") {
    return CliParseExit(cli_exit(0, stdout=cli_help()))
  }
  if cli_matches_flag(matches, "version") {
    return CliParseExit(cli_exit(0, stdout="justhtml \{cli_version()}\n"))
  }

  let options = cli_default_options()
  match cli_last_value(matches, "format") {
    Some(value) =>
      match cli_parse_format(value) {
        Some(format) => options.format = format
        None =>
          return CliParseExit(
            cli_arg_error("--format must be one of: html, text, markdown"),
          )
      }
    None => ()
  }
  options.output_path = cli_last_value(matches, "output")
  options.selector = cli_last_value(matches, "selector")
  options.allow_tags = cli_last_value(matches, "allow-tags")
  match cli_last_value(matches, "separator") {
    Some(value) => options.separator = value
    None => ()
  }
  options.unsafe_mode = cli_matches_flag(matches, "unsafe")
  options.cleanup = cli_matches_flag(matches, "cleanup")
  options.first = cli_matches_flag(matches, "first")
  options.fragment = cli_matches_flag(matches, "fragment")
  options.strict = cli_matches_flag(matches, "strict")
  options.separator_blocks_only = cli_matches_flag(
    matches, "separator-blocks-only",
  )

  let strip = cli_matches_flag(matches, "strip")
  let no_strip = cli_matches_flag(matches, "no-strip")
  if strip && no_strip {
    return CliParseExit(cli_arg_error(cli_strip_conflict_message(args)))
  }
  if no_strip {
    options.strip = false
  } else if strip {
    options.strip = true
  }

  match cli_first_value(matches, "path") {
    Some(path) => {
      options.path = Some(path)
      CliParsed(options)
    }
    None => CliParseExit(cli_exit(1, stderr=cli_help()))
  }
}

///|
/// Parse CLI arguments and report whether the caller must read an input path.
///
/// Use this when integrating with an environment that performs its own file or
/// standard-input IO. For direct byte input, use `run_cli_bytes`.
pub fn cli_read_plan(args : ArrayView[String]) -> CliReadPlan {
  match cli_parse_args(args) {
    CliParseExit(result) => CliImmediate(result)
    CliParsed(options) => CliReadPath(options.path.unwrap())
  }
}
