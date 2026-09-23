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

fn test_child_document_fully_active_state_follows_parent_navigable() {
	mut parent_document := Document.create(URL{ value: 'https://parent.example/' })
	mut child_document := Document.create(URL{ value: 'https://child.example/' })
	mut parent_navigable := &Navigable{
		is_top_level_traversable_: true
	}
	mut child_navigable := &Navigable{
		parent_: parent_navigable
		// A logical parent can be remote, so no local container document is
		// required for the fully-active decision.
		container_document_: none
	}
	parent_navigable.set_active_document(parent_document)
	child_navigable.set_active_document(child_document)

	assert parent_document.is_fully_active()
	assert child_document.is_fully_active()

	parent_navigable.set_active_document(none)
	assert !child_document.is_fully_active()
}

fn test_navigable_exposes_active_document_url_and_origin() {
	document := Document.create(URL{ value: 'https://example.test/path' })
	mut navigable := &Navigable{}
	assert navigable.active_document_url() == none
	assert navigable.active_document_origin() == none

	navigable.set_active_document(document)
	assert navigable.active_document_url()? == document.url
	assert navigable.active_document_origin()?.is_same_origin(document.origin())
	assert navigable.active_document_is(document)
	other_document := Document.create(URL{ value: 'https://other.test/' })
	assert !navigable.active_document_is(other_document)

	navigable.set_active_document(none)
	assert navigable.active_document_url() == none
	assert navigable.active_document_origin() == none
	assert !navigable.active_document_is(document)
}

fn test_traversable_navigable_walks_the_logical_parent_chain() {
	top := &Navigable{
		is_top_level_traversable_: true
	}
	child := &Navigable{
		parent_: top
		traversable_navigable_: top
	}
	grandchild := &Navigable{
		parent_: child
		// A cached root does not make a child a traversable itself.
		traversable_navigable_: top
	}

	assert top.is_traversable()
	assert !child.is_traversable()
	assert !grandchild.is_traversable()
	assert grandchild.traversable_navigable()? == top
	assert grandchild.top_level_traversable() == top
}
