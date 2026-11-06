module browserjs

fn module_lexer_test_wasm_available(mut runtime Runtime) bool {
	return runtime.evaluate_host('(function(){try{new WebAssembly.Module(new Uint8Array([0,97,115,109,1,0,0,0]));return true}catch(error){return false}})()') or { 'false' } == 'true'
}

fn module_lexer_test_functions(mut runtime Runtime, retain_asm bool) !(voidptr, voidptr) {
	return module_lexer_test_functions_with_copy(mut runtime, retain_asm, true)
}

fn module_lexer_test_functions_with_copy(mut runtime Runtime, retain_asm bool, native_copy bool) !(voidptr, voidptr) {
	factory := runtime.evaluate_host_value(module_source_factory_with_lexer(retain_asm))!
	defer { runtime.release_javascript_value(factory) }
	resolver := runtime.evaluate_host_value('(specifier,base,key)=>base+"|"+specifier')!
	defer { runtime.release_javascript_value(resolver) }
	copy_source := if native_copy { runtime.module_lexer_copy_function()! } else {
		C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	functions := runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [resolver, runtime.binding_string('__lexerFixture'), copy_source])!)!
	defer { runtime.release_javascript_value(functions) }
	mut exception := unsafe { nil }
	transform := runtime.retain_javascript_value(C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, functions, 0, &exception))!
	status := runtime.retain_javascript_value(C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, functions, 2, &exception))!
	assert exception == unsafe { nil }
	return transform, status
}

fn test_native_module_lexer_copy_preserves_wasm_rewrites_and_growth() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	candidate, _ := module_lexer_test_functions_with_copy(mut runtime, false, true)!
	control, _ := module_lexer_test_functions_with_copy(mut runtime, false, false)!
	for padding in [0, 1, 63, 512 * 1024, 19] {
		for source in [
			'/*' + 'é😀'.repeat(padding) + '*/import "./escaped.js";export const value=42;',
			r'import "./\u0061.js"; export {default} from "./second.js";',
			r'const result=import(`./${import("./nested.js")}.js`);',
			'/*\x00*/import "./nul.js";',
			'import "unterminated',
		] {
			assert module_lexer_test_rewrite(mut runtime, candidate, source, true, false)! ==
				module_lexer_test_rewrite(mut runtime, control, source, true, false)!
		}
	}
}

fn module_lexer_test_status(mut runtime Runtime, status voidptr) !string {
	value := runtime.call_javascript_function(status, C.vox_jsc_JSValueMakeUndefined(runtime.context), [])!
	return runtime.binding_dom_string(value)
}

fn module_lexer_test_rewrite(mut runtime Runtime, transform voidptr, source string, is_module bool, skip bool) !string {
	value := runtime.call_javascript_function(transform, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		runtime.binding_string(source), runtime.binding_string('https://lexer.test/base'),
		runtime.binding_string('https://lexer.test/key'),
		C.vox_jsc_JSValueMakeBoolean(runtime.context, is_module),
		C.vox_jsc_JSValueMakeBoolean(runtime.context, skip),
	])!
	return runtime.binding_dom_string(value)
}

fn test_wasm_specifier_lexer_is_lazy_and_matches_asm_rewrites() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	wasm_available := module_lexer_test_wasm_available(mut runtime)
	candidate, status := module_lexer_test_functions(mut runtime, false)!
	control, control_status := module_lexer_test_functions(mut runtime, true)!
	assert module_lexer_test_status(mut runtime, status)! == 'uninitialized'
	assert module_lexer_test_rewrite(mut runtime, candidate, 'const value=42;', true, true)! ==
		module_lexer_test_rewrite(mut runtime, control, 'const value=42;', true, true)!
	assert module_lexer_test_status(mut runtime, status)! == 'uninitialized'
	assert module_lexer_test_status(mut runtime, control_status)! == 'uninitialized'
	for source in [
		'import x from "./one.js"; export {x} from "./two.js";',
		'import.meta.url; export * from "./three.js";',
		'const p=import("./dynamic.js",{with:{type:"json"}});',
		'import(import("./inner.js").then(value=>"./outer.js"));',
		r'const value=`x${import("./template.js")}y`; export {value};',
		r'const pattern=/import\("x"\)/; export const importer=1/2;',
		r'import {value} from "./\u0061.js"; const text="é😀";',
		'#!/usr/bin/env node\nimport "./hashbang.js";',
		'/* unterminated', 'import(', 'const value="unterminated',
		r'import "./\8.js";', r'import "./\1.js";', r'import "./\u{}.js";',
		'import source value from "./module.wasm";',
	] {
		for is_module in [false, true] {
			assert module_lexer_test_rewrite(mut runtime, candidate, source, is_module, false)! ==
				module_lexer_test_rewrite(mut runtime, control, source, is_module, false)!
		}
	}
	assert module_lexer_test_status(mut runtime, status)! == if wasm_available { 'wasm' } else { 'asm-fallback' }
	assert module_lexer_test_status(mut runtime, control_status)! == 'asm-control'
}

fn test_wasm_specifier_lexer_retains_intrinsics_across_author_replacement() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	wasm_available := module_lexer_test_wasm_available(mut runtime)
	candidate, status := module_lexer_test_functions(mut runtime, false)!
	control, _ := module_lexer_test_functions(mut runtime, true)!
	runtime.evaluate_host('const fail=()=>{throw new Error("replaced intrinsic")}; if(typeof WebAssembly!=="undefined"){WebAssembly.Module=fail; Object.defineProperty(WebAssembly.Instance.prototype,"exports",{get:fail}); Object.defineProperty(WebAssembly.Memory.prototype,"buffer",{get:fail}); WebAssembly.Memory.prototype.grow=fail; Object.defineProperty(WebAssembly.Global.prototype,"value",{get:fail});} Uint16Array.prototype.set=fail; globalThis.WebAssembly=undefined; globalThis.atob=fail; globalThis.Buffer={from:fail}; globalThis.Uint8Array=fail; globalThis.Uint16Array=fail; globalThis.eval=fail;')!
	// Force linear-memory growth after the first parse as well.
	for padding in [0, 512 * 1024] {
		source := '/*' + 'x'.repeat(padding) + r'*/import "./\u006b' + 'ept.js"; export const value=42;'
		assert module_lexer_test_rewrite(mut runtime, candidate, source, true, false)! ==
			module_lexer_test_rewrite(mut runtime, control, source, true, false)!
	}
	assert module_lexer_test_status(mut runtime, status)! == if wasm_available { 'wasm' } else { 'asm-fallback' }
}

fn test_wasm_specifier_lexer_falls_back_when_unavailable_or_compilation_fails() {
	$if !darwin { return }
	for setup in ['globalThis.WebAssembly=undefined;',
		'globalThis.wasmAttempts=0; WebAssembly.Module=function(){globalThis.wasmAttempts++;throw new Error("wasm disabled")};'] {
		mut runtime := Runtime.create()
		wasm_available := module_lexer_test_wasm_available(mut runtime)
		runtime.evaluate_host(if setup.contains('wasmAttempts') && !wasm_available {
			'globalThis.wasmAttempts=0;'
		} else { setup })!
		candidate, status := module_lexer_test_functions(mut runtime, false)!
		control, _ := module_lexer_test_functions(mut runtime, true)!
		for _ in 0 .. 2 {
			assert module_lexer_test_rewrite(mut runtime, candidate, 'import "./fallback.js";', true, false)! ==
				module_lexer_test_rewrite(mut runtime, control, 'import "./fallback.js";', true, false)!
		}
		assert module_lexer_test_status(mut runtime, status)! == 'asm-fallback'
		if setup.contains('wasmAttempts') {
			assert runtime.evaluate_host('wasmAttempts')! == if wasm_available { '1' } else { '0' }
		}
		runtime.close()
	}
}
