module webaudio

fn test_float32_array_helpers_snapshot_and_overwrite_live_views() {
	mut exposed := [f32(1), 2, 3, 4]
	assert float32_array_length(exposed) == 4
	snapshot := copy_float32_array(exposed)
	exposed[0] = 9
	assert snapshot == [f32(1), 2, 3, 4]
	overwrite_float32_array(mut exposed, [f32(5), 6])
	assert exposed == [f32(5), 6, 3, 4]
}
