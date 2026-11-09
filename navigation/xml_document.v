module main

import dom
import encoding
import html

// XML's encoding declaration is considered only without a transport charset;
// the existing decoder's BOM handling still takes precedence over either.
fn browser_xml_declaration_encoding(source string) ?string {
	if !source.starts_with('<?xml') || source.len < 6 || source[5] !in [` `, `\t`, `\n`, `\r`] {
		return none
	}
	end := source.index('?>') or { return none }
	declaration := source[5..end]
	start := declaration.index('encoding') or { return none }
	if start > 0 && declaration[start - 1] !in [` `, `\t`, `\n`, `\r`] { return none }
	mut value := declaration[start + 'encoding'.len..].trim_space()
	if !value.starts_with('=') { return none }
	value = value[1..].trim_space()
	if value.len < 2 || value[0] !in [u8(39), u8(34)] { return none }
	close := value[1..].index_u8(value[0])
	if close < 0 { return none }
	return encoding.get_an_encoding(value[1..close + 1])
}

fn parse_browser_navigation_xml_document(document &dom.Document, source string) {
	// Token names, attributes and CDATA may alias the parser source. Keep it
	// in the document owner after the decoded-input workspace is released.
	html.parse_xml_document_source(document, source.clone()) or {
		// Match DOMParser's XML error document rather than exposing a partial
		// active tree whose scripts came from malformed markup.
		mut root := document.as_node()
		root.remove_all_children(true)
		parser_error := document.create_element_ns('http://www.mozilla.org/newlayout/xml/parsererror.xml', 'parsererror') or { return }
		root.append_child(parser_error.as_node()) or { return }
	}
	// XML has no HTML tokenizer state, but shares the end-of-parsing steps,
	// including readiness and the resource-delayed load event.
	html.HTMLParser.the_end(document, none)
}
