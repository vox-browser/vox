module css

import dom

// A CSSOM-style read/write inline style for an element, mirroring `element.style`: a live view of the
// element's `style` attribute as a CSSStyleDeclaration. Reads parse the attribute; writes re-serialize
// the parsed block back to the attribute. (This binding lives in css because dom can't depend on css.)
pub struct InlineStyleDeclaration {
	element &dom.Element
}

// The inline style of `element` (analogous to `element.style`).
pub fn inline_style(element &dom.Element) InlineStyleDeclaration {
	return InlineStyleDeclaration{
		element: element
	}
}

fn (s InlineStyleDeclaration) style_attribute() string {
	return s.element.get_attribute('style') or { '' }
}

fn (s InlineStyleDeclaration) write(text string) {
	mut element := unsafe { &dom.Element(s.element) }
	element.set_attribute_value('style', text)
}

// The value of `property_name` in the inline style, or '' when unset (analogous to getPropertyValue).
pub fn (s InlineStyleDeclaration) get_property_value(property_name string) string {
	return parse_css_property_declaration_block_with_parser(s.style_attribute()).get_property_value(property_name)
}

pub fn (s InlineStyleDeclaration) get_property_priority(property_name string) string {
	return parse_css_property_declaration_block_with_parser(s.style_attribute()).get_property_priority(property_name)
}

// Set (or replace) `property_name` in the inline style and write it back to the `style` attribute.
pub fn (s InlineStyleDeclaration) set_property(property_name string, value string) {
	s.set_property_with_priority(property_name, value, '')
}

pub fn (s InlineStyleDeclaration) set_property_with_priority(property_name string, value string, priority string) {
	mut block := parse_css_property_declaration_block_with_parser(s.style_attribute())
	block.set_property(property_name, value, priority) or { return }
	s.write(block.css_text())
}

// Remove `property_name` from the inline style and write the result back to the `style` attribute.
pub fn (s InlineStyleDeclaration) remove_property(property_name string) {
	mut block := parse_css_property_declaration_block_with_parser(s.style_attribute())
	block.remove_property(property_name) or { return }
	s.write(block.css_text())
}

// The serialized inline style (analogous to `element.style.cssText`).
pub fn (s InlineStyleDeclaration) css_text() string {
	return parse_css_property_declaration_block_with_parser(s.style_attribute()).css_text()
}

pub fn (s InlineStyleDeclaration) set_css_text(text string) {
	block := parse_css_property_declaration_block_with_parser(text)
	s.write(block.css_text())
}

// The number of declarations in the inline style.
pub fn (s InlineStyleDeclaration) length() int {
	return parse_css_property_declaration_block_with_parser(s.style_attribute()).length()
}

pub fn (s InlineStyleDeclaration) item(index usize) string {
	return parse_css_property_declaration_block_with_parser(s.style_attribute()).item(index)
}
