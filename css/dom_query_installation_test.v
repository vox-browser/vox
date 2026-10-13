module css

import dom

fn test_style_computer_lookup_retains_document_selector_parser_and_cache() {
	document := dom.Document.create(dom.url_about_blank())
	install_document_selector_query_hook(document)
	first := document.selector_query_hook() or { panic('missing hook') }
	mut state := unsafe { &DocumentSelectorQueryState(first.target) }
	assert state.parse('.target') != none
	assert state.parse('[') == none
	computer := css_style_computer_for(document)
	assert voidptr(css_style_computer_for(document)) == voidptr(computer)
	install_document_selector_query_hook(document)
	second := document.selector_query_hook() or { panic('missing retained hook') }
	assert second.target == first.target
	assert '.target' in state.parsed
	assert '[' in state.invalid
}

fn installation_test_foreign_selector_validate(_ voidptr, _ string) bool {
	return false
}

fn test_installation_replaces_a_different_selector_bridge() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_selector_query_hook(dom.DocumentSelectorQueryHook{
		validate: installation_test_foreign_selector_validate
	})
	install_document_selector_query_hook(document)
	hook := document.selector_query_hook() or { panic('missing replacement hook') }
	assert hook.target != unsafe { nil }
	assert hook.validate(hook.target, '.target')
	assert !hook.validate(hook.target, '[')
}
