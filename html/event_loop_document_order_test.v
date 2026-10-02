module html

import dom

fn ordered_documents(event_loop &EventLoop) []&dom.Document {
	return event_loop.documents_in_this_event_loop_matching(fn (_ &dom.Document) bool {
		return true
	})
}

fn order_test_navigable_change(target voidptr, _ &dom.Document) {
	mut event_loop := unsafe { &EventLoop(target) }
	event_loop.document_navigable_did_change()
}

fn order_test_attach(document &dom.Document, parent ?&dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_navigable(&dom.Navigable{
		active_document_: document
		container_document_: parent
	})
}

fn test_document_order_visits_registered_ancestors_before_descendants() {
	mut event_loop := EventLoop.create(.window)
	grandparent := dom.Document.create(dom.url_about_blank())
	parent := dom.Document.create(dom.url_about_blank())
	child := dom.Document.create(dom.url_about_blank())
	unrelated := dom.Document.create(dom.url_about_blank())
	order_test_attach(parent, grandparent)
	order_test_attach(child, parent)
	event_loop.register_document(child)
	event_loop.register_document(unrelated)
	event_loop.register_document(parent)
	event_loop.register_document(grandparent)
	assert ordered_documents(event_loop) == [grandparent, parent, child, unrelated]
	assert ordered_documents(event_loop) == [grandparent, parent, child, unrelated]
}

fn test_navigable_change_invalidates_sorted_documents_and_absent_containers_are_skipped() {
	mut event_loop := EventLoop.create(.window)
	mut first := dom.Document.create(dom.url_about_blank())
	second := dom.Document.create(dom.url_about_blank())
	unregistered_parent := dom.Document.create(dom.url_about_blank())
	first.set_lifecycle_hook(dom.DocumentLifecycleHook{
		target: voidptr(event_loop)
		document_navigable_did_change: order_test_navigable_change
	})
	event_loop.register_document(first)
	event_loop.register_document(second)
	assert ordered_documents(event_loop) == [first, second]
	order_test_attach(first, second)
	assert ordered_documents(event_loop) == [second, first]
	order_test_attach(first, unregistered_parent)
	assert ordered_documents(event_loop) == [second, first]
	first.set_navigable(none)
	assert ordered_documents(event_loop) == [second, first]
}

fn test_document_order_terminates_for_a_cyclic_container_relationship() {
	mut event_loop := EventLoop.create(.window)
	first := dom.Document.create(dom.url_about_blank())
	second := dom.Document.create(dom.url_about_blank())
	order_test_attach(first, second)
	order_test_attach(second, first)
	event_loop.register_document(first)
	event_loop.register_document(second)
	assert ordered_documents(event_loop) == [second, first]
}
