// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibThreading/ThreadPool.{cpp,h}: shared four-worker FIFO pool.
@[has_globals]
module threading

import sync

#include "condition_bridge.h"

fn C.vox_thread_pool_condition_create() voidptr
fn C.vox_thread_pool_lock(state voidptr)
fn C.vox_thread_pool_unlock(state voidptr)
fn C.vox_thread_pool_wait(state voidptr)
fn C.vox_thread_pool_signal(state voidptr)
fn C.vox_thread_pool_set_name(name &char)

__global (
	thread_pool_                      ?&ThreadPool = ?&ThreadPool(none)
	thread_pool_initialization_mutex_ = sync.new_mutex()
)

@[heap]
pub struct ThreadPool {
mut:
	condition_  voidptr
	work_queue_ []fn ()
	threads_    []thread
}

pub fn ThreadPool.the() &ThreadPool {
	thread_pool_initialization_mutex_.lock()
	defer { thread_pool_initialization_mutex_.unlock() }
	if pool := thread_pool_ { return pool }
	mut pool := &ThreadPool{
		condition_: C.vox_thread_pool_condition_create()
	}
	if pool.condition_ == unsafe { nil } { panic('Failed to create ThreadPool condition') }
	thread_pool_ = pool
	for i in 0 .. 4 {
		pool.threads_ << spawn pool.worker_thread_func('Pool/${i}')
	}
	return pool
}

@[spawn_stack: 8388608]
fn (mut pool ThreadPool) worker_thread_func(name string) {
	// Under -prealloc a spawned thread's arena is freed when it returns; work
	// results outlive this worker, so keep the arena (see platform).
	$if prealloc {
		_ = unsafe { prealloc_scope_retain_current() }
	}
	C.vox_thread_pool_set_name(name.str)
	for {
		C.vox_thread_pool_lock(pool.condition_)
		// Upstream's idle ak_kmalloc_collect() trims the calling worker's
		// allocator. Boehm owns one process heap: gc_collect() here instead
		// stops every thread and traces the live page once per idle worker.
		// Keep automatic GC and the browser's process-idle cleanup in charge.
		for pool.work_queue_.len == 0 {
			C.vox_thread_pool_wait(pool.condition_)
		}
		work := pool.work_queue_[0]
		pool.work_queue_.delete(0)
		C.vox_thread_pool_unlock(pool.condition_)
		work()
	}
}

pub fn (mut pool ThreadPool) submit(work fn ()) {
	C.vox_thread_pool_lock(pool.condition_)
	pool.work_queue_ << work
	C.vox_thread_pool_signal(pool.condition_)
	C.vox_thread_pool_unlock(pool.condition_)
}
