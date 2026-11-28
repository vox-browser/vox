module libjs

fn test_direct_data_reads_remain_live_and_preserve_accessors_prototypes_and_lengths() {
	for enabled in [false, true] {
		set_direct_property_reads_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut script := Script.parse('var base={x:17};var o=Object.create(base);var a=[1,2];o.x=25;var n=o.x;delete o.x;n+o.x+a.length-2', vm.realm(), 'direct.js', unsafe { nil })!
		diagnose_direct_property_reads_for_testing(true)
		assert vm.run(mut script)!.number == 42
		assert (diagnose_direct_property_reads_for_testing(false) > 0) == enabled
		mut getters := Script.parse('var p={get x(){return this.n}};var q=Object.create(p);q.n=42;q.x', vm.realm(), 'getters.js', unsafe { nil })!
		assert vm.run(mut getters)!.number == 42
	}
	set_direct_property_reads_for_testing(true)
}
