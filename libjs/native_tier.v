module libjs

import crypto.sha256
import dl
import os
import strings
import time
import rand

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
	handle      voidptr
	stats       NativeCodeStats
	diagnostics bool
	activity    NativeCodeActivity
}

pub struct NativeCodeActivity {
pub mut:
	entries    u64
	fast_steps u64
	slow_steps u64
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
	previous := tier.activity
	tier.activity = NativeCodeActivity{}
	return previous
}

// Start counting cached executable entries. No code is compiled during warmup.
pub fn (mut vm VM) profile_native_code() ! {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Native profiling must begin outside JavaScript execution')
	}
	if vm.native_tier != none { return error('Native tier already initialized') }
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
	source, fast_count := native_source(selected)!
	// The generated ABI, opcodes, target and optimization flags are part of the
	// key. No function pointer or process-specific payload is embedded in the file.
	key := sha256.hexhash('libjs-native-v1:${os.user_os()}:${os.uname().machine}:O2:no-strict-aliasing:' + source)
	os.mkdir_all(directory)!
	library := os.join_path(os.real_path(directory), key + dl.dl_ext)
	mut stats := NativeCodeStats{
		observed_executables: tier.observed.len
		compiled_executables: selected.len
		fast_instructions:    fast_count
		cache_hit:            os.is_file(library)
		library:              library
	}
	for executable in selected { stats.compiled_instructions += executable.instructions.len }
	if !stats.cache_hit {
		started := time.sys_mono_now()
		// Generate outside Build/; only the final binary survives compilation.
		job := os.join_path(os.real_path(directory), '.compile-' + rand.uuid_v4())
		os.mkdir(job)!
		defer { os.rmdir_all(job) or {} }
		input := os.join_path(job, 'code.c')
		output := os.join_path(job, 'code' + dl.dl_ext)
		os.write_file(input, source)!
		mut process := os.new_process(compiler)
		mut args := ['-O2', '-std=c11', '-fno-strict-aliasing']
		$if macos {
			args << '-dynamiclib'
		} $else {
			args << ['-shared', '-fPIC']
		}
		args << [input, '-o', output]
		process.set_args(args)
		process.set_redirect_stdio()
		process.run()
		diagnostic := process.stderr_slurp()
		process.wait()
		code := process.code
		process.close()
		if code != 0 { return error('Native compiler exited ${code}: ${diagnostic}') }
		os.mv(output, library)!
		stats.compile_ms = f64(time.sys_mono_now() - started) / 1e6
	}
	started := time.sys_mono_now()
	handle := dl.open_opt(library, dl.rtld_now | dl.rtld_local)!
	mut entries := map[voidptr]NativeEntry{}
	for index, executable in selected {
		symbol := dl.sym_opt(handle, 'vox_native_${index}') or {
			dl.close(handle)
			return err
		}
		entries[voidptr(executable)] = unsafe { NativeEntry(symbol) }
	}
	stats.load_ms = f64(time.sys_mono_now() - started) / 1e6
	stats.library_sha256 = sha256.hexhash(os.read_file(library)!)
	tier.entries = entries.move()
	tier.handle = handle
	tier.stats = stats
	tier.enabled = true
	return stats
}

// Switch the same warmed VM between control and candidate without profiling or
// recompilation in the measured region. Code can only be unloaded while idle.
pub fn (mut vm VM) use_native_code(enabled bool) ! {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Cannot switch native code during JavaScript execution')
	}
	mut tier := vm.native_tier or { return error('Native tier is not initialized') }
	if enabled && tier.handle == unsafe { nil } { return error('No native code loaded') }
	tier.enabled = enabled
}

pub fn (mut vm VM) close_native_code() ! {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Cannot unload native code during JavaScript execution')
	}
	if mut tier := vm.native_tier {
		tier.enabled = false
		if tier.handle != unsafe { nil } { dl.close(tier.handle) }
	}
	vm.native_tier = none
}

fn native_slow_step(opaque voidptr, pc u32) u32 {
	mut invocation := unsafe { &NativeInvocation(opaque) }
	mut vm := invocation.vm
	if mut tier := vm.native_tier {
		if tier.diagnostics { tier.activity.slow_steps++ }
	}
	mut frame := vm.running_execution_context()
	frame.program_counter = pc
	vm.consume_execution_budget() or {
		invocation.failure = err
		return 0xffffffff
	}
	instruction := invocation.executable.instructions[pc]
	next := vm.execute_instruction(instruction, invocation.executable) or {
		if is_throw_completion(err) && vm.handle_exception(pc, thrown_value(err)) == .continue_in_this_executable {
			return frame.program_counter
		}
		invocation.failure = err
		return 0xffffffff
	}
	frame.program_counter = next
	if instruction.op == .end { invocation.ended = true }
	return next
}

fn native_slot(operand Operand, executable &Executable) !u32 {
	// Argument-count-dependent streams stay interpreted. Generated function
	// bodies access parameters through their environments in this VM.
	return operand.slot(executable, 0, false)
}

fn native_source(executables []&Executable) !(string, int) {
	mut source := strings.new_builder(16384)
	sample := Value{}
	number_offset := uint(&sample.number) - uint(&sample)
	cell_offset := uint(&sample.cell) - uint(&sample)
	source.writeln('#include <stdint.h>\n#include <stddef.h>\n#include <math.h>')
	source.writeln('typedef struct { uint8_t tag; double number; void *cell; } NV;')
	source.writeln('_Static_assert(sizeof(NV)==${sizeof(Value)}, "Value size");')
	source.writeln('_Static_assert(offsetof(NV,number)==${number_offset} && offsetof(NV,cell)==${cell_offset}, "Value offsets");')
	source.writeln('typedef uint32_t (*Slow)(void*,uint32_t);')
	source.writeln('static int number(NV v) { return v.tag==${int(ValueTag.int32)} || v.tag==${int(ValueTag.double)}; }')
	source.writeln('static NV num(double x) { NV v={${int(ValueTag.double)},x,0}; if(x>=-2147483648.0 && x<=2147483647.0 && x==(int32_t)x && !(x==0 && signbit(x))) v.tag=${int(ValueTag.int32)}; return v; }')
	source.writeln('static NV boolean(int x) { NV v={${int(ValueTag.boolean)},!!x,0}; return v; }')
	mut fast_count := 0
	for index, executable in executables {
		source.writeln('void vox_native_${index}(void *state,NV *v,uint64_t *budget,uint8_t limited,uint32_t *pc,Slow slow,uint64_t *fast_steps) { uint32_t next=*pc; goto dispatch;')
		for offset, instruction in executable.instructions {
			fast := native_fast_instruction(instruction, executable)!
			source.writeln('L${offset}:;')
			if fast != '' {
				fast_count++
				// Budget is shared with all nested calls. An exhausted budget is
				// reported by the ordinary VM path at precisely this instruction.
				source.writeln('if(limited && !*budget) goto S${offset};')
				// Guards precede decrement so a slow exit consumes exactly once.
				source.writeln(fast.replace('SLOW', 'S${offset}').replace('BUDGET', 'if(limited) --*budget; if(fast_steps) ++*fast_steps;'))
				if instruction.op == .jump {
					source.writeln('goto L${instruction.target};')
				} else if instruction.op == .end {
					source.writeln('*pc=0xfffffffe; return;')
				} else {
					source.writeln('goto L${offset + 1};')
				}
			}
			source.writeln('S${offset}: *pc=${offset}; next=slow(state,${offset});')
			source.writeln('if(next==${offset + 1}) goto L${offset + 1}; goto dispatch;')
		}
		source.writeln('L${executable.bytecode_length}: *pc=${executable.bytecode_length}; return;')
		source.writeln('dispatch: switch(next) {')
		for offset in 0 .. executable.instructions.len {
			source.writeln('case ${offset}: goto L${offset};')
		}
		source.writeln('default: *pc=next; return; } }')
	}
	return source.str(), fast_count
}

fn native_fast_instruction(instruction Instruction, executable &Executable) !string {
	if instruction.op == .jump { return 'BUDGET' }
	if instruction.op !in [.mov, .end, .jump_if_true, .jump_if_false, .jump_if_nullish, .add, .sub,
		.mul, .div, .less_than, .less_than_equals, .greater_than, .greater_than_equals, .strict_equals,
		.strict_inequals, .increment, .decrement, .to_numeric, .unary_plus, .unary_minus, .not_op] {
		return ''
	}
	lhs := native_slot(instruction.lhs, executable)!
	left := 'v[${lhs}]'
	mut code := 'if(${left}.tag==${int(ValueTag.empty)}) goto SLOW;\n'
	if instruction.op == .end {
		return code + 'BUDGET v[${register_return_value}]=${left}; v[${register_exception}]=(NV){${int(ValueTag.empty)},0,0};'
	}
	if instruction.op == .mov {
		return code + 'BUDGET v[${native_slot(instruction.dst, executable)!}]=${left};'
	}
	if instruction.op == .jump_if_nullish {
		return code + 'BUDGET if(${left}.tag==${int(ValueTag.undefined)} || ${left}.tag==${int(ValueTag.null)}) goto L${instruction.target};'
	}
	if instruction.op in [.jump_if_true, .jump_if_false, .not_op] {
		// Strings and BigInts need their existing truthiness implementation.
		code += 'if(${left}.tag==${int(ValueTag.string)} || ${left}.tag==${int(ValueTag.bigint)}) goto SLOW;\n'
		truth := '(${left}.tag==${int(ValueTag.object)} || ${left}.tag==${int(ValueTag.symbol)} || ${left}.tag==${int(ValueTag.accessor)} || ((${left}.tag==${int(ValueTag.boolean)} || number(${left})) && ${left}.number!=0 && ${left}.number==${left}.number))'
		if instruction.op == .not_op {
			return code + 'BUDGET v[${native_slot(instruction.dst, executable)!}]=boolean(!${truth});'
		}
		return code + 'BUDGET if(${if instruction.op == .jump_if_false { '!' } else { '' }}${truth}) goto L${instruction.target};'
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
