module css

import dom

// A block has at most one winning record per PropertyID, including a shorthand
// which could not be expanded. Keep intermediate vector growth on the stack;
// typed values and serialized text still belong to the caller's retained arena.
struct CSSOMDeclarationBuilder {
mut:
	properties  [int(PropertyID.container) + 1]CSSStyleProperty
	count       int
	important   Important
	base_url    ?string
}

// The opaque context is borrowed synchronously. Passing the local directly
// avoids V promoting a pointer-receiver builder and its fixed array to the heap.
fn append_parsed_cssom_declaration(context voidptr, property StyleProperty) {
	mut builder := unsafe { &CSSOMDeclarationBuilder(context) }
	builder.important = property.important
	builder.base_url = property.value.base_url
	StyleComputer.for_each_property_expanding_shorthands_with_context(property.property_id,
		property.value, context, append_cssom_longhand)
}

// Publish through an output parameter: returning the array into an owner makes
// current V conservatively heap-promote the borrowed builder as well.
fn publish_cssom_declarations(context voidptr, destination voidptr) {
	builder := unsafe { &CSSOMDeclarationBuilder(context) }
	mut declaration := unsafe { &CSSStyleProperties(destination) }
	mut result := []CSSStyleProperty{len: builder.count}
	for index in 0 .. builder.count {
		result[index] = builder.properties[index]
	}
	declaration.properties = result
}

fn append_cssom_longhand(context voidptr, property_id PropertyID, value &dom.StyleValue) {
	mut builder := unsafe { &CSSOMDeclarationBuilder(context) }
	mut retained_value := unsafe { &dom.StyleValue(value) }
	if retained_value.base_url == none { retained_value.base_url = builder.base_url }
	name := string_from_property_id(property_id)
	for index in 0 .. builder.count {
		existing := builder.properties[index]
		if existing.name != name { continue }
		if existing.important && builder.important == .no { return }
		for next in index + 1 .. builder.count {
			builder.properties[next - 1] = builder.properties[next]
		}
		builder.count--
		break
	}
	builder.properties[builder.count] = CSSStyleProperty{
		name:        name
		value:       dom_style_value_to_css_text(value)
		important:   builder.important == .yes
		style_value: unsafe { value }
	}
	builder.count++
}
