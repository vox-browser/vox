module html

import dom

fn test_direct_navigation_document_constructs_its_own_global_registry() {
	first := dom.Document.create_and_initialize(.html, 'text/html', &dom.NavigationParams{
		response_url: dom.URL{
			value: 'https://example.test/'
		}
	})!
	second := dom.Document.create_and_initialize(.html, 'text/html', &dom.NavigationParams{
		response_url:   dom.URL{
			value: 'about:srcdoc'
		}
		about_base_url: dom.URL{
			value: 'https://example.test/'
		}
	})!
	assert first.custom_element_registry() != unsafe { nil }
	assert second.custom_element_registry() != unsafe { nil }
	assert first.custom_element_registry() != second.custom_element_registry()
	mut first_registry := unsafe { &CustomElementRegistry(first.custom_element_registry()) }
	assert !first_registry.is_scoped()
	assert first_registry.document_ == first
	first_registry.define('x-first', CustomElementConstructor{ id: 123 }, ElementDefinitionOptions{})!
	assert first_registry.get_definition_with_name_and_local_name('x-first', 'x-first') != none
	second_registry := unsafe { &CustomElementRegistry(second.custom_element_registry()) }
	assert second_registry.get_definition_with_name_and_local_name('x-first', 'x-first') == none
	element := first.create_element('x-first')!
	assert element.custom_element_registry() == first.custom_element_registry()
}
