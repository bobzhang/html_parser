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
