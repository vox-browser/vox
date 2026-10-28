module html

import dom

$if test {
	fn ascii_alphabetic_to_index(character u8) u8 {
		assert character.is_letter()
		return if character <= `Z` { character - `A` } else { character - `a` + 26 }
	}
}

$if test {
	fn is_whitespace_or_slash(character u8) bool {
		return is_number_ascii_whitespace(character) || character == `/`
	}
}

$if test {
	fn is_whitespace_or_end_chevron(character u8) bool {
		return is_number_ascii_whitespace(character) || character == `>`
	}
}

// Shared helpers for the HTML tree-construction machinery (stack of open elements, list of active
// formatting elements, and eventually the parser itself).
const ns_html = 'http://www.w3.org/1999/xhtml'
const ns_svg = 'http://www.w3.org/2000/svg'
const ns_mathml = 'http://www.w3.org/1998/Math/MathML'

// Node identity: V's `&Element == &Element` compares BY VALUE (structural), so element identity
// on the parser stacks must go through the DOM's unique-id based is_same_node.
fn same_element(a &dom.Element, b &dom.Element) bool {
	return a.as_node().is_same_node(b.as_node())
}

fn element_in_namespace(e &dom.Element, ns string) bool {
	return (e.namespace_uri() or { return false }) == ns
}

// The HTML-namespace "special" element tag names.
const special_html_tags = ['address', 'applet', 'area', 'article', 'aside', 'base', 'basefont',
	'bgsound', 'blockquote', 'body', 'br', 'button', 'caption', 'center', 'col', 'colgroup', 'dd',
	'details', 'dir', 'div', 'dl', 'dt', 'embed', 'fieldset', 'figcaption', 'figure', 'footer',
	'form', 'frame', 'frameset', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head', 'header', 'hgroup',
	'hr', 'html', 'iframe', 'img', 'input', 'keygen', 'li', 'link', 'listing', 'main', 'marquee',
	'menu', 'meta', 'nav', 'noembed', 'noframes', 'noscript', 'object', 'ol', 'p', 'param',
	'plaintext', 'pre', 'script', 'search', 'section', 'select', 'source', 'style', 'summary', 'table',
	'tbody', 'td', 'template', 'textarea', 'tfoot', 'th', 'thead', 'title', 'tr', 'track', 'ul',
	'wbr', 'xmp']

const special_svg_tags = ['desc', 'foreignObject', 'title']

const special_mathml_tags = ['mi', 'mo', 'mn', 'ms', 'mtext', 'annotation-xml']

// https://html.spec.whatwg.org/multipage/parsing.html#special
pub fn is_special_tag(tag_name string, namespace_ ?string) bool {
	ns := namespace_ or { return false }
	if ns == ns_html {
		return tag_name in special_html_tags
	} else if ns == ns_svg {
		return tag_name in special_svg_tags
	} else if ns == ns_mathml {
		return tag_name in special_mathml_tags
	}
	return false
}

// HTMLParser::is_special_tag(). Keep the free helper for translated stack
// code whose upstream C++ calls this static method.
pub fn HTMLParser.is_special_tag(tag_name string, namespace_ ?string) bool {
	return is_special_tag(tag_name, namespace_)
}
