///|
/// EOF immediately after in-tag whitespace previously crashed the parser
/// (the attribute loop unwrapped current() after the skip ran to EOF).
/// The whitespace variants match the whitespace-free analog: eof-in-tag,
/// token dropped, standard scaffold.
test "tag whitespace then eof parses without crashing" {
  inspect(
    @html_parser.parse("<div").to_html(),
    content=(
      #|<html>
      #|  <head></head>
      #|  <body></body>
      #|</html>
    ),
  )
  inspect(
    @html_parser.parse("<div ").to_html(),
    content=(
      #|<html>
      #|  <head></head>
      #|  <body></body>
      #|</html>
    ),
  )
  inspect(
    @html_parser.parse("</div ").to_html(),
    content=(
      #|<html>
      #|  <head></head>
      #|  <body></body>
      #|</html>
    ),
  )
  inspect(
    @html_parser.parse("<div id=x ").to_html(),
    content=(
      #|<html>
      #|  <head></head>
      #|  <body></body>
      #|</html>
    ),
  )
  inspect(
    @html_parser.parse("<div \t\n").to_html(),
    content=(
      #|<html>
      #|  <head></head>
      #|  <body></body>
      #|</html>
    ),
  )
}
