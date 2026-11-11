module html

import dom

fn iframe_load_state_fixture() !(&dom.Document, &dom.Document, &dom.Navigable, &HTMLIFrameElementModel) {
	mut parent := dom.Document.create(dom.URL{ value: 'https://parent.test/' })
	mut child := dom.Document.create(dom.URL{ value: 'https://child.test/' })
	child.set_document_type(.html)
	install_document_fragment_parsing_hook(child)
	frame := parent.create_element_ns(dom.namespace_html_uri, 'iframe')!
	model := html_iframe_element_model_for_dom_element(unsafe { &dom.HTMLIFrameElement(frame) })
	navigable := &dom.Navigable{ container_: frame.as_node(), active_document_: child }
	child.set_navigable(navigable)
	return parent, child, navigable, model
}

fn test_iframe_load_uses_the_live_child_document_open_state() {
	mut parent, mut child, mut navigable, mut iframe := iframe_load_state_fixture()!
	defer {
		navigable.remove_from_all_navigables()
		child.finalize()
		parent.finalize()
	}
	iframe.event_target().add_event_listener_without_options('load', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [child] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert child.is_iframe_load_in_progress()
			mut document := unsafe { &dom.Document(child) }
			document.open() or { panic(err) }
			assert document.should_mute_iframe_load()
			return dom.js_undefined()
		}
	}))
	assert iframe.container.content_navigable() == none
	iframe.run_iframe_load_event_steps()
	assert iframe.event_count('load') == 1
	assert !child.is_iframe_load_in_progress()
	assert child.should_mute_iframe_load()
	iframe.run_iframe_load_event_steps()
	assert iframe.event_count('load') == 1

	child.open()!
	assert !child.should_mute_iframe_load()
	iframe.run_iframe_load_event_steps()
	assert iframe.event_count('load') == 2
	assert !child.is_iframe_load_in_progress()
}

fn test_iframe_load_keeps_the_dispatch_document_and_skips_navigation_gaps() {
	mut parent, mut child, mut navigable, mut iframe := iframe_load_state_fixture()!
	mut replacement := dom.Document.create(dom.URL{ value: 'https://replacement.test/' })
	defer {
		navigable.remove_from_all_navigables()
		replacement.finalize()
		child.finalize()
		parent.finalize()
	}
	iframe.event_target().add_event_listener_without_options('load', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [child, replacement, navigable] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert child.is_iframe_load_in_progress()
			mut current := unsafe { &dom.Navigable(navigable) }
			current.set_active_document(replacement)
			assert !replacement.is_iframe_load_in_progress()
			return dom.js_undefined()
		}
	}))
	iframe.run_iframe_load_event_steps()
	assert iframe.event_count('load') == 1
	assert !child.is_iframe_load_in_progress()
	assert !replacement.is_iframe_load_in_progress()

	navigable.set_active_document(none)
	iframe.run_iframe_load_event_steps()
	assert iframe.event_count('load') == 1
}

fn test_standalone_iframe_model_still_dispatches_after_child_creation() {
	mut iframe := HTMLIFrameElementModel.create(dom.URL{ value: 'https://parent.test/' }, dom.Origin{ value: 'https://parent.test' })
	iframe.run_iframe_load_event_steps()
	assert iframe.event_count('load') == 0
	iframe.container.create_new_child_navigable()
	iframe.run_iframe_load_event_steps()
	assert iframe.event_count('load') == 1
	iframe.removed_from_document()
}
