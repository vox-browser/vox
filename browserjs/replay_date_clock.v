// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import os
import strconv

fn (mut runtime Runtime) configure_replay_date_clock() {
	if runtime.engine != .libjs { return }
	text := os.getenv('VOX_LIBJS_DATE_EPOCH_MS')
	if text == '' { return }
	epoch := strconv.atof64(text) or {
		eprintln('LibJS replay Date clock unavailable: ${err.msg()}')
		return
	}
	runtime.agent_vm.set_date_clock_epoch_milliseconds(epoch) or {
		eprintln('LibJS replay Date clock unavailable: ${err.msg()}')
	}
}
