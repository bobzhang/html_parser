///|
/// Benchmarks the library's main entry points (parse, sanitize, serialize,
/// query, markdown, linkify, stream) against a representative real-world
/// document plus small synthetic inputs, and reports per-operation latency
/// and input throughput.
#coverage.skip
async fn main {
  let all_args = @env.args()
  let args = if all_args.is_empty() { all_args[:] } else { all_args[1:] }
  let mut json_output = false
  let mut quick = false
  let mut fixture = "tests/fixtures/justhtml/data/wikipedia.html"
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--json" => json_output = true
      "--quick" => quick = true
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
          fixture = arg
        }
    }
    index += 1
  }
  if !@fs.exists(fixture) {
    eprintln("benchmark fixture not found: \{fixture}")
    exit_process(2)
  }
  let html = @fs.read_file(fixture).text() catch {
    error => {
      eprintln("could not read \{fixture}: \{error}")
      exit_process(1)
      return
    }
  }
  run_benchmarks(html, json_output~, quick~)
}

///|
#coverage.skip
fn usage_text() -> String {
  (
    #|usage: moon run --target native --release cmd/benchmark [fixture.html]
    #|         [--json] [--quick]
    #|
    #|Benchmarks parse/sanitize/serialize/query/markdown/linkify/stream on the
    #|given HTML document (default: the vendored Wikipedia portal page).
    #|--quick runs each workload once as a smoke test; --json emits the raw
    #|per-workload summaries as JSON lines.
  ).to_string()
}

///|
priv struct Workload {
  name : String
  input_bytes : Int
  run : () -> Unit
}

///|
#coverage.skip
fn run_benchmarks(html : String, json_output~ : Bool, quick~ : Bool) -> Unit {
  let input_bytes = html.length() * 2
  let parsed = try! @html_parser.parse(html)
  let small_fragment = "<p>Hello <b>world</b>, this is a <a href=\"https://example.com\">link</a> and <i>some</i> nested <span>markup</span>.</p>"
  let link_text = "Visit https://example.com/docs and mailto:user@example.com or www.github.com/moonbit for more."
  let workloads : Array[Workload] = [
    {
      name: "parse:document",
      input_bytes,
      run: () => ignore(try! @html_parser.parse(html)),
    },
    {
      name: "parse:document:collect_errors",
      input_bytes,
      run: () => ignore(try! @html_parser.parse(html, collect_errors=true)),
    },
    {
      name: "parse:document:sanitize",
      input_bytes,
      run: () => ignore(try! @html_parser.parse(html, sanitize=true)),
    },
    {
      name: "parse:fragment:small",
      input_bytes: small_fragment.length() * 2,
      run: () => ignore(try! @html_parser.parse_fragment(small_fragment)),
    },
    {
      name: "serialize:to_html",
      input_bytes,
      run: () => ignore(try! @html_parser.to_html(parsed.root, pretty=false)),
    },
    {
      name: "serialize:to_markdown",
      input_bytes,
      run: () => ignore(try! @html_parser.to_markdown(parsed.root)),
    },
    {
      name: "query:selector",
      input_bytes,
      run: () => ignore(@html_parser.query(parsed.root, "a[href]")),
    },
    {
      name: "linkify:text",
      input_bytes: link_text.length() * 2,
      run: () => ignore(@html_parser.find_links(link_text)),
    },
    {
      name: "stream:events",
      input_bytes,
      run: () => {
        let mut events = 0
        @html_parser.stream_each(html, _event => events += 1)
        ignore(events)
      },
    },
  ]
  if quick {
    for workload in workloads {
      (workload.run)()
      println("ok \{workload.name}")
    }
    return
  }
  if !json_output {
    println(
      "benchmarking against \{input_bytes / 2} UTF-16 code units of input",
    )
    println("")
    println(
      pad("workload", 32) + pad("mean", 12) + pad("median", 12) + "throughput",
    )
  }
  for workload in workloads {
    let summary = @bench.single_bench(name=workload.name, workload.run)
    if json_output {
      println(summary.to_json().stringify())
    } else {
      let stats = summary.to_json()
      let mean_us = json_number(stats, "mean")
      let median_us = json_number(stats, "median")
      let throughput = if mean_us > 0.0 {
        let bytes_per_second = workload.input_bytes.to_double() /
          (mean_us / 1.0e6)
        "\{format_double(bytes_per_second / 1048576.0)} MiB/s"
      } else {
        "-"
      }
      println(
        pad(workload.name, 32) +
        pad("\{format_double(mean_us)} us", 12) +
        pad("\{format_double(median_us)} us", 12) +
        throughput,
      )
    }
  }
}

///|
#coverage.skip
fn json_number(value : Json, key : String) -> Double {
  match value {
    Object(map) =>
      match map.get(key) {
        Some(Number(number, ..)) => number
        _ => 0.0
      }
    _ => 0.0
  }
}

///|
#coverage.skip
fn format_double(value : Double) -> String {
  let scaled = (value * 100.0).round() / 100.0
  let text = scaled.to_string()
  match text.find(".") {
    Some(dot) =>
      if text.length() > dot + 3 {
        text[0:dot + 3].to_owned()
      } else {
        text
      }
    None => text
  }
}

///|
#coverage.skip
fn pad(text : String, width : Int) -> String {
  let out = StringBuilder()
  out <+ "\{text}"
  let mut remaining = width - text.length()
  while remaining > 0 {
    out <+ " "
    remaining -= 1
  }
  out.to_string()
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
