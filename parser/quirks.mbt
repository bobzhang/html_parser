///|
/// Doctype-based quirks-mode classification, per the spec's "determine the
/// document's mode" algorithm (only full quirks is tracked: limited-quirks
/// does not change tree construction here).
fn doctype_triggers_quirks(
  name : String,
  public_id : String?,
  system_id : String?,
  force_quirks : Bool,
) -> Bool {
  if force_quirks {
    return true
  }
  if name != "html" {
    return true
  }
  let public_lower = match public_id {
    Some(value) => @syn.lower_ascii(value)
    None => ""
  }
  let system_lower = match system_id {
    Some(value) => @syn.lower_ascii(value)
    None => ""
  }
  if public_id is Some(_) {
    if public_lower == "-//w3o//dtd w3 html strict 3.0//en//" ||
      public_lower == "-/w3c/dtd html 4.0 transitional/en" ||
      public_lower == "html" {
      return true
    }
    for prefix in quirky_public_prefixes() {
      if public_lower.has_prefix(prefix) {
        return true
      }
    }
    if system_id is None {
      for
        prefix in [
          "-//w3c//dtd html 4.01 frameset//", "-//w3c//dtd html 4.01 transitional//",
        ] {
        if public_lower.has_prefix(prefix) {
          return true
        }
      }
    }
  }
  if system_id is Some(_) &&
    system_lower == "http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd" {
    return true
  }
  false
}

///|
fn quirky_public_prefixes() -> Array[String] {
  [
    "-//advasoft ltd//dtd html 3.0 aswedit + extensions//", "-//as//dtd html 3.0 aswedit + extensions//",
    "-//ietf//dtd html 2.0 level 1//", "-//ietf//dtd html 2.0 level 2//", "-//ietf//dtd html 2.0 strict level 1//",
    "-//ietf//dtd html 2.0 strict level 2//", "-//ietf//dtd html 2.0 strict//", "-//ietf//dtd html 2.0//",
    "-//ietf//dtd html 2.1e//", "-//ietf//dtd html 3.0//", "-//ietf//dtd html 3.2 final//",
    "-//ietf//dtd html 3.2//", "-//ietf//dtd html 3//", "-//ietf//dtd html level 0//",
    "-//ietf//dtd html level 1//", "-//ietf//dtd html level 2//", "-//ietf//dtd html level 3//",
    "-//ietf//dtd html strict level 0//", "-//ietf//dtd html strict level 1//", "-//ietf//dtd html strict level 2//",
    "-//ietf//dtd html strict level 3//", "-//ietf//dtd html strict//", "-//ietf//dtd html//",
    "-//metrius//dtd metrius presentational//", "-//microsoft//dtd internet explorer 2.0 html strict//",
    "-//microsoft//dtd internet explorer 2.0 html//", "-//microsoft//dtd internet explorer 2.0 tables//",
    "-//microsoft//dtd internet explorer 3.0 html strict//", "-//microsoft//dtd internet explorer 3.0 html//",
    "-//microsoft//dtd internet explorer 3.0 tables//", "-//netscape comm. corp.//dtd html//",
    "-//netscape comm. corp.//dtd strict html//", "-//o'reilly and associates//dtd html 2.0//",
    "-//o'reilly and associates//dtd html extended 1.0//", "-//o'reilly and associates//dtd html extended relaxed 1.0//",
    "-//softquad software//dtd hotmetal pro 6.0::19990601::extensions to html 4.0//",
    "-//softquad//dtd hotmetal pro 4.0::19971010::extensions to html 4.0//", "-//spyglass//dtd html 2.0 extended//",
    "-//sq//dtd html 2.0 hotmetal + extensions//", "-//sun microsystems corp.//dtd hotjava html//",
    "-//sun microsystems corp.//dtd hotjava strict html//", "-//w3c//dtd html 3 1995-03-24//",
    "-//w3c//dtd html 3.2 draft//", "-//w3c//dtd html 3.2 final//", "-//w3c//dtd html 3.2//",
    "-//w3c//dtd html 3.2s draft//", "-//w3c//dtd html 4.0 frameset//", "-//w3c//dtd html 4.0 transitional//",
    "-//w3c//dtd html experimental 19960712//", "-//w3c//dtd html experimental 970421//",
    "-//w3c//dtd w3 html//", "-//w3o//dtd w3 html 3.0//", "-//webtechs//dtd mozilla html 2.0//",
    "-//webtechs//dtd mozilla html//",
  ]
}

///|
/// Full quirks mode is active for document parses with no doctype or a
/// quirky doctype; fragments and iframe-srcdoc documents stay no-quirks.
fn Parser::in_quirks_mode(self : Parser) -> Bool {
  !self.is_fragment_parser() && !self.iframe_srcdoc && self.doctype_quirks_mode
}

///|
fn document_doctype_is_initial_target(parser : Parser) -> Bool {
  for child in parser.root.children {
    match child.kind {
      Element => return false
      Doctype => return false
      Text => if !is_whitespace_text_node(child) { return false }
      _ => ()
    }
  }
  true
}
