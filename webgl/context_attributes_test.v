module webgl

fn test_context_attribute_defaults_and_conversion() {
	defaults := convert_context_attributes(none)!
	assert defaults.alpha
	assert defaults.depth
	assert defaults.antialias
	assert defaults.premultiplied_alpha
	assert !defaults.stencil
	converted := convert_context_attributes(ContextAttributeInput{
		alpha: false
		stencil: true
		power_preference: 'high-performance'
		xr_compatible: true
	})!
	assert !converted.alpha
	assert converted.stencil
	assert converted.power_preference == .high_performance
	assert converted.xr_compatible
	assert !convert_value_to_context_attributes_dictionary(ContextAttributeInput{
		xr_compatible: true
	})!.xr_compatible
	context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{
		depth: false
		stencil: true
		antialias: false
	}, [])
	assert !context.native.drawing_buffer_options.depth
	assert context.native.drawing_buffer_options.stencil
	assert !context.native.drawing_buffer_options.antialias
	assert !context.xr_compatible()
	convert_context_attributes(ContextAttributeInput{ power_preference: 'fastest' }) or {
		assert err.msg() == "TypeError: Invalid value 'fastest' for enumeration type 'WebGLPowerPreference'"
		return
	}
	assert false
}

fn test_context_event_and_value_objects() {
	event := WebGLContextEvent.new('webglcontextcreationerror', WebGLContextEventInit{
		status_message: 'native creation failed'
	})
	assert event.status_message == 'native creation failed'
	info := WebGLActiveInfo{
		name: 'position'
		type_: 0x1406
		size: 2
	}
	assert info.name == 'position'
	precision := WebGLShaderPrecisionFormat{
		range_min: -126
		range_max: 127
		precision: 23
	}
	assert precision.precision == 23
}
