module processmetrics

fn test_instruction_stages_balance_javascript_nesting_and_leave_disabled_calls_empty() {
	outer := begin_javascript_instruction_stage()
	inner := begin_javascript_instruction_stage()
	if outer.id > 0 {
		assert inner.id == 0
		assert load_stage_current_is_javascript
	} else {
		assert inner.id == 0
		assert !load_stage_current_is_javascript
	}
	child := begin_instruction_stage('fixture_native_child')
	assert !load_stage_current_is_javascript
	callback := begin_javascript_instruction_stage()
	if outer.id > 0 {
		assert callback.id > child.id && child.id > outer.id
		assert load_stage_current_is_javascript
	}
	callback.finish()
	assert !load_stage_current_is_javascript
	child.finish()
	assert load_stage_current_is_javascript == (outer.id > 0)
	inner.finish()
	outer.finish()
	assert !load_stage_current_is_javascript
}

fn instruction_stage_worker_is_inactive() bool {
	stage := begin_instruction_stage('fixture_worker')
	js := begin_javascript_instruction_stage()
	stage.finish()
	js.finish()
	return stage.id == 0 && js.id == 0
}

fn test_instruction_stages_ignore_worker_threads() {
	worker := spawn instruction_stage_worker_is_inactive()
	assert worker.wait()
	assert !load_stage_current_is_javascript
}
