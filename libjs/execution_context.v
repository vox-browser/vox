module libjs

// Translated from LibJS/Runtime/ExecutionContext.{h,cpp}. Upstream places the
// value tail directly after the record in memory; here `values` holds the same
// [registers | locals | constants | arguments] layout.

pub enum ScriptOrModuleKind {
	empty
	script
	module
}

// ScriptOrModule = Variant<Empty, GC::Ref<Script>, GC::Ref<Module>>
pub struct ScriptOrModule {
pub:
	kind   ScriptOrModuleKind = .empty
	script ?&Script
	module_record ?Module
}

pub fn ScriptOrModule.from_script(script &Script) ScriptOrModule {
	return ScriptOrModule{
		kind:   .script
		script: script
	}
}

pub fn ScriptOrModule.from_module(module_record Module) ScriptOrModule {
	return ScriptOrModule{
		kind:   .module
		module_record: module_record
	}
}

pub fn (script_or_module ScriptOrModule) is_empty() bool {
	return script_or_module.kind == .empty
}

pub fn (script_or_module ScriptOrModule) filename() string {
	return match script_or_module.kind {
		.empty { '' }
		.script { (script_or_module.script or { panic('script record missing') }).filename }
		.module { (script_or_module.module_record or { panic('module record missing') }).filename() }
	}
}

// LibJS/Bytecode/Register.h
pub const register_accumulator = u32(0)
pub const register_exception = u32(1)
pub const register_this_value = u32(2)
pub const register_return_value = u32(3)
pub const register_saved_lexical_environment = u32(4)
pub const reserved_register_count = u32(5)

// UINT32_MAX means "no continuation" (generator is done).
pub const no_yield_continuation = u32(0xFFFFFFFF)

// 9.4 Execution Contexts, https://tc39.es/ecma262/#sec-execution-contexts
@[heap]
pub struct ExecutionContext {
pub mut:
	function            ?FunctionObject     // [[Function]]
	realm               ?&Realm             // [[Realm]]
	script_or_module    ScriptOrModule      // [[ScriptOrModule]]
	lexical_environment ?Environment        // [[LexicalEnvironment]]
	variable_environment ?Environment       // [[VariableEnvironment]]
	private_environment ?&PrivateEnvironment // [[PrivateEnvironment]]

	frame_id        u64
	program_counter u32

	// https://html.spec.whatwg.org/multipage/webappapis.html#skip-when-determining-incumbent-counter
	skip_when_determining_incumbent_counter u32

	// Non-standard: generators and async generators report yield/await state to
	// the caller without allocating a GC cell.
	yield_continuation             u32 = no_yield_continuation
	yield_is_await                 bool
	yield_value_is_iterator_result bool
	caller_is_construct            bool
	frame_initialized              bool

	this_value ?Value
	executable ?&Executable

	// Non-standard: inline frame linkage for the bytecode interpreter. Only
	// inline JS-to-JS calls use these fields.
	caller_frame          ?&ExecutionContext
	passed_argument_count u32
	caller_return_pc      u32
	caller_dst_raw        u32

	// [registers | locals | constants | arguments]
	values         []Value
	argument_count u32

	// InterpreterStack bookkeeping: the byte offset of this frame on the stack.
	stack_offset    uint
	stack_allocated bool
}

// ExecutionContextAllocator rounds the value tail up to a size class so freed
// frames can be reused.
fn tail_allocation_size(tail_size int) int {
	if tail_size <= 4 {
		return 4
	}
	if tail_size <= 16 {
		return 16
	}
	if tail_size <= 64 {
		return 64
	}
	if tail_size <= 128 {
		return 128
	}
	if tail_size <= 256 {
		return 256
	}
	if tail_size <= 512 {
		return 512
	}
	return tail_size
}

pub fn ExecutionContext.create(registers_and_locals_count u32, constants []Value, arguments_count u32) &ExecutionContext {
	total := u64(registers_and_locals_count) + u64(constants.len) + u64(arguments_count)
	if total > u64(0xFFFFFFFF) {
		panic('ExecutionContext.create: value tail overflows u32')
	}
	mut values := []Value{len: int(total), cap: tail_allocation_size(int(total))}
	// NB: Enter initializes the remaining registers and locals; the reserved
	//     registers start out as the special empty value.
	reserved := if registers_and_locals_count < reserved_register_count {
		registers_and_locals_count
	} else {
		reserved_register_count
	}
	for index in 0 .. int(reserved) {
		values[index] = js_special_empty_value()
	}
	for index, constant in constants {
		values[int(registers_and_locals_count) + index] = constant
	}
	return &ExecutionContext{
		values:         values
		argument_count: arguments_count
	}
}

pub fn (context &ExecutionContext) registers_and_constants_and_locals_and_arguments_count() u32 {
	return u32(context.values.len)
}

pub fn (context &ExecutionContext) argument(index u32) Value {
	if index >= context.argument_count {
		return js_undefined()
	}
	return context.values[context.arguments_offset() + int(index)]
}

fn (context &ExecutionContext) arguments_offset() int {
	return context.values.len - int(context.argument_count)
}

pub fn (context &ExecutionContext) arguments() []Value {
	return context.values[context.arguments_offset()..]
}

pub fn (mut context ExecutionContext) set_argument(index u32, value Value) {
	if index >= context.argument_count {
		panic('set_argument: index ${index} is out of range for ${context.argument_count} arguments')
	}
	context.values[context.arguments_offset() + int(index)] = value
}

pub fn (context &ExecutionContext) local_variables() []Value {
	executable := context.executable or { panic('local_variables() requires an executable') }
	start := int(executable.local_index_base)
	return context.values[start..start + executable.local_variable_names.len]
}

pub fn (context &ExecutionContext) copy() &ExecutionContext {
	// NB: The entire non-argument count is passed as registers_and_locals_count with 0 constants.
	non_argument_count := u32(context.values.len) - context.argument_count
	mut duplicate := ExecutionContext.create(non_argument_count, []Value{}, context.argument_count)
	duplicate.function = context.function
	duplicate.realm = context.realm
	duplicate.script_or_module = context.script_or_module
	duplicate.lexical_environment = context.lexical_environment
	duplicate.variable_environment = context.variable_environment
	duplicate.private_environment = context.private_environment
	duplicate.program_counter = context.program_counter
	duplicate.frame_id = context.frame_id
	duplicate.yield_continuation = context.yield_continuation
	duplicate.yield_is_await = context.yield_is_await
	duplicate.yield_value_is_iterator_result = context.yield_value_is_iterator_result
	duplicate.caller_is_construct = context.caller_is_construct
	duplicate.frame_initialized = context.frame_initialized
	duplicate.this_value = context.this_value
	duplicate.executable = context.executable
	duplicate.passed_argument_count = context.passed_argument_count
	for index in 0 .. context.values.len {
		if !context.frame_initialized && index >= int(reserved_register_count)
			&& index < int(non_argument_count) {
			continue
		}
		duplicate.values[index] = context.values[index]
	}
	duplicate.argument_count = context.argument_count
	return duplicate
}

// ExecutionContext::visit_edges: report the cells this frame keeps alive.
pub fn (context &ExecutionContext) visit_roots(mut roots HeapRoots) {
	if function := context.function {
		roots.add(function_object_identity(function))
	}
	if realm := context.realm {
		roots.add(voidptr(realm))
	}
	if environment := context.variable_environment {
		roots.add(environment_identity(environment))
	}
	if environment := context.lexical_environment {
		roots.add(environment_identity(environment))
	}
	if private_environment := context.private_environment {
		roots.add(voidptr(private_environment))
	}
	if this_value := context.this_value {
		roots.add_value(this_value)
	}
	if executable := context.executable {
		roots.add(voidptr(executable))
	}
	if context.frame_initialized {
		for value in context.values {
			roots.add_value(value)
		}
	} else {
		// NB: Call setup can trigger GC before Enter initializes the frame.
		//     Only the reserved registers and arguments are live at that point.
		non_argument_count := context.values.len - int(context.argument_count)
		live_registers := if non_argument_count < int(reserved_register_count) {
			non_argument_count
		} else {
			int(reserved_register_count)
		}
		for index in 0 .. live_registers {
			roots.add_value(context.values[index])
		}
		for value in context.arguments() {
			roots.add_value(value)
		}
	}
	match context.script_or_module.kind {
		.script {
			if script := context.script_or_module.script {
				roots.add(voidptr(script))
			}
		}
		.module {
			if module_record := context.script_or_module.module_record {
				roots.add(module_identity(module_record))
			}
		}
		.empty {}
	}
}
