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
fn C.vox_thread_pool_wait_for_idle_collection(state voidptr) int
fn C.vox_thread_pool_signal(state voidptr)
fn C.vox_thread_pool_set_name(name &char)

__global (
	thread_pool_                      ?&ThreadPool
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
	C.vox_thread_pool_set_name(name.str)
	mut collected_since_last_work := false
	for {
		mut should_collect := false
		C.vox_thread_pool_lock(pool.condition_)
		for pool.work_queue_.len == 0 {
			if collected_since_last_work {
				C.vox_thread_pool_wait(pool.condition_)
			} else if C.vox_thread_pool_wait_for_idle_collection(pool.condition_) == 0
				&& pool.work_queue_.len == 0 {
				should_collect = true
				break
			}
		}
		if should_collect {
			C.vox_thread_pool_unlock(pool.condition_)
			// AK::ak_kmalloc_collect projects to V's actual allocator collection.
			gc_collect()
			collected_since_last_work = true
			continue
		}
		work := pool.work_queue_[0]
		pool.work_queue_.delete(0)
		C.vox_thread_pool_unlock(pool.condition_)
		collected_since_last_work = false
		work()
	}
}

pub fn (mut pool ThreadPool) submit(work fn ()) {
	C.vox_thread_pool_lock(pool.condition_)
	pool.work_queue_ << work
	C.vox_thread_pool_signal(pool.condition_)
	C.vox_thread_pool_unlock(pool.condition_)
}
