module main

import os

fn main() {
	restore_build_environment() or {
		eprintln(err.msg())
		exit(1)
	}
	repo := os.getenv_opt('VOX_BUILD_ROOT') or { os.dir(os.dir(@VMODROOT)) }
	code := dispatch_build(os.real_path(repo), os.args[1..]) or {
		eprintln(err.msg())
		1
	}
	exit(code)
}

fn dispatch_build(repo string, args []string) !int {
	if args.len == 0 || args[0] in ['help', '--help', '-h'] {
		println('Vox native build tools\nUsage: sh tools/vox-build.sh COMMAND [ARGUMENTS]\n\nCommands: supervise, memory, pre-commit, prune, prepare-http, prepare-ui2,\n          prepare-linux-modules, prepare-prealloc, prepare-font, build-native,\n          build-avif, build-linux-skia, build-graphite, build-graphite-dawn,\n          build-snapshot-deflate, renderer, backend, manifest, parallel, freeze,\n          localize-rpaths')
		return 0
	}
	command := args[0]
	options := args[1..]
	match command {
		'supervise' { return supervise(repo, options) }
		'memory' { return memory_guard(repo, options) }
		'pre-commit' { return native_pre_commit(repo, options) }
		'prune' { return prune_build(repo, options) }
		'manifest' { return manifest_cli(repo, options) }
		'parallel' { return parallel_cli(repo, options) }
		'freeze' { return freeze_cli(repo, options) }
		'prepare-http', 'prepare-ui2', 'prepare-linux-modules', 'prepare-prealloc', 'prepare-font' {
			compiler := if options.len > 0 { options[0] } else { env_default('V_BIN', 'v') }
			path := match command {
				'prepare-http' { prepare_http(repo, compiler)! }
				'prepare-ui2' { prepare_ui2(repo, compiler)! }
				'prepare-linux-modules' { prepare_linux_modules(repo, compiler)! }
				'prepare-prealloc' {
					prepare_prealloc(repo, compiler, if options.len > 1 { options[1] } else { '' })!
				}
				else { prepare_font(repo, compiler)! }
			}
			println(path)
		}
		'build-native' { build_native(repo, options)! }
		'build-avif' { println(build_avif(repo, options)!) }
		'build-linux-skia' { build_linux_skia(repo)! }
		'build-graphite' { build_graphite(repo, options)! }
		'build-graphite-dawn' { build_graphite_dawn(repo, options)! }
		'build-snapshot-deflate' { println(build_snapshot_deflate(repo)!) }
		'renderer' { println(renderer_compiler(repo, options)!) }
		'backend' { println(browser_backend(if options.len > 0 { options[0] } else { repo })!) }
		'localize-rpaths' {
			if options.len != 2 {
				return error('localize-rpaths requires EXECUTABLE BUILD_DIRECTORY')
			}
			localize_bundle(repo, options[0], options[1])!
		}
		else { return error('Unknown build command: ${command}') }
	}
	return 0
}
