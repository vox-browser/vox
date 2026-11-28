// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn private_class_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'private-class.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})!
}

fn check_private_class(source string) !bool {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	value := private_class_eval(mut vm, source)!
	assert vm.running_execution_context().private_environment == none
	return value.as_bool()
}

fn test_private_fields_read_write_update_and_brand_without_ordinary_properties() {
	assert check_private_class('class C{#x=40;read(){this.#x+=1;var old=this.#x++;return old+this.#x}static has(o){return #x in o}}var c=new C();c.read()===83&&C.has(c)&&!C.has({})&&Object.keys(c).length===0&&!Object.hasOwn(c,"#x")')!
	assert check_private_class('class C{#x;read(){this.#x??=42;this.#x&&=43;return this.#x}}new C().read()===43')!
	assert check_private_class('class C{#x=42;read(o){return o.#x}}var c=new C(),caught=0;for(var x of [null,undefined,1,{},Object.create(c)]){try{c.read(x)}catch(e){if(e instanceof TypeError)caught++}}caught===5')!
	assert check_private_class('class C{before=#x in this;#x=42;after=#x in this;static before=#s in this;static #s=7;static after=#s in this}var c=new C();!c.before&&c.after&&!C.before&&C.after')!
}

fn test_private_methods_install_before_fields_preserve_receivers_and_cannot_be_written() {
	assert check_private_class('class C{x=this.#m();#m(){return 42}read(){return this.#m.name==="#m"&&!("prototype" in this.#m)}static has(o){return #m in o}}var c=new C();c.x===42&&c.read()&&C.has(c)&&!C.has(C.prototype)&&Object.keys(c).join()==="x"')!
	assert check_private_class('class C{#m(){return this}read(){var caught=false;try{this.#m=1}catch(e){caught=e instanceof TypeError};return caught&&this.#m()===this}}new C().read()')!
}

fn test_private_accessors_merge_getters_setters_and_keep_native_brand_checks() {
	assert check_private_class('class C{#x=40;get #v(){return this.#x}set #v(v){this.#x=v}read(){this.#v+=2;return this.#v}}new C().read()===42')!
	assert check_private_class('class C{set #v(v){this.answer=v}read(){this.#v=42;var caught=false;try{this.#v}catch(e){caught=e instanceof TypeError};return caught&&this.answer===42}}new C().read()')!
	assert check_private_class('class C{get #v(){return 42}read(){var caught=false;try{this.#v=1}catch(e){caught=e instanceof TypeError};return caught&&this.#v===42}}new C().read()')!
}

fn test_static_private_elements_install_before_static_initializers_and_are_not_inherited_brands() {
	assert check_private_class('class C{static x=this.#m();static #value=40;static #m(){return 42}static get #v(){return this.#value}static set #v(v){this.#value=v}static read(){this.#v+=2;return this.#v}static has(o){return #m in o}}class D extends C{}var caught=false;try{D.read()}catch(e){caught=e instanceof TypeError};C.x===42&&C.read()===42&&C.has(C)&&!C.has(D)&&caught')!
}

fn test_class_evaluations_have_distinct_private_identities_and_nested_scopes() {
	assert check_private_class('function factory(){return class{#x=42;static has(o){return #x in o}}}var A=factory(),B=factory();A.has(new A())&&!A.has(new B())&&B.has(new B())')!
	assert check_private_class('class O{#x=42;make(){return class I{read(o){return o.#x}}}}var o=new O(),I=o.make();new I().read(o)===42')!
	assert check_private_class('class O{#x=42;read(){class I{#x=7;read(o){return o.#x}}var caught=false;try{new I().read(this)}catch(e){caught=e instanceof TypeError};return caught&&this.#x===42&&new I().read(new I())===7}}new O().read()')!
	assert check_private_class('class O{#x=Object;make(){var outer=this;return class I extends this.#x{#x=42;[(#x in outer)?"bad":"good"](){return this.#x}}}}var I=new O().make();new I().good()===42')!
}

fn test_private_scope_restores_after_computed_key_or_static_initializer_throws() {
	assert check_private_class('class O{#x=42;read(){try{class I{#x;[(()=>{throw 7})()](){}}}catch(e){}return this.#x}}new O().read()===42')!
	assert check_private_class('class O{#x=42;read(){try{class I{#x;static y=(()=>{throw 7})()}}catch(e){}return this.#x}}new O().read()===42')!
}

fn test_private_fields_stamp_nonextensible_super_returns_and_reject_duplicate_initialization() {
	assert check_private_class('class B{constructor(o){return o}}class C extends B{#x=42;static read(o){return o.#x}}var o=Object.preventExtensions({});new C(o);var caught=false;try{new C(o)}catch(e){caught=e instanceof TypeError};C.read(o)===42&&caught&&!Object.isExtensible(o)&&Object.keys(o).length===0')!
}

fn test_private_optional_access_and_private_in_rejects_primitives() {
	assert check_private_class('class C{#x=42;read(o){return o?.#x}static has(o){return #x in o}}var c=new C(),caught=false;try{C.has(1)}catch(e){caught=e instanceof TypeError};c.read(null)===undefined&&c.read(c)===42&&caught')!
}

fn test_private_class_native_entries_reuse_in_fresh_vm_with_compiler_disabled() {
	directory := os.join_path(os.temp_dir(), 'vox-private-class-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert private_class_eval(mut vm, 'class C{#x=40;#m(){return this.#x+2}read(){return this.#m()}static has(o){return #x in o}}var c=new C();C.has(c)&&c.read()===42')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 5 && stats.compiler_invocations == 0 && activity.entries >= 5 }
		vm.close_native_code()!
	}
}
