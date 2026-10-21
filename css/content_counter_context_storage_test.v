module css

import dom
import platform

fn content_counter_context_style(source string) &ComputedProperties {
	mut style := computed_properties_with_initial_values()
	value := parse_css_value_logic(.content, source) or { panic('invalid content fixture') }
	style.set_property(.content, dom_style_value_from_value_logic(value), .no, .no)
	return style
}

fn test_ordinary_layout_content_keeps_quote_state_without_allocating_empty_registries() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns(dom.namespace_html_uri, 'div')!
	target := dom.AbstractElement.new(element, none)
	style := content_counter_context_style('normal')
	before := platform.thread_arena_usage().used
	for _ in 0 .. 256 {
		styles := content_counter_styles_for_layout(style, target)
		result := styles.resolve_content(style, &target, 7)
		assert result.content_data.type_ == .normal
		assert result.final_quote_nesting_level == 7
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
}

fn test_layout_content_counter_context_matches_existing_evaluation_and_author_dependencies() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	add_document_author_style_sheet(document, '@counter-style probe{system:cyclic;symbols:"PASS";suffix:""}')
	element := document.create_element_ns(dom.namespace_html_uri, 'p')!
	target := dom.AbstractElement.new(element, .before)
	for source in ['normal', 'none', '"label"', 'open-quote "label" close-quote',
		'counter(item, probe)', 'counters(item, ".", probe)', '"label" / counter(item, probe)'] {
		style := content_counter_context_style(source)
		legacy := registered_counter_styles_for_content(style, target)
		expected := style.content(&target, 2, legacy)
		styles := content_counter_styles_for_layout(style, target)
		actual := styles.resolve_content(style, &target, 2)
		assert actual.final_quote_nesting_level == expected.final_quote_nesting_level
		assert actual.content_data.type_ == expected.content_data.type_
		assert actual.content_data.text == expected.content_data.text
		assert actual.content_data.alt_text == expected.content_data.alt_text
		assert actual.content_data.items == expected.content_data.items
		assert actual.content_data.counter_style_dependencies.len == expected.content_data.counter_style_dependencies.len
		if actual.content_data.counter_style_dependencies.len > 0 {
			dependency := actual.content_data.counter_style_dependencies[0] or { panic('lost counter dependency') }
			assert dependency.name() == 'probe'
		}
	}
}
