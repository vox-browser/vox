module metal

fn test_essl_pair_compiles_to_actual_metal_functions_and_uniform_layouts() {
	mut target := DrawingBuffer.create(8, 8)!
	defer { target.close() }
	mut program := ShaderProgram.compile(target,
		'attribute vec2 position;varying vec2 uv;uniform mat4 transform;void main(){gl_Position=transform*vec4(position,0.0,1.0);uv=position;}',
		'precision mediump float;varying vec2 uv;uniform vec4 color;void main(){gl_FragColor=color+vec4(uv,0.0,0.0);}', 2)!
	defer { program.close() }
	assert (program.source(.vertex)!).len > 0
	assert (program.source(.fragment)!).len > 0
	resources := program.resources()!
	positions := resources.filter(it.kind == 3 && it.stage == .vertex && it.name == 'position')
	assert positions.len == 1 && positions[0].rows == 2
	transforms := resources.filter(it.kind == 100 && it.stage == .vertex && it.name == 'transform')
	assert transforms.len == 1
	assert transforms[0].columns == 4 && transforms[0].rows == 4
	assert transforms[0].matrix_stride == 16
	colors := resources.filter(it.kind == 100 && it.stage == .fragment && it.name == 'color')
	assert colors.len == 1 && colors[0].rows == 4 && colors[0].byte_size == 16
}

fn test_essl_sampler_name_and_webgl2_shaders_compile_on_metal() {
	mut target := DrawingBuffer.create(8, 8)!
	defer { target.close() }
	mut program := ShaderProgram.compile(target,
		'attribute vec2 position;void main(){gl_Position=vec4(position,0.0,1.0);}',
		'precision mediump float;uniform sampler2D texture;void main(){gl_FragColor=texture2D(texture,vec2(0.5));}', 2)!
	resources := program.resources()!
	assert resources.any(it.kind == 7 && it.name == 'texture'), '${resources}'
	program.close()
	program = ShaderProgram.compile(target,
		'#version 300 es\nin vec2 position;void main(){gl_Position=vec4(position,0.0,1.0);}',
		'#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1.0);}', 3)!
	program.close()
}

fn test_metal_shader_link_preserves_essl_errors_and_versions() {
	mut target := DrawingBuffer.create(8, 8)!
	defer { target.close() }
	vertex := 'varying vec4 value;void main(){gl_Position=vec4(0.0);value=vec4(1.0);}'
	for fragment in [
		'precision mediump float;varying vec3 value;void main(){gl_FragColor=vec4(value,1.0);}',
		'#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1.0);}',
		'#version 300 es\nout vec4 color;void main(){color=vec4(1.0);}',
	] {
		mut rejected := false
		ShaderProgram.compile(target, vertex, fragment, 3) or {
			assert err.msg().len > 0
			rejected = true
		}
		assert rejected
	}
}
