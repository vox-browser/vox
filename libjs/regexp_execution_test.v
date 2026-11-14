module libjs

fn test_regexp_literals_constructor_exec_and_string_match_use_v_engine() {
	for source, expected in {
		'"rank 123.".match(/[0-9]+/)[0]': '"123"'
		'/x/.test("abc")': 'false'
		'var r=/a/g;r.exec("aba").index+":"+r.lastIndex+":"+r.exec("aba").index+":"+r.lastIndex': '"0:1:2:3"'
		'var r=/a/g;r.lastIndex=9;r.test("a")+":"+r.lastIndex': '"false:0"'
		'var r=/a/y;r.lastIndex=1;r.exec("ba").index': '1'
		'"a1 b22".match(/[0-9]+/g).join(",")': '"1,22"'
		'"😀".match(/(?:)/gu).length': '2'
		'"ab".match(/(?<letter>a)(z)?/).groups.letter': '"a"'
		'"ab".match(/(a)(z)?/)[2]': 'undefined'
		'"xab".match(/(?<x>a)(b)/d).indices.groups.x.join(":")': '"1:2"'
		'new RegExp("a+","i").test("AAA")': 'true'
		'var r=/a/;var s=RegExp(r);r===s': 'true'
		'var r=/a/;r.lastIndex=5;r.exec("a")[0]+":"+r.lastIndex': '"a:5"'
		'"abc".match({[Symbol.match]:function(s){return s+42}})': '"abc42"'
		'/a/igm.flags+":"+/a/.source': '"gim:a"'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut script := Script.parse(source, vm.realm(), 'regex.js', unsafe { nil })!
		value := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000}) or {
			if is_throw_completion(err) { eprintln(thrown_value(err).as_object().error_message() or { '' }) }
			panic(source + ': ' + err.msg())
		}
		assert value.str() == expected, source
	}
}

fn test_regexp_compile_errors_do_not_execute_preceding_code() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('var changed=1;/[z-a]/', vm.realm(), 'bad-regex.js', unsafe { nil })!
	if _ := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 1000}) { assert false }
	assert !vm.get_global_object().has_own_property(PropertyName.from_str('changed'))
}
