module libjs

import dl
import os
import crypto.rand
import crypto.sha256

pub struct NativeWarmupSource {
pub:
	code string
	filename string
	kind SourceType
	line u32 = 1
}

fn native_site_cache_path(directory string, identity string) string {
	return os.join_path(directory, 'site-v1-' + sha256.hexhash(identity) + '.ready')
}

fn native_site_cache_directory(root string, options NativeCodeCacheOptions) !string {
	base := native_cache_abi()!
	abi := if options.generated_code_identity { sha256.hexhash('native-generated-code-v1:' + base) } else { base }
	return os.join_path(root, abi)
}

pub fn native_site_cache_ready(root string, identity string, options NativeCodeCacheOptions) bool {
	directory := native_site_cache_directory(root, options) or { return false }
	marker := native_site_cache_path(directory, identity)
	if !os.is_file(marker) || os.file_size(marker) > 128 * 65 { return false }
	contents := os.read_file(marker) or { return false }
	if contents == '' { return false }
	return contents.split('\n').all(native_site_program_exists(directory, it))
}

fn native_site_program_exists(directory string, key string) bool {
	if !valid_native_digest(key) { return false }
	path := os.join_path(directory, key + '.json')
	if !os.is_file(path) || os.file_size(path) > 16384 { return false }
	data := os.read_file(path) or { return false }
	record := decode_native_cache_record(data) or { return false }
	return record.key == key && record.abi == os.file_name(directory)
		&& record.library.ends_with(dl.dl_ext) && valid_native_digest(record.library.all_before_last(dl.dl_ext))
		&& os.is_file(os.join_path(directory, record.library))
}

// Compile detached source records. A fresh realm supplies compiler layouts
// and receives no DOM, fetch callbacks or author execution.
pub fn compile_native_site_cache(root string, identity string, compiler string,
	options NativeCodeCacheOptions, sources []NativeWarmupSource) ! {
	if sources.len == 0 || sources.len > 128 { return error('Invalid native site source count') }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.enable_native_code_cache_with_options(root, compiler, options)!
	defer { vm.close_native_code() or {} }
	mut tier := vm.native_tier or { return error('Missing native tier') }
	mut cache := tier.persistent or { return error('Missing disk cache') }
	mut keys := []string{cap: sources.len}
	for source in sources {
		keys << prepare_site_program(mut vm, mut cache, vm.realm(), source)!
	}
	vm.flush_native_code_cache()!
	marker := native_site_cache_path(cache.directory, identity)
	temporary := marker + '.' + rand.bytes(16)!.hex() + '.tmp'
	defer { os.rm(temporary) or {} }
	os.write_file(temporary, keys.join('\n'))!
	os.mv(temporary, marker)!
}

fn prepare_site_program(mut vm VM, mut cache NativeCodeCache, realm &Realm, source NativeWarmupSource) !string {
	parsed := parse_source_with_options(source.code, source.kind, ParseOptions{max_recursion_depth: 256})
	if parsed.has_errors() || parsed.reached_recursion_limit { return error('Unsupported LibJS script syntax') }
	mut context := ExecutionContext.create(0, [], 0)
	context.realm = realm
	context.lexical_environment = Environment(realm.global_environment_record())
	context.variable_environment = context.lexical_environment
	mut script := &Script{realm: realm, filename: source.filename, starting_line: source.line,
		parsed: parsed, is_strict_mode: parsed.is_strict_mode}
	mut module_record := &SourceTextModule{module_realm: realm, module_filename: source.filename,
		parsed: parsed, module_starting_line: source.line}
	context.script_or_module = if source.kind == .module {
		ScriptOrModule.from_module(Module(module_record))
	} else {
		ScriptOrModule.from_script(script)
	}
	vm.push_execution_context_checked(mut context)!
	defer { vm.pop_current_context() }
	executable := if source.kind == .module { module_record.compile_module(mut vm)! } else { script.compile(mut vm)! }
	key := cache.key(executable)
	if key == '' { return error('Missing native program key') }
	if !native_site_program_exists(cache.directory, key) {
		cache.pending[key] = executable
	}
	_ = prepare_native_source_templates(mut vm, mut cache, executable, source.filename,
		0, 128)!
	return key
}
