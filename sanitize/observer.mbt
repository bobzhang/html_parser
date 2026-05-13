///|
pub struct SanitizeTransformObserver {
  priv hook : ((@dom.Node) -> Unit)?
  priv report_callback : ((String, @dom.Node?) -> Unit)?
}

///|
pub fn SanitizeTransformObserver::new(
  hook : ((@dom.Node) -> Unit)?,
  report_callback : ((String, @dom.Node?) -> Unit)?,
) -> SanitizeTransformObserver {
  { hook, report_callback }
}

///|
fn sanitize_observer_event(
  observer : SanitizeTransformObserver?,
  message : String,
  node : @dom.Node?,
) -> Unit {
  match observer {
    Some(observer) => {
      match (node, observer.hook) {
        (Some(node), Some(hook)) => hook(node)
        _ => ()
      }
      match observer.report_callback {
        Some(report) => report(message, node)
        None => ()
      }
    }
    None => ()
  }
}

///|
fn sanitize_report_unsafe(
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
  message : String,
  node : @dom.Node?,
) -> Unit raise @core.HtmlError {
  policy.handle_unsafe(message)
  sanitize_observer_event(observer, message, node)
}
