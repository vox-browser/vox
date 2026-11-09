module contentsecuritypolicy

import url

fn test_worker_destinations_apply_script_source_fallback_before_and_after_fetch() {
	creator := url.parse('https://worker-csp.test/page') or { panic('invalid URL') }
	target := url.parse('data:text/javascript,void%200') or { panic('invalid URL') }
	for destination in [RequestDestination.worker, .shared_worker, .service_worker] {
		for serialized in ["script-src 'self' 'unsafe-inline'", "script-src * 'unsafe-inline'"] {
			mut policy := parse_a_serialized_csp(serialized, .header, .enforce)
			policy.set_self_origin(creator.origin())
			list := PolicyList.create([policy])
			mut global := GlobalContext{url: creator, policy_list: list}
			request := Request{url: target, current_url: target, destination: destination,
				policy_list: list, mode: .same_origin}
			assert request.destination_is_script_like()
			assert should_request_be_blocked_by_content_security_policy(mut global, request) == .blocked
			assert global.reports.len == 1 && global.reports[0].effective_directive == 'worker-src'
			assert should_response_to_request_be_blocked_by_content_security_policy(mut global, Response{url: target}, request) == .blocked
		}
	}
}
