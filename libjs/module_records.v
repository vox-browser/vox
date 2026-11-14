module libjs

// Translated from the module records the VM's loader bookkeeping depends on:
// Module and the loading payload variants (LibJS/Module.h, ModuleLoading.h,
// Runtime/ModuleRequest.h) plus FinishLoadingImportedModule from Module.cpp.
// The synchronous CyclicModule graph path is in module_graph_*.v. Payloads keep
// the embedding's asynchronous fetch continuation separate from evaluation.

// https://tc39.es/ecma262/#loadedmodulerequest-record
pub struct LoadedModuleRequest {
pub:
	specifier  Utf16String       // [[Specifier]]
	attributes []ImportAttribute // [[Attributes]]
	module_record     Module            // [[Module]]
}

// 16.2.1.3 ModuleRequestsEqual ( left, right ), https://tc39.es/ecma262/#sec-ModuleRequestsEqual
pub fn module_requests_equal(record LoadedModuleRequest, request ModuleRequest) bool {
	// 1. If left.[[Specifier]] is not right.[[Specifier]], return false.
	if record.specifier != request.module_specifier {
		return false
	}
	// 2-4. Both attribute lists must contain the same key/value pairs.
	if record.attributes.len != request.attributes.len {
		return false
	}
	for attribute in record.attributes {
		mut found := false
		for other in request.attributes {
			if attribute.key == other.key && attribute.value == other.value {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}

// 16.2.1.4 Abstract Module Records, https://tc39.es/ecma262/#sec-abstract-module-records
pub interface Module {
	filename() string
	realm() &Realm
	loaded_modules() []LoadedModuleRequest
	import_meta() ?&Object
mut:
	append_loaded_module(record LoadedModuleRequest)
	set_import_meta(import_meta &Object)
	// 16.2.1.5.1 LoadRequestedModules ( [ hostDefined ] )
	load_requested_modules(mut vm VM, host_defined voidptr) &PromiseCapability
	link(mut vm VM) !
	evaluate(mut vm VM) !&PromiseCapability
}

pub fn module_identity(module_record Module) voidptr {
	return unsafe { *(&voidptr(&module_record)) }
}

pub fn same_module(a Module, b Module) bool {
	return module_identity(a) == module_identity(b)
}

// https://tc39.es/ecma262/#graphloadingstate-record
@[heap]
pub struct GraphLoadingState {
pub mut:
	promise_capability   ?&PromiseCapability // [[PromiseCapability]]
	is_loading           bool                // [[IsLoading]]
	pending_module_count int                 // [[PendingModulesCount]]
	requested_module_count int               // embedding graph-work budget
	visited              []Module            // [[Visited]]
	host_defined         voidptr             // [[HostDefined]]
}

pub enum ImportedModuleReferrerKind {
	script
	cyclic_module
	realm
}

// ImportedModuleReferrer = Variant<GC::Ref<Script>, GC::Ref<CyclicModule>, GC::Ref<Realm>>
pub struct ImportedModuleReferrer {
pub:
	kind   ImportedModuleReferrerKind
	script ?&Script
	module_record ?Module
	realm  ?&Realm
}

pub fn ImportedModuleReferrer.from_script(script &Script) ImportedModuleReferrer {
	return ImportedModuleReferrer{
		kind:   .script
		script: script
	}
}

pub fn ImportedModuleReferrer.from_module(module_record Module) ImportedModuleReferrer {
	return ImportedModuleReferrer{
		kind:   .cyclic_module
		module_record: module_record
	}
}

pub fn ImportedModuleReferrer.from_realm(realm &Realm) ImportedModuleReferrer {
	return ImportedModuleReferrer{
		kind:  .realm
		realm: realm
	}
}

pub fn (referrer ImportedModuleReferrer) filename() string {
	return match referrer.kind {
		.script { (referrer.script or { panic('script referrer missing') }).filename }
		.cyclic_module { (referrer.module_record or { panic('module referrer missing') }).filename() }
		.realm { panic('realm referrers have no filename') }
	}
}

pub fn (referrer ImportedModuleReferrer) loaded_modules() []LoadedModuleRequest {
	return match referrer.kind {
		.script { (referrer.script or { panic('script referrer missing') }).loaded_modules }
		.cyclic_module { (referrer.module_record or { panic('module referrer missing') }).loaded_modules() }
		.realm { panic('realm referrers have no [[LoadedModules]]') }
	}
}

pub fn (referrer ImportedModuleReferrer) append_loaded_module(record LoadedModuleRequest) {
	match referrer.kind {
		.script {
			mut script := referrer.script or { panic('script referrer missing') }
			script.loaded_modules << record
		}
		.cyclic_module {
			mut module_record := referrer.module_record or { panic('module referrer missing') }
			module_record.append_loaded_module(record)
		}
		.realm {
			panic('realm referrers have no [[LoadedModules]]')
		}
	}
}

pub struct ModuleLoadResult {
pub:
	module_record ?Module
	thrown ?Value
}

pub fn ModuleLoadResult.from_module(module_record Module) ModuleLoadResult {
	return ModuleLoadResult{
		module_record: module_record
	}
}

pub fn ModuleLoadResult.from_error(err IError) ModuleLoadResult {
	return ModuleLoadResult{
		thrown: thrown_value(err)
	}
}

pub fn (result ModuleLoadResult) is_error() bool {
	return result.thrown != none
}

pub enum ImportedModulePayloadKind {
	graph_loading_state
	promise_capability
}

// ImportedModulePayload = Variant<GC::Ref<GraphLoadingState>, GC::Ref<PromiseCapability>>
pub struct ImportedModulePayload {
pub:
	kind                ImportedModulePayloadKind
	graph_loading_state ?&GraphLoadingState
	promise_capability  ?&PromiseCapability
	// Receives the FinishLoadingImportedModule result. Upstream continues into
	// ContinueModuleLoading or ContinueDynamicImport, which are part of the
	// pending CyclicModule translation.
	on_finished fn (result ModuleLoadResult) = unsafe { nil }
}

pub fn ImportedModulePayload.for_graph_loading_state(state &GraphLoadingState, on_finished fn (result ModuleLoadResult)) ImportedModulePayload {
	return ImportedModulePayload{
		kind:                .graph_loading_state
		graph_loading_state: state
		on_finished:         on_finished
	}
}

pub fn ImportedModulePayload.for_promise_capability(capability &PromiseCapability, on_finished fn (result ModuleLoadResult)) ImportedModulePayload {
	return ImportedModulePayload{
		kind:               .promise_capability
		promise_capability: capability
		on_finished:        on_finished
	}
}

// 16.2.1.9 FinishLoadingImportedModule ( referrer, moduleRequest, payload, result ), https://tc39.es/ecma262/#sec-FinishLoadingImportedModule
pub fn finish_loading_imported_module(referrer ImportedModuleReferrer, module_request ModuleRequest, payload ImportedModulePayload, result ModuleLoadResult) {
	// 1. If result is a normal completion, then
	if module_record := result.module_record {
		// NOTE: Only Script and CyclicModule referrers have the [[LoadedModules]] internal slot.
		if referrer.kind == .script || referrer.kind == .cyclic_module {
			mut found_record := false
			// a. If referrer.[[LoadedModules]] contains a LoadedModuleRequest Record record such that ModuleRequestsEqual(record, moduleRequest) is true, then
			for record in referrer.loaded_modules() {
				if module_requests_equal(record, module_request) {
					// i. Assert: record.[[Module]] and result.[[Value]] are the same Module Record.
					if !same_module(record.module_record, module_record) {
						panic('FinishLoadingImportedModule: a different module was already recorded for ${module_request.module_specifier.str()}')
					}
					found_record = true
				}
			}
			// b. Else,
			if !found_record {
				// i. Append the LoadedModuleRequest Record { [[Specifier]]: moduleRequest.[[Specifier]], [[Attributes]]: moduleRequest.[[Attributes]], [[Module]]: result.[[Value]] } to referrer.[[LoadedModules]].
				referrer.append_loaded_module(LoadedModuleRequest{
					specifier:  module_request.module_specifier
					attributes: module_request.attributes
					module_record:     module_record
				})
			}
		}
	}
	// 2. If payload is a GraphLoadingState Record, perform ContinueModuleLoading(payload, result).
	// 3. Else, perform ContinueDynamicImport(payload, result).
	if payload.on_finished != unsafe { nil } {
		payload.on_finished(result)
	}
}

pub struct ModuleParseError {
	Error
pub:
	diagnostics []SyntaxDiagnostic
}

pub fn (err ModuleParseError) msg() string {
	if err.diagnostics.len == 0 {
		return 'Module parse error'
	}
	first := err.diagnostics[0]
	return 'SyntaxError: ${first.line}:${first.column}: ${first.message}'
}

// 16.2.1.7 Source Text Module Records, https://tc39.es/ecma262/#sec-source-text-module-records
// Parsing runs through the translated frontend; synchronous dependency graphs
// retain live bindings and a private ModuleEnvironment for each source module.
@[heap]
pub struct SourceTextModule {
pub mut:
	module_realm    &Realm
	module_filename string
	parsed          &ParsedSource // [[ECMAScriptCode]]
	loaded          []LoadedModuleRequest
	meta            ?&Object // [[ImportMeta]]
	host_defined    voidptr
	module_starting_line u32 = 1
mut:
	module_environment ?&ModuleEnvironment
	module_executable ?&Executable
	module_body_start u32
	module_status ModuleExecutionStatus
	module_evaluation ?&PromiseCapability
	module_dfs_index int
	module_dfs_ancestor int
	module_namespace_ ?&Object
}

// 16.2.1.7.1 ParseModule ( sourceText, realm, hostDefined ), https://tc39.es/ecma262/#sec-parsemodule
pub fn SourceTextModule.parse(source_text string, realm &Realm, filename string, host_defined voidptr) !&SourceTextModule {
	return SourceTextModule.parse_with_options(source_text, realm, filename, host_defined, ParseOptions{})
}

pub fn SourceTextModule.parse_with_options(source_text string, realm &Realm, filename string, host_defined voidptr, options ParseOptions) !&SourceTextModule {
	parsed := parse_source_with_options(source_text, .module, options)
	if parsed.has_errors() {
		return ModuleParseError{
			diagnostics: parsed.diagnostics
		}
	}
	return &SourceTextModule{
		module_realm:    realm
		module_filename: filename
		parsed:          parsed
		host_defined:    host_defined
	}
}

pub fn (module_record &SourceTextModule) filename() string {
	return module_record.module_filename
}

pub fn (module_record &SourceTextModule) realm() &Realm {
	return module_record.module_realm
}

pub fn (module_record &SourceTextModule) loaded_modules() []LoadedModuleRequest {
	return module_record.loaded
}

pub fn (module_record &SourceTextModule) import_meta() ?&Object {
	return module_record.meta
}

pub fn (module_record &SourceTextModule) has_top_level_await() bool {
	return module_record.parsed.has_top_level_await
}

pub fn (mut module_record SourceTextModule) append_loaded_module(record LoadedModuleRequest) {
	module_record.loaded << record
}

pub fn (mut module_record SourceTextModule) set_import_meta(import_meta &Object) {
	module_record.meta = import_meta
}

pub fn (mut module_record SourceTextModule) load_requested_modules(mut vm VM, host_defined voidptr) &PromiseCapability {
	mut promise := Promise.create(module_record.module_realm)
	capability := PromiseCapability.create(promise, none, none)
	state := &GraphLoadingState{promise_capability:capability,is_loading:true,pending_module_count:1,host_defined:host_defined}
	continue_source_module_loading(mut vm,state,ModuleLoadResult.from_module(Module(&module_record)))
	return capability
}
