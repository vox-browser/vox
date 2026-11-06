module devtools

import dom
import strings

// Chrome's light Elements palette.
pub const color_tag = u32(0x881280)
pub const color_attribute_name = u32(0x994500)
pub const color_attribute_value = u32(0x1a1aa6)
pub const color_text = u32(0x222222)
pub const color_comment = u32(0x236e25)
pub const color_doctype = u32(0x808080)

const void_elements = ['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'keygen', 'link',
	'meta', 'param', 'source', 'track', 'wbr']

// Longest text node shown on its parent's row, as Chrome does for <title>.
const inline_text_limit = 80
const max_text_chars = 200
const max_value_chars = 120

pub struct Segment {
pub:
	text  string
	color u32
}

// shorten collapses whitespace runs, trims the ends and limits text to
// `limit` characters.
pub fn shorten(text string, limit int) string {
	return collapse(text.trim_space(), limit)
}

fn collapse(text string, limit int) string {
	mut builder := strings.new_builder(text.len)
	mut space := false
	for r in text.runes() {
		if r in [` `, `\n`, `\t`, `\r`, `\f`] {
			space = true
			continue
		}
		if space {
			builder.write_rune(` `)
			space = false
		}
		builder.write_rune(r)
	}
	if space {
		builder.write_rune(` `)
	}
	collapsed := builder.str()
	runes := collapsed.runes()
	if runes.len <= limit {
		return collapsed
	}
	return runes[..limit].string() + '…'
}

pub fn is_whitespace_text(node &dom.Node) bool {
	if !node.is_text() {
		return false
	}
	text := node.text_content() or { return true }
	return text.trim_space().len == 0
}

pub fn tag_name(element &dom.Element) string {
	namespace := element.namespace_uri() or { '' }
	if namespace in ['', 'http://www.w3.org/1999/xhtml', 'http://www.w3.org/2000/svg',
		'http://www.w3.org/1998/Math/MathML'] {
		return element.local_name()
	}
	return element.qualified_name_str()
}

pub fn is_void_element(element &dom.Element) bool {
	namespace := element.namespace_uri() or { '' }
	return namespace == 'http://www.w3.org/1999/xhtml' && element.local_name() in void_elements
}

pub struct Attribute {
pub:
	name  string
	value string
}

pub fn attributes(element &dom.Element) []Attribute {
	mut result := []Attribute{}
	list := element.attribute_list() or { return result }
	for attribute in list.attrs {
		result << Attribute{
			name:  attribute.name_
			value: attribute.value_
		}
	}
	return result
}

pub fn open_tag_segments(element &dom.Element) []Segment {
	mut segments := [Segment{'<' + tag_name(element), color_tag}]
	for attribute in attributes(element) {
		segments << Segment{' ' + attribute.name, color_attribute_name}
		if attribute.value != '' || attribute.name !in ['hidden', 'disabled', 'checked', 'selected',
			'async', 'defer', 'autofocus', 'readonly', 'required', 'multiple', 'open'] {
			segments << Segment{'="' + shorten(attribute.value, max_value_chars) + '"', color_attribute_value}
		}
	}
	segments << Segment{'>', color_tag}
	return segments
}

pub fn close_tag_segment(element &dom.Element) Segment {
	return Segment{'</' + tag_name(element) + '>', color_tag}
}

pub fn text_segment(node &dom.Node) Segment {
	text := node.text_content() or { '' }
	return Segment{'"' + shorten(text, max_text_chars) + '"', color_text}
}

pub fn comment_segment(node &dom.Node) Segment {
	data := node.node_value() or { '' }
	return Segment{'<!--' + collapse(data, max_text_chars) + '-->', color_comment}
}

pub fn doctype_segment(node &dom.Node) Segment {
	doctype := node.as_document_type() or { return Segment{'<!DOCTYPE>', color_doctype} }
	mut text := '<!DOCTYPE ${doctype.name_}'
	if doctype.public_id_ != '' {
		text += ' PUBLIC "${doctype.public_id_}"'
	}
	if doctype.system_id_ != '' {
		text += ' "${doctype.system_id_}"'
	}
	return Segment{text + '>', color_doctype}
}

// node_label is the breadcrumb and sidebar name: `div#main.card.wide`.
pub fn node_label(node &dom.Node) string {
	if element := node.as_element() {
		mut label := tag_name(element)
		if id := element.get_attribute('id') {
			if id != '' {
				label += '#' + id
			}
		}
		if classes := element.get_attribute('class') {
			for name in classes.fields() {
				label += '.' + name
			}
		}
		return shorten(label, 60)
	}
	if node.is_text() {
		return '#text'
	}
	if node.is_comment() {
		return '#comment'
	}
	if node.is_shadow_root() {
		return '#shadow-root'
	}
	return node.node_name()
}

// inline_text returns the only child when Chrome would show it on its
// element's own row: a single short text node.
pub fn inline_text(children []&dom.Node) ?&dom.Node {
	if children.len != 1 || !children[0].is_text() {
		return none
	}
	text := children[0].text_content() or { return none }
	if text.contains('\n') || text.runes().len > inline_text_limit {
		return none
	}
	return children[0]
}
