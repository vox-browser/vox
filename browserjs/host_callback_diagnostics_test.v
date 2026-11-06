module browserjs

import platform

fn test_host_callback_diagnostics_sample_first_and_every_sixty_fourth_invocation() {
	mut diagnostic := &HostCallbackDiagnostic{}
	for _ in 0 .. 130 {
		start := begin_host_callback_diagnostic(diagnostic)
		finish_host_callback_diagnostic(diagnostic, start)
	}
	assert diagnostic.calls == 130
	assert diagnostic.sample_attempts == 3
	$if darwin {
		assert diagnostic.samples == 3
		assert diagnostic.minimum_instructions > 0
		assert diagnostic.maximum_instructions >= diagnostic.minimum_instructions
		assert diagnostic.inclusive_instructions >= diagnostic.maximum_instructions
	}
	// A missing counter or nonsampled invocation is never recorded as zero work.
	previous := diagnostic.samples
	finish_host_callback_diagnostic(diagnostic, begin_host_callback_diagnostic(unsafe { nil }))
	assert diagnostic.samples == previous
}

fn test_host_callback_diagnostics_keep_native_results_exceptions_and_distinct_records() {
	$if !darwin && !linux {
		return
	}
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	runtime.define_host_function('diagnosticEcho', fn (input string) !string { return input + '!' })!
	runtime.define_host_function('diagnosticFailure', fn (_ string) !string {
		return error('original failure')
	})!
	runtime.define_value_host_function('diagnosticValue', fn (_ voidptr, args []voidptr) !voidptr {
		return args[0]
	})!
	assert runtime.evaluate_host(r'(()=>{for(let i=0;i<67;i++)if(diagnosticEcho("é")!=="é!"||diagnosticValue(i)!==i)throw 1;try{diagnosticFailure("x")}catch(e){return String(e).includes("original failure")}return false})()')! == 'true'
	for record in runtime.host_functions_ {
		if host_callback_diagnostics_enabled {
			assert record.diagnostic != unsafe { nil }
			assert record.diagnostic.calls == if record.diagnostic.name == 'diagnosticEcho' {
				u64(67)
			} else {
				u64(1)
			}
			assert record.diagnostic.site_count > 0 && record.diagnostic.site_count <= 12
		} else {
			assert record.diagnostic == unsafe { nil }
		}
	}
	for record in runtime.value_host_functions_ {
		if host_callback_diagnostics_enabled {
			assert record.diagnostic != unsafe { nil }
			if record.diagnostic.name == 'diagnosticValue' {
				assert record.diagnostic.calls == 67
			}
		} else {
			assert record.diagnostic == unsafe { nil }
		}
	}
}

fn test_host_callback_diagnostic_labels_survive_retired_scratch_without_retaining_it() {
	work := platform.begin_thread_scratch('diagnostic registration caller')
	name := 'diagnostic-' + 'label'.repeat(30)
	diagnostic := new_host_callback_diagnostic(name)
	work.finish()
	if host_callback_diagnostics_enabled {
		assert diagnostic != unsafe { nil }
		assert diagnostic.name == 'diagnostic-' + 'label'.repeat(30)
		start := begin_host_callback_diagnostic(diagnostic)
		finish_host_callback_diagnostic(diagnostic, start)
		assert diagnostic.calls == 1
	} else {
		assert diagnostic == unsafe { nil }
	}
}
