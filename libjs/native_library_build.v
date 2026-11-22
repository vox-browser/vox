module libjs

import crypto.rand
import dl
import os
import time

struct NativeLibraryBuild {
	compiler string
	job      string
	stats    NativeCodeStats
}

// Snapshot the only input the compiler needs while the VM owns the bytecode.
// The compiler can use this source file without borrowing anything from the VM.
fn prepare_native_library(selected []&Executable, directory string, compiler string) !NativeLibraryBuild {
	source, fast_count := native_source(selected)!
	// The generated ABI, opcodes, target and optimization flags are part of the
	// key. No function pointer or process-specific payload is embedded in the file.
	key := native_cache_digest_string('libjs-native-v1:${os.user_os()}:${os.uname().machine}:O2:no-strict-aliasing:' + source)
	os.mkdir_all(directory)!
	root := os.real_path(directory)
	library := os.join_path(root, key + dl.dl_ext)
	mut stats := NativeCodeStats{
		compiled_executables: selected.len
		fast_instructions:    fast_count
		cache_hit:            os.is_file(library)
		library:              library
	}
	for executable in selected {
		stats.compiled_instructions += executable.instructions.len
	}
	if stats.cache_hit {
		return NativeLibraryBuild{ stats: stats }
	}
	job := os.join_path(root, '.compile-' + rand.bytes(16)!.hex())
	os.mkdir(job)!
	os.write_file(os.join_path(job, 'code.c'), source) or {
		os.rmdir_all(job) or {}
		return err
	}
	return NativeLibraryBuild{
		compiler: compiler
		job:      job
		stats:    stats
	}
}

fn (build &NativeLibraryBuild) discard() {
	if build.job != '' { os.rmdir_all(build.job) or {} }
}

fn (build &NativeLibraryBuild) compile() !f64 {
	if build.job == '' { return 0 }
	defer { build.discard() }
	started := time.sys_mono_now()
	input := os.join_path(build.job, 'code.c')
	output := os.join_path(build.job, 'code' + dl.dl_ext)
	mut args := [build.compiler, '-O2', '-std=c11', '-fno-strict-aliasing']
	$if macos {
		args << '-dynamiclib'
	} $else {
		args << ['-shared', '-fPIC']
	}
	args << [input, '-o', output]
	// Capture both output streams together. Reading only stderr can leave the
	// child blocked writing stdout while the parent is waiting for EOF.
	result := os.exec(args)
	if result.exit_code != 0 {
		return error('Native compiler exited ${result.exit_code}: ${result.output}')
	}
	os.mv(output, build.stats.library)!
	return f64(time.sys_mono_now() - started) / 1e6
}

fn (build &NativeLibraryBuild) load(compile_ms f64) !NativeCompiledLibrary {
	mut stats := build.stats
	library := stats.library
	stats.compile_ms = compile_ms
	stats.library_sha256 = native_cache_digest_string(os.read_file(library)!)
	started := time.sys_mono_now()
	handle := dl.open_opt(library, dl.rtld_now | dl.rtld_local)!
	mut entries := []NativeEntry{cap: stats.compiled_executables}
	for index in 0 .. stats.compiled_executables {
		symbol := dl.sym_opt(handle, 'vox_native_${index}') or {
			dl.close(handle)
			return err
		}
		entries << unsafe { NativeEntry(symbol) }
	}
	stats.load_ms = f64(time.sys_mono_now() - started) / 1e6
	return NativeCompiledLibrary{handle: handle, entries: entries, stats: stats}
}
