///|
/// A URL or email-like span found in plain text.
///
/// `start` and `end` are UTF-16 offsets into the input `StringView`.
/// `kind` is `"url"` or `"email"`.
pub(all) struct LinkMatch {
  start : Int
  end : Int
  text : String
  href : String
  kind : String
} derive(Debug, Eq)

///|
/// Options for the plain-text link scanner.
pub struct LinkifyConfig {
  priv fuzzy_ip : Bool
  priv extra_tlds : Set[String]
} derive(Debug)

///|
/// Create a linkify scanner configuration.
///
/// `fuzzy_ip` enables bare IPv4 address matches such as `192.168.0.1`.
/// `extra_tlds` extends the default fuzzy domain and email TLD allowlist.
pub fn LinkifyConfig::new(
  fuzzy_ip? : Bool = false,
  extra_tlds? : Array[String] = [],
) -> LinkifyConfig {
  { fuzzy_ip, extra_tlds: linkify_tld_set(extra_tlds) }
}

///|
/// Create a linkify scanner configuration with additional fuzzy-link TLDs.
pub fn LinkifyConfig::with_extra_tlds(
  extra_tlds : Array[String],
) -> LinkifyConfig {
  LinkifyConfig::new(extra_tlds~)
}

///|
fn linkify_tld_set(values : Array[String]) -> Set[String] {
  let out : Set[String] = Set::default()
  for value in values {
    let tld = value[:].trim().to_lower().to_owned()
    if tld != "" {
      out.add(tld)
    }
  }
  out
}
