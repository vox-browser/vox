module browserjs

import css
import dom
import html
import indexeddb
import loader

fn test_native_message_database_and_media_events_keep_their_wrappers_together() {
	$if !darwin && !linux {
		return
	}
	if !loader.is_initialized() { loader.initialize() }
	for database_first in [true, false] {
		url := dom.URL{ value: 'https://event-composition-${database_first}.test/' }
		mut document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
		mut runtime := Runtime.create()
		runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
		runtime.install_window_message_binding()!
		if database_first {
			runtime.install_indexed_db_binding()!
			runtime.install_window_media_query_binding()!
		} else {
			runtime.install_window_media_query_binding()!
			runtime.install_indexed_db_binding()!
		}
		runtime.evaluate_host('globalThis.document={}')!
		runtime.install_document_window_event_binding(document, runtime.evaluate_host_value('document')!)!
		runtime.install_message_channel_binding()!
		mut fonts := FontFaceHost.create(document)
		fonts.install(mut runtime)!
		assert runtime.evaluate_host(r'
 globalThis.received={window:false,port:false,upgrade:false,media:false};
 addEventListener("message",event=>{received.window=event instanceof MessageEvent&&event.isTrusted&&event.data==="probe";});
 postMessage("probe","*");
 const channel=new MessageChannel();channel.port2.onmessage=event=>{received.port=event instanceof MessageEvent&&event.isTrusted&&event.data==="port";};channel.port1.postMessage("port");
 const opening=indexedDB.open("composition",1);
 opening.onupgradeneeded=event=>{received.upgrade=event instanceof IDBVersionChangeEvent&&event.isTrusted&&event.oldVersion===0&&event.newVersion===1;};
 opening.onsuccess=()=>opening.result.close();
 globalThis.query=matchMedia("(min-width: 1px)");
 query.onchange=event=>{received.media=event instanceof MediaQueryListEvent&&event.isTrusted&&event.media==="(min-width: 1px)"&&event.matches;};
 Object.values(received).every(value=>value===false);
 ')! == 'true'
		mut queue := html.main_thread_event_loop().task_queue()
		mut count := 0
		for {
			indexeddb.cleanup_indexed_database_transactions(voidptr(html.main_thread_event_loop()))
			task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
				return task.source() in [.posted_message, .database_access]
			}) or { break }
			task.execute()
			count++
			assert count < 100
		}
		target := runtime.native_event_target(runtime.evaluate_host_value('query')!)!
		event := css.MediaQueryListEvent.create('change', css.MediaQueryListEventInit{
			media:   '(min-width: 1px)'
			matches: true
		})
		target.dispatch_event(unsafe { &dom.Event(event) })
		assert runtime.evaluate_host('JSON.stringify(received)')! == '{"window":true,"port":true,"upgrade":true,"media":true}'
		runtime.close()
		document.finalize()
	}
}
