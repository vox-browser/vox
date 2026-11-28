// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import fetch
import html
import libjs
import platform
import processmetrics

struct LibJSModuleImport {
	referrer libjs.ImportedModuleReferrer
	request libjs.ModuleRequest
	payload libjs.ImportedModulePayload
}

fn (mut host ModuleHost) install_libjs(mut runtime Runtime) ! {
	if runtime.module_host_ != none { return error('A module loader is already installed') }
	host.runtime=&runtime
	if mut document_host := runtime.libjs_document_host_ {
		document_host.install_fetch(fetch.RequestClient(host.settings), host.transport)!
	}
	owner := &host
	mut vm := runtime.agent_vm
	vm.host_load_imported_module=fn [owner] (referrer libjs.ImportedModuleReferrer,request libjs.ModuleRequest,_ voidptr,payload libjs.ImportedModulePayload) {
		mut host := unsafe { &ModuleHost(owner) }
		if host.closed { return }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		operation := LibJSModuleImport{referrer,request,payload}
		host.load_libjs_import(operation) or {
			mut vm := unsafe { &libjs.VM(host.runtime.agent_vm) }
			libjs.finish_loading_imported_module(referrer,request,payload,
				libjs.ModuleLoadResult.from_error(vm.throw_error(.type_error,err.msg())))
			host.drain_libjs_modules()
		}
	}
	vm.host_get_import_meta_properties=fn [owner] (module_record libjs.Module) []libjs.ImportMetaProperty {
		mut host := unsafe { &ModuleHost(owner) }
		mut vm := unsafe { &libjs.VM(host.runtime.agent_vm) }
		key := module_record.filename()
		base := if source := host.sources[key] { source.base } else { key }
		resolve := libjs.NativeFunction.create(mut vm,module_record.realm(),module_record.realm().function_prototype,
			fn [owner,key,base] (mut vm libjs.VM) !libjs.Value {
				mut host := unsafe { &ModuleHost(owner) }
				if host.closed { return vm.throw_error(.type_error,'Module loader is closed') }
				specifier := vm.argument(0).to_primitive_string(mut vm)!.str()
				resolved := host.resolve(specifier,base,key) or { return vm.throw_error(.type_error,err.msg()) }
				return libjs.Value.from_string(vm.create_string_from_str(resolved))
			},1,libjs.PropertyName.from_str('resolve'),none)
		return [
			libjs.ImportMetaProperty{libjs.PropertyName.from_str('url'),libjs.Value.from_string(vm.create_string_from_str(base))},
			libjs.ImportMetaProperty{libjs.PropertyName.from_str('resolve'),libjs.Value.from_object(resolve.object)},
		]
	}
	runtime.module_host_=host
	runtime.add_close_handler(fn [owner] () {
		mut host := unsafe { &ModuleHost(owner) }
		host.close()
	})
}

fn (mut host ModuleHost) load_libjs_import(imported LibJSModuleImport) ! {
	// This runtime executes JavaScript modules. Other module types must fail
	// before fetching rather than treating their response body as JavaScript.
	if imported.request.attributes.len>0 { return error('LibJS import attributes are not supported by the JavaScript module host') }
	parent := if imported.referrer.kind == .realm { host.settings.api_base_url().serialize() } else { imported.referrer.filename() }
	base := if source := host.sources[parent] { source.base } else {
		if parent == '' || parent == '<script>' { host.settings.api_base_url().serialize() } else { parent }
	}
	key := host.resolve(imported.request.module_specifier.str(),base,parent)!
	mut runtime := unsafe { &Runtime(host.runtime) }
	if cached := runtime.libjs_modules_[key] {
		if imported.payload.kind==.promise_capability { runtime.queue_native_module_templates(cached) }
		libjs.finish_loading_imported_module(imported.referrer,imported.request,imported.payload,
			libjs.ModuleLoadResult.from_module(libjs.Module(cached)))
		return
	}
	mut operation := &BrowserModuleOperation{key:key,source:host.sources[key]!,libjs_import:imported}
	host.operations << operation
	if pending := host.in_flight[key] {
		mut waiters := pending.clone();waiters << operation;host.in_flight[key]=waiters
		return
	}
	host.in_flight[key]=[operation]
	host.fetch_module(mut operation)
}

fn (mut host ModuleHost) reject_libjs_import(operation &BrowserModuleOperation,message string) {
	host.runtime.prepare_html_script()
	defer { host.runtime.clean_up_html_script() }
	if imported := operation.libjs_import {
		mut vm := unsafe { &libjs.VM(host.runtime.agent_vm) }
		libjs.finish_loading_imported_module(imported.referrer,imported.request,imported.payload,
			libjs.ModuleLoadResult.from_error(vm.throw_error(.type_error,message)))
	}
	host.drain_libjs_modules()
}

fn (mut host ModuleHost) consume_libjs_script(operation &BrowserModuleOperation,script ?&html.Script) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	host.runtime.prepare_html_script()
	defer { host.runtime.clean_up_html_script() }
	mut waiters := host.in_flight[operation.key] or { []&BrowserModuleOperation{} }
	host.in_flight.delete(operation.key)
	// A preload only populates HTML's module map. It need not retain an AST
	// until an import actually requests the module.
	if waiters.len==0 { return }
	mut runtime := unsafe { &Runtime(host.runtime) }
	mut vm := runtime.agent_vm
	mut result := libjs.ModuleLoadResult{}
	if source := script {
		module_script := unsafe { &html.JavaScriptModuleScript(source) }
		if module_script.kind==.javascript {
			base := (module_script.base_url or { dom.URL{value:operation.key} }).serialize()
			host.sources[operation.key]=BrowserModuleSource{...operation.source,base:base}
			module_record := host.parse_libjs_module(operation.key,module_script.source,1) or {
				for mut waiter in waiters { host.reject(mut waiter,'${operation.key}: ${err.msg()}') }
				return
			}
			result=libjs.ModuleLoadResult.from_module(libjs.Module(module_record))
		}
	}
	if result.module_record == none {
		result = libjs.ModuleLoadResult.from_error(vm.throw_error(.type_error,
			'Failed to fetch JavaScript module ${operation.key}'))
	}
	for mut waiter in waiters {
		if waiter.finished { continue }
		waiter.finished=true
		if imported := waiter.libjs_import {
			if imported.payload.kind==.promise_capability {
				if loaded := result.module_record {
					if loaded is libjs.SourceTextModule { runtime.queue_native_module_templates(loaded) }
				}
			}
			libjs.finish_loading_imported_module(imported.referrer,imported.request,imported.payload,result)
		}
	}
	host.drain_libjs_modules()
}

fn (mut host ModuleHost) parse_libjs_module(key string,code string,starting_line int) !&libjs.SourceTextModule {
	mut runtime := unsafe { &Runtime(host.runtime) }
	if cached := runtime.libjs_modules_[key] { return cached }
	frontend_stage := processmetrics.begin_thread_instruction_substage('libjs_module_frontend')
	defer { frontend_stage.finish() }
	preparsed := host.libjs_preparsed[key] or { unsafe { &libjs.ParsedSource(nil) } }
	if preparsed != unsafe { nil } { host.libjs_preparsed.delete(key) }
	parsed := runtime.prepare_libjs_frontend_with(code, .module, libjs.ParseOptions{max_recursion_depth:256}, preparsed)
	if parsed.has_errors() { return libjs.ModuleParseError{diagnostics: parsed.diagnostics} }
	mut created := &libjs.SourceTextModule{module_realm:runtime.realm, module_filename:key,
		host_defined:voidptr(runtime), parsed:parsed}
	created.module_starting_line=u32(starting_line)
	runtime.libjs_modules_[key.clone()]=created
	// Initial and statically imported modules also contain uncalled event
	// handlers needed on later visits. Queue their syntax without running it.
	runtime.queue_native_module_templates(created)
	return created
}

// Parse a fetched JavaScript module on a worker, then resume its fetch from an
// ordinary networking task on this thread. Returns false when the module is
// handled synchronously: other engines, cached or non-JavaScript modules, a
// failed decode, or no available worker.
fn (mut host ModuleHost) parse_libjs_module_in_background(mut operation BrowserModuleOperation, response &fetch.Response, body []u8, callback html.OnFetchScriptComplete) bool {
	if host.runtime.engine != .libjs || host.closed { return false }
	runtime := unsafe { &Runtime(host.runtime) }
	if _ := runtime.libjs_modules_[operation.key] { return false }
	if !fetch.is_ok_status(response.status) { return false }
	mime := fetch.extract_mime_type(response.header_list) or { return false }
	if !mime.is_javascript() { return false }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	source := html.decode_module_script_source(body) or { return false }
	owner := voidptr(host)
	op := voidptr(operation)
	key := operation.key.clone()
	// Called once on this thread's run loop; it releases itself afterwards. The
	// runtime does not own it, because a worker may still hold it at close.
	done := fn [owner, op, key, response, callback] (parsed &libjs.ParsedSource) {
		mut host := unsafe { &ModuleHost(owner) }
		if host.closed { return }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		html.queue_a_task(.networking, host.settings.responsible_event_loop(), host.settings.responsible_document(), fn [owner, op, key, parsed, response, callback] () {
			mut host := unsafe { &ModuleHost(owner) }
			if host.closed { return }
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut operation := unsafe { &BrowserModuleOperation(op) }
			host.libjs_preparsed[key] = parsed
			host.complete_module_fetch(mut operation, response, callback)
		})
	}
	if !submit_libjs_module_parse(source, libjs.ParseOptions{ max_recursion_depth: 256 }, done) {
		platform.release_closure(voidptr(done))
		return false
	}
	host.libjs_background_parses++
	return true
}

fn (mut host ModuleHost) execute_libjs(source ScriptSource,stringify_result bool) !string {
	if host.closed { return error('Module loader is closed') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	host.runtime.prepare_html_script()
	defer { host.runtime.clean_up_html_script() }
	mut key := source.url
	mut base := if key=='' { host.settings.api_base_url().serialize() } else { key }
	mut options := html.default_script_fetch_options()
	mut inline := false
	if element := source.element {
		inline = !element.has_attribute_ns(none, 'src')
		if inline {
			base=element.document().base_url().serialize()
			key=base.all_before('#')+'#vox-libjs-inline-${element.as_node().unique_id()}'
		}
		options.cryptographic_nonce=element.cryptographic_nonce()
		options.integrity_metadata=(element.get_attribute_ns(none, 'integrity') or { '' })
		options.referrer_policy=(element.get_attribute_ns(none, 'referrerpolicy') or { '' })
		options.credentials_mode=if (element.get_attribute_ns(none, 'crossorigin') or { '' }).to_lower()=='use-credentials' { .include } else { .same_origin }
	}
	if key=='' { host.next_inline++;key=base.all_before('#')+'#vox-libjs-inline-${host.next_inline}';inline=true }
	host.sources[key]=BrowserModuleSource{base:base,options:options,top_level:.yes,code:if inline { source.code } else { none }}
	mut module_record := host.parse_libjs_module(key,source.code,source.starting_line)!
	mut execution := &BrowserModuleExecution{
		key:key
		element:source.external_element
		libjs_module:module_record
		blocks_readiness:if element := source.element {
			if element.is_html_element() && element.local_name()=='script' && !element.has_attribute('async') {
				html.html_script_element_model_for_dom_element(unsafe { &dom.HTMLScriptElement(element) }).is_parser_inserted()
			} else { false }
		} else { false }
	}
	if mut document := host.settings.responsible_document() {
		execution.delayer=dom.DocumentLoadEventDelayer.new(mut document)
		if execution.blocks_readiness { document.begin_module_readiness_delay() }
	}
	host.executions << execution;host.pending_scripts++
	mut vm := unsafe { &libjs.VM(host.runtime.agent_vm) }
	execution.libjs_loading=module_record.load_requested_modules(mut vm,voidptr(host))
	host.drain_libjs_modules()
	return if stringify_result { 'undefined' } else { '' }
}

fn (mut host ModuleHost) drain_libjs_modules() {
	if host.closed || host.libjs_draining { return }
	host.libjs_draining=true
	defer { host.libjs_draining=false }
	for mut execution in host.executions {
		if execution.finished || execution.evaluated { continue }
		loading := execution.libjs_loading or { continue }
		if loading.promise.state==.pending { continue }
		if loading.promise.state==.rejected {
			host.finish_script(mut execution,libjs_exception_message(libjs.throw_completion(loading.promise.result)))
			continue
		}
		if html.can_run_script_for_settings(host.settings)!=.run {
			host.finish_script(mut execution,'Module execution is disabled for its document');continue
		}
		host.evaluate_libjs_execution(mut execution)
	}
}

fn (mut host ModuleHost) evaluate_libjs_execution(mut execution BrowserModuleExecution) {
	mut module_record := execution.libjs_module or { return }
	javascript_stage := processmetrics.begin_javascript_instruction_stage()
	defer { javascript_stage.finish() }
	mut vm := unsafe { &libjs.VM(host.runtime.agent_vm) }
	host.runtime.prepare_html_script()
	previous := if document := host.settings.responsible_document() { document.current_script() } else { none }
	if mut document := host.settings.responsible_document() { document.set_current_script(none) }
	defer {
		if mut document := host.settings.responsible_document() { document.set_current_script(previous) }
		host.runtime.clean_up_html_script()
	}
	link_stage := processmetrics.begin_thread_instruction_substage('libjs_module_link')
	module_record.link(mut vm) or {
		link_stage.finish()
		host.finish_script(mut execution,libjs_exception_message(err))
		return
	}
	link_stage.finish()
	execution.evaluated=true
	result := module_record.evaluate_with_limits(mut vm, host.runtime.libjs_execution_limits()) or { host.finish_script(mut execution,libjs_exception_message(err));return }
	message := if result.promise.state==.rejected { libjs_exception_message(libjs.throw_completion(result.promise.result)) } else { '' }
	host.finish_script(mut execution,message)
}
