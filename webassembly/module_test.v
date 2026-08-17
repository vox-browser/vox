module webassembly

import webidl

fn wasm_module_bytes() []u8 {
	return [
		u8(0),
		0x61,
		0x73,
		0x6d,
		1,
		0,
		0,
		0,
		// custom "x" with contents 01 02
		0,
		4,
		1,
		`x`,
		1,
		2,
		// type section: one () -> () function
		1,
		4,
		1,
		0x60,
		0,
		0,
		// import section: env.f, function type 0
		2,
		9,
		1,
		3,
		`e`,
		`n`,
		`v`,
		1,
		`f`,
		0,
		0,
		// export section: f, function index 0
		7,
		5,
		1,
		1,
		`f`,
		0,
		0,
	]
}

fn test_module_validation_import_export_and_custom_sections() {
	source := webidl.BufferSource.array_buffer(wasm_module_bytes())
	assert validate(source)
	compiled := Module.construct(source)!
	assert compiled.imports() == [
		ModuleImportDescriptor{
			module: 'env'
			name:   'f'
			kind:   .function_
		},
	]
	assert compiled.exports() == [
		ModuleExportDescriptor{
			name: 'f'
			kind: .function_
		},
	]
	assert compiled.custom_sections('x') == [[u8(1), 2]]
	assert compiled.custom_sections('missing').len == 0
	for malformed in [
		[]u8{},
		[u8(0), 0x61, 0x73, 0x6d, 2, 0, 0, 0],
		[u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 7, 10, 0],
	] {
		assert !validate(webidl.BufferSource.array_buffer(malformed))
	}
}

fn test_instance_import_linking_and_export_shape() {
	compiled := compile(webidl.BufferSource.array_buffer(wasm_module_bytes()))!
	if _ := Instance.construct(compiled, ImportObject{}) {
		assert false
	} else {
		assert err.msg().starts_with('LinkError:')
	}
	imports := {
		'env': {
			'f': ExternalValue{
				kind:  .function_
				value: webidl.callback_value()
			}
		}
	}
	instance := Instance.construct(compiled, imports)!
	assert instance.exports['f'].kind == .function_
	assert instance.exports['f'].value.kind == .callback
}

fn test_data_count_section_precedes_code_despite_numeric_identifier() {
	// Data-count, code and data each contain an empty vector.
	bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 12, 1, 0, 10, 1, 0, 11, 1, 0]
	assert validate(webidl.BufferSource.array_buffer(bytes))
	bad_order := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 10, 1, 0, 12, 1, 0]
	assert !validate(webidl.BufferSource.array_buffer(bad_order))
}
