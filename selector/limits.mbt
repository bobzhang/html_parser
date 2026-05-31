///|
/// Resource limits used while parsing and matching CSS selectors.
///
/// Limits are defensive bounds for selector length, nesting, list size, and
/// match cost. Negative match budgets are treated as exhausted.
pub(all) struct SelectorLimits {
  max_match_depth : Int
  max_length : Int
  max_list_items : Int
  max_compound_simple_selectors : Int
  max_complex_selector_parts : Int
  max_parse_depth : Int
  max_match_steps : Int
  max_match_bytes : Int
} derive(Debug, Eq)

///|
/// Construct selector limits, using conservative defaults for omitted values.
pub fn SelectorLimits::SelectorLimits(
  max_match_depth? : Int = 100,
  max_length? : Int = 8192,
  max_list_items? : Int = 256,
  max_compound_simple_selectors? : Int = 512,
  max_complex_selector_parts? : Int = 512,
  max_parse_depth? : Int = 100,
  max_match_steps? : Int = 100000000,
  max_match_bytes? : Int = 100000000,
) -> SelectorLimits {
  {
    max_match_depth,
    max_length,
    max_list_items,
    max_compound_simple_selectors,
    max_complex_selector_parts,
    max_parse_depth,
    max_match_steps,
    max_match_bytes,
  }
}
