module html

import contentsecuritypolicy as csp
import fetch

// Check embedding policies before any response body can become the child's
// active Document. Both synchronous and RequestServer navigation share this.
fn navigation_response_allows_embedding(params &NavigationParams) bool {
	request := params.request or { return true }
	response := params.response.unsafe_response()
	policies := params.policy_container.csp_list
	if !check_a_navigation_responses_adherence_to_x_frame_options(params.navigable.host_navigable(),
		policies, response.header_list.get_decode_and_split('X-Frame-Options') or { []string{} }, params.origin) {
		return false
	}
	mut global := request.csp_global or {
		if client := request.client {
			if client is fetch.RequestSecurityClient {
				client.fetch_request_client_csp_global()
			} else {
				&csp.GlobalContext{}
			}
		} else {
			&csp.GlobalContext{}
		}
	}
	url := request.current_url().parsed() or { return false }
	policy_request := csp.new_request(url)
	return csp.should_navigation_response_to_navigation_request_of_type_in_target_be_blocked_by_content_security_policy(mut global,
		&policy_request, fetch.csp_response(response), fetch_csp_policy_list(policies), .other,
		csp.NavigableContext{ navigable: params.navigable.host_navigable() }) != .blocked
}
