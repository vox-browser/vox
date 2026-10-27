module adblock

import os
import time

fn test_default_self_worker_configuration_keeps_engine_startup_lazy() {
	_ = release_unused_engine()
	defer {
		_ = release_unused_engine()
		configure_default_worker_with_deadline(os.getenv('VOX_ADBLOCK_WORKER_HELPER'), 15000) or {
			panic(err)
		}
	}
	configure_default_self_worker()!
	assert C.vox_adblock_worker_is_configured() == 1
	assert default_worker_pid() == 0
	assert C.vox_adblock_get_context() == unsafe { nil }
}

fn test_bundled_worker_requires_an_executable_file_inside_the_browser_bundle() {
	root := os.join_path(os.temp_dir(), 'vox bundled worker ${os.getpid()} ${time.sys_mono_now()}')
	directory := os.join_path(root, 'Renamed Vox.app', 'Contents', 'MacOS')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(root) or {} }
	executable := os.join_path(directory, 'Vox')
	helper := os.join_path(directory, 'VoxAdblockWorker')
	assert default_self_worker_path(executable) == executable
	os.write_file(helper, '')!
	os.chmod(helper, 0o644)!
	assert default_self_worker_path(executable) == executable
	os.chmod(helper, 0o755)!
	assert default_self_worker_path(executable) == helper
	os.rm(helper)!
	os.mkdir(helper)!
	assert default_self_worker_path(executable) == executable
}

fn test_standalone_worker_capable_executables_keep_their_own_image() {
	root := os.join_path(os.temp_dir(), 'vox standalone worker ${os.getpid()} ${time.sys_mono_now()}')
	os.mkdir_all(root)!
	defer { os.rmdir_all(root) or {} }
	helper := os.join_path(root, 'VoxAdblockWorker')
	os.write_file(helper, '')!
	os.chmod(helper, 0o755)!
	for name in ['Vox', 'helper', 'other.app/Contents/MacOS/other'] {
		executable := os.join_path(root, name)
		assert default_self_worker_path(executable) == executable
	}
}
