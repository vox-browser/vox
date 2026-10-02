// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module html

import dom
import webgl
import webidl

fn xr_owner_fixture() (&EnvironmentSettingsObject, &EventLoop) {
	url := dom.URL{'https://xr-binding.example/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	_ := WindowModel.create_top_level(document, none, '') or { panic(err) }
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	return settings, settings.responsible_event_loop()
}

fn xr_owner_task(owner &EventLoop) {
	mut queue := owner.task_queue()
	task := queue.dequeue() or { panic('missing XR task') }
	assert task.source() == .unspecified
	task.execute()
}

fn test_source_xr_compatibility_updates_only_on_owner_settlement_task_and_jobs() {
	settings, mut owner := xr_owner_fixture()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	mut context := webgl.WebGLRenderingContext.new(.webgl1, webgl.WebGLContextAttributes{}, [])
	mut promise := make_webgl_xr_compatible(context, settings)
	child := promise.upon_fulfillment(fn (value webidl.Value) !webidl.Value { return value })
	assert promise.state == .pending
	assert !context.xr_compatible()
	assert webidl.promise_realm(promise) == u64(voidptr(settings.realm()))
	xr_owner_task(owner)
	assert promise.state == .pending
	assert !context.xr_compatible()
	assert owner.microtask_queue_empty()
	xr_owner_task(owner)
	assert context.xr_compatible()
	assert settings.realm().script_execution_depth == 0
	assert settings.realm().callback_execution_depth == 0
	assert promise.state == .fulfilled
	assert promise.result.kind == .undefined
	assert child.state == .pending
	job := owner.dequeue_microtask() or { panic('missing XR reaction job') }
	job.execute()
	assert child.state == .fulfilled
	assert webidl.promise_realm(child) == webidl.promise_realm(promise)
	// The already-compatible branch also creates and settles a fresh Promise.
	next := make_webgl_xr_compatible(context, settings)
	assert voidptr(next) != voidptr(promise)
	assert next.state == .pending
	xr_owner_task(owner)
	xr_owner_task(owner)
	assert next.state == .fulfilled
}

fn test_source_xr_loss_is_checked_in_deferred_work_and_rejects_on_settlement() {
	settings, mut owner := xr_owner_fixture()
	pause := owner.pause()
	defer { owner.unpause(pause) }
	mut context := webgl.WebGLRenderingContext.new(.webgl2, webgl.WebGLContextAttributes{}, [])
	context.set_xr_compatible(true)
	promise := make_webgl_xr_compatible(context, settings)
	context.lose_context('test')
	xr_owner_task(owner)
	assert promise.state == .pending
	assert context.xr_compatible()
	xr_owner_task(owner)
	assert !context.xr_compatible()
	assert promise.state == .rejected
	exception := promise.result.dom_exception_ or { panic('DOMException') }
	assert exception.name() == 'InvalidStateError'
	assert exception.message() == 'The WebGL context has been lost.'
	// Source selection is made during deferred work, not repeated at settlement.
	mut late_loss := webgl.WebGLRenderingContext.new(.webgl1, webgl.WebGLContextAttributes{}, [])
	selected := make_webgl_xr_compatible(late_loss, settings)
	xr_owner_task(owner)
	late_loss.lose_context('after source branch selection')
	xr_owner_task(owner)
	assert selected.state == .fulfilled
	assert late_loss.xr_compatible()
}
