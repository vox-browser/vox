module contentsecuritypolicy

import dom
import url

fn test_directive_and_policy_serialization_round_trip() {
	directive := SerializedDirective{
		name:  script_src
		value: ["'self'", 'https:']
	}
	assert decode_serialized_directive(encode_serialized_directive(directive))! == directive
	origin := url.Origin.tuple('https', url.Host.from_string('example.test'), u16(8443),
		'example.test')
	policy := SerializedPolicy{
		directives:               [directive]
		disposition:              .report
		source:                   .header
		self_origin:              origin
		pre_parsed_policy_string: "script-src 'self' https:"
	}
	decoded := decode_serialized_policy(encode_serialized_policy(policy))!
	assert decoded.directives == policy.directives
	assert decoded.disposition == .report
	assert decoded.self_origin.serialize() == 'https://example.test:8443'
	assert decoded.pre_parsed_policy_string == policy.pre_parsed_policy_string
	recreated := Policy.create_from_serialized_policy(decoded)
	assert recreated.directives[0].kind == .script_source
}

fn test_opaque_origin_serialization_and_trailing_data_rejection() {
	origin := url.Origin.opaque([u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]!, .file)
	policy := SerializedPolicy{
		self_origin: origin
	}
	encoded := encode_serialized_policy(policy)
	decoded := decode_serialized_policy(encoded)!
	assert decoded.self_origin.is_opaque_file_origin()
	mut invalid := encoded.clone()
	invalid << u8(0)
	if _ := decode_serialized_policy(invalid) {
		assert false
	}
}

fn test_security_policy_violation_event_init() {
	init := SecurityPolicyViolationEventInit{
		EventInit:           dom.EventInit{
			bubbles:  true
			composed: true
		}
		document_uri:        'https://example.test/'
		blocked_uri:         'https://evil.test/x.js'
		effective_directive: script_src_elem
		violated_directive:  script_src_elem
		original_policy:     "default-src 'self'"
		disposition:         .report
		status_code:         403
		line_number:         9
		column_number:       2
		sample:              'alert(1)'
	}
	event := SecurityPolicyViolationEvent.construct_impl('securitypolicyviolation', init)!
	assert event.type_name() == 'securitypolicyviolation'
	assert event.bubbles()
	assert event.composed()
	assert event.blocked_uri() == 'https://evil.test/x.js'
	assert event.effective_directive() == script_src_elem
	assert event.disposition() == .report
	assert event.status_code() == 403
}
