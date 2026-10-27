// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// HTML/EventLoop/Task.cpp UniqueTaskSource and its AK::IDAllocator pool.
module html

import crypto.rand as crypto_rand
import platform

__global html_allocated_unique_task_sources_ map[int]bool

pub struct UniqueTaskSource {
pub:
	source TaskSource
}

pub fn UniqueTaskSource.create() UniqueTaskSource {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	assert html_allocated_unique_task_sources_.len < 0x7fff_ffff - 2
	for {
		id := int(crypto_rand.int_u64(0x7fff_ffff) or { panic(err) })
		if id < int(TaskSource.unique_task_source_start) { continue }
		if id !in html_allocated_unique_task_sources_ {
			html_allocated_unique_task_sources_[id] = true
			return UniqueTaskSource{ source: unsafe { TaskSource(id) } }
		}
	}
	return UniqueTaskSource{}
}

pub fn (source &UniqueTaskSource) finalize() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	html_allocated_unique_task_sources_.delete(int(source.source))
}
