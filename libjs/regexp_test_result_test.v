module libjs

fn regexp_test_result_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'regexp-test-result.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_regexp_boolean_results_keep_exec_dispatch_and_reentrancy() {
	for enabled in [false, true] {
		set_regexp_test_results_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		for source in [
			'var r=/(?<a>a)(b)?/dg;r.test("a")&&r.lastIndex===1&&!r.test("a")&&r.lastIndex===0',
			'var r=/a/y;r.lastIndex=1;r.test("ba")&&r.lastIndex===2&&!r.test("ba")&&r.lastIndex===0',
			'var r=/a/,log="",exec=RegExp.prototype.exec;Object.defineProperty(r,"exec",{get(){log+="g";return exec}});r.test("a")&&r.test("a")&&log==="gg"',
			'var r=/a/,seen="";r.exec=function(s){seen=s;return {}};r.test("b")&&seen==="b"',
			'var r=/a/,seen="";r.exec=function(s){seen=s;return null};!r.test("b")&&seen==="b"',
			'var r=/a/g,inner;r.lastIndex={valueOf(){inner=/(?<x>b)/d.exec("b");return 0}};r.test("a")&&inner[0]==="b"&&inner.groups.x==="b"&&inner.indices.groups.x[1]===1&&r.lastIndex===1',
			'var r=/a/g;r.exec=undefined;r.test("a")&&r.lastIndex===1',
			'var r=/a/,bad=false;r.exec=function(){return 1};try{r.test("a")}catch(e){bad=e instanceof TypeError}bad',
			'var bad=false;try{RegExp.prototype.test.call({exec:RegExp.prototype.exec},"a")}catch(e){bad=e instanceof TypeError}bad',
			'var r=/(?<a>a)(b)?/dg;r.test("a");r.lastIndex=0;var m=r.exec("a");m!==r&&m[0]==="a"&&m[1]==="a"&&m[2]===undefined&&m.index===0&&m.input==="a"&&m.groups.a==="a"&&m.indices[0][1]===1',
		] {
			assert regexp_test_result_eval(mut vm, source)!.as_bool(), source
		}
	}
	set_regexp_test_results_for_testing(true)
}

fn test_empty_regexp_replacement_keeps_coercion_and_exec_side_effect_order() {
	for enabled in [false, true] {
		set_empty_regexp_replacements_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		for source in [
			'var log="",r=/z/g;Object.defineProperty(r,"flags",{get(){log+="f";return "g"}});r.exec=function(s){log+="e";return null};var replacement={toString(){log+="r";return "x"}};"abc".replace(r,replacement)==="abc"&&log==="rfe"&&r.lastIndex===0',
			'var called=0;"abc".replace(/z/g,function(){called++;return "x"})==="abc"&&called===0',
			'"".replace(/z/,"x")===""&&"😀".replace(/z/gu,"x")==="😀"',
		] {
			assert regexp_test_result_eval(mut vm, source)!.as_bool(), source
		}
	}
	set_empty_regexp_replacements_for_testing(true)
}
