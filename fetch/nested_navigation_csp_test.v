module fetch

import contentsecuritypolicy as csp
import dom

fn test_nested_document_navigation_enforces_frame_src_without_blocking_top_level_navigation() {
	for nested in [false, true] {
		mut request := Request.create()
		request.set_url(dom.URL{ value: 'https://child.example/document' })
		request.mode = .navigate
		request.destination = .document
		request.target_is_nested_navigable = nested
		policy := csp.parse_a_serialized_csp("frame-src 'none'", .header, .enforce)
		request.resolved_policy_container = RequestPolicyContainer{ csp_list: &csp.PolicyList{ policies: [policy] } }
		assert apply_request_security_policies(mut request) == nested
	}
}
