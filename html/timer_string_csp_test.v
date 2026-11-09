module html

import dom

@[heap]
struct TimerStringCSPObservation {
mut:
	calls []string
}

fn test_timer_string_csp_is_checked_before_install_and_not_rechecked_after_policy_changes() {
	mut document := parse_document_with_url('<!doctype html><div></div>',dom.URL{value:'https://timer-csp.test/'})
	defer { document.finalize() }
	window := WindowModel.create_top_level(document,none,'timer-csp')!
	mut settings := window.environment_settings_.settings
	mut scope := window.window_or_worker_global_scope()
	observation := &TimerStringCSPObservation{}
	scope.set_timer_script_evaluator(fn [observation] (source string) ! {
		mut observed := unsafe { &TimerStringCSPObservation(observation) }
		observed.calls << source
	})
	allowed := scope.set_timeout(timer_source_handler('accepted'),0,[])
	assert allowed > 0
	settings.set_policy_container(&PolicyContainer{csp_list:[parse_response_csp_policy("script-src 'self'",.enforce,document.origin())]})
	assert scope.set_timeout(timer_source_handler('blocked'),0,[]) == 0
	assert scope.set_interval(timer_source_handler('blocked'),0,[]) == 0
	assert scope.active_timer_count() == 1 && scope.reported_errors().len == 0
	scope.run_all_timers()
	assert observation.calls == ['accepted']
	assert scope.active_timer_count() == 0
}
