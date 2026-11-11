module browserjs

import dom
import html
import loader

fn test_visibility_state_entries_use_the_native_window_timeline_and_interface() {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{value: 'https://visibility-entry.test/'}
	mut document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_performance_binding()!
	mut scope := settings.window_or_worker_global_scope()!
	mut performance := scope.performance()
	assert runtime.evaluate_host(r'
const entries=performance.getEntriesByType("visibility-state"),entry=entries[0];
let brands=0;for(const call of [()=>new VisibilityStateEntry(),()=>VisibilityStateEntry.prototype.toJSON.call({}),()=>VisibilityStateEntry.prototype.toJSON.call(new PerformanceMark("other"))]){try{call()}catch(error){if(error instanceof TypeError)brands++}}
globalThis.observedVisibility=[];globalThis.visibilityObserver=new PerformanceObserver(list=>observedVisibility.push(...list.getEntries()));visibilityObserver.observe({type:"visibility-state"});
entries.length===1&&entry.name==="visible"&&entry.startTime===0&&entry.duration===0&&entry.entryType==="visibility-state"&&
entry instanceof VisibilityStateEntry&&entry instanceof PerformanceEntry&&entry.constructor===VisibilityStateEntry&&Object.getPrototypeOf(VisibilityStateEntry)===PerformanceEntry&&Object.prototype.toString.call(entry)==="[object VisibilityStateEntry]"&&
PerformanceObserver.supportedEntryTypes.includes("visibility-state")&&performance.getEntries().includes(entry)&&
JSON.stringify(entry.toJSON())==="{\"name\":\"visible\",\"entryType\":\"visibility-state\",\"startTime\":0,\"duration\":0}"&&brands===3;
')! == 'true'
	before := performance.now()
	document.update_the_visibility_state(.hidden)
	document.update_the_visibility_state(.hidden)
	document.update_the_visibility_state(.visible)
	after := performance.now()
	entries := performance.get_entries_by_type('visibility-state')
	assert entries.len == 3
	assert entries[1].start_time >= before && entries[2].start_time <= after
	assert entries[1].start_time <= entries[2].start_time
	mut queue := scope.responsible_event_loop().task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .performance_timeline
		}) or { break }
		task.execute()
	}
	assert runtime.evaluate_host(r'
const visibility=performance.getEntriesByType("visibility-state");
observedVisibility.length===2&&observedVisibility[0]===visibility[1]&&observedVisibility[1]===visibility[2]&&observedVisibility.map(entry=>entry.name).join(",")==="hidden,visible";
')! == 'true'
	for index in 0 .. 60 {
		document.update_the_visibility_state(if index % 2 == 0 { .hidden } else { .visible })
	}
	assert runtime.evaluate_host('performance.getEntriesByType("visibility-state").length===50&&visibilityObserver.takeRecords().length===60')! == 'true'
	tuple := performance.timeline.entry_buffers['visibility-state'] or { panic('missing visibility buffer') }
	assert tuple.dropped_entries_count == 13
}
