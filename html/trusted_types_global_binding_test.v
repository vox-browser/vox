module html

import dom
import trustedtypes
import webidl

fn trusted_global_window() &WindowModel {
	document := parse_document_with_url('<!doctype html><div id="target"></div>', dom.URL{ value: 'https://trusted-global.example/' })
	return WindowModel.create_top_level(document, none, 'trusted-global') or { panic(err) }
}

fn test_global_trusted_types_getter_exposes_the_real_factory_and_retains_global_and_realm() {
	window := trusted_global_window()
	mut services := window.window_or_worker_global_scope()
	mut factory := services.trusted_types()
	assert factory == services.trusted_types()
	assert factory.relevant_global_impl() == voidptr(window)
	assert factory.relevant_realm() == voidptr(window.environment_settings_.settings.realm())
	policy := factory.create_policy('safe', trustedtypes.TrustedTypePolicyOptions{
		create_html: fn (input string, _ []webidl.Value) !trustedtypes.PolicyResult {
			return trustedtypes.PolicyResult{ value: 'safe:${input}' }
		}
	}) or { panic(err) }
	value := policy.create_html('content', []webidl.Value{}) or { panic(err) }
	assert value.to_string() == 'safe:content'
	assert factory.is_html(trustedtypes.TrustedTypeOrString(value))
}

fn test_global_default_policy_is_used_by_real_document_html_mutation_sinks() {
	window := trusted_global_window()
	mut document := window.associated_document()
	document.enforce_meta_csp("require-trusted-types-for 'script'; trusted-types default")
	mut services := window.window_or_worker_global_scope()
	mut factory := services.trusted_types()
	policy := factory.create_policy('default', trustedtypes.TrustedTypePolicyOptions{
		create_html: fn (_ string, _ []webidl.Value) !trustedtypes.PolicyResult {
			return trustedtypes.PolicyResult{ value: '<span id="safe">filtered by the global policy</span>' }
		}
	}) or { panic(err) }
	mut target := document.get_element_by_id('target') or { panic('target missing') }
	target.set_inner_html('<script>unsafe()</script>') or { panic(err) }
	assert document.get_element_by_id('safe') != none
	assert target.inner_html() or { panic(err) } == '<span id="safe">filtered by the global policy</span>'
	assert factory.default_policy() or { panic('default missing') } == policy
	assert voidptr(trusted_types_factory_for_document(document)) == voidptr(factory)
	if _ := factory.create_policy('default', trustedtypes.TrustedTypePolicyOptions{}) {
		assert false
	}
}

fn test_cached_global_factory_reads_csp_added_after_the_getter_was_accessed() {
	window := trusted_global_window()
	mut services := window.window_or_worker_global_scope()
	mut factory := services.trusted_types()
	factory.create_policy('before', trustedtypes.TrustedTypePolicyOptions{}) or { panic(err) }
	mut document := window.associated_document()
	document.enforce_meta_csp('trusted-types allowed')
	factory.create_policy('allowed', trustedtypes.TrustedTypePolicyOptions{}) or { panic(err) }
	if _ := factory.create_policy('blocked', trustedtypes.TrustedTypePolicyOptions{}) {
		assert false
	} else {
		assert err.msg().contains('Content Security Policy blocked')
	}
	assert factory.violations.len == 1
}

fn test_worker_trusted_types_factory_uses_worker_global_realm_and_live_header_policy() {
	window := trusted_global_window()
	owner_settings := window.environment_settings_.settings
	mut realm := &ScriptingRealm{}
	worker := WorkerGlobalScope.create(dom.URL{ value: 'https://trusted-global.example/worker.js' }, .classic, '', realm)
	settings := WorkerEnvironmentSettingsObject.setup(worker, mut realm, owner_settings.serialize(), 0).settings
	mut services := worker.window_or_worker_global_scope()
	mut factory := services.trusted_types()
	assert factory.relevant_global_impl() == voidptr(worker)
	assert factory.relevant_realm() == voidptr(realm)
	mut window_services := window.window_or_worker_global_scope()
	assert factory != window_services.trusted_types()
	mut mutable_settings := unsafe { &EnvironmentSettingsObject(settings) }
	mutable_settings.set_policy_container(&PolicyContainer{
		csp_list: [SerializedCSPPolicy{
			disposition: .enforce
			source:      .header
			directives:  [SerializedCSPDirective{ name: 'trusted-types', value: ['worker-safe'] }]
		}]
	})
	factory.create_policy('worker-safe', trustedtypes.TrustedTypePolicyOptions{}) or { panic(err) }
	if _ := factory.create_policy('blocked', trustedtypes.TrustedTypePolicyOptions{}) {
		assert false
	} else {
		assert err.msg().contains('Content Security Policy blocked')
	}
}
