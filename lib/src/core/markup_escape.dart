// XML/HTML escaping, in one place.
//
// There used to be two hand-written copies of the same `& < >` chain — one in
// the HTML template, one in the JUnit template — plus whatever extra each
// context needed bolted on the end. Two copies of an escaper is how a report
// eventually renders `&#39;` at the user.
//
// The contexts genuinely differ, so they stay separate functions over a shared
// base rather than one function with flags: text content needs no quote
// escaping, an HTML attribute needs both quote characters, and an XML
// attribute needs its newlines encoded but not its apostrophes.

/// Escapes the three characters that can end an element: `&`, `<`, `>`.
///
/// `&` goes first, so already-escaped entities are not double-escaped into
/// `&amp;amp;`.
String escapeMarkupText(String text) =>
    text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Escapes [text] for use inside an HTML attribute value.
///
/// Both quote characters are encoded, because the surrounding delimiter is not
/// known at this point.
String escapeHtmlAttribute(String text) =>
    escapeMarkupText(text).replaceAll('"', '&quot;').replaceAll("'", '&#39;');

/// Escapes [text] for use inside a double-quoted XML attribute value.
///
/// Newlines become `&#10;`: a raw newline in an attribute is normalised to a
/// space by conforming parsers, which silently reflows a multi-line failure
/// message. Carriage returns are dropped rather than encoded, and apostrophes
/// are left alone — the delimiter is `"`, and encoding `'` would only make CI
/// dashboards print `&#39;` literally.
String escapeXmlAttribute(String text) =>
    escapeMarkupText(text).replaceAll('"', '&quot;').replaceAll('\n', '&#10;').replaceAll('\r', '');
