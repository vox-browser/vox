// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module html

import dom

// Ladybird 42d6dfd0612f4e68aa23d4e10a63caff1105e972.
fn test_javascript_url_result_keeps_target_and_csp_sandbox_restrictions() {
	for policy_text in ['', 'sandbox allow-scripts allow-same-origin allow-forms allow-top-navigation'] {
	for target_bits in [u32(0), u32(SandboxingFlag.sandboxed_forms) | u32(SandboxingFlag.sandboxed_top_level_navigation_without_user_activation)] {
		url := dom.URL{value: 'https://sandbox.test/'}
		mut document := dom.Document.create(url)
		defer { document.finalize() }
		document.set_origin(url.origin())
		document.populate_with_html_head_and_body()!
		window := WindowModel.create_top_level(document, none, '')!
		mut context := unsafe { &BrowsingContextModel(window.browsing_context()) }
		context.set_popup_sandboxing_flag_set(SandboxingFlagSet{bits: target_bits})
		policy := &PolicyContainer{csp_list: [parse_response_csp_policy(policy_text, .enforce, url.origin())]}
		document.set_policy_container(policy)
		host := document.navigable()?
		mut model := navigable_model_for_host(host)?
		model.set_javascript_url_hook(fn (_ string, _ &dom.Document) ?string {
			return '<!doctype html><p>replacement</p>'
		})
		mut replacement := model.evaluate_javascript_url(dom.URL{value: "javascript:'replacement'"}, document.origin(), .none, 'sandbox-test')?
		defer { replacement.finalize() }
		expected := target_bits | csp_derived_sandboxing_flags(policy).bits
		assert replacement.active_sandboxing_flag_bits() == expected
		assert replacement.active_sandboxing_flag_bits() & u32(SandboxingFlag.sandboxed_forms) == target_bits & u32(SandboxingFlag.sandboxed_forms)
		assert replacement.active_sandboxing_flag_bits() & u32(SandboxingFlag.sandboxed_scripts) == 0
	}
}
}
