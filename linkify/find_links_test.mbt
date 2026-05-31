// Blackbox snapshot tests for `find_links` and `find_links_with_config`.
//
// Each snapshot is a `LinkMatch` array: (start, end) are UTF-16 code-unit
// offsets into the input, `text` is the matched substring (with trailing
// punctuation trimmed), and `href` is the normalized URL to link to.

///|
test "find_links detects scheme URL and trims trailing punctuation" {
  // The trailing "." is stripped from the match even though it sits
  // immediately after the URL.
  debug_inspect(
    @linkify.find_links("See https://example.com/a?b=1."),
    content=(
      #|[
      #|  {
      #|    start: 4,
      #|    end: 29,
      #|    text: "https://example.com/a?b=1",
      #|    href: "https://example.com/a?b=1",
      #|    kind: "url",
      #|  },
      #|]
    ),
  )
}

///|
test "find_links detects fuzzy domain without scheme" {
  // No "http://" in the input, but the matcher adds it to `href`.
  debug_inspect(
    @linkify.find_links("Go to example.com/path now"),
    content=(
      #|[
      #|  {
      #|    start: 6,
      #|    end: 22,
      #|    text: "example.com/path",
      #|    href: "http://example.com/path",
      #|    kind: "url",
      #|  },
      #|]
    ),
  )
}

///|
test "find_links detects email address" {
  // `href` gets the `mailto:` scheme automatically.
  debug_inspect(
    @linkify.find_links("Mail test@example.com now"),
    content=(
      #|[
      #|  {
      #|    start: 5,
      #|    end: 21,
      #|    text: "test@example.com",
      #|    href: "mailto:test@example.com",
      #|    kind: "email",
      #|  },
      #|]
    ),
  )
}

///|
test "find_links detects protocol-relative URL" {
  debug_inspect(
    @linkify.find_links("See //example.com/x"),
    content=(
      #|[
      #|  {
      #|    start: 4,
      #|    end: 19,
      #|    text: "//example.com/x",
      #|    href: "//example.com/x",
      #|    kind: "url",
      #|  },
      #|]
    ),
  )
}

///|
test "find_links returns multiple matches in order" {
  debug_inspect(
    @linkify.find_links(
      "Visit https://example.com or email me@example.org soon",
    ),
    content=(
      #|[
      #|  {
      #|    start: 6,
      #|    end: 25,
      #|    text: "https://example.com",
      #|    href: "https://example.com",
      #|    kind: "url",
      #|  },
      #|  {
      #|    start: 35,
      #|    end: 49,
      #|    text: "me@example.org",
      #|    href: "mailto:me@example.org",
      #|    kind: "email",
      #|  },
      #|]
    ),
  )
}

///|
test "find_links returns empty for non-link text" {
  // No fuzzy match for unknown TLDs like .js or unrecognized schemes.
  debug_inspect(
    @linkify.find_links("import app.js and hppt://example.com"),
    content=(
      #|[]
    ),
  )
}

///|
test "find_links_with_config extra_tlds opts in to custom TLDs" {
  // Default behavior: `site.internal` is not a link.
  let plain = @linkify.find_links("site.internal")
  // With extra_tlds: `internal` is recognized.
  let custom = @linkify.find_links_with_config(
    "site.internal",
    @linkify.LinkifyConfig::with_extra_tlds(["internal"]),
  )
  debug_inspect(
    (plain, custom),
    content=(
      #|(
      #|  [],
      #|  [
      #|    {
      #|      start: 0,
      #|      end: 13,
      #|      text: "site.internal",
      #|      href: "http://site.internal",
      #|      kind: "url",
      #|    },
      #|  ],
      #|)
    ),
  )
}

///|
test "find_links_with_config fuzzy_ip enables bare IPv4 addresses" {
  let plain = @linkify.find_links("192.168.0.1")
  let ips = @linkify.find_links_with_config(
    "192.168.0.1",
    @linkify.LinkifyConfig(fuzzy_ip=true),
  )
  debug_inspect(
    (plain, ips),
    content=(
      #|(
      #|  [],
      #|  [
      #|    {
      #|      start: 0,
      #|      end: 11,
      #|      text: "192.168.0.1",
      #|      href: "http://192.168.0.1",
      #|      kind: "url",
      #|    },
      #|  ],
      #|)
    ),
  )
}
