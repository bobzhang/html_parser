///|
fn node_is_sanitize_container(node : @dom.Node) -> Bool {
  node.kind is (Document | Fragment)
}

///|
/// What to do in the enclosing frame once a frame's children are exhausted.
///
/// Each variant mirrors the code that ran after a recursive call returned in
/// the former recursive formulation of `sanitize_container_children`, so the
/// explicit stack replays exactly the same sequence of mutations, observer
/// callbacks, and unsafe-input reports.
priv enum SanitizeResume {
  /// Advance the enclosing index by one.
  Advance
  /// The allowed element's children are done: sanitize its template contents
  /// (read when this runs), then advance the enclosing index by one.
  TemplateThenAdvance(@dom.Node)
  /// Hoist the disallowed element's sanitized children into the enclosing
  /// node and skip over them.
  Unwrap
  /// Replace the disallowed element with escaped tag text around its
  /// sanitized children and skip over them. The tag text is computed before
  /// the children are sanitized.
  Escape(child~ : @dom.Node, start_tag~ : String, end_tag~ : String?)
}

///|
/// One pending activation of the container-children walk.
priv struct SanitizeFrame {
  node : @dom.Node
  mut index : Int
  on_done : SanitizeResume
  /// Cached `node_is_effectively_foreign(node)` once computed.
  mut foreign : Bool?
}

///|
fn SanitizeFrame::new(
  node : @dom.Node,
  on_done : SanitizeResume,
) -> SanitizeFrame {
  { node, index: 0, on_done, foreign: None, }
}

///|
/// One step of `node_is_effectively_foreign`: whether `node` itself makes it
/// and its descendants effectively foreign.
fn sanitize_node_is_self_foreign(node : @dom.Node) -> Bool {
  sanitize_namespace_is_foreign(node) ||
  (node.kind is Element && sanitize_node_name(node) is ("math" | "svg"))
}

///|
/// Compute `node_is_effectively_foreign(node)` using per-frame caches.
///
/// The walk follows `parent` pointers exactly like `node_is_effectively_foreign`
/// but stops at the first ancestor that is an active frame node with a cached
/// answer. Frame nodes passed on the way are cached with the result: all of
/// them sit below the first self-foreign node (or the chain end), so their
/// answer equals `node`'s. This keeps the check amortized O(1) per element
/// instead of O(depth), which made deep trees quadratic.
///
/// The cache is sound because the sanitizer never changes the ancestor chain,
/// names, namespaces, or kinds of active frame nodes: it only rewrites the
/// children of the frame being scanned and the subtree below it. It assumes
/// observer and URL-filter callbacks do not reparent or rename those
/// ancestors mid-walk.
fn sanitize_frames_effectively_foreign(
  stack : Array[SanitizeFrame],
  node : @dom.Node,
) -> Bool {
  let mut current = node
  let mut candidate = stack.length() - 1
  let passed : Array[SanitizeFrame] = []
  let mut result = false
  while true {
    if candidate >= 0 && physical_equal(current, stack[candidate].node) {
      let frame = stack[candidate]
      if frame.foreign is Some(cached) {
        result = cached
        break
      }
      passed.push(frame)
      candidate -= 1
    }
    if sanitize_node_is_self_foreign(current) {
      result = true
      break
    }
    match current.parent {
      Some(parent) => current = parent
      None => break
    }
  }
  for frame in passed {
    frame.foreign = Some(result)
  }
  result
}

///|
/// Replace `old_child` with the freshly created, detached node `fresh`.
///
/// Equivalent to `ignore(parent.replace_child(fresh, old_child))` for a fresh
/// node, minus the ancestor-cycle walk (a fresh node is never an ancestor of
/// `parent`), which costs O(depth) per call.
fn replace_child_with_fresh_node(
  parent : @dom.Node,
  fresh : @dom.Node,
  old_child : @dom.Node,
) -> Unit {
  guard parent.kind is (Document | Fragment | Element) else { return }
  for index, child in parent.children {
    if physical_equal(child, old_child) {
      parent.children[index] = fresh
      fresh.parent = Some(parent)
      if old_child.parent is Some(current_parent) &&
        physical_equal(current_parent, parent) {
        old_child.parent = None
      }
      return
    }
  }
}

///|
/// Sanitize the children of `root` (and their subtrees) in place.
///
/// The walk uses an explicit heap-allocated stack of frames instead of
/// recursion so arbitrarily deep trees cannot overflow the call stack. Each
/// frame is one activation of the former recursive procedure: it scans its
/// node's children by index, and when they are exhausted the frame's `on_done`
/// action runs in the enclosing frame, exactly where the recursive call used
/// to return.
fn sanitize_container_children(
  root : @dom.Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Unit raise @core.HtmlError {
  let stack : Array[SanitizeFrame] = [SanitizeFrame::new(root, Advance)]
  while stack.last() is Some(frame) {
    let parent = frame.node
    let index = frame.index
    if index >= parent.children.length() {
      ignore(stack.pop())
      guard stack.last() is Some(outer) else { break }
      match frame.on_done {
        Advance => outer.index += 1
        TemplateThenAdvance(element) =>
          match element.template_contents {
            Some(contents) => stack.push(SanitizeFrame::new(contents, Advance))
            None => outer.index += 1
          }
        Unwrap => outer.index += unwrap_child_at(outer.node, outer.index)
        Escape(child~, start_tag~, end_tag~) =>
          outer.index += finish_escape_child_at(
            outer.node,
            outer.index,
            child,
            start_tag,
            end_tag,
            policy,
          )
      }
      continue
    }
    let child = parent.children[index]
    match child.kind {
      Text if child.sanitize_escape_only =>
        if policy.disallowed_tag_handling == Escape {
          // Revealed as ordinary text, so it is revisited as one and gets the
          // same invisible-Unicode stripping as every other text node.
          child.sanitize_escape_only = false
        } else {
          remove_child_at(parent, index)
        }
      Text => {
        match sanitized_text_node_data(child, policy) {
          Some(stripped) => {
            sanitize_observer_event(
              observer,
              "Stripped invisible Unicode from text node",
              Some(child),
            )
            replace_child_with_fresh_node(parent, @dom.text(stripped), child)
          }
          None => ()
        }
        frame.index += 1
      }
      Comment =>
        if policy.drop_comments {
          sanitize_observer_event(observer, "Dropped comment", Some(child))
          remove_child_at(parent, index)
        } else {
          frame.index += 1
        }
      Doctype =>
        if policy.drop_doctype {
          sanitize_observer_event(observer, "Dropped doctype", Some(child))
          remove_child_at(parent, index)
        } else {
          frame.index += 1
        }
      Element => {
        let tag_name = sanitize_node_name(child)
        if policy.drop_foreign_namespaces &&
          sanitize_frames_effectively_foreign(stack, child) {
          sanitize_report_unsafe(
            policy,
            observer,
            "Unsafe tag '\{tag_name}' (foreign namespace)",
            Some(child),
          )
          remove_child_at(parent, index)
        } else if !policy.drop_foreign_namespaces &&
          is_active_foreign_mutation_tag(tag_name) &&
          sanitize_frames_effectively_foreign(stack, child) {
          sanitize_report_unsafe(
            policy,
            observer,
            "Unsafe tag '\{tag_name}' (active foreign content)",
            Some(child),
          )
          remove_child_at(parent, index)
        } else if policy.drop_content_tags.contains(tag_name) {
          sanitize_report_unsafe(
            policy,
            observer,
            "Unsafe tag '\{tag_name}' (dropped content)",
            Some(child),
          )
          remove_child_at(parent, index)
        } else if !policy.allowed_tags.contains(tag_name) {
          sanitize_report_unsafe(
            policy,
            observer,
            "Unsafe tag '\{tag_name}' (not allowed)",
            Some(child),
          )
          match policy.disallowed_tag_handling {
            Drop => remove_child_at(parent, index)
            Escape => {
              child.flatten_template_contents()
              let start_tag = sanitizer_escaped_start_tag_for(child)
              let end_tag = sanitizer_escaped_end_tag_for(child)
              stack.push(
                SanitizeFrame::new(child, Escape(child~, start_tag~, end_tag~)),
              )
            }
            Unwrap => {
              child.flatten_template_contents()
              stack.push(SanitizeFrame::new(child, Unwrap))
            }
          }
        } else {
          sanitize_element_attributes_with_foreign(
            child,
            policy,
            observer,
            sanitize_frames_effectively_foreign(stack, child),
          )
          if sanitize_foreign_text_integration_children(child, policy, observer) {
            frame.index += 1
          } else if sanitize_rawtext_element_children(child, policy, observer) {
            frame.index += 1
          } else {
            stack.push(SanitizeFrame::new(child, TemplateThenAdvance(child)))
          }
        }
      }
      Document | Fragment => stack.push(SanitizeFrame::new(child, Advance))
    }
  }
}

///|
/// Sanitize a DOM node in place and return the sanitized root.
///
/// When no policy is supplied, document roots use the document policy and other
/// roots use the fragment policy.
pub fn sanitize_dom(
  node : @dom.Node,
  policy? : SanitizationPolicy,
) -> @dom.Node raise @core.HtmlError {
  sanitize_dom_with_observer(node, policy, None)
}

///|
/// Sanitize a DOM node in place with optional observer callbacks.
///
/// When `policy` is `None`, document roots use the document policy and other
/// roots use the fragment policy. The observer is notified about sanitizer
/// rewrites and unsafe input reports. Non-document/non-fragment roots are
/// sanitized through a temporary fragment wrapper; the returned node may
/// therefore be the original node or a fragment containing surviving nodes.
pub fn sanitize_dom_with_observer(
  node : @dom.Node,
  policy : SanitizationPolicy?,
  observer : SanitizeTransformObserver?,
) -> @dom.Node raise @core.HtmlError {
  let policy = policy.unwrap_or_else(() => {
    if node.kind == Document {
      default_document_sanitization_policy()
    } else {
      default_sanitization_policy()
    }
  })
  if node_is_sanitize_container(node) {
    sanitize_container_children(node, policy, observer)
    node
  } else {
    let wrapper = @dom.fragment(children=[node])
    sanitize_container_children(wrapper, policy, observer)
    if wrapper.children.length() == 1 {
      let only = wrapper.children[0]
      ignore(wrapper.children.remove(0))
      only.parent = None
      only
    } else {
      wrapper
    }
  }
}
