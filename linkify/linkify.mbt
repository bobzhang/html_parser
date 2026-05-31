///|
/// Find URL and email-like spans in plain text using the default configuration.
pub fn find_links(text : StringView) -> Array[LinkMatch] {
  find_links_with_config(text, LinkifyConfig())
}

///|
/// Find URL and email-like spans in plain text using an explicit configuration.
pub fn find_links_with_config(
  text : StringView,
  config : LinkifyConfig,
) -> Array[LinkMatch] {
  let out : Array[LinkMatch] = []
  let mut pos = 0
  let mut last_end = -1
  while pos < text.length() {
    if linkify_left_boundary(text, pos) &&
      linkify_candidate_can_start(text, pos) {
      let raw_end = if linkify_broad_candidate_start(text, pos) {
        linkify_candidate_end(text, pos)
      } else {
        linkify_fuzzy_candidate_end(text, pos)
      }
      match linkify_match_candidate(text, pos, raw_end, config) {
        Some(link) => {
          if link.start >= last_end {
            out.push(link)
            last_end = link.end
          }
          pos = raw_end
          continue
        }
        None =>
          match linkify_embedded_scheme_start(text, pos, raw_end) {
            Some(next) => {
              pos = next
              continue
            }
            None =>
              if raw_end > pos {
                pos = raw_end
                continue
              }
          }
      }
    }
    pos += text.get_char(pos).unwrap().utf16_len()
  }
  out
}
