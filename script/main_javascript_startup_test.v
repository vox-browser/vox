module main

import browserjs
import os

fn test_startup_warmup_precedes_a_real_javascript_context() {
	$if macos {
		previous := os.getenv_opt('JSC_thresholdForJITAfterWarmUp')
		defer {
			if value := previous { os.setenv('JSC_thresholdForJITAfterWarmUp', value, true) }
			else { os.unsetenv('JSC_thresholdForJITAfterWarmUp') }
		}
		os.unsetenv('JSC_thresholdForJITAfterWarmUp')
		configure_browser_javascript_startup()
		assert os.getenv('JSC_thresholdForJITAfterWarmUp') == '10000'
		mut runtime := browserjs.Runtime.create()
		defer { runtime.close() }
		assert runtime.evaluate_host('(()=>{let n=0;for(let i=0;i<100000;i++)n+=i;return n})()')! == '4999950000'
	}
}

fn test_startup_warmup_preserves_explicit_engine_options() {
	$if macos {
		previous := os.getenv_opt('JSC_thresholdForJITAfterWarmUp')
		defer {
			if value := previous { os.setenv('JSC_thresholdForJITAfterWarmUp', value, true) }
			else { os.unsetenv('JSC_thresholdForJITAfterWarmUp') }
		}
		for value in ['500', '2000', '10000', ''] {
			os.setenv('JSC_thresholdForJITAfterWarmUp', value, true)
			configure_browser_javascript_startup()
			assert os.getenv_opt('JSC_thresholdForJITAfterWarmUp')? == value
		}
	}
}
