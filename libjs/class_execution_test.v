// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn class_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'classes.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 }) or {
		if is_throw_completion(err) { return error(thrown_value(err).as_object().error_message() or { thrown_value(err).str() }) }
		return err
	}
}

fn test_base_classes_construct_call_methods_and_keep_descriptors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert class_eval(mut vm, 'class Box{constructor(v){this.value=v}read(){return this.value}static create(v){return new Box(v)}}var b=Box.create(42);b instanceof Box&&b.read()===42&&b.constructor===Box&&Box.name==="Box"&&Box.length===1&&typeof windowBox==="undefined"')!.as_bool()
	assert class_eval(mut vm, 'var d=Object.getOwnPropertyDescriptor(Box,"prototype"),m=Object.getOwnPropertyDescriptor(Box.prototype,"read");!d.writable&&!d.enumerable&&!d.configurable&&m.writable&&!m.enumerable&&m.configurable&&!Object.prototype.hasOwnProperty.call(b.read,"prototype")')!.as_bool()
	assert class_eval(mut vm, 'var called=false;try{Box(1)}catch(e){called=e instanceof TypeError};var constructed=false;try{new b.read()}catch(e){constructed=e instanceof TypeError};called&&constructed')!.as_bool()
	assert class_eval(mut vm, 'class Empty{}var e=new Empty(1,2);e instanceof Empty&&Empty.length===0')!.as_bool()
}

fn test_class_accessors_static_and_computed_symbol_methods() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert class_eval(mut vm, 'var key=Symbol("answer"),order="";function name(v){order+=v;return v};class Access{constructor(){this.n=1}get value(){return this.n}set value(v){this.n=v}static get kind(){return "access"}[name("a")](){return 1}[key](){return 42}static [name("b")](){return 2}}var a=new Access();a.value=42;var d=Object.getOwnPropertyDescriptor(Access.prototype,"value");a.value===42&&Access.kind==="access"&&a[key]()===42&&Access.b()===2&&order==="ab"&&d.get.name==="get value"&&d.set.name==="set value"&&a[key].name==="[answer]"')!.as_bool()
	assert class_eval(mut vm, 'var read=Object.getOwnPropertyDescriptor(Access.prototype,"value").get,caught=false;try{read()}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
}

fn test_class_inner_name_is_immutable_outer_binding_mutable_and_keys_observe_tdz() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert class_eval(mut vm, 'var F=class Inner{static self(){return Inner}static change(){Inner=0}};var original=F;F=0;var caught=false;try{original.change()}catch(e){caught=e instanceof TypeError};original.self()===original&&typeof Inner==="undefined"&&caught')!.as_bool()
	assert class_eval(mut vm, 'var caught=false;try{class TDZ{[TDZ](){}}}catch(e){caught=e instanceof ReferenceError};caught&&typeof TDZ==="undefined"')!.as_bool()
	assert class_eval(mut vm, 'var caught=false;try{class Strict{[undeclaredClassKey=1](){}}}catch(e){caught=e instanceof ReferenceError};caught&&typeof undeclaredClassKey==="undefined"')!.as_bool()
	assert class_eval(mut vm, 'class Mutable{static self(){return Mutable}}var before=Mutable;Mutable=0;before.self()===before')!.as_bool()
	assert class_eval(mut vm, 'class Text{read(){return 42}}Text.toString()==="class Text{read(){return 42}}"')!.as_bool()
}

fn test_base_class_module_exports_and_persisted_native_execution() {
	directory := os.join_path(os.temp_dir(), 'vox-classes-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		mut record := SourceTextModule.parse('export class Box{constructor(v){this.v=v}read(){return this.v}}export const answer=new Box(42).read()', vm.realm(), 'class-export.mjs', unsafe { nil })!
		record.link(mut vm)!
		assert record.evaluate(mut vm)!.promise.state == .fulfilled
		assert record.export_value(mut vm, utf16_string('answer'))!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 3 && stats.compiler_invocations == 0 && activity.entries >= 4 }
		vm.close_native_code()!
	}
}

fn test_untranslated_class_slices_fail_before_executing_author_effects() {
	for source in ['class Field{#value=1}', 'class Private{#read(){}}', 'class Static{static{effect=1}}'] {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		class_eval(mut vm, 'var effect=0')!
		if _ := class_eval(mut vm, 'effect=42;'+source) { assert false } else { assert err.msg().contains('is not translated yet') }
		assert class_eval(mut vm, 'effect')!.number == 0
	}
}

fn test_class_bytecode_rejects_invalid_source_records_and_method_kinds() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for corrupt in ['source', 'method', 'field'] {
		mut script := Script.parse('class C{field;read(){return 42}}', vm.realm(), 'class-bytecode.js', unsafe { nil })!
		mut executable := script.compile(mut vm)!
		for mut instruction in executable.instructions {
			if corrupt == 'source' && instruction.op == .new_class { instruction.identifier = 0xffffffff }
			if corrupt == 'method' && instruction.op == .define_class_method { instruction.identifier = 3 }
			if corrupt == 'field' && instruction.op == .record_empty_class_field { instruction.identifier = 2 }
		}
		if _ := executable.validate(0) { assert false } else {
			assert err.msg() == if corrupt == 'source' { 'Class source index out of range' } else if corrupt == 'method' { 'Invalid class method kind' } else { 'Invalid class field kind' }
		}
	}
}
