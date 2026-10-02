// Copyright (c) 2024-2025, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2024-2025, Luke Wilde <luke@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
module webgl

import webidl

pub type WebGLTaskScheduler = fn (fn ())

// WebGLRenderingContextBase.cpp make_xr_compatible's executed branches. The
// pinned source leaves permissions/device selection TODO and assumes a
// compatible adapter; its device-null and context-loss fallback are unreachable.
pub fn (context &WebGLRenderingContext) make_xr_compatible(promise_context webidl.PromiseContext,
	deferred_invoke WebGLTaskScheduler, queue_settlement_task WebGLTaskScheduler) &webidl.Promise {
	mut promise := webidl.create_promise_for(promise_context)
	deferred_invoke(fn [context, mut promise, queue_settlement_task] () {
		if context.is_context_lost() {
			queue_settlement_task(fn [context, mut promise] () {
				mut mutable_context := unsafe { &WebGLRenderingContext(context) }
				mutable_context.set_xr_compatible(false)
				webidl.reject_promise(mut promise, webidl.dom_exception_value(webidl.DOMException.create('InvalidStateError',
					'The WebGL context has been lost.')))
			})
		} else if context.xr_compatible() {
			queue_settlement_task(fn [mut promise] () {
				webidl.resolve_promise(mut promise, webidl.undefined_value())
			})
		} else {
			queue_settlement_task(fn [context, mut promise] () {
				mut mutable_context := unsafe { &WebGLRenderingContext(context) }
				mutable_context.set_xr_compatible(true)
				webidl.resolve_promise(mut promise, webidl.undefined_value())
			})
		}
	})
	return promise
}
