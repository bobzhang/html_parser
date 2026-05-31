// Coverage tests for the root-level streaming re-exports. The full
// snapshot suite lives in `stream/` — see `stream/README.mbt.md`.

///|
test "root stream re-exports forward to @stream" {
  let from_string = @html_parser.stream("<p>hi</p>")
  let from_bytes = @html_parser.stream_bytes(b"<p>hi</p>")
  let from_bytes_explicit = @html_parser.stream_bytes(
    b"<p>hi</p>",
    encoding="utf-8",
  )
  // Same event sequence regardless of entry point.
  assert_eq(from_string.length(), 3)
  assert_eq(from_bytes.length(), 3)
  assert_eq(from_bytes_explicit.length(), 3)
}

///|
test "root stream_bytes_each re-export covers both encoding branches" {
  let default_count = Ref(0)
  @html_parser.stream_bytes_each(b"<p>x</p>", _ => {
    default_count.val = default_count.val + 1
  })
  let explicit_count = Ref(0)
  @html_parser.stream_bytes_each(
    b"<p>x</p>",
    _ => explicit_count.val = explicit_count.val + 1,
    encoding="utf-8",
  )
  assert_eq(default_count.val, 3)
  assert_eq(explicit_count.val, 3)
}
