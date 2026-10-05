module html

import dom
import page

fn test_source_initial_about_blank_copies_actual_creator_base_before_population_and_keeps_snapshot() {
	creator_owner := page.Page.create(1)!
	child_owner := page.Page.create(1)!
	url := dom.URL{value: 'https://creator-base.example/root/actual.html'}
	mut creator := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(creator_owner) })!
	parse_html_from_a_string(creator, '<!doctype html><html><head><base href="assets/"></head><body><iframe id="embedder"></iframe></body></html>')
	assert creator.base_url().serialize() == 'https://creator-base.example/root/assets/'
	iframe := creator.get_element_by_id('embedder')?
	created := BrowsingContextModel.create_a_new_browsing_context_and_document(unsafe { &dom.Page(child_owner) }, creator, iframe)!
	mut child := created.document
	defer {
		creator.finalize()
		child.finalize()
	}
	assert child.url == dom.url_about_blank() && child.get_is_initial_about_blank()
	assert child.document_element() != none && child.head() != none && child.body() != none
	assert child.is_completely_loaded() && child.document_ready_for_post_load_tasks()
	assert child.get_about_base_url()?.serialize() == 'https://creator-base.example/root/assets/'
	assert child.fallback_base_url().serialize() == 'https://creator-base.example/root/assets/'
	assert child.base_url().serialize() == 'https://creator-base.example/root/assets/'
	assert child.encoding_parse_url('image.png')?.serialize() == 'https://creator-base.example/root/assets/image.png'
	assert child.origin().is_same_origin(creator.origin())
	assert voidptr(child.page()) == voidptr(child_owner)
	assert voidptr(created.browsing_context.active_document()?) == voidptr(child)
	assert voidptr(creator.get_browsing_context()?) != voidptr(child.get_browsing_context()?)
	mut creator_node := creator.as_node()
	creator_node.replace_all(none)
	assert creator.document_element() == none
	parse_html_from_a_string(creator, '<!doctype html><html><head><base href="https://changed-creator.example/later/"></head><body>changed creator</body></html>')
	assert creator.base_url().serialize() == 'https://changed-creator.example/later/'
	assert child.get_about_base_url()?.serialize() == 'https://creator-base.example/root/assets/'
	assert child.encoding_parse_url('after.png')?.serialize() == 'https://creator-base.example/root/assets/after.png'
	mut child_node := child.as_node()
	child_node.replace_all(none)
	parse_html_from_a_string(child, '<!doctype html><html><head><base href="nested/"></head><body>child relative base</body></html>')
	assert child.base_url().serialize() == 'https://creator-base.example/root/assets/nested/'
	assert child.encoding_parse_url('relative.css')?.serialize() == 'https://creator-base.example/root/assets/nested/relative.css'
}

fn test_source_initial_about_blank_without_creator_keeps_null_about_base_and_actual_owner() {
	owner := page.Page.create(1)!
	created := BrowsingContextModel.create_a_new_browsing_context_and_document(unsafe { &dom.Page(owner) }, none, none)!
	mut document := created.document
	defer { document.finalize() }
	assert document.get_about_base_url() == none
	assert document.fallback_base_url() == dom.url_about_blank()
	assert document.base_url() == dom.url_about_blank()
	assert document.url == dom.url_about_blank() && document.get_is_initial_about_blank()
	assert document.document_ready_for_post_load_tasks() && document.is_completely_loaded()
	assert voidptr(document.page()) == voidptr(owner)
	assert voidptr(created.browsing_context.active_document()?) == voidptr(document)
	assert voidptr(created.browsing_context.native_browsing_context_?) == voidptr(document.get_browsing_context()?)
	assert voidptr(created.browsing_context.active_window()?.associated_document()) == voidptr(document)
}
