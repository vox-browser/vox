module main

import crypto.sha256
import json2 as json
import os

const frozen_protocol = 'preprocessed-c-v1'

struct FlagPart {
	kind  string
	value []string
}

struct FrozenCompile {
mut:
	protocol                 string
	source_inputs            RepositoryState
	source_inputs_at_sealing map[string]json.Any
	repository_at_sealing    RepositoryState
	cwd                      string
	compiler                 string
	compiler_command         []string
	flags_parts              []json.Any
	resolved_libraries       map[string]string
	live_inputs              map[string]string
	sealed_inputs            map[string]string
	original_objects         map[string]string
	exact_source_manifest    map[string]string
	source_inventory         SourceInventory
	complete                 bool
	compiler_exit            int = -1
}

fn string_maps_equal(left map[string]string, right map[string]string) bool {
	if left.len != right.len { return false }
	for key, value in left {
		if key !in right || right[key] != value { return false }
	}
	return true
}

fn fingerprint(paths []string) !map[string]string {
	mut result := map[string]string{}
	mut sorted := paths.clone()
	sorted.sort()
	for path in sorted {
		resolved := os.real_path(path)
		result[resolved] = hash_file(resolved)!
	}
	return result
}

fn check_fingerprints(expected map[string]string) ! {
	for path, digest in expected {
		if !os.is_file(path) || hash_file(path)! != digest {
			return error('Frozen build input changed: ${path}')
		}
	}
}

fn source_language(path string) string {
	return match os.file_ext(path) {
		'.c' { 'c' }
		'.m' { 'objective-c' }
		'.cc', '.cpp', '.cxx' { 'c++' }
		'.mm' { 'objective-c++' }
		else { '' }
	}
}

fn preprocessed_language(language string) !string {
	return match language {
		'c' { 'cpp-output' }
		'objective-c' { 'objective-c-cpp-output' }
		'c++' { 'c++-cpp-output' }
		'objective-c++' { 'objective-c++-cpp-output' }
		else { return error('Unsupported source language: ${language}') }
	}
}

fn absolute_from(path string, cwd string) string {
	return os.real_path(if os.is_abs_path(path) { path } else { os.join_path(cwd, path) })
}

fn parse_frozen_flags(flags []string, cwd string) ![]FlagPart {
	operands := ['-I', '-L', '-F', '-D', '-U', '-isystem', '-iquote', '-idirafter', '-isysroot',
		'--sysroot', '-include', '-imacros', '-framework', '-weak_framework', '-arch', '-target',
		'-stdlib', '-isystem-after']
	mut parts := []FlagPart{}
	mut language := 'none'
	mut index := 0
	for index < flags.len {
		token := flags[index]
		if token.starts_with('-Wl,') {
			linker := token.split(',')[1..]
			mut safe := linker.len == 2 && linker[0] in ['-rpath', '-stack_size']
			if !safe {
				safe = linker.len > 0
				for item in linker {
					if item !in ['-dead_strip', '-dead_strip_dylibs', '-search_paths_first',
						'-no_compact_unwind'] {
						safe = false
					}
				}
			}
			if !safe { return error('Unsupported linker option in frozen build: ${token}') }
		}
		if token == '-x' || token in operands {
			if index + 1 == flags.len { return error('Missing operand for ${token}') }
			if token == '-x' { language = flags[index + 1] }
			parts << FlagPart{'option', flags[index..index + 2].clone()}
			index += 2
			continue
		}
		if token in ['-o', '-E', '-c', '-S'] {
			return error('Unexpected output/action in dumped flags: ${token}')
		}
		mut unsafe_flag := token.starts_with('@') || token in ['-Xclang', '-Xpreprocessor', '-Xlinker',
			'-include-pch']
		for prefix in ['-fmodule', '-fplugin', '-fpass-plugin', '-fprofile', '-B', '-specs=', '-Wl,@',
			'-Wl,-filelist', '-Wl,-force_load', '-Wl,-bundle_loader', '-Wl,-lto_library',
			'-Wl,-sectcreate'] {
			if token.starts_with(prefix) { unsafe_flag = true }
		}
		if unsafe_flag { return error('Unsealed response file or module flag: ${token}') }
		path := absolute_from(token, cwd)
		if !token.starts_with('-') && source_language(token) != '' {
			if !os.is_file(path) { return error('Missing compiler source: ${path}') }
			selected := if language == 'none' { source_language(token) } else { language }
			preprocessed_language(selected)!
			parts << FlagPart{'source', [path, selected]}
		} else if !token.starts_with('-') && os.file_ext(token) in ['.o', '.a', '.dylib', '.tbd'] {
			if !os.is_file(path) { return error('Missing link input: ${path}') }
			parts << FlagPart{if os.file_ext(token) in ['.o', '.a'] { 'object' } else { 'library' }, [path]}
		} else if token.starts_with('-') {
			parts << FlagPart{'option', [token]}
		} else {
			return error('Unrecognized compiler operand: ${token}')
		}
		index++
	}
	return parts
}

fn flag_parts_json(parts []FlagPart) []json.Any {
	mut result := []json.Any{}
	for part in parts {
		mut value := json.Any(part.value[0])
		if part.kind !in ['object', 'library'] {
			mut words := []json.Any{}
			for item in part.value { words << json.Any(item) }
			value = json.Any(words)
		}
		result << json.Any([json.Any(part.kind), value])
	}
	return result
}

fn flags_from_json(entries []json.Any) ![]FlagPart {
	mut parts := []FlagPart{}
	for entry in entries {
		row := entry.as_array()
		if row.len != 2 { return error('Malformed frozen compiler flags') }
		kind := row[0].str()
		mut value := []string{}
		if kind in ['object', 'library'] {
			value << row[1].str()
		} else {
			for word in row[1].as_array() { value << word.str() }
		}
		if value.len == 0 { return error('Empty frozen compiler flag') }
		parts << FlagPart{kind, value}
	}
	return parts
}

fn resolved_libraries(parts []FlagPart, cwd string) !map[string]string {
	mut directories := []string{}
	mut frameworks := []string{}
	mut names := []string{}
	mut libraries := map[string]string{}
	for part in parts {
		if part.kind == 'library' { libraries['file:' + part.value[0]] = part.value[0] }
		if part.kind != 'option' { continue }
		token := part.value[0]
		if token in ['-framework', '-weak_framework'] { names << part.value[1] }
		if token == '-F' || (token.starts_with('-F') && token.len > 2) {
			frameworks << absolute_from(if token == '-F' { part.value[1] } else { token[2..] }, cwd)
		}
		if token == '-L' || (token.starts_with('-L') && token.len > 2) {
			directories << absolute_from(if token == '-L' { part.value[1] } else { token[2..] }, cwd)
		}
	}
	for part in parts {
		if part.kind != 'option' || !part.value[0].starts_with('-l') || part.value[0].len <= 2 {
			continue
		}
		name := part.value[0][2..]
		mut found := ''
		for folder in directories {
			for extension in ['.dylib', '.tbd', '.a'] {
				candidate := os.join_path(folder, 'lib' + name + extension)
				if os.is_file(candidate) {
					found = os.real_path(candidate)
					break
				}
			}
			if found != '' { break }
		}
		if found != '' {
			libraries['library:' + name] = found
		} else if name !in ['System', 'c', 'm', 'pthread', 'objc', 'z', 'iconv', 'c++', 'icucore',
			'resolv', 'dl'] {
			return error('Cannot pin linker library: ${name}')
		}
	}
	if names.len > 0 {
		mut sdk := ''
		for part in parts {
			if part.kind != 'option' { continue }
			if part.value[0] in ['-isysroot', '--sysroot'] { sdk = part.value[1] }
			if part.value[0].starts_with('--sysroot=') { sdk = part.value[0].all_after('=') }
		}
		if sdk == '' { sdk = capture_command(['xcrun', '--show-sdk-path'])!.trim_space() }
		settings := os.join_path(sdk, 'SDKSettings.json')
		if os.is_file(settings) { libraries['sdk-settings'] = settings }
		for name in names {
			mut selected := os.join_path(sdk, 'System/Library/Frameworks', name + '.framework')
			for folder in frameworks {
				candidate := os.join_path(folder, name + '.framework')
				if os.is_dir(candidate) {
					selected = candidate
					break
				}
			}
			binary := os.join_path(selected, name)
			if os.is_file(binary) {
				libraries['framework:' + name] = os.real_path(binary)
			} else {
				mut stubs := os.walk_ext(selected, '.tbd')
				stubs.sort()
				if stubs.len == 0 { return error('Cannot pin linker framework: ${name}') }
				for path in stubs {
					libraries['framework:' + name + ':' + path.all_after(selected + '/')] = os.real_path(path)
				}
			}
		}
	}
	return libraries
}

fn canonical_source_json(sources map[string]string) string {
	mut keys := sources.keys()
	keys.sort()
	mut entries := []string{}
	for key in keys { entries << json.encode(key) + ': ' + json.encode(sources[key]) }
	return '{' + entries.join(', ') + '}'
}

fn verify_consumed_sources(root string, inventory SourceInventory, manifest map[string]string, components []string) ! {
	if components.len > 0 {
		if !string_maps_equal(combine_source_inputs(root, inventory, components, true)!, manifest) {
			return error('Parsed source proof does not match compiler inputs')
		}
	} else {
		check_fingerprints(manifest)!
	}
}

fn prepare_frozen_compile(root string, stage string, receipt string, source string,
	flags_path string, output string, manifest map[string]string, inventory SourceInventory, components []string) !FrozenCompile {
	before := json.decode[RepositoryState](os.read_file(os.join_path(receipt, 'inputs-before.json'))!)!
	if before.build_inputs_sha256 == '' { return error('Incomplete build source identity') }
	if inventory.protocol != '' { validate_source_inventory(root, inventory, components.len > 0)! }
	if manifest.len > 0 {
		verify_consumed_sources(root, inventory, manifest, components)!
	} else if !same_build_inputs(before, repository_state(root)!) {
		return error('Repository inputs changed before C preprocessing')
	}
	cwd := os.getwd()
	compiler := os.real_path(executable('clang', '')!)
	parts := parse_frozen_flags(shell_split(os.read_file(flags_path)!)!, cwd)!
	frozen := os.join_path(receipt, 'frozen-compiler-inputs')
	os.mkdir(frozen)!
	mut pp_options := []string{}
	for part in parts {
		if part.kind == 'option' && part.value[0] != '-x' { pp_options << part.value }
	}
	mut sources := [FlagPart{'source', [source, 'objective-c']}]
	for part in parts { if part.kind == 'source' { sources << part } }
	mut preprocessed := map[string][]string{}
	mut objects := map[string]string{}
	mut original_objects := map[string]string{}
	mut commands := [][]string{}
	for index, part in sources {
		path, language := part.value[0], part.value[1]
		digest := hash_file(path)!
		destination := os.join_path(frozen, '${index}-${os.file_name(path)}.i')
		command := [compiler, ...pp_options, '-Qunused-arguments', '-x', language, '-E', path,
			'-o', destination]
		commands << command
		atomic_write_json_text(os.join_path(receipt, 'preprocess-commands.json'), json.encode(commands))!
		run_command(command)!
		if hash_file(path)! != digest {
			return error('C source changed during preprocessing: ${path}')
		}
		preprocessed[path] = [destination, preprocessed_language(language)!]
	}
	for index, part in parts {
		if part.kind != 'object' { continue }
		path := part.value[0]
		destination := os.join_path(frozen, 'link-${index}-${os.file_name(path)}')
		digest := hash_file(path)!
		os.cp(path, destination)!
		if hash_file(destination)! != digest || hash_file(path)! != digest {
			return error('Link object changed while sealing: ${path}')
		}
		original_objects[path] = digest
		objects[path] = destination
	}
	libraries := resolved_libraries(parts, cwd)!
	mut late := os.walk_ext(os.join_path(stage, 'Vox.app'), '')
	for name in os.ls(stage)! {
		if name.ends_with('.dylib') && os.is_file(os.join_path(stage, name)) {
			late << os.join_path(stage, name)
		}
	}
	late << [os.join_path(root, 'packaging/Vox.entitlements.plist'),
		os.join_path(root, 'tools/voxbuild/native.v'), compiler]
	late << libraries.values()
	live_inputs := fingerprint(late)!
	mut sealed_paths := [source, flags_path]
	sealed_paths << os.walk_ext(frozen, '')
	for directory in components {
		for name in ['v_sources', 'v_source_digests', 'parsed-verified.json'] {
			sealed_paths << os.join_path(directory, name)
		}
	}
	sealed_inputs := fingerprint(sealed_paths)!
	after := repository_state(root)!
	if inventory.protocol != '' { validate_source_inventory(root, inventory, components.len > 0)! }
	if manifest.len > 0 {
		verify_consumed_sources(root, inventory, manifest, components)!
	} else if !same_build_inputs(before, after) {
		return error('Repository inputs changed while sealing compiler inputs')
	}
	first := preprocessed[source]
	mut command := [compiler, '-x', first[1], first[0], '-x', 'none']
	for part in parts {
		match part.kind {
			'source' {
				item := preprocessed[part.value[0]]
				command << ['-x', item[1], item[0], '-x', 'none']
			}
			'object' { command << objects[part.value[0]] }
			'library' { command << part.value[0] }
			else {
				if part.value[0] in ['-include', '-imacros', '-include-pch'] { continue }
				if part.value.len == 1 && (part.value[0].starts_with('-include') || part.value[0].starts_with('-imacros')) {
					return error('Unsupported attached forced-include flag')
				}
				command << part.value
			}
		}
	}
	command << ['-o', output]
	mut accepted := json.map_from(after)
	if components.len > 0 {
		accepted = {
			'head':                json.Any(after.head)
			'dirty':               json.Any(true)
			'source_kind':         json.Any('verified parsed buffers and sealed native inputs')
			'build_inputs_sha256': json.Any(sha256.hexhash(canonical_source_json(manifest)))
		}
	}
	data := FrozenCompile{
		protocol:                 frozen_protocol
		source_inputs:            if manifest.len > 0 { before } else { after }
		source_inputs_at_sealing: accepted
		repository_at_sealing:    after
		cwd:                      cwd
		compiler:                 compiler
		compiler_command:         command
		flags_parts:              flag_parts_json(parts)
		resolved_libraries:       libraries
		live_inputs:              live_inputs
		sealed_inputs:            sealed_inputs
		original_objects:         original_objects
		exact_source_manifest:    manifest
		source_inventory:         inventory
	}
	atomic_write_json_text(os.join_path(receipt, 'frozen-compile.json'), json.encode(data))!
	return data
}

fn validate_frozen_compile(_ string, receipt string, expected RepositoryState, require_complete bool) !FrozenCompile {
	data := json.decode[FrozenCompile](os.read_file(os.join_path(receipt, 'frozen-compile.json'))!)!
	if data.protocol != frozen_protocol || expected.build_inputs_sha256 == '' || !same_build_inputs(data.source_inputs, expected) {
		return error('Frozen compilation source receipt does not match build inputs')
	}
	if require_complete && (!data.complete || data.compiler_exit != 0) {
		return error('Frozen compilation did not complete successfully')
	}
	if data.sealed_inputs.len == 0 || data.live_inputs.len == 0 || data.compiler_command.len == 0 {
		return error('Frozen compilation input manifest is incomplete')
	}
	check_fingerprints(data.sealed_inputs)!
	check_fingerprints(data.live_inputs)!
	if !string_maps_equal(resolved_libraries(flags_from_json(data.flags_parts)!, data.cwd)!, data.resolved_libraries) {
		return error('Link library search resolution changed after sealing')
	}
	return data
}

fn accepted_frozen_source(repo string, receipt string, expected RepositoryState) !RepositoryState {
	data := validate_frozen_compile(repo, receipt, expected, true)!
	if data.source_inputs_at_sealing.len > 0 {
		return json.decode[RepositoryState](json.encode(data.source_inputs_at_sealing))
	}
	return data.source_inputs
}

fn frozen_checkout_matches(repo string, receipt string) bool {
	data := json.decode[FrozenCompile](os.read_file(os.join_path(receipt, 'frozen-compile.json')) or { return false }) or { return false }
	return matches_compiled_source_inventory(repo, data.source_inventory, data.exact_source_manifest)
}

fn freeze_cli(repo string, args []string) !int {
	root := os.real_path(required_option(args, '--root')!)
	stage := os.real_path(required_option(args, '--stage')!)
	receipt := os.real_path(required_option(args, '--receipt')!)
	source := os.real_path(required_option(args, '--source')!)
	flags := os.real_path(required_option(args, '--flags')!)
	output := os.abs_path(required_option(args, '--output')!)
	manifest_path := option_value(args, '--source-manifest', '')!
	inventory_path := option_value(args, '--source-inventory', '')!
	components := repeated_options(args, '--parsed-component')!
	if (manifest_path == '') != (inventory_path == '') {
		return error('Source manifest and source inventory must be supplied together')
	}
	if components.len > 0 && manifest_path == '' {
		return error('Parsed components require source manifest and inventory')
	}
	manifest := if manifest_path != '' {
		json.decode[map[string]string](os.read_file(manifest_path)!)!
	} else {
		map[string]string{}
	}
	inventory := if inventory_path != '' {
		json.decode[SourceInventory](os.read_file(inventory_path)!)!
	} else {
		SourceInventory{}
	}
	mut data := prepare_frozen_compile(root, stage, receipt, source, flags, output, manifest, inventory, components)!
	validate_frozen_compile(repo, receipt, data.source_inputs, false)!
	code := os.system_args(data.compiler_command)
	data.compiler_exit = code
	data.complete = code == 0
	atomic_write_json_text(os.join_path(receipt, 'frozen-compile.json'), json.encode(data))!
	if code != 0 { return code }
	validate_frozen_compile(repo, receipt, data.source_inputs, true)!
	println('Compiled the verified preprocessed production inputs')
	return 0
}
