///|
/// Find URL and email-like spans in plain text using the default configuration.
pub fn find_links(text : StringView) -> Array[LinkMatch] {
  find_links_with_config(text, LinkifyConfig::new())
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

///|
fn linkify_left_boundary(text : StringView, pos : Int) -> Bool {
  if pos <= 0 {
    return true
  }
  match text.get_char(pos - 1) {
    Some(ch) => !(linkify_ascii_alnum(ch) || ch == '_')
    None => true
  }
}

///|
fn linkify_candidate_can_start(text : StringView, pos : Int) -> Bool {
  linkify_broad_candidate_start(text, pos) ||
  linkify_fuzzy_start_char(text.get_char(pos).unwrap())
}

///|
fn linkify_broad_candidate_start(text : StringView, pos : Int) -> Bool {
  @syn.starts_with_case_insensitive(text, pos, "http://") ||
  @syn.starts_with_case_insensitive(text, pos, "https://") ||
  @syn.starts_with_case_insensitive(text, pos, "ftp://") ||
  @syn.starts_with_case_insensitive(text, pos, "mailto:") ||
  @syn.starts_with_case_insensitive(text, pos, "www.") ||
  (text.get_char(pos) is Some('/') && text.get_char(pos + 1) is Some('/'))
}

///|
fn linkify_candidate_end(text : StringView, start : Int) -> Int {
  let mut pos = start
  for ch in text[start:text.length()] {
    if linkify_candidate_delimiter(ch) {
      return pos
    }
    pos += ch.utf16_len()
  }
  text.length()
}

///|
fn linkify_fuzzy_candidate_end(text : StringView, start : Int) -> Int {
  let mut pos = start
  for ch in text[start:text.length()] {
    if linkify_candidate_delimiter(ch) ||
      ch == '(' ||
      ch == ')' ||
      ch == '[' ||
      ch == ']' {
      return pos
    }
    pos += ch.utf16_len()
  }
  text.length()
}

///|
fn linkify_candidate_delimiter(ch : Char) -> Bool {
  ch.is_ascii_whitespace() || ch == '<' || ch == '>' || ch == '\u{FF5C}'
}

///|
fn linkify_match_candidate(
  text : StringView,
  start : Int,
  raw_end : Int,
  config : LinkifyConfig,
) -> LinkMatch? {
  let mut end = linkify_trim_trailing_end(text, start, raw_end)
  if end <= start {
    return None
  }
  guard text.get_view(start~, end~) is Some(candidate) else { return None }
  if linkify_is_scheme_url(candidate) {
    match linkify_find_substring(candidate, ")[") {
      Some(offset) =>
        end = linkify_trim_trailing_end(text, start, start + offset)
      None => ()
    }
  }
  guard text.get_view(start~, end~) is Some(candidate) else { return None }
  if !linkify_validate_candidate(candidate, text, start, config) {
    return None
  }
  let match_text = candidate.to_owned()
  let (href, kind) = linkify_href_for(candidate)
  Some({ start, end, text: match_text, href, kind })
}

///|
fn linkify_trim_trailing_end(text : StringView, start : Int, end : Int) -> Int {
  let mut end = end
  while end > start {
    match text.get_char(end - 1) {
      Some(ch) if ch == '.' ||
        ch == ',' ||
        ch == ';' ||
        ch == ':' ||
        ch == '!' ||
        ch == '?' => end -= 1
      _ => break
    }
  }
  while end > start {
    match text.get_char(end - 1) {
      Some('"') if linkify_count_char(text, start, end, '"') % 2 == 1 =>
        end -= 1
      Some('\'') if linkify_count_char(text, start, end, '\'') % 2 == 1 =>
        end -= 1
      _ => break
    }
  }
  while end > start {
    match text.get_char(end - 1) {
      Some(')') if linkify_count_char(text, start, end, ')') >
        linkify_count_char(text, start, end, '(') => end -= 1
      Some(']') if linkify_count_char(text, start, end, ']') >
        linkify_count_char(text, start, end, '[') => end -= 1
      Some('}') if linkify_count_char(text, start, end, '}') >
        linkify_count_char(text, start, end, '{') => end -= 1
      Some('>') if linkify_count_char(text, start, end, '>') >
        linkify_count_char(text, start, end, '<') => end -= 1
      _ => break
    }
  }
  end
}

///|
fn linkify_embedded_scheme_start(
  text : StringView,
  start : Int,
  end : Int,
) -> Int? {
  let mut pos = start
  for ch in text[start:end] {
    let next = pos + ch.utf16_len()
    if next < end &&
      (
        @syn.starts_with_case_insensitive(text, next, "http://") ||
        @syn.starts_with_case_insensitive(text, next, "https://") ||
        @syn.starts_with_case_insensitive(text, next, "ftp://") ||
        @syn.starts_with_case_insensitive(text, next, "mailto:")
      ) {
      return Some(next)
    }
    pos = next
  }
  None
}
