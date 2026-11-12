module shader

fn test_direct_metal_pair_and_stage_linking() {
	vertex := translate('attribute vec2 position;varying vec2 uv;void main(){gl_Position=vec4(position,0.0,1.0);uv=position;}', .vertex)!
	fragment := translate('precision mediump float;varying vec2 uv;void main(){gl_FragColor=vec4(uv,0.0,1.0);}', .fragment)!
	link(vertex, fragment)!
	assert vertex.inputs.len == 1 && vertex.inputs[0].name == 'position'
	assert vertex.source.contains('[[attribute(0)]]')
	assert fragment.source.contains('[[user(v_uv)]]')
	assert vertex.source.contains('result.position.z =')
	mismatch := translate('precision mediump float;varying vec3 uv;void main(){gl_FragColor=vec4(uv,1.0);}', .fragment)!
	link(vertex, mismatch) or {
		assert err.msg().contains('Varying mismatch')
		return
	}
	assert false
}

fn test_direct_metal_rejects_unsupported_source_without_a_fallback() {
	for source in ['void main(){} /*', 'void main(){}\x00', 'uniform vec4 color;void main(){}',
		'#version 410\nvoid main(){}', '#include <bad>\nvoid main(){}', 'void main(){}void main(){}',
		'void main(){gl_FragColor=vec4(1.0);}', 'attribute vec2 a[2];void main(){}'] {
		translate(source, .vertex) or { continue }
		assert false, source
	}
	translate('void main(){gl_FragColor=vec4(1.0);}', .fragment) or { return }
	assert false
}

fn test_lexer_keeps_numbers_operators_and_ignores_comments() {
	assert lex('1e-3 + .5 <= 2. // ignored\n/* attribute */ x++')! == ['1e-3', '+', '.5', '<=',
		'2.', 'x', '++']
	translated := translate('#version 300 es\n// gl_FragColor\nvoid main(){gl_Position=vec4(float(gl_VertexID),0.,0.,1.);}', .vertex)!
	assert translated.version == 300
	assert translated.source.contains('float4 ( float ( gl_VertexID )')
}
