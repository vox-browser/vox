module css

import dom

// A CSSOM-style read/write inline style for an element, mirroring `element.style`.
pub struct InlineStyleDeclaration {
	element &dom.Element
}

// The inline style of `element` (analogous to `element.style`).
pub fn inline_style(element &dom.Element) InlineStyleDeclaration {
	return InlineStyleDeclaration{
		element: element
	}
}

fn (s InlineStyleDeclaration) declaration() &CSSStyleProperties {
	mut element := unsafe { &dom.Element(s.element) }
	element.style_for_bindings()
	return inline_style_for_abstract_element(dom.AbstractElement.new(element, none)) or {
		panic('element.style must have a retained CSSStyleProperties object')
	}
}

// The value of `property_name` in the inline style, or '' when unset (analogous to getPropertyValue).
pub fn (s InlineStyleDeclaration) get_property_value(property_name string) string {
	return s.declaration().get_property_value(property_name)
}

pub fn (s InlineStyleDeclaration) get_property_priority(property_name string) string {
	return s.declaration().get_property_priority(property_name)
}

// Set (or replace) `property_name` in the inline style and write it back to the `style` attribute.
pub fn (s InlineStyleDeclaration) set_property(property_name string, value string) {
	s.set_property_with_priority(property_name, value, '')
}

pub fn (s InlineStyleDeclaration) set_property_with_priority(property_name string, value string, priority string) {
	mut block := s.declaration()
	block.set_property(property_name, value, priority) or { return }
}

// Remove `property_name` from the inline style and write the result back to the `style` attribute.
pub fn (s InlineStyleDeclaration) remove_property(property_name string) {
	mut block := s.declaration()
	block.remove_property(property_name) or { return }
}

// The serialized inline style (analogous to `element.style.cssText`).
pub fn (s InlineStyleDeclaration) css_text() string {
	return s.declaration().css_text()
}

pub fn (s InlineStyleDeclaration) set_css_text(text string) {
	mut block := s.declaration()
	block.set_css_text(text) or { return }
}

// The number of declarations in the inline style.
pub fn (s InlineStyleDeclaration) length() int {
	return s.declaration().length()
}

pub fn (s InlineStyleDeclaration) item(index uint) string {
	return s.declaration().item(index)
}
