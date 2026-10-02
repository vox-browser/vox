// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// WindowOrWorkerGlobalScope::crypto and Crypto/SubtleCrypto's owning global.
module html

import webcrypto
import webidl

fn GlobalScopeCrypto.create(event_loop &EventLoop, realm_id u64) &GlobalScopeCrypto {
	implementation := webcrypto.Crypto.create()
	context := webidl.PromiseContext{
		realm_id:      realm_id
		job_scheduler: fn [event_loop] (job fn ()) {
			queue_a_task(.microtask, event_loop, none, job)
		}
	}
	return &GlobalScopeCrypto{
		implementation: implementation
		subtle_:        webcrypto.SubtleCryptoBinding.create(implementation.subtle(), context,
			// EventLoopPlugin's deferred invocation is adapted to an owning-loop
			// task; the following crypto settlement task stays a separate task.
			fn [event_loop] (steps fn ()) { queue_a_task(.unspecified, event_loop, none, steps) },
			fn [event_loop] (steps fn ()) { queue_a_task(.crypto, event_loop, none, steps) })
	}
}

pub fn (crypto &GlobalScopeCrypto) crypto() &webcrypto.Crypto {
	return crypto.implementation
}

pub fn (crypto &GlobalScopeCrypto) subtle() &webcrypto.SubtleCryptoBinding {
	return crypto.subtle_
}

pub fn (crypto &GlobalScopeCrypto) get_random_values(mut destination []u8) ![]u8 {
	return crypto.implementation.get_random_values(mut destination)
}

pub fn (crypto &GlobalScopeCrypto) get_random_values_view(mut destination webcrypto.RandomValuesArrayView) !webcrypto.RandomValuesArrayView {
	return crypto.implementation.get_random_values_view(mut destination)
}

pub fn (crypto &GlobalScopeCrypto) random_uuid() !string {
	return crypto.implementation.random_uuid()
}
