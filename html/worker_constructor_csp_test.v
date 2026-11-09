module html

import contentsecuritypolicy as csp
import dom

@[heap]
struct ConstructorCSPResult {
mut:
	count int
}

fn test_worker_constructor_policy_blocks_and_reports_on_its_owning_loop() {
	for disposition in [CSPPolicyDisposition.enforce, .report] {
		url := dom.URL{value: 'https://creator.test/page'}
		mut document := dom.Document.create(url)
		document.set_origin(url.origin())
		document.populate_with_html_head_and_body()!
		window := WindowModel.create_top_level(document, none, 'constructor-csp')!
		mut realm := &ScriptingRealm{}
		mut settings := WindowEnvironmentSettingsObject.setup(window, url, mut realm, none, url, url.origin()).settings
		settings.responsible_event_loop_ = EventLoop.create(.window)
		settings.set_policy_container(&PolicyContainer{csp_list: [parse_response_csp_policy("worker-src 'none'", disposition, url.origin())]})
		assert settings.policy_container().csp_list.len == 1
		observed := &ConstructorCSPResult{}
		target := unsafe { &dom.EventTarget(document) }
		target.add_event_listener_without_options('securitypolicyviolation', dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [observed] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				assert event.type_name() == 'securitypolicyviolation'
				actual := unsafe { &csp.SecurityPolicyViolationEvent(event) }
				assert actual.effective_directive() == 'worker-src'
				mut result := unsafe { &ConstructorCSPResult(observed) }
				result.count++
				return dom.js_undefined()
			}
		}))
		assert worker_constructor_csp_allows(settings, dom.URL{value: 'data:text/javascript,void 0'}, false) == (disposition == .report)
		assert observed.count == 0
		mut queue := settings.responsible_event_loop().task_queue()
		mut executed := 0
		for {
			task := queue.dequeue() or { break }
			executed++
			task.execute()
		}
		assert observed.count == 1, 'executed ${executed} tasks, observed ${observed.count}'
	}
}
