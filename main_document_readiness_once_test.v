module main

import browserjs
import dom
import html
import page

fn readiness_once_run_tasks_after(cutoff u64) int {
	mut queue := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable_matching(fn [cutoff] (task &html.Task) bool {
			return task.id() > cutoff
		}) or { break }
		count++
		assert count < 100
		task.execute()
	}
	return count
}

// The compact host fires DOMContentLoaded and load once its scripts have run.
// The parser's end steps, queued while parsing, must not deliver them again:
// 4chan's catalog builds its menus and thread grid from a DOMContentLoaded
// listener and showed every control twice.
fn test_readiness_events_fire_once_when_the_parser_end_tasks_run_later() {
	$if !darwin {
		return
	}
	cutoff := if task := html.main_thread_event_loop().task_queue().last_added_task() {
		task.id()
	} else {
		u64(0)
	}
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><div id="result"></div>',
		dom.URL{value: 'https://readiness-once.example/'}, none, none, unsafe { &dom.Page(owner) }, 123456700000)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
 globalThis.entries=[];
 document.addEventListener("DOMContentLoaded",function(){entries.push("document ready");});
 window.addEventListener("DOMContentLoaded",function(){entries.push("window ready");});
 window.addEventListener("load",function(){entries.push("load");});
'], runtime, mut messages)
	assert runtime.evaluate_host('entries.join()')! == 'document ready,window ready,load'
	assert readiness_once_run_tasks_after(cutoff) > 0
	assert document.readiness() == .complete
	assert runtime.evaluate_host('entries.join()')! == 'document ready,window ready,load'
	assert messages == []
}
