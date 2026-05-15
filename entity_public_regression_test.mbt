///|
test "entity decoding covers upstream fixture cases" {
  let numeric = @html_parser.parse_fragment("&#65")
  assert_eq(numeric.to_text(separator="", strip=false), "A")
  let control = @html_parser.parse_fragment("&#x80")
  assert_eq(control.to_text(separator="", strip=false), "\u{20AC}")
  let legacy = @html_parser.parse_fragment("&notit; &not &amp")
  assert_eq(legacy.to_text(separator="", strip=false), "¬it; ¬ &")
  let named = @html_parser.parse_fragment(
    "&copy; &eacute; &frac12; &AMP; &apos; &nbsp;",
  )
  assert_eq(
    named.to_text(separator="", strip=false),
    "\u{00A9} \u{00E9} \u{00BD} & ' \u{00A0}",
  )
  let legacy_named_entities : Array[(String, String)] = [
    ("gt", ">"),
    ("lt", "<"),
    ("amp", "&"),
    ("quot", "\""),
    ("nbsp", "\u{00A0}"),
    ("AMP", "&"),
    ("QUOT", "\""),
    ("GT", ">"),
    ("LT", "<"),
    ("COPY", "\u{00A9}"),
    ("REG", "\u{00AE}"),
    ("AElig", "\u{00C6}"),
    ("Aacute", "\u{00C1}"),
    ("Acirc", "\u{00C2}"),
    ("Agrave", "\u{00C0}"),
    ("Aring", "\u{00C5}"),
    ("Atilde", "\u{00C3}"),
    ("Auml", "\u{00C4}"),
    ("Ccedil", "\u{00C7}"),
    ("ETH", "\u{00D0}"),
    ("Eacute", "\u{00C9}"),
    ("Ecirc", "\u{00CA}"),
    ("Egrave", "\u{00C8}"),
    ("Euml", "\u{00CB}"),
    ("Iacute", "\u{00CD}"),
    ("Icirc", "\u{00CE}"),
    ("Igrave", "\u{00CC}"),
    ("Iuml", "\u{00CF}"),
    ("Ntilde", "\u{00D1}"),
    ("Oacute", "\u{00D3}"),
    ("Ocirc", "\u{00D4}"),
    ("Ograve", "\u{00D2}"),
    ("Oslash", "\u{00D8}"),
    ("Otilde", "\u{00D5}"),
    ("Ouml", "\u{00D6}"),
    ("THORN", "\u{00DE}"),
    ("Uacute", "\u{00DA}"),
    ("Ucirc", "\u{00DB}"),
    ("Ugrave", "\u{00D9}"),
    ("Uuml", "\u{00DC}"),
    ("Yacute", "\u{00DD}"),
    ("aacute", "\u{00E1}"),
    ("acirc", "\u{00E2}"),
    ("acute", "\u{00B4}"),
    ("aelig", "\u{00E6}"),
    ("agrave", "\u{00E0}"),
    ("aring", "\u{00E5}"),
    ("atilde", "\u{00E3}"),
    ("auml", "\u{00E4}"),
    ("brvbar", "\u{00A6}"),
    ("ccedil", "\u{00E7}"),
    ("cedil", "\u{00B8}"),
    ("cent", "\u{00A2}"),
    ("copy", "\u{00A9}"),
    ("curren", "\u{00A4}"),
    ("deg", "\u{00B0}"),
    ("divide", "\u{00F7}"),
    ("eacute", "\u{00E9}"),
    ("ecirc", "\u{00EA}"),
    ("egrave", "\u{00E8}"),
    ("eth", "\u{00F0}"),
    ("euml", "\u{00EB}"),
    ("frac12", "\u{00BD}"),
    ("frac14", "\u{00BC}"),
    ("frac34", "\u{00BE}"),
    ("iacute", "\u{00ED}"),
    ("icirc", "\u{00EE}"),
    ("iexcl", "\u{00A1}"),
    ("igrave", "\u{00EC}"),
    ("iquest", "\u{00BF}"),
    ("iuml", "\u{00EF}"),
    ("laquo", "\u{00AB}"),
    ("macr", "\u{00AF}"),
    ("micro", "\u{00B5}"),
    ("middot", "\u{00B7}"),
    ("not", "\u{00AC}"),
    ("ntilde", "\u{00F1}"),
    ("oacute", "\u{00F3}"),
    ("ocirc", "\u{00F4}"),
    ("ograve", "\u{00F2}"),
    ("ordf", "\u{00AA}"),
    ("ordm", "\u{00BA}"),
    ("oslash", "\u{00F8}"),
    ("otilde", "\u{00F5}"),
    ("ouml", "\u{00F6}"),
    ("para", "\u{00B6}"),
    ("plusmn", "\u{00B1}"),
    ("pound", "\u{00A3}"),
    ("raquo", "\u{00BB}"),
    ("reg", "\u{00AE}"),
    ("sect", "\u{00A7}"),
    ("shy", "\u{00AD}"),
    ("sup1", "\u{00B9}"),
    ("sup2", "\u{00B2}"),
    ("sup3", "\u{00B3}"),
    ("szlig", "\u{00DF}"),
    ("thorn", "\u{00FE}"),
    ("times", "\u{00D7}"),
    ("uacute", "\u{00FA}"),
    ("ucirc", "\u{00FB}"),
    ("ugrave", "\u{00F9}"),
    ("uml", "\u{00A8}"),
    ("uuml", "\u{00FC}"),
    ("yacute", "\u{00FD}"),
    ("yen", "\u{00A5}"),
    ("yuml", "\u{00FF}"),
  ]
  for item in legacy_named_entities {
    let (name, value) = item
    let parsed = @html_parser.parse_fragment("&" + name + ";")
    assert_eq(parsed.to_text(separator="", strip=false), value)
  }
  let exact = @html_parser.parse_fragment(
    "&notin; &hellip; &mdash; &ndash; &trade; &euro;",
  )
  assert_eq(
    exact.to_text(separator="", strip=false),
    "\u{2209} \u{2026} \u{2014} \u{2013} \u{2122} \u{20AC}",
  )
  let quotes = @html_parser.parse_fragment(
    "&ldquo;quote&rdquo; &lsquo;x&rsquo; &rarr; &larr; &le; &ge; &ne;",
  )
  assert_eq(
    quotes.to_text(separator="", strip=false),
    "\u{201C}quote\u{201D} \u{2018}x\u{2019} \u{2192} \u{2190} \u{2264} \u{2265} \u{2260}",
  )
}

///|
test "entity decoding reports upstream fixture errors" {
  let numeric = @html_parser.tokenize("&#65", collect_errors=true)
  guard numeric.tokens[0] is Characters("A") else {
    fail("expected numeric reference token")
  }
  assert_eq(numeric.errors.length(), 1)
  assert_eq(
    numeric.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  guard numeric.errors[0].column is Some(4) else {
    fail("expected numeric missing semicolon at column 4")
  }
  let control = @html_parser.tokenize("&#x80", collect_errors=true)
  guard control.tokens[0] is Characters("\u{20AC}") else {
    fail("expected Windows-1252 numeric replacement")
  }
  assert_eq(control.errors.length(), 2)
  assert_eq(
    control.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(control.errors[1].code, "control-character-reference")
  guard control.errors[1].column is Some(5) else {
    fail("expected control reference at column 5")
  }
  let noncharacter = @html_parser.tokenize("&#xFDD0;", collect_errors=true)
  guard noncharacter.tokens[0] is Characters("\u{FDD0}") else {
    fail("expected noncharacter numeric reference")
  }
  assert_eq(noncharacter.errors.length(), 1)
  assert_eq(noncharacter.errors[0].code, "noncharacter-character-reference")
  guard noncharacter.errors[0].column is Some(8) else {
    fail("expected noncharacter reference at column 8")
  }
  let named_semicolon = @html_parser.tokenize("&notit;", collect_errors=true)
  guard named_semicolon.tokens[0] is Characters("¬it;") else {
    fail("expected legacy prefix match with semicolon")
  }
  assert_eq(named_semicolon.errors.length(), 1)
  assert_eq(
    named_semicolon.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  guard named_semicolon.errors[0].column is Some(7) else {
    fail("expected legacy semicolon error at column 7")
  }
  let named_eof = @html_parser.tokenize("&notit", collect_errors=true)
  guard named_eof.tokens[0] is Characters("¬it") else {
    fail("expected legacy prefix match without semicolon")
  }
  assert_eq(named_eof.errors.length(), 1)
  assert_eq(
    named_eof.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  guard named_eof.errors[0].column is Some(6) else {
    fail("expected legacy EOF error at column 6")
  }
  let fragment = @html_parser.parse_fragment(
    "&#x80 &#xFDD0; &not",
    collect_errors=true,
  )
  assert_eq(fragment.to_text(separator="", strip=false), "€ \u{FDD0} ¬")
  assert_eq(fragment.errors.length(), 4)
  assert_eq(
    fragment.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(fragment.errors[1].code, "control-character-reference")
  assert_eq(fragment.errors[2].code, "noncharacter-character-reference")
  assert_eq(
    fragment.errors[3].code,
    "missing-semicolon-after-character-reference",
  )
  let named_legacy = @html_parser.tokenize(
    "&copy &eacute &frac12 &COPY",
    collect_errors=true,
  )
  guard named_legacy.tokens[0]
    is Characters("\u{00A9} \u{00E9} \u{00BD} \u{00A9}") else {
    fail("expected legacy named entity decoding")
  }
  assert_eq(named_legacy.errors.length(), 4)
  for error in named_legacy.errors {
    assert_eq(error.code, "missing-semicolon-after-character-reference")
  }
  let named_prefix = @html_parser.tokenize(
    "&copycat; &regression &frac12x &notit;",
    collect_errors=true,
  )
  guard named_prefix.tokens[0]
    is Characters("\u{00A9}cat; \u{00AE}ression \u{00BD}x \u{00AC}it;") else {
    fail("expected longest legacy prefix decoding")
  }
  assert_eq(named_prefix.errors.length(), 4)
  for error in named_prefix.errors {
    assert_eq(error.code, "missing-semicolon-after-character-reference")
  }
}

///|
test "numeric entity decoding covers replacement and no digit edges" {
  let zero = @html_parser.tokenize("&#0;", collect_errors=true)
  guard zero.tokens[0] is Characters("\u{FFFD}") else {
    fail("expected null numeric reference replacement")
  }
  assert_eq(zero.errors.length(), 1)
  assert_eq(zero.errors[0].code, "control-character-reference")
  guard zero.errors[0].column is Some(4) else {
    fail("expected null control reference at column 4")
  }
  let c1 = @html_parser.tokenize("&#x82;", collect_errors=true)
  guard c1.tokens[0] is Characters("\u{201A}") else {
    fail("expected C1 numeric replacement")
  }
  assert_eq(c1.errors.length(), 1)
  assert_eq(c1.errors[0].code, "control-character-reference")
  guard c1.errors[0].column is Some(6) else {
    fail("expected C1 control reference at column 6")
  }
  let c1_printable = @html_parser.tokenize("&#x83; &#131;", collect_errors=true)
  guard c1_printable.tokens[0] is Characters("\u{0192} \u{0192}") else {
    fail("expected C1 printable numeric replacements")
  }
  assert_eq(c1_printable.errors.length(), 2)
  for error in c1_printable.errors {
    assert_eq(error.code, "control-character-reference")
  }
  guard c1_printable.errors[0].column is Some(6) else {
    fail("expected hex C1 printable error at column 6")
  }
  guard c1_printable.errors[1].column is Some(13) else {
    fail("expected decimal C1 printable error at column 13")
  }
  let c1_replacements : Array[(String, String)] = [
    ("&#x84;", "\u{201E}"),
    ("&#x85;", "\u{2026}"),
    ("&#x86;", "\u{2020}"),
    ("&#x87;", "\u{2021}"),
    ("&#x88;", "\u{02C6}"),
    ("&#x89;", "\u{2030}"),
    ("&#x8A;", "\u{0160}"),
    ("&#x8B;", "\u{2039}"),
    ("&#x8C;", "\u{0152}"),
    ("&#x8E;", "\u{017D}"),
    ("&#x91;", "\u{2018}"),
    ("&#x92;", "\u{2019}"),
    ("&#x93;", "\u{201C}"),
    ("&#x94;", "\u{201D}"),
    ("&#x95;", "\u{2022}"),
    ("&#x96;", "\u{2013}"),
    ("&#x97;", "\u{2014}"),
    ("&#x98;", "\u{02DC}"),
    ("&#x99;", "\u{2122}"),
    ("&#x9A;", "\u{0161}"),
    ("&#x9B;", "\u{203A}"),
    ("&#x9C;", "\u{0153}"),
    ("&#x9E;", "\u{017E}"),
    ("&#x9F;", "\u{0178}"),
  ]
  for item in c1_replacements {
    let (source, expected) = item
    let result = @html_parser.tokenize(source, collect_errors=true)
    guard result.tokens[0] is Characters(actual) else {
      fail("expected C1 replacement token")
    }
    assert_eq(actual, expected)
    assert_eq(result.errors.length(), 1)
    assert_eq(result.errors[0].code, "control-character-reference")
  }
  let lowercase_hex = @html_parser.tokenize("&#xa;", collect_errors=true)
  guard lowercase_hex.tokens[0] is Characters("\n") else {
    fail("expected lowercase hex numeric reference")
  }
  assert_eq(lowercase_hex.errors.length(), 1)
  assert_eq(lowercase_hex.errors[0].code, "control-character-reference")
  guard lowercase_hex.errors[0].column is Some(5) else {
    fail("expected lowercase hex control reference at column 5")
  }
  let upper_x = @html_parser.tokenize("&#X66;", collect_errors=true)
  guard upper_x.tokens[0] is Characters("f") else {
    fail("expected uppercase X hex marker")
  }
  assert_eq(upper_x.errors.length(), 0)
  let invalid_scalars = @html_parser.tokenize(
    "&#x110000; &#xD800;",
    collect_errors=true,
  )
  guard invalid_scalars.tokens[0] is Characters("\u{FFFD} \u{FFFD}") else {
    fail("expected invalid numeric scalars to replace")
  }
  assert_eq(invalid_scalars.errors.length(), 0)
  let no_digits = @html_parser.tokenize("&#x; &#; &#xg;", collect_errors=true)
  guard no_digits.tokens[0] is Characters("&#x; &#; &#xg;") else {
    fail("expected digitless numeric references to remain literal")
  }
  assert_eq(no_digits.errors.length(), 0)
}

///|
test "attribute entity decoding reports upstream fixture errors" {
  let quoted = @html_parser.tokenize(
    "<div a='&#x80 &notit;'>",
    collect_errors=true,
  )
  guard quoted.tokens[0] is Tag(quoted_tag) else {
    fail("expected quoted attr tag")
  }
  guard quoted_tag.attrs["a"] is Some("\u{20AC} &notit;") else {
    fail("expected stricter attribute entity decoding")
  }
  assert_eq(quoted.errors.length(), 2)
  assert_eq(
    quoted.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(quoted.errors[1].code, "control-character-reference")
  guard quoted.errors[0].column is Some(23) else {
    fail("expected quoted attr errors at current tag cursor")
  }
  guard quoted.errors[1].column is Some(23) else {
    fail("expected quoted attr control error at current tag cursor")
  }
  let unquoted_numeric = @html_parser.tokenize(
    "<div a=&#65>",
    collect_errors=true,
  )
  guard unquoted_numeric.tokens[0] is Tag(unquoted_numeric_tag) else {
    fail("expected unquoted numeric attr tag")
  }
  guard unquoted_numeric_tag.attrs["a"] is Some("A") else {
    fail("expected unquoted numeric attr")
  }
  assert_eq(unquoted_numeric.errors.length(), 1)
  assert_eq(
    unquoted_numeric.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  guard unquoted_numeric.errors[0].column is Some(12) else {
    fail("expected unquoted numeric attr error at tag close")
  }
  let unquoted_named = @html_parser.tokenize(
    "<div a=&notit>",
    collect_errors=true,
  )
  guard unquoted_named.tokens[0] is Tag(unquoted_named_tag) else {
    fail("expected unquoted named attr tag")
  }
  guard unquoted_named_tag.attrs["a"] is Some("&notit") else {
    fail("expected blocked legacy prefix in attribute")
  }
  assert_eq(unquoted_named.errors.length(), 0)
  let parsed = @html_parser.parse_fragment(
    "<div a='&#x80 &notit;'></div>",
    collect_errors=true,
  )
  guard parsed.query_one("div") is Some(div) else {
    fail("expected parsed div")
  }
  guard div.attrs()["a"] is Some("\u{20AC} &notit;") else {
    fail("expected parsed attr value")
  }
  assert_eq(parsed.errors.length(), 2)
  assert_eq(
    parsed.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(parsed.errors[1].code, "control-character-reference")
  let legacy_named = @html_parser.tokenize(
    "<div a='&copycat; &copy= &copy &copy; &apos &apos;'>",
    collect_errors=true,
  )
  guard legacy_named.tokens[0] is Tag(legacy_tag) else {
    fail("expected legacy named attr tag")
  }
  guard legacy_tag.attrs["a"]
    is Some("&copycat; &copy= \u{00A9} \u{00A9} &apos '") else {
    fail("expected legacy named attr blocking")
  }
  assert_eq(legacy_named.errors.length(), 1)
  assert_eq(
    legacy_named.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  let exact_named = @html_parser.tokenize(
    "<div a='&notin; &trade; &notin &trade'>x</div>",
    collect_errors=true,
  )
  guard exact_named.tokens[0] is Tag(exact_tag) else {
    fail("expected exact named attr tag")
  }
  guard exact_tag.attrs["a"] is Some("\u{2209} \u{2122} &notin &trade") else {
    fail("expected exact named attr decoding")
  }
  assert_eq(exact_named.errors.length(), 0)
}

///|
test "attribute legacy entities block alphanumeric continuations" {
  let attr = @html_parser.parse_fragment(
    "<div a='&copycat &copy0 &copy= &copy.'>x</div>",
    collect_errors=true,
  )
  assert_eq(
    attr.to_html(pretty=false),
    "<div a=\"&amp;copycat &amp;copy0 &amp;copy= \u{00A9}.\">x</div>",
  )
  assert_eq(attr.errors.length(), 1)
  assert_eq(attr.errors[0].code, "missing-semicolon-after-character-reference")
  guard attr.errors[0].column is Some(39) else {
    fail("expected decoded attribute legacy entity error at tag close")
  }
  let text = @html_parser.parse_fragment(
    "&copycat &copy0 &copy= &copy.",
    collect_errors=true,
  )
  assert_eq(
    text.to_html(pretty=false),
    "\u{00A9}cat \u{00A9}0 \u{00A9}= \u{00A9}.",
  )
  assert_eq(text.errors.length(), 4)
  for error in text.errors {
    assert_eq(error.code, "missing-semicolon-after-character-reference")
  }
}

///|
test "special text entity decoding reports upstream fixture errors" {
  let title = @html_parser.tokenize(
    "<title>&#x80 &notit;</title>",
    collect_errors=true,
  )
  guard title.tokens[1] is Characters("\u{20AC} ¬it;") else {
    fail("expected title RCDATA entities")
  }
  assert_eq(title.errors.length(), 3)
  assert_eq(title.errors[0].code, "missing-semicolon-after-character-reference")
  assert_eq(title.errors[1].code, "control-character-reference")
  assert_eq(title.errors[2].code, "missing-semicolon-after-character-reference")
  guard title.errors[0].column is Some(28) else {
    fail("expected title entity errors at closing tag")
  }
  guard title.errors[2].column is Some(28) else {
    fail("expected title legacy entity error at closing tag")
  }
  let textarea = @html_parser.tokenize(
    "<textarea>&#65</textarea>",
    collect_errors=true,
  )
  guard textarea.tokens[1] is Characters("A") else {
    fail("expected textarea RCDATA entity")
  }
  assert_eq(textarea.errors.length(), 1)
  assert_eq(
    textarea.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  guard textarea.errors[0].column is Some(25) else {
    fail("expected textarea entity error at closing tag")
  }
  let script = @html_parser.tokenize(
    "<script>&#x80</script>",
    collect_errors=true,
  )
  guard script.tokens[1] is Characters("&#x80") else {
    fail("expected script raw text to skip entity decoding")
  }
  assert_eq(script.errors.length(), 0)
  let parsed = @html_parser.parse_fragment(
    "<title>&#x80 &notit;</title>",
    collect_errors=true,
  )
  assert_eq(parsed.to_text(separator="", strip=false), "\u{20AC} ¬it;")
  assert_eq(parsed.errors.length(), 3)
  assert_eq(
    parsed.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(parsed.errors[1].code, "control-character-reference")
  assert_eq(
    parsed.errors[2].code,
    "missing-semicolon-after-character-reference",
  )
}
