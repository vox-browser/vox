module main

import os

fn test_native_tool_forwards_exact_caller_vexe_to_guarded_child() ! {
	tool := os.getenv('VOX_BUILD_TEST_TOOL')
	if tool == '' { return }
	assert os.is_file(tool)
	root := make_temp_directory(os.temp_dir(), 'vox-build-environment-test-')!
	defer { os.rmdir_all(root) or {} }
	for name in ['unset', 'explicit', 'empty'] {
		mut environment := os.environ()
		environment['VOX_BUILD_ROOT'] = root
		environment['VOX_BUILD_TOOL'] = tool
		value := if name == 'explicit' { r'/caller/compiler with spaces/$literal' } else { '' }
		if name == 'unset' { environment.delete('VEXE') } else { environment['VEXE'] = value }
		output := os.join_path(root, name + '.txt')
		log := os.join_path(root, name + '.log')
		// Invoke the immutable binary directly, without the shell bootstrap.
		mut child := spawn_build_child([tool, 'memory', '--report', os.join_path(root, name + '.json'),
			'--lock', os.join_path(root, 'guard.lock'), '--timeout', '5', '--', 'sh', '-c',
			r'printf "%s\n%s" "${VEXE+x}" "${VEXE-}" > "$1"', 'vexe-fixture', output],
			environment, root, log, false, '', false, false)!
		child.poll(true)!
		assert child.exit_code == 0, os.read_file(log)!
		expected := if name == 'unset' { '\n' } else { 'x\n' + value }
		assert os.read_file(output)! == expected
	}
}
