module processmetrics

import os

fn test_thread_substages_preserve_javascript_state_and_nest_with_both_streams() {
	$if macos {
		previous := load_stage_current_is_javascript
		defer { load_stage_current_is_javascript = previous }
		load_stage_current_is_javascript = true
		outer := begin_instruction_stage('thread_substage_test_outer')
		before := load_stage_current_is_javascript
		inner := begin_thread_instruction_substage('thread_substage_test_inner')
		if load_stage_diagnostics && thread_load_stage_diagnostics && instructions_enabled() {
			assert inner.id > outer.id && outer.id > 0
			assert !load_stage_current_is_javascript
		} else {
			assert inner.id == 0
			assert load_stage_current_is_javascript == before
		}
		javascript := begin_javascript_instruction_stage()
		javascript.finish()
		inner.finish()
		assert load_stage_current_is_javascript == before
		outer.finish()
		assert load_stage_current_is_javascript
	}
}

fn test_thread_substage_with_disabled_dynamic_counters_keeps_state_and_identity() {
	previous_flag := os.getenv('VOX_PROFILE_INSTRUCTIONS')
	previous_state := load_stage_current_is_javascript
	defer {
		os.setenv('VOX_PROFILE_INSTRUCTIONS', previous_flag, true)
		load_stage_current_is_javascript = previous_state
	}
	os.setenv('VOX_PROFILE_INSTRUCTIONS', '', true)
	load_stage_current_is_javascript = true
	before := load_stage_next_id
	stage := begin_thread_instruction_substage('thread_substage_test_disabled')
	assert stage.id == 0 && load_stage_next_id == before
	stage.finish()
	assert load_stage_current_is_javascript
}
