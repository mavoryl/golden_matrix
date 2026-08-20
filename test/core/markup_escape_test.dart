import 'package:flutter_test/flutter_test.dart';
import 'package:golden_matrix/src/core/markup_escape.dart';

void main() {
  // Three escapers used to be two copies of the same `& < >` chain plus
  // whatever each context happened to need. Sharing the base keeps them from
  // drifting while letting each context stay honest — HTML attributes need the
  // apostrophe, XML attributes need the newline, and neither needs the other's.
  group('escapeMarkupText', () {
    test('escapes the three characters that end an element', () {
      expect(escapeMarkupText('a & b < c > d'), 'a &amp; b &lt; c &gt; d');
    });

    test('escapes the ampersand first, so entities are not double-escaped', () {
      expect(escapeMarkupText('&lt;'), '&amp;lt;');
    });

    test('leaves quotes alone — they are legal in text content', () {
      expect(escapeMarkupText('''he said "hi"'''), '''he said "hi"''');
    });
  });

  group('escapeHtmlAttribute', () {
    test('adds both quote characters', () {
      expect(escapeHtmlAttribute('''a"b'c'''), 'a&quot;b&#39;c');
    });

    test('still escapes the markup characters', () {
      expect(escapeHtmlAttribute('<a & b>'), '&lt;a &amp; b&gt;');
    });
  });

  group('escapeXmlAttribute', () {
    test('a newline becomes a character reference', () {
      // A raw newline inside an XML attribute is normalised to a space by
      // conforming parsers, which silently reflows a multi-line failure message.
      expect(escapeXmlAttribute('line1\nline2'), 'line1&#10;line2');
    });

    test('a carriage return is dropped rather than encoded', () {
      expect(escapeXmlAttribute('line1\r\nline2'), 'line1&#10;line2');
    });

    test('double quotes are escaped, apostrophes are not', () {
      // The attribute delimiter is `"`, so `'` needs no escaping and encoding
      // it would only make CI dashboards render `&#39;` literally.
      expect(escapeXmlAttribute('''a"b'c'''), '''a&quot;b'c''');
    });
  });
}
