///|
fn cli_option_value_from_equals(arg : String, option : String) -> String? {
  let prefix = "\{option}="
  if !arg.has_prefix(prefix) {
    return None
  }
  Some(arg[prefix.length():arg.length()].to_owned())
}

///|
fn cli_read_option_value(
  args : ArrayView[String],
  index : Int,
  option : String,
) -> (String?, Int, CliResult?) {
  let arg = args[index]
  match cli_option_value_from_equals(arg, option) {
    Some(value) => (Some(value), index + 1, None)
    None =>
      if arg == option {
        if index + 1 >= args.length() {
          (None, index + 1, Some(cli_arg_error("\{option} requires a value")))
        } else {
          (Some(args[index + 1]), index + 2, None)
        }
      } else {
        (None, index, None)
      }
  }
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
fn cli_parse_args(args : ArrayView[String]) -> CliParseResult {
  let options = cli_default_options()
  if args.length() == 0 {
    return CliParseExit(cli_exit(1, stderr=cli_help()))
  }
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    if arg == "--help" || arg == "-h" {
      return CliParseExit(cli_exit(0, stdout=cli_help()))
    }
    if arg == "--version" {
      return CliParseExit(cli_exit(0, stdout="justhtml \{cli_version()}\n"))
    }
    let (format_value, next_index, format_error) = cli_read_option_value(
      args, index, "--format",
    )
    if format_error is Some(error) {
      return CliParseExit(error)
    }
    if format_value is Some(value) {
      match cli_parse_format(value) {
        Some(format) => options.format = format
        None =>
          return CliParseExit(
            cli_arg_error("--format must be one of: html, text, markdown"),
          )
      }
      index = next_index
      continue
    }
    let (output_value, next_index, output_error) = cli_read_option_value(
      args, index, "--output",
    )
    if output_error is Some(error) {
      return CliParseExit(error)
    }
    if output_value is Some(value) {
      options.output_path = Some(value)
      index = next_index
      continue
    }
    let (selector_value, next_index, selector_error) = cli_read_option_value(
      args, index, "--selector",
    )
    if selector_error is Some(error) {
      return CliParseExit(error)
    }
    if selector_value is Some(value) {
      options.selector = Some(value)
      index = next_index
      continue
    }
    let (allow_tags_value, next_index, allow_tags_error) = cli_read_option_value(
      args, index, "--allow-tags",
    )
    if allow_tags_error is Some(error) {
      return CliParseExit(error)
    }
    if allow_tags_value is Some(value) {
      options.allow_tags = Some(value)
      index = next_index
      continue
    }
    let (separator_value, next_index, separator_error) = cli_read_option_value(
      args, index, "--separator",
    )
    if separator_error is Some(error) {
      return CliParseExit(error)
    }
    if separator_value is Some(value) {
      options.separator = value
      index = next_index
      continue
    }
    match arg {
      "--unsafe" => options.unsafe_mode = true
      "--cleanup" => options.cleanup = true
      "--first" => options.first = true
      "--fragment" => options.fragment = true
      "--strict" => options.strict = true
      "--separator-blocks-only" => options.separator_blocks_only = true
      "--strip" => {
        if options.strip_seen && !options.strip {
          return CliParseExit(
            cli_arg_error("--strip conflicts with --no-strip"),
          )
        }
        options.strip = true
        options.strip_seen = true
      }
      "--no-strip" => {
        if options.strip_seen && options.strip {
          return CliParseExit(
            cli_arg_error("--no-strip conflicts with --strip"),
          )
        }
        options.strip = false
        options.strip_seen = true
      }
      _ =>
        if arg.has_prefix("-") && arg != "-" {
          return CliParseExit(cli_arg_error("unknown option: \{arg}"))
        } else {
          if options.path is Some(_) {
            return CliParseExit(
              cli_arg_error("only one input path is supported"),
            )
          }
          options.path = Some(arg)
        }
    }
    index += 1
  }
  if options.path is None {
    CliParseExit(cli_exit(1, stderr=cli_help()))
  } else {
    CliParsed(options)
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
