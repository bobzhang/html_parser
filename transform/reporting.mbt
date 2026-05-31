///|
fn transform_call_hook(node : @dom.Node, transform : TransformSpec) -> Unit {
  match transform.node_hook {
    Some(hook) => (hook.callback)(node)
    None => ()
  }
}

///|
fn sanitize_transform_observer(
  transform : TransformSpec,
) -> @san.SanitizeTransformObserver? {
  match (transform.node_hook, transform.report_callback) {
    (None, None) => None
    _ => {
      let hook = transform.node_hook.map(fn(hook) {
        fn(node) { (hook.callback)(node) }
      })
      let report_callback = transform.report_callback.map(fn(report) {
        fn(message, node) { (report.callback)(message, node) }
      })
      Some(SanitizeTransformObserver(hook, report_callback))
    }
  }
}

///|
fn transform_report(
  transform : TransformSpec,
  message : String,
  node : @dom.Node?,
) -> Unit {
  match transform.report_callback {
    Some(report) => (report.callback)(message, node)
    None => ()
  }
}

///|
fn transform_report_node_action(
  node : @dom.Node,
  transform : TransformSpec,
  action : StringView,
) -> Unit {
  transform_call_hook(node, transform)
  let tag = @syn.lower_ascii(node.name)
  transform_report(
    transform,
    "\{action.to_owned()} <\{tag}> (matched selector '\{transform.selector}')",
    Some(node),
  )
}
