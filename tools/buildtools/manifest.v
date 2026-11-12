module buildtools

import os
import time
import json2 as json
import crypto.sha256

fn v_source(path string) bool { return ['.v', '.vv', '.vsh'].any(path.ends_with(it)) }

fn production_input(name string) bool {
	base := os.file_name(name)
	if name.starts_with('docs/') || name.starts_with('Tests/') || name.to_lower().ends_with('.md') || name.ends_with('_test.v') || name.ends_with('.py') {
		return false
	}
	if name.contains('/testdata/') && ['.tsv', '.jxl'].any(name.to_lower().ends_with(it)) {
		return false
	}
	if name.starts_with('tools/') && (base.starts_with('test_') || base.all_before_last('.').ends_with('_test')) {
		return false
	}
	return true
}

fn checkout_names(root string) ![]string {
	mut names := git(root, 'ls-files', '-z', '--cached', '--others', '--exclude-standard')!.split('\x00').filter(it.len > 0 && !it.ends_with('.swp') && !it.contains('.v3cc.'))
	names.sort()
	return unique_strings(names)
}

fn embedded_fixtures(root string, names []string) ![]string {
	mut corpora := []string{}
	for name in names {
		if name.contains('/testdata/') && (name.to_lower().ends_with('.tsv') || name.to_lower().ends_with('.jxl')) {
			corpora << name
		}
	}
	// Conservatively pin all corpus payloads when dynamic embed expressions occur.
	mut result := []string{}
	for name in names {
		if !v_source(name) || name.starts_with('tools/buildtools/') || !production_input(name) || !os.is_file(join(root, name)) {
			continue
		}
		text := read(join(root, name))!
		mut tail := text
		for tail.contains('\$embed_file') {
			tail = tail.all_after('\$embed_file').trim_left(' \t\n')
			if !tail.starts_with('(') { return corpora }
			tail = tail[1..].trim_left(' \t\n')
			if tail.len == 0 || tail[0] !in [`'`, `"`] { return corpora }
			q := tail[0].ascii_str()
			tail = tail[1..]
			value := tail.all_before(q)
			if value.contains('$') || value.contains('\\') { return corpora }
			tail = tail.all_after(q)
			if !tail.trim_left(' \t\n').starts_with(')') { return corpora }
			expanded := value.replace('@VMODROOT', root).replace('@DIR', os.dir(join(root, name)))
			if expanded.contains('@') { return corpora }
			resolved := real(if os.is_abs_path(expanded) {
				expanded
			} else {
				join(os.dir(join(root, name)), expanded)
			})
			mut matched := false
			for corpus in corpora {
				if real(join(root, corpus)) == resolved {
					result << corpus
					matched = true
				}
			}
			if !matched && ['.tsv', '.jxl'].any(value.to_lower().ends_with(it)) { return corpora }
		}
	}
	return unique_strings(result)
}

fn input_names(root string) ![]string {
	names := checkout_names(root)!
	fixtures := embedded_fixtures(root, names)!
	return names.filter(production_input(it) || it in fixtures)
}

fn repository_state(root string) !Record {
	mut full := sha256.new()
	mut build := sha256.new()
	names := checkout_names(root)!
	fixtures := embedded_fixtures(root, names)!
	for name in names {
		path := join(root, name)
		bytes := if os.is_link(path) {
			os.readlink(path)!
		} else if os.is_file(path) {
			read(path)!
		} else {
			'missing'
		}
		full.write((name + '\x00').bytes())!
		full.write(bytes.bytes())!
		if production_input(name) || name in fixtures {
			build.write((name + '\x00').bytes())!
			build.write(bytes.bytes())!
		}
	}
	return map[string]json.Any{
		'head':                git(root, 'rev-parse', 'HEAD')!.trim_space()
		'repository_sha256':   full.sum([]u8{}).hex()
		'build_inputs_sha256': build.sum([]u8{}).hex()
		'dirty':               git(root, 'status', '--porcelain')!.len > 0
	}
}

fn same_inputs(before Record, after Record) bool {
	if 'build_inputs_sha256' in before && 'build_inputs_sha256' in after {
		return (before['build_inputs_sha256'] or { json.Null{} }) == (after['build_inputs_sha256'] or { json.Null{} })
	}
	return before == after
}

fn begin_inventory(root string) !Record {
	names := input_names(root)!
	mut paths := []string{}
	for name in names {
		path := join(root, name)
		if os.is_file(path) && (!v_source(name) || os.is_link(path) || name.starts_with('tools/')) {
			paths << path
		}
	}
	return map[string]json.Any{
		'protocol':     'production-source-inventory-v1'
		'names':        any_strings(names)
		'early_inputs': record_strings(fingerprint(paths)!)
	}
}

fn validate_inventory(root string, inventory Record, parsed bool) ! {
	if (inventory['protocol'] or { json.Null{} }).str() != 'production-source-inventory-v1' || strings((inventory['names'] or { json.Null{} })).len == 0 {
		return error('Incomplete production source inventory')
	}
	mut names := input_names(root)!
	mut original := strings((inventory['names'] or { json.Null{} }))
	if parsed {
		names = names.filter(!v_source(it) || it.starts_with('tools/'))
		original = original.filter(!v_source(it) || it.starts_with('tools/'))
	}
	if names != original { return error('Production source membership changed') }
	check_fingerprints(string_map((inventory['early_inputs'] or { json.Null{} })))!
}

fn component_inputs(directory string) !map[string]string {
	names := read(join(directory, 'v_sources'))!.split('\x00')
	digests := read(join(directory, 'v_source_digests'))!.split('\x00')
	if names.len != digests.len || names.len == 0 || names[0].len == 0 {
		return error('Incomplete compiler source manifest: ${directory}')
	}
	mut result := map[string]string{}
	for i, raw in names {
		if raw == '' && digests[i] == '' && i == names.len - 1 { continue }
		digest_value := digests[i]
		if digest_value.len != 64 || digest_value.bytes().any(!((it >= `0` && it <= `9`) || (it >= `a` && it <= `f`))) {
			return error('Invalid compiler source digest: ${raw}')
		}
		if raw == '@native-input-manifest:v1' {
			if digest_value != hash('v3-native-input-manifest-v1') {
				return error('Invalid native manifest marker')
			}
			continue
		}
		name := raw.trim_string_left('@native-input:')
		if !os.is_abs_path(name) || name.starts_with('@') {
			return error('Invalid compiler source path: ${name}')
		}
		if name in result && result[name] != digest_value {
			return error('Conflicting compiler source digest: ${name}')
		}
		result[name] = digest_value
	}
	if !result.keys().any(v_source(it)) { return error('Compiler manifest has no V sources') }
	return result
}

fn only_v(inputs map[string]string) map[string]string {
	mut result := map[string]string{}
	for name, value in inputs { if v_source(name) { result[name] = value } }
	return result
}

fn verified_component(directory string) !map[string]string {
	proof := load(join(directory, 'parsed-verified.json'))!
	actual := component_inputs(directory)!
	if (proof['protocol'] or { json.Null{} }).str() != 'verified-parsed-buffers-v1' || string_map((proof['sources'] or { json.Null{} })) != only_v(actual) {
		return error('Compiler source buffers changed after verification: ${directory}')
	}
	return actual
}

fn membership(root string, names []string, sources map[string]string) []string {
	mut directories := []string{}
	for name, _ in sources { if name.starts_with(root + '/') { directories << os.dir(name) } }
	return names.filter(v_source(it) && os.dir(join(root, it)) in directories)
}

fn combine(root string, inventory Record, components []string, parsed bool) !map[string]string {
	validate_inventory(root, inventory, parsed)!
	mut result := string_map((inventory['early_inputs'] or { json.Null{} }))
	for directory in components {
		inputs := if parsed { verified_component(directory)! } else { component_inputs(directory)! }
		for name, value in inputs {
			if name in result && result[name] != value {
				return error('Production components consumed different source bytes: ${name}')
			}
			result[name] = value
		}
	}
	mut checked_inputs := map[string]string{}
	for name, value in result { if !parsed || !v_source(name) { checked_inputs[name] = value } }
	check_fingerprints(checked_inputs)!
	return result
}

fn matches_checkout(root string, frozen Record) bool {
	if 'source_inventory' !in frozen || 'exact_source_manifest' !in frozen { return false }
	validate_inventory(root, (frozen['source_inventory'] or { json.Null{} }).as_map(), false) or { return false }
	check_fingerprints(string_map((frozen['exact_source_manifest'] or { json.Null{} }))) or { return false }
	return true
}

fn compile_component(root string, inventory Record, directory string, command []string) !int {
	if command.len == 0 { return error('Missing compiler command') }
	mut env := os.environ()
	env['V_MACOS_V3_SOURCE_MANIFEST'] = '1'
	env['V_MACOS_V3_C_ERROR_DIR'] = directory
	identity := fingerprint([real(command[0])])!
	validate_inventory(root, inventory, true)!
	starting_names := input_names(root)!
	mut process := os.new_process(command[0])
	process.set_args(command[1..])
	process.set_environment(env)
	process.run()
	mut proof := false
	mut failure := ''
	for {
		alive := process.is_alive()
		if !proof && failure.len == 0 && os.is_file(join(directory, 'v_source_digests')) {
			if inputs := component_inputs(directory) {
				sources := only_v(inputs)
				verify_parsed(root, inventory, directory, sources, starting_names) or { failure = err.msg() }
				if failure.len == 0 {
					write_json(join(directory, 'parsed-verified.json'), json.Any(map[string]json.Any{
						'protocol':           'verified-parsed-buffers-v1'
						'sources':            record_strings(sources)
						'compiler':           record_strings(identity)
						'verified_unix':      f64(time.now().unix_milli()) / 1000
						'package_membership': any_strings(membership(root, starting_names, sources))
					}))!
					proof = true
				} else {
					write_json(join(directory, 'verification-error.json'), json.Any(map[string]json.Any{
						'error': failure
					}))!
				}
			}
		}
		if !alive { break }
		time.sleep(50 * time.millisecond)
	}
	process.wait()
	code := process.code
	process.close()
	if code != 0 { return code }
	check_fingerprints(identity)!
	if failure.len > 0 { return error(failure) }
	if exists(join(directory, 'v_sources')) { verified_component(directory)! }
	return 0
}

fn verify_parsed(root string, inventory Record, directory string, sources map[string]string, names []string) ! {
	validate_inventory(root, inventory, true)!
	if membership(root, names, sources) != membership(root, input_names(root)!, sources) {
		return error('Consumed V package membership changed during parsing')
	}
	check_fingerprints(sources)!
	if sources != only_v(component_inputs(directory)!) {
		return error('Compiler manifest changed during verification')
	}
}

fn manifest_command(args []string) !int {
	a := arguments(args, ['--parsed'])!
	root := real(a.required('--root')!)
	path := a.required('--inventory')!
	match a.positional(0, '') {
		'begin' {
			script := join(os.dir(path), 'build-script.json')
			if os.is_file(script) {
				delivered := load(script)!
				check_fingerprints({
					(delivered['path'] or { json.Null{} }).str(): (delivered['sha256'] or { json.Null{} }).str()
				})!
			}
			write_json(path, json.Any(begin_inventory(root)!))!
		}
		'combine' {
			write_json(a.required('--output')!, record_strings(combine(root, load(path)!, a.options['--component'], a.has('--parsed'))!))!
		}
		'compile' {
			return compile_component(root, load(path)!, a.required('--component-dir')!, a.command)
		}
		else { return error('Expected begin, combine or compile') }
	}
	return 0
}
