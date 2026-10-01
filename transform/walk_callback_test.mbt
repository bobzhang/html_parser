// Exact tests for transform walks whose callbacks mutate the tree while it
// is being walked: edits that remove the current child, insert siblings or
// replace template contents, hooks that mutate during unwrap, decide actions
// after tree edits, template-first ordering, post-order pruning, and linkify
// with skip tags and template contents. The snapshots pin both the resulting
// tree and the exact callback order, so they double as a behaviour check of
// the explicit-stack walks against the former recursive ones.

///|
fn wc_el(name : String, id : String, children : Array[@dom.Node]) -> @dom.Node {
  let attrs : Map[String, String?] = if id == "" {
    Map([])
  } else {
    { "id": Some(id) }
  }
  @dom.element(name, attrs~, children~)
}

///|
fn wc_t(data : String) -> @dom.Node {
  @dom.text(data)
}

///|
/// A template element with template `contents` and also regular `children`.
/// `append_child` on a template inserts into its contents, so the regular
/// children are attached directly.
fn wc_template(
  id : String,
  children : Array[@dom.Node],
  contents : Array[@dom.Node],
) -> @dom.Node {
  let template = wc_el("template", id, contents)
  for child in children {
    child.parent = Some(template)
    template.children.push(child)
  }
  template
}

///|
fn wc_id(node : @dom.Node) -> String {
  match node.attrs.get("id") {
    Some(Some(id)) => id
    _ => ""
  }
}

///|
fn wc_label(node : @dom.Node) -> String {
  match node.kind {
    Text => "'\{node.data}'"
    Comment => "<!--\{node.data}-->"
    Doctype => "<!doctype>"
    Document => "#document"
    Fragment => "#fragment"
    Element => {
      let prefix = match node.ns {
        Some(ns) if ns != "html" => ns + ":"
        _ => ""
      }
      let id = wc_id(node)
      if id == "" {
        prefix + node.name
      } else {
        "\{prefix}\{node.name}#\{id}"
      }
    }
  }
}

///|
/// Compact structural dump: `label(attrs){template contents}[children]`.
fn wc_dump(node : @dom.Node) -> String {
  let out = StringBuilder()
  out.write_string(wc_label(node))
  let attrs : Array[String] = []
  for name, value in node.attrs {
    if name != "id" {
      let value = value.unwrap_or("")
      attrs.push("\{name}=\{value}")
    }
  }
  if !attrs.is_empty() {
    out.write_string("(\{attrs.join(",")})")
  }
  if node.template_contents is Some(contents) {
    out.write_string("{\{contents.children.map(wc_dump).join(",")}}")
  }
  if !node.children.is_empty() {
    out.write_string("[\{node.children.map(wc_dump).join(",")}]")
  }
  out.to_string()
}

///|
test "edit callbacks that remove, insert and replace children" {
  let log : Array[String] = []
  let inserted = Ref(false)
  let root = @dom.fragment(children=[
    wc_el("div", "1", [
      wc_el("span", "a", [wc_t("x")]),
      wc_el("span", "b", [wc_el("span", "b1", [])]),
      wc_el("span", "c", [wc_t("z")]),
    ]),
    wc_el("p", "2", [wc_el("span", "d", [])]),
  ])
  let out = @transform.apply_transforms(root, [
    @transform.TransformSpec::edit(
      "span",
      node => {
        log.push("edit " + wc_label(node))
        match node.parent {
          Some(parent) =>
            match wc_id(node) {
              "a" =>
                if !inserted.val {
                  inserted.val = true
                  parent.insert_before(
                    wc_el("span", "new", [wc_el("span", "new1", [])]),
                    Some(node),
                  )
                }
              "b" => parent.remove_child(node)
              "c" => parent.append_child(wc_el("span", "e", []))
              "d" =>
                ignore(
                  parent.replace_child(
                    wc_el("span", "f", [wc_el("span", "g", [])]),
                    node,
                  ),
                )
              _ => ()
            }
          None => ()
        }
      },
      hook=node => log.push("hook " + wc_label(node)),
      report=(message, _) => log.push("report " + message),
    ),
  ])
  debug_inspect(
    log,
    content=(
      #|[
      #|  "hook span#a",
      #|  "report Edited <span> (matched selector 'span')",
      #|  "edit span#a",
      #|  "hook span#new",
      #|  "report Edited <span> (matched selector 'span')",
      #|  "edit span#new",
      #|  "hook span#new1",
      #|  "report Edited <span> (matched selector 'span')",
      #|  "edit span#new1",
      #|  "hook span#a",
      #|  "report Edited <span> (matched selector 'span')",
      #|  "edit span#a",
      #|  "hook span#b",
      #|  "report Edited <span> (matched selector 'span')",
      #|  "edit span#b",
      #|  "hook span#c",
      #|  "report Edited <span> (matched selector 'span')",
      #|  "edit span#c",
      #|  "hook span#e",
      #|  "report Edited <span> (matched selector 'span')",
      #|  "edit span#e",
      #|  "hook span#d",
      #|  "report Edited <span> (matched selector 'span')",
      #|  "edit span#d",
      #|  "hook span#f",
      #|  "report Edited <span> (matched selector 'span')",
      #|  "edit span#f",
      #|  "hook span#g",
      #|  "report Edited <span> (matched selector 'span')",
      #|  "edit span#g",
      #|]
    ),
  )
  inspect(
    wc_dump(out),
    content=(
      #|#fragment[div#1[span#new[span#new1],span#a['x'],span#c['z'],span#e],p#2[span#f[span#g]]]
    ),
  )
}

///|
test "edit_attrs callbacks that mutate siblings and template contents" {
  let log : Array[String] = []
  let root = @dom.fragment(children=[
    wc_el("p", "a", [wc_el("b", "a1", [])]),
    wc_el("p", "victim", []),
    wc_el("p", "b", [wc_el("b", "b1", [])]),
    wc_el("p", "c", []),
    wc_template("t", [wc_el("i", "t-child", [])], [
      wc_el("i", "old-content", []),
    ]),
    wc_el("p", "d", []),
  ])
  let out = @transform.apply_transforms(root, [
    @transform.TransformSpec::edit_attrs(
      "*",
      node => {
        log.push("edit_attrs " + wc_label(node))
        guard node.parent is Some(parent) else { None }
        match wc_id(node) {
          "a" => {
            // Remove the next sibling before the walk reaches it.
            parent.remove_child(parent.children[1])
            Some({ "seen": Some("a") })
          }
          "b" => {
            // Detach the current element: its subtree is not walked.
            parent.remove_child(node)
            Some({ "seen": Some("b") })
          }
          "c" => {
            // Children added now are walked after the callback.
            node.append_child(wc_el("i", "c-child", []))
            None
          }
          "t" => {
            // Replaced template contents are the ones that get walked.
            node.template_contents = Some(
              @dom.fragment(children=[wc_el("i", "new-content", [])]),
            )
            None
          }
          _ => None
        }
      },
      report=(message, _) => log.push("report " + message),
    ),
  ])
  debug_inspect(
    log,
    content=(
      #|[
      #|  "edit_attrs p#a",
      #|  "report Edited attributes on <p> (matched selector '*')",
      #|  "edit_attrs b#a1",
      #|  "edit_attrs p#b",
      #|  "report Edited attributes on <p> (matched selector '*')",
      #|  "edit_attrs p#c",
      #|  "edit_attrs i#c-child",
      #|  "edit_attrs template#t",
      #|  "edit_attrs i#new-content",
      #|  "edit_attrs i#t-child",
      #|  "edit_attrs p#d",
      #|]
    ),
  )
  inspect(
    wc_dump(out),
    content=(
      #|#fragment[p(seen=a)[b#a1],p#c[i#c-child],template#t{i#new-content}[i#t-child],p#d]
    ),
  )
}

///|
test "hooks that mutate the tree during unwrap" {
  let log : Array[String] = []
  // Unwrapping `outer` hoists s1, s2 and s3; the hook for `inner` (reached
  // while walking the hoisted s1) removes s2 from the root, so the walk of
  // the hoisted range moves on to s3 and then to `after`.
  let root = @dom.fragment(children=[
    wc_el("b", "outer", [
      wc_el("span", "s1", [wc_el("b", "inner", [wc_t("i")])]),
      wc_el("span", "s2", [wc_el("b", "x", [wc_t("2")])]),
      wc_el("span", "s3", [wc_t("3")]),
    ]),
    wc_el("span", "after", [wc_el("b", "y", [wc_t("4")])]),
    wc_el("b", "grow", [wc_t("g")]),
    wc_template("t", [wc_el("b", "t-child", [])], [
      wc_el("b", "t-content", [wc_el("b", "t-deep", [])]),
    ]),
  ])
  let out = @transform.apply_transforms(root, [
    @transform.TransformSpec::unwrap(
      "b, template",
      hook=node => {
        log.push("hook " + wc_label(node))
        match wc_id(node) {
          "inner" =>
            match node.parent.bind(parent => parent.parent) {
              Some(top) => top.remove_child(top.children[1])
              None => ()
            }
          // Children appended by the hook are hoisted with the others.
          "grow" => node.append_child(wc_el("b", "grown", [wc_t("h")]))
          _ => ()
        }
      },
      report=(message, _) => log.push("report " + message),
    ),
  ])
  debug_inspect(
    log,
    content=(
      #|[
      #|  "hook b#outer",
      #|  "report Unwrapped <b> (matched selector 'b, template')",
      #|  "hook b#inner",
      #|  "report Unwrapped <b> (matched selector 'b, template')",
      #|  "hook b#y",
      #|  "report Unwrapped <b> (matched selector 'b, template')",
      #|  "hook b#grow",
      #|  "report Unwrapped <b> (matched selector 'b, template')",
      #|  "hook template#t",
      #|  "report Unwrapped <template> (matched selector 'b, template')",
      #|  "hook b#t-deep",
      #|  "report Unwrapped <b> (matched selector 'b, template')",
      #|]
    ),
  )
  inspect(
    wc_dump(out),
    content=(
      #|#fragment[span#s1['i'],span#s3['3'],span#after['4'],'g',b#grown['h'],b#t-child,b#t-content]
    ),
  )
}

///|
test "selector transforms walk template contents before children" {
  let log : Array[String] = []
  let root = @dom.fragment(children=[
    wc_template(
      "t",
      [wc_el("p", "regular", [wc_el("p", "regular-inner", [])])],
      [
        wc_el("p", "content", []),
        wc_template("nested", [wc_el("p", "nested-regular", [])], [
          wc_el("p", "nested-content", []),
        ]),
      ],
    ),
    wc_el("p", "after", []),
  ])
  let report = (message : String, node : @dom.Node?) => {
    let label = match node {
      Some(node) => wc_label(node)
      None => "-"
    }
    log.push("\{message} @ \{label}")
  }
  let out = @transform.apply_transforms(root, [
    @transform.TransformSpec::set_attrs("p", { "k": Some("v") }, report~),
    @transform.TransformSpec::drop("p#nested-content", report~),
    @transform.TransformSpec::escape("p#regular-inner", report~),
    @transform.TransformSpec::empty("p#regular", report~),
  ])
  debug_inspect(
    log,
    content=(
      #|[
      #|  "Set attributes on <p> (matched selector 'p') @ p#content",
      #|  "Set attributes on <p> (matched selector 'p') @ p#nested-content",
      #|  "Set attributes on <p> (matched selector 'p') @ p#nested-regular",
      #|  "Set attributes on <p> (matched selector 'p') @ p#regular",
      #|  "Set attributes on <p> (matched selector 'p') @ p#regular-inner",
      #|  "Set attributes on <p> (matched selector 'p') @ p#after",
      #|  "Dropped <p> (matched selector 'p#nested-content') @ p#nested-content",
      #|  "Escaped <p> (matched selector 'p#regular-inner') @ p#regular-inner",
      #|  "Emptied <p> (matched selector 'p#regular') @ p#regular",
      #|]
    ),
  )
  inspect(
    wc_dump(out),
    content=(
      #|#fragment[template#t{p#content(k=v),template#nested{}[p#nested-regular(k=v)]}[p#regular(k=v)],p#after(k=v)]
    ),
  )
}

///|
test "decide actions after callbacks edit the tree" {
  let log : Array[String] = []
  let once = Ref(false)
  let root = @dom.fragment(children=[
    wc_el("p", "1", [
      wc_t("t1"),
      @dom.comment("c"),
      wc_el("b", "2", [wc_t("t2")]),
      wc_el("i", "3", []),
      wc_el("u", "4", [wc_t("t4")]),
      wc_template("5", [], [wc_el("s", "5c", [])]),
      wc_t("tail"),
    ]),
  ])
  let out = @transform.apply_transforms(root, [
    @transform.TransformSpec::decide(
      "*",
      node => {
        log.push("decide " + wc_label(node))
        match (node.kind, wc_id(node)) {
          (Comment, _) => Escape
          (Text, _) => if node.data == "tail" { Escape } else { Keep }
          (Element, "2") =>
            if once.val {
              Unwrap
            } else {
              // Insert a sibling before the current node and then drop:
              // the drop removes whatever is now at the current index.
              once.val = true
              match node.parent {
                Some(parent) =>
                  parent.insert_before(wc_el("em", "ins", []), Some(node))
                None => ()
              }
              Drop
            }
          (Element, "3") => {
            // Removing the current node and keeping it advances past the
            // node that took its place.
            match node.parent {
              Some(parent) => parent.remove_child(node)
              None => ()
            }
            Keep
          }
          (Element, "5") => Empty
          _ => Keep
        }
      },
      hook=node => log.push("hook " + wc_label(node)),
      report=(message, _) => log.push("report " + message),
    ),
  ])
  debug_inspect(
    log,
    content=(
      #|[
      #|  "decide p#1",
      #|  "decide 't1'",
      #|  "decide <!--c-->",
      #|  "hook <!--c-->",
      #|  "report Decide -> escape '#comment' (matched selector '*')",
      #|  "decide b#2",
      #|  "hook b#2",
      #|  "report Decide -> drop 'b' (matched selector '*')",
      #|  "decide b#2",
      #|  "hook b#2",
      #|  "report Decide -> unwrap 'b' (matched selector '*')",
      #|  "decide 't2'",
      #|  "decide i#3",
      #|  "decide template#5",
      #|  "hook template#5",
      #|  "report Decide -> empty 'template' (matched selector '*')",
      #|  "decide 'tail'",
      #|  "hook 'tail'",
      #|  "report Decide -> escape '#text' (matched selector '*')",
      #|]
    ),
  )
  inspect(
    wc_dump(out),
    content=(
      #|#fragment[p#1['t1','t2',u#4['t4'],template#5]]
    ),
  )
}

///|
test "node-kind and whitespace transforms visit template contents first" {
  let log : Array[String] = []
  let report = (message : String, node : @dom.Node?) => {
    let label = match node {
      Some(node) => wc_label(node)
      None => "-"
    }
    log.push("\{message} @ \{label}")
  }
  let root = @dom.fragment(children=[
    wc_template(
      "t",
      [@dom.comment("regular"), wc_t(" r  r "), wc_el("svg", "", [])],
      [
        @dom.comment("content"),
        wc_t(" c  c "),
        @dom.element("svg", ns="svg", children=[@dom.comment("in-svg")]),
        wc_el("pre", "", [wc_t(" p  p ")]),
      ],
    ),
    wc_el("pre", "", [
      wc_template("in-pre", [], [wc_t(" skipped  too ")]),
      wc_t(" kept  as is "),
    ]),
    @dom.element("math", ns="mathml", children=[wc_t("m")]),
  ])
  let out = @transform.apply_transforms(root, [
    @transform.TransformSpec::drop_comments(report~),
    @transform.TransformSpec::collapse_whitespace(report~),
    @transform.TransformSpec::drop_foreign_namespaces(report~),
  ])
  debug_inspect(
    log,
    content=(
      #|[
      #|  "Dropped comment @ <!--content-->",
      #|  "Dropped comment @ <!--in-svg-->",
      #|  "Dropped comment @ <!--regular-->",
      #|  "Collapsed whitespace in text node @ ' c  c '",
      #|  "Collapsed whitespace in text node @ ' r  r '",
      #|  "Unsafe tag 'svg' (foreign namespace) @ svg:svg",
      #|  "Unsafe tag 'math' (foreign namespace) @ math:math",
      #|]
    ),
  )
  inspect(
    wc_dump(out),
    content=(
      #|#fragment[template#t{' c c ',pre[' p  p ']}[' r r ',svg],pre[template#in-pre{' skipped  too '},' kept  as is ']]
    ),
  )
}

///|
test "prune_empty runs post-order with mutating hooks" {
  let log : Array[String] = []
  let root = @dom.fragment(children=[
    wc_el("div", "a", [
      wc_el("p", "b", [wc_el("span", "c", [wc_t("  ")]), @dom.comment("x")]),
      wc_el("p", "d", [wc_t(" ")]),
      wc_el("span", "keep", [wc_t("k")]),
    ]),
    wc_el("div", "e", [
      wc_template("t", [], [wc_el("span", "tc", [])]),
      wc_el("span", "f", []),
    ]),
    wc_el("div", "g", [wc_el("span", "h", []), wc_el("span", "i", [])]),
    wc_el("div", "j", [wc_el("span", "k", [])]),
  ])
  let out = @transform.apply_transforms(root, [
    @transform.TransformSpec::prune_empty(
      "span",
      hook=node => {
        log.push("hook span " + wc_label(node))
        match (wc_id(node), node.parent) {
          // Remove the next sibling while the current one is being pruned.
          ("h", Some(parent)) => parent.remove_child(parent.children[1])
          // Add content to the grandparent before it is checked.
          ("k", Some(parent)) => parent.append_child(wc_t("filled"))
          _ => ()
        }
      },
      report=(message, _) => log.push("report " + message),
    ),
    @transform.TransformSpec::prune_empty("p", strip_whitespace=false, report=(
      message,
      _,
    ) => log.push("report " + message)),
    @transform.TransformSpec::prune_empty("div, template", report=(message, _) => {
      log.push("report " + message)
    }),
  ])
  debug_inspect(
    log,
    content=(
      #|[
      #|  "hook span span#c",
      #|  "report Pruned empty <span> (matched selector 'span')",
      #|  "report Pruned empty <p> (matched selector 'p')",
      #|  "hook span span#tc",
      #|  "report Pruned empty <span> (matched selector 'span')",
      #|  "report Pruned empty <template> (matched selector 'div, template')",
      #|  "hook span span#f",
      #|  "report Pruned empty <span> (matched selector 'span')",
      #|  "report Pruned empty <div> (matched selector 'div, template')",
      #|  "hook span span#h",
      #|  "report Pruned empty <span> (matched selector 'span')",
      #|  "report Pruned empty <div> (matched selector 'div, template')",
      #|  "hook span span#k",
      #|  "report Pruned empty <span> (matched selector 'span')",
      #|]
    ),
  )
  inspect(
    wc_dump(out),
    content=(
      #|#fragment[div#a[p#d[' '],span#keep['k']],div#j['filled']]
    ),
  )
}

///|
test "linkify transform honours skip tags and template contents" {
  let log : Array[String] = []
  let added = Ref(false)
  let root = @dom.fragment(children=[
    wc_t("see a.com "),
    wc_el("b", "skip", [wc_t("b.com"), wc_template("in-b", [], [wc_t("c.com")])]),
    wc_template("t", [wc_t("regular d.com")], [
      wc_t("content e.com"),
      wc_el("b", "", [wc_t("f.com")]),
    ]),
    wc_el("code", "", [wc_t("g.com")]),
    wc_el("a", "", [wc_t("h.com")]),
    wc_el("p", "", [wc_t("i.com and j.com")]),
  ])
  let out = @transform.apply_transforms(root, [
    @transform.TransformSpec::linkify(
      skip_tags=["B"],
      hook=node => {
        log.push("hook " + wc_label(node))
        // Text appended to the current parent is linkified when reached.
        match node.parent {
          Some(parent) if !added.val => {
            added.val = true
            parent.append_child(wc_t(" k.com"))
          }
          _ => ()
        }
      },
      report=(message, _) => log.push("report " + message),
    ),
  ])
  debug_inspect(
    log,
    content=(
      #|[
      #|  "hook 'see a.com '",
      #|  "report Linkified 1 link(s) in text node",
      #|  "hook 'content e.com'",
      #|  "report Linkified 1 link(s) in text node",
      #|  "hook 'regular d.com'",
      #|  "report Linkified 1 link(s) in text node",
      #|  "hook 'g.com'",
      #|  "report Linkified 1 link(s) in text node",
      #|  "hook 'h.com'",
      #|  "report Linkified 1 link(s) in text node",
      #|  "hook 'i.com and j.com'",
      #|  "report Linkified 2 link(s) in text node",
      #|  "hook ' k.com'",
      #|  "report Linkified 1 link(s) in text node",
      #|]
    ),
  )
  inspect(
    wc_dump(out),
    content=(
      #|#fragment['see ',a(href=http://a.com)['a.com'],' ',b#skip['b.com',template#in-b{'c.com'}],template#t{'content ',a(href=http://e.com)['e.com'],b['f.com']}['regular ',a(href=http://d.com)['d.com']],code[a(href=http://g.com)['g.com']],a[a(href=http://h.com)['h.com']],p[a(href=http://i.com)['i.com'],' and ',a(href=http://j.com)['j.com']],' ',a(href=http://k.com)['k.com']]
    ),
  )
  // A skipped root element and a bare text root.
  let skipped = @transform.apply_transforms(
    wc_el("b", "", [wc_t("x.com"), wc_template("", [], [wc_t("y.com")])]),
    [@transform.TransformSpec::linkify(skip_tags=["b"])],
  )
  let text = @transform.apply_transforms(wc_t("z.com and w.com"), [
    @transform.TransformSpec::linkify(),
  ])
  debug_inspect(
    [wc_dump(skipped), wc_dump(text)],
    content=(
      #|[
      #|  "b['x.com',template{'y.com'}]",
      #|  "#fragment[a(href=http://z.com)['z.com'],' and ',a(href=http://w.com)['w.com']]",
      #|]
    ),
  )
}
