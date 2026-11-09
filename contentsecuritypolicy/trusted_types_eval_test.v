module contentsecuritypolicy

fn test_trusted_types_eval_requires_an_enforced_case_sensitive_script_sink() {
	for disposition in [Disposition.enforce,.report] {
		for requirement in ["'script'",'script','"script"',"'SCRIPT'"] {
			mut global := GlobalContext{policy_list:PolicyList.create([
				parse_a_serialized_csp("script-src 'TRUSTED-TYPES-EVAL'",.header,.enforce),
				parse_a_serialized_csp('require-trusted-types-for '+requirement,.header,disposition)])}
			mut blocked := false
			ensure_csp_does_not_block_string_compilation(mut global,CompilationInput{type_:.timer,code_string:'1'}) or { blocked = true }
			assert blocked == !(disposition == .enforce && requirement == "'script'")
			assert global.events.len == if blocked { 1 } else { 0 }
		}
	}
	assert parse_source_expression(.keyword_source,"'TRUSTED-TYPES-EVAL'") != none
}
