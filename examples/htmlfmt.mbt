///|
/// Result returned by the example `htmlfmt` command runner.
///
/// `exit_code` follows command-line conventions: `0` for formatted output and
/// `2` for argument parsing errors. `stdout` carries formatted HTML on success;
/// `stderr` carries parser help or diagnostics when argument parsing fails.
pub(all) struct HtmlFmtResult {
  exit_code : Int
  stdout : String
  stderr : String
} derive(Debug, Eq)

///|
/// Run the example `htmlfmt` command with an argument vector.
///
/// The command accepts one HTML fragment positional argument and an optional
/// `--compact` flag. Successful runs return formatted HTML in `stdout`; parse
/// errors from the command-line parser are converted into a nonzero
/// `HtmlFmtResult` instead of escaping as exceptions.
pub fn run_htmlfmt(args : ArrayView[String]) -> HtmlFmtResult raise {
  let command = htmlfmt_command()
  let matches = command.parse(argv=args, env={}) catch {
    error =>
      return {
        exit_code: 2,
        stdout: "",
        stderr: error.to_string() + "\n\n" + command.render_help(),
      }
  }
  let input = matches.values["html"][0]
  let compact = match matches.flags.get("compact") {
    Some(value) => value
    None => false
  }
  let output = if compact {
    compact_fragment(input)
  } else {
    pretty_fragment(input)
  }
  { exit_code: 0, stdout: output, stderr: "" }
}

///|
fn htmlfmt_command() -> @argparse.Command {
  Command(
    "htmlfmt",
    about="Format an HTML fragment with bobzhang/html_parser.",
    flags=[
      FlagArg(
        "compact",
        long="compact",
        about="Write compact HTML instead of pretty HTML.",
      ),
    ],
    positionals=[
      PositionArg(
        "html",
        num_args=@argparse.ValueRange::single(),
        allow_hyphen_values=true,
        about="HTML fragment to format.",
      ),
    ],
  )
}
