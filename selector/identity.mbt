///|
fn node_identity_seen(nodes : Array[@dom.Node], node : @dom.Node) -> Bool {
  for seen in nodes {
    if physical_equal(seen, node) {
      return true
    }
  }
  false
}
