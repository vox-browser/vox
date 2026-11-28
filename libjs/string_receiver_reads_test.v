module libjs

fn string_receiver_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'string-receiver.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 300000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

// Property reads on primitive strings: length and indices are own; other keys
// read String.prototype (then Object.prototype) with the primitive receiver,
// including replaced methods, accessors and symbol keys.
fn test_string_receiver_reads_keep_get_value_semantics() {
	for source, expected in {
		'var s="héllo";var k="length";[s.length,s[1],s["0"],s[k],s[9],s["9"],s.charAt(4)].join()':                        '5,é,h,5,,,o'
		'var s="ab";Object.defineProperty(String.prototype,"probe",{get(){"use strict";return typeof this+this.length},configurable:true});var r=s.probe;delete String.prototype.probe;[r,s.probe].join()': 'string2,'
		'var s="ab";var a=s.toUpperCase();String.prototype.toUpperCase=function(){return "patched"};var b=s.toUpperCase();[a,b,s.hasOwnProperty("length"),s.hasOwnProperty("x")].join()': 'AB,patched,true,false'
		'var s="ab";Object.defineProperty(String.prototype,"loose",{get(){return typeof this+(this instanceof String)},configurable:true});var r=s.loose;delete String.prototype.loose;r': 'objecttrue'
		'var g=function(x){return typeof x.at+typeof x.length};var o={at:1};[g("s"),g(o),g("t"),g([]),g(o)].join()':                    'functionnumber,numberundefined,functionnumber,functionnumber,numberundefined'
		'var s="abc";var o="";for(var i=-1;i<4;i++)o+=String(s[i])+"|";o':                                                                     'undefined|a|b|c|undefined|'
		'var s="xy";var it=s[Symbol.iterator]();[typeof s[Symbol.iterator],it.next().value,s.missing,s.constructor===String].join()': 'function,x,,true'
		'var f=function(){var s="q";var t=0;for(var i=0;i<20;i++){t+=s.length;if(i==10)String.prototype.length=7}return t};String(f())':     '20'
	} {
		assert string_receiver_eval(source)! == expected, source
	}
}

// With wrapper elision off, the read boxes the string after the key has been
// converted once; the key's toString must not run again.
fn test_string_receiver_reads_without_wrapper_elision_convert_keys_once() {
	defer { set_primitive_reads_for_testing(true) }
	for enabled in [true, false] {
		set_primitive_reads_for_testing(enabled)
		source := 'var n=0;var k={toString(){n++;return "slice"}};var r=[];for(var i=0;i<3;i++)r.push(typeof "x"[k]);r.push(n,"ab"[{toString(){n+=10;return "1"}}],n);r.join()'
		assert string_receiver_eval(source)! == 'function,function,function,3,b,13', '${enabled}'
	}
}
