///|
fn node_identity_seen(nodes : Array[@dom.Node], node : @dom.Node) -> Bool {
  nodes.any(seen => physical_equal(seen, node))
}
