# Native CLI

These Moon Cram tests exercise the compiled native `justhtml` wrapper. They focus on
shell-visible behavior that MoonBit unit tests cannot cover directly: argv,
stdin, file IO, stdout, stderr, and process exit codes.

## Version

```mooncram
$ "$JUSTHTML_CLI" --version
justhtml 0.1.7
```

## Help

```mooncram
$ "$JUSTHTML_CLI" --help | grep -E '^(usage: justhtml|  --format html|  -h, --help)'
usage: justhtml [OPTIONS] <path|->
  --format html|text|markdown   Output format (default: html)
  -h, --help                    Print this help and exit
```

## Text Output From Stdin

```mooncram
$ printf '<article><p>Hi <b>there</b></p><p>Bye</p></article>' | "$JUSTHTML_CLI" - --selector p --format text
Hi there
Bye
```

## Equals Option Form

```mooncram
$ printf '<p>Hello</p>' | "$JUSTHTML_CLI" --format=text -
Hello
```

## Repeated Option Uses Last Value

```mooncram
$ printf '<p>Hello</p>' | "$JUSTHTML_CLI" - --format html --format text
Hello
```

## File Input And Output File

```mooncram
$ printf '<p>File</p>' > input.html && "$JUSTHTML_CLI" input.html --format text --output out.txt && cat out.txt
File
```

## Empty Selection Exit Code

```mooncram
$ set +e; printf '<p>Hello</p>' | "$JUSTHTML_CLI" - --selector '.missing' > empty.out; code=$?; set -e; printf 'exit=%s\n' "$code"; test ! -s empty.out
exit=1
```

## Unknown Option Error

```mooncram
$ set +e; "$JUSTHTML_CLI" --bad > unknown.out 2> unknown.err; code=$?; set -e; printf 'exit=%s\n' "$code"; sed -n '1p' unknown.err; test ! -s unknown.out
exit=2
error: unexpected argument '--bad' found
```

## Strip Flag Conflict Preserves Argument Order

```mooncram
$ set +e; printf '<p>x</p>' | "$JUSTHTML_CLI" - --no-strip --strip > strip.out 2> strip.err; code=$?; set -e; printf 'exit=%s\n' "$code"; sed -n '1p' strip.err
exit=2
error: --strip conflicts with --no-strip
```
