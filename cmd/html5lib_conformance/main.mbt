///|
/// Runs the html5lib-tests tree-construction conformance suite against the
/// public parser API and compares the outcome with the expected-failures
/// manifest. Mirrors the semantics of the JustHTML reference harness
/// (tests/harness/tree.py): tree comparison only, script-on cases that embed
/// a <script> tag are skipped because scripts never execute.
#coverage.skip
async fn main {
  let all_args = @env.args()
  let args = if all_args.is_empty() { all_args[:] } else { all_args[1:] }
  let mut corpus_dir = "tests/fixtures/html5lib-tests/tree-construction"
  let mut expected_path = "tests/fixtures/html5lib-tests/expected-failures.txt"
  let mut update_expected = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--update-expected" => update_expected = true
      "--expected" => {
        index += 1
        if index >= args.length() {
          eprintln("--expected requires a path argument")
          exit_process(2)
        }
        expected_path = args[index]
      }
      "--help" | "-h" => {
        println(usage_text())
        return
      }
      arg =>
        if arg.has_prefix("-") {
          eprintln("unknown option: \{arg}")
          eprintln(usage_text())
          exit_process(2)
        } else {
          corpus_dir = arg
        }
    }
    index += 1
  }
  if !@fs.exists(corpus_dir) {
    eprintln("html5lib-tests corpus not found: \{corpus_dir}")
    exit_process(2)
  }
  let code = run_suite(corpus_dir, expected_path, update_expected)
  if code != 0 {
    exit_process(code)
  }
}

///|
#coverage.skip
fn usage_text() -> String {
  (
    #|usage: moon run --target native cmd/html5lib_conformance [corpus-dir]
    #|         [--expected path] [--update-expected]
    #|
    #|Runs the html5lib-tests tree-construction suite and verifies the set of
    #|failing cases matches the expected-failures manifest exactly.
  ).to_string()
}

///|
priv struct DatCase {
  id : String
  data : String
  expected_error_count : Int
  document : String
  fragment_tag : String?
  fragment_ns : String?
  script_directive : String?
}

///|
priv enum CaseOutcome {
  CasePassed
  CaseSkipped
  CaseFailed(String)
}

///|
#coverage.skip
async fn run_suite(
  corpus_dir : String,
  expected_path : String,
  update_expected : Bool,
) -> Int {
  let files = collect_dat_files(corpus_dir, "")
  if files.is_empty() {
    eprintln("no .dat files found under \{corpus_dir}")
    return 1
  }
  let mut passed = 0
  let mut skipped = 0
  let mut error_count_matches = 0
  let mut error_count_checked = 0
  let failures : Array[String] = []
  let failure_details : Map[String, String] = {}
  for relative in files {
    let text = match read_text("\{corpus_dir}/\{relative}") {
      Some(value) => value
      None => {
        eprintln("could not read \{corpus_dir}/\{relative}")
        return 1
      }
    }
    for case in parse_dat_cases(relative, text) {
      match run_case(case) {
        CasePassed => {
          passed += 1
          error_count_checked += 1
          if case_error_count_matches(case) {
            error_count_matches += 1
          }
        }
        CaseSkipped => skipped += 1
        CaseFailed(detail) => {
          failures.push(case.id)
          failure_details[case.id] = detail
        }
      }
    }
  }
  let total = passed + failures.length()
  println(
    "html5lib tree-construction: \{passed}/\{total} passed, \{failures.length()} failed, \{skipped} skipped (script-dependent)",
  )
  println(
    "parse error counts matched on \{error_count_matches}/\{error_count_checked} passing cases (informational)",
  )
  if update_expected {
    let body = StringBuilder()
    body <+
      "# Failing html5lib-tests tree-construction cases (file:case-index).\n"
    body <+
      "# Regenerate with: moon run --target native cmd/html5lib_conformance -- --update-expected\n"
    for id in failures {
      body <+ "\{id}\n"
    }
    @fs.write_file(
      expected_path,
      body.to_string(),
      create_mode=CreateOrTruncate,
    )
    println(
      "wrote \{failures.length()} expected failure(s) to \{expected_path}",
    )
    return 0
  }
  let expected = load_expected_failures(expected_path)
  let unexpected : Array[String] = []
  for id in failures {
    if !expected.contains(id) {
      unexpected.push(id)
    }
  }
  let stale : Array[String] = []
  for id in expected {
    if !failures.contains(id) {
      stale.push(id)
    }
  }
  let mut shown = 0
  for id in unexpected {
    if shown >= 10 {
      println("... and \{unexpected.length() - shown} more unexpected failures")
      break
    }
    println("")
    println("UNEXPECTED FAILURE \{id}")
    match failure_details.get(id) {
      Some(detail) => println(detail)
      None => ()
    }
    shown += 1
  }
  for id in stale {
    println("expected failure now passes (remove from manifest): \{id}")
  }
  if !unexpected.is_empty() || !stale.is_empty() {
    println(
      "conformance drift: \{unexpected.length()} unexpected failure(s), \{stale.length()} stale expected failure(s)",
    )
    return 1
  }
  0
}

///|
#coverage.skip
async fn collect_dat_files(root : String, prefix : String) -> Array[String] {
  let out : Array[String] = []
  let entries = @fs.readdir("\{root}/\{prefix}", sort=true) catch {
    _ => return out
  }
  for entry in entries {
    let relative = if prefix.is_empty() { entry } else { "\{prefix}/\{entry}" }
    if entry.has_suffix(".dat") {
      out.push(relative)
    } else {
      let kind = @fs.kind("\{root}/\{relative}") catch { _ => Regular }
      if kind is Directory {
        out.append(collect_dat_files(root, relative))
      }
    }
  }
  out
}

///|
#coverage.skip
async fn read_text(path : String) -> String? {
  let data = @fs.read_file(path) catch { _ => return None }
  Some(data.text())
}

///|
#coverage.skip
async fn load_expected_failures(path : String) -> Array[String] {
  let out : Array[String] = []
  let text = match read_text(path) {
    Some(value) => value
    None => return out
  }
  for line_view in text.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    out.push(line)
  }
  out
}

///|
/// Splits a .dat file into test cases. A case ends right before the next
/// `#data` line, matching the JustHTML harness parser.
#coverage.skip
fn parse_dat_cases(file_label : String, text : String) -> Array[DatCase] {
  let lines : Array[String] = []
  for line_view in text.split("\n") {
    lines.push(line_view.to_owned())
  }
  let cases : Array[DatCase] = []
  let current : Array[String] = []
  for i in 0..<lines.length() {
    current.push(lines[i])
    if i + 1 >= lines.length() || lines[i + 1] == "#data" {
      if has_nonblank_line(current) {
        match parse_single_case(file_label, cases.length(), current) {
          Some(case) => cases.push(case)
          None => ()
        }
      }
      current.clear()
    }
  }
  cases
}

///|
#coverage.skip
fn has_nonblank_line(lines : Array[String]) -> Bool {
  for line in lines {
    if !line.trim().is_empty() {
      return true
    }
  }
  false
}

///|
#coverage.skip
fn parse_single_case(
  file_label : String,
  index : Int,
  lines : Array[String],
) -> DatCase? {
  let data : Array[String] = []
  let errors : Array[String] = []
  let document : Array[String] = []
  let mut fragment_tag : String? = None
  let mut fragment_ns : String? = None
  let mut script_directive : String? = None
  let mut mode = ""
  for line in lines {
    if line.has_prefix("#") {
      let directive = line[1:].to_owned()
      match directive {
        "script-on" | "script-off" => script_directive = Some(directive)
        "new-errors" => mode = "errors"
        _ => mode = directive
      }
    } else if mode == "data" {
      data.push(line)
    } else if mode == "errors" {
      errors.push(line)
    } else if mode == "document" {
      document.push(line)
    } else if mode == "document-fragment" {
      let fragment = line.trim().to_owned()
      match fragment.find(" ") {
        Some(space) => {
          fragment_ns = Some(fragment[0:space].to_owned())
          fragment_tag = Some(fragment[space + 1:].to_owned())
        }
        None => fragment_tag = Some(fragment)
      }
    }
  }
  if data.is_empty() && document.is_empty() {
    return None
  }
  let mut expected_error_count = 0
  for line in errors {
    if !line.trim().is_empty() {
      expected_error_count += 1
    }
  }
  Some({
    id: "\{file_label}:\{index}",
    data: decode_escapes(join_lines(data)),
    expected_error_count,
    document: join_lines(document),
    fragment_tag,
    fragment_ns,
    script_directive,
  })
}

///|
#coverage.skip
fn join_lines(lines : Array[String]) -> String {
  let out = StringBuilder()
  for i, line in lines {
    if i > 0 {
      out <+ "\n"
    }
    out <+ "\{line}"
  }
  out.to_string()
}

///|
/// Decodes `\xNN` and `\uNNNN` escapes in fixture input, mirroring the
/// JustHTML harness so both runners interpret the corpus identically.
#coverage.skip
fn decode_escapes(text : String) -> String {
  if !text.contains("\\x") && !text.contains("\\u") {
    return text
  }
  let chars = text.to_array()
  let out = StringBuilder()
  let mut i = 0
  while i < chars.length() {
    if chars[i] is '\\' && i + 3 < chars.length() && chars[i + 1] is 'x' {
      match decoded_escape_char(chars, i + 2, 2) {
        Some(c) => {
          out.write_char(c)
          i += 4
          continue
        }
        None => ()
      }
    }
    if chars[i] is '\\' && i + 5 < chars.length() && chars[i + 1] is 'u' {
      match decoded_escape_char(chars, i + 2, 4) {
        Some(c) => {
          out.write_char(c)
          i += 6
          continue
        }
        None => ()
      }
    }
    out.write_char(chars[i])
    i += 1
  }
  out.to_string()
}

///|
/// Decodes a fixed-width hex escape into a Char. Returns None for malformed
/// hex or code points (such as lone surrogates) that cannot form a Char, in
/// which case the literal escape text is preserved.
#coverage.skip
fn decoded_escape_char(chars : Array[Char], start : Int, length : Int) -> Char? {
  let mut value = 0
  for offset in 0..<length {
    let digit = match chars[start + offset] {
      '0'..='9' as c => c.to_int() - '0'
      'a'..='f' as c => c.to_int() - 'a' + 10
      'A'..='F' as c => c.to_int() - 'A' + 10
      _ => return None
    }
    value = value * 16 + digit
  }
  value.to_char()
}

///|
#coverage.skip
fn case_error_count_matches(case : DatCase) -> Bool {
  let parsed = parse_case_input(case) catch { _ => return false }
  parsed.errors.length() == case.expected_error_count
}

///|
#coverage.skip
fn parse_case_input(case : DatCase) -> @html_parser.ParsedHtml raise {
  let scripting_enabled = !(case.script_directive is Some("script-off"))
  match case.fragment_tag {
    Some(tag) =>
      @html_parser.parse_fragment(
        case.data,
        context=match case.fragment_ns {
          Some(ns) => FragmentContext(tag, ns~)
          None => FragmentContext(tag)
        },
        collect_errors=true,
        sanitize=false,
        scripting_enabled~,
      )
    None =>
      @html_parser.parse(
        case.data,
        collect_errors=true,
        sanitize=false,
        scripting_enabled~,
      )
  }
}

///|
#coverage.skip
fn run_case(case : DatCase) -> CaseOutcome {
  if case.script_directive is Some("script-on") &&
    contains_script_tag(case.data) {
    return CaseSkipped
  }
  let parsed = parse_case_input(case) catch {
    error => return CaseFailed("parse raised: \{error}")
  }
  let actual = @html_parser.to_test_format(parsed.root)
  if normalize_tree(actual) == normalize_tree(case.document) {
    CasePassed
  } else {
    CaseFailed(
      "#data\n\{case.data}\n#expected\n\{case.document}\n#actual\n\{actual}",
    )
  }
}

///|
#coverage.skip
fn contains_script_tag(data : String) -> Bool {
  data.to_lower().contains("<script")
}

///|
/// Strips the whole text and trailing whitespace per line before comparison,
/// matching the JustHTML harness's compare_outputs().
#coverage.skip
fn normalize_tree(text : String) -> String {
  let stripped = text.trim().to_owned()
  let out : Array[String] = []
  for line_view in stripped.split("\n") {
    out.push(rstrip(line_view.to_owned()))
  }
  join_lines(out)
}

///|
#coverage.skip
fn rstrip(line : String) -> String {
  line.trim_end().to_owned()
}

///|
#coverage.skip
async fn eprintln(message : String) -> Unit noraise {
  @stdio.stderr.write("\{message}\n") catch {
    _ => ()
  }
}

///|
#coverage.skip
extern "C" fn exit_process(code : Int) = "exit"
