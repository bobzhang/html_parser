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
    SelectorLimits(),
  )
  assert_eq(text_root.data, "x")
  ignore(
    apply_transform(
      @dom.fragment(children=[@dom.element("p")]),
      TransformSpec::prune_empty("p"),
      SelectorLimits(),
    ),
  )
  ignore(
    apply_transform(
      @dom.fragment(children=[@dom.element("p")]),
      TransformSpec::stage([TransformSpec::drop("p")]),
      SelectorLimits(),
    ),
  )
  assert_true(
    decide_transform_action(
      @dom.element("p"),
      make_transform_spec(DecideNode, true),
    )
    is Keep,
  )
  apply_edit_document_transform(
    @dom.fragment(),
    make_transform_spec(EditDocumentRoot, true),
  )
  apply_edit_transform(
    @dom.element("p"),
    make_transform_spec(EditElement, true),
  )
  assert_eq(
    apply_edit_attrs_transform(
      @dom.element("p"),
      make_transform_spec(EditAttributes, true),
    ),
    false,
  )
  assert_eq(
    apply_set_attrs_transform(
      @dom.element("p"),
      make_transform_spec(SetAttributes, true),
    ),
    false,
  )
  let mixed = @dom.fragment(children=[@dom.text("x")])
  apply_drop_kind_transform(mixed, Text, TransformSpec::drop_comments())
  assert_eq(mixed.children.length(), 0)
  let unmatched_kind = @dom.fragment(children=[@dom.element("p")])
  transform_children(
    unmatched_kind,
    make_transform_spec(SanitizeTree, true, selector="p"),
    SelectorLimits(),
  )
  assert_eq(unmatched_kind.children.length(), 1)
}
