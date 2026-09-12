@[has_globals]
module html

import dom

__global navigation_requests []EmbeddedNavigationRequest

fn embedded_navigation_hook(request EmbeddedNavigationRequest) ! {
	navigation_requests << request
}

fn embedded_object_fetch(url dom.URL) !ObjectResourceResponse {
	if url.serialize().ends_with('.png') {
		return ObjectResourceResponse{
			content_type: 'image/png'
			bitmap:       &dom.ImmutableBitmap_{
				width:  20
				height: 10
				pitch:  80
				data:   []u8{len: 800}
			}
		}
	}
	if url.serialize().ends_with('.html') {
		return ObjectResourceResponse{
			content_type: 'text/html'
			body:         '<p>child</p>'.bytes()
		}
	}
	return error('network error')
}

fn test_navigable_container_origin_navigation_and_destruction() {
	mut container := NavigableContainerModel.create(dom.URL{ value: 'https://example.test/a/' }, dom.Origin{
		value: 'https://example.test'
	})
	container.set_name('frame')
	container.set_src('child.html')
	container.set_navigation_hook(embedded_navigation_hook)
	mut navigable := container.create_new_child_navigable()
	assert navigable.target_name == 'frame'
	assert container in navigable_container_all_instances()
	assert navigable_container_navigable_container_with_content_navigable(navigable)? == container
	assert navigable_container_content_window(container) != none
	assert !navigable_container_content_navigable_has_session_history_entry_and_ready_for_navigation(container)
	navigable_container_set_content_navigable_has_session_history_entry_and_ready_for_navigation(container)
	assert navigable_container_content_navigable_has_session_history_entry_and_ready_for_navigation(container)
	navigable.has_pending_navigations = true
	assert container.shared_attribute_processing_steps(.yes, []) == none
	navigable.has_pending_navigations = false
	navigable.ongoing_navigation_is_navigation = true
	assert container.shared_attribute_processing_steps(.yes, []) == none
	navigable.ongoing_navigation_is_navigation = false
	url := container.shared_attribute_processing_steps(.yes, [])?
	container.navigate_an_iframe_or_frame(url, .origin, none, .yes)!
	assert navigation_requests.last().url.serialize() == 'https://example.test/a/child.html'
	assert container.content_document() != none
	mut child := navigable.active_document
	child.origin = dom.Origin{
		value: 'https://cross-origin.test'
	}
	assert container.content_document() == none
	assert container.content_document_without_origin_check() != none
	navigable.active_document = unsafe { nil }
	assert container.content_document() == none
	container.destroy_the_child_navigable()
	assert container.content_navigable() == none
}

fn test_iframe_src_change_does_not_replace_incomplete_document_history() {
	mut container := NavigableContainerModel.create(dom.URL{ value: 'https://example.test/' }, dom.Origin{ value: 'https://example.test' })
	mut navigable := container.create_new_child_navigable()
	assert !navigable.active_document.completely_loaded
	container.navigate_an_iframe_or_frame(dom.URL{ value: 'https://example.test/initial' }, .origin, none, .yes)!
	assert navigable.last_navigation_replaced_current_entry
	assert navigable.history.len == 1
	container.navigate_an_iframe_or_frame(dom.URL{ value: 'https://example.test/changed' }, .origin, none, .no)!
	assert !navigable.last_navigation_replaced_current_entry
	assert navigable.history.map(it.serialize()) == [
		'https://example.test/initial',
		'https://example.test/changed',
	]
}

fn test_dom_load_event_delay_uses_navigable_container_algorithm() {
	mut document := dom.Document.create(dom.URL{ value: 'https://parent.test/' })
	document.set_origin(dom.Origin{ value: 'https://parent.test' })
	iframe_element := unsafe { &dom.HTMLIFrameElement(document.create_element('iframe')!) }
	mut iframe := html_iframe_element_model_for_dom_element(iframe_element)
	dom_element := unsafe { &dom.Element(iframe_element) }

	assert dom_element.as_node().currently_delays_the_load_event()
	mut child := iframe.container.create_new_child_navigable()
	assert dom_element.as_node().currently_delays_the_load_event()
	iframe.container.mark_content_navigable_ready()
	assert dom_element.as_node().currently_delays_the_load_event()

	child.active_document.ready_for_post_load_tasks = true
	assert !dom_element.as_node().currently_delays_the_load_event()
	child.is_delaying_load_events = true
	assert dom_element.as_node().currently_delays_the_load_event()
	child.is_delaying_load_events = false
	child.active_document.anything_delays_load_event = true
	assert dom_element.as_node().currently_delays_the_load_event()

	iframe.container.set_potentially_delays_the_load_event(false)
	assert !dom_element.as_node().currently_delays_the_load_event()
}

fn test_iframe_srcdoc_sandbox_lazy_loading_and_events() {
	mut iframe := HTMLIFrameElementModel.create(dom.URL{ value: 'https://example.test/' }, dom.Origin{
		value: 'https://example.test'
	})
	iframe.set_navigation_hook(embedded_navigation_hook)
	iframe.set_sandbox('allow-scripts')
	iframe.set_loading_lazy(true)
	iframe.set_srcdoc('<h1>Hello</h1>')
	iframe.post_connection(true, [])!
	assert !iframe.container.content_navigable_has_session_history_entry_and_ready_for_navigation()
	mut event_loop := main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks()
		&& !iframe.container.content_navigable_has_session_history_entry_and_ready_for_navigation() {
		event_loop.process()
	}
	assert iframe.container.content_navigable_has_session_history_entry_and_ready_for_navigation()
	assert iframe.current_navigation_was_lazy_loaded()
	assert iframe.event_count('load') == 0
	assert iframe.iframe_sandboxing_flag_set().contains(.sandboxed_origin)
	assert !iframe.iframe_sandboxing_flag_set().contains(.sandboxed_scripts)
	iframe.resume_lazy_load()
	assert iframe.event_count('load') == 1
	navigable := iframe.container.content_navigable()?
	assert navigable.active_document.url.serialize() == 'about:srcdoc'
	assert navigable.last_srcdoc? == '<h1>Hello</h1>'
	iframe.removed_from_document()
	assert iframe.container.content_navigable() == none
}

fn test_iframe_applies_sandbox_before_creating_its_initial_document() {
	owner_origin := dom.Origin{ value: 'https://example.test' }
	mut iframe := HTMLIFrameElementModel.create(dom.URL{ value: 'https://example.test/' }, owner_origin)
	iframe.set_sandbox('allow-scripts')
	iframe.post_connection(true, [])!
	initial_document := iframe.container.content_navigable()?.active_document
	assert initial_document.active_sandboxing_flags.contains(.sandboxed_origin)
	assert !initial_document.active_sandboxing_flags.contains(.sandboxed_scripts)
	assert !initial_document.origin.is_same_origin(owner_origin)
	iframe.removed_from_document()
}

fn test_destroyed_child_is_not_marked_ready_by_deferred_creation_bookkeeping() {
	mut container := NavigableContainerModel.create(dom.URL{ value: 'https://example.test/' }, dom.Origin{
		value: 'https://example.test'
	})
	child := container.create_new_child_navigable()
	container.destroy_the_child_navigable()
	mut event_loop := main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}
	assert child.has_been_destroyed
	assert !child.has_session_history_entry_and_ready
	assert container.content_navigable() == none
}

fn test_concrete_iframe_attributes_tab_index_and_removal() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/root/' })
	mut iframe_dom_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'iframe') or {
		panic(err)
	}
	iframe_element := unsafe { &dom.HTMLIFrameElement(iframe_dom_element) }
	mut model := html_iframe_element_model_for_dom_element(iframe_element)
	model.set_navigation_hook(embedded_navigation_hook)
	model.post_connection(true, [])!
	assert model.container.content_navigable() != none
	assert iframe_dom_element.tab_index() == 0
	assert html_iframe_element_default_tab_index_value(iframe_element) == 0

	html_iframe_element_attribute_changed(iframe_element, 'sandbox', none, 'allow-scripts', none)
	assert model.iframe_sandboxing_flag_set().contains(.sandboxed_origin)
	assert !model.iframe_sandboxing_flag_set().contains(.sandboxed_scripts)
	html_iframe_element_attribute_changed(iframe_element, 'marginwidth', none, '8', none)
	assert model.container.content_document_without_origin_check()?.body_needs_style_update
	html_iframe_element_attribute_changed(iframe_element, 'srcdoc', none, '<p>child</p>', none)
	assert model.container.content_document_without_origin_check()?.url.serialize() == 'about:srcdoc'

	document_node := unsafe { &dom.Node(document) }
	html_iframe_element_removed_from(iframe_element, none, document_node)
	assert model.container.content_navigable() == none
}

fn test_object_representation_image_document_and_fallback() {
	mut object := HTMLObjectElementModel.create(dom.URL{ value: 'https://example.test/' }, dom.Origin{
		value: 'https://example.test'
	})
	object.set_fetch_hook(embedded_object_fetch)
	object.set_data('/image.png')
	object.run_object_representation_steps()
	assert object.representation() == .image
	assert object.image_data()?.width == 20
	assert object.event_count('load') == 1

	object.set_data('/child.html')
	object.run_object_representation_steps()
	assert object.representation() == .content_navigable
	assert object.container.content_document_without_origin_check()?.content_type == 'text/html'

	object.set_data('/missing.bin')
	object.run_object_representation_steps()
	assert object.representation() == .children
	assert object.event_count('error') == 1
}

fn test_concrete_object_element_representation_form_lifecycle_and_image_provider() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/root/' })
	mut navigable := &dom.Navigable{
		active_document_:          document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	mut object_dom := document.create_element_ns('http://www.w3.org/1999/xhtml', 'object') or {
		panic(err)
	}
	object_dom.set_attribute_value('data', '/image.png')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(object_dom.as_node()) or { panic(err) }
	object := unsafe { &dom.HTMLObjectElement(object_dom) }
	mut model := html_object_element_model_for_dom_element(object)
	model.set_fetch_hook(embedded_object_fetch)
	html_object_element_queue_element_task_to_run_object_representation_steps(object)
	assert model.representation() == .image
	assert html_object_element_data(object) == 'https://example.test/image.png'
	assert html_object_element_is_image_available(object)
	assert html_object_element_intrinsic_width(object)? == 20
	assert html_object_element_intrinsic_height(object)? == 10
	assert html_object_element_intrinsic_aspect_ratio(object)? == 2.0
	assert html_object_element_current_image_bitmap_sized(object, 40, 20)?.width == 20
	assert html_object_element_default_tab_index_value(object) == 0
	assert object_dom.tab_index() == 0
	assert model.event_count('load') == 1

	html_object_element_set_data(object, '/child.html')
	assert model.representation() == .content_navigable
	assert model.container.content_navigable() != none
	html_object_element_form_associated_element_was_removed(object, document_node)
	assert model.container.content_navigable() == none
}

fn test_embed_and_object_presentational_hints() {
	hints := embedded_presentational_hints({
		'align':  'CENTER'
		'width':  '320'
		'height': '200'
		'hspace': '4'
		'vspace': '6'
		'border': '2'
	}, true)
	assert hints.text_align? == 'center'
	assert hints.width? == 320
	assert hints.height? == 200
	assert hints.margin_left? == 4
	assert hints.margin_top? == 6
	assert hints.border_width? == 2
}
