module buildtools

import os
import json2 as json

fn test_capture_header_coexists_with_generated_prototypes() ! {
	root := temporary(os.temp_dir(), 'vox-capture-compat-')!
	defer { remove(root) or {} }
	header := join(root_dir(), 'native/include/native_process_capture_compat.h')
	// os_nix.c.v binds &char / &&char. FastC can emit these declarations
	// in the same unit as the native include, in either include order.
	prototypes := 'int v_os_execute_capture_start(char *, int *, int *);\n' +
		'int v_os_exec_capture_start(char **, int *, int *);\n'
	use := 'int (*shell_capture)(char *, int *, int *) = v_os_execute_capture_start;\n' +
		'int (*argv_capture)(char **, int *, int *) = v_os_exec_capture_start;\n'
	include := '#include ' + json.encode(header) + '\n'
	compiler := shell_split(os.getenv_opt('CC') or { 'cc' })!
	source := join(root, 'capture.c')
	for generated_first in [true, false] {
		declarations := if generated_first { prototypes + include } else { include + prototypes }
		os.write_file(source, declarations + use)!
		result := os.exec([...compiler, '-std=c11', '-Werror', '-fsyntax-only', source])
		assert result.exit_code == 0, 'generated_first=${generated_first}: ${result.output}'
	}
}
