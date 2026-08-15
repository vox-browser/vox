module referrerpolicy

const all_named_policies = [ReferrerPolicy.no_referrer, .no_referrer_when_downgrade, .same_origin,
	.origin, .strict_origin, .origin_when_cross_origin, .strict_origin_when_cross_origin, .unsafe_url]

fn test_to_string() {
	assert to_string(.empty_string) == ''
	assert to_string(.no_referrer) == 'no-referrer'
	assert to_string(.no_referrer_when_downgrade) == 'no-referrer-when-downgrade'
	assert to_string(.same_origin) == 'same-origin'
	assert to_string(.origin) == 'origin'
	assert to_string(.strict_origin) == 'strict-origin'
	assert to_string(.origin_when_cross_origin) == 'origin-when-cross-origin'
	assert to_string(.strict_origin_when_cross_origin) == 'strict-origin-when-cross-origin'
	assert to_string(.unsafe_url) == 'unsafe-url'
}

fn test_from_string_exact() {
	assert from_string('no-referrer')? == ReferrerPolicy.no_referrer
	assert from_string('strict-origin-when-cross-origin')? == ReferrerPolicy.strict_origin_when_cross_origin
	assert from_string('unsafe-url')? == ReferrerPolicy.unsafe_url
}

fn test_from_string_empty_is_empty_string_policy() {
	assert from_string('')? == ReferrerPolicy.empty_string
}

fn test_from_string_is_ascii_case_insensitive() {
	assert from_string('No-Referrer')? == ReferrerPolicy.no_referrer
	assert from_string('UNSAFE-URL')? == ReferrerPolicy.unsafe_url
	assert from_string('Same-Origin')? == ReferrerPolicy.same_origin
}

fn test_from_string_unknown_is_none() {
	assert from_string('bogus') == none
	assert from_string('no_referrer') == none // underscore, not hyphen
	assert from_string('origin ') == none // trailing space is not trimmed here
}

fn test_default_policy() {
	assert default_referrer_policy == ReferrerPolicy.strict_origin_when_cross_origin
}

fn test_round_trip_named_policies() {
	for policy in all_named_policies {
		assert from_string(to_string(policy))? == policy
	}
}

fn test_parse_from_header_tokens_last_valid_wins() {
	// The last valid, non-empty token wins.
	assert parse_a_referrer_policy_from_header_tokens(['no-referrer', 'origin']) == ReferrerPolicy.origin
	assert parse_a_referrer_policy_from_header_tokens(['origin', 'strict-origin']) == ReferrerPolicy.strict_origin
}

fn test_parse_from_header_tokens_skips_invalid_and_empty() {
	// Unknown tokens are ignored; an empty-string token does not override the running policy.
	assert parse_a_referrer_policy_from_header_tokens(['origin', 'bogus']) == ReferrerPolicy.origin
	assert parse_a_referrer_policy_from_header_tokens(['no-referrer', '']) == ReferrerPolicy.no_referrer
}

fn test_parse_from_header_tokens_defaults_to_empty_string() {
	// No tokens, or only invalid ones, yields the empty-string policy.
	assert parse_a_referrer_policy_from_header_tokens([]) == ReferrerPolicy.empty_string
	assert parse_a_referrer_policy_from_header_tokens(['bogus', 'also-bogus']) == ReferrerPolicy.empty_string
}
