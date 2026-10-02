module browserjs

import libjs

fn install_string_test_host(mut runtime Runtime) {
	mut vm := runtime.libjs_vm()
	realm := vm.realm()
	parent := libjs.Object.create(realm, none)
	// Test-only method host using the real String exotic record. Full
	// StringPrototype initialization and its remaining methods are not installed.
	mut prototype := libjs.StringObject.create(realm, vm.empty_string(), parent).object
	behaviours := [libjs.NativeFunctionPointer(libjs.string_prototype_at), libjs.string_prototype_char_at,
		libjs.string_prototype_char_code_at, libjs.string_prototype_code_point_at,
		libjs.string_prototype_concat, libjs.string_prototype_index_of,
		libjs.string_prototype_last_index_of, libjs.string_prototype_slice,
		libjs.string_prototype_substring, libjs.string_prototype_substr, libjs.string_prototype_to_string,
		libjs.string_prototype_value_of, libjs.string_prototype_is_well_formed,
		libjs.string_prototype_to_well_formed, libjs.string_prototype_trim,
		libjs.string_prototype_trim_start, libjs.string_prototype_trim_end, libjs.string_prototype_repeat,
		libjs.string_prototype_pad_start, libjs.string_prototype_pad_end, libjs.string_prototype_anchor,
		libjs.string_prototype_big, libjs.string_prototype_blink, libjs.string_prototype_bold,
		libjs.string_prototype_fixed, libjs.string_prototype_fontcolor, libjs.string_prototype_fontsize,
		libjs.string_prototype_italics, libjs.string_prototype_link, libjs.string_prototype_small,
		libjs.string_prototype_strike, libjs.string_prototype_sub, libjs.string_prototype_sup,
		libjs.string_prototype_to_lowercase, libjs.string_prototype_to_uppercase,
		libjs.string_prototype_normalize]
	names := ['at', 'charAt', 'charCodeAt', 'codePointAt', 'concat', 'indexOf', 'lastIndexOf',
		'slice', 'substring', 'substr', 'toString', 'valueOf', 'isWellFormed', 'toWellFormed',
		'trim', 'trimStart', 'trimEnd', 'repeat', 'padStart', 'padEnd', 'anchor', 'big', 'blink',
		'bold', 'fixed', 'fontcolor', 'fontsize', 'italics', 'link', 'small', 'strike', 'sub',
		'sup', 'toLowerCase', 'toUpperCase', 'normalize']
	lengths := [1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1,
		0, 1, 0, 0, 0, 0, 0, 0, 0]
	for index, name in names {
		method := libjs.NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
			behaviours[index], lengths[index], libjs.PropertyName.from_str(name), none)
		prototype.define_direct_property(libjs.PropertyName.from_str(name),
			libjs.Value.from_object(method.object), 5)
	}
	iterator := libjs.StringIteratorPrototype.create(mut vm, realm, parent).object
	getter := fn [iterator] (realm &libjs.Realm) &libjs.Object {
		return iterator
	}
	next_method := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn [getter] (mut vm libjs.VM) !libjs.Value {
		return libjs.string_prototype_symbol_iterator(mut vm, getter)
	}, 0, libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()), none)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()),
		libjs.Value.from_object(next_method.object), 5)
	constructor := libjs.StringConstructor.create(mut vm, realm, libjs.StringConstructorDependencies{
		prototype:        prototype
		prototype_getter: fn [prototype] (realm &libjs.Realm) &libjs.Object {
			return prototype
		}
		primitives:       libjs.PrimitiveObjectPrototypes{
			string: fn [prototype] (realm &libjs.Realm) &libjs.Object {
				return prototype
			}
			number: fn [parent] (realm &libjs.Realm) &libjs.Object {
				return parent
			}
			bigint: fn [parent] (realm &libjs.Realm) &libjs.Object {
				return parent
			}
		}
	}).object
	mut global := vm.get_global_object()
	global.define_direct_property(libjs.PropertyName.from_str('HostString'),
		libjs.Value.from_object(constructor), 7)
	// Object literals are pending: expose a real template record as a fixture.
	mut template := libjs.Object.create(realm, none)
	template.define_direct_property(libjs.PropertyName.from_str('raw'),
		libjs.Value.from_string(vm.create_string_from_str('AB')), 7)
	global.define_direct_property(libjs.PropertyName.from_str('HostTemplate'),
		libjs.Value.from_object(template), 7)
}

fn test_browser_string_constructor_static_methods_and_exotic_wrappers_execute_native_records() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_string_test_host(mut runtime)
	assert runtime.evaluate('HostString.name==="String" && HostString.length===1 && HostString.fromCharCode.length===1 && HostString.raw.length===1;')! == 'true'
	assert runtime.evaluate('HostString()==="" && HostString(undefined)==="undefined" && HostString(Symbol("x"))==="Symbol(x)" && HostString(123456789123456789n)==="123456789123456789";')! == 'true'
	assert runtime.evaluate('HostString.fromCharCode(65,66,67)==="ABC" && HostString.fromCharCode(-1)==="\\uffff" && HostString.fromCodePoint(128512)==="😀";')! == 'true'
	assert runtime.evaluate('var boxed=new HostString("😀A"); boxed.length===3 && boxed[0]==="\\ud83d" && boxed[1]==="\\ude00" && boxed.valueOf()==="😀A" && HostString(boxed)==="😀A";')! == 'true'
	assert runtime.evaluate('HostString.prototype.valueOf()==="" && HostString.prototype.constructor===HostString && HostString.raw(HostTemplate,10,"ignored")==="A10B";')! == 'true'
	assert runtime.evaluate('var make=HostString.bind(null,"bound"); (new make()).valueOf()==="bound";')! == 'true'
	assert runtime.context == unsafe { nil }
}

fn test_browser_string_native_methods_preserve_utf16_boundaries_and_live_iterator_state() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_string_test_host(mut runtime)
	assert runtime.evaluate('var text=new HostString("😀ab😀"); text.at(-1)==="\\ude00" && text.charCodeAt(0)===55357 && text.codePointAt(0)===128512 && text.charAt(1)==="\\ude00";')! == 'true'
	assert runtime.evaluate('text.slice(0,1)==="\\ud83d" && text.substring(4,2)==="ab" && text.substr(-2,2)==="😀" && text.indexOf("\\ude00")===1 && text.lastIndexOf("😀")===4;')! == 'true'
	assert runtime.evaluate('HostString.prototype.concat.call("a",42,null,false)==="a42nullfalse" && HostString.prototype.trim.call("  😀  ")==="😀";')! == 'true'
	assert runtime.evaluate('HostString.prototype.trimStart.call("  a  ")==="a  " && HostString.prototype.trimEnd.call("  a  ")==="  a";')! == 'true'
	assert runtime.evaluate('HostString.prototype.isWellFormed.call("😀") && !HostString.prototype.isWellFormed.call("\\ud800") && HostString.prototype.toWellFormed.call("\\ud800A\\udc00")==="\\ufffdA\\ufffd";')! == 'true'
	assert runtime.evaluate('var iterator=text[Symbol.iterator](); iterator.next().value==="😀" && iterator.next().value==="a" && iterator.next().value==="b" && iterator.next().value==="😀" && iterator.next().done && iterator.next().done;')! == 'true'
	assert runtime.evaluate('var slice=text.slice.bind(text,2,4); slice()==="ab";')! == 'true'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_string_conversion_brand_and_range_errors_restore_later_script_execution() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_string_test_host(mut runtime)
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'new HostString(Symbol("x"));', url: 'string-symbol.js' },
		ScriptSource{ code: 'HostString.fromCharCode(1n);', url: 'string-bigint.js' },
		ScriptSource{ code: 'HostString.fromCodePoint(1114112);', url: 'string-codepoint.js' },
		ScriptSource{ code: 'HostString.raw();', url: 'string-raw.js' },
		ScriptSource{ code: 'HostString.prototype.valueOf.call(42);', url: 'string-brand.js' },
		ScriptSource{ code: 'HostString.prototype.at.call(null);', url: 'string-null.js' },
		ScriptSource{
			code: 'HostString.prototype.indexOf.call("text",Symbol("x"));'
			url:  'string-search.js'
		},
	])
	assert errors.len == 7
	for index, message in ['Cannot convert symbol to string', 'Cannot convert BigInt to number',
		'Invalid code point 1114112', 'ToObject on null or undefined', 'Not an object of type String',
		'null cannot be converted to an object', 'Cannot convert symbol to string'] {
		assert errors[index].contains(message)
	}
	assert errors[0].contains('string-symbol.js')
	assert runtime.evaluate('HostString.fromCodePoint(4294967296).length===1 && HostString.fromCodePoint(4294967361)==="A";')! == 'true'
	assert runtime.evaluate('HostString(42);')! == '42'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_string_unicode_case_and_normalization_preserve_utf16_and_error_recovery() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_string_test_host(mut runtime)
	assert runtime.evaluate('var text=new HostString("İßﬃ😀"); text.toLowerCase()==="i\\u0307ßﬃ😀" && text.toUpperCase()==="İSSFFI😀";')! == 'true'
	assert runtime.evaluate('var sigma=new HostString("ΟΣ"); sigma.toLowerCase()==="ος" && (new HostString("ΟΣΑ")).toLowerCase()==="οσα";')! == 'true'
	assert runtime.evaluate('var norm=new HostString("\\u1e9b\\u0323"); norm.normalize()==="\\u1e9b\\u0323" && norm.normalize("NFD")==="\\u017f\\u0323\\u0307" && norm.normalize("NFKC")==="\\u1e69" && norm.normalize("NFKD")==="s\\u0323\\u0307";')! == 'true'
	assert runtime.evaluate('var bound=norm.normalize.bind(norm,"NFKC"); bound()==="\\u1e69" && text.toLowerCase.length===0 && text.toUpperCase.length===0 && norm.normalize.length===0;')! == 'true'
	assert runtime.evaluate('var raw=HostString.fromCharCode(55296,0,65,769,56320); var unpaired=new HostString(raw); unpaired.normalize()===HostString.fromCharCode(55296,0,193,56320) && unpaired.toLowerCase()===HostString.fromCharCode(55296,0,97,769,56320);')! == 'true'
	assert runtime.evaluate('text.toLowerCase(Symbol("ignored"))==="i\\u0307ßﬃ😀" && (new HostString("e\\u0301")).normalize(undefined)==="é";')! == 'true'
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'norm.normalize("NFC1");', url: 'string-normalization-form.js' },
		ScriptSource{ code: 'norm.normalize(Symbol("x"));', url: 'string-normalization-symbol.js' },
		ScriptSource{
			code: 'HostString.prototype.toLowerCase.call(null);'
			url:  'string-case-null.js'
		},
		ScriptSource{
			code: 'HostString.prototype.toUpperCase.call(undefined);'
			url:  'string-case-undefined.js'
		},
		ScriptSource{
			code: 'HostString.prototype.toLowerCase.call(Symbol("x"));'
			url:  'string-case-symbol.js'
		},
	])
	assert errors.len == 5
	for index, message in [
		"The normalization form must be one of NFC, NFD, NFKC, NFKD. Got 'NFC1'",
		'Cannot convert symbol to string',
		'null cannot be converted to an object',
		'undefined cannot be converted to an object',
		'Cannot convert symbol to string',
	] {
		assert errors[index].contains(message)
	}
	assert runtime.evaluate('norm.normalize("NFKD")==="s\\u0323\\u0307" && text.toUpperCase()==="İSSFFI😀";')! == 'true'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_string_repeat_padding_and_legacy_html_execute_translated_native_bodies() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_string_test_host(mut runtime)
	assert runtime.evaluate('var text=new HostString("😀"); text.repeat(2)==="😀😀" && text.padStart(3,"😀")==="\\ud83d😀" && text.padEnd(5,"😀")==="😀😀\\ud83d";')! == 'true'
	assert runtime.evaluate('var repeat=text.repeat.bind(text,2); repeat()==="😀😀" && text.repeat.length===1 && text.padStart.length===1 && text.padEnd.length===1;')! == 'true'
	assert runtime.evaluate('text.padStart(2,Symbol("ignored"))==="😀" && text.padEnd(Infinity,"")==="😀" && HostString.prototype.repeat.call("",1e300)==="";')! == 'true'
	assert runtime.evaluate('var quote=HostString.fromCharCode(34); var legacy=new HostString("x"); legacy.anchor(quote)==="<a name="+quote+"&quot;"+quote+">x</a>" && legacy.link("&<")==="<a href="+quote+"&<"+quote+">x</a>";')! == 'true'
	assert runtime.evaluate('legacy.fontcolor("red")==="<font color="+quote+"red"+quote+">x</font>" && legacy.fontsize(3)==="<font size="+quote+"3"+quote+">x</font>";')! == 'true'
	for index, method in ['big', 'blink', 'bold', 'fixed', 'italics', 'small', 'strike', 'sub',
		'sup'] {
		tag := ['big', 'blink', 'b', 'tt', 'i', 'small', 'strike', 'sub', 'sup'][index]
		assert runtime.evaluate('legacy.${method}(Symbol("ignored"))==="<${tag}>x</${tag}>" && legacy.${method}.length===0;')! == 'true'
	}
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'text.repeat(-1);', url: 'string-repeat-negative.js' },
		ScriptSource{ code: 'text.repeat(Infinity);', url: 'string-repeat-infinite.js' },
		ScriptSource{ code: 'text.repeat(1099511627775);', url: 'string-repeat-overflow.js' },
		ScriptSource{ code: 'text.padEnd(5,Symbol("x"));', url: 'string-padding-symbol.js' },
		ScriptSource{ code: 'legacy.anchor(Symbol("x"));', url: 'string-html-symbol.js' },
	])
	assert errors.len == 5
	for index, message in ['repeat count must be a positive number',
		'repeat count must be a finite number', 'repeat count must not overflow',
		'Cannot convert symbol to string', 'Cannot convert symbol to string'] {
		assert errors[index].contains(message)
	}
	assert runtime.evaluate('legacy.bold()==="<b>x</b>" && text.repeat(1)==="😀";')! == 'true'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}
