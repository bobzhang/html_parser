///|
/// Describes how the CLI should obtain input after argument parsing.
///
/// `CliImmediate` means parsing already produced a complete result, such as
/// help, version output, or an argument error. `CliReadPath` asks the caller to
/// read the given path, where `"-"` conventionally means standard input.
pub(all) enum CliReadPlan {
  CliImmediate(CliResult)
  CliReadPath(String)
} derive(Debug, Eq)

///|
/// Result produced by the embeddable CLI runner.
///
/// `stdout` and `stderr` contain terminal output. When `file_output_path` is
/// present, `file_output_content` contains the bytes that a shell wrapper should
/// write to that path instead of printing to standard output.
pub(all) struct CliResult {
  exit_code : Int
  stdout : String
  stderr : String
  file_output_path : String?
  file_output_content : String?
} derive(Debug, Eq)

///|
priv enum CliFormat {
  CliHtml
  CliText
  CliMarkdown
}

///|
priv struct CliOptions {
  mut path : String?
  mut output_path : String?
  mut selector : String?
  mut format : CliFormat
  mut unsafe_mode : Bool
  mut allow_tags : String?
  mut cleanup : Bool
  mut first : Bool
  mut fragment : Bool
  mut strict : Bool
  mut separator : String
  mut separator_blocks_only : Bool
  mut strip : Bool
  mut strip_seen : Bool
}

///|
priv enum CliParseResult {
  CliParsed(CliOptions)
  CliParseExit(CliResult)
}

///|
/// Return the CLI usage text.
pub fn cli_help() -> String {
  let text =
    #|usage: justhtml [OPTIONS] <path|->
    #|
    #|Parse HTML5 and output text, pretty-printed HTML, or Markdown.
    #|
    #|Options:
    #|  --output FILE                 File to write output to
    #|  --selector CSS                CSS selector for choosing nodes
    #|  --format html|text|markdown   Output format (default: html)
    #|  --unsafe                      Disable sanitization
    #|  --allow-tags TAGS             Safe mode: comma-separated tags to allow
    #|  --cleanup                     Remove common useless output
    #|  --first                       Only output the first matching node
    #|  --fragment                    Parse input as an HTML fragment
    #|  --strict                      Exit with code 2 on parse errors
    #|  --separator TEXT              Text join separator (default: space)
    #|  --separator-blocks-only       Only apply separator between block elements
    #|  --strip                       Strip text nodes (default)
    #|  --no-strip                    Preserve text node whitespace
    #|  --version                     Print version and exit
    #|  -h, --help                    Print this help and exit
    #|
  text
}

///|
fn cli_success(
  stdout? : String = "",
  file_output_path? : String,
  file_output_content? : String,
) -> CliResult {
  { exit_code: 0, stdout, stderr: "", file_output_path, file_output_content }
}

///|
fn cli_exit(
  code : Int,
  stdout? : String = "",
  stderr? : String = "",
) -> CliResult {
  {
    exit_code: code,
    stdout,
    stderr,
    file_output_path: None,
    file_output_content: None,
  }
}

///|
fn cli_arg_error(message : String) -> CliResult {
  cli_exit(2, stderr="error: \{message}\n\n\{cli_help()}")
}

///|
fn cli_parse_error(message : String) -> CliResult {
  cli_exit(2, stderr="\{message}\n")
}

///|
fn cli_default_options() -> CliOptions {
  {
    path: None,
    output_path: None,
    selector: None,
    format: CliHtml,
    unsafe_mode: false,
    allow_tags: None,
    cleanup: false,
    first: false,
    fragment: false,
    strict: false,
    separator: " ",
    separator_blocks_only: false,
    strip: true,
    strip_seen: false,
  }
}

///|
fn cli_version() -> String {
  "0.1.6"
}
