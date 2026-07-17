///|
fn cli_run_parsed(
  root : @dom.Node,
  options : CliOptions,
  safe : Bool,
  policy : @san.SanitizationPolicy?,
) -> CliResult {
  if options.cleanup {
    if cli_apply_cleanup_or_error(root, safe, policy) is Some(result) {
      return result
    }
  } else if safe {
    if cli_sanitize_or_error(root, policy) is Some(result) {
      return result
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
