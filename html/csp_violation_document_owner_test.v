module html

import contentsecuritypolicy
import dom
import highresolutiontime
import page
import url as liburl

@[heap]
struct SourceCSPViolationOwnerObservation {
mut:
	targets []voidptr
}

fn source_csp_owner_window(owner &page.Page, address string) !(&dom.Document, &WindowModel) {
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	window := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(window) }
}

fn source_csp_observe_violation(target &dom.EventTarget, observation &SourceCSPViolationOwnerObservation) {
	target.add_event_listener_without_options('securitypolicyviolation', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert event.type_name() == 'securitypolicyviolation' && event.is_trusted()
			mut observed := unsafe { &SourceCSPViolationOwnerObservation(observation) }
			observed.targets << voidptr(event.target() or { panic('actual violation target') })
			return dom.js_undefined()
		}
	}))
}

fn source_csp_queue_actual_base_violation(mut global contentsecuritypolicy.GlobalContext) {
	base := liburl.parse('https://blocked-base.test/') or { panic('actual base URL') }
	assert contentsecuritypolicy.is_base_allowed_for_document(mut global, base) == .blocked
}

fn source_csp_execute_violation_task(loop &EventLoop) {
	mut queue := loop.task_queue()
	task := queue.last_added_task() or { panic('queued actual violation task') }
	assert task.source() == .unspecified && task.document() == none && task.is_runnable()
	runnable := queue.take_first_runnable_matching(fn [task] (candidate &Task) bool {
		return candidate.id == task.id
	}) or { panic('runnable actual violation task') }
	runnable.execute()
}

fn test_source_queued_csp_violation_reads_actual_window_document_when_task_executes() {
	owner := page.Page.create(1)!
	mut original, mut window := source_csp_owner_window(owner, 'https://csp-owner.test/original')!
	mut replacement, _ := source_csp_owner_window(owner, 'https://csp-owner.test/replacement')!
	defer {
		window.set_associated_document(original)
		original.finalize()
		replacement.finalize()
	}
	mut settings := window.environment_settings_.settings
	loop := EventLoop.create(.window)
	settings.responsible_event_loop_ = loop
	settings.set_policy_container(&PolicyContainer{
		csp_list: [parse_response_csp_policy("base-uri 'none'", .enforce, original.origin())]
	})
	observation := &SourceCSPViolationOwnerObservation{}
	source_csp_observe_violation(unsafe { &dom.EventTarget(original) }, observation)
	source_csp_observe_violation(unsafe { &dom.EventTarget(replacement) }, observation)
	mut global := settings.fetch_request_client_csp_global()
	source_csp_queue_actual_base_violation(mut global)
	assert observation.targets.len == 0
	window.set_associated_document(replacement)
	mut old_navigable := original.navigable()?
	old_navigable.set_active_document(none)
	assert !original.is_fully_active()
	source_csp_execute_violation_task(loop)
	assert observation.targets == [voidptr(replacement)]
}

fn test_source_csp_global_created_before_document_targets_later_actual_window_document() {
	owner := page.Page.create(1)!
	url := dom.URL{value: 'https://csp-owner.test/before-document'}
	context := BrowsingContextModel.create_for_page(unsafe { &dom.Page(owner) }, none, '')
	window := create_window_global_before_document(context, url, url.origin(), url, url.origin())
	mut settings := window.environment_settings_.settings
	loop := EventLoop.create(.window)
	settings.responsible_event_loop_ = loop
	settings.set_policy_container(&PolicyContainer{
		csp_list: [parse_response_csp_policy("base-uri 'none'", .enforce, url.origin())]
	})
	assert settings.responsible_document() == none
	mut global := settings.fetch_request_client_csp_global()
	mut document := construct_document_in_global(window, context, url, url.origin())!
	defer { document.finalize() }
	observation := &SourceCSPViolationOwnerObservation{}
	source_csp_observe_violation(unsafe { &dom.EventTarget(document) }, observation)
	source_csp_queue_actual_base_violation(mut global)
	assert observation.targets.len == 0
	source_csp_execute_violation_task(loop)
	assert observation.targets == [voidptr(document)]
}

fn test_source_queued_csp_violation_keeps_actual_worker_global_target_and_null_document() {
	owner := page.Page.create(1)!
	mut document, window := source_csp_owner_window(owner, 'https://csp-owner.test/outside')!
	defer { document.finalize() }
	mut realm := &ScriptingRealm{}
	mut worker := WorkerGlobalScope.create(dom.URL{value: 'https://csp-owner.test/worker.js'}, .classic, 'worker', realm)
	defer { worker.close_a_worker() }
	worker_settings := WorkerEnvironmentSettingsObject.setup(worker, mut realm, window.environment_settings_.settings.serialize(), highresolutiontime.unsafe_shared_current_time())
	mut settings := worker_settings.settings
	settings.set_policy_container(&PolicyContainer{
		csp_list: [parse_response_csp_policy("base-uri 'none'", .enforce, worker.url().origin())]
	})
	observation := &SourceCSPViolationOwnerObservation{}
	source_csp_observe_violation(worker.this_impl(), observation)
	mut global := settings.fetch_request_client_csp_global()
	source_csp_queue_actual_base_violation(mut global)
	assert observation.targets.len == 0
	source_csp_execute_violation_task(worker.event_loop)
	assert observation.targets == [voidptr(worker.this_impl())]
}

fn test_inline_csp_check_queues_the_real_element_and_rechecks_its_connection() {
	owner := page.Page.create(1)!
	mut document, window := source_csp_owner_window(owner, 'https://csp-owner.test/inline')!
	defer { document.finalize() }
	install_document_csp_hook(document)
	mut settings := window.environment_settings_.settings
	loop := EventLoop.create(.window)
	settings.responsible_event_loop_ = loop
	settings.set_policy_container(&PolicyContainer{csp_list:[parse_response_csp_policy("script-src-attr 'none'", .enforce, document.origin())]})
	mut root := document.create_element('html')!
	document.as_node().append_child(root.as_node())!
	mut button := document.create_element('button')!
	root.as_node().append_child(button.as_node())!
	observation := &SourceCSPViolationOwnerObservation{}
	source_csp_observe_violation(unsafe { &dom.EventTarget(document) }, observation)
	assert document.should_block_inline_content(button, 'script-attribute', 'void(0)')
	assert observation.targets.len == 0
	source_csp_execute_violation_task(loop)
	assert observation.targets == [voidptr(button)]
	assert document.should_block_inline_content(button, 'script-attribute', 'void(0)')
	button.as_node().remove(false)
	source_csp_execute_violation_task(loop)
	assert observation.targets == [voidptr(button), voidptr(document)]
}
