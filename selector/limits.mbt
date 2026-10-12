///|
/// Resource limits used while parsing and matching CSS selectors.
///
/// Limits are defensive bounds for selector length, nesting, list size, and
/// match cost. Negative match budgets are treated as exhausted.
pub(all) struct SelectorLimits {
  max_match_depth : Int32
  max_length : Int32
  max_list_items : Int32
  max_compound_simple_selectors : Int32
  max_complex_selector_parts : Int32
  max_parse_depth : Int32
  max_match_steps : Int32
  max_match_bytes : Int32
} derive(Debug, Eq)

///|
/// Construct selector limits, using conservative defaults for omitted values.
pub fn SelectorLimits::SelectorLimits(
  max_match_depth~ : Int32 = 100,
  max_length~ : Int32 = 8192,
  max_list_items~ : Int32 = 256,
  max_compound_simple_selectors~ : Int32 = 512,
  max_complex_selector_parts~ : Int32 = 512,
  max_parse_depth~ : Int32 = 100,
  max_match_steps~ : Int32 = 100000000,
  max_match_bytes~ : Int32 = 100000000,
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
