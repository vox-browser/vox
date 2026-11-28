// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import os

fn test_replay_date_clock_uses_the_requested_epoch_without_rewriting_author_code() {
	previous := os.getenv_opt('VOX_LIBJS_DATE_EPOCH_MS')
	defer {
		if value := previous {
			os.setenv('VOX_LIBJS_DATE_EPOCH_MS', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_DATE_EPOCH_MS')
		}
	}
	os.setenv('VOX_LIBJS_DATE_EPOCH_MS', '946684800000', true)
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.agent_vm.date_clock_epoch_milliseconds()? == 946684800000
	assert runtime.evaluate_host('new Date().getUTCFullYear()===2000&&new Date(123).getTime()===123')! == 'true'
}

fn test_invalid_replay_date_epoch_does_not_replace_the_system_clock() {
	previous := os.getenv_opt('VOX_LIBJS_DATE_EPOCH_MS')
	defer {
		if value := previous {
			os.setenv('VOX_LIBJS_DATE_EPOCH_MS', value, true)
		} else {
			os.unsetenv('VOX_LIBJS_DATE_EPOCH_MS')
		}
	}
	os.setenv('VOX_LIBJS_DATE_EPOCH_MS', 'not a timestamp', true)
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	assert runtime.agent_vm.date_clock_epoch_milliseconds() == none
}
