module css

import dom
import platform

fn test_substitution_retires_large_intermediate_custom_property_tokens() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	target := document.create_element('div')!
	mut element := dom.AbstractElement.new(target, none)
	source := '/* discarded substitution input */'.repeat(4096) + '17px'
	element.set_custom_property_data(dom.CSSCustomPropertyData_.create({
		'--size': dom.CSSCustomProperty_{
			value: &dom.CSSStyleValue_{ css_text: source }
		}
	}, none))
	value := parse_css_value_logic(.width, 'var(--size)')?
	assert value is UnresolvedStyleValue
	before := platform.thread_arena_usage().used
	for _ in 0 .. 4 {
		resolved := resolve_unresolved_style_value_for_property(element, .width, value)
		assert resolved.css_text == '17px'
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 32768
	}
}

fn test_substituted_strings_and_attribute_values_survive_workspace_retirement() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut target := document.create_element('div')!
	target.set_attribute_value('data-label', 'attribute label')
	mut element := dom.AbstractElement.new(target, none)
	element.set_custom_property_data(dom.CSSCustomPropertyData_.create({
		'--label': dom.CSSCustomProperty_{
			value: &dom.CSSStyleValue_{ css_text: r'"esc\61 ped"' }
		}
	}, none))
	for source, expected in {
		'var(--label)':     '"escaped"'
		'attr(data-label)': '"attribute label"'
	} {
		value := parse_css_value_logic(.content, source)?
		assert value is UnresolvedStyleValue
		resolved := resolve_unresolved_style_value_for_property(element, .content, value)
		assert resolved.css_text == expected
		assert typed_style_value_logic_from_dom(resolved)?.serialize(.normal) == expected
	}
}

fn test_property_resolution_keeps_enclosing_substitution_cycle_state() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	target := document.create_element('div')!
	element := dom.AbstractElement.new(target, none)
	value := parse_css_value_logic(.width, 'var(--missing, 19px)')?
	assert value is UnresolvedStyleValue
	mut contexts := GuardedSubstitutionContexts{}
	mut enclosing := SubstitutionContext{ dependency_type: .property, first: 'width' }
	contexts.guard(mut enclosing)
	resolved := resolve_unresolved_style_value_for_property_with_context(element, .width, value,
		mut contexts)
	assert typed_style_value_logic_from_dom(resolved)? is GuaranteedInvalidStyleValue
	assert contexts.contexts.len == 1
	assert contexts.contexts[0].is_cyclic
}

fn test_custom_function_lookup_keeps_lazy_document_caches_after_substitution() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	target := document.create_element('div')!
	element := dom.AbstractElement.new(target, none)
	scratch := platform.begin_thread_scratch('test lazy function lookup')
	contexts := GuardedSubstitutionContexts{}
	assert resolve_custom_function_definition(element, '--absent', contexts) == none
	scratch.leave()
	scratch.finish()
	mut scope := css_style_scope_for_document(document)
	assert scope.rule_cache != none
	add_document_author_style_sheet(document, '@function --size() { result: 17px; }')
	value := parse_css_value_logic(.width, '--size()')?
	assert value is UnresolvedStyleValue
	for _ in 0 .. 2 {
		resolved := resolve_unresolved_style_value_for_property(element, .width, value)
		assert resolved.css_text == '17px'
	}
	assert scope.get_function_definition('--size') != none
}
