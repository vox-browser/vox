// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebAssembly/Module.{h,cpp} and Instance.{h,cpp}.
@[has_globals]
module webassembly

import webidl
import encoding.utf8

pub enum ImportExportKind {
	function_
	table
	memory
	global
}

pub fn import_export_kind_string(kind ImportExportKind) string {
	return match kind {
		.function_ { 'function' }
		.table { 'table' }
		.memory { 'memory' }
		.global { 'global' }
	}
}

pub struct ModuleExportDescriptor {
pub:
	name  string
	kind  ImportExportKind
	index u32
}

pub struct ModuleImportDescriptor {
pub:
	module      string
	name        string
	kind        ImportExportKind
	memory_type WasmLimits
	function_type_index u32
	table_type ?BinaryTableType
	global_type ?BinaryGlobalType
}

pub struct CustomSection {
pub:
	name     string
	contents []u8
}

@[heap]
pub struct Module {
pub mut:
	bytes            []u8
	import_entries   []ModuleImportDescriptor
	binary_import_entries []BinaryImport
	export_entries   []ModuleExportDescriptor
	custom_sections_ []CustomSection
	memory_types     []WasmLimits
	types            []BinaryDefinedType
	canonical_types []&BinaryCanonicalType
	function_type_indices []u32
	start_function_index ?u32
	data_count ?u32
	tag_types []BinaryTagType
	tag_import_entries []BinaryTagImport
	tag_export_entries []BinaryTagExport
	global_definitions []BinaryGlobalDefinition
	function_bodies []BinaryFunctionBody
	table_definitions []BinaryTableDefinition
	data_segments []BinaryDataSegment
	element_segments []BinaryElementSegment
}

pub struct SerializedModule {
pub:
	bytes []u8
}

pub fn Module.create(source webidl.BufferSource) !&Module {
	return compile_a_webassembly_module(webidl.get_buffer_source_copy(source))
}

pub fn Module.create_for_serialization() &Module {
	return &Module{}
}

pub fn Module.construct(source webidl.BufferSource) !&Module {
	return compile_a_webassembly_module(webidl.get_buffer_source_copy(source))
}

pub fn Module.construct_impl(source webidl.BufferSource) !&Module {
	return Module.construct(source)
}

pub fn (compiled &Module) compiled_module() &Module {
	return compiled
}

pub fn (compiled &Module) imports() []ModuleImportDescriptor {
	for _ in compiled.tag_import_entries { eprintln('Not yet implemented: importing tags') }
	return compiled.import_entries.clone()
}

pub fn (compiled &Module) exports() []ModuleExportDescriptor {
	for _ in compiled.tag_export_entries { eprintln('Not yet implemented: exporting tags') }
	return compiled.export_entries.clone()
}

pub fn (compiled &Module) custom_sections(name string) [][]u8 {
	mut result := [][]u8{}
	for section in compiled.custom_sections_ {
		if section.name == name {
			result << section.contents.clone()
		}
	}
	return result
}

pub fn (compiled &Module) serialization_steps(for_storage bool) !SerializedModule {
	if for_storage {
		return error('DataCloneError: WebAssembly Module instances may not be serialized for storage')
	}
	return SerializedModule{
		bytes: compiled.bytes.clone()
	}
}

pub fn (mut compiled Module) deserialization_steps(serialized SerializedModule) ! {
	restored := compile_a_webassembly_module(serialized.bytes)!
	compiled.bytes = restored.bytes.clone()
	compiled.import_entries = restored.import_entries.clone()
	compiled.binary_import_entries = restored.binary_import_entries.clone()
	compiled.export_entries = restored.export_entries.clone()
	compiled.custom_sections_ = restored.custom_sections_.clone()
	compiled.memory_types = restored.memory_types.clone()
	compiled.types = restored.types.clone()
	compiled.canonical_types = restored.canonical_types.clone()
	compiled.function_type_indices = restored.function_type_indices.clone()
	compiled.start_function_index = restored.start_function_index
	compiled.data_count = restored.data_count
	compiled.tag_types = restored.tag_types.clone()
	compiled.tag_import_entries = restored.tag_import_entries.clone()
	compiled.tag_export_entries = restored.tag_export_entries.clone()
	compiled.global_definitions = restored.global_definitions.clone()
	compiled.function_bodies = restored.function_bodies.clone()
	compiled.table_definitions = restored.table_definitions.clone()
	compiled.data_segments = restored.data_segments.clone()
	compiled.element_segments = restored.element_segments.clone()
}

struct Decoder {
	bytes []u8
mut:
	offset int
}

fn (mut decoder Decoder) byte() !u8 {
	if decoder.offset >= decoder.bytes.len {
		return error('CompileError: unexpected end of WebAssembly binary')
	}
	value := decoder.bytes[decoder.offset]
	decoder.offset++
	return value
}

fn (mut decoder Decoder) u32_leb() !u32 {
	mut value := u32(0)
	mut shift := u32(0)
	for count := 0; count < 5; count++ {
		byte := decoder.byte()!
		payload := u32(byte & 0x7f)
		if shift == 28 && payload > 0x0f {
			return error('CompileError: integer representation too long')
		}
		value |= payload << shift
		if byte & 0x80 == 0 {
			return value
		}
		shift += 7
	}
	return error('CompileError: integer representation too long')
}

fn (mut decoder Decoder) name() !string {
	bytes := decoder.byte_vector()!
	if bytes.len > 0 && !utf8.validate(bytes.data, bytes.len) {
		return error('CompileError: name is not valid UTF-8')
	}
	return bytes.bytestr()
}

fn compile_module(bytes []u8) !&Module {
	if bytes.len < 8 || bytes[..4] != [u8(0), 0x61, 0x73, 0x6d] || bytes[4..8] != [
		u8(1),
		0,
		0,
		0,
	] {
		return error('CompileError: invalid WebAssembly magic or version')
	}
	mut decoder := Decoder{
		bytes:  bytes
		offset: 8
	}
	mut imports := []ModuleImportDescriptor{}
	mut binary_imports := []BinaryImport{}
	mut exports := []ModuleExportDescriptor{}
	mut custom := []CustomSection{}
	mut memory_types := []WasmLimits{}
	mut types := []BinaryDefinedType{}
	mut function_type_indices := []u32{}
	mut start_function_index := ?u32(none)
	mut data_count := ?u32(none)
	mut tag_types := []BinaryTagType{}
	mut tag_import_entries := []BinaryTagImport{}
	mut tag_export_entries := []BinaryTagExport{}
	mut global_definitions := []BinaryGlobalDefinition{}
	mut function_bodies := []BinaryFunctionBody{}
	mut table_definitions := []BinaryTableDefinition{}
	mut data_segments := []BinaryDataSegment{}
	mut element_segments := []BinaryElementSegment{}
	mut last_non_custom_rank := 0
	mut seen := map[u8]bool{}
	for decoder.offset < bytes.len {
		section_id := decoder.byte()!
		if section_id > 13 {
			return error('CompileError: unknown section id ${section_id}')
		}
		section_size := int(decoder.u32_leb()!)
		if decoder.offset + section_size > bytes.len {
			return error('CompileError: section extends beyond WebAssembly binary')
		}
		section_end := decoder.offset + section_size
		mut section := Decoder{
			bytes: bytes[decoder.offset..section_end]
		}
		decoder.offset = section_end
		if section_id != 0 {
			rank := section_rank(section_id)!
			if seen[section_id] || rank < last_non_custom_rank {
				return error('CompileError: duplicate or out-of-order section')
			}
			seen[section_id] = true
			last_non_custom_rank = rank
		}
		match section_id {
			0 { parse_custom_section(mut section, mut custom)! }
			1 { types = parse_type_section(mut section)! }
			2 { parse_import_section(mut section, mut imports, mut tag_import_entries, mut binary_imports)! }
			3 { function_type_indices = parse_function_section(mut section)! }
			4 { table_definitions = parse_table_section(mut section)! }
			5 { parse_memory_section(mut section, mut memory_types)! }
			6 { global_definitions = parse_global_section(mut section)! }
			7 { parse_export_section(mut section, mut exports, mut tag_export_entries)! }
			// Parser.cpp::StartSection::parse retains the function index. The
			// machine's invocation and signature validation are separate work.
			8 { start_function_index = section.u32_leb()! }
			9 { element_segments = parse_element_section(mut section)! }
			10 { function_bodies = parse_code_section(mut section)! }
			11 { data_segments = parse_data_section(mut section)! }
			12 {
				count_section := parse_data_count_section(mut section)!
				data_count = count_section.count
			}
			13 { tag_types = parse_tag_section(mut section)! }
			else {
				return error('CompileError: unknown section id ${section_id}')
			}
		}
		if section.offset != section.bytes.len {
			return error('CompileError: trailing bytes in section ${section_id}')
		}
	}
	validate_binary_export_names(exports, tag_export_entries)!
	canonical_types := canonicalize_binary_module_types(types)!
	validate_binary_type_section(types, canonical_types)!
	mut compiled := &Module{
		bytes:            bytes.clone()
		import_entries:   imports
		binary_import_entries: binary_imports
		export_entries:   exports
		custom_sections_: custom
		memory_types:     memory_types
		types:            types
		canonical_types: canonical_types
		function_type_indices: function_type_indices
		start_function_index: start_function_index
		data_count: data_count
		tag_types: tag_types
		tag_import_entries: tag_import_entries
		tag_export_entries: tag_export_entries
		global_definitions: global_definitions
		function_bodies: function_bodies
		table_definitions: table_definitions
		data_segments: data_segments
		element_segments: element_segments
	}
	context := validate_binary_module_indices(compiled)!
	mut validator := &BinaryInstructionValidator{context: context}
	validator.validate_data_section(mut compiled.data_segments)!
	validator.validate_element_section(mut compiled.element_segments)!
	validator.validate_global_section(mut compiled.global_definitions)!
	for memory in compiled.memory_types { validate_memory_type(memory)! }
	validator.validate_table_section(mut compiled.table_definitions)!
	validator.validate_code_section(mut compiled.function_bodies)!
	for tag in compiled.tag_types { validate_binary_tag_type(tag, context.types)! }
	return compiled
}

// Binary section identifiers are not their semantic order: tag (13) belongs
// between memory and global, while data-count (12) precedes code and data.
fn section_rank(section_id u8) !int {
	return match section_id {
		1, 2, 3, 4, 5 { int(section_id) }
		13 { 6 }
		6 { 7 }
		7 { 8 }
		8 { 9 }
		9 { 10 }
		12 { 11 }
		10 { 12 }
		11 { 13 }
		else {
			return error('CompileError: unknown section id ${section_id}')
		}
	}
}

fn parse_custom_section(mut decoder Decoder, mut result []CustomSection) ! {
	name := decoder.name()!
	contents := decoder.bytes[decoder.offset..].clone()
	decoder.offset = decoder.bytes.len
	result << CustomSection{
		name:     name
		contents: contents
	}
}

fn external_kind(byte u8) !ImportExportKind {
	return match byte {
		0 { .function_ }
		1 { .table }
		2 { .memory }
		3 { .global }
		4 {
			return error('CompileError: tag imports/exports are not exposed by this API')
		}
		else {
			return error('CompileError: invalid external kind')
		}
	}
}

fn parse_import_section(mut decoder Decoder, mut result []ModuleImportDescriptor, mut tag_result []BinaryTagImport, mut binary_result []BinaryImport) ! {
	count := decoder.u32_leb()!
	for _ in 0 .. count {
		module_name := decoder.name()!
		name := decoder.name()!
		kind_byte := decoder.byte()!
		if kind_byte == 4 {
			type_ := parse_binary_tag_type(mut decoder)!
			tag_result << BinaryTagImport{ module: module_name, name: name, type_: type_ }
			binary_result << BinaryImport{ module: module_name, name: name, description: type_ }
			// Module.cpp::imports omits tags at its current JS API boundary;
			// retain the binary record for the separate machine translation.
			continue
		}
		kind := external_kind(kind_byte)!
		mut memory_type := WasmLimits{}
		mut function_type_index := u32(0)
		mut table_type := ?BinaryTableType(none)
		mut global_type := ?BinaryGlobalType(none)
		mut description := BinaryImportDescription(BinaryImportTypeIndex{})
		match kind {
			.function_ {
				function_type_index = decoder.u32_leb()!
				description = BinaryImportTypeIndex{ value: function_type_index }
			}
			.table {
				parsed := parse_binary_table_type(mut decoder)!
				validate_limits(parsed.limits, if parsed.limits.address_type == .i64 { none } else { ?u64(u64(max_u32)) })!
				table_type = parsed
				description = parsed
			}
			.memory {
				memory_type = parse_limits(mut decoder)!
				description = memory_type
			}
			.global {
				parsed := parse_binary_global_type(mut decoder)!
				global_type = parsed
				description = parsed
			}
		}
		binary_result << BinaryImport{ module: module_name, name: name, description: description }
		result << ModuleImportDescriptor{
			module:      module_name
			name:        name
			kind:        kind
			memory_type: memory_type
			function_type_index: function_type_index
			table_type: table_type
			global_type: global_type
		}
	}
}

fn parse_export_section(mut decoder Decoder, mut result []ModuleExportDescriptor, mut tag_result []BinaryTagExport) ! {
	count := decoder.u32_leb()!
	for _ in 0 .. count {
		name := decoder.name()!
		kind_byte := decoder.byte()!
		if kind_byte == 4 {
			tag_result << BinaryTagExport{ name: name, index: decoder.u32_leb()! }
			continue
		}
		kind := external_kind(kind_byte)!
		index := decoder.u32_leb()!
		result << ModuleExportDescriptor{
			name:  name
			kind:  kind
			index: index
		}
	}
}

pub struct ExternalValue {
pub:
	kind  ImportExportKind
	value webidl.Value
	memory ?&Memory
}

pub type ImportObject = map[string]map[string]ExternalValue

pub struct InstanceExport {
pub:
	name    string
	kind    ImportExportKind
	address u64
	value   ExternalValue
}

@[heap]
pub struct ModuleInstance {
pub:
	module &Module
pub mut:
	exports_ []InstanceExport
	memories []&Memory
}

pub fn (instance &ModuleInstance) exports() []InstanceExport {
	return instance.exports_.clone()
}

@[heap]
pub struct Instance {
pub:
	module           &Module
	cache_           &WebAssemblyCache
	module_instance_ &ModuleInstance
mut:
	exports_ map[string]ExternalValue
}

pub fn Instance.construct(compiled &Module, imports ImportObject) !&Instance {
	return Instance.create(compiled, imports)
}

pub fn Instance.create(compiled &Module, imports ImportObject) !&Instance {
	return instance_create_with_cache(get_cache(), compiled, imports)
}

pub fn Instance.create_for_realm(realm string, compiled &Module, imports ImportObject) !&Instance {
	return instance_create_with_cache(get_cache_for_realm(realm), compiled, imports)
}

fn instance_create_with_cache(cache &WebAssemblyCache, compiled &Module, imports ImportObject) !&Instance {
	mut memories := []&Memory{}
	for required in compiled.import_entries {
		if required.module !in imports {
			return error('LinkError: Import module=${required.module} is not an object')
		}
		namespace := imports[required.module].clone()
		value := namespace[required.name] or {
			return error('LinkError: Import ${required.module}.${required.name} is missing')
		}
		if value.kind != required.kind {
			return error('LinkError: Import ${required.module}.${required.name} has the wrong kind')
		}
		if required.kind == .memory {
			memory := value.memory or {
				return error('LinkError: Expected an instance of WebAssembly.Memory for a memory import')
			}
			if !matches_memory_limits(memory.wasm_type(), required.memory_type) {
				return error('LinkError: Memory import and extern do not match')
			}
			memories << memory
			// The legacy typed linking boundary carries the actual imported
			// object. Its address belongs to its owning Store; installing it in
			// a different realm's address map would overwrite a local instance.
		}
	}
	for type_ in compiled.memory_types {
		memories << memory_create_for_module_with_cache(cache, type_)!
	}
	mut module_instance := &ModuleInstance{
		module: compiled
		memories: memories
	}
	mut exports := map[string]ExternalValue{}
	for index, descriptor in compiled.export_entries {
		mut address := u64(voidptr(module_instance)) + u64(index + 1)
		value := match descriptor.kind {
			.function_ {
				webidl.callback_value()
			}
			.global {
				global := global_create_with_cache(cache, GlobalDescriptor{ value: .i32 }, WasmValue{ type_: .i32 })!
				address = global.address()
				webidl.platform_object_value()
			}
			.memory {
				if descriptor.index >= u32(memories.len) {
					return error('LinkError: An export could not be resolved')
				}
				memory := memories[descriptor.index]
				address = memory.address()
				webidl.platform_object_value()
			}
			.table {
				table_ := table_construct_with_cache(cache, TableDescriptor{
					element: .externref
				}, none)!
				address = table_.address()
				webidl.platform_object_value()
			}
		}
		external := ExternalValue{
			kind: descriptor.kind
			value: value
			memory: if descriptor.kind == .memory { ?&Memory(memories[descriptor.index]) } else { ?&Memory(none) }
		}
		exports[descriptor.name] = external
		module_instance.exports_ << InstanceExport{
			name: descriptor.name
			kind: descriptor.kind
			address: address
			value: external
		}
	}
	return &Instance{
		module: compiled
		cache_: cache
		module_instance_: module_instance
		exports_: exports
	}
}

pub fn Instance.construct_impl(compiled &Module, imports ImportObject) !&Instance {
	return Instance.construct(compiled, imports)
}

pub fn (instance &Instance) module_instance() &ModuleInstance {
	return instance.module_instance_
}

pub fn (instance &Instance) cache() &WebAssemblyCache {
	return instance.cache_
}

pub fn (instance &Instance) global_instance(address u64) &Global {
	if global := instance.cache_.get_global_instance(address) {
		return global
	}
	return Global.create_for_store_address(instance.cache_, address)
}

pub fn (instance &Instance) memory_instance(address u64) &Memory {
	if memory := instance.cache_.get_memory_instance(address) {
		return memory
	}
	// Pinned Instance.cpp explicitly selects non-shared until LibWasm has
	// threads/atomics types; it wraps the existing Store address on cache miss.
	return memory_wrap_store_address(instance.cache_, address, false)
}

pub fn (instance &Instance) table_instance(address u64) &Table {
	if table_ := instance.cache_.get_table_instance(address) {
		return table_
	}
	return Table.create_for_store_address(instance.cache_, address)
}

pub fn (instance &Instance) exports() map[string]ExternalValue {
	return instance.exports_.clone()
}

pub fn construct_instance(realm string, compiled &Module, imports ImportObject) !&Instance {
	return Instance.create_for_realm(realm, compiled, imports)
}

@[heap]
pub struct InstanceExportsObject {
pub:
	realm            string
	values           map[string]ExternalValue
	function_objects map[string]&ExportedWasmFunction
	global_objects   map[string]&Global
	memory_objects   map[string]&Memory
	table_objects    map[string]&Table
	frozen           bool
}

@[heap]
pub struct InstanceExportsCache {
pub:
	instance &Instance
pub mut:
	primary_exports     &InstanceExportsObject = unsafe { nil }
	live_export_objects map[string]&InstanceExportsObject
	function_instances  map[u64]&ExportedWasmFunction
}

__global instance_exports_caches_ = map[u64]&InstanceExportsCache{}

pub fn instance_exports_caches() map[u64]&InstanceExportsCache {
	return instance_exports_caches_.clone()
}

pub fn prune_instance_exports_cache(mut cache InstanceExportsCache) {
	for realm, exports in cache.live_export_objects {
		if isnil(exports) {
			cache.live_export_objects.delete(realm)
		}
	}
}

pub fn prune_instance_exports_caches() {
	for address, cache in instance_exports_caches_ {
		if isnil(cache.instance) {
			instance_exports_caches_.delete(address)
		}
	}
}

pub fn instance_exports_cache_for(instance &Instance) &InstanceExportsCache {
	prune_instance_exports_caches()
	address := u64(voidptr(instance))
	if cache := instance_exports_caches_[address] {
		return cache
	}
	cache := &InstanceExportsCache{
		instance: instance
		live_export_objects: map[string]&InstanceExportsObject{}
		function_instances: map[u64]&ExportedWasmFunction{}
	}
	instance_exports_caches_[address] = cache
	return cache
}

pub fn create_native_function_for_instance_realm(realm string, address u64, instance &Instance) &ExportedWasmFunction {
	for export_ in instance.module_instance_.exports_ {
		if export_.kind == .function_ && export_.address == address {
			return ExportedWasmFunction.create_for_realm(realm, export_.name, address)
		}
	}
	return ExportedWasmFunction.create_for_realm(realm, '', address)
}

pub fn create_exports_object(realm string, instance &Instance, cache_function_exports bool) &InstanceExportsObject {
	mut values := map[string]ExternalValue{}
	mut functions := map[string]&ExportedWasmFunction{}
	mut globals := map[string]&Global{}
	mut memories := map[string]&Memory{}
	mut tables := map[string]&Table{}
	for export_ in instance.module_instance_.exports_ {
		values[export_.name] = export_.value
		match export_.kind {
			.function_ {
				mut function := unsafe { nil }
				if cache_function_exports {
					mut cache := instance_exports_cache_for(instance)
					if cached := cache.function_instances[export_.address] {
						function = cached
					} else {
						function = create_native_function_with_cache(instance.cache_, realm, export_.address, export_.name)
						cache.function_instances[export_.address] = function
					}
				} else {
					function = create_native_function_for_instance_realm(realm, export_.address, instance)
				}
				functions[export_.name] = function
			}
			.global {
				globals[export_.name] = instance.global_instance(export_.address)
			}
			.memory {
				memories[export_.name] = export_.value.memory or { instance.memory_instance(export_.address) }
			}
			.table {
				tables[export_.name] = instance.table_instance(export_.address)
			}
		}
	}
	return &InstanceExportsObject{
		realm: realm
		values: values
		function_objects: functions
		global_objects: globals
		memory_objects: memories
		table_objects: tables
		frozen: true
	}
}

pub fn (instance &Instance) exports_for_realm(realm string) &InstanceExportsObject {
	mut cache := instance_exports_cache_for(instance)
	if isnil(cache.primary_exports) {
		exports := create_exports_object(realm, instance, true)
		cache.primary_exports = exports
		return exports
	}
	if cache.primary_exports.realm == realm {
		return cache.primary_exports
	}
	prune_instance_exports_cache(mut cache)
	if exports := cache.live_export_objects[realm] {
		return exports
	}
	exports := create_exports_object(realm, instance, false)
	cache.live_export_objects[realm] = exports
	return exports
}

pub fn initialize_webassembly_export_binding(realm string, mut environment map[string]ExternalValue, name string, instance &Instance) ! {
	exports := instance.exports_for_realm(realm)
	value := exports.values[name] or {
		return error('LinkError: WebAssembly export ${name} is missing')
	}
	environment[name] = value
}
