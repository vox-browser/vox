module main

import crypto.sha256
import encoding.utf8
import json2
import os
import time

struct SourceInventory {
	protocol     string
	names        []string
	early_inputs map[string]string
}

struct ParsedBufferProof {
	protocol           string
	sources            map[string]string
	compiler           map[string]string
	verified_unix      f64
	package_membership []string
}

fn source_is_v(path string) bool {
	return os.file_ext(path) in ['.v', '.vv', '.vsh']
}

fn source_is_build_tool(path string) bool {
	return path.starts_with('tools/voxbuild/')
}

fn production_input_names(root string) ![]string {
	listing := supervisor_git(root, ['ls-files', '-z', '--cached', '--others', '--exclude-standard'])!
	if !utf8.validate_str(listing) {
		return error('Production source names are not valid UTF-8')
	}
	mut names := []string{}
	mut seen := map[string]bool{}
	for name in listing.split('\x00') {
		if name == '' || name in seen || name.ends_with('.swp') || name.contains('.v3cc.')
			|| (name.starts_with('tools/') && name.ends_with('.py')) || !production_input_path(name) {
			continue
		}
		seen[name] = true
		names << name
	}
	names.sort()
	return names
}

fn begin_source_inventory(root string) !SourceInventory {
	names := production_input_names(root)!
	mut early := map[string]string{}
	for name in names {
		path := os.join_path(root, name)
		if os.is_file(path) && (!source_is_v(name) || source_is_build_tool(name) || os.is_link(path)) {
			// Preserve the lexical symlink path so changing its target is checked.
			early[path] = hash_file(path)!
		}
	}
	tool := os.getenv('VOX_BUILD_TOOL')
	if tool != '' {
		path := os.abs_path(tool)
		if !os.is_file(path) {
			return error('Build tool is unavailable: ${path}')
		}
		early[path] = hash_file(path)!
	}
	return SourceInventory{
		protocol:     'production-source-inventory-v1'
		names:        names
		early_inputs: early
	}
}

fn validate_source_inventory(root string, inventory SourceInventory, parsed bool) ! {
	if inventory.protocol != 'production-source-inventory-v1' || inventory.names.len == 0 {
		return error('Incomplete production source inventory')
	}
	mut names := production_input_names(root)!
	mut original := inventory.names.clone()
	if parsed {
		// Build-tool V files were consumed before the browser parse. Their bytes
		// and membership remain pinned even when later browser edits are allowed.
		names = names.filter(!source_is_v(it) || source_is_build_tool(it))
		original = original.filter(!source_is_v(it) || source_is_build_tool(it))
	}
	if names != original {
		return error('Production source membership changed')
	}
	check_fingerprints(inventory.early_inputs)!
}

fn source_digest_valid(digest string) bool {
	if digest.len != 64 {
		return false
	}
	for ch in digest.bytes() {
		if !ch.is_digit() && (ch < `a` || ch > `f`) {
			return false
		}
	}
	return true
}

fn component_inputs(directory string) !map[string]string {
	name_bytes := os.read_file(os.join_path(directory, 'v_sources'))!
	digest_bytes := os.read_file(os.join_path(directory, 'v_source_digests'))!
	if !utf8.validate_str(name_bytes) || !utf8.validate_str(digest_bytes) {
		return error('Invalid UTF-8 compiler source manifest: ${directory}')
	}
	names := name_bytes.split('\x00')
	digests := digest_bytes.split('\x00')
	if names.len != digests.len || names.len == 0 || names[0] == '' {
		return error('Incomplete compiler source manifest: ${directory}')
	}
	mut result := map[string]string{}
	for index, raw_name in names {
		digest := digests[index]
		if !source_digest_valid(digest) {
			return error('Invalid compiler source digest: ${raw_name}')
		}
		if raw_name == '@native-input-manifest:v1' {
			if digest != sha256.hexhash('v3-native-input-manifest-v1') {
				return error('Invalid native source manifest marker')
			}
			continue
		}
		name := raw_name.trim_string_left('@native-input:')
		if !os.is_abs_path(name) || name.starts_with('@') {
			return error('Invalid compiler source path: ${name}')
		}
		if name in result && result[name] != digest {
			return error('Conflicting compiler source digest: ${name}')
		}
		result[name] = digest
	}
	if v_inputs(result).len == 0 {
		return error('Compiler manifest has no V sources')
	}
	return result
}

fn v_inputs(inputs map[string]string) map[string]string {
	mut result := map[string]string{}
	for name, digest in inputs {
		if source_is_v(name) {
			result[name] = digest
		}
	}
	return result
}

fn verified_component(directory string) !map[string]string {
	proof := json2.decode[ParsedBufferProof](os.read_file(os.join_path(directory, 'parsed-verified.json'))!)!
	actual := component_inputs(directory)!
	if proof.protocol != 'verified-parsed-buffers-v1' || !string_maps_equal(proof.sources, v_inputs(actual)) {
		return error('Compiler source buffers changed after verification: ${directory}')
	}
	return actual
}

fn component_membership(root string, names []string, sources map[string]string) []string {
	mut directories := map[string]bool{}
	prefix := root.trim_right('/\\') + os.path_separator
	for name, _ in sources {
		if name.starts_with(prefix) {
			directories[os.dir(name)] = true
		}
	}
	return names.filter(source_is_v(it) && os.dir(os.join_path(root, it)) in directories)
}

fn combine_source_inputs(root string, inventory SourceInventory, components []string, parsed bool) !map[string]string {
	validate_source_inventory(root, inventory, parsed)!
	mut result := inventory.early_inputs.clone()
	for directory in components {
		inputs := if parsed { verified_component(directory)! } else { component_inputs(directory)! }
		for name, digest in inputs {
			if name in result && result[name] != digest {
				return error('Production components consumed different source bytes: ${name}')
			}
			result[name] = digest
		}
	}
	mut live := map[string]string{}
	for name, digest in result {
		if !parsed || !source_is_v(name) || name in inventory.early_inputs {
			live[name] = digest
		}
	}
	check_fingerprints(live)!
	return result
}

fn matches_compiled_source_inventory(root string, inventory SourceInventory, exact map[string]string) bool {
	if inventory.names.len == 0 || exact.len == 0 {
		return false
	}
	validate_source_inventory(root, inventory, false) or { return false }
	check_fingerprints(exact) or { return false }
	return true
}

fn verify_parsed_buffers(root string, inventory SourceInventory, directory string,
	starting_names []string, sources map[string]string, identity map[string]string) !ParsedBufferProof {
	validate_source_inventory(root, inventory, true)!
	membership := component_membership(root, starting_names, sources)
	if component_membership(root, production_input_names(root)!, sources) != membership {
		return error('Consumed V package membership changed during parsing')
	}
	check_fingerprints(sources)!
	if !string_maps_equal(sources, v_inputs(component_inputs(directory)!)) {
		return error('Compiler manifest changed during parsed-buffer verification')
	}
	return ParsedBufferProof{
		protocol:           'verified-parsed-buffers-v1'
		sources:            sources
		compiler:           identity
		verified_unix:      f64(time.now().unix_milli()) / 1000.0
		package_membership: membership
	}
}

fn compile_component(root string, inventory SourceInventory, directory string, command []string) !int {
	if command.len == 0 {
		return error('A compiler command is required')
	}
	mut environment := os.environ()
	environment['V_MACOS_V3_SOURCE_MANIFEST'] = '1'
	environment['V_MACOS_V3_C_ERROR_DIR'] = directory
	identity := fingerprint([os.real_path(command[0])])!
	validate_source_inventory(root, inventory, true)!
	starting_names := production_input_names(root)!
	// Leave stdout/stderr inherited. The supervisor records both streams for
	// production; standalone invocations retain the compiler's own diagnostics.
	mut child := spawn_build_child(command, environment, os.getwd(), '', false, '', false, false)!
	defer {
		if !child.exited {
			C.vox_build_kill(i32(child.pid), 1)
			child.poll(true) or {}
		}
	}
	mut proved := false
	mut failure := ''
	for {
		finished := child.poll(false)!
		if !proved && failure == '' && os.exists(os.join_path(directory, 'v_source_digests')) {
			// V writes names and digests separately. Incomplete pairs are retried
			// until a complete pair can be sealed or compilation finishes.
			if inputs := component_inputs(directory) {
				if proof := verify_parsed_buffers(root, inventory, directory, starting_names, v_inputs(inputs), identity) {
					atomic_write_json_text(os.join_path(directory, 'parsed-verified.json'), json2.encode(proof))!
					proved = true
				} else {
					failure = err.msg()
					atomic_write_json_text(os.join_path(directory, 'verification-error.json'), json2.encode({
						'error': failure
					}))!
				}
			}
		}
		if finished {
			break
		}
		time.sleep(50 * time.millisecond)
	}
	if child.exit_code != 0 {
		return child.exit_code
	}
	check_fingerprints(identity)!
	if failure != '' {
		return error(failure)
	}
	if os.exists(os.join_path(directory, 'v_sources')) {
		verified_component(directory)!
	}
	return 0
}

fn manifest_cli(repo string, args []string) !int {
	if args.len == 0 || args[0] !in ['begin', 'combine', 'compile'] {
		return error('manifest requires begin, combine, or compile')
	}
	action := args[0]
	options := args[1..]
	root := os.abs_path(option_value(options, '--root', repo)!)
	inventory_path := required_option(options, '--inventory')!
	if action == 'begin' {
		delivered := os.join_path(os.dir(inventory_path), 'build-script.json')
		if os.is_file(delivered) {
			values := json2.decode[map[string]string](os.read_file(delivered)!)!
			path := values['path'] or { return error('Missing delivered build-script path') }
			digest := values['sha256'] or { return error('Missing delivered build-script digest') }
			check_fingerprints({
				path: digest
			})!
		}
		atomic_write_json_text(inventory_path, json2.encode(begin_source_inventory(root)!))!
		return 0
	}
	inventory := json2.decode[SourceInventory](os.read_file(inventory_path)!)!
	if action == 'combine' {
		components := repeated_options(options, '--component')!
		if components.len == 0 {
			return error('combine requires components and an output')
		}
		output := required_option(options, '--output')!
		combined := combine_source_inputs(root, inventory, components, '--parsed' in options)!
		atomic_write_json_text(output, json2.encode(combined))!
		return 0
	}
	directory := required_option(options, '--component-dir')!
	return compile_component(root, inventory, directory, command_after(options, '--command')!)
}
