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
