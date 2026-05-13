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
