module css

import dom

fn test_simple_selector_constructor_matches_full_parser_metadata_and_matching() {
	document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('section')!
	element.set_attribute_value('id', 'Main')
	element.set_attribute_value('class', 'card selected -token _item --custom')
	for source in ['section', '.card', '#Main', 'section.card.selected#Main',
		'.-token._item.--custom', ' SECTION.card ', '.missing', 'article.card'] {
		actual := simple_owned_selector(source) or { panic(source) }
		expected := selector_from_text_impl(source)
		assert actual.text() == expected.text()
		assert actual.serialize() == expected.serialize()
		assert actual.specificity() == expected.specificity()
		assert actual.can_use_fast_matches() == expected.can_use_fast_matches()
		assert actual.data_.contained_pseudo_classes == expected.data_.contained_pseudo_classes
		assert selector_matches(actual, element) == selector_matches(expected, element)
	}
}

fn test_simple_selector_constructor_keeps_complex_and_escaped_inputs_on_full_parser() {
	for source in ['', '.', '#', '-1', '.-1', '.card .child', '.card>.child',
		'.card:hover', '*', '[data-x]', 'svg|a', 'β', r'.\63 ard', '.a,.b', '.a/**/.b',
		'.a'.repeat(17)] {
		assert simple_owned_selector(source) == none, source
	}
}
