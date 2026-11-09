module browserjs

import contentsecuritypolicy as csp
import dom
import html
import loader
import page

@[heap]
struct WorkerCSPObservation {
mut:
	directives []string
	blocked []string
	dispositions []csp.Disposition
}

fn worker_constructor_document(url dom.URL) !&dom.Document {
 owner := page.Page.create(1)!
 document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
 html.parse_html_from_a_string(document, '<!doctype html>')
 mut active := &dom.Navigable{active_document_: document, is_top_level_traversable_: true}
 active.traversable_navigable_ = active
 document.set_cached_navigable(active)
 assert document.is_fully_active()
 return document
}

fn observe_worker_constructor_csp(document &dom.Document) &WorkerCSPObservation {
	observation := &WorkerCSPObservation{}
	target := unsafe { &dom.EventTarget(document) }
	target.add_event_listener_without_options('securitypolicyviolation', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			actual := unsafe { &csp.SecurityPolicyViolationEvent(event) }
			mut result := unsafe { &WorkerCSPObservation(observation) }
			assert actual.is_trusted()
			result.directives << actual.effective_directive()
			result.blocked << actual.blocked_uri()
			result.dispositions << actual.disposition()
			return dom.js_undefined()
		}
	}))
	return observation
}

fn test_worker_constructors_enforce_creator_csp_and_queue_actual_document_violations() {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{value: 'https://worker-constructor-csp.test/page'}
	for policy in ["worker-src 'none'", "script-src 'self' 'unsafe-inline'", "script-src * 'unsafe-inline'"] {
		mut document := worker_constructor_document(url)!
		mut runtime := Runtime.create()
		defer { runtime.close(); document.finalize() }
		mut settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		settings.set_policy_container(&html.PolicyContainer{csp_list: [html.parse_response_csp_policy(policy, .enforce, url.origin())]})
		observed := observe_worker_constructor_csp(document)
		mut host := WorkerHost.create(settings, '/nonexistent-csp-worker')!
		host.install(mut runtime)!
		runtime.evaluate_host('globalThis.failures=[];const dedicated=new Worker("data:text/javascript,postMessage(1)"),shared=new SharedWorker("data:text/javascript,onconnect=()=>{}");dedicated.onerror=event=>failures.push(event.type);shared.onerror=event=>failures.push(event.type);')!
		assert observed.directives.len == 0
		for _, remote in host.workers { assert remote.process == none }
		mut queue := settings.responsible_event_loop().task_queue()
		for {
			task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() in [.unspecified, .posted_message] }) or { break }
			task.execute()
		}
		assert observed.directives == ['worker-src', 'worker-src']
		assert observed.blocked == ['data', 'data']
		assert observed.dispositions == [csp.Disposition.enforce, .enforce]
		assert runtime.evaluate_host('failures.length')! == '2'
	}
}

fn test_worker_constructor_report_only_policy_reports_without_blocking() {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{value: 'https://worker-constructor-csp.test/page'}
	mut document := worker_constructor_document(url)!
	defer { document.finalize() }
	mut settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	settings.set_policy_container(&html.PolicyContainer{csp_list: [html.parse_response_csp_policy("worker-src 'none'", .report, url.origin())]})
	observed := observe_worker_constructor_csp(document)
	assert html.worker_constructor_csp_allows(settings, dom.URL{value: 'data:text/javascript,void 0'}, false)
	assert observed.directives.len == 0
	mut queue := settings.responsible_event_loop().task_queue()
	for {
	 task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .unspecified }) or { break }
	 task.execute()
	}
	assert observed.directives == ['worker-src'] && observed.dispositions == [csp.Disposition.report]
}
