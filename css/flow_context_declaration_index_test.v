module css

import dom

// Compare the indexed declaration path with the full property walk. Both
// feed the same cascade machinery, including importance, substitution and all.
fn flow_context_compare_declaration(element dom.AbstractElement, declaration &CSSStyleProperties) {
	properties := declaration_style_properties(declaration)
	for important in [Important.no, .yes] {
		mut indexed := CascadedProperties.new()
		mut ordinary := CascadedProperties.new()
		cascade_one_declaration(mut indexed, element, declaration, none, .author,
			important, none, none, [.writing_mode, .direction])
		apply_property_list_to_cascade(mut ordinary, element, properties, .author,
			important, none, voidptr(declaration), none, none, [.writing_mode, .direction])
		for id in [PropertyID.writing_mode, .direction] {
			actual := indexed.property(id)
			expected := ordinary.property(id)
			if value := expected {
				assert (actual or { panic('missing property') }).css_text == value.css_text
			} else {
				assert actual == none
			}
		}
	}
}

fn test_flow_context_index_preserves_full_cascade_and_cssom_replacement() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('div')!
	abstract_element := dom.AbstractElement.new(element, none)
	for source in [
		'margin:1px; padding:2px; border:1px solid red; color:blue',
		'writing-mode:vertical-rl; direction:rtl!important; margin-inline-start:3px',
		'all:initial; writing-mode:vertical-lr!important; direction:ltr',
		'all:var(--missing, inherit); direction:var(--direction, rtl); margin:var(--missing, 2px)',
		'writing-mode:revert-layer; direction:unset; border:var(--missing, 1px solid red)',
	] {
		mut declaration := parse_css_property_declaration_block(ParsingParams{ document: document }, source)
		flow_context_compare_declaration(abstract_element, declaration)
		declaration.set_property('writing-mode', 'horizontal-tb', 'important')!
		declaration.set_property('direction', 'ltr', '')!
		flow_context_compare_declaration(abstract_element, declaration)
		declaration.remove_property('writing-mode')!
		declaration.remove_property('direction')!
		flow_context_compare_declaration(abstract_element, declaration)
	}
}
