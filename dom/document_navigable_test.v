module dom

fn test_navigable_maintains_active_document_back_pointer() {
	mut first_document := Document.create(URL{ value: 'https://first.example/' })
	mut second_document := Document.create(URL{ value: 'https://second.example/' })
	mut navigable := &Navigable{}

	navigable.set_active_document(first_document)
	assert first_document.navigable()? == navigable
	assert first_document.as_node().navigable()? == navigable
	assert navigable.active_document_id()? == first_document.unique_id()

	navigable.set_active_document(second_document)
	assert first_document.navigable() == none
	assert second_document.navigable()? == navigable
	assert navigable.active_document()? == second_document

	navigable.remove_from_all_navigables()
	assert navigable.active_document() == none
	assert second_document.navigable() == none
}
