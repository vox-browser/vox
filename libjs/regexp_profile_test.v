module libjs

fn test_regexp_pattern_profile_is_opt_in_resettable_and_preserves_results() {
	for enabled in [false, true] {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		profile_regexp_patterns_for_testing(enabled)
		mut script := Script.parse('var r=/a+/g;var first=r.exec("baa");first[0]==="aa"&&first.index===1&&r.lastIndex===3&&r.exec("x")===null&&r.lastIndex===0&&r.exec("x")===null', vm.realm(), 'regex-profile.js', unsafe { nil })!
		assert vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})!.as_bool()
		samples := profile_regexp_patterns_for_testing(false)
		assert samples.len == if enabled { 1 } else { 0 }
		if enabled {
			assert samples[0].pattern == 'a+' && samples[0].flags == 'g'
			assert samples[0].calls == 2 && samples[0].matches == 1 && samples[0].input_units == 4
			assert samples[0].engine_ns > 0
		}
		assert profile_regexp_patterns_for_testing(false).len == 0
	}
}
