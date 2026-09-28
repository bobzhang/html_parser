///|
/// An independent description of a sanitization policy, used both to build
/// the real policy and as the oracle its output is checked against.
///
/// The oracle does not call into the sanitizer. It restates the documented
/// contract: only allowlisted tags and attributes survive, event handlers,
/// `srcdoc` and namespaced attributes never do, dropped-content tags and
/// foreign content disappear with their text, comments and doctypes follow
/// their flags, invisible Unicode is stripped from text, and URL attributes
/// keep only the schemes the default URL policy lists.
struct PolicyModel {
  tags : Array[String]
  attrs : Map[String, Array[String]]
  handling : @html_parser.DisallowedTagHandling
  drop_content : Array[String]
  drop_comments : Bool
  drop_doctype : Bool
  strip_invisible : Bool
  css : Array[String]
}

///|
/// The documented default fragment policy.
fn default_policy_model() -> PolicyModel {
  {
    tags: [
      "p", "br", "div", "span", "blockquote", "pre", "code", "h1", "h2", "h3", "h4",
      "h5", "h6", "ul", "ol", "li", "table", "caption", "thead", "tbody", "tfoot",
      "tr", "th", "td", "b", "strong", "i", "em", "u", "s", "sub", "sup", "small",
      "mark", "hr", "a", "img",
    ],
    attrs: {
      "*": ["class", "id", "title", "lang", "dir"],
      "a": ["href", "title"],
      "img": ["src", "alt", "title", "width", "height", "loading", "decoding"],
      "th": ["colspan", "rowspan"],
      "td": ["colspan", "rowspan"],
    },
    handling: Unwrap,
    drop_content: ["script", "style"],
    drop_comments: true,
    drop_doctype: true,
    strip_invisible: true,
    css: [],
  }
}

///|
/// The documented default document policy: the fragment policy plus the
/// document shell, with the doctype kept.
fn document_policy_model() -> PolicyModel {
  let model = default_policy_model()
  {
    ..model,
    tags: model.tags + ["html", "head", "body", "title"],
    drop_doctype: false,
  }
}

///|
/// Build the real policy this model describes.
fn PolicyModel::to_policy(
  self : PolicyModel,
) -> @html_parser.SanitizationPolicy {
  SanitizationPolicy(
    self.tags,
    allowed_attributes=self.attrs,
    drop_comments=self.drop_comments,
    drop_doctype=self.drop_doctype,
    drop_content_tags=self.drop_content,
    disallowed_tag_handling=self.handling,
    allowed_css_properties=self.css,
    strip_invisible_unicode=self.strip_invisible,
  )
}

///|
/// Return whether the sanitizer documents `ch` as invisible Unicode.
fn is_documented_invisible(ch : Char) -> Bool {
  let code = ch.to_int()
  code == 0x061C ||
  (code >= 0x200B && code <= 0x200F) ||
  (code >= 0x202A && code <= 0x202E) ||
  (code >= 0x2060 && code <= 0x2069) ||
  (code >= 0xFE00 && code <= 0xFE0F) ||
  code == 0xFEFF ||
  (code >= 0xE000 && code <= 0xF8FF) ||
  (code >= 0xE0100 && code <= 0xE01EF) ||
  (code >= 0xF0000 && code <= 0xFFFFD) ||
  (code >= 0x100000 && code <= 0x10FFFD)
}

///|
/// The scheme a browser would resolve `value` with, if it has one.
///
/// Mirrors the URL parser rather than the sanitizer: leading and trailing C0
/// controls and spaces are stripped, tabs and newlines are removed anywhere,
/// and the scheme is the leading `[A-Za-z][A-Za-z0-9+.-]*` before a `:`.
fn browser_url_scheme(value : String) -> String? {
  let cleaned = StringBuilder()
  for ch in value.trim(char_set=url_c0_and_space()) {
    if !(ch is ('\t' | '\n' | '\r')) {
      cleaned.write_char(ch)
    }
  }
  let url = cleaned.to_string()
  let scheme = StringBuilder()
  for index, ch in url {
    if ch == ':' {
      return if index == 0 { None } else { Some(scheme.to_string().to_lower()) }
    }
    let ok = if index == 0 {
      ch.is_ascii_alphabetic()
    } else {
      ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch is ('+' | '-' | '.')
    }
    if !ok {
      return None
    }
    scheme.write_char(ch)
  }
  None
}

///|
/// C0 controls and space, which the URL parser strips from both ends.
fn url_c0_and_space() -> String {
  let out = StringBuilder()
  for code in 0..<=0x20 {
    out.write_char(code.unsafe_to_char())
  }
  out.to_string()
}

///|
/// Check one URL attribute value against the default URL policy.
///
/// Only `a[href]` and `img[src]` have rules; every other URL-bearing
/// attribute is stripped. Anchors take http, https, mailto and tel, with
/// protocol-relative URLs resolved to https; images take relative URLs only.
fn url_attribute_violation(
  tag : String,
  name : String,
  value : String,
) -> String? {
  let url_like = [
    "href", "src", "poster", "action", "formaction", "data", "cite", "background",
    "srcset", "imagesrcset", "ping", "attributionsrc",
  ]
  if !url_like.contains(name) {
    return None
  }
  let trimmed = value.trim(char_set=url_c0_and_space()).to_owned()
  if trimmed.contains_char('\\') {
    return Some("backslash in \{tag}[\{name}]=\{value}")
  }
  match (tag, name) {
    ("a", "href") =>
      match browser_url_scheme(value) {
        Some("http" | "https" | "mailto" | "tel") | None =>
          if trimmed.has_prefix("//") {
            Some("unresolved protocol-relative a[href]=\{value}")
          } else {
            None
          }
        Some(scheme) => Some("scheme \{scheme} in a[href]=\{value}")
      }
    ("img", "src") =>
      if browser_url_scheme(value) is Some(scheme) {
        Some("scheme \{scheme} in img[src]=\{value}")
      } else if trimmed.has_prefix("//") || trimmed.has_prefix("#") {
        Some("non-relative img[src]=\{value}")
      } else {
        None
      }
    _ => Some("URL attribute without a rule: \{tag}[\{name}]=\{value}")
  }
}

///|
/// Remove CSS comments and lowercase, for resource-load checks on style
/// values that survived. Escapes are left in place: a surviving backslash is
/// itself reported, so nothing hides behind one.
fn css_for_checking(value : String) -> String {
  let out = StringBuilder()
  let mut in_comment = false
  let mut index = 0
  let chars = value.to_array()
  while index < chars.length() {
    let ch = chars[index]
    if in_comment {
      if ch == '*' && index + 1 < chars.length() && chars[index + 1] == '/' {
        in_comment = false
        index += 1
      }
    } else if ch == '/' && index + 1 < chars.length() && chars[index + 1] == '*' {
      in_comment = true
      index += 1
    } else if !(ch is (' ' | '\t' | '\n' | '\r' | '\u{000C}')) {
      out.write_char(ch.to_ascii_lowercase())
    }
    index += 1
  }
  out.to_string()
}

///|
/// Check a surviving `style` value: only allowlisted properties, and nothing
/// that can load a resource or run script.
///
/// `image()` and `src()` are not listed: no browser ships them, and the
/// sanitizer's documented list of resource-loading functions leaves them out.
fn style_violation(model : PolicyModel, value : String) -> String? {
  let checked = css_for_checking(value)
  for
    needle in [
      "\\", "url(", "image-set(", "expression(", "@import", "binding", "behavior",
      "javascript:",
    ] {
    if checked.contains(needle) {
      return Some("style keeps \{needle}: \{value}")
    }
  }
  for declaration in value.split(";") {
    let declaration = declaration.trim()
    if declaration.is_empty() {
      continue
    }
    guard declaration.find(":") is Some(colon) else {
      return Some("style declaration without a colon: \{value}")
    }
    let property = declaration
      .view(end_offset=colon)
      .trim()
      .to_owned()
      .to_lower()
    if !model.css.contains(property) {
      return Some("style keeps property \{property}: \{value}")
    }
  }
  None
}

///|
/// Return the first way `root` violates `model`, or `None`.
fn policy_violation(root : @dom.Node, model : PolicyModel) -> String? {
  for node in collect_all_nodes(root) {
    match node.kind() {
      Comment => if model.drop_comments { return Some("comment kept") }
      Doctype => if model.drop_doctype { return Some("doctype kept") }
      Text =>
        if model.strip_invisible {
          for ch in node.data() {
            if is_documented_invisible(ch) {
              return Some("invisible U+\{ch.to_int().to_string(radix=16)} kept")
            }
          }
        }
      Element => {
        let tag = node.name().to_lower()
        if !(node.namespace_uri() is (None | Some("html"))) {
          return Some("foreign element \{tag} kept")
        }
        if !model.tags.contains(tag) {
          return Some("disallowed element \{tag} kept")
        }
        if model.drop_content.contains(tag) {
          return Some("dropped-content element \{tag} kept")
        }
        let global = model.attrs.get("*").unwrap_or([])
        let own = model.attrs.get(tag).unwrap_or([])
        for name, value in node.attrs() {
          let name = name.to_lower()
          if name.has_prefix("on") || name == "srcdoc" || name.contains(":") {
            return Some("dangerous attribute \{tag}[\{name}] kept")
          }
          if !global.contains(name) && !own.contains(name) {
            return Some("disallowed attribute \{tag}[\{name}] kept")
          }
          let value = value.unwrap_or("")
          if url_attribute_violation(tag, name, value) is Some(message) {
            return Some(message)
          }
          if name == "style" && style_violation(model, value) is Some(message) {
            return Some(message)
          }
        }
      }
      Document | Fragment => ()
    }
  }
  None
}

///|
/// Render a violation for a counterexample report.
fn describe_violation(violation : String?) -> String {
  match violation {
    Some(message) => message
    None => "none"
  }
}

///|
/// Sanitize a deep copy of `root`; the sanitizer works in place.
fn sanitized_copy(
  root : @dom.Node,
  model : PolicyModel,
) -> @dom.Node raise @core.HtmlError {
  @html_parser.sanitize_dom(
    root.clone_node(deep=true),
    policy=model.to_policy(),
  )
}

///|
test "property: default sanitizer output conforms to the documented policy" {
  let fragment = default_policy_model()
  let document = document_policy_model()
  @qc.check(
    (input : MarkupFuzz) => {
      let src = input.source()
      if policy_violation(@html_parser.parse(src, sanitize=true).root, document)
        is Some(_) {
        return false
      }
      for context in fuzz_contexts() {
        let root = fuzz_parse_fragment(src, context, sanitize=true).root
        if policy_violation(root, fragment) is Some(_) {
          return false
        }
      }
      true
    },
    count=800,
    seed=20260910,
    observe=fuzz_observations,
    counterexample_context=input => {
      let src = input.source()
      try {
        let doc = @html_parser.parse(src, sanitize=true).root
        let frag = @html_parser.parse_fragment(src, sanitize=true).root
        let doc_violation = policy_violation(doc, document_policy_model())
        let frag_violation = policy_violation(frag, default_policy_model())
        "document: \{describe_violation(doc_violation)}, fragment: \{describe_violation(frag_violation)}"
      } catch {
        _ => "raised"
      }
    },
  )
}

///|
test "property: sanitized output stays conformant when reparsed" {
  // Mutation XSS: what matters is the tree a browser builds from the
  // sanitizer's *serialized* output, which need not be the sanitized tree.
  let fragment = default_policy_model()
  let document = document_policy_model()
  @qc.check(
    (input : MarkupFuzz) => {
      let src = input.source()
      // The document policy keeps the doctype, whose name can be one the
      // serializer refuses (the issue #113 name grammar), so that side is
      // skipped when serialization raises. The fragment policy drops doctypes
      // and every element and attribute name it keeps is serializable.
      let doc_html = fuzz_to_html(@html_parser.parse(src, sanitize=true).root)
      let frag_html = @html_parser.parse_fragment(src, sanitize=true).to_html(
        pretty=false,
      )
      for scripting in [true, false] {
        if doc_html is Some(doc_html) {
          let doc = @html_parser.parse(doc_html, scripting_enabled=scripting)
          if policy_violation(doc.root, document) is Some(_) {
            return false
          }
        }
        let frag = @html_parser.parse_fragment(
          frag_html,
          scripting_enabled=scripting,
        )
        if policy_violation(frag.root, fragment) is Some(_) {
          return false
        }
      }
      true
    },
    count=800,
    seed=20260911,
  )
}

///|
test "property: sanitizing is idempotent" {
  @qc.check(
    (input : MarkupFuzz) => {
      let src = input.source()
      let model = default_policy_model()
      let once = @html_parser.parse_fragment(src, sanitize=true).root
      let once_html = @html_parser.to_html(once, pretty=false)
      // On the tree itself: a second pass finds nothing left to remove.
      let twice = sanitized_copy(once, model)
      if @html_parser.to_html(twice, pretty=false) != once_html {
        return false
      }
      // And on the markup a caller stores: sanitizing the sanitized HTML again
      // changes nothing beyond what reparsing it does anyway (a serialized
      // carriage return, say, reparses as a line feed).
      let reparsed = @html_parser.parse_fragment(once_html).to_html(
        pretty=false,
      )
      let again = @html_parser.parse_fragment(once_html, sanitize=true)
      again.to_html(pretty=false) == reparsed
    },
    count=1000,
    seed=20260912,
  )
}

///|
/// The text the documented unwrap policy keeps from `node`: everything but
/// comments, dropped-content elements, foreign subtrees, and invisible
/// characters.
fn expected_unwrapped_text(
  node : @dom.Node,
  model : PolicyModel,
  out : StringBuilder,
) -> Unit {
  match node.kind() {
    Text =>
      // `text()` rather than `data()`: the parser keeps the source of a tag
      // cut off by EOF as a hidden text node that only `Escape` handling
      // reveals, and which is not part of the document's text.
      for ch in node.text() {
        if !(model.strip_invisible && is_documented_invisible(ch)) {
          out.write_char(ch)
        }
      }
    Comment | Doctype => ()
    Element => {
      let tag = node.name().to_lower()
      if !(node.namespace_uri() is (None | Some("html"))) ||
        tag is ("svg" | "math") ||
        model.drop_content.contains(tag) {
        return
      }
      if node.template_content() is Some(content) {
        expected_unwrapped_text(content, model, out)
      }
      for child in node.children() {
        expected_unwrapped_text(child, model, out)
      }
    }
    Document | Fragment => {
      if node.template_content() is Some(content) {
        expected_unwrapped_text(content, model, out)
      }
      for child in node.children() {
        expected_unwrapped_text(child, model, out)
      }
    }
  }
}

///|
test "property: unwrapping keeps exactly the text outside dropped content" {
  // The default policy unwraps disallowed elements "so their text survives";
  // only script and style content, foreign content and invisible characters
  // go.
  @qc.check(
    (input : MarkupFuzz) => {
      let model = default_policy_model()
      let parsed = @html_parser.parse_fragment(input.source()).root
      let expected = StringBuilder()
      expected_unwrapped_text(parsed, model, expected)
      sanitized_copy(parsed, model).text() == expected.to_string()
    },
    count=1000,
    seed=20260913,
  )
}

///|
/// Return whether `small` is a subsequence of `large`.
fn is_subsequence(small : String, large : String) -> Bool {
  let wanted = small.to_array()
  let mut index = 0
  for ch in large {
    if index < wanted.length() && wanted[index] == ch {
      index += 1
    }
  }
  index == wanted.length()
}

///|
/// A random sanitization policy.
struct RandomPolicy {
  model : PolicyModel
}

///|
impl Debug for RandomPolicy with fn to_repr(self) {
  let model = self.model
  let attrs = StringBuilder()
  for tag, names in model.attrs {
    attrs.write_string("\{tag}:[\{names.join(",")}] ")
  }
  let handling = match model.handling {
    Unwrap => "unwrap"
    Drop => "drop"
    Escape => "escape"
  }
  Repr(
    "tags=[\{model.tags.join(",")}] attrs=\{attrs} handling=\{handling} drop=[\{model.drop_content.join(",")}] comments=\{model.drop_comments} css=[\{model.css.join(",")}]",
  )
}

///|
/// Pick a random subset of `values`, each kept with probability 1/`one_in`.
fn random_subset(
  values : Array[String],
  one_in : Int,
  state : @splitmix.RandomState,
) -> Array[String] {
  let out = []
  for value in values {
    let lower = value.to_lower()
    if state.next_positive_int() % one_in == 0 && !out.contains(lower) {
      out.push(lower)
    }
  }
  out
}

///|
impl @qc.Arbitrary for RandomPolicy with fn arbitrary(_size, state) {
  let tags = random_subset(fuzz_tag_names, 3, state)
  let attrs : Map[String, Array[String]] = {
    "*": random_subset(fuzz_attr_names, 4, state),
  }
  for tag in tags {
    if state.next_positive_int() % 3 == 0 {
      attrs[tag] = random_subset(fuzz_attr_names, 3, state)
    }
  }
  let drop_content = random_subset(
    [
      "script", "style", "textarea", "title", "noscript", "iframe", "template", "select",
    ],
    2,
    state,
  )
  let css = random_subset(
    css_preset_text_names() + ["background-image", "behavior", "list-style"],
    2,
    state,
  )
  {
    model: {
      tags,
      attrs,
      handling: pick([Unwrap, Drop, Escape], state),
      drop_content,
      drop_comments: state.next_positive_int() % 2 == 0,
      drop_doctype: state.next_positive_int() % 2 == 0,
      strip_invisible: state.next_positive_int() % 2 == 0,
      css,
    },
  }
}

///|
/// The documented text-style CSS preset.
fn css_preset_text_names() -> Array[String] {
  @html_parser.css_preset_text()
}

///|
impl @shrink.Shrink for RandomPolicy with fn shrink(_self) {
  Iter::empty()
}

///|
test "property: any policy's output conforms to that policy, before and after a reparse" {
  @qc.check(
    (input : (RandomPolicy, MarkupFuzz)) => {
      let (policy, markup) = input
      let model = policy.model
      let parsed = @html_parser.parse_fragment(markup.source()).root
      let clean = sanitized_copy(parsed, model)
      if policy_violation(clean, model) is Some(_) {
        return false
      }
      // Removal modes only ever take text away.
      if model.handling is (Unwrap | Drop) &&
        !is_subsequence(clean.text(), parsed.text()) {
        return false
      }
      guard fuzz_to_html(clean) is Some(html) else { return true }
      // Only reparse when the policy keeps no element whose content the
      // tokenizer reads as text: a policy that allows `script` has asked for
      // its contents to be live.
      for tag in model.tags {
        if tag
          is ("script"
          | "style"
          | "textarea"
          | "title"
          | "xmp"
          | "iframe"
          | "noembed"
          | "noframes"
          | "noscript"
          | "plaintext") {
          return true
        }
      }
      let reparsed = @html_parser.parse_fragment(html).root
      policy_violation(reparsed, { ..model, tags: model.tags + ["tbody"], })
      is None
    },
    count=1500,
    seed=20260914,
    counterexample_context=input => {
      let (policy, markup) = input
      try {
        let parsed = @html_parser.parse_fragment(markup.source()).root
        let clean = sanitized_copy(parsed, policy.model)
        let violation = policy_violation(clean, policy.model)
        let html = fuzz_to_html(clean).unwrap_or("(not serializable)")
        "violation: \{describe_violation(violation)}, html: \{html}"
      } catch {
        _ => "raised"
      }
    },
  )
}

///|
/// A node of generated markup that the default policy fully allows.
enum SafeNode {
  SafeText(String)
  SafeElement(String, Array[(String, String)], Array[SafeNode])
  SafeVoid(String, Array[(String, String)])
}

///|
/// Generated markup made only of what the default policy allows, well nested
/// so the tree builder keeps it as written.
struct SafeDoc {
  blocks : Array[SafeNode]
}

///|
/// Text runs without invisible characters, carriage returns or NUL, and with
/// the characters escaping has to handle.
let safe_text_runs : Array[String] = [
  "a", "hello world", "&", "<", ">", "\"", "'", "x&y", "a<b", "\u{00A0}", "\u{4F60}\u{597D}",
  "\u{1F600}", "caf\u{00E9}", " ", "&amp;",
]

///|
/// Values for the global attributes.
let safe_global_values : Array[String] = [
  "x", "two words", "with\"quote", "a&b", "a<b>", "\u{4F60}", "rtl", "en-US",
]

///|
/// Anchor targets the default URL policy keeps unchanged.
let safe_hrefs : Array[String] = [
  "http://example.com/", "https://example.com/a?b=c&d=e#f", "mailto:a@example.com",
  "tel:+123", "/relative/path", "relative.html", "?query=1", "#fragment", "HTTPS://EXAMPLE.COM/",
]

///|
/// Image sources the default URL policy keeps unchanged: relative only.
let safe_srcs : Array[String] = ["x.png", "/images/a.png", "../b.gif", "?v=1"]

///|
fn safe_global_attrs(state : @splitmix.RandomState) -> Array[(String, String)] {
  let out = []
  for name in ["class", "id", "title", "lang", "dir"] {
    if state.next_positive_int() % 5 == 0 {
      out.push((name, pick(safe_global_values, state)))
    }
  }
  out
}

///|
fn safe_inline(
  budget : Int,
  in_anchor : Bool,
  state : @splitmix.RandomState,
) -> SafeNode {
  if budget <= 0 || state.next_positive_int() % 3 == 0 {
    return SafeText(pick(safe_text_runs, state))
  }
  match state.next_positive_int() % 8 {
    0 => SafeVoid("br", [])
    1 => {
      let attrs = safe_global_attrs(state)
      attrs.push(("src", pick(safe_srcs, state)))
      if state.next_positive_int() % 2 == 0 {
        attrs.push(("alt", pick(safe_global_values, state)))
      }
      if state.next_positive_int() % 3 == 0 {
        attrs.push(("width", "10"))
      }
      SafeVoid("img", attrs)
    }
    2 if !in_anchor => {
      let attrs = safe_global_attrs(state)
      attrs.push(("href", pick(safe_hrefs, state)))
      SafeElement("a", attrs, safe_inline_children(budget - 1, true, state))
    }
    _ => {
      let name = pick(
        [
          "b", "strong", "i", "em", "u", "s", "sub", "sup", "small", "mark", "code",
          "span",
        ],
        state,
      )
      SafeElement(
        name,
        safe_global_attrs(state),
        safe_inline_children(budget - 1, in_anchor, state),
      )
    }
  }
}

///|
fn safe_inline_children(
  budget : Int,
  in_anchor : Bool,
  state : @splitmix.RandomState,
) -> Array[SafeNode] {
  let count = state.next_positive_int() % 3 + 1
  let out = []
  for _ in 0..<count {
    out.push(safe_inline(budget, in_anchor, state))
  }
  out
}

///|
fn safe_flow(budget : Int, state : @splitmix.RandomState) -> SafeNode {
  if budget <= 0 {
    return safe_inline(0, false, state)
  }
  match state.next_positive_int() % 9 {
    0 =>
      SafeElement(
        "p",
        safe_global_attrs(state),
        safe_inline_children(budget - 1, false, state),
      )
    1 =>
      SafeElement(
        "div",
        safe_global_attrs(state),
        safe_flow_children(budget - 1, state),
      )
    2 => SafeElement("blockquote", [], safe_flow_children(budget - 1, state))
    3 => {
      let items = []
      for _ in 0..<(state.next_positive_int() % 3 + 1) {
        items.push(
          SafeElement(
            "li",
            safe_global_attrs(state),
            safe_flow_children(budget - 1, state),
          ),
        )
      }
      SafeElement(pick(["ul", "ol"], state), [], items)
    }
    4 => {
      let cell_attrs = if state.next_positive_int() % 3 == 0 {
        [("colspan", "2")]
      } else {
        []
      }
      let cell = SafeElement(
        pick(["td", "th"], state),
        cell_attrs,
        safe_flow_children(budget - 1, state),
      )
      let rows = [SafeElement("tr", [], [cell])]
      let sections = [SafeElement("tbody", [], rows)]
      if state.next_positive_int() % 2 == 0 {
        sections.insert(
          0,
          SafeElement(
            "caption",
            [],
            safe_inline_children(budget - 1, false, state),
          ),
        )
      }
      SafeElement("table", safe_global_attrs(state), sections)
    }
    5 =>
      SafeElement(
        pick(["h1", "h2", "h3", "h6"], state),
        safe_global_attrs(state),
        safe_inline_children(budget - 1, false, state),
      )
    6 => SafeVoid("hr", safe_global_attrs(state))
    _ => safe_inline(budget - 1, false, state)
  }
}

///|
fn safe_flow_children(
  budget : Int,
  state : @splitmix.RandomState,
) -> Array[SafeNode] {
  let count = state.next_positive_int() % 3 + 1
  let out = []
  for _ in 0..<count {
    out.push(safe_flow(budget, state))
  }
  out
}

///|
fn SafeNode::render(self : SafeNode, out : StringBuilder) -> Unit {
  match self {
    SafeText(text) => out.write_string(escape_document_text(text))
    SafeVoid(name, attrs) => {
      out <+ "<\{name}"
      for attr in attrs {
        out <+ " \{attr.0}=\"\{escape_document_attr(attr.1)}\""
      }
      out.write_char('>')
    }
    SafeElement(name, attrs, children) => {
      out <+ "<\{name}"
      for attr in attrs {
        out <+ " \{attr.0}=\"\{escape_document_attr(attr.1)}\""
      }
      out.write_char('>')
      for child in children {
        child.render(out)
      }
      out <+ "</\{name}>"
    }
  }
}

///|
fn SafeDoc::source(self : SafeDoc) -> String {
  let out = StringBuilder()
  for node in self.blocks {
    node.render(out)
  }
  out.to_string()
}

///|
impl Debug for SafeDoc with fn to_repr(self) {
  Repr(self.source())
}

///|
impl @qc.Arbitrary for SafeDoc with fn arbitrary(size, state) {
  let budget = 1 + size % 4
  { blocks: safe_flow_children(budget, state), }
}

///|
impl @shrink.Shrink for SafeDoc with fn shrink(self) {
  let length = self.blocks.length()
  let candidates = []
  if length > 1 {
    for skip in 0..<length {
      let rest = []
      for index, node in self.blocks {
        if index != skip {
          rest.push(node)
        }
      }
      candidates.push({ blocks: rest, })
    }
  }
  candidates.iter()
}

///|
test "property: the sanitizer leaves already-safe markup unchanged" {
  // Markup made only of allowed tags, attributes and URLs has nothing to
  // remove, so sanitizing must preserve it exactly — its text included.
  @qc.check(
    (input : SafeDoc) => {
      let src = input.source()
      let plain = @html_parser.parse_fragment(src)
      let clean = @html_parser.parse_fragment(src, sanitize=true)
      plain.to_html(pretty=false) == clean.to_html(pretty=false) &&
      plain.root.text() == clean.root.text()
    },
    count=1500,
    seed=20260915,
    observe=input => {
      let src = input.source()
      [
        @qc.classify(src.contains("<a "), "anchor"),
        @qc.classify(src.contains("<img"), "image"),
        @qc.classify(src.contains("<table"), "table"),
        @qc.classify(src.contains("<li"), "list"),
        @qc.classify(
          src.contains("&amp;") || src.contains("&lt;"),
          "escaped text",
        ),
        @qc.classify(src.contains("&quot;"), "escaped attribute"),
      ]
    },
  )
}

///|
/// A generated inline style value.
struct StyleValue {
  declarations : Array[String]
}

///|
fn StyleValue::value(self : StyleValue) -> String {
  self.declarations.join(";")
}

///|
impl Debug for StyleValue with fn to_repr(self) {
  Repr(self.value())
}

///|
/// Declaration pieces: allowed and disallowed properties, and values that try
/// to load a resource through every spelling the CSS tokenizer accepts.
let style_properties : Array[String] = [
  "color", "COLOR", "font-size", "background-color", "text-align", "background-image",
  "background", "behavior", "-moz-binding", "list-style", "content", "col\\6f r",
  "c/**/olor",
]

///|
let style_values : Array[String] = [
  "red", "#fff", "12px", "rgb(1, 2, 3)", "url(http://x/y)", "URL(javascript:alert(1))",
  "u\\72l(x)", "\\75rl(x)", "url (x)", "u/**/rl(x)", "expression(alert(1))", "image-set(\"x.png\" 1x)",
  "-webkit-image-set(url(x) 1x)", "image(\"x.png\")", "src(\"x\")", "red !important",
  "red /* url(x) */", "\"url(x)\"", "@import 'x'", "var(--x)", "red\\;background:url(x)",
  "",
]

///|
impl @qc.Arbitrary for StyleValue with fn arbitrary(size, state) {
  let count = state.next_positive_int() % (size % 4 + 1) + 1
  let declarations = []
  for _ in 0..<count {
    let separator = pick([":", ": ", " : ", ""], state)
    declarations.push(
      "\{pick(style_properties, state)}\{separator}\{pick(style_values, state)}",
    )
  }
  { declarations, }
}

///|
impl @shrink.Shrink for StyleValue with fn shrink(self) {
  let candidates = []
  if self.declarations.length() > 1 {
    for skip in 0..<self.declarations.length() {
      let rest = []
      for index, declaration in self.declarations {
        if index != skip {
          rest.push(declaration)
        }
      }
      candidates.push({ declarations: rest, })
    }
  }
  candidates.iter()
}

///|
test "property: inline styles keep only allowed declarations that load nothing" {
  let model = {
    ..default_policy_model(),
    attrs: { "*": ["style"] },
    css: @html_parser.css_preset_text(),
  }
  @qc.check(
    (input : StyleValue) => {
      let value = input.value()
      let node = @html_parser.element("span", attrs={ "style": Some(value) })
      let clean = sanitized_copy(@html_parser.fragment(children=[node]), model)
      // Checked on the tree and again after a reparse of the output.
      guard policy_violation(clean, model) is None else { return false }
      let html = @html_parser.to_html(clean, pretty=false)
      policy_violation(@html_parser.parse_fragment(html).root, model) is None
    },
    count=2000,
    seed=20260916,
    observe=input => {
      let value = input.value()
      let node = @html_parser.element("span", attrs={ "style": Some(value) })
      let kept = sanitized_copy(@html_parser.fragment(children=[node]), model) catch {
        _ => return []
      }
      let has_style = collect_elements(kept)
        .iter()
        .any(element => element.attrs().contains("style"))
      [@qc.classify(has_style, "some declaration kept")]
    },
  )
}
