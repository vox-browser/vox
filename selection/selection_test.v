module selection

import dom

fn test_selection_create_binds_document() {
	document := dom.Document.create(dom.url_about_blank())
	created := selection_create(document)
	assert voidptr(created.document()) == voidptr(document)
	assert created.is_empty()
}
