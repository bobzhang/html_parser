///|
test "sanitize_dom filters attributes and dangerous URLs" {
  let fragment = @html_parser.parse_fragment(
    "<div id=x onclick=alert(1) srcdoc='<p>p</p>' x:y=z title=t class=c data-x=y><a href='javascript:alert(1)' title='t'>x</a><a href='//example.com/path'>y</a><img src='https://x' alt=abs><img src='/safe.png' onerror=x alt=ok></div>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root).to_html(pretty=false),
    "<div id=\"x\" title=\"t\" class=\"c\"><a title=\"t\">x</a><a href=\"https://example.com/path\">y</a><img alt=\"abs\"><img src=\"/safe.png\" alt=\"ok\"></div>",
  )
}

///|
test "sanitize_dom drops meta refresh content attributes" {
  let policy = @html_parser.SanitizationPolicy(
    ["meta", "p"],
    allowed_attributes={ "meta": ["http-equiv", "content"] },
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<meta http-equiv='refresh' content='0;url=javascript:alert(1)'><meta http-equiv='Content-Type' content='text/html; charset=utf-8'><p>ok</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<meta http-equiv=\"refresh\"><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"><p>ok</p>",
  )
}

///|
test "sanitize_dom drops base href even when allowlisted" {
  let policy = @html_parser.SanitizationPolicy(
    ["base", "img"],
    allowed_attributes={ "base": ["href"], "img": ["src"] },
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<base Href='https://evil.example/assets/'><img src='pixel'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<base><img src=\"pixel\">",
  )
}

///|
test "sanitize_dom drops url-like attributes without exact url rules" {
  let policy = @html_parser.SanitizationPolicy(
    ["a", "img", "blockquote", "object", "p", "form", "button", "video"],
    allowed_attributes={
      "a": ["href", "ping"],
      "img": ["src", "srcset", "attributionsrc", "poster"],
      "video": ["poster"],
      "form": ["action"],
      "button": ["formaction"],
      "blockquote": ["cite"],
      "object": ["data"],
      "p": ["background", "data-x"],
    },
    url_policy=@html_parser.UrlPolicy(allow_rules=[]),
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://example.com' ping='https://trusted.example/p https://evil.example/p'>x</a><img src='/ok.png' srcset='/one.png 1x' attributionsrc='https://evil.example/register' poster='/poster.png'><video poster='/poster.png'></video><form action='/submit'></form><button formaction='/submit'>go</button><blockquote cite='https://evil.example/q'></blockquote><object data='/payload'></object><p background='/bg.png' data-x='ok'>t</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a>x</a><img><video></video><form></form><button>go</button><blockquote></blockquote><object></object><p data-x=\"ok\">t</p>",
  )
}

///|
test "sanitize_dom applies single url-like attribute rules" {
  let remote_rule = @html_parser.UrlRule(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy(allow_rules=[
    @html_parser.UrlPolicyRule("video", "poster", remote_rule),
    @html_parser.UrlPolicyRule("form", "action", remote_rule),
    @html_parser.UrlPolicyRule("button", "formaction", remote_rule),
    @html_parser.UrlPolicyRule("blockquote", "cite", remote_rule),
    @html_parser.UrlPolicyRule("object", "data", remote_rule),
    @html_parser.UrlPolicyRule("p", "background", remote_rule),
  ])
  let policy = @html_parser.SanitizationPolicy(
    ["video", "form", "button", "blockquote", "object", "p"],
    allowed_attributes={
      "video": ["poster"],
      "form": ["action"],
      "button": ["formaction"],
      "blockquote": ["cite"],
      "object": ["data"],
      "p": ["background"],
    },
    url_policy~,
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<video poster='https://trusted.example/poster.png'></video><video poster='https://evil.example/poster.png'></video><form action='//trusted.example/submit'></form><button formaction='https://trusted.example/send'>go</button><blockquote cite='https://trusted.example/q'></blockquote><object data='https://trusted.example/payload'></object><p background='https://trusted.example/bg.png'>ok</p><p background='/relative.png'>rel</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<video poster=\"https://trusted.example/poster.png\"></video><video></video><form action=\"https://trusted.example/submit\"></form><button formaction=\"https://trusted.example/send\">go</button><blockquote cite=\"https://trusted.example/q\"></blockquote><object data=\"https://trusted.example/payload\"></object><p background=\"https://trusted.example/bg.png\">ok</p><p>rel</p>",
  )
}

///|
test "sanitize_dom applies custom url policy rules" {
  let url_policy = @html_parser.UrlPolicy(
    default_handling=UrlStrip,
    default_allow_relative=false,
    allow_rules=[
      @html_parser.UrlPolicyRule(
        "a",
        "href",
        @html_parser.UrlRule(
          allowed_schemes=["https"],
          allow_fragment=false,
          allow_relative=false,
          handling=UrlAllow,
        ),
      ),
      @html_parser.UrlPolicyRule(
        "img",
        "src",
        @html_parser.UrlRule(
          allowed_schemes=["https"],
          allow_relative=false,
          resolve_protocol_relative=None,
        ),
      ),
    ],
  )
  let policy = @html_parser.SanitizationPolicy(
    ["a", "img"],
    allowed_attributes={ "a": ["href"], "img": ["src"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='http://drop.test/'>http</a><a href='https://ok.test/'>https</a><a href='/rel'>rel</a><a href='#frag'>frag</a><a href='//ok.test/path'>proto</a><img src='https://ok.test/i.png'><img src='/rel.png'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a>http</a><a href=\"https://ok.test/\">https</a><a>rel</a><a>frag</a><a href=\"https://ok.test/path\">proto</a><img><img>",
  )
}

///|
test "sanitize_dom drops empty url values" {
  let url_policy = @html_parser.UrlPolicy(allow_rules=[
    @html_parser.UrlPolicyRule(
      "a",
      "href",
      @html_parser.UrlRule(allowed_schemes=["https"], allow_relative=false),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href=' \t\n'></a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a></a>",
  )
}

///|
test "sanitize_dom drops decoded control characters in url values" {
  let url_policy = @html_parser.UrlPolicy(allow_rules=[
    @html_parser.UrlPolicyRule(
      "a",
      "href",
      @html_parser.UrlRule(
        allowed_schemes=["https"],
        allowed_hosts=["example.com"],
        allow_relative=false,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://example.com/a&#10;b'>lf</a><a href='https://example.com/a&#x7F;b'>del</a><a href='https://example.com/a\\b'>slash</a><a href='https://example.com/ok'>ok</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a>lf</a><a>del</a><a>slash</a><a href=\"https://example.com/ok\">ok</a>",
  )
}

///|
test "sanitize_dom applies url policy host allowlists" {
  let url_policy = @html_parser.UrlPolicy(allow_rules=[
    @html_parser.UrlPolicyRule(
      "a",
      "href",
      @html_parser.UrlRule(
        allowed_schemes=["https"],
        allowed_hosts=["trusted.example", "::1"],
        allow_relative=false,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://trusted.example/path'>ok</a><a href='https://TRUSTED.example/case'>case</a><a href='https://trusted.example:443/port'>port</a><a href='https://user@trusted.example/userinfo'>userinfo</a><a href='https://[::1]/ip'>ipv6</a><a href='//trusted.example/proto'>proto</a><a href='https://evil.example/path'>evil</a><a href='https://ex[ample].com/path'>bad-bracket</a><a href='https://[::1'>missing-bracket</a><a href='https://evil.example\\@trusted.example/path'>backslash</a><a href='/relative'>relative</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a href=\"https://trusted.example/path\">ok</a><a href=\"https://TRUSTED.example/case\">case</a><a href=\"https://trusted.example:443/port\">port</a><a href=\"https://user@trusted.example/userinfo\">userinfo</a><a href=\"https://[::1]/ip\">ipv6</a><a href=\"https://trusted.example/proto\">proto</a><a>evil</a><a>bad-bracket</a><a>missing-bracket</a><a>backslash</a><a>relative</a>",
  )
}

///|
test "sanitize_dom applies srcset url policy rules" {
  let srcset_rule = @html_parser.UrlRule(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy(allow_rules=[
    @html_parser.UrlPolicyRule("img", "srcset", srcset_rule),
    @html_parser.UrlPolicyRule("link", "imagesrcset", srcset_rule),
  ])
  let policy = @html_parser.SanitizationPolicy(
    ["img", "link"],
    allowed_attributes={
      "img": ["srcset"],
      "link": ["rel", "as", "imagesrcset"],
    },
    url_policy~,
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<img srcset=' https://trusted.example/a 1x, , //trusted.example/b 2x '><img srcset='https://trusted.example/a 1x, https://evil.example/b 2x'><img srcset='  \t\n  '><link rel='preload' as='image' imagesrcset='https://trusted.example/a 1x, https://trusted.example/b 2x'><link rel='preload' as='image' imagesrcset='https://evil.example/a 1x'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<img srcset=\"https://trusted.example/a 1x, https://trusted.example/b 2x\"><img><img><link rel=\"preload\" as=\"image\" imagesrcset=\"https://trusted.example/a 1x, https://trusted.example/b 2x\"><link rel=\"preload\" as=\"image\">",
  )
}

///|
test "sanitize_dom applies space separated url list rules" {
  let url_list_rule = @html_parser.UrlRule(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy(allow_rules=[
    @html_parser.UrlPolicyRule("a", "href", url_list_rule),
    @html_parser.UrlPolicyRule("a", "ping", url_list_rule),
    @html_parser.UrlPolicyRule("img", "src", url_list_rule),
    @html_parser.UrlPolicyRule("img", "attributionsrc", url_list_rule),
  ])
  let policy = @html_parser.SanitizationPolicy(
    ["a", "img"],
    allowed_attributes={
      "a": ["href", "ping"],
      "img": ["src", "attributionsrc"],
    },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://trusted.example/x' ping=' https://trusted.example/p   //trusted.example/q '>ok</a><a href='https://trusted.example/x' ping='https://trusted.example/p https://evil.example/p'>bad</a><a href='https://trusted.example/x' ping='  \t\n  '>empty</a><img src='https://trusted.example/x.png' attributionsrc='https://trusted.example/register https://trusted.example/measure'><img src='https://trusted.example/x.png' attributionsrc='https://trusted.example/register https://evil.example/register'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a href=\"https://trusted.example/x\" ping=\"https://trusted.example/p https://trusted.example/q\">ok</a><a href=\"https://trusted.example/x\">bad</a><a href=\"https://trusted.example/x\">empty</a><img src=\"https://trusted.example/x.png\" attributionsrc=\"https://trusted.example/register https://trusted.example/measure\"><img src=\"https://trusted.example/x.png\">",
  )
}

///|
test "sanitize_dom handles standalone nodes and url edge cases" {
  let allowed = @html_parser.element(
    "p",
    attrs={ "onclick": Some("x"), "title": Some("t") },
    children=[@html_parser.text("ok")],
  )
  assert_eq(
    @html_parser.sanitize_dom(allowed).to_html(pretty=false),
    "<p title=\"t\">ok</p>",
  )
  let unwrapped = @html_parser.element("sarcasm", children=[
    @html_parser.text("a"),
    @html_parser.element("b", children=[@html_parser.text("b")]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(unwrapped).to_html(pretty=false),
    "a<b>b</b>",
  )
  let strict_attrs = @html_parser.fragment(children=[
    @html_parser.element("div", attrs={ "id": Some("x") }),
  ])
  let strict_policy = @html_parser.SanitizationPolicy(["div"])
  assert_eq(
    @html_parser.sanitize_dom(strict_attrs, policy=strict_policy).to_html(
      pretty=false,
    ),
    "<div></div>",
  )
  let foreign = @html_parser.fragment(children=[
    @html_parser.element("svg", ns="svg", children=[
      @html_parser.element("title", ns="svg", children=[@html_parser.text("x")]),
    ]),
    @html_parser.element("p", children=[@html_parser.text("ok")]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(foreign).to_html(pretty=false),
    "<p>ok</p>",
  )
  let urls = @html_parser.parse_fragment(
    "<a href='#frag'>f</a><a href='HTTP://ok'>h</a><a href='/rel'>r</a><a href='java\t\nscript:evil'>bad</a><a href='/bad\npath'>control</a><img src='//x'><img src>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(urls.root).to_html(pretty=false),
    "<a href=\"#frag\">f</a><a href=\"HTTP://ok\">h</a><a href=\"/rel\">r</a><a>bad</a><a>control</a><img><img>",
  )
}
