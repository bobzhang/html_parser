///|
pub(all) enum TagKind {
  StartTag
  EndTag
} derive(Debug, Eq)

///|
pub(all) struct TagToken {
  kind : TagKind
  name : String
  attrs : Map[String, String?]
  self_closing : Bool
} derive(Debug, Eq)

///|
pub(all) struct DoctypeInfo {
  name : String
  public_id : String?
  system_id : String?
  force_quirks : Bool
} derive(Debug, Eq)

///|
pub(all) enum HtmlToken {
  Tag(TagToken)
  Characters(String)
  CommentToken(String)
  DoctypeToken(DoctypeInfo)
  Eof
} derive(Debug, Eq)

///|
pub(all) struct TokenizedHtml {
  tokens : Array[HtmlToken]
  errors : Array[ParseError]
} derive(Debug)

///|
pub fn tokenize(
  html : StringView,
  collect_errors? : Bool = false,
) -> TokenizedHtml raise HtmlError {
  let parsed = parse_fragment(html, sanitize=false, collect_errors~)
  let tokens : Array[HtmlToken] = []
  for child in parsed.root.children {
    append_tokens_from_node(child, tokens)
  }
  tokens.push(Eof)
  TokenizedHtml::{ tokens, errors: parsed.errors }
}

///|
fn append_tokens_from_node(node : Node, tokens : Array[HtmlToken]) -> Unit {
  match node.kind {
    Document | Fragment =>
      for child in node.children {
        append_tokens_from_node(child, tokens)
      }
    Element => {
      tokens.push(
        Tag(TagToken::{
          kind: StartTag,
          name: node.name,
          attrs: node.attrs.copy(),
          self_closing: is_void_element(node.name),
        }),
      )
      for child in node.children {
        append_tokens_from_node(child, tokens)
      }
      if !is_void_element(node.name) {
        tokens.push(
          Tag(TagToken::{
            kind: EndTag,
            name: node.name,
            attrs: {},
            self_closing: false,
          }),
        )
      }
    }
    Text => tokens.push(Characters(node.data))
    Comment => tokens.push(CommentToken(node.data))
    Doctype =>
      tokens.push(
        DoctypeToken(DoctypeInfo::{
          name: node.data,
          public_id: node.public_id,
          system_id: node.system_id,
          force_quirks: node.force_quirks,
        }),
      )
  }
}
