// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebAssembly/Module.{h,cpp} and Instance.{h,cpp}.
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
	name string
	kind ImportExportKind
}

pub struct ModuleImportDescriptor {
pub:
	module string
	name   string
	kind   ImportExportKind
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
	export_entries   []ModuleExportDescriptor
	custom_sections_ []CustomSection
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
	return compiled.import_entries.clone()
}

pub fn (compiled &Module) exports() []ModuleExportDescriptor {
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
	compiled.export_entries = restored.export_entries.clone()
	compiled.custom_sections_ = restored.custom_sections_.clone()
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
	length := int(decoder.u32_leb()!)
	if length < 0 || decoder.offset + length > decoder.bytes.len {
		return error('CompileError: name extends beyond section')
	}
	bytes := decoder.bytes[decoder.offset..decoder.offset + length].clone()
	decoder.offset += length
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
		bytes: bytes
		offset: 8
	}
	mut imports := []ModuleImportDescriptor{}
	mut exports := []ModuleExportDescriptor{}
	mut custom := []CustomSection{}
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
			2 { parse_import_section(mut section, mut imports)! }
			7 { parse_export_section(mut section, mut exports)! }
			else {
				section.offset = section.bytes.len
			}
		}
		if section.offset != section.bytes.len {
			return error('CompileError: trailing bytes in section ${section_id}')
		}
	}
	return &Module{
		bytes: bytes.clone()
		import_entries: imports
		export_entries: exports
		custom_sections_: custom
	}
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
		name: name
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

fn parse_import_section(mut decoder Decoder, mut result []ModuleImportDescriptor) ! {
	count := decoder.u32_leb()!
	for _ in 0 .. count {
		module_name := decoder.name()!
		name := decoder.name()!
		kind_byte := decoder.byte()!
		kind := external_kind(kind_byte)!
		skip_import_description(mut decoder, kind)!
		result << ModuleImportDescriptor{
			module: module_name
			name: name
			kind: kind
		}
	}
}

fn skip_import_description(mut decoder Decoder, kind ImportExportKind) ! {
	match kind {
		.function_ {
			decoder.u32_leb()!
		}
		.table {
			decoder.byte()!
			skip_limits(mut decoder)!
		}
		.memory {
			skip_limits(mut decoder)!
		}
		.global {
			decoder.byte()!
			mutability := decoder.byte()!
			if mutability > 1 {
				return error('CompileError: invalid global mutability')
			}
		}
	}
}

fn skip_limits(mut decoder Decoder) ! {
	flags := decoder.u32_leb()!
	if flags > 3 {
		return error('CompileError: invalid limits flags')
	}
	decoder.u32_leb()!
	if flags & 1 != 0 {
		decoder.u32_leb()!
	}
}

fn parse_export_section(mut decoder Decoder, mut result []ModuleExportDescriptor) ! {
	count := decoder.u32_leb()!
	mut names := map[string]bool{}
	for _ in 0 .. count {
		name := decoder.name()!
		if names[name] {
			return error('CompileError: duplicate export name')
		}
		names[name] = true
		kind := external_kind(decoder.byte()!)!
		decoder.u32_leb()!
		result << ModuleExportDescriptor{
			name: name
			kind: kind
		}
	}
}

pub struct ExternalValue {
pub:
	kind  ImportExportKind
	value webidl.Value
}

pub type ImportObject = map[string]map[string]ExternalValue

@[heap]
pub struct Instance {
pub:
	module &Module
mut:
	exports_ map[string]ExternalValue
}

pub fn Instance.construct(compiled &Module, imports ImportObject) !&Instance {
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
	}
	mut exports := map[string]ExternalValue{}
	for descriptor in compiled.export_entries {
		exports[descriptor.name] = ExternalValue{
			kind: descriptor.kind
			value: if descriptor.kind == .function_ {
				webidl.callback_value()} else {
				webidl.platform_object_value()}
		}
	}
	return &Instance{
		module:   compiled
		exports_: exports
	}
}

pub fn Instance.construct_impl(compiled &Module, imports ImportObject) !&Instance {
	return Instance.construct(compiled, imports)
}

pub fn (instance &Instance) exports() map[string]ExternalValue {
	return instance.exports_.clone()
}
