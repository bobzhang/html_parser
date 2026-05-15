///|
test "parser closes open buttons before repeated button starts" {
  let nested = @html_parser.parse_fragment(
    "<button>one<button>two</button>three</button>",
    collect_errors=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<button>one</button><button>two</button>three",
  )
  assert_eq(nested.errors.length(), 2)
  assert_eq(nested.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(nested.errors[1].code, "unexpected-end-tag")
  let with_formatting = @html_parser.parse_fragment(
    "<button><b>one</b><button>two</button></button>",
    collect_errors=true,
  )
  assert_eq(
    with_formatting.to_html(pretty=false),
    "<button><b>one</b></button><button>two</button>",
  )
  assert_eq(with_formatting.errors.length(), 2)
  assert_eq(
    with_formatting.errors[0].code,
    "unexpected-start-tag-implies-end-tag",
  )
  assert_eq(with_formatting.errors[1].code, "unexpected-end-tag")
  let through_table_header = @html_parser.parse_fragment(
    "<button>outer<table><tr><th><button>inner</button></th></tr></table></button>",
    collect_errors=true,
  )
  assert_eq(
    through_table_header.to_html(pretty=false),
    "<button>outer<table><tbody><tr><th><button>inner</button></th></tr></tbody></table></button>",
  )
  assert_eq(through_table_header.errors.length(), 0)
}

///|
test "parser ignores nested form starts and clears form element on end" {
  let nested = @html_parser.parse_fragment(
    "<form><form>x</form>y</form>",
    collect_errors=true,
  )
  assert_eq(nested.to_html(pretty=false), "<form>x</form>y")
  assert_eq(nested.errors.length(), 2)
  assert_eq(nested.errors[0].code, "unexpected-start-tag")
  assert_eq(nested.errors[1].code, "unexpected-end-tag")
  let paragraph = @html_parser.parse_fragment(
    "<form><p>a<form>b</form>",
    collect_errors=true,
  )
  assert_eq(paragraph.to_html(pretty=false), "<form><p>ab</p></form>")
  assert_eq(paragraph.errors.length(), 1)
  assert_eq(paragraph.errors[0].code, "unexpected-start-tag")
}
