module css

import os

const retain_rule_bucket_double_lookups = os.getenv('VOX_RETAIN_RULE_BUCKET_DOUBLE_LOOKUPS') != ''
const borrowed_rule_bucket_diagnostics = os.getenv('VOX_BORROWED_RULE_BUCKET_DIAGNOSTICS') != ''
__global borrowed_rule_bucket_reported bool

// These read-only walks consume the bucket synchronously while its RuleCache
// remains alive. Preserve the borrowed array header and distinguish an absent
// key from a present empty bucket without checking and hashing the key twice.
@[inline]
fn borrowed_string_rule_bucket(buckets map[string][]&MatchingRule, name string) ?[]&MatchingRule {
	unsafe {
		if retain_rule_bucket_double_lookups {
			if name in buckets { return buckets[name] }
			return none
		}
		if bucket := buckets[name] {
			report_borrowed_rule_bucket()
			return bucket
		}
	}
	return none
}

@[inline]
fn borrowed_pseudo_rule_bucket(buckets map[PseudoElement][]&MatchingRule, pseudo PseudoElement) ?[]&MatchingRule {
	unsafe {
		if retain_rule_bucket_double_lookups {
			if pseudo in buckets { return buckets[pseudo] }
			return none
		}
		if bucket := buckets[pseudo] {
			report_borrowed_rule_bucket()
			return bucket
		}
	}
	return none
}

@[inline]
fn report_borrowed_rule_bucket() {
	if borrowed_rule_bucket_diagnostics && !borrowed_rule_bucket_reported {
		borrowed_rule_bucket_reported = true
		eprintln('Vox rule buckets: borrowed single lookup executed')
	}
}
