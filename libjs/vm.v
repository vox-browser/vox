module libjs

import os
import time
import math.big

// Translated from LibJS/Runtime/VM.{h,cpp} together with the VM members that
// Interpreter/Interpreter.cpp defines (handle_exception,
// unwind_inline_frame_for_exception, get_identifier,
// global_declarative_environment). Bytecode execution (run, run_executable,
// push_inline_frame) stays with the pending interpreter translation.

pub enum HandledByHost {
	handled
	unhandled
}

pub enum EvalMode {
	direct
	indirect
}

pub enum CompilationType {
	direct_eval
	indirect_eval
	function
	timer
}

pub enum NativeFunctionType as u32 {
	raw_native_function
}

pub type NativeFunctionPointer = fn (mut vm VM) !Value

pub struct NativeFunctionTableEntry {
pub:
	function NativeFunctionPointer = unsafe { nil }
	type_    NativeFunctionType
}

pub enum HandleExceptionResponse {
	exit_from_executable
	continue_in_this_executable
}

// Messages used in contexts that must not fail to allocate, such as raising an
// out-of-memory error, are pre-allocated at VM creation time.
pub enum VmErrorMessage {
	out_of_memory
}

pub enum HeapRootType {
	vm
}

// The cells the VM keeps alive; upstream hands these to GC::Heap as roots.
pub struct HeapRoots {
pub mut:
	cells map[voidptr]HeapRootType
}

pub fn (mut roots HeapRoots) add(cell voidptr) {
	if cell == unsafe { nil } {
		return
	}
	roots.cells[cell] = .vm
}

pub fn (mut roots HeapRoots) add_value(value Value) {
	if value.is_cell() {
		roots.add(value.cell)
	}
}

pub fn (roots &HeapRoots) contains(cell voidptr) bool {
	return cell in roots.cells
}

pub struct StringToAtomCacheEntry {
pub mut:
	string ?&PrimitiveString
	atom   ?Utf16String
}

pub struct NumericStringCacheEntry {
pub mut:
	number u64
	string ?&PrimitiveString
}

pub struct StackTraceElement {
pub:
	execution_context &ExecutionContext
	source_range      ?SourceCodeRange
}

pub struct CachedStrings {
pub mut:
	number        &PrimitiveString = unsafe { nil }
	undefined     &PrimitiveString = unsafe { nil }
	object        &PrimitiveString = unsafe { nil }
	string        &PrimitiveString = unsafe { nil }
	symbol        &PrimitiveString = unsafe { nil }
	boolean       &PrimitiveString = unsafe { nil }
	bigint        &PrimitiveString = unsafe { nil }
	function      &PrimitiveString = unsafe { nil }
	object_object &PrimitiveString = unsafe { nil }
}

// JS_ENUMERATE_WELL_KNOWN_SYMBOLS
pub enum WellKnownSymbol {
	async_dispose
	async_iterator
	dispose
	has_instance
	is_concat_spreadable
	iterator
	match_
	match_all
	replace
	replace_all
	search
	species
	split
	to_primitive
	to_string_tag
	unscopables
}

pub const well_known_symbol_names = ['asyncDispose', 'asyncIterator', 'dispose', 'hasInstance',
	'isConcatSpreadable', 'iterator', 'match', 'matchAll', 'replace', 'replaceAll', 'search',
	'species', 'split', 'toPrimitive', 'toStringTag', 'unscopables']

pub struct GlobalSymbolRegistryEntry {
pub:
	key    Utf16String
	symbol &Symbol
}

pub type PromiseJob = fn () !Value

// 9.13 FinalizationRegistry cleanup surface used by the VM job queue.
pub interface FinalizationRegistry {
	has_empty_cells() bool
mut:
	cleanup(mut vm VM) !
}

pub fn finalization_registry_identity(registry FinalizationRegistry) voidptr {
	return unsafe { *(&voidptr(&registry)) }
}

pub fn function_object_identity(function FunctionObject) voidptr {
	return unsafe { *(&voidptr(&function)) }
}

// 9.7 Agents, https://tc39.es/ecma262/#sec-agents
pub interface Agent {
	can_block() bool
mut:
	spin_event_loop_until(goal_condition fn () bool)
}

// 9.7.2 AgentCanSuspend ( ), https://tc39.es/ecma262/#sec-agentcansuspend
pub fn agent_can_suspend(vm &VM) bool {
	// 1. Let AR be the Agent Record of the surrounding agent.
	agent := vm.agent() or {
		// NOTE: We default to true if no agent has been provided (standalone LibJS with no embedder).
		return true
	}
	// 2. Return AR.[[CanBlock]].
	return agent.can_block()
}

// The resizable-buffer surface the default HostResizeArrayBuffer hook needs.
pub interface ArrayBuffer {
mut:
	try_resize(new_byte_length uint, zero_fill_new_bytes bool) bool
}

// LibJS/Debugger.h: the interpreter selects a debugging dispatch table when the
// debugger exists. Breakpoints and pause handling are not translated.
@[heap]
pub struct Debugger {
pub mut:
	is_paused bool
}

pub struct ImportMetaProperty {
pub:
	key   PropertyName
	value Value
}

struct SavedExecutionContextStack {
	stack                           []&ExecutionContext
	previous_running_contexts       []?&ExecutionContext
	running_execution_context       ?&ExecutionContext
	type_error_realm_override       ?&Realm
	type_error_realm_override_depth int
}

pub struct StoredModule {
pub mut:
	referrer                 ImportedModuleReferrer
	filename                 string
	type_                    string
	module_record                   Module
	has_once_started_linking bool
}

// The override only applies at the execution-context-stack depth the scope was
// created at, so callees pushed while the scope is alive are unaffected. V has
// no destructors: call restore() (typically through defer) when leaving the scope.
pub struct TypeErrorRealmScope {
mut:
	vm             &VM
	previous_realm ?&Realm
	previous_depth int
	active         bool
}

pub fn TypeErrorRealmScope.new(mut vm VM, realm &Realm) TypeErrorRealmScope {
	scope := TypeErrorRealmScope{
		vm:             vm
		previous_realm: vm.type_error_realm_override
		previous_depth: vm.type_error_realm_override_depth
		active:         true
	}
	vm.type_error_realm_override = realm
	vm.type_error_realm_override_depth = vm.execution_context_stack_.len
	return scope
}

pub fn (mut scope TypeErrorRealmScope) restore() {
	if !scope.active {
		return
	}
	scope.vm.type_error_realm_override = scope.previous_realm
	scope.vm.type_error_realm_override_depth = scope.previous_depth
	scope.active = false
}

@[heap]
pub struct VM {
mut:
	string_to_atom_cache       []StringToAtomCacheEntry
	fly_string_cache           []?&PrimitiveString
	numeric_string_cache       []?&PrimitiveString
	large_numeric_string_cache []NumericStringCacheEntry

	execution_context_stack_ []&ExecutionContext
	// Base pushes may happen while an inline JS-to-JS frame is running, and a
	// temporary execution context can push the same context multiple times.
	// Keep the previous running context for each base push so we can restore
	// and walk the full active stack without relying on caller_frame there.
	execution_context_stack_previous_running_contexts []?&ExecutionContext
	running_execution_context_                        ?&ExecutionContext
	// Only active while generated WebIDL conversion code runs without
	// re-entering ECMAScript. Any execution context push saves and clears it.
	type_error_realm_override       ?&Realm
	type_error_realm_override_depth int

	saved_execution_context_stacks []SavedExecutionContextStack

	stack_info_        StackInfo
	interpreter_stack_ InterpreterStack

	// GlobalSymbolRegistry, https://tc39.es/ecma262/#table-globalsymbolregistry-record-fields
	global_symbol_registry_ map[string]GlobalSymbolRegistryEntry

	promise_jobs                       []PromiseJob
	finalization_registry_cleanup_jobs []FinalizationRegistry

	empty_string_                  &PrimitiveString = unsafe { nil }
	single_ascii_character_strings []&PrimitiveString
	error_messages                 []Utf16String

	loaded_modules []StoredModule

	well_known_symbols_ []&Symbol

	execution_generation_          u32
	native_function_table          []NativeFunctionTableEntry
	native_function_indices        map[string]u32
	run_executable_depth           u32
	instruction_budget u64
	instruction_budget_active bool
	array_join_objects map[voidptr]bool
	module_execution_depth         u32
	module_async_evaluation_count  u64 // [[ModuleAsyncEvaluationCount]]
	private_environment_next_id    u64 = 1

	debugger_ ?&Debugger
	agent_    ?Agent

	dynamic_imports_allowed bool
pub mut:
	cached_strings CachedStrings

	on_promise_unhandled_rejection   fn (mut promise Promise) = unsafe { nil }
	on_promise_rejection_handled     fn (mut promise Promise) = unsafe { nil }
	on_unimplemented_property_access fn (object &Object, key PropertyName) = unsafe { nil }

	// 16.2.1.10 HostLoadImportedModule ( referrer, moduleRequest, hostDefined, payload ), https://tc39.es/ecma262/#sec-HostLoadImportedModule
	host_load_imported_module fn (referrer ImportedModuleReferrer, module_request ModuleRequest, host_defined voidptr, payload ImportedModulePayload) = unsafe { nil }

	host_get_import_meta_properties      fn (module_record Module) []ImportMetaProperty      = unsafe { nil }
	host_finalize_import_meta            fn (import_meta &Object, module_record Module)       = unsafe { nil }
	host_get_supported_import_attributes fn () []Utf16String                         = unsafe { nil }

	host_promise_rejection_tracker                 fn (mut promise Promise, operation RejectionOperation) = unsafe { nil }
	host_call_job_callback                         fn (mut job_callback JobCallback, this_value Value, arguments []Value) !Value = unsafe { nil }
	host_enqueue_finalization_registry_cleanup_job fn (mut registry FinalizationRegistry) = unsafe { nil }
	host_enqueue_promise_job                       fn (job PromiseJob, realm ?&Realm) = unsafe { nil }
	host_make_job_callback                         fn (callback FunctionObject) &JobCallback = unsafe { nil }
	host_get_code_for_eval                         fn (object &Object) ?&PrimitiveString = unsafe { nil }
	host_ensure_can_compile_strings                fn (realm &Realm, parameter_strings []Utf16String, body_string Utf16String, code_string Utf16String, compilation_type CompilationType, parameter_args []Value, body_arg Value) ! = unsafe { nil }
	host_ensure_can_add_private_element            fn (mut object Object) ! = unsafe { nil }
	host_resize_array_buffer                       fn (mut buffer ArrayBuffer, new_byte_length uint) !HandledByHost = unsafe { nil }
	host_grow_shared_array_buffer                  fn (mut buffer ArrayBuffer, new_byte_length uint) !HandledByHost = unsafe { nil }
	host_unrecognized_date_string                  fn (date_string Utf16String) = unsafe { nil }
	host_system_utc_epoch_nanoseconds              fn (global &Object) big.Integer = unsafe { nil }
	host_promise_job_queue_is_empty                fn () bool = unsafe { nil }

	// ParseJSONModule needs the JSON parser translation; hosts can supply one.
	parse_json_module fn (mut vm VM, realm &Realm, source_text string, filename string) !Module = unsafe { nil }
}

fn new_primitive_string(text string) &PrimitiveString {
	return &PrimitiveString{
		utf16: utf16_string(text)
	}
}

// 2.3.1 HostSystemUTCEpochNanoseconds clamps to the Temporal instant range.
const nanoseconds_min_instant = '-8640000000000000000000'
const nanoseconds_max_instant = '8640000000000000000000'

pub fn VM.create() &VM {
	mut vm := &VM{
		stack_info_:                StackInfo.new()
		interpreter_stack_:         InterpreterStack.new()
		string_to_atom_cache:       []StringToAtomCacheEntry{len: string_to_atom_cache_size}
		fly_string_cache:           []?&PrimitiveString{len: fly_string_cache_size, init: none}
		numeric_string_cache:       []?&PrimitiveString{len: numeric_string_cache_size, init: none}
		large_numeric_string_cache: []NumericStringCacheEntry{len: large_numeric_string_cache_size}
	}
	vm.error_messages = [utf16_string(ErrorType.out_of_memory.message())]
	vm.empty_string_ = &PrimitiveString{}
	vm.cached_strings = CachedStrings{
		number:        new_primitive_string('number')
		undefined:     new_primitive_string('undefined')
		object:        new_primitive_string('object')
		string:        new_primitive_string('string')
		symbol:        new_primitive_string('symbol')
		boolean:       new_primitive_string('boolean')
		bigint:        new_primitive_string('bigint')
		function:      new_primitive_string('function')
		object_object: new_primitive_string('[object Object]')
	}
	for code in 0 .. 128 {
		vm.single_ascii_character_strings << &PrimitiveString{
			utf16: Utf16String.from_slice([u16(code)])
		}
	}
	for name in well_known_symbol_names {
		vm.well_known_symbols_ << Symbol.create(utf16_string('Symbol.${name}'), .unique)
	}

	// Default hook implementations. Hosts override these; for example LibWeb
	// places promise jobs on the microtask queue.
	vm.host_promise_rejection_tracker = fn [mut vm] (mut promise Promise, operation RejectionOperation) {
		vm.promise_rejection_tracker(mut promise, operation)
	}
	vm.host_call_job_callback = fn [mut vm] (mut job_callback JobCallback, this_value Value, arguments []Value) !Value {
		return call_job_callback(mut vm, mut job_callback, this_value, arguments)
	}
	vm.host_enqueue_finalization_registry_cleanup_job = fn [mut vm] (mut registry FinalizationRegistry) {
		vm.enqueue_finalization_registry_cleanup_job(mut registry)
	}
	vm.host_enqueue_promise_job = fn [mut vm] (job PromiseJob, realm ?&Realm) {
		vm.enqueue_promise_job(job, realm)
	}
	vm.host_promise_job_queue_is_empty = fn [vm] () bool {
		return vm.promise_jobs.len == 0
	}
	vm.host_make_job_callback = fn (callback FunctionObject) &JobCallback {
		return make_job_callback(callback)
	}
	vm.host_load_imported_module = fn [mut vm] (referrer ImportedModuleReferrer, module_request ModuleRequest, host_defined voidptr, payload ImportedModulePayload) {
		vm.load_imported_module(referrer, module_request, host_defined, payload)
	}
	vm.host_get_import_meta_properties = fn (module_record Module) []ImportMetaProperty {
		return []
	}
	vm.host_finalize_import_meta = fn (import_meta &Object, module_record Module) {}
	vm.host_get_supported_import_attributes = fn () []Utf16String {
		return [utf16_string('type')]
	}
	// 1 HostGetCodeForEval ( argument ), https://tc39.es/proposal-dynamic-code-brand-checks/#sec-hostgetcodeforeval
	vm.host_get_code_for_eval = fn (object &Object) ?&PrimitiveString {
		// The default implementation of HostGetCodeForEval is to return NO-CODE.
		return none
	}
	// 2 HostEnsureCanCompileStrings ( calleeRealm, parameterStrings, bodyString, codeString, compilationType, parameterArgs, bodyArg ), https://tc39.es/proposal-dynamic-code-brand-checks/#sec-hostensurecancompilestrings
	vm.host_ensure_can_compile_strings = fn (realm &Realm, parameter_strings []Utf16String, body_string Utf16String, code_string Utf16String, compilation_type CompilationType, parameter_args []Value, body_arg Value) ! {
		// The default implementation of HostEnsureCanCompileStrings is to return NormalCompletion(unused).
	}
	vm.host_ensure_can_add_private_element = fn (mut object Object) ! {
		// The default implementation of HostEnsureCanAddPrivateElement is to return NormalCompletion(unused).
	}
	// 25.1.3.8 HostResizeArrayBuffer ( buffer, newByteLength ), https://tc39.es/ecma262/#sec-hostresizearraybuffer
	vm.host_resize_array_buffer = fn [mut vm] (mut buffer ArrayBuffer, new_byte_length uint) !HandledByHost {
		if !buffer.try_resize(new_byte_length, true) {
			return vm.throw_error_type(.range_error, .not_enough_memory_to_allocate, new_byte_length.str())
		}
		return HandledByHost.handled
	}
	// 25.2.2.4 HostGrowSharedArrayBuffer ( buffer, newByteLength ), https://tc39.es/ecma262/#sec-hostgrowsharedarraybuffer
	vm.host_grow_shared_array_buffer = fn (mut buffer ArrayBuffer, new_byte_length uint) !HandledByHost {
		// The default implementation of HostGrowSharedArrayBuffer is to return NormalCompletion(unhandled).
		return HandledByHost.unhandled
	}
	// 2.3.1 HostSystemUTCEpochNanoseconds ( global ), https://tc39.es/proposal-temporal/#sec-hostsystemutcepochnanoseconds
	vm.host_system_utc_epoch_nanoseconds = fn (global &Object) big.Integer {
		// 1. Let ns be the approximate current UTC date and time, in nanoseconds since the epoch.
		mut nanoseconds := big.integer_from_i64(time.now().unix_nano())
		// 2. Return the result of clamping ns between nsMinInstant and nsMaxInstant.
		minimum := big.integer_from_string(nanoseconds_min_instant) or { panic(err) }
		maximum := big.integer_from_string(nanoseconds_max_instant) or { panic(err) }
		if nanoseconds < minimum {
			nanoseconds = minimum
		}
		if nanoseconds > maximum {
			nanoseconds = maximum
		}
		return nanoseconds
	}
	// AD-HOC: Inform the host that we received a date string we were unable to parse.
	vm.host_unrecognized_date_string = fn (date_string Utf16String) {}
	vm.parse_json_module = fn (mut vm VM, realm &Realm, source_text string, filename string) !Module {
		return vm.throw_error(.internal_error, 'JSON modules require the JSON parser translation (${filename})')
	}
	return vm
}

pub fn (vm &VM) heap_roots() HeapRoots {
	mut roots := HeapRoots{}
	vm.gather_roots(mut roots)
	return roots
}

// Native function table

pub fn (mut vm VM) register_native_function(function NativeFunctionPointer, type_ NativeFunctionType) u32 {
	if function == unsafe { nil } {
		panic('register_native_function: null function pointer')
	}
	key := '${u64(voidptr(function))}:${u32(type_)}'
	if index := vm.native_function_indices[key] {
		return index
	}
	index := u32(vm.native_function_table.len)
	vm.native_function_table << NativeFunctionTableEntry{
		function: function
		type_:    type_
	}
	vm.native_function_indices[key] = index
	return index
}

pub fn (vm &VM) native_function(index u32, expected_type NativeFunctionType) NativeFunctionPointer {
	if index >= u32(vm.native_function_table.len) {
		panic('native_function: index ${index} is out of range')
	}
	entry := vm.native_function_table[index]
	if entry.type_ != expected_type {
		panic('native_function: entry ${index} has type ${entry.type_}, expected ${expected_type}')
	}
	return entry.function
}

pub fn (vm &VM) native_function_count() int {
	return vm.native_function_table.len
}

// Debugger

// NB: The interpreter picks its dispatch table when it starts running an
//     outermost executable, so enabling debugging affects later invocations only.
pub fn (mut vm VM) enable_debugging() {
	if vm.debugger_ == none {
		vm.debugger_ = &Debugger{}
	}
}

pub fn (mut vm VM) disable_debugging() {
	if debugger := vm.debugger_ {
		if debugger.is_paused {
			panic('disable_debugging while the debugger is paused')
		}
	}
	vm.debugger_ = none
}

pub fn (vm &VM) debugging_enabled() bool {
	return vm.debugger_ != none
}

pub fn (vm &VM) debugger() ?&Debugger {
	return vm.debugger_
}

// Agent

pub fn (mut vm VM) set_agent(agent Agent) {
	vm.agent_ = agent
}

pub fn (vm &VM) agent() ?Agent {
	return vm.agent_
}

// Strings and symbols

pub fn (vm &VM) error_message(message VmErrorMessage) Utf16String {
	text := vm.error_messages[int(message)]
	if text.is_empty() {
		panic('error_message: ${message} was not pre-allocated')
	}
	return text
}

pub fn (vm &VM) empty_string() &PrimitiveString {
	return vm.empty_string_
}

pub fn (vm &VM) single_ascii_character_string(character u8) &PrimitiveString {
	if character >= 0x80 {
		panic('single_ascii_character_string: ${character} is not ASCII')
	}
	return vm.single_ascii_character_strings[character]
}

pub fn (mut vm VM) string_to_atom_cache() []StringToAtomCacheEntry {
	return vm.string_to_atom_cache
}

pub fn (vm &VM) fly_string_cache_entry(index int) ?&PrimitiveString {
	return vm.fly_string_cache[index]
}

pub fn (vm &VM) well_known_symbol(symbol WellKnownSymbol) &Symbol {
	return vm.well_known_symbols_[int(symbol)]
}

pub fn (vm &VM) well_known_symbol_async_dispose() &Symbol {
	return vm.well_known_symbol(.async_dispose)
}

pub fn (vm &VM) well_known_symbol_async_iterator() &Symbol {
	return vm.well_known_symbol(.async_iterator)
}

pub fn (vm &VM) well_known_symbol_dispose() &Symbol {
	return vm.well_known_symbol(.dispose)
}

pub fn (vm &VM) well_known_symbol_has_instance() &Symbol {
	return vm.well_known_symbol(.has_instance)
}

pub fn (vm &VM) well_known_symbol_is_concat_spreadable() &Symbol {
	return vm.well_known_symbol(.is_concat_spreadable)
}

pub fn (vm &VM) well_known_symbol_iterator() &Symbol {
	return vm.well_known_symbol(.iterator)
}

pub fn (vm &VM) well_known_symbol_match() &Symbol {
	return vm.well_known_symbol(.match_)
}

pub fn (vm &VM) well_known_symbol_match_all() &Symbol {
	return vm.well_known_symbol(.match_all)
}

pub fn (vm &VM) well_known_symbol_replace() &Symbol {
	return vm.well_known_symbol(.replace)
}

pub fn (vm &VM) well_known_symbol_replace_all() &Symbol {
	return vm.well_known_symbol(.replace_all)
}

pub fn (vm &VM) well_known_symbol_search() &Symbol {
	return vm.well_known_symbol(.search)
}

pub fn (vm &VM) well_known_symbol_species() &Symbol {
	return vm.well_known_symbol(.species)
}

pub fn (vm &VM) well_known_symbol_split() &Symbol {
	return vm.well_known_symbol(.split)
}

pub fn (vm &VM) well_known_symbol_to_primitive() &Symbol {
	return vm.well_known_symbol(.to_primitive)
}

pub fn (vm &VM) well_known_symbol_to_string_tag() &Symbol {
	return vm.well_known_symbol(.to_string_tag)
}

pub fn (vm &VM) well_known_symbol_unscopables() &Symbol {
	return vm.well_known_symbol(.unscopables)
}

fn global_symbol_registry_key(key Utf16String) string {
	return encode_utf16(key.as_slice(), false)
}

pub fn (vm &VM) global_symbol_registry() []GlobalSymbolRegistryEntry {
	return vm.global_symbol_registry_.values()
}

pub fn (vm &VM) global_symbol_registry_lookup(key Utf16String) ?&Symbol {
	entry := vm.global_symbol_registry_[global_symbol_registry_key(key)] or { return none }
	return entry.symbol
}

pub fn (mut vm VM) global_symbol_registry_set(key Utf16String, symbol &Symbol) {
	vm.global_symbol_registry_[global_symbol_registry_key(key)] = GlobalSymbolRegistryEntry{
		key:    key
		symbol: symbol
	}
}

fn (mut vm VM) allocate_private_environment_id() u64 {
	id := vm.private_environment_next_id
	vm.private_environment_next_id++
	if vm.private_environment_next_id == 0 {
		panic('private environment ids exhausted')
	}
	return id
}

// Execution context stack

pub fn (vm &VM) stack_info() StackInfo {
	return vm.stack_info_
}

pub fn (mut vm VM) interpreter_stack() &InterpreterStack {
	return &vm.interpreter_stack_
}

pub fn (vm &VM) did_reach_stack_space_limit() bool {
	return vm.stack_info_.size_free() < 32 * 1024
}

// push_execution_context(ExecutionContext&, CheckStackSpaceLimitTag)
pub fn (mut vm VM) push_execution_context_checked(mut context ExecutionContext) ! {
	// Ensure we got some stack space left, so the next function call doesn't kill us.
	if vm.did_reach_stack_space_limit() {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	vm.push_execution_context(mut context)
}

pub fn (mut vm VM) push_execution_context(mut context ExecutionContext) {
	context.caller_frame = none
	context.caller_return_pc = 0
	context.caller_dst_raw = 0
	context.caller_is_construct = false
	vm.execution_context_stack_ << &context
	vm.execution_context_stack_previous_running_contexts << vm.running_execution_context_
	vm.running_execution_context_ = &context
}

pub fn (mut vm VM) pop_execution_context() &ExecutionContext {
	if vm.execution_context_stack_.len == 0 {
		panic('pop_execution_context on an empty execution context stack')
	}
	mut context := vm.execution_context_stack_.pop()
	context.caller_frame = none
	context.caller_return_pc = 0
	context.caller_dst_raw = 0
	context.caller_is_construct = false
	vm.running_execution_context_ = vm.execution_context_stack_previous_running_contexts.pop()
	return context
}

// https://tc39.es/ecma262/#running-execution-context
// At any point in time, there is at most one execution context per agent that
// is actually executing code. This is the agent's running execution context.
pub fn (vm &VM) running_execution_context() &ExecutionContext {
	return vm.running_execution_context_ or { panic('no running execution context') }
}

pub fn (vm &VM) has_running_execution_context() bool {
	return vm.running_execution_context_ != none
}

// Non-standard: the interpreter switches the running context for inline frames
// without touching the base stack.
pub fn (mut vm VM) set_running_execution_context(context ?&ExecutionContext) {
	vm.running_execution_context_ = context
}

// https://tc39.es/ecma262/#execution-context-stack
// The execution context stack tracks base execution contexts. Inline JS-to-JS
// frames are threaded through ExecutionContext.caller_frame starting at the
// running execution context.
pub fn (vm &VM) execution_context_stack() []&ExecutionContext {
	return vm.execution_context_stack_
}

fn collect_execution_contexts_top_to_bottom(stack []&ExecutionContext, previous_running_contexts []?&ExecutionContext, running_execution_context ?&ExecutionContext) []&ExecutionContext {
	if stack.len != previous_running_contexts.len {
		panic('execution context stack and previous running contexts are out of sync')
	}
	mut contexts := []&ExecutionContext{}
	running := running_execution_context or {
		for index := stack.len - 1; index >= 0; index-- {
			contexts << stack[index]
		}
		return contexts
	}
	if stack.len == 0 {
		mut current := ?&ExecutionContext(running)
		for {
			context := current or { break }
			contexts << context
			current = context.caller_frame
		}
		return contexts
	}
	mut stack_index := stack.len
	mut current := ?&ExecutionContext(running)
	for {
		context := current or { break }
		contexts << context
		if stack_index > 0 && voidptr(context) == voidptr(stack[stack_index - 1]) {
			current = previous_running_contexts[stack_index - 1]
			stack_index--
			continue
		}
		current = context.caller_frame
	}
	if stack_index != 0 {
		panic('execution context walk did not reach the bottom of the base stack')
	}
	return contexts
}

// for_each_execution_context_top_to_bottom: the running context first, inline
// frames through caller_frame, then each earlier base push.
pub fn (vm &VM) execution_contexts_top_to_bottom() []&ExecutionContext {
	return collect_execution_contexts_top_to_bottom(vm.execution_context_stack_, vm.execution_context_stack_previous_running_contexts,
		vm.running_execution_context_)
}

// Returns the topmost execution context the predicate accepts.
pub fn (vm &VM) last_execution_context_matching(callback fn (context &ExecutionContext) bool) ?&ExecutionContext {
	for context in vm.execution_contexts_top_to_bottom() {
		if callback(context) {
			return context
		}
	}
	return none
}

pub fn (vm &VM) previous_execution_context() ?&ExecutionContext {
	contexts := vm.execution_contexts_top_to_bottom()
	if contexts.len < 2 {
		return none
	}
	return contexts[1]
}

pub fn (mut vm VM) save_execution_context_stack() {
	vm.saved_execution_context_stacks << SavedExecutionContextStack{
		stack:                           vm.execution_context_stack_
		previous_running_contexts:       vm.execution_context_stack_previous_running_contexts
		running_execution_context:       vm.running_execution_context_
		type_error_realm_override:       vm.type_error_realm_override
		type_error_realm_override_depth: vm.type_error_realm_override_depth
	}
	vm.execution_context_stack_ = []
	vm.execution_context_stack_previous_running_contexts = []
	vm.running_execution_context_ = none
	vm.type_error_realm_override = none
	vm.type_error_realm_override_depth = 0
}

pub fn (mut vm VM) clear_execution_context_stack() {
	vm.execution_context_stack_.clear()
	vm.execution_context_stack_previous_running_contexts.clear()
	vm.running_execution_context_ = none
	vm.type_error_realm_override = none
	vm.type_error_realm_override_depth = 0
}

pub fn (mut vm VM) restore_execution_context_stack() {
	if vm.saved_execution_context_stacks.len == 0 {
		panic('restore_execution_context_stack without a saved stack')
	}
	saved_stack := vm.saved_execution_context_stacks.pop()
	vm.execution_context_stack_ = saved_stack.stack
	vm.execution_context_stack_previous_running_contexts = saved_stack.previous_running_contexts
	vm.running_execution_context_ = saved_stack.running_execution_context
	vm.type_error_realm_override = saved_stack.type_error_realm_override
	vm.type_error_realm_override_depth = saved_stack.type_error_realm_override_depth
}

pub fn (vm &VM) saved_execution_context_stack_count() int {
	return vm.saved_execution_context_stacks.len
}

// Running-context accessors

pub fn (vm &VM) realm() &Realm {
	return vm.running_execution_context().realm or { panic('running execution context has no realm') }
}

pub fn (vm &VM) global_object() &Object {
	return vm.realm().global_object_record()
}

pub fn (vm &VM) global_declarative_environment() &DeclarativeEnvironment {
	return vm.realm().global_declarative_environment or {
		panic('realm has no global declarative environment')
	}
}

pub fn (vm &VM) lexical_environment() ?Environment {
	return vm.running_execution_context().lexical_environment
}

pub fn (vm &VM) variable_environment() ?Environment {
	return vm.running_execution_context().variable_environment
}

// https://tc39.es/ecma262/#current-realm
// The value of the Realm component of the running execution context is also called the current Realm Record.
pub fn (vm &VM) current_realm() ?&Realm {
	return vm.running_execution_context().realm
}

// https://tc39.es/ecma262/#active-function-object
// The value of the Function component of the running execution context is also called the active function object.
pub fn (vm &VM) active_function_object() ?FunctionObject {
	return vm.running_execution_context().function
}

pub fn (vm &VM) argument_count() u32 {
	return vm.running_execution_context().argument_count
}

pub fn (vm &VM) argument(index u32) Value {
	return vm.running_execution_context().argument(index)
}

pub fn (vm &VM) this_value() Value {
	return vm.running_execution_context().this_value or {
		panic('running execution context has no this value')
	}
}

pub fn (vm &VM) reg(index u32) Value {
	return vm.running_execution_context().values[index]
}

pub fn (mut vm VM) set_reg(index u32, value Value) {
	mut context := vm.running_execution_context()
	context.values[index] = value
}

pub fn (vm &VM) accumulator() Value {
	return vm.reg(register_accumulator)
}

pub fn (mut vm VM) set_accumulator(value Value) {
	vm.set_reg(register_accumulator, value)
}

pub fn (mut vm VM) do_return(value_argument Value) {
	mut value := value_argument
	if value.is_special_empty_value() {
		value = js_undefined()
	}
	vm.set_reg(register_return_value, value)
	vm.set_reg(register_exception, js_special_empty_value())
}

pub fn (vm &VM) current_executable() &Executable {
	return vm.running_execution_context().executable or {
		panic('running execution context has no executable')
	}
}

pub fn (vm &VM) get_identifier(index u32) Utf16String {
	return vm.current_executable().get_identifier(index)
}

pub fn (vm &VM) execution_generation() u32 {
	return vm.execution_generation_
}

pub fn (mut vm VM) finish_execution_generation() {
	vm.execution_generation_++
}

pub fn (vm &VM) run_executable_depth() u32 {
	return vm.run_executable_depth
}

// Module bookkeeping

pub fn (mut vm VM) enter_module_execution() {
	vm.module_execution_depth++
}

pub fn (mut vm VM) leave_module_execution() {
	if vm.module_execution_depth == 0 {
		panic('leave_module_execution without a matching enter')
	}
	vm.module_execution_depth--
}

pub fn (vm &VM) is_executing_module() bool {
	return vm.module_execution_depth > 0
}

pub fn (mut vm VM) increment_module_async_evaluation_count() u64 {
	count := vm.module_async_evaluation_count
	vm.module_async_evaluation_count++
	return count
}

pub fn (mut vm VM) set_dynamic_imports_allowed(value bool) {
	vm.dynamic_imports_allowed = value
}

pub fn (vm &VM) dynamic_imports_allowed() bool {
	return vm.dynamic_imports_allowed
}

// Errors

fn (vm &VM) realm_for_thrown_error(kind ErrorKind) &Realm {
	if kind == .type_error {
		if override := vm.type_error_realm_override {
			if vm.execution_context_stack_.len == vm.type_error_realm_override_depth {
				return override
			}
		}
	}
	return vm.current_realm() or { panic('throwing an error requires a realm on the running execution context') }
}

// 5.2.3.2 Throw an Exception, https://tc39.es/ecma262/#sec-throw-an-exception
pub fn (mut vm VM) throw_error_utf16(kind ErrorKind, message Utf16String) IError {
	realm := vm.realm_for_thrown_error(kind)
	error_object := create_error(mut vm, realm, kind, message)
	return throw_completion(Value.from_object(error_object))
}

pub fn (mut vm VM) throw_error(kind ErrorKind, message string) IError {
	return vm.throw_error_utf16(kind, utf16_string(message))
}

// throw_completion<T>(ErrorType const&, Args&&...)
pub fn (mut vm VM) throw_error_type(kind ErrorKind, error_type ErrorType, args ...string) IError {
	return vm.throw_error(kind, error_type.formatted(...args))
}

// Binding resolution

// 9.1.2.1 GetIdentifierReference ( env, name, strict ), https://tc39.es/ecma262/#sec-getidentifierreference
pub fn (mut vm VM) get_identifier_reference(environment ?Environment, name Utf16String, strict bool, hops u32) !Reference {
	// 1. If env is the value null, then
	env := environment or {
		// a. Return the Reference Record { [[Base]]: unresolvable, [[ReferencedName]]: name, [[Strict]]: strict, [[ThisValue]]: empty }.
		return Reference.unresolvable(name, strict)
	}
	// 2. Let exists be ? env.HasBinding(name).
	exists, index := env.has_binding(mut vm, name)!
	// Note: This is an optimization for looking up the same reference.
	mut environment_coordinate := ?EnvironmentCoordinate(none)
	if binding_index := index {
		environment_coordinate = EnvironmentCoordinate{
			hops:  hops
			index: u32(binding_index)
		}
	}
	// 3. If exists is true, then
	if exists {
		// a. Return the Reference Record { [[Base]]: env, [[ReferencedName]]: name, [[Strict]]: strict, [[ThisValue]]: empty }.
		return Reference.for_environment(env, name, strict, environment_coordinate)
	}
	// 4. Else,
	// a. Let outer be env.[[OuterEnv]].
	// b. Return ? GetIdentifierReference(outer, name, strict).
	return vm.get_identifier_reference(env.outer_environment(), name, strict, hops + 1)
}

// 9.4.2 ResolveBinding ( name [ , env ] ), https://tc39.es/ecma262/#sec-resolvebinding
pub fn (mut vm VM) resolve_binding(name Utf16String, strict bool, environment ?Environment) !Reference {
	// 1. If env is not present or if env is undefined, then
	env := environment or {
		// a. Set env to the running execution context's LexicalEnvironment.
		vm.running_execution_context().lexical_environment or {
			// 2. Assert: env is an Environment Record.
			panic('ResolveBinding: the running execution context has no lexical environment')
		}
	}
	// 3. If the source text matched by the syntactic production that is being evaluated is contained in strict mode code, let strict be true; else let strict be false.
	// NOTE: We take this as a parameter.
	// 4. Return ? GetIdentifierReference(env, name, strict).
	return vm.get_identifier_reference(env, name, strict, 0)
}

// 9.4.4 ResolveThisBinding ( ), https://tc39.es/ecma262/#sec-resolvethisbinding
pub fn (mut vm VM) resolve_this_binding() !Value {
	// 1. Let envRec be GetThisEnvironment().
	environment := get_this_environment(vm)
	// 2. Return ? envRec.GetThisBinding().
	return environment.get_this_binding(mut vm)
}

// 9.4.5 GetNewTarget ( ), https://tc39.es/ecma262/#sec-getnewtarget
pub fn (vm &VM) get_new_target() Value {
	// 1. Let envRec be GetThisEnvironment().
	environment := get_this_environment(vm)
	// 2. Assert: envRec has a [[NewTarget]] field.
	// 3. Return envRec.[[NewTarget]].
	if environment is FunctionEnvironment {
		return environment.new_target
	}
	panic('GetNewTarget: the this environment is not a function environment')
}

// 13.3.12.1 Runtime Semantics: Evaluation, https://tc39.es/ecma262/#sec-meta-properties-runtime-semantics-evaluation
// ImportMeta branch only
pub fn (mut vm VM) get_import_meta() &Object {
	// 1. Let module be GetActiveScriptOrModule().
	script_or_module := vm.get_active_script_or_module()
	// 2. Assert: module is a Source Text Module Record.
	mut module_record := script_or_module.module_record or {
		panic('GetImportMeta: the active script or module is not a module')
	}
	// 3. Let importMeta be module.[[ImportMeta]].
	// 4. If importMeta is empty, then
	if existing := module_record.import_meta() {
		// 5. Else, b. Return importMeta.
		return existing
	}
	// a. Set importMeta to OrdinaryObjectCreate(null).
	realm := vm.current_realm() or { panic('GetImportMeta requires a realm') }
	mut import_meta := Object.create(realm, none)
	// b. Let importMetaValues be HostGetImportMetaProperties(module).
	import_meta_values := vm.host_get_import_meta_properties(module_record)
	// c. For each Record { [[Key]], [[Value]] } p of importMetaValues, do
	for entry in import_meta_values {
		// i. Perform ! CreateDataPropertyOrThrow(importMeta, p.[[Key]], p.[[Value]]).
		import_meta.create_data_property_or_throw(mut vm, entry.key, entry.value) or {
			panic('CreateDataPropertyOrThrow on a fresh import.meta object failed')
		}
	}
	// d. Perform HostFinalizeImportMeta(importMeta, module).
	vm.host_finalize_import_meta(import_meta, module_record)
	// e. Set module.[[ImportMeta]] to importMeta.
	module_record.set_import_meta(import_meta)
	// f. Return importMeta.
	return import_meta
}

// 9.4.5 GetGlobalObject ( ), https://tc39.es/ecma262/#sec-getglobalobject
pub fn (vm &VM) get_global_object() &Object {
	// 1. Let currentRealm be the current Realm Record.
	current_realm := vm.current_realm() or { panic('GetGlobalObject requires a realm') }
	// 2. Return currentRealm.[[GlobalObject]].
	return current_realm.global_object_record()
}

// Jobs

pub fn (mut vm VM) run_queued_promise_jobs() {
	for vm.promise_jobs.len > 0 {
		job := vm.promise_jobs[0]
		vm.promise_jobs.delete(0)
		// The job result is intentionally ignored.
		job() or {}
	}
}

// 9.5.4 HostEnqueuePromiseJob ( job, realm ), https://tc39.es/ecma262/#sec-hostenqueuepromisejob
pub fn (mut vm VM) enqueue_promise_job(job PromiseJob, realm ?&Realm) {
	// Jobs must run in the same order as the HostEnqueuePromiseJob invocations that scheduled them.
	vm.promise_jobs << job
}

pub fn (vm &VM) promise_job_count() int {
	return vm.promise_jobs.len
}

pub fn (mut vm VM) run_queued_finalization_registry_cleanup_jobs() {
	for vm.finalization_registry_cleanup_jobs.len > 0 {
		mut registry := vm.finalization_registry_cleanup_jobs.pop()
		// FIXME: Handle any uncaught exceptions here.
		registry.cleanup(mut vm) or {
			if registry.has_empty_cells() {
				vm.finalization_registry_cleanup_jobs << registry
			}
		}
	}
}

// 9.10.4.1 HostEnqueueFinalizationRegistryCleanupJob ( finalizationRegistry ), https://tc39.es/ecma262/#sec-host-cleanup-finalization-registry
pub fn (mut vm VM) enqueue_finalization_registry_cleanup_job(mut registry FinalizationRegistry) {
	vm.finalization_registry_cleanup_jobs << registry
}

pub fn (vm &VM) finalization_registry_cleanup_job_count() int {
	return vm.finalization_registry_cleanup_jobs.len
}

// 27.2.1.9 HostPromiseRejectionTracker ( promise, operation ), https://tc39.es/ecma262/#sec-host-promise-rejection-tracker
pub fn (vm &VM) promise_rejection_tracker(mut promise Promise, operation RejectionOperation) {
	match operation {
		.reject {
			// A promise was rejected without any handlers
			if vm.on_promise_unhandled_rejection != unsafe { nil } {
				vm.on_promise_unhandled_rejection(mut promise)
			}
		}
		.handle {
			// A handler was added to an already rejected promise
			if vm.on_promise_rejection_handled != unsafe { nil } {
				vm.on_promise_rejection_handled(mut promise)
			}
		}
	}
}

// Stack traces and roots

pub fn (vm &VM) stack_trace() []StackTraceElement {
	mut stack_trace := []StackTraceElement{}
	for context in vm.execution_contexts_top_to_bottom() {
		mut source_range := ?SourceCodeRange(none)
		if executable := context.executable {
			source_range = executable.get_source_range(context.program_counter)
		}
		stack_trace << StackTraceElement{
			execution_context: context
			source_range:      source_range
		}
	}
	return stack_trace
}

pub fn (vm &VM) backtrace_lines() []string {
	mut lines := []string{}
	for frame in vm.execution_contexts_top_to_bottom() {
		name := if function := frame.function { function.name_for_call_stack().str() } else { '' }
		if executable := frame.executable {
			if source_range := executable.source_range_at(frame.program_counter) {
				lines << '-> ${name} @ ${source_range.filename().str()}:${source_range.start.line},${source_range.start.column}'
				continue
			}
		}
		lines << '-> ${name}'
	}
	return lines
}

pub fn (vm &VM) dump_backtrace() {
	for line in vm.backtrace_lines() {
		eprintln(line)
	}
}

pub fn (vm &VM) gather_roots(mut roots HeapRoots) {
	roots.add(voidptr(vm.empty_string_))
	for cached in vm.single_ascii_character_strings {
		roots.add(voidptr(cached))
	}
	for entry in vm.numeric_string_cache {
		// The numeric string cache is populated lazily, so skip null entries.
		if cached := entry {
			roots.add(voidptr(cached))
		}
	}
	for entry in vm.large_numeric_string_cache {
		if cached := entry.string {
			roots.add(voidptr(cached))
		}
	}
	roots.add(voidptr(vm.cached_strings.number))
	roots.add(voidptr(vm.cached_strings.undefined))
	roots.add(voidptr(vm.cached_strings.object))
	roots.add(voidptr(vm.cached_strings.string))
	roots.add(voidptr(vm.cached_strings.symbol))
	roots.add(voidptr(vm.cached_strings.boolean))
	roots.add(voidptr(vm.cached_strings.bigint))
	roots.add(voidptr(vm.cached_strings.function))
	roots.add(voidptr(vm.cached_strings.object_object))
	for symbol in vm.well_known_symbols_ {
		roots.add(voidptr(symbol))
	}
	for _, entry in vm.global_symbol_registry_ {
		roots.add(voidptr(entry.symbol))
	}
	for registry in vm.finalization_registry_cleanup_jobs {
		roots.add(finalization_registry_identity(registry))
	}
	for context in vm.execution_contexts_top_to_bottom() {
		context.visit_roots(mut roots)
	}
	for saved_stack in vm.saved_execution_context_stacks {
		for context in collect_execution_contexts_top_to_bottom(saved_stack.stack, saved_stack.previous_running_contexts,
			saved_stack.running_execution_context)
		{
			context.visit_roots(mut roots)
		}
	}
	if override := vm.type_error_realm_override {
		roots.add(voidptr(override))
	}
	for saved_stack in vm.saved_execution_context_stacks {
		if override := saved_stack.type_error_realm_override {
			roots.add(voidptr(override))
		}
	}
	// Promise jobs are V closures managed by the V runtime rather than GC cells.
}

// 9.4.1 GetActiveScriptOrModule ( ), https://tc39.es/ecma262/#sec-getactivescriptormodule
pub fn (vm &VM) get_active_script_or_module() ScriptOrModule {
	// 1. If the execution context stack is empty, return null.
	if vm.running_execution_context_ == none {
		return ScriptOrModule{}
	}
	// 2. Let ec be the topmost execution context on the execution context stack whose ScriptOrModule component is not null.
	for context in vm.execution_contexts_top_to_bottom() {
		if !context.script_or_module.is_empty() {
			// 3. Otherwise, return ec's ScriptOrModule.
			return context.script_or_module
		}
	}
	// 3. If no such execution context exists, return null.
	return ScriptOrModule{}
}

// Exception handling (Interpreter/Interpreter.cpp)

pub fn (mut vm VM) handle_exception(program_counter_argument u32, exception Value) HandleExceptionResponse {
	// NOTE: Debugger pause-on-exception hooks are part of the pending debugger translation.
	mut program_counter := program_counter_argument
	for {
		if handlers := vm.current_executable().exception_handlers_for_offset(program_counter) {
			vm.set_reg(register_exception, exception)
			mut running := vm.running_execution_context()
			running.program_counter = handlers.handler_offset
			return .continue_in_this_executable
		}
		// If we're in an inline frame, unwind to the caller and try its handlers.
		callee_frame := vm.running_execution_context()
		if caller_frame := callee_frame.caller_frame {
			caller_pc := callee_frame.caller_return_pc
			vm.interpreter_stack_.deallocate_context(callee_frame)
			vm.running_execution_context_ = caller_frame
			// NB: caller_pc is the return address (one past the Call instruction).
			//     For handler lookup we need a PC inside the Call instruction,
			//     since the exception occurred during that call, not after it.
			//     Exception handler ranges use an exclusive end offset, so using
			//     caller_pc directly would miss a handler ending right at that address.
			program_counter = caller_pc - 1
			continue
		}
		vm.set_reg(register_exception, exception)
		return .exit_from_executable
	}
	return .exit_from_executable
}

pub fn (mut vm VM) unwind_inline_frame_for_exception() {
	callee_frame := vm.running_execution_context()
	caller_frame := callee_frame.caller_frame or {
		panic('unwind_inline_frame_for_exception: the running frame has no caller frame')
	}
	vm.interpreter_stack_.deallocate_context(callee_frame)
	vm.running_execution_context_ = caller_frame
}

// Module loading (the default HostLoadImportedModule for file-backed modules)

pub fn (vm &VM) stored_module_count() int {
	return vm.loaded_modules.len
}

pub fn (vm &VM) stored_module(index int) StoredModule {
	return vm.loaded_modules[index]
}

pub fn (vm &VM) get_stored_module(referrer ImportedModuleReferrer, filename string, module_type string) ?int {
	// FIXME: This should probably check referrer as well.
	for index, stored_module in vm.loaded_modules {
		if stored_module.filename == filename {
			return index
		}
	}
	return none
}

// LexicalPath::canonicalized_path resolves "." and ".." segments lexically.
pub fn lexical_canonicalized_path(path string) string {
	is_absolute := path.starts_with('/')
	mut parts := []string{}
	for part in path.split('/') {
		if part == '' || part == '.' {
			continue
		}
		if part == '..' {
			if parts.len > 0 && parts.last() != '..' {
				parts.pop()
			} else if !is_absolute {
				parts << '..'
			}
			continue
		}
		parts << part
	}
	joined := parts.join('/')
	if is_absolute {
		return '/' + joined
	}
	if joined == '' {
		return '.'
	}
	return joined
}

// LexicalPath::absolute_path(dir_path, target)
pub fn lexical_absolute_path(directory string, target string) string {
	if target.starts_with('/') {
		return lexical_canonicalized_path(target)
	}
	return lexical_canonicalized_path(os.join_path_single(directory, target))
}

pub fn resolve_module_filename(filename string, module_type string) string {
	mut extensions := ['js', 'mjs']
	if module_type == 'json' {
		extensions = ['json']
	}
	if !os.exists(filename) {
		for extension in extensions {
			// import "./foo" -> import "./foo.ext"
			resolved_filepath := '${filename}.${extension}'
			if os.exists(resolved_filepath) {
				return resolved_filepath
			}
		}
	} else if os.is_dir(filename) {
		for extension in extensions {
			// import "./foo" -> import "./foo/index.ext"
			resolved_filepath := os.join_path_single(filename, 'index.${extension}')
			if os.exists(resolved_filepath) {
				return resolved_filepath
			}
		}
	}
	return filename
}

pub fn (mut vm VM) link_and_eval_module(mut module_record Module) ! {
	filename := module_record.filename()
	if filename != '' {
		absolute_filename := resolve_module_filename(lexical_absolute_path('.', filename), '')
		if vm.get_stored_module(ImportedModuleReferrer.from_module(module_record), absolute_filename, '') == none {
			// Register the entry module before loading dependencies so self-imports resolve to this Module Record.
			vm.loaded_modules << StoredModule{
				referrer:                 ImportedModuleReferrer.from_module(module_record)
				filename:                 absolute_filename
				module_record:                   module_record
				has_once_started_linking: true
			}
		}
	}
	promise_capability := module_record.load_requested_modules(mut vm, unsafe { nil })
	if promise_capability.promise.state == .rejected {
		return throw_completion(promise_capability.promise.result)
	}
	module_record.link(mut vm)!
	evaluated := module_record.evaluate(mut vm)!
	evaluated_promise := evaluated.promise
	vm.run_queued_promise_jobs()
	if vm.promise_jobs.len != 0 {
		panic('promise jobs remained queued after module evaluation')
	}
	// FIXME: This will break if we start doing promises actually asynchronously.
	if evaluated_promise.state == .pending {
		panic('module evaluation left its promise pending')
	}
	if evaluated_promise.state == .rejected {
		return throw_completion(evaluated_promise.result)
	}
}

fn strip_utf8_byte_order_mark(text string) string {
	if text.len >= 3 && text[0] == 0xEF && text[1] == 0xBB && text[2] == 0xBF {
		return text[3..]
	}
	return text
}

// 16.2.1.8 HostLoadImportedModule ( referrer, specifier, hostDefined, payload ), https://tc39.es/ecma262/#sec-HostLoadImportedModule
pub fn (mut vm VM) load_imported_module(referrer ImportedModuleReferrer, module_request ModuleRequest, host_defined voidptr, payload ImportedModulePayload) {
	// Here we check, against the spec, if payload is a promise capability, meaning that this was called for a dynamic import
	if payload.kind == .promise_capability && !vm.dynamic_imports_allowed {
		// If you are here because you want to enable dynamic module importing make sure it won't be a security problem
		// by checking the default implementation of HostImportModuleDynamically and creating your own hook or calling
		// vm.set_dynamic_imports_allowed(true).
		finish_loading_imported_module(referrer, module_request, payload, ModuleLoadResult.from_error(vm.throw_error_type(.internal_error,
			.dynamic_import_not_allowed, module_request.module_specifier.str())))
		return
	}
	mut module_type := ''
	for attribute in module_request.attributes {
		if attribute.key.str() == 'type' {
			module_type = attribute.value.str()
			break
		}
	}
	base_filename := if referrer.kind == .realm {
		// Generally within ECMA262 we always get a referencing_script_or_module. However, ShadowRealm gives an explicit null.
		// To get around this is we attempt to get the active script_or_module otherwise we might start loading "random" files from the working directory.
		active := vm.get_active_script_or_module()
		if active.is_empty() { '.' } else { active.filename() }
	} else {
		referrer.filename()
	}
	base_directory := os.dir(base_filename)
	mut filename := lexical_absolute_path(base_directory, module_request.module_specifier.str())
	filename = resolve_module_filename(filename, module_type)
	if loaded_index := vm.get_stored_module(referrer, filename, module_type) {
		finish_loading_imported_module(referrer, module_request, payload, ModuleLoadResult.from_module(vm.loaded_modules[loaded_index].module_record))
		return
	}
	file_content := os.read_file(filename) or {
		finish_loading_imported_module(referrer, module_request, payload, ModuleLoadResult.from_error(vm.throw_error_type(.syntax_error,
			.module_not_found, module_request.module_specifier.str())))
		return
	}
	source_text := strip_utf8_byte_order_mark(file_content)
	realm := vm.current_realm() or { panic('HostLoadImportedModule requires a realm') }
	result := if module_type == 'json' {
		// If moduleRequest.[[Attributes]] has an entry entry such that entry.[[Key]] is "type" and entry.[[Value]] is "json",
		// when the host environment performs FinishLoadingImportedModule(referrer, moduleRequest, payload, result), result
		// must either be the Completion Record returned by an invocation of ParseJSONModule or a throw completion.
		json_module := vm.parse_json_module(mut vm, realm, source_text, filename) or {
			finish_loading_imported_module(referrer, module_request, payload, ModuleLoadResult.from_error(err))
			return
		}
		ModuleLoadResult.from_module(json_module)
	} else {
		// Note: We treat all files as module, so if a script does not have exports it just runs it.
		source_module := SourceTextModule.parse(source_text, realm, filename, unsafe { nil }) or {
			finish_loading_imported_module(referrer, module_request, payload, ModuleLoadResult.from_error(vm.throw_error(.syntax_error,
				err.msg())))
			return
		}
		ModuleLoadResult.from_module(Module(source_module))
	}
	if module_record := result.module_record {
		vm.loaded_modules << StoredModule{
			referrer:                 referrer
			filename:                 module_record.filename()
			module_record:                   module_record
			has_once_started_linking: true
		}
	}
	finish_loading_imported_module(referrer, module_request, payload, result)
}
