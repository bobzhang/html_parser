///|
fn legacy_named_entity_value(name : StringView) -> String? {
  named_entity_value(name, legacy_only=true)
}

///|
fn semicolon_named_entity_value(name : StringView) -> String? {
  named_entity_value(name, legacy_only=false)
}

///|
// Read the packed little-endian offset, including its legacy-name flag.
fn named_entity_offset(index : Int) -> Int {
  let pos = index * 2
  named_entity_offsets[pos].to_int() |
  (named_entity_offsets[pos + 1].to_int() << 8)
}

///|
// Compare UTF-16 input with a NUL-terminated ASCII name without allocating.
fn compare_named_entity(name : StringView, start : Int) -> Int {
  let mut index = 0
  while named_entity_data[start + index] != 0 {
    if index == name.length() {
      return -1
    }
    let order = name[index].to_int() - named_entity_data[start + index].to_int()
    if order != 0 {
      return order
    }
    index += 1
  }
  name.length() - index
}

///|
// Share one small binary search between semicolon and legacy references.
// Common references keep their allocation-free, constant-string fast path.
fn named_entity_value(name : StringView, legacy_only~ : Bool) -> String? {
  match name {
    "amp" | "AMP" => return Some("&")
    "lt" | "LT" => return Some("<")
    "gt" | "GT" => return Some(">")
    "quot" | "QUOT" => return Some("\"")
    "nbsp" => return Some("\u{00A0}")
    "apos" => return if legacy_only { None } else { Some("'") }
    _ => ()
  }
  if name.is_empty() || name.length() > (if legacy_only { 6 } else { 31 }) {
    return None
  }
  let initial = name[0].to_int() - 65
  if initial < 0 || initial >= 58 {
    return None
  }
  let boundary = initial * 2
  let mut low = named_entity_initial_offsets[boundary].to_int() |
    (named_entity_initial_offsets[boundary + 1].to_int() << 8)
  let mut high = named_entity_initial_offsets[boundary + 2].to_int() |
    (named_entity_initial_offsets[boundary + 3].to_int() << 8)
  while low < high {
    let mid = low + (high - low) / 2
    let marked = named_entity_offset(mid)
    let start = marked & 0x7FFF
    let order = compare_named_entity(name, start)
    if order < 0 {
      high = mid
    } else if order > 0 {
      low = mid + 1
    } else {
      if legacy_only && (marked & 0x8000) == 0 {
        return None
      }
      let end = named_entity_offset(mid + 1) & 0x7FFF
      // The complete table contains only valid UTF-8, verified by tests.
      return Some(
        try! @utf8.decode(
          named_entity_data[start + name.length() + 1:end],
          ignore_bom=false,
        ),
      )
    }
  }
  None
}
