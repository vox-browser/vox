// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn literal_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'literal.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_object_literal_prototype_setter_uses_syntax_and_ignores_primitive_values() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert literal_eval(mut vm, 'var p={answer:42};var a={__proto__:p};var b={"__proto__":null};a.answer+":"+Object.hasOwn(a,"__proto__")+":"+(Object.getPrototypeOf(b)===null)')!.as_string().str() == '42:false:true'
	assert literal_eval(mut vm, 'var computed={["__proto__"]:42};var __proto__=21;var short={__proto__};computed.__proto__+short.__proto__+":"+(Object.getPrototypeOf(computed)===Object.prototype)')!.as_string().str() == '63:true'
	assert literal_eval(mut vm, 'var calls=0;var ignored={__proto__:(calls++,42),x:41};calls+ignored.x+":"+Object.hasOwn(ignored,"__proto__")+":"+(Object.getPrototypeOf(ignored)===Object.prototype)')!.as_string().str() == '42:false:true'
	Script.parse('({__proto__:null,"__proto__":{}})', vm.realm(), 'duplicate-proto.js', unsafe { nil }) or {
		assert err is ScriptParseError
		return
	}
	assert false, 'Duplicate prototype setter syntax remains an early error'
}

fn test_object_literal_computed_keys_convert_before_value_and_only_once() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert literal_eval(mut vm, 'var order="";var key={toString:function(){order+="k";return "answer"}};var o={[key]:(order+="v",42)};order+":"+o.answer')!.as_string().str() == 'kv:42'
	assert literal_eval(mut vm, 'var hit=0;try{var fail={[{toString:function(){throw 17}}]:hit++}}catch(e){hit+=e};hit')!.number == 17
	assert literal_eval(mut vm, 'var symbol=Symbol("key");var value={[symbol]:42};value[symbol]+":"+(Object.getOwnPropertySymbols(value)[0]===symbol)')!.as_string().str() == '42:true'
}

fn test_object_literal_anonymous_functions_get_string_and_symbol_property_names() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert literal_eval(mut vm, 'var s=Symbol("description");var bare=Symbol();var o={plain:function(){return 20},[s]:function(){return 22},[bare]:()=>42,renamed:function explicit(){return 42}};o.plain.name+":"+o[s].name+":"+o[bare].name+":"+o.renamed.name+":"+(o.plain()+o[s]())')!.as_string().str() == 'plain:[description]::explicit:42'
	assert literal_eval(mut vm, 'var a={__proto__:null,c:function(e){return e+2}};a.c(40)+":"+a.c.name+":"+(Object.getPrototypeOf(a)===null)')!.as_string().str() == '42:c:true'
}
