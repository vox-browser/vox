module webaudio

fn test_buffer_source_constructor_consumes_the_one_non_null_buffer_assignment() {
	mut context := make_base_context(1, 48_000, 1, false) or { panic(err) }
	buffer := context.create_buffer(1, 8, 48_000) or { panic(err) }
	mut source := context.create_buffer_source(AudioBufferSourceOptions{buffer: buffer}) or { panic(err) }
	source.set_buffer(none) or { panic(err) }
	mut rejected := false
	source.set_buffer(buffer) or { rejected = true }
	assert rejected
	mut empty := context.create_buffer_source(AudioBufferSourceOptions{}) or { panic(err) }
	empty.set_buffer(buffer) or { panic(err) }
	rejected = false
	empty.set_buffer(buffer) or { rejected = true }
	assert rejected
}
