module layout

import css
import html

fn test_document_class_absence_tracks_parser_and_inner_html_created_elements() {
	mut document := html.parse_document('<!doctype html><main id="scope"><p class="ready">text</p></main>')
	defer { document.finalize() }
	assert css.query_selector_all(document.as_node(), '.ready').len == 1
	assert css.query_selector_all(document.as_node(), '.future').len == 0
	mut scope := document.get_element_by_id('scope')?
	scope.set_inner_html('<section class="future"><span class="new-child">next</span></section>')!
	assert css.query_selector_all(document.as_node(), '.future.new-child').len == 0
	assert css.query_selector_all(document.as_node(), '.future').len == 1
	assert css.query_selector_all(document.as_node(), '.new-child').len == 1
	scope.set_inner_html('')!
	assert css.query_selector_all(document.as_node(), '.future').len == 0
}
