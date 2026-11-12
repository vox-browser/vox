module buildtools

import os

pub fn main_command(name string, args []string) {
	code := dispatch(name, args) or {
		eprintln('${name}: ${err}')
		if name == 'dev_build_env' {
			println(if '--shell' in args && 'powershell' in args {
				"throw 'Vox build setup failed'"
			} else {
				'false'
			})
		}
		exit(1)
	}
	exit(code)
}

fn dispatch(name string, args []string) !int {
	if name != 'v_match_scope_cc' {
		for argument in args {
			if argument in ['--', '--command'] { break }
			if argument == '--help' {
				println('${name}: Vox build tool; see tools/BUILDING.md')
				return 0
			}
		}
	}
	match name {
		'browser_backend' {
			println(browser_backend(if args.len > 0 { args[0] } else { root_dir() })!)
			return 0
		}
		'prepare_ui2' {
			println(prepare_ui(if args.len > 0 { args[0] } else { compiler() })!)
			return 0
		}
		'prepare_font_runtime' {
			println(prepare_font(if args.len > 0 { args[0] } else { compiler() })!)
			return 0
		}
		'prepare_prealloc_runtime' {
			println(prepare_prealloc(if args.len > 0 { args[0] } else { compiler() }, if args.len > 1 {
				args[1]
			} else {
				join(root_dir(), 'Build/v/prealloc-runtime')
			})!)
			return 0
		}
		'run_memory_bounded' { return memory_command(args) }
		'prepare_http_compat' {
			println(prepare_http(if args.len > 0 { args[0] } else { compiler() })!)
			return 0
		}
		'rebuild_browser' { return rebuild_command(args) }
		'pre_commit_check' { return pre_commit(os.getwd()) }
		'production_source_manifest' { return manifest_command(args) }
		'freeze_browser_compile' { return freeze_command(args) }
		'parallel_browser_compile' { return parallel_command(args) }
		'localize_bundle_rpaths' {
			if args.len != 2 { return error('Expected executable and build directory') }
			localize(args[0], args[1])!
			return 0
		}
		'build_harfbuzz' {
			a := arguments(args, []string{})!
			if a.has('--check-executable') {
				check_harfbuzz(a.required('--check-executable')!)!
				println('No Graphite2 library or symbol dependency')
			} else {
				println(build_harfbuzz()!)
			}
			return 0
		}
		'build_native_avif' {
			build_avif(arguments(args, ['--sanitize'])!)!
			return 0
		}
		'build_linux_native' {
			a := arguments(args, []string{})!
			build_linux_native(a.get('--os', 'linux'))!
			return 0
		}
		'prepare_linux_modules' {
			if args.len != 1 { return error('Expected V compiler') }
			println(prepare_linux(args[0])!)
			return 0
		}
		'prepare_v_match_scope' {
			if args.len != 1 { return error('Expected V compiler') }
			println(prepare_match(args[0])!)
			return 0
		}
		'v_match_scope_cc' { return match_cc(args) }
		'prune_build' {
			a := arguments(args, ['--dry-run', '--verbose'])!
			prune_build(root_dir(), a.get('--idle-hours', '12').f64(), a.has('--dry-run'), a.has('--verbose'))!
			return 0
		}
		'prepare_windows_jsc' {
			prepare_windows_jsc(arguments(args, []string{})!)!
			return 0
		}
		'prepare_windows_mesa' {
			a := arguments(args, []string{})!
			println(prepare_windows_mesa(real(a.get('--deps-root', join(root_dir(), 'Build/deps/windows'))))!)
			return 0
		}
		'build_windows_browser' {
			build_windows(arguments(args, ['--console'])!)!
			return 0
		}
		'dev_build_env' {
			development_command(arguments(args, []string{})!)!
			return 0
		}
		else { return error('Unknown build tool: ${name}') }
	}
}
