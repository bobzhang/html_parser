///|
fn main {
  let all_args = @env.args()
  let args = if all_args.is_empty() { all_args[:] } else { all_args[1:] }
  let result = @html_parser_examples.run_htmlfmt(args) catch {
    error => { exit_code: 1, stdout: "", stderr: error.to_string() }
  }
  if result.stderr != "" {
    println(result.stderr)
  } else {
    println(result.stdout)
  }
}
