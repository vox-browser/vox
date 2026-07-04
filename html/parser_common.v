module html

import dom

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
	'plaintext', 'pre', 'script', 'search', 'section', 'select', 'source', 'style', 'summary',
	'table', 'tbody', 'td', 'template', 'textarea', 'tfoot', 'th', 'thead', 'title', 'tr', 'track',
	'ul', 'wbr', 'xmp']

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
