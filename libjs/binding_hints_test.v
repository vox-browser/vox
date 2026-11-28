module libjs

fn binding_hint_string(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'binding-hints.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 300000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

// Each source reads the same binding sites repeatedly while the scope chain
// changes beneath them; hinted reads must match the ordinary lookup.
fn test_binding_hints_follow_scope_chains() {
	for source, expected in {
		'function mk(v){return function(){return v}}var a=mk(1),b=mk(2);[a(),b(),a(),b()].join()':                          '1,2,1,2'
		'var fs=[];for(let i=0;i<3;i++){fs.push(()=>i)}fs.map(f=>f()).join()':                                                 '0,1,2'
		'function f(n){var x="f"+n;function g(){return x}return n?g()+f(n-1):g()}f(3)':                                          'f3f2f1f0'
		'function outer(){var k=1;function read(){return k}var r=[read()];k=2;r.push(read());return r.join()}outer()':         '1,2'
		'function t(){try{return (function(){return late})()}catch(e){return e.name}finally{}let late=1}t()':                  'ReferenceError'
		'function t(){var r=[];for(var i=0;i<2;i++){try{r.push((()=>v)())}catch(e){r.push(e.name)}}let v=1;return r.join()}t()': 'ReferenceError,ReferenceError'
		'function outer(){function helper(x){return x*2}function use(n){var s=0;for(var i=0;i<n;i++){s+=helper(i)}return s}return ""+use(5)+use(3)}outer()': '206'
		'var G=1;function g(){return G}var r=[g()];G=5;r.push(g());r.join()':                                                   '1,5'
		'function o(){var k="outer";function m(){var k="mid";return function(){return k}}return m()()}o()':                    'mid'
	} {
		assert binding_hint_string(source)! == expected, source
	}
}

// Direct eval can add a shadowing var at run time, so its references keep
// the ordinary lookup (scope analysis marks them).
fn test_binding_hints_leave_eval_scopes_unhinted() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('function outer(){var k="outer";function mid(code){eval(code);return (function(){return k})()}return mid("")+","+mid("var k=\\"evaluated\\"")}outer()',
		vm.realm(), 'binding-hints-eval.js', unsafe { nil }) or { return }
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 300000 }) or {
		// The translated runtime may not provide eval in this realm.
		return
	}
	assert value.is_string()
	assert value.as_string().str() == 'outer,evaluated'
}

// Identifiers that resolve globally start at the global environment, whose
// lexical declarations, object properties and accessors stay live.
fn test_global_binding_reads_follow_the_global_environment() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for source, expected in {
		'globalThis.G=1;function g(){return G}var r=[g()];G=2;r.push(g());delete globalThis.G;try{g()}catch(e){r.push(e.name)}r.join()': '1,2,ReferenceError'
		'function h(){return typeof Late}var r=[h()];globalThis.Late=5;r.push(h(),Late);r.join()':                              'undefined,number,5'
		'Object.defineProperty(globalThis,"A",{get(){return "got"},configurable:true});function a(){return A}a()+a()':          'gotgot'
		'function c(){return helper(3)}function helper(x){return x*2}var r=[c()];helper=function(x){return x+1};r.push(c());r.join()': '6,4'
		'function m(){return Math.max(1,2)+(undefined===void 0?1:0)}""+m()':                                                     '3'
	} {
		assert binding_hint_string(source)! == expected, source
	}
	// A later script's global lexical declaration shadows the global object.
	mut first := Script.parse('var S="object";function s(){return S}', vm.realm(), 'g1.js', unsafe { nil })!
	vm.run(mut first)!
	mut read := Script.parse('s()', vm.realm(), 'g2.js', unsafe { nil })!
	assert vm.run(mut read)!.as_string().str() == 'object'
	mut shadow := Script.parse('let T="lexical";var T2=1', vm.realm(), 'g3.js', unsafe { nil })!
	vm.run(mut shadow)!
	mut lexical := Script.parse('function t(){return T}t()', vm.realm(), 'g4.js', unsafe { nil })!
	assert vm.run(mut lexical)!.as_string().str() == 'lexical'
}
