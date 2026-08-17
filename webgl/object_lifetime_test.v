module webgl

fn test_object_context_identity_buffer_compatibility_and_deletion() {
	mut first := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut second := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut buffer := first.create_buffer()
	assert buffer.object.handle(first.identity())! > 0
	buffer.object.handle(second.identity()) or { assert err.msg() == 'GL_INVALID_OPERATION' }
	assert buffer.is_compatible_with(array_buffer)
	assert buffer.is_compatible_with(copy_read_buffer)
	assert !buffer.is_compatible_with(element_array_buffer)
	first.bind_buffer(array_buffer, buffer)
	first.buffer_data(array_buffer, [u8(1), 2, 3, 4], 0x88e4)
	first.buffer_sub_data(array_buffer, 1, [u8(9), 8])
	assert buffer.bytes() == [u8(1), 9, 8, 4]
	first.delete_buffer(buffer)
	assert !first.is_buffer(buffer)
	assert buffer.object.invalidated()
}

fn test_buffer_element_array_class_is_sticky() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut buffer := context.create_buffer()
	context.bind_buffer(element_array_buffer, buffer)
	assert context.get_error() == no_error
	context.bind_buffer(array_buffer, buffer)
	assert context.get_error() == invalid_operation
}
