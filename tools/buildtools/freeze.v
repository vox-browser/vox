module buildtools

import os
import json2 as json

struct FlagPart {
	kind   string
	values []string
}

const source_languages = {
	'.c':   'c'
	'.m':   'objective-c'
	'.cc':  'c++'
	'.cpp': 'c++'
	'.cxx': 'c++'
	'.mm':  'objective-c++'
}
const pp_languages = {
	'c':             'cpp-output'
	'objective-c':   'objective-c-cpp-output'
	'c++':           'c++-cpp-output'
	'objective-c++': 'objective-c++-cpp-output'
}
const option_arguments = ['-I', '-L', '-F', '-D', '-U', '-isystem', '-iquote', '-idirafter', '-isysroot',
	'--sysroot', '-include', '-imacros', '-framework', '-weak_framework', '-arch', '-target', '-stdlib',
	'-isystem-after']

fn parse_flags(flags []string, cwd string) ![]FlagPart {
	mut parts := []FlagPart{}
	mut language := 'none'
	for i := 0; i < flags.len; i++ {
		token := flags[i]
		if token.starts_with('-Wl,') {
			linker := token.split(',')[1..]
			if !(linker.len == 2 && linker[0] in ['-rpath', '-stack_size']) && !linker.all(it in [
				'-dead_strip',
				'-dead_strip_dylibs',
				'-search_paths_first',
				'-no_compact_unwind',
			]) {
				return error('Unsupported linker option in frozen build: ${token}')
			}
		}
		if token == '-x' || token in option_arguments {
			if i + 1 == flags.len { return error('Missing operand for ${token}') }
			parts << FlagPart{'option', flags[i..i + 2].clone()}
			if token == '-x' { language = flags[i + 1] }
			i++
			continue
		}
		if token in ['-o', '-E', '-c', '-S'] {
			return error('Unexpected output/action in dumped flags: ${token}')
		}
		if token.starts_with('@') || ['-fmodule', '-fplugin', '-fpass-plugin', '-fprofile', '-B',
			'-specs=', '-Wl,@', '-Wl,-filelist', '-Wl,-force_load', '-Wl,-bundle_loader',
			'-Wl,-lto_library', '-Wl,-sectcreate'].any(token.starts_with(it)) || token in [
			'-Xclang',
			'-Xpreprocessor',
			'-Xlinker',
			'-include-pch',
		] {
			return error('Unsealed response file or module flag: ${token}')
		}
		path := if os.is_abs_path(token) { token } else { join(cwd, token) }
		extension := os.file_ext(path)
		if !token.starts_with('-') && extension in source_languages {
			if !os.is_file(path) { return error('Missing source: ${path}') }
			selected := if language == 'none' { source_languages[extension] } else { language }
			if selected !in pp_languages {
				return error('Unsupported source language: ${selected}')
			}
			parts << FlagPart{'source', [real(path), selected]}
		} else if !token.starts_with('-') && extension in ['.o', '.a', '.dylib', '.tbd'] {
			if !os.is_file(path) { return error('Missing linker input: ${path}') }
			parts << FlagPart{if extension in ['.o', '.a'] { 'object' } else { 'library' }, [real(path)]}
		} else if token.starts_with('-') {
			parts << FlagPart{'option', [token]}
		} else {
			return error('Unrecognized compiler operand: ${token}')
		}
	}
	return parts
}

fn resolved_libraries(parts []FlagPart, cwd string) !map[string]string {
	mut directories := []string{}
	mut frameworks := []string{}
	mut names := []string{}
	mut libraries := map[string]string{}
	mut sysroot := ''
	for part in parts {
		if part.kind == 'library' { libraries['file:' + part.values[0]] = part.values[0] }
		if part.kind != 'option' { continue }
		token := part.values[0]
		if token in ['-framework', '-weak_framework'] { names << part.values[1] }
		if token.starts_with('-F') {
			value := if token == '-F' { part.values[1] } else { token[2..] }
			frameworks << real(if os.is_abs_path(value) { value } else { join(cwd, value) })
		}
		if token.starts_with('-L') {
			value := if token == '-L' { part.values[1] } else { token[2..] }
			directories << real(if os.is_abs_path(value) { value } else { join(cwd, value) })
		}
		if token in ['-isysroot', '--sysroot'] { sysroot = part.values[1] }
		if token.starts_with('--sysroot=') { sysroot = token.all_after('=') }
	}
	for part in parts {
		if part.kind != 'option' || !part.values[0].starts_with('-l') || part.values[0].len <= 2 {
			continue
		}
		name := part.values[0][2..]
		mut found := ''
		for folder in directories {
			for suffix in ['.dylib', '.tbd', '.a'] {
				candidate := join(folder, 'lib' + name + suffix)
				if os.is_file(candidate) {
					found = real(candidate)
					break
				}
			}
			if found.len > 0 { break }
		}
		if found.len > 0 {
			libraries['library:' + name] = found
		} else if name !in ['System', 'c', 'm', 'pthread', 'objc', 'z', 'iconv', 'c++', 'resolv',
			'dl'] {
			return error('Cannot pin linker library: ${name}')
		}
	}
	if names.len > 0 {
		sdk := if sysroot.len > 0 {
			sysroot
		} else {
			capture(['xcrun', '--show-sdk-path'])!.trim_space()
		}
		if os.is_file(join(sdk, 'SDKSettings.json')) {
			libraries['sdk-settings'] = real(join(sdk, 'SDKSettings.json'))
		}
		for name in names {
			mut selected := join(sdk, 'System/Library/Frameworks', name + '.framework')
			for folder in frameworks {
				if os.is_dir(join(folder, name + '.framework')) {
					selected = join(folder, name + '.framework')
					break
				}
			}
			if os.is_file(join(selected, name)) {
				libraries['framework:' + name] = real(join(selected, name))
				continue
			}
			stubs := (files(selected)!).filter(it.ends_with('.tbd'))
			if stubs.len == 0 { return error('Cannot pin linker framework: ${name}') }
			for path in stubs {
				libraries['framework:' + name + ':' + relative(path, selected)] = real(path)
			}
		}
	}
	return libraries
}

fn encode_parts(parts []FlagPart) json.Any {
	mut result := []json.Any{}
	for part in parts {
		value := if part.kind in ['object', 'library'] {
			json.Any(part.values[0])
		} else {
			any_strings(part.values)
		}
		result << json.Any([json.Any(part.kind), value])
	}
	return json.Any(result)
}

fn decode_parts(value json.Any) []FlagPart {
	mut result := []FlagPart{}
	for raw in value.as_array() {
		pair := raw.as_array()
		kind := pair[0].str()
		result << FlagPart{kind, if kind in ['object', 'library'] {
			[pair[1].str()]
		} else {
			strings(pair[1])
		}}
	}
	return result
}

fn check_sources(root string, inventory Record, manifest map[string]string, components []string) ! {
	if inventory.len > 0 { validate_inventory(root, inventory, components.len > 0)! }
	if components.len > 0 {
		if combine(root, inventory, components, true)! != manifest {
			return error('Parsed source proof does not match compiler inputs')
		}
	} else if manifest.len > 0 {
		check_fingerprints(manifest)!
	}
}

fn prepare_frozen(a Args) !Record {
	root := real(a.required('--root')!)
	stage := real(a.required('--stage')!)
	receipt := real(a.required('--receipt')!)
	source := real(a.required('--source')!)
	flags_path := real(a.required('--flags')!)
	output := absolute(a.required('--output')!)
	before := load(join(receipt, 'inputs-before.json'))!
	manifest := if a.has('--source-manifest') {
		string_map(json.Any(load(a.required('--source-manifest')!)!))
	} else {
		map[string]string{}
	}
	inventory := if a.has('--source-inventory') {
		load(a.required('--source-inventory')!)!
	} else {
		Record{}
	}
	components := a.options['--parsed-component']
	if (manifest.len > 0) != (inventory.len > 0) || (components.len > 0 && manifest.len == 0) {
		return error('Source manifest and inventory must be supplied together')
	}
	check_sources(root, inventory, manifest, components)!
	if manifest.len == 0 && !same_inputs(before, repository_state(root)!) {
		return error('Repository inputs changed before C preprocessing')
	}
	cwd := os.getwd()
	clang := real(os.find_abs_path_of_executable('clang')!)
	parts := parse_flags(shell_split(read(flags_path)!)!, cwd)!
	frozen := join(receipt, 'frozen-compiler-inputs')
	os.mkdir(frozen)!
	mut pp_options := []string{}
	for part in parts {
		if part.kind == 'option' && part.values[0] != '-x' { pp_options << part.values }
	}
	mut sources := [FlagPart{'source', [source, 'objective-c']}]
	sources << parts.filter(it.kind == 'source')
	mut preprocessed := map[string][]string{}
	mut commands := []json.Any{}
	for index, part in sources {
		path := part.values[0]
		language := part.values[1]
		sha := digest(path)!
		destination := join(frozen, '${index}-${os.file_name(path)}.i')
		command := [clang, ...pp_options, '-Qunused-arguments', '-x', language, '-E', path, '-o',
			destination]
		commands << any_strings(command)
		write_json(join(receipt, 'preprocess-commands.json'), json.Any(commands))!
		checked(command)!
		if digest(path)! != sha { return error('C source changed during preprocessing: ${path}') }
		preprocessed[path] = [destination, pp_languages[language]]
	}
	mut objects := map[string]string{}
	mut original_objects := map[string]string{}
	for index, part in parts {
		if part.kind != 'object' { continue }
		path := part.values[0]
		sha := digest(path)!
		destination := join(frozen, 'link-${index}-${os.file_name(path)}')
		os.cp(path, destination)!
		if digest(destination)! != sha || digest(path)! != sha {
			return error('Link object changed while sealing: ${path}')
		}
		objects[path] = destination
		original_objects[path] = sha
	}
	libraries := resolved_libraries(parts, cwd)!
	mut late := files(join(stage, 'Vox.app'))!
	late << (listing(stage)!).filter(it.ends_with('.dylib'))
	late << [join(root, 'packaging/Vox.entitlements.plist'),
		join(root, 'tools/localize_bundle_rpaths.vsh'), clang]
	late << libraries.values()
	live_inputs := fingerprint(late)!
	mut sealed_paths := [source, flags_path, ...listing(frozen)!]
	for directory in components {
		for name in ['v_sources', 'v_source_digests', 'parsed-verified.json'] {
			sealed_paths << join(directory, name)
		}
	}
	sealed_inputs := fingerprint(sealed_paths)!
	after := repository_state(root)!
	check_sources(root, inventory, manifest, components)!
	if manifest.len == 0 && !same_inputs(before, after) {
		return error('Repository inputs changed while sealing compiler inputs')
	}
	mut command := [clang, '-x', preprocessed[source][1], preprocessed[source][0], '-x', 'none']
	for part in parts {
		match part.kind {
			'source' {
				values := preprocessed[part.values[0]]
				command << ['-x', values[1], values[0], '-x', 'none']
			}
			'object' { command << objects[part.values[0]] }
			'library' { command << part.values[0] }
			else {
				if part.values[0] in ['-include', '-imacros', '-include-pch'] { continue }
				if part.values.len == 1 && ['-include', '-imacros'].any(part.values[0].starts_with(it)) {
					return error('Unsupported attached forced-include flag')
				}
				command << part.values
			}
		}
	}
	command << ['-o', output]
	mut result := map[string]json.Any{
		'protocol':           'preprocessed-c-v1'
		'source_inputs':      json.Any(if manifest.len > 0 { before } else { after })
		'cwd':                cwd
		'compiler':           clang
		'compiler_command':   any_strings(command)
		'flags_parts':        encode_parts(parts)
		'resolved_libraries': record_strings(libraries)
		'live_inputs':        record_strings(live_inputs)
		'sealed_inputs':      record_strings(sealed_inputs)
		'original_objects':   record_strings(original_objects)
		'complete':           false
	}
	if manifest.len > 0 {
		result['exact_source_manifest'] = record_strings(manifest)
		result['source_inputs_at_sealing'] = json.Any(after)
		if components.len > 0 {
			result['repository_at_sealing'] = json.Any(after)
			result['source_inputs_at_sealing'] = json.Any(map[string]json.Any{
				'head':                (after['head'] or { json.Null{} })
				'dirty':               true
				'source_kind':         'verified parsed buffers and sealed native inputs'
				'build_inputs_sha256': hash(json.encode(manifest))
			})
		}
	}
	if inventory.len > 0 { result['source_inventory'] = json.Any(inventory) }
	write_json(join(receipt, 'frozen-compile.json'), json.Any(result))!
	return result
}

fn validate_frozen(receipt string, expected Record, require_complete bool) !Record {
	data := load(join(receipt, 'frozen-compile.json'))!
	if (data['protocol'] or { json.Null{} }).str() != 'preprocessed-c-v1' || !same_inputs((data['source_inputs'] or { json.Null{} }).as_map(), expected) {
		return error('Frozen compilation source receipt does not match build inputs')
	}
	if require_complete && (!(data['complete'] or { json.Null{} }).bool() || (data['compiler_exit'] or { json.Null{} }).int() != 0) {
		return error('Frozen compilation did not complete successfully')
	}
	if (data['sealed_inputs'] or { json.Null{} }).as_map().len == 0 || (data['live_inputs'] or { json.Null{} }).as_map().len == 0 || strings((data['compiler_command'] or { json.Null{} })).len == 0 {
		return error('Frozen compilation input manifest is incomplete')
	}
	check_fingerprints(string_map((data['sealed_inputs'] or { json.Null{} })))!
	check_fingerprints(string_map((data['live_inputs'] or { json.Null{} })))!
	if resolved_libraries(decode_parts((data['flags_parts'] or { json.Null{} })), (data['cwd'] or { json.Null{} }).str())! != string_map((data['resolved_libraries'] or { json.Null{} })) {
		return error('Link library search resolution changed after sealing')
	}
	return data
}

fn freeze_command(args []string) !int {
	a := arguments(args, []string{})!
	mut data := prepare_frozen(a)!
	receipt := a.required('--receipt')!
	validate_frozen(receipt, (data['source_inputs'] or { json.Null{} }).as_map(), false)!
	code := execute(strings((data['compiler_command'] or { json.Null{} })))
	data['compiler_exit'] = code
	data['complete'] = code == 0
	write_json(join(receipt, 'frozen-compile.json'), json.Any(data))!
	if code != 0 { return code }
	validate_frozen(receipt, (data['source_inputs'] or { json.Null{} }).as_map(), true)!
	println('Compiled the verified preprocessed production inputs')
	return 0
}
