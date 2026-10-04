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

fn wasm_export_only_bytes(name string, kind u8) []u8 {
	mut payload := [u8(1), u8(name.len)]
	payload << name.bytes()
	payload << kind
	payload << u8(0)
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, 4, 1, 0x60, 0, 0,
		2, 5, 1, 0, 0, kind, 0, 7, u8(payload.len)]
	bytes << payload
	return bytes
}

fn wasm_import_only_bytes(module_name string, name string, kind u8) []u8 {
	mut payload := [u8(1), u8(module_name.len)]
	payload << module_name.bytes()
	payload << u8(name.len)
	payload << name.bytes()
	payload << kind
	payload << u8(0)
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, 4, 1, 0x60, 0, 0, 2, u8(payload.len)]
	bytes << payload
	return bytes
}

fn deny_wasm_byte_compilation() ! {
	return error('WebAssembly.CompileError: Blocked by Content Security Policy')
}

fn test_host_policy_is_checked_before_compiling_wasm_bytes() {
	set_host_ensure_can_compile_wasm_bytes_hook(deny_wasm_byte_compilation)
	defer {
		set_host_ensure_can_compile_wasm_bytes_hook(none)
	}

	if _ := compile(webidl.BufferSource.array_buffer(wasm_module_bytes())) {
		assert false
	} else {
		assert err.msg() == 'WebAssembly.CompileError: Blocked by Content Security Policy'
	}
	assert !validate(webidl.BufferSource.array_buffer(wasm_module_bytes()))
}

fn test_clearing_host_policy_restores_wasm_compilation() {
	set_host_ensure_can_compile_wasm_bytes_hook(none)
	assert validate(webidl.BufferSource.array_buffer(wasm_module_bytes()))
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
	exports := instance.exports()
	exported_function := exports['f'] or { panic('missing exported function') }
	assert exported_function.kind == .function_
	assert exported_function.value.kind == .callback
}

fn test_instance_retains_owner_cache_and_caches_exports_per_realm() {
	compiled := compile(webidl.BufferSource.array_buffer(wasm_module_bytes()))!
	imports := {
		'env': {
			'f': ExternalValue{
				kind: .function_
				value: webidl.callback_value()
			}
		}
	}
	instance := construct_instance('instance-owner-realm', compiled, imports)!
	assert voidptr(instance.cache()) == voidptr(get_cache_for_realm('instance-owner-realm'))
	assert voidptr(instance.module_instance().module) == voidptr(compiled)
	assert instance.module_instance().exports().len == 1

	primary := instance.exports_for_realm('instance-export-realm-a')
	assert primary.frozen
	assert voidptr(instance.exports_for_realm('instance-export-realm-a')) == voidptr(primary)
	secondary := instance.exports_for_realm('instance-export-realm-b')
	assert voidptr(secondary) != voidptr(primary)
	assert voidptr(instance.exports_for_realm('instance-export-realm-b')) == voidptr(secondary)
	primary_function := primary.function_objects['f'] or { panic('missing primary function') }
	secondary_function := secondary.function_objects['f'] or { panic('missing secondary function') }
	assert primary_function.realm == 'instance-export-realm-a'
	assert secondary_function.realm == 'instance-export-realm-b'
	assert voidptr(primary_function) != voidptr(secondary_function)
	assert primary_function.exported_address() == secondary_function.exported_address()

	mut environment := map[string]ExternalValue{}
	initialize_webassembly_export_binding('instance-export-realm-b', mut environment, 'f', instance)!
	exported_function := environment['f'] or { panic('missing export environment binding') }
	assert exported_function.kind == .function_
	assert instance_exports_caches().len > 0
}

fn test_instance_resolves_exported_wrapper_objects_through_its_cache() {
	compiled := &Module{
		memory_types: [WasmLimits{}]
		export_entries: [
			ModuleExportDescriptor{ name: 'global', kind: .global },
			ModuleExportDescriptor{ name: 'memory', kind: .memory },
			ModuleExportDescriptor{ name: 'table', kind: .table },
		]
	}
	instance := Instance.create_for_realm('instance-wrapper-realm', compiled, ImportObject{})!
	exports := instance.module_instance().exports()
	assert voidptr(instance.global_instance(exports[0].address)) == voidptr(instance.cache().get_global_instance(exports[0].address) or {
		panic('missing global wrapper')
	})
	assert voidptr(instance.memory_instance(exports[1].address)) == voidptr(instance.cache().get_memory_instance(exports[1].address) or {
		panic('missing memory wrapper')
	})
	assert voidptr(instance.table_instance(exports[2].address)) == voidptr(instance.cache().get_table_instance(exports[2].address) or {
		panic('missing table wrapper')
	})
}

fn test_webassembly_module_record_parses_resolves_and_executes() {
	mut record := WebAssemblyModule.parse(wasm_module_bytes(), 'module-record-realm', 'example.wasm')!
	assert record.requested_modules == ['env']
	assert record.export_name_list() == ['f']
	assert record.get_exported_names() == ['f']
	resolution := record.resolve_export('f')
	assert resolution.valid
	assert resolution.binding_name == 'f'
	assert voidptr(resolution.module) == voidptr(record)
	assert !record.resolve_export('missing').valid
	assert voidptr(record.module_record()) == voidptr(record)

	record.initialize_environment()!
	mut environment := record.environment() or { panic('missing module environment') }
	if _ := environment.get_binding_value('f') {
		assert false
	} else {
		assert err.msg().starts_with('ReferenceError:')
	}
	record.link_javascript_module('env', {
		'f': ExternalValue{
			kind: .function_
			value: webidl.callback_value()
		}
	})
	record.execute_module()!
	instance := record.instance() or { panic('module was not instantiated') }
	assert voidptr(instance.cache()) == voidptr(get_cache_for_realm('module-record-realm'))
	assert environment.get_binding_value('f')!.value.kind == .callback
}

fn test_webassembly_module_record_rejects_reserved_names() {
	for bytes in [
		wasm_import_only_bytes('wasm-js:', 'f', 0),
		wasm_import_only_bytes('env', 'wasm:f', 0),
		wasm_export_only_bytes('wasm:f', 0),
	] {
		if _ := WebAssemblyModule.parse(bytes, 'reserved-name-realm', '') {
			assert false
		} else {
			assert err.msg().starts_with('LinkError:')
		}
	}
}

fn test_webassembly_module_record_links_wasm_module_exports() {
	dependency_source := &Module{
		export_entries: [ModuleExportDescriptor{ name: 'f', kind: .function_ }]
	}
	mut dependency := WebAssemblyModule.create('dependency-realm', 'dependency.wasm', dependency_source)
	mut importer := WebAssemblyModule.create('importer-realm', 'importer.wasm', &Module{
		import_entries: [ModuleImportDescriptor{
			module: 'dependency'
			name: 'f'
			kind: .function_
		}]
	})
	importer.link_webassembly_module('dependency', dependency)
	if _ := importer.execute_module() {
		assert false
	} else {
		assert err.msg().contains('has not been instantiated')
	}
	dependency.execute_module()!
	importer.execute_module()!
	assert importer.instance() != none
}

fn test_data_count_section_precedes_code_despite_numeric_identifier() {
	// Data-count, code and data each contain an empty vector.
	bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 12, 1, 0, 10, 1, 0, 11, 1, 0]
	assert validate(webidl.BufferSource.array_buffer(bytes))
	bad_order := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 10, 1, 0, 12, 1, 0]
	assert !validate(webidl.BufferSource.array_buffer(bad_order))
}

fn test_module_structured_serialization_round_trips_original_bytes() {
	module_ := Module.create(webidl.BufferSource.array_buffer(wasm_module_bytes()))!
	serialized := module_.serialization_steps(false)!
	assert serialized.bytes == wasm_module_bytes()

	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(serialized)!
	assert restored.bytes == wasm_module_bytes()
	assert restored.imports() == module_.imports()
	assert restored.exports() == module_.exports()
	assert restored.custom_sections('x') == [[u8(1), 2]]
}

fn test_module_serialization_for_storage_and_corrupt_deserialization_fail() {
	module_ := Module.create(webidl.BufferSource.array_buffer(wasm_module_bytes()))!
	if _ := module_.serialization_steps(true) {
		assert false
	} else {
		assert err.msg().starts_with('DataCloneError:')
	}

	mut restored := Module.create_for_serialization()
	if _ := restored.deserialization_steps(SerializedModule{
		bytes: [u8(0), 1, 2]
	}) {
		assert false
	} else {
		assert err.msg().starts_with('CompileError:')
	}
}
