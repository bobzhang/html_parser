///|
fn cli_extra_allowed_tags(value : String) -> Array[String] {
  let normalized = value.replace_all(old=" ", new=",")
  let tags : Array[String] = []
  for part in normalized.split(",") {
    let tag = @syn.lower_ascii(part.trim())
    if !tag.is_empty() {
      tags.push(tag)
    }
  }
  tags
}

///|
fn cli_policy_for_options(options : CliOptions) -> @san.SanitizationPolicy? {
  match options.allow_tags {
    None => None
    Some(raw) => {
      let base = if options.fragment {
        @san.default_sanitization_policy()
      } else {
        @san.default_document_sanitization_policy()
      }
      Some(base.with_extra_allowed_tags(cli_extra_allowed_tags(raw)))
    }
  }
}

///|
fn cli_sanitize(
  root : @dom.Node,
  policy : @san.SanitizationPolicy?,
) -> Unit raise @core.HtmlError {
  match policy {
    Some(policy) => ignore(@san.sanitize_dom(root, policy~))
    None => ignore(@san.sanitize_dom(root))
  }
}

///|
fn cli_sanitize_transform(
  policy : @san.SanitizationPolicy?,
) -> @tr.TransformSpec {
  match policy {
    Some(policy) => @tr.TransformSpec::sanitize(policy~)
    None => @tr.TransformSpec::sanitize()
  }
}

///|
fn cli_cleanup_transforms(
  safe : Bool,
  policy : @san.SanitizationPolicy?,
) -> Array[@tr.TransformSpec] {
  let transforms : Array[@tr.TransformSpec] = []
  if safe {
    transforms.push(cli_sanitize_transform(policy))
  }
  transforms.push(@tr.TransformSpec::unwrap("a:not([href])"))
  transforms.push(@tr.TransformSpec::drop("img:not([src]), img[src=\"\"]"))
  transforms.push(@tr.TransformSpec::prune_empty("*"))
  transforms
}

///|
fn cli_apply_cleanup_or_error(
  root : @dom.Node,
  safe : Bool,
  policy : @san.SanitizationPolicy?,
) -> CliResult? {
  ignore(@tr.apply_transforms(root, cli_cleanup_transforms(safe, policy))) catch {
    error => return Some(cli_parse_error(cli_html_error_message(error)))
  }
  None
}

///|
fn cli_sanitize_or_error(
  root : @dom.Node,
  policy : @san.SanitizationPolicy?,
) -> CliResult? {
  cli_sanitize(root, policy) catch {
    error => return Some(cli_parse_error(cli_html_error_message(error)))
  }
  None
}
