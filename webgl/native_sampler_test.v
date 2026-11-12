module webgl

fn test_native_sampler_parameters_preserve_floats_and_driver_validation() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut sampler := context.create_sampler()
	assert sampler.object.native_handle_ != 0
	context.sampler_parameterf(mut sampler, texture_min_lod, -2.75)
	context.sampler_parameterf(mut sampler, texture_max_lod, 6.5)
	context.sampler_parameteri(mut sampler, texture_min_filter, 0x2600)
	assert C.vox_gl_sampler_parameter(sampler.object.native_handle_, texture_min_lod) == -2.75
	assert C.vox_gl_sampler_parameter(sampler.object.native_handle_, texture_max_lod) == 6.5
	assert C.vox_gl_sampler_parameter(sampler.object.native_handle_, texture_min_filter) == 0x2600
	assert context.get_error() == no_error
	context.sampler_parameteri(mut sampler, texture_mag_filter, 0x2700)
	assert context.get_error() == invalid_enum
	assert C.vox_gl_sampler_parameter(sampler.object.native_handle_, texture_mag_filter) == 0x2601
	context.sampler_parameterf(mut sampler, 0xbad, 1.25)
	assert context.get_error() == invalid_enum
	context.bind_sampler(0, sampler)
	assert (context.get_parameter(sampler_binding).sampler or {panic("sampler")}).object.native_handle_ == sampler.object.native_handle_
	context.bind_sampler(0xffffffff, sampler)
	assert context.get_error() == invalid_value
	mut actual_sampler := i32(0)
	C.vox_gl_int_parameter(sampler_binding, &actual_sampler)
	assert GLuint(actual_sampler) == sampler.object.native_handle_
	context.delete_sampler(sampler)
	assert (context.get_parameter(sampler_binding).sampler or {panic("unbound sampler")}).object.native_handle_ == 0
	context.bind_sampler(0, sampler)
	assert context.get_error() == invalid_operation
}
