///|
/// Observer callbacks for sanitizer-driven DOM rewrites.
///
/// The node hook runs for events that have an associated DOM node. The report
/// callback receives every sanitizer event message and the optional related
/// node, including unsafe input that was stripped or collected.
pub struct SanitizeTransformObserver {
  priv hook : ((@dom.Node) -> Unit)?
  priv report_callback : ((String, @dom.Node?) -> Unit)?
}

///|
/// Construct sanitizer observer callbacks.
///
/// Pass `None` for either callback to observe only reports or only affected
/// nodes. Both callbacks are best-effort notifications; they do not change the
/// sanitizer decision.
pub fn SanitizeTransformObserver::SanitizeTransformObserver(
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
