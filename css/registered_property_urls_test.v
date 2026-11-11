module css

import dom

fn test_registered_url_values_keep_the_declaring_sheet_base_through_substitution() {
	mut document := dom.Document.create(dom.URL{value:'https://urls.test/document/page.html'})
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut element := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut node := document.as_node()
	node.append_child(element.as_node())!
	register_property_for_document(mut document, PropertyDefinition{name:'--main',syntax:'<url>',inherits:true,initial_value:'url(https://urls.test/initial.png)'})!
	register_property_for_document(mut document, PropertyDefinition{name:'--alt',syntax:'<url>',inherits:true,initial_value:'url(https://urls.test/initial.png)'})!
	register_property_for_document(mut document, PropertyDefinition{name:'--ref',syntax:'<url>',inherits:true,initial_value:'url(https://urls.test/initial.png)'})!
	mut main := parse_custom_property_value('url(image.png)')
	main.base_url = 'https://urls.test/main/sheet.css'
	mut alt := parse_custom_property_value('url(image.png)')
	alt.base_url = 'https://urls.test/alt/sheet.css'
	mut reference := parse_custom_property_value('var(--alt)')
	reference.base_url = 'https://urls.test/main/sheet.css'
	mut abstract := dom.AbstractElement.new(element, none)
	abstract.set_custom_property_data(dom.CSSCustomPropertyData_.create({
		'--main':dom.CSSCustomProperty_{value:custom_property_bridge_value(main)},
		'--alt':dom.CSSCustomProperty_{value:custom_property_bridge_value(alt)},
		'--ref':dom.CSSCustomProperty_{value:custom_property_bridge_value(reference)},
	}, none))
	for name, expected in {'--main':'https://urls.test/main/image.png','--alt':'https://urls.test/alt/image.png','--ref':'https://urls.test/alt/image.png'} {
		mut contexts := GuardedSubstitutionContexts{}
		resolved := compute_value_of_custom_property_with_guarded_contexts(abstract, name, mut contexts)
		assert resolved.css_text == 'url("${expected}")', '${name}: ${resolved.css_text}'
	}
}

fn test_image_computation_resolves_document_relative_urls_without_a_retained_parser() {
	mut document := dom.Document.create(dom.URL{value:'https://urls.test/document/page.html'})
	defer { document.finalize() }
	element := document.create_element_ns(dom.namespace_html_uri, 'div')!
	value := ImageStyleValue.create_from_url_string('image.png')
	computed := value.absolutized(ComputationContext{abstract_element:dom.AbstractElement.new(element, none)})
	assert computed.url_.url() == 'https://urls.test/document/image.png'
	assert value.url_.url() == 'image.png'
}

fn test_cached_stylesheet_custom_declarations_keep_independent_bases() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := parse_css_stylesheet_with_params(ParsingParams{document:document}, 'html{--image:url(image.png)}', 'https://urls.test/main/sheet.css')
	second := parse_css_stylesheet_with_params(ParsingParams{document:document}, 'html{--image:url(image.png)}', 'https://urls.test/alt/sheet.css')
	for index, sheet in [first, second] {
		expected := ['https://urls.test/main/sheet.css', 'https://urls.test/alt/sheet.css'][index]
		declaration := sheet.rules.rules[0].style() or { panic('declaration') }
		property := declaration.custom_property('--image') or { panic('custom property') }
		assert property.value.base_url or { '' } == expected
	}
}
