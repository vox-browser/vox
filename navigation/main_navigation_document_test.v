module main

import css
import dom
import html

fn test_compact_navigation_grants_script_readiness_before_inline_import_maps() {
	document := parse_browser_navigation_document_with_response_time('<!doctype html><script type="importmap">{"imports":{"fixture":"./module.js"}}</script><p id="after">parsed</p>', dom.URL{value: 'https://navigation.example/page'}, none, none, 1_000_000)
	assert document.document_ready_to_run_scripts()
	assert document.get_element_by_id('after') != none
}

fn test_browser_navigation_origin_uses_final_document_url_and_preserves_base_url_separately() {
	document := parse_browser_navigation_document('<!doctype html><base href="https://cdn.example/assets/"><p>navigation</p>', dom.URL{
		value: 'https://final.example/page'
	}, dom.URL{
		value: 'https://old.example/'
	}.origin())
	assert document.origin().is_same_origin(dom.URL{ value: 'https://final.example/' }.origin())
	assert document.url.serialize() == 'https://final.example/page'
	assert document.base_url().serialize() == 'https://cdn.example/assets/'
	// CSS subresource requests retain the response origin despite a foreign base.
	environment := css.CSSFetchEnvironmentSettings.from_document(document)
	assert environment.origin_object?.is_same_origin(document.origin())
	assert environment.origin == 'https://final.example'
}

fn test_browser_about_blank_inherits_the_initiator_opaque_identity() {
	initiator := dom.origin_create_opaque()
	document := parse_browser_navigation_document('<p>blank</p>', dom.url_about_blank(), initiator)
	assert document.origin().is_same_origin(initiator)
	initial := parse_browser_navigation_document('<p>initial</p>', dom.url_about_blank(), none)
	assert initial.origin().is_opaque()
	assert !initial.origin().is_same_origin(initiator)
}

fn test_browser_data_and_file_navigation_keep_their_distinct_opaque_origins() {
	initiator := dom.URL{
		value: 'https://old.example/'
	}.origin()
	data := parse_browser_navigation_document('<p>data</p>', dom.URL{
		value: 'data:text/html,fixture'
	}, initiator)
	file := parse_browser_navigation_document('<p>file</p>', dom.URL{
		value: 'file:///tmp/fixture.html'
	}, initiator)
	assert data.origin().is_opaque()
	assert !data.origin().is_opaque_file_origin()
	assert !data.origin().is_same_origin(initiator)
	assert file.origin().is_opaque_file_origin()
	assert !file.origin().is_same_origin(data.origin())
	// Generic string parsing remains a distinct non-navigation entry point.
	standalone := html.parse_document_with_url('<p>standalone</p>', dom.URL{
		value: 'https://untrusted.example/'
	})
	assert standalone.origin().is_opaque()
}
