module html

import dom
import page
import webdriver

@[heap]
struct PromptedCloseOwnerObservation {
mut:
	events      []string
	bare_checks int
}

fn prompted_close_owner_document(address string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.populate_with_html_head_and_body()!
	return document, unsafe { &WindowModel(document.get_window() or { return error('missing actual Window') }) }
}

fn prompted_close_owner_traversable(document &dom.Document) &TraversableNavigable {
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(document.navigable() or { panic('missing actual Navigable') })
	traversable.active_document_ = document
	return traversable
}

fn prompted_close_owner_observe(window &WindowModel, name string, observation &PromptedCloseOwnerObservation, cancel bool) {
	target := unsafe { &dom.EventTarget(window) }
	target.add_event_listener_without_options('beforeunload', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [name, observation, cancel] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut state := unsafe { &PromptedCloseOwnerObservation(observation) }
			state.events << name
			if cancel {
				mut mutable_event := unsafe { &dom.Event(event) }
				mutable_event.prevent_default()
			}
			return dom.js_undefined()
		}
	}))
}

fn prompted_close_owner_dismiss() {
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.before_unload: webdriver.PromptHandlerConfiguration{ handler: .dismiss }
	})
}

fn prompted_close_unsupported_document_hook(_ []&dom.Document) CheckIfUnloadingIsCanceledResult {
	return .continue_
}

fn test_prompted_close_collects_actual_replacement_document_and_ignores_old_local_document_hook() {
	mut original, original_window := prompted_close_owner_document('https://prompted-close-owner.example/original')!
	mut traversable := prompted_close_owner_traversable(original)
	traversable.set_before_unload_hook(prompted_close_unsupported_document_hook)
	url := dom.URL{value: 'https://prompted-close-owner.example/replacement'}
	mut replacement := create_navigation_document_for_page(url, url.origin(), original, original.page())!
	replacement_window := unsafe { &WindowModel(replacement.get_window()?) }
	snapshot := webdriver.user_prompt_handler()
	defer {
		webdriver.set_user_prompt_handler(snapshot or { map[webdriver.PromptType]webdriver.PromptHandlerConfiguration{} })
		original.finalize()
		replacement.finalize()
	}
	prompted_close_owner_dismiss()
	observation := &PromptedCloseOwnerObservation{}
	prompted_close_owner_observe(original_window, 'old', observation, true)
	prompted_close_owner_observe(replacement_window, 'replacement', observation, true)
	assert unsafe { &dom.EventTarget(replacement) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	assert replacement.get_window()?.has_sticky_activation()
	assert voidptr(traversable.active_document_?) == voidptr(original)
	assert voidptr(traversable.active_document()?) == voidptr(replacement)
	traversable.close_top_level_traversable()
	assert traversable.is_closing() && replacement_window.closed()
	assert traversable.traversal_queue_.queue.len == 0
	mut event_loop := main_thread_event_loop()
	assert event_loop.task_queue().last_added_task()?.document() == none
	event_loop.process()
	assert observation.events == ['replacement']
	assert !traversable.is_closing() && !replacement_window.closed()
	assert !traversable.close_steps_have_been_appended_ && traversable.traversal_queue_.queue.len == 0
	assert !replacement.has_been_destroyed() && !traversable.has_been_destroyed()
}

fn test_prompted_close_native_collection_includes_real_current_document_tree_child_and_retains_cancellation() {
	mut original, original_window := prompted_close_owner_document('https://prompted-close-owner.example/tree-original')!
	mut traversable := prompted_close_owner_traversable(original)
	url := dom.URL{value: 'https://prompted-close-owner.example/tree-current'}
	mut current := create_navigation_document_for_page(url, url.origin(), original, original.page())!
	current.populate_with_html_head_and_body()!
	current_window := unsafe { &WindowModel(current.get_window()?) }
	container := current.create_element_ns(namespace_html, 'iframe')!
	body := current.body()?
	mut body_node := body.as_node()
	body_node.append_child(container.as_node())!
	assert current.as_node().is_ancestor_of(container.as_node())
	mut child, child_window := prompted_close_owner_document('https://prompted-close-owner.example/tree-child')!
	mut child_native := child.navigable()?
	child_native.parent_ = current.navigable()?
	child_native.is_top_level_traversable_ = false
	child_native.container_ = container.as_node()
	child_native.container_document_ = current
	snapshot := webdriver.user_prompt_handler()
	defer {
		webdriver.set_user_prompt_handler(snapshot or { map[webdriver.PromptType]webdriver.PromptHandlerConfiguration{} })
		original.finalize()
		current.finalize()
		child.finalize()
	}
	prompted_close_owner_dismiss()
	observation := &PromptedCloseOwnerObservation{}
	prompted_close_owner_observe(original_window, 'old', observation, false)
	prompted_close_owner_observe(current_window, 'current', observation, false)
	prompted_close_owner_observe(child_window, 'child', observation, true)
	assert unsafe { &dom.EventTarget(child) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	assert child.get_window()?.has_sticky_activation()
	assert child.is_fully_active() && current.is_fully_active()
	assert current.inclusive_descendant_navigables().len == 2
	traversable.close_top_level_traversable()
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert observation.events == ['current']
	assert traversable.is_closing() && traversable.traversal_queue_.queue.len == 0
	event_loop.process()
	assert observation.events == ['current', 'child']
	assert !traversable.is_closing() && !current_window.closed()
	assert traversable.traversal_queue_.queue.len == 0 && !traversable.close_steps_have_been_appended_
	assert !current.has_been_destroyed() && !child.has_been_destroyed()
}

fn test_prompted_close_bare_host_keeps_explicit_document_list_compatibility() {
	mut traversable := TraversableNavigable.create_a_new_top_level_traversable('bare-close-owner')!
	mut document := traversable.active_document()?
	defer { document.finalize() }
	observation := &PromptedCloseOwnerObservation{}
	assert traversable.local_navigable_model() == none
	traversable.set_before_unload_hook(fn [observation, document] (documents []&dom.Document) CheckIfUnloadingIsCanceledResult {
		assert documents.len == 1 && voidptr(documents[0]) == voidptr(document)
		mut state := unsafe { &PromptedCloseOwnerObservation(observation) }
		state.bare_checks++
		return .canceled_by_before_unload
	})
	traversable.close_top_level_traversable()
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert observation.bare_checks == 1
	assert !traversable.is_closing() && !traversable.close_steps_have_been_appended_
	assert traversable.traversal_queue_.queue.len == 0 && !document.has_been_destroyed()
}
