module libjs

fn test_register_call_metadata_preserves_parameters_vars_and_argument_aliasing() {
	defer { set_register_call_metadata_for_testing(true) }
	defer { diagnose_register_call_metadata_for_testing(false) }
	for enabled in [false, true] {
		set_register_call_metadata_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		for source, expected in {
			'(function(a,b){var c=1,d=2,e=3,f=4,g=5,h=6,i=7,j=8,k=9,l=10;return a+b+c+d+e+f+g+h+i+j+k+l})(20,22)': '97'
			'(function(a,b){var c=1,d=2,e=3,f=4,g=5,h=6,i=7,j=8,k=9,l=10;return a+":"+b})(20)':                    '"20:undefined"'
			'(function(a,a){var a;return a})(1,2)':                                                                '2'
			'(function(a){arguments[0]=9;return a})(1)':                                                           '9'
			'(function(a){function f(){return a}var a;return f()})(42)':                                           '42'
			'(function(a){var before=typeof b;var b;return a+":"+before})(2)':                                     '"2:undefined"'
			'(function(a=3,...rest){return a+rest[0]})(undefined,4)':                                              '7'
		} {
			mut script := Script.parse(source, vm.realm(), 'register-call-metadata.js', unsafe { nil })!
			assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })!.str() == expected, source
		}
		diagnose_register_call_metadata_for_testing(true)
		mut script := Script.parse('function registerCallMetadata(a,b){var c=1,d=2,e=3,f=4,g=5,h=6,i=7,j=8,k=9,l=10;return a+b+c+d+e+f+g+h+i+j+k+l};registerCallMetadata(20,22);registerCallMetadata(20,22)', vm.realm(), 'metadata-counter.js', unsafe { nil })!
		assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })!.number == 97
		assert (diagnose_register_call_metadata_for_testing(false) > 0) == enabled
	}
}
