///|
pub(all) struct HtmlFmtResult {
  exit_code : Int
  stdout : String
  stderr : String
} derive(Debug, Eq)

///|
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
