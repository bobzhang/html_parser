///|
fn node_identity_seen(nodes : Array[@dom.Node], node : @dom.Node) -> Bool {
  nodes.any(seen => physical_equal(seen, node))
}

///|
/// Detects where the `parent` chain `x0 = start, x1 = x0.parent, ...` first
/// revisits a node, without remembering the nodes already walked.
///
/// `repeats_at(k)` answers whether `xk` equals one of `x0 .. x(k-1)`, exactly
/// like scanning the list of nodes walked so far, but in amortised constant
/// time: Brent's cycle detection runs lazily ahead of the caller. With a tail
/// of length `mu` and a cycle of length `lambda`, the first repeated index is
/// `mu + lambda`, and Brent's search sees the cycle by hare index
/// `3 * (mu + lambda) - 1`, so advancing the hare to `3 * k` decides index `k`.
priv struct AncestorRepeatGuard {
  start : @dom.Node
  mut tortoise : @dom.Node
  mut hare : @dom.Node?
  mut hare_index : Int
  mut power : Int
  mut lambda : Int
  /// `-1` while unknown, `ancestor_chain_acyclic` when the chain ends.
  mut first_repeat : Int
}

///|
let ancestor_chain_acyclic : Int = 2147483647

///|
fn AncestorRepeatGuard::new(start : @dom.Node) -> AncestorRepeatGuard {
  {
    start,
    tortoise: start,
    hare: start.parent,
    hare_index: 1,
    power: 1,
    lambda: 1,
    first_repeat: if start.parent is None {
      ancestor_chain_acyclic
    } else {
      -1
    },
  }
}

///|
/// Index of the first node of the cycle, once its length is `self.lambda`.
fn AncestorRepeatGuard::cycle_start(self : AncestorRepeatGuard) -> Int {
  let mut behind = self.start
  let mut ahead = self.start
  for _ in 0..<self.lambda {
    guard ahead.parent is Some(next) else { return ancestor_chain_acyclic }
    ahead = next
  }
  let mut mu = 0
  while !physical_equal(behind, ahead) {
    guard behind.parent is Some(next_behind) && ahead.parent is Some(next_ahead) else {
      return ancestor_chain_acyclic
    }
    behind = next_behind
    ahead = next_ahead
    mu += 1
  }
  mu
}

///|
fn AncestorRepeatGuard::step(self : AncestorRepeatGuard) -> Unit {
  guard self.hare is Some(hare) else {
    self.first_repeat = ancestor_chain_acyclic
    return
  }
  if physical_equal(self.tortoise, hare) {
    let mu = self.cycle_start()
    self.first_repeat = if mu == ancestor_chain_acyclic {
      ancestor_chain_acyclic
    } else {
      mu + self.lambda
    }
    return
  }
  if self.power == self.lambda {
    self.tortoise = hare
    self.power *= 2
    self.lambda = 0
  }
  self.hare = hare.parent
  self.hare_index += 1
  self.lambda += 1
  if self.hare is None {
    self.first_repeat = ancestor_chain_acyclic
  }
}

///|
/// Whether the `index`-th node of the chain (`index >= 1`) repeats an earlier
/// one. Callers ask for consecutive indices while walking the chain.
fn AncestorRepeatGuard::repeats_at(
  self : AncestorRepeatGuard,
  index : Int,
) -> Bool {
  let horizon = if index > ancestor_chain_acyclic / 3 {
    ancestor_chain_acyclic
  } else {
    3 * index
  }
  while self.first_repeat < 0 && self.hare_index <= horizon {
    self.step()
    if self.hare_index == ancestor_chain_acyclic {
      break
    }
  }
  self.first_repeat >= 0 && index >= self.first_repeat
}
