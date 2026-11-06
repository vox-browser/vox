module css

import platform

fn test_borrowed_rule_buckets_preserve_presence_identity_and_live_replacement() {
	mut strings := map[string][]&MatchingRule{}
	mut pseudos := map[PseudoElement][]&MatchingRule{}
	assert borrowed_string_rule_bucket(strings, 'missing') == none
	assert borrowed_pseudo_rule_bucket(pseudos, .before) == none
	strings['empty'] = []&MatchingRule{}
	pseudos[.before] = []&MatchingRule{}
	assert (borrowed_string_rule_bucket(strings, 'empty') or { panic('present empty string') }).len == 0
	assert (borrowed_pseudo_rule_bucket(pseudos, .before) or { panic('present empty pseudo') }).len == 0
	for index in 0 .. 3 {
		rule := &MatchingRule{rule_index:uint(index)}
		strings['entry'] = [rule]
		pseudos[.after] = [rule]
		string_bucket := borrowed_string_rule_bucket(strings, 'entry') or { panic('entry') }
		pseudo_bucket := borrowed_pseudo_rule_bucket(pseudos, .after) or { panic('pseudo') }
		assert string_bucket.data == unsafe { strings['entry'].data }
		assert pseudo_bucket.data == unsafe { pseudos[.after].data }
		assert voidptr(string_bucket[0]) == voidptr(rule)
		assert voidptr(pseudo_bucket[0]) == voidptr(rule)
		strings.delete('entry')
		pseudos.delete(.after)
		assert borrowed_string_rule_bucket(strings, 'entry') == none
		assert borrowed_pseudo_rule_bucket(pseudos, .after) == none
	}
	assert strings.len == 1 && pseudos.len == 1
}

fn test_borrowed_rule_bucket_lookup_does_not_allocate_in_callers_arena() {
	$if prealloc {
		mut strings := map[string][]&MatchingRule{}
		mut pseudos := map[PseudoElement][]&MatchingRule{}
		rule := &MatchingRule{}
		strings['hit'] = [rule]
		pseudos[.before] = [rule]
		mut arena := platform.new_arena('borrowed rule bucket test')
		defer { arena.release() }
		entry := arena.enter()
		before := arena.usage().used
		for _ in 0 .. 1000 {
			assert (borrowed_string_rule_bucket(strings, 'hit') or { panic('hit') }).len == 1
			assert (borrowed_pseudo_rule_bucket(pseudos, .before) or { panic('hit') }).len == 1
			assert borrowed_string_rule_bucket(strings, 'miss') == none
			assert borrowed_pseudo_rule_bucket(pseudos, .after) == none
		}
		assert arena.usage().used == before
		arena.leave(entry)
	}
}
