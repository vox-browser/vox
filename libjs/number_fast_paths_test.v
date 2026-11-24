module libjs

import math

fn number_fast_eval(source string) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'number-fast-paths.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

// 7.1.6 ToInt32 for in-range, fractional, modular and non-finite Numbers.
fn test_number_to_i32_matches_modular_conversion() {
	numbers := [0.0, -0.0, 1.9, -1.9, 2147483647.0, 2147483647.9, 2147483648.0, -2147483648.0,
		-2147483648.5, -2147483649.0, 4294967296.0, 4294967301.0, -4294967297.0, 1.0e20]
	expected := [i32(0), 0, 1, -1, 2147483647, 2147483647, -2147483648, -2147483648, -2147483648,
		2147483647, 0, 5, -1, 1661992960]
	for index, number in numbers {
		assert number_to_i32(number) == expected[index], '${number}'
	}
	assert number_to_i32(math.nan()) == 0
	assert number_to_i32(math.inf(1)) == 0
	assert number_to_i32(math.inf(-1)) == 0
}

fn test_number_fast_paths_keep_operator_semantics() {
	for source, expected in {
		'(function(){var a=0.1,b=0.2;return a+b})()':                              0.30000000000000004
		'(function(){var a=7,b=2;return a%b+a/b+a*b-a})()':                       11.5
		'(function(){var a=-7,b=2;return a%b})()':                                -1.0
		'(function(){var a=2,b=10;return a**b})()':                               1024.0
		'(function(){var a=-1,b=28;return a>>>b})()':                             15.0
		'(function(){var a=-1,b=0;return a>>>b})()':                              4294967295.0
		'(function(){var a=1,b=33;return a<<b})()':                               2.0
		'(function(){var a=-16,b=2;return a>>b})()':                              -4.0
		'(function(){var a=4294967301,b=3;return a&b})()':                        1.0
		'(function(){var a=2147483648,b=0;return a|b})()':                        -2147483648.0
		'(function(){var a=5,b=3;return a^b})()':                                 6.0
		'(function(){var a=2147483647;a++;return a})()':                          2147483648.0
		'(function(){var n=0;for(var i=0;i<10;i++){n+=i}return n})()':            45.0
	} {
		actual := number_fast_eval(source)!
		assert actual.is_number(), source
		assert actual.number == expected, '${source}: ${actual.number}'
	}
	for source, expected in {
		'(function(){var a=NaN,b=1;return a<b||a<=b||a>b||a>=b||a==b})()': false
		'(function(){var a=NaN;return a!==a})()':                           true
		'(function(){var a=0,b=-0;return a===b&&a<=b&&a>=b&&!(a<b)})()':    true
		'(function(){var a=-0,b=0;return 1/(a-b)})()<0':                     true
		'(function(){var a=-0;a++;a--;return 1/a})()>0':                     true
		'(function(){var a="2",b=3;return a+b})()==="23"':                   true
		'(function(){var a="10",b=9;return a<b})()':                          false
		'(function(){var a=1n,b=2n;return a+b===3n&&a<b})()':                true
		'(function(){var o={valueOf(){return 4}},b=2;return o*b===8&&o>b})()': true
	} {
		actual := number_fast_eval(source)!
		assert actual.is_boolean(), source
		assert actual.as_bool() == expected, source
	}
}

fn test_inline_dispatch_keeps_uninitialized_and_type_errors() {
	// Inline handlers leave throwing cases to execute_instruction().
	assert number_fast_eval('(function(){var s=Symbol();try{return s+1}catch(e){return e instanceof TypeError}})()')!.as_bool()
	assert number_fast_eval('(function(){var a=1n;try{return a+1}catch(e){return e instanceof TypeError}})()')!.as_bool()
	assert number_fast_eval('(function(){var t="";if(t)return false;return !""})()')!.as_bool()
}

fn test_inline_bitwise_handlers_match_slow_paths() {
	for source, expected in {
		'(function(){var a=-7,b=2,r=[];r.push(a&b,a|b,a^b,a<<b,a>>b,a>>>b);return r.join()})()':                 '0,-5,-5,-28,-2,1073741822'
		'(function(){var a=4294967297.5,b=33;return [a|0,a<<b,a>>>0,-1>>>0].join()})()':                          '1,2,1,4294967295'
		'(function(){var a=NaN,b=Infinity;return [a|0,b&1,~~a].join()})()':                                      '0,0,0'
		'(function(){var a="12",b=3;return [a&b,a|b,typeof (a>>>b)].join()})()':                                 '0,15,number'
		'(function(){var a=12n,b=5n;return String(a&b)+String(a|b)})()':                                       '413'
		'(function(){var o={valueOf(){return 6}},b=3;return [o&b,o<<b].join()})()':                              '2,48'
	} {
		value := number_fast_eval(source)!
		assert value.is_string(), source
		assert value.as_string().str() == expected, source
	}
}
