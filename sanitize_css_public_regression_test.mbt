///|
test "sanitize_dom filters inline style declarations by property allowlist" {
  let no_css = @html_parser.parse_fragment(
    "<p style='color: red'>x</p>",
    sanitize=false,
  )
  let no_css_policy = @html_parser.SanitizationPolicy(["p"], allowed_attributes={
    "*": [],
    "p": ["style"],
  })
  assert_eq(
    @html_parser.sanitize_dom(no_css.root, policy=no_css_policy).to_html(
      pretty=false,
    ),
    "<p>x</p>",
  )
  let styled = @html_parser.parse_fragment(
    "<p style='; color; color: ; co_lor: red; margin: 0; COLOR: red; font-weight: 700; background-image: url(/x.png); width: expression(alert(1))'>ok</p><p style>empty</p><p STYLE='color: blue; text-align: center; background-image: u/**/rl(/x.png)'>case</p><p style='color: /*unterminated'>comment</p><p style=': red; color: orange'>empty-prop</p>",
    sanitize=false,
  )
  let style_policy = @html_parser.SanitizationPolicy(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=[
      "color", "font-weight", "background-image", "width", "text-align",
    ],
  )
  assert_eq(
    @html_parser.sanitize_dom(styled.root, policy=style_policy).to_html(
      pretty=false,
    ),
    "<p style=\"color: red; font-weight: 700\">ok</p><p>empty</p><p style=\"color: blue; text-align: center\">case</p><p>comment</p><p style=\"color: orange\">empty-prop</p>",
  )
}

///|
test "css_preset_text allows conservative inline text styling" {
  let policy = @html_parser.SanitizationPolicy(
    ["div"],
    allowed_attributes={ "*": [], "div": ["style"] },
    allowed_css_properties=@html_parser.css_preset_text(),
  )
  let styled = @html_parser.parse_fragment(
    "<div style='color: red; position: fixed; top: 0'>x</div><div style='position: fixed'>y</div>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(styled.root, policy~).to_html(pretty=false),
    "<div style=\"color: red\">x</div><div>y</div>",
  )

  let mutated = @html_parser.css_preset_text()
  mutated.clear()
  let fresh = @html_parser.SanitizationPolicy(
    ["span"],
    allowed_attributes={ "span": ["style"] },
    allowed_css_properties=@html_parser.css_preset_text(),
  )
  let span = @html_parser.parse_fragment(
    "<span style='font-weight: 700'>ok</span>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(span.root, policy=fresh).to_html(pretty=false),
    "<span style=\"font-weight: 700\">ok</span>",
  )
}

///|
test "sanitize_dom applies css url function policy rules" {
  let css_url_rule = @html_parser.UrlRule(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy(allow_rules=[
    @html_parser.UrlPolicyRule("*", "style:background-image", css_url_rule),
  ])
  let policy = @html_parser.SanitizationPolicy(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style='background-image: url(/safe.png); color: red'>ok</p><p style=\"background-image: url('https://evil.example/x.png'); color: blue\">bad</p><p style=\"background-image: image-set(url('/safe.png') 1x); color: green\">blocked</p><p style='background-image: URL(  \"/safe-2.png\"  )'>case</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"background-image: url('/safe.png'); color: red\">ok</p><p style=\"color: blue\">bad</p><p style=\"color: green\">blocked</p><p style=\"background-image: url('/safe-2.png')\">case</p>",
  )
}

///|
test "sanitize_dom rejects comments in css url function values" {
  let css_url_rule = @html_parser.UrlRule(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy(allow_rules=[
    @html_parser.UrlPolicyRule("*", "style:background-image", css_url_rule),
  ])
  let policy = @html_parser.SanitizationPolicy(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style='background-image: url(/x.png)/*comment*/; color: red'>comment</p><p style='background-image: linear-gradient(red, blue), url(/y.png); color: blue'>gradient</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"color: red\">comment</p><p style=\"background-image: linear-gradient(red, blue), url('/y.png'); color: blue\">gradient</p>",
  )
}

///|
test "sanitize_dom rejects malformed css url function values" {
  let css_url_rule = @html_parser.UrlRule(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy(allow_rules=[
    @html_parser.UrlPolicyRule("*", "style:background-image", css_url_rule),
  ])
  let policy = @html_parser.SanitizationPolicy(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style=\"background-image: url('/x\\y.png'); color: red\">backslash</p><p style='background-image: url(/x y); color: blue'>space</p><p style='background-image: url(/x\u{007F}y); color: green'>del</p><p style='background-image: url(); color: black'>empty</p><p style=\"background-image: url('/x')x; color: purple\">tail</p><p style=\"background-image: url('/unterminated); color: olive\">missing-quote</p><p style=\"background-image: url('/missing-paren'; color: maroon\">missing-paren</p><p style='background-image: u rl(/x.png); color: lime'>obfuscated</p><p style='background-image: u\trl(/x.png); color: aqua'>tab</p><p style=\"background-image: url('/spaced.png'   ); color: navy\">spaced</p><p style=\"background-image: url(/ok.png), url('/next.png'); color: teal\">ok</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"color: red\">backslash</p><p style=\"color: blue\">space</p><p style=\"color: green\">del</p><p style=\"color: black\">empty</p><p style=\"color: purple\">tail</p><p style=\"color: olive\">missing-quote</p><p style=\"color: maroon\">missing-paren</p><p style=\"color: lime\">obfuscated</p><p style=\"color: aqua\">tab</p><p style=\"background-image: url('/spaced.png'); color: navy\">spaced</p><p style=\"background-image: url('/ok.png'), url('/next.png'); color: teal\">ok</p>",
  )
}

///|
test "sanitize_dom drops unquoted css url with missing close paren" {
  let css_url_rule = @html_parser.UrlRule(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy(allow_rules=[
    @html_parser.UrlPolicyRule("*", "style:background-image", css_url_rule),
  ])
  let policy = @html_parser.SanitizationPolicy(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style='background-image: url(/missing; color: silver'>missing-raw-paren</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"color: silver\">missing-raw-paren</p>",
  )
}

///|
test "public css text preset returns independent conservative lists" {
  let mutated = @html_parser.css_preset_text()
  assert_true(mutated.length() > 0)
  mutated.clear()
  let policy = @html_parser.SanitizationPolicy(
    ["span"],
    allowed_attributes={ "*": [], "span": ["style"] },
    allowed_css_properties=@html_parser.css_preset_text(),
  )
  let doc = @html_parser.parse_fragment(
    "<span style='font-weight:700; position:fixed; color:red'>ok</span>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(doc.root, policy~).to_html(pretty=false),
    "<span style=\"font-weight: 700; color: red\">ok</span>",
  )
}
