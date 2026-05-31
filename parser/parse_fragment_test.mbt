// Blackbox snapshot tests for `parse_fragment` — parses an HTML fragment
// without wrapping it in implicit html/head/body. The optional
// `context` argument tells the parser what container the fragment is
// being inserted into, which changes the active insertion mode.

///|
test "parse_fragment default body context wraps content as fragment" {
  let doc = @parser.parse_fragment("<p class='hi'>Hello <b>MoonBit</b></p>")
  inspect(
    @ser.to_html(doc.root, pretty=false),
    content=(
      #|<p class="hi">Hello <b>MoonBit</b></p>
    ),
  )
}

///|
test "parse_fragment table context inserts implicit tbody" {
  // Bare <tr> in a table context gets wrapped in an implicit <tbody>
  // — same rule the full document parser applies.
  let doc = @parser.parse_fragment(
    "<tr><td>a</td><td>b</td></tr>",
    context=@parser.FragmentContext("table"),
  )
  inspect(
    @ser.to_html(doc.root, pretty=true),
    content=(
      #|<tbody>
      #|  <tr>
      #|    <td>a</td>
      #|    <td>b</td>
      #|  </tr>
      #|</tbody>
    ),
  )
}

///|
test "parse_fragment select context restricts allowed children" {
  let doc = @parser.parse_fragment(
    "<option>a</option><option>b</option>",
    context=@parser.FragmentContext("select"),
  )
  inspect(
    @ser.to_html(doc.root, pretty=false),
    content=(
      #|<option>a</option><option>b</option>
    ),
  )
}

///|
test "parse_fragment recovers from missing end tag inside fragment" {
  let doc = @parser.parse_fragment("<p>one<p>two")
  inspect(
    @ser.to_html(doc.root, pretty=true),
    content=(
      #|<p>one</p>
      #|<p>two</p>
    ),
  )
}
