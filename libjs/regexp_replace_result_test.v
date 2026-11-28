module libjs

fn replacement_result_eval(source string, budget u64) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'replace-results.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: budget})
}

fn test_internal_regexp_replace_results_preserve_captures_groups_and_callbacks() {
	defer { set_internal_regexp_replace_results_for_testing(true) }
	for enabled in [false, true] {
		set_internal_regexp_replace_results_for_testing(enabled)
		for source, expected in {
			'"abc".replace(/(b)/g,"[$1]-$&")': 'a[b]-bc'
			'"b".replace(/(a)?b/,"$1x")': 'x'
			'"abc".replace(/(?<part>b)/dg,"[$<part>]")': 'a[b]c'
			'"ab".replace(/(?<part>.)/g,function(m,p,i,s,g){return g.part+i})': 'a0b1'
			'"ab".replace(/(?:)/g,"x")': 'xaxbx'
			'"abc".replace(/z/g,"x")': 'abc'
			'var r=/x/y;r.lastIndex={valueOf(){r.lastIndex=0;RegExp.prototype.exec.call(r,"x");return 0}};RegExp.prototype[Symbol.replace].call(r,"x","y")': 'y'
		} {
			assert replacement_result_eval(source, 100000)!.as_string().utf16.str() == expected, source
		}
		order := replacement_result_eval('var log=[];var match={get length(){log.push("length");return 2},get 0(){log.push("0");return "x"},get index(){log.push("index");return 0},get 1(){log.push("1");return "y"},get groups(){log.push("groups");return undefined}};RegExp.prototype[Symbol.replace].call({flags:"",exec(){log.push("exec");return match}},"x","$1");log.join(",")', 100000)!
		assert order.as_string().utf16.str() == 'exec,length,0,index,1,groups'
	}
}

fn test_internal_regexp_replace_results_preserve_exact_budget_boundaries() {
	defer { set_internal_regexp_replace_results_for_testing(true) }
	for budget in 1 .. 100 {
		mut completed := []bool{}
		for enabled in [false, true] {
			set_internal_regexp_replace_results_for_testing(enabled)
			if value := replacement_result_eval('"abab".replace(/(a)(b)/g,"$2$1")', u64(budget)) {
				assert value.as_string().utf16.str() == 'baba'
				completed << true
			} else {
				assert is_throw_completion(err)
				assert thrown_value(err).as_object().error_message()?.contains('budget')
				completed << false
			}
		}
		assert completed[0] == completed[1], 'Budget ${budget}'
	}
}
