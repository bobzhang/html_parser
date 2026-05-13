///|
/// Apply transforms to a DOM tree in order.
///
/// The transform mutates and returns `node`.
pub fn apply_transforms(
  node : Node,
  transforms : Array[TransformSpec],
) -> Node raise HtmlError {
  @tr.apply_transforms(node, transforms)
}
