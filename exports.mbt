///|
pub using @cl {type CliReadPlan, type CliResult}

///|
pub using @core {type HtmlError, type ParseError}

///|
pub using @dom {type Node, type NodeKind}

///|
pub using @link {type LinkifyConfig, type LinkMatch}

///|
pub using @p {type FragmentContext, type ParsedHtml}

///|
pub using @san {
  type DisallowedTagHandling,
  type SanitizationPolicy,
  type SanitizeTransformObserver,
  type UnsafeHandling,
  type UrlFilter,
  type UrlHandling,
  type UrlPolicy,
  type UrlPolicyRule,
  type UrlProxy,
  type UrlRule,
}

///|
pub using @sel {type SelectorLimits}

///|
pub using @ser {type HtmlContext}

///|
pub using @stream {
  type StreamDoctypeEvent,
  type StreamEvent,
  type StreamStartEvent,
}

///|
pub using @tok {
  type DoctypeInfo,
  type HtmlToken,
  type TagKind,
  type TagToken,
  type TokenizedHtml,
}

///|
pub using @tr {type DecideAction, type TransformSpec}
