// SPDX-License-Identifier: BSD-2-Clause
module libjs

// CyclicModule.cpp::InnerModuleLoading / ContinueModuleLoading. The embedding
// loader owns I/O; completion may be immediate or arrive on its event loop.
pub fn (module_record &SourceTextModule) requested_module_requests() []ModuleRequest {
	mut requests := []ModuleRequest{}
	program := module_record.parsed.program.kind.program_data or { return requests }
	for statement in program.scope.children {
		request := if statement.kind.tag==.import_stmt {
			(statement.kind.import_data or { continue }).module_request
		} else if statement.kind.tag==.export_stmt {
			(statement.kind.export_data or { continue }).module_request or { continue }
		} else { continue }
		if !requests.any(module_requests_equal(LoadedModuleRequest{specifier:it.module_specifier,attributes:it.attributes,module_record:Module(module_record)},request)) { requests << request }
	}
	return requests
}

fn (module_record &SourceTextModule) imported_source_module(mut vm VM,request ModuleRequest) !&SourceTextModule {
	for loaded in module_record.loaded {
		if !module_requests_equal(loaded,request) { continue }
		if loaded.module_record is SourceTextModule { return loaded.module_record }
		return vm.throw_error(.internal_error,'Non-JavaScript imported modules are not translated yet')
	}
	return vm.throw_error(.internal_error,'LibJS module dependency is not loaded: ${request.module_specifier.str()}')
}

fn continue_source_module_loading(mut vm VM,state &GraphLoadingState,result ModuleLoadResult) {
	mut loading := unsafe { &GraphLoadingState(state) }
	if !loading.is_loading { return }
	mut capability := loading.promise_capability or { return }
	if reason := result.thrown {
		loading.is_loading=false
		capability.promise.reject(mut vm,reason)
		return
	}
	module_record := result.module_record or { return }
	if !loading.visited.any(same_module(it,module_record)) {
		if loading.visited.len>=4096 || vm.stack_info_.size_free()<512*1024 {
			continue_source_module_loading(mut vm,state,ModuleLoadResult.from_error(vm.throw_error(.internal_error,'LibJS module graph loading budget exceeded')))
			return
		}
		loading.visited << module_record
		if module_record is SourceTextModule {
			referrer := ImportedModuleReferrer.from_module(module_record)
			for request in module_record.requested_module_requests() {
				if !loading.is_loading { return }
				loading.requested_module_count++
				if loading.requested_module_count>16384 {
					continue_source_module_loading(mut vm,state,ModuleLoadResult.from_error(vm.throw_error(.internal_error,'LibJS module graph request budget exceeded')))
					return
				}
				loading.pending_module_count++
				mut cached := ?Module(none)
				for entry in module_record.loaded { if module_requests_equal(entry,request) { cached=entry.module_record;break } }
				if loaded := cached {
					continue_source_module_loading(mut vm,state,ModuleLoadResult.from_module(loaded))
				} else {
					owner := &vm
					payload := ImportedModulePayload.for_graph_loading_state(state,fn [owner,state] (loaded ModuleLoadResult) {
						mut agent := unsafe { &VM(owner) }
						continue_source_module_loading(mut agent,state,loaded)
					})
					vm.host_load_imported_module(referrer,request,loading.host_defined,payload)
				}
			}
		}
	}
	if !loading.is_loading { return }
	loading.pending_module_count--
	if loading.pending_module_count==0 {
		loading.is_loading=false
		capability.promise.fulfill(js_undefined())
	}
}
