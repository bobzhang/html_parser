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
  "0.1.2"
}

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

///|
fn cli_extra_allowed_tags(value : String) -> Array[String] {
  let normalized = value.replace_all(old=" ", new=",")
  let tags : Array[String] = []
  for part in normalized.split(",") {
    let tag = @syn.lower_ascii(part.trim())
    if !tag.is_empty() {
      tags.push(tag)
    }
  }
  tags
}

///|
fn cli_policy_for_options(options : CliOptions) -> @san.SanitizationPolicy? {
  match options.allow_tags {
    None => None
    Some(raw) => {
      let base = if options.fragment {
        @san.default_sanitization_policy()
      } else {
        @san.default_document_sanitization_policy()
      }
      Some(base.with_extra_allowed_tags(cli_extra_allowed_tags(raw)))
    }
  }
}

///|
fn cli_sanitize(
  root : @dom.Node,
  policy : @san.SanitizationPolicy?,
) -> Unit raise @core.HtmlError {
  match policy {
    Some(policy) => ignore(@san.sanitize_dom(root, policy~))
    None => ignore(@san.sanitize_dom(root))
  }
}

///|
fn cli_sanitize_transform(
  policy : @san.SanitizationPolicy?,
) -> @tr.TransformSpec {
  match policy {
    Some(policy) => @tr.TransformSpec::sanitize(policy~)
    None => @tr.TransformSpec::sanitize()
  }
}

///|
fn cli_cleanup_transforms(
  safe : Bool,
  policy : @san.SanitizationPolicy?,
) -> Array[@tr.TransformSpec] {
  let transforms : Array[@tr.TransformSpec] = []
  if safe {
    transforms.push(cli_sanitize_transform(policy))
  }
  transforms.push(@tr.TransformSpec::unwrap("a:not([href])"))
  transforms.push(@tr.TransformSpec::drop("img:not([src]), img[src=\"\"]"))
  transforms.push(@tr.TransformSpec::prune_empty("*"))
  transforms
}

///|
fn cli_parse_document(
  input : BytesView,
  options : CliOptions,
) -> @p.ParsedHtml raise @core.HtmlError {
  if options.fragment {
    let (decoded, _) = @enc.decode_html_bytes(input, None)
    @p.parse_fragment(
      decoded,
      context=@p.FragmentContext::new("div"),
      sanitize=false,
      strict=options.strict,
    )
  } else {
    @p.parse_bytes(input, sanitize=false, strict=options.strict)
  }
}

///|
fn cli_apply_cleanup_or_error(
  root : @dom.Node,
  safe : Bool,
  policy : @san.SanitizationPolicy?,
) -> CliResult? {
  ignore(@tr.apply_transforms(root, cli_cleanup_transforms(safe, policy))) catch {
    error => return Some(cli_parse_error(cli_html_error_message(error)))
  }
  None
}

///|
fn cli_sanitize_or_error(
  root : @dom.Node,
  policy : @san.SanitizationPolicy?,
) -> CliResult? {
  cli_sanitize(root, policy) catch {
    error => return Some(cli_parse_error(cli_html_error_message(error)))
  }
  None
}

///|
fn cli_run_parsed(
  root : @dom.Node,
  options : CliOptions,
  safe : Bool,
  policy : @san.SanitizationPolicy?,
) -> CliResult {
  if options.cleanup {
    match cli_apply_cleanup_or_error(root, safe, policy) {
      Some(result) => return result
      None => ()
    }
  } else if safe {
    match cli_sanitize_or_error(root, policy) {
      Some(result) => return result
      None => ()
    }
  }
  let nodes = match cli_selected_nodes(root, options) {
    Some(nodes) => nodes
    None => return cli_parse_error("Invalid selector")
  }
  if nodes.is_empty() {
    return cli_exit(1)
  }
  let content = cli_render_nodes(nodes, options) catch {
    error => return cli_parse_error(cli_html_error_message(error))
  }
  cli_output_result(content, options)
}

///|
fn cli_selector_is_valid(selector : StringView) -> Bool {
  @sel.is_valid(selector)
}

///|
fn cli_selected_nodes(
  root : @dom.Node,
  options : CliOptions,
) -> Array[@dom.Node]? {
  let nodes = match options.selector {
    Some(selector) => {
      if !cli_selector_is_valid(selector) {
        return None
      }
      @sel.query(root, selector)
    }
    None => [root]
  }
  if nodes.is_empty() {
    Some([])
  } else if options.first {
    Some([nodes[0]])
  } else {
    Some(nodes)
  }
}

///|
fn cli_html_error_message(error : @core.HtmlError) -> String {
  match error {
    StrictMode(parse_error) =>
      "Strict mode error: \{parse_error.code}: \{parse_error.message}"
    InvalidSerialization(message) => message
    UnsafeHtml(message) => message
    SelectorError(message) => message
  }
}

///|
fn cli_render_node(
  node : @dom.Node,
  options : CliOptions,
) -> String raise @core.HtmlError {
  match options.format {
    CliHtml => @ser.to_html(node)
    CliText =>
      @ser.to_text(
        node,
        separator=options.separator,
        strip=options.strip,
        separator_blocks_only=options.separator_blocks_only,
      )
    CliMarkdown => @md.to_markdown(node)
  }
}

///|
fn cli_render_nodes(
  nodes : Array[@dom.Node],
  options : CliOptions,
) -> String raise @core.HtmlError {
  let rendered : Array[String] = []
  for node in nodes {
    rendered.push(cli_render_node(node, options))
  }
  let separator = match options.format {
    CliMarkdown => "\n\n"
    _ => "\n"
  }
  "\{rendered.join(separator)}\n"
}

///|
fn cli_output_result(content : String, options : CliOptions) -> CliResult {
  match options.output_path {
    Some(path) =>
      cli_success(file_output_path=path, file_output_content=content)
    None => cli_success(stdout=content)
  }
}

///|
/// Run the JustHTML-compatible CLI over already-read input bytes.
///
/// `args` should contain only command-line arguments after the executable name.
/// The returned `CliResult` captures exit status, terminal output, and optional
/// output-file content for the caller to write.
pub fn run_cli_bytes(args : ArrayView[String], input : BytesView) -> CliResult {
  let options = match cli_parse_args(args) {
    CliParseExit(result) => return result
    CliParsed(options) => options
  }
  let safe = !options.unsafe_mode
  let policy = if safe { cli_policy_for_options(options) } else { None }
  let parsed = cli_parse_document(input, options) catch {
    error => return cli_parse_error(cli_html_error_message(error))
  }
  cli_run_parsed(parsed.root, options, safe, policy)
}

///|
/// Run the CLI with caller-provided path reading.
///
/// The callback receives the input path selected by argument parsing. This is
/// useful for native or embedded hosts that want the library to handle CLI
/// options while the host owns filesystem or standard-input IO.
pub fn run_cli_with_reader(
  args : ArrayView[String],
  read_input : (String) -> Bytes,
) -> CliResult {
  match cli_read_plan(args) {
    CliImmediate(result) => result
    CliReadPath(path) => {
      let input = read_input(path)
      run_cli_bytes(args, input)
    }
  }
}
