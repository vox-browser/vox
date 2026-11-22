module libjs

import dl
import strings

// An experimental baseline compiler, explicitly driven by the embedder after
// warmup. Cache entries contain code/layout only, never realm pointers or values.
// Dynamic operations retain the interpreter's semantics and exception machinery.
type NativeEntry = fn (voidptr, voidptr, &u64, u8, &u32, fn (voidptr, u32) u32, &u64)

@[heap]
struct NativeTier {
mut:
	profiling   bool = true
	enabled     bool
	observed    []&Executable
	indices     map[voidptr]int
	calls       []u64
	entries     map[voidptr]NativeEntry
	entry_cache []NativeEntryCacheSlot
	handle      voidptr
	stats       NativeCodeStats
	diagnostics bool
	activity    NativeCodeActivity
	persistent ?&NativeCodeCache
}

struct NativeCompiledLibrary {
	handle voidptr
	entries []NativeEntry
	stats NativeCodeStats
}

pub struct NativeCodeActivity {
pub mut:
	entries    u64
	fast_steps u64
	slow_steps u64
	function_environments_reused u64
	generated_string_hits u64
	argument_workspace_calls u64
	function_environments_allocated u64
	forwarded_call_slices u64
	direct_array_search_reads u64
	empty_binding_environments_skipped u64
	direct_accessor_gets u64
	direct_accessor_sets u64
	own_global_binding_reads u64
	compact_reference_reads u64
	direct_slow_steps u64
	global_binding_hint_hits u64
	entry_cache_hits u64
	specialized_property_steps u64
	specialized_object_property_steps u64
	native_length_steps u64
	native_index_steps u64
	binding_lookup_cache_hits u64
	binding_lookup_cache_misses u64
}

pub struct NativeCodeStats {
pub mut:
	observed_executables  int
	compiled_executables  int
	compiled_instructions int
	fast_instructions     int
	cache_hit             bool
	compile_ms            f64
	load_ms               f64
	library               string
	library_sha256        string
}

struct NativeInvocation {
	vm         &VM
	executable &Executable
	primitive_type_names voidptr
	property_read_step voidptr
	property_length_step voidptr
	property_index_step voidptr
mut:
	failure ?IError
	ended   bool
}

// Enable counters only in a separate eligibility diagnostic, outside timing.
pub fn (mut vm VM) diagnose_native_code(enabled bool) !NativeCodeActivity {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Cannot change native diagnostics during JavaScript execution')
	}
	mut tier := vm.native_tier or { return error('Native tier is not initialized') }
	tier.diagnostics = enabled
	mut previous := tier.activity
	$if test {
		bindings := diagnose_binding_lookup_for_testing(enabled)
		previous.binding_lookup_cache_hits = bindings.hits
		previous.binding_lookup_cache_misses = bindings.misses
	}
	tier.activity = NativeCodeActivity{}
	return previous
}

// Start counting cached executable entries. No code is compiled during warmup.
pub fn (mut vm VM) profile_native_code() ! {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Native profiling must begin outside JavaScript execution')
	}
	if vm.native_tier != none { return error('Native tier already initialized') }
	vm.ensure_native_type_names()
	vm.native_tier = &NativeTier{}
}

fn (mut tier NativeTier) observe(executable &Executable) {
	key := voidptr(executable)
	if index := tier.indices[key] {
		tier.calls[index]++
	} else {
		tier.indices[key] = tier.observed.len
		tier.observed << executable
		tier.calls << u64(1)
	}
}

// Explicitly load/compile a single native library for the warmup cohort. The
// directory is caller-owned executable storage, not a network/HTTP script cache.
// A failed compilation leaves ordinary interpreted execution available.
pub fn (mut vm VM) compile_native_code(directory string, compiler string, minimum_calls u64) !NativeCodeStats {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Native compilation must run outside JavaScript execution')
	}
	mut tier := vm.native_tier or { return error('Profile native code before compiling') }
	if tier.handle != unsafe { nil } { return error('Native code is already loaded') }
	tier.profiling = false
	mut selected := []&Executable{}
	for index, executable in tier.observed {
		if tier.calls[index] >= minimum_calls {
			executable.validate(0)!
			selected << executable
		}
	}
	if selected.len == 0 { return error('No warmed executables meet the native threshold') }
	compiled := native_compile_library(selected, directory, compiler)!
	mut entries := map[voidptr]NativeEntry{}
	for index, executable in selected { entries[voidptr(executable)] = compiled.entries[index] }
	tier.entries = entries.move()
	tier.entry_cache = []NativeEntryCacheSlot{}
	tier.handle = compiled.handle
	tier.stats = NativeCodeStats{...compiled.stats, observed_executables: tier.observed.len}
	tier.enabled = true
	return tier.stats
}

fn native_compile_library(selected []&Executable, directory string, compiler string) !NativeCompiledLibrary {
	$if prealloc {
		// Source builders, compiler diagnostics and library-hash input are batch
		// work, not VM state. Nothing in this synchronous operation mutates an
		// executable or retains V data outside its returned library record.
		scope := unsafe { prealloc_scope_begin() }
		defer { unsafe { prealloc_scope_free_after(scope) } }
		compiled := native_compile_library_in_workspace(selected, directory, compiler) or {
			unsafe { prealloc_scope_leave(scope) }
			message := err.msg().clone()
			return error_with_code(message, err.code())
		}
		// Keep the workspace alive while copying the small retained result into
		// the caller's arena. dlopen owns the machine code independently.
		unsafe { prealloc_scope_leave(scope) }
		return NativeCompiledLibrary{
			handle: compiled.handle
			entries: compiled.entries.clone()
			stats: NativeCodeStats{...compiled.stats,
				library: compiled.stats.library.clone()
				library_sha256: compiled.stats.library_sha256.clone()
			}
		}
	}
	return native_compile_library_in_workspace(selected, directory, compiler)
}

fn native_compile_library_in_workspace(selected []&Executable, directory string, compiler string) !NativeCompiledLibrary {
	build := prepare_native_library(selected, directory, compiler)!
	compile_ms := build.compile()!
	return build.load(compile_ms)
}

// Switch the same warmed VM between control and candidate without profiling or
// recompilation in the measured region. Code can only be unloaded while idle.
pub fn (mut vm VM) use_native_code(enabled bool) ! {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Cannot switch native code during JavaScript execution')
	}
	mut tier := vm.native_tier or { return error('Native tier is not initialized') }
	if enabled && tier.handle == unsafe { nil } && tier.persistent == none { return error('No native code loaded') }
	tier.enabled = enabled
}

pub fn (mut vm VM) close_native_code() ! {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Cannot unload native code during JavaScript execution')
	}
	if mut tier := vm.native_tier {
		tier.enabled = false
		if tier.handle != unsafe { nil } { dl.close(tier.handle) }
		if mut cache := tier.persistent {
			cache.release_background_batch()
			for _, library in cache.libraries { dl.close(library.handle) }
		}
	}
	vm.native_tier = none
}

fn native_slow_step(opaque voidptr, pc u32) u32 {
	mut invocation := unsafe { &NativeInvocation(opaque) }
	mut vm := invocation.vm
	if mut tier := vm.native_tier {
		if tier.diagnostics { tier.activity.slow_steps++ }
	}
	mut frame := vm.current_context()
	frame.program_counter = pc
	vm.consume_execution_budget() or {
		invocation.failure = err
		return 0xffffffff
	}
	instruction := &invocation.executable.instructions[pc]
	direct := use_native_dynamic_dispatch() && instruction.op in [.call, .construct, .super_construct, .get_property, .get_binding, .typeof_binding, .get_callee_and_this]
	if direct {
		if mut tier := vm.native_tier { if tier.diagnostics { tier.activity.direct_slow_steps++ } }
	}
	next := (if direct { vm.execute_native_dynamic(instruction, invocation.executable) }
		else { vm.execute_instruction(instruction, invocation.executable) }) or {
		if is_throw_completion(err) && vm.handle_exception(pc, thrown_value(err)) == .continue_in_this_executable {
			return frame.program_counter
		}
		invocation.failure = err
		return 0xffffffff
	}
	frame.program_counter = next
	if instruction.op in [.end, .await_value, .generator_start, .yield_value, .yield_iterator_result] {
		// These instructions return control to the caller even when their saved
		// resume PC is inside the executable. Returning that PC to generated C
		// would continue past await/yield before the VM has resumed the frame.
		invocation.ended = true
		return 0xffffffff
	}
	return next
}

fn native_slot(operand Operand, executable &Executable) !u32 {
	// Argument-count-dependent streams stay interpreted. Generated function
	// bodies access parameters through their environments in this VM.
	return operand.slot(executable, 0, false)
}

const native_fast_budget_check = 'if(limited) --*budget; if(fast_steps) ++*fast_steps;'

// Copy template spans directly into the translation unit. Both substitutions
// used to allocate intermediate copies of the entire instruction.
fn write_native_fast_step(mut output strings.Builder, template string, offset int) {
	mut cursor := 0
	mut slow := template.index_('SLOW')
	mut budget := template.index_('BUDGET')
	for slow >= 0 || budget >= 0 {
		replace_slow := slow >= 0 && (budget < 0 || slow < budget)
		marker := if replace_slow { slow } else { budget }
		unsafe { output.write_ptr(template.str + cursor, marker - cursor) }
		if replace_slow {
			output.write_byte(`S`)
			output.write_decimal(offset)
			cursor = slow + 'SLOW'.len
			slow = template.index_after_('SLOW', cursor)
		} else {
			output.write_string(native_fast_budget_check)
			cursor = budget + 'BUDGET'.len
			budget = template.index_after_('BUDGET', cursor)
		}
	}
	unsafe { output.write_ptr(template.str + cursor, template.len - cursor) }
	output.write_byte(`\n`)
}

fn native_source(executables []&Executable) !(string, int) {
	mut source := strings.new_builder(16384)
	sample := Value{}
	tag_offset := uint(&sample.tag) - uint(&sample)
	number_offset := uint(&sample.number) - uint(&sample)
	cell_offset := uint(&sample.cell) - uint(&sample)
	source.writeln('#include <stdint.h>\n#include <stddef.h>\n#include <math.h>')
	source.writeln('typedef struct { union { double number; void *cell; }; uint8_t tag; } NV;')
	source.writeln('_Static_assert(sizeof(NV)==${sizeof(Value)}, "Value size");')
	source.writeln('_Static_assert(offsetof(NV,tag)==${tag_offset} && offsetof(NV,number)==${number_offset} && offsetof(NV,cell)==${cell_offset}, "Value offsets");')
	source.writeln('typedef uint32_t (*Slow)(void*,uint32_t);')
	source.writeln('static int number(NV v) { return v.tag==${int(ValueTag.int32)} || v.tag==${int(ValueTag.double)}; }')
	source.writeln('static NV num(double x) { NV v={.number=x,.tag=${int(ValueTag.double)}}; if(x>=-2147483648.0 && x<=2147483647.0 && x==(int32_t)x && !(x==0 && signbit(x))) v.tag=${int(ValueTag.int32)}; return v; }')
	source.writeln('static NV boolean(int x) { NV v={.number=!!x,.tag=${int(ValueTag.boolean)}}; return v; }')
	source.writeln(native_primitive_helpers())
	source.writeln(native_property_helpers())
	source.writeln(native_length_helpers())
	source.writeln(native_index_helpers())
	mut fast_count := 0
	for index, executable in executables {
		mut has_properties := false
		for offset, instruction in executable.instructions {
			if _ := native_property_plan(instruction, executable, u32(offset)) { has_properties = true; break }
		}
		property_reader := if has_properties { 'PropertyRead property=property_reader(state);' } else { '' }
		source.writeln('void vox_native_${index}(void *state,NV *v,uint64_t *budget,uint8_t limited,uint32_t *pc,Slow slow,uint64_t *fast_steps) { uint32_t next=*pc; ${property_reader} goto dispatch;')
		for offset, instruction in executable.instructions {
			length_fast := native_length_instruction(instruction, executable, u32(offset))
			index_fast := native_index_instruction(instruction, executable, u32(offset))
			fast := if length_fast != '' { length_fast } else if index_fast != '' { index_fast } else { native_fast_instruction(instruction, executable)! }
			source.writeln('L${offset}:;')
			if fast != '' {
				fast_count++
				// Budget is shared with all nested calls. An exhausted budget is
				// reported by the ordinary VM path at precisely this instruction.
				source.writeln('if(limited && !*budget) goto S${offset};')
				// Guards precede decrement so a slow exit consumes exactly once.
				write_native_fast_step(mut source, fast, offset)
				if instruction.op == .jump {
					source.writeln('goto L${instruction.target};')
				} else if instruction.op == .end {
					source.writeln('*pc=0xfffffffe; return;')
				} else {
					source.writeln('goto L${offset + 1};')
				}
			}
			source.writeln('S${offset}:;')
			if plan := native_property_plan(instruction, executable, u32(offset)) {
				source.writeln('if(property) { static const uint32_t plan[]={${plan}}; *pc=${offset}; next=property(state,(void*)plan); if(next==${offset + 1}) goto L${offset + 1}; goto dispatch; }')
			}
			source.writeln('*pc=${offset}; next=slow(state,${offset});')
			source.writeln('if(next==${offset + 1}) goto L${offset + 1}; goto dispatch;')
		}
		source.writeln('L${executable.bytecode_length}: *pc=${executable.bytecode_length}; return;')
		source.writeln('dispatch: switch(next) {')
		for offset in 0 .. executable.instructions.len {
			source.writeln('case ${offset}: goto L${offset};')
		}
		// The slow callback leaves the throwing PC installed for source maps
		// and the queued jobs run while unwinding. Its exit marker is not a PC.
		source.writeln('case 0xffffffff: return; default: *pc=next; return; } }')
	}
	return source.str(), fast_count
}

fn native_fast_instruction(instruction Instruction, executable &Executable) !string {
	if instruction.op in [.jump, .nop] { return 'BUDGET' }
	if instruction.op !in [.mov, .end, .jump_if_true, .jump_if_false, .jump_if_nullish, .add, .sub,
		.mul, .div, .less_than, .less_than_equals, .greater_than, .greater_than_equals, .strict_equals,
		.strict_inequals, .loose_equals, .loose_inequals, .increment, .decrement, .to_numeric, .unary_plus, .unary_minus, .not_op, .typeof_op] {
		return ''
	}
	if instruction.op == .typeof_op && !use_native_primitive_ops() { return '' }
	lhs := native_slot(instruction.lhs, executable)!
	left := 'v[${lhs}]'
	mut code := 'if(${left}.tag==${int(ValueTag.empty)}) goto SLOW;\n'
	if instruction.op == .typeof_op {
		return code + '{ void *type_name=primitive_typeof(state,${left}); if(!type_name) goto SLOW; BUDGET v[${native_slot(instruction.dst, executable)!}]=(NV){.cell=type_name,.tag=${int(ValueTag.string)}}; }'
	}
	if instruction.op == .end {
		return code + 'BUDGET v[${register_return_value}]=${left}; v[${register_exception}]=(NV){.tag=${int(ValueTag.empty)}};'
	}
	if instruction.op == .mov {
		return code + 'BUDGET v[${native_slot(instruction.dst, executable)!}]=${left};'
	}
	if instruction.op == .jump_if_nullish {
		return code + 'BUDGET if(${left}.tag==${int(ValueTag.undefined)} || ${left}.tag==${int(ValueTag.null)}) goto L${instruction.target};'
	}
	if instruction.op in [.jump_if_true, .jump_if_false, .not_op] {
		if use_native_primitive_ops() {
			code += 'if(${left}.tag==${int(ValueTag.bigint)}) goto SLOW;\n'
		} else {
			code += 'if(${left}.tag==${int(ValueTag.string)} || ${left}.tag==${int(ValueTag.bigint)}) goto SLOW;\n'
		}
		string_truth := if use_native_primitive_ops() { '(${left}.tag==${int(ValueTag.string)} && string_length(${left})!=0) || ' } else { '' }
		truth := '(${string_truth}${left}.tag==${int(ValueTag.object)} || ${left}.tag==${int(ValueTag.symbol)} || ${left}.tag==${int(ValueTag.accessor)} || ((${left}.tag==${int(ValueTag.boolean)} || number(${left})) && ${left}.number!=0 && ${left}.number==${left}.number))'
		if instruction.op == .not_op {
			return code + 'BUDGET v[${native_slot(instruction.dst, executable)!}]=boolean(!${truth});'
		}
		return code + 'BUDGET if(${if instruction.op == .jump_if_false { '!' } else { '' }}${truth}) goto L${instruction.target};'
	}
	if instruction.op in [.strict_equals, .strict_inequals, .loose_equals, .loose_inequals] {
		if use_native_primitive_ops() { return code + native_primitive_equality(instruction, executable, left)! }
		if instruction.op in [.loose_equals, .loose_inequals] { return '' }
	}
	dst := native_slot(instruction.dst, executable)!
	code += 'if(!number(${left})) goto SLOW;\n'
	if instruction.op in [.increment, .decrement, .to_numeric, .unary_plus, .unary_minus] {
		value := match instruction.op {
			.increment { '${left}.number+1' }
			.decrement { '${left}.number-1' }
			.unary_minus { '-${left}.number' }
			else { '${left}.number' }
		}
		return code + 'BUDGET v[${dst}]=num(${value});'
	}
	rhs := native_slot(instruction.rhs, executable)!
	right := 'v[${rhs}]'
	code += 'if(!number(${right})) goto SLOW;\n'
	op := match instruction.op {
		.add { '+' }
		.sub { '-' }
		.mul { '*' }
		.div { '/' }
		.less_than { '<' }
		.less_than_equals { '<=' }
		.greater_than { '>' }
		.greater_than_equals { '>=' }
		.strict_equals { '==' }
		else { '!=' }
	}
	wrap := if instruction.op in [.add, .sub, .mul, .div] { 'num' } else { 'boolean' }
	return code + 'BUDGET v[${dst}]=${wrap}(${left}.number ${op} ${right}.number);'
}
