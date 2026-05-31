///|
test "public parse error constructor defaults and equality stay stable" {
  let basic = @html_parser.ParseError("custom-error")
  assert_eq(basic.code, "custom-error")
  assert_true(basic.line is None)
  assert_true(basic.column is None)
  assert_eq(basic.category, "parse")
  assert_eq(basic.message, "custom-error")

  let detailed = @html_parser.ParseError(
    "custom-error",
    line=2,
    column=4,
    category="tokenizer",
    message="detail",
  )
  let same = @html_parser.ParseError(
    "custom-error",
    line=2,
    column=4,
    category="tokenizer",
    message="detail",
  )
  assert_true(detailed == same)
  assert_true(detailed != basic)
  guard detailed.line is Some(2) else { fail("expected detailed line") }
  guard detailed.column is Some(4) else { fail("expected detailed column") }
  assert_eq(detailed.category, "tokenizer")
  assert_eq(detailed.message, "detail")
}

///|
test "public fragment context and selector limit constructors stay stable" {
  let context = @html_parser.FragmentContext("TeMpLaTe", ns="mathml")
  assert_eq(context.tag_name, "template")
  guard context.ns is Some("mathml") else {
    fail("expected namespace to be preserved")
  }

  let defaults = @html_parser.SelectorLimits()
  assert_eq(defaults.max_match_depth, 100)
  assert_eq(defaults.max_length, 8192)
  assert_eq(defaults.max_list_items, 256)
  assert_eq(defaults.max_compound_simple_selectors, 512)
  assert_eq(defaults.max_complex_selector_parts, 512)
  assert_eq(defaults.max_parse_depth, 100)
  assert_eq(defaults.max_match_steps, 100000000)
  assert_eq(defaults.max_match_bytes, 100000000)

  let custom = @html_parser.SelectorLimits(
    max_match_depth=0,
    max_length=10,
    max_list_items=2,
    max_compound_simple_selectors=3,
    max_complex_selector_parts=4,
    max_parse_depth=5,
    max_match_steps=6,
    max_match_bytes=-1,
  )
  assert_eq(custom.max_match_depth, 0)
  assert_eq(custom.max_length, 10)
  assert_eq(custom.max_list_items, 2)
  assert_eq(custom.max_compound_simple_selectors, 3)
  assert_eq(custom.max_complex_selector_parts, 4)
  assert_eq(custom.max_parse_depth, 5)
  assert_eq(custom.max_match_steps, 6)
  assert_eq(custom.max_match_bytes, -1)
  assert_true(custom != defaults)
}

///|
test "public linkify config constructors normalize and copy options" {
  let extra_tlds = [" INTERNAL ", "", "EXAMPLE"]
  let config = @html_parser.LinkifyConfig(fuzzy_ip=true, extra_tlds~)
  extra_tlds.clear()
  let matches = @html_parser.find_links_with_config(
    "site.internal a@b.example 192.168.0.1 site.invalid", config,
  )
  assert_eq(matches.length(), 3)
  assert_eq(matches[0].text, "site.internal")
  assert_eq(matches[0].href, "http://site.internal")
  assert_eq(matches[1].text, "a@b.example")
  assert_eq(matches[1].href, "mailto:a@b.example")
  assert_eq(matches[2].text, "192.168.0.1")
  assert_eq(matches[2].href, "http://192.168.0.1")

  let tld_only = @html_parser.LinkifyConfig::with_extra_tlds(["Internal"])
  assert_eq(
    @html_parser.find_links_with_config("site.internal", tld_only).length(),
    1,
  )
  assert_eq(
    @html_parser.find_links_with_config("192.168.0.1", tld_only).length(),
    0,
  )
}
