///|
/// Check if any character in the view matches the condition, mirroring
/// `ArrayView::any`. A package-local method (foreign types only accept
/// non-pub extensions); the `#locals` annotation keeps the predicate
/// stack-allocated so this performs on par with a hand-written loop.
/// TODO: upstream to moonbitlang/core as `StringView::any`.
#locals(f)
fn StringView::any(self : StringView, f : (Char) -> Bool) -> Bool {
  for ch in self {
    if f(ch) {
      return true
    }
  }
  false
}
