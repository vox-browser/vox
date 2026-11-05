module main

import browserjs
import dom
import html
import platform
import time

// V compiles each test file separately; both paint suites use these fixtures.
$if test {
	fn javascript_task_paint_fixture(markup string) (&BrowserApp, &browserjs.Runtime, &dom.Document) {
		mut document := html.parse_document(markup)
		mut runtime := browserjs.Runtime.create()
		mut messages := []string{}
		run_document_javascript(document, 'https://task-paint.test/', [], runtime, mut messages)
		assert messages == []string{}
		runtime.evaluate_host('globalThis.taskPaintFilterRuns=0;globalThis.__voxAdblockApplyProcedural=()=>{taskPaintFilterRuns++;return ""};') or { panic(err) }
		mut app := &BrowserApp{ document: document, js_runtime: runtime }
		app.relayout(320, 232)
		runtime.evaluate_host('taskPaintFilterRuns=0') or { panic(err) }
		runtime.take_document_state_dirty()
		return app, runtime, document
	}
	fn run_javascript_task_paint_timer(runtime &browserjs.Runtime, source string) {
		runtime.evaluate_host('globalThis.taskPaintTimerDone=false;setTimeout(()=>{try{${source}}finally{taskPaintTimerDone=true}},1)') or { panic(err) }
		deadline := time.sys_mono_now() + 2_000_000_000
		for runtime.evaluate_host('taskPaintTimerDone') or { panic(err) } != 'true'
			&& time.sys_mono_now() < deadline {
			platform.pump_native_events(0.005)
		}
		assert runtime.evaluate_host('taskPaintTimerDone') or { panic(err) } == 'true'
	}
}
