// SPDX-License-Identifier: BSD-2-Clause
module html

import contentsecuritypolicy as csp
import dom
import fetch

// Worker startup runs in another process, whose serialized outside settings
// cannot dispatch an event into this Window. Apply the initial request policy
// in its creating environment before handing it to the worker agent.
pub fn worker_constructor_csp_allows(settings &EnvironmentSettingsObject, address dom.URL, is_shared bool) bool {
	target := address.parsed() or { return false }
	mut global := settings.fetch_request_client_csp_global()
	request := csp.Request{
		url: target
		current_url: target
		global_url: global.url
		destination: if is_shared { csp.RequestDestination.shared_worker } else { csp.RequestDestination.worker }
		parser_metadata: .not_parser_inserted
		mode: .same_origin
		is_local: fetch.is_local_url(address)
		policy_list: global.policy_list
	}
	csp.report_content_security_policy_violations_for_request(mut global, request)
	return csp.should_request_be_blocked_by_content_security_policy(mut global, request) == .allowed
}
