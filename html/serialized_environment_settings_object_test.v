module html

import dom

fn environment_test_policy_container() SerializedPolicyContainer {
	return dom.SerializedPolicyContainer{
		csp_list:        [
			dom.SerializedCSPPolicy{
				directives:               [
					dom.SerializedCSPDirective{
						name:  'script-src'
						value: ["'self'", 'https:']
					},
				]
				disposition:              .report
				source:                   .meta
				self_origin:              dom.Origin{
					value: 'https://example.test'
				}
				pre_parsed_policy_string: "script-src 'self' https:"
			},
		]
		embedder_policy: dom.EmbedderPolicy{
			value:                          .require_corp
			report_only_value:              .credentialless
			reporting_endpoint:             'default'
			report_only_reporting_endpoint: 'reports'
		}
		referrer_policy: .strict_origin
	}
}

fn test_serialized_environment_settings_window_round_trip() {
	object := SerializedEnvironmentSettingsObject{
		id:                               'settings-1'
		creation_url:                     dom.URL{
			value: 'https://example.test/creator'
		}
		top_level_creation_url:           dom.URL{
			value: 'https://example.test/'
		}
		top_level_origin:                 dom.Origin{
			value: 'https://example.test'
		}
		api_base_url:                     dom.URL{
			value: 'https://example.test/base/'
		}
		origin:                           dom.Origin{
			value: 'https://example.test'
		}
		has_cross_site_ancestor:          true
		policy_container:                 environment_test_policy_container()
		cross_origin_isolated_capability: .yes
		time_origin:                      1234.5
		global:                           SerializedWindow{
			associated_document: SerializedDocument{
				url:                                        dom.URL{
					value: 'https://example.test/page'
				}
				relevant_settings_object_is_secure_context: true
			}
		}
	}
	decoded :=
		decode_serialized_environment_settings_object(encode_serialized_environment_settings_object(object))!
	assert decoded.id == object.id
	assert decoded.creation_url == object.creation_url
	assert decoded.top_level_creation_url? == object.top_level_creation_url?
	assert decoded.top_level_origin? == object.top_level_origin?
	assert decoded.has_cross_site_ancestor
	assert decoded.cross_origin_isolated_capability == .yes
	assert decoded.time_origin == 1234.5
	assert decoded.policy_container.csp_list[0].directives[0].value == ["'self'", 'https:']
	assert decoded.policy_container.embedder_policy.report_only_value == .credentialless
	assert decoded.global is SerializedWindow
	window := decoded.global as SerializedWindow
	assert window.associated_document.url.value == 'https://example.test/page'
	assert window.associated_document.relevant_settings_object_is_secure_context
}

fn test_serialized_environment_settings_worker_and_snapshot() {
	object := SerializedEnvironmentSettingsObject{
		id:                               'worker-settings'
		creation_url:                     dom.URL{
			value: 'https://example.test/worker.js'
		}
		api_base_url:                     dom.URL{
			value: 'https://example.test/worker.js'
		}
		origin:                           dom.Origin{
			value: 'https://example.test'
		}
		policy_container:                 environment_test_policy_container()
		cross_origin_isolated_capability: .yes
		time_origin:                      99.25
		global:                           SerializedWorkerGlobalScope{
			relevant_settings_object_is_secure_context: true
		}
	}
	decoded :=
		decode_serialized_environment_settings_object(encode_serialized_environment_settings_object(object))!
	assert decoded.global is SerializedWorkerGlobalScope
	snapshot := EnvironmentSettingsSnapshot.create(decoded)
	assert snapshot.responsible_document() == none
	assert snapshot.api_base_url().value == object.api_base_url.value
	assert snapshot.origin() == object.origin
	assert snapshot.time_origin() == object.time_origin
	assert snapshot.policy_container().referrer_policy == .strict_origin
	assert snapshot.cross_origin_isolated_capability() == .no
}

fn test_serialized_environment_settings_decoder_rejects_bad_data() {
	if _ := decode_serialized_environment_settings_object([u8(1), 2, 3]) {
		assert false
	}
}
