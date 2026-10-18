module layout

import css
import html

fn test_document_tag_query_tracks_parser_created_and_replaced_markup() {
	mut document := html.parse_document('<!doctype html><main id="root"><p>text</p></main>')
	defer { document.finalize() }
	assert css.query_selector_all(document.as_node(), 'audio, video, use').len == 0
	mut root := document.get_element_by_id('root')?
	root.set_inner_html('<video controls></video><audio></audio><svg><use href="#shape"></use></svg>')!
	assert css.query_selector_all(document.as_node(), 'audio, video, use').len == 3
	assert document.has_seen_element_local_name('audio')
	assert document.has_seen_element_local_name('video')
	assert document.has_seen_element_local_name('use')
	root.set_inner_html('<p>only text</p>')!
	assert css.query_selector_all(document.as_node(), 'audio, video, use').len == 0
	assert css.query_selector_all(document.as_node(), 'p').len == 1
}
