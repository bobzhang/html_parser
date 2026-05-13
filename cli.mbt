///|
/// Return the CLI usage text.
pub fn cli_help() -> String {
  @cl.cli_help()
}

///|
/// Parse CLI arguments and report whether the caller must read an input path.
pub fn cli_read_plan(args : ArrayView[String]) -> CliReadPlan {
  @cl.cli_read_plan(args)
}

///|
/// Run the embeddable CLI with already-read input bytes.
pub fn run_cli_bytes(args : ArrayView[String], input : BytesView) -> CliResult {
  @cl.run_cli_bytes(args, input)
}

///|
/// Run the embeddable CLI with a path reader callback.
pub fn run_cli_with_reader(
  args : ArrayView[String],
  read_input : (String) -> Bytes,
) -> CliResult {
  @cl.run_cli_with_reader(args, read_input)
}
