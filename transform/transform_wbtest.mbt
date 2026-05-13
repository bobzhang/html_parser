///|
test "transform private helpers keep defensive no-op behavior" {
  assert_eq(decide_action_label(Keep), "keep")
  assert_eq(node_has_foreign_namespace(@dom.element("p")), false)
  assert_eq(node_has_foreign_namespace(@dom.text("x")), false)
  assert_eq(prune_empty_node_is_effectively_empty(@dom.text("x"), true), false)
  let text_root = @dom.text("x")
  apply_prune_empty_transform(
    text_root,
    TransformSpec::prune_empty("*"),
    @sel.SelectorLimits::new(),
  )
  assert_eq(text_root.data, "x")
  ignore(
    apply_transform(
      @dom.fragment(children=[@dom.element("p")]),
      TransformSpec::prune_empty("p"),
      @sel.SelectorLimits::new(),
    ),
  )
  ignore(
    apply_transform(
      @dom.fragment(children=[@dom.element("p")]),
      TransformSpec::stage([TransformSpec::drop("p")]),
      @sel.SelectorLimits::new(),
    ),
  )
  assert_true(
    decide_transform_action(@dom.element("p"), make_transform_spec(DecideNode))
    is Keep,
  )
  apply_edit_document_transform(
    @dom.fragment(),
    make_transform_spec(EditDocumentRoot),
  )
  apply_edit_transform(@dom.element("p"), make_transform_spec(EditElement))
  assert_eq(
    apply_edit_attrs_transform(
      @dom.element("p"),
      make_transform_spec(EditAttributes),
    ),
    false,
  )
  assert_eq(
    apply_set_attrs_transform(
      @dom.element("p"),
      make_transform_spec(SetAttributes),
    ),
    false,
  )
  let mixed = @dom.fragment(children=[@dom.text("x")])
  apply_drop_kind_transform(mixed, Text, TransformSpec::drop_comments())
  assert_eq(mixed.children.length(), 0)
  let unmatched_kind = @dom.fragment(children=[@dom.element("p")])
  transform_children(
    unmatched_kind,
    make_transform_spec(SanitizeTree, selector="p"),
    @sel.SelectorLimits::new(),
  )
  assert_eq(unmatched_kind.children.length(), 1)
}
