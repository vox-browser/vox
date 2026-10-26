module browserjs

import os
import platform
import time

fn worker_process_test_helper() !(string, string) {
	if executable := os.getenv_opt('VOX_WORKER_TEST_HELPER') {
		if !os.is_file(executable) { return error('Missing configured worker test helper') }
		return executable, ''
	}
	directory := os.join_path(os.temp_dir(), 'vox-worker-process-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir(directory, mode: 0o700)!
	mut completed := false
	defer { if !completed { os.rmdir_all(directory) or {} } }
	executable := os.join_path(directory, 'helper')
	mut arguments := ['-std=c11', '-O1', '-pthread',
		os.join_path(os.dir(@FILE), '..', 'tools', 'native_worker_process_test.c'), '-o', executable]
	$if darwin {
		arguments << ['-framework', 'JavaScriptCore']
	} $else $if linux {
		mut pkgconfig := os.new_process('pkg-config')
		pkgconfig.set_args(['--cflags', '--libs', 'javascriptcoregtk-4.1'])
		pkgconfig.set_redirect_stdio()
		pkgconfig.run()
		flags := pkgconfig.stdout_read()
		pkgconfig.wait()
		pkgconfig.close()
		if pkgconfig.code != 0 { return error('Cannot locate JavaScriptCoreGTK for worker test') }
		arguments << flags.fields()
	}
	mut compiler := os.new_process('clang')
	compiler.set_args(arguments)
	compiler.run()
	compiler.wait()
	compiler.close()
	if compiler.code != 0 {
		return error('Cannot compile native worker test helper')
	}
	completed = true
	return executable, directory
}

fn worker_process_test_read(process &WorkerProcess) !WorkerProcessFrame {
	deadline := time.sys_mono_now() + 5 * time.second
	for time.sys_mono_now() < deadline {
		process.flush()!
		read := process.receive()!
		if read.ended { return error('Worker helper ended before expected frame') }
		if frame := read.frame { return frame }
		process.wait(10)!
	}
	return error('Worker helper frame deadline')
}

fn test_worker_process_runs_an_isolated_engine_and_retains_binary_frames_across_scratch_resets() {
	executable, directory := worker_process_test_helper()!
	defer { if directory != '' { os.rmdir_all(directory) or {} } }
	mut caller := platform.begin_thread_scratch('worker caller')
	mut process := WorkerProcess.spawn(executable)!
	process.queue(2, 'globalThis.workerValue=40;workerValue+2'.bytes())!
	caller.finish()
	defer { process.close() }
	assert worker_process_test_read(process)!.kind == 1
	answer := worker_process_test_read(process)!
	assert answer.kind == 3 && answer.bytes.bytestr() == '42'
	mut sender := platform.begin_thread_scratch('worker sender')
	mut message := [u8(0), 255, 128, 65]
	process.queue(4, message)!
	message[0] = 9
	sender.finish()
	mut receiver := platform.begin_thread_scratch('worker receiver')
	frame := worker_process_test_read(process)!
	receiver.finish()
	assert frame.kind == 4 && frame.bytes == [u8(0), 255, 128, 65]
	process.queue(2, 'workerValue+3'.bytes())!
	assert worker_process_test_read(process)!.bytes.bytestr() == '43'
	process.close()
	process.close()
	if _ := process.queue(4, []) {
		assert false
	}
	if _ := process.flush() {
		assert false
	}
	if _ := process.receive() {
		assert false
	}
	if _ := process.wait(0) {
		assert false
	}
}

fn test_worker_process_rejects_invalid_paths_roles_and_timeouts() {
	if _ := WorkerProcess.spawn('/missing/vox-worker') {
		assert false
	}
	if _ := WorkerProcess.spawn('') {
		assert false
	}
	if _ := WorkerProcess.spawn('/tmp/vox\x00ignored') {
		assert false
	}
	if _ := WorkerProcess.begin_child() {
		assert false
	}
	executable, directory := worker_process_test_helper()!
	defer { if directory != '' { os.rmdir_all(directory) or {} } }
	mut process := WorkerProcess.spawn(executable)!
	defer { process.close() }
	if _ := process.wait(-1) {
		assert false
	}
	if _ := process.wait(2147483648) {
		assert false
	}
	if _ := process.queue(0, []) {
		assert false
	}
	assert worker_process_test_read(process)!.kind == 1
}
