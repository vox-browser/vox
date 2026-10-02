// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Streams constructors select HTML::relevant_realm(relevant_global_object).
// Bindings/MainThreadVM.cpp HostEnqueuePromiseJob supplies the owning microtask
// queue and the realm's script/callback setup for the native WebIDL boundary.
module html

import dom
import streams
import webidl

pub fn (settings &EnvironmentSettingsObject) stream_promise_context() webidl.PromiseContext {
	return webidl.PromiseContext{
		realm_id: u64(voidptr(settings.realm()))
		job_scheduler: fn [settings] (job fn ()) {
			active_script := if context := top_most_script_having_execution_context() {
				context.active_classic_script_
			} else { ?&ClassicScript(none) }
			document := if script := active_script {
				if script_settings := settings_object_of_realm(script.realm()) {
					script_settings.responsible_document()
				} else { ?&dom.Document(none) }
			} else { ?&dom.Document(none) }
			queue_a_task(.microtask, settings.responsible_event_loop(), document, fn [settings, active_script, job] () {
				mut realm := unsafe { &ScriptingRealm(settings.realm()) }
				prepare_to_run_script(mut realm)
				prepare_to_run_callback(mut realm)
				previous_script := realm.active_classic_script_
				realm.active_classic_script_ = active_script
				job()
				realm.active_classic_script_ = previous_script
				clean_up_after_running_callback(mut realm)
				clean_up_after_running_script(mut realm)
			})
		}
	}
}

pub fn (settings &EnvironmentSettingsObject) stream_realm() streams.StreamRealm {
	return streams.StreamRealm.create_with_promise_context(settings.stream_promise_context())
}

pub fn (settings &EnvironmentSettingsObject) create_readable_stream(source streams.UnderlyingSource, strategy streams.QueuingStrategy) !&streams.ReadableStream {
	return streams.ReadableStream.create_for_constructor(settings.stream_realm(), source, strategy)
}

pub fn (settings &EnvironmentSettingsObject) create_writable_stream(sink streams.UnderlyingSink, strategy streams.QueuingStrategy) !&streams.WritableStream {
	return streams.WritableStream.create_for_constructor(settings.stream_realm(), sink, strategy)
}

pub fn (settings &EnvironmentSettingsObject) create_transform_stream(transformer streams.Transformer, writable_strategy streams.QueuingStrategy, readable_strategy streams.QueuingStrategy) !&streams.TransformStream {
	return streams.TransformStream.create_for_constructor(settings.stream_realm(), transformer, writable_strategy, readable_strategy)
}
