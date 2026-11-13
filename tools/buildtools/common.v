module buildtools

import os
import time
import crypto.sha256
import json2 as json

pub type Record = map[string]json.Any

pub fn root_dir() string { return os.real_path(os.join_path(@VMODROOT, '')) }

fn join(parts ...string) string { return os.join_path(...parts) }

fn read(path string) !string { return os.read_file(path) }

fn hash(data string) string { return sha256.hexhash(data) }

fn digest(path string) !string { return hash(read(path)!) }

fn absolute(path string) string { return os.abs_path(path) }

fn real(path string) string { return os.real_path(absolute(path)) }

fn exists(path string) bool { return os.exists(path) || os.is_link(path) }

fn mkdir(path string) ! { os.mkdir_all(path)! }

fn remove(path string) ! {
	if os.is_link(path) || os.is_file(path) {
		os.rm(path)!
	} else if os.is_dir(path) {
		os.rmdir_all(path)!
	}
}

fn temporary(parent string, prefix string) !string {
	mkdir(parent)!
	path := join(parent, prefix + '${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir(path)!
	return path
}

fn atomic_write(path string, data string) ! {
	mkdir(os.dir(path))!
	tmp := path + '.tmp-${os.getpid()}-${time.sys_mono_now()}'
	defer { if exists(tmp) { os.rm(tmp) or {} } }
	os.write_file(tmp, data)!
	os.rename(tmp, path)!
}

fn write_changed(path string, data string) ! {
	if os.is_link(path) { os.rm(path)! }
	if !os.is_file(path) || read(path)! != data { atomic_write(path, data)! }
}

fn load(path string) !Record { return json.parse(read(path)!)!.as_map() }

fn maybe_load(path string) Record { return load(path) or { Record{} } }

fn write_json(path string, value json.Any) ! {
	atomic_write(path, json.encode(value, prettify: true) + '\n')!
}

fn string_map(value json.Any) map[string]string { return value.as_map_of_strings() }

fn strings(value json.Any) []string { return value.as_array().map(it.str()) }

fn any_strings(values []string) json.Any { return json.Any(values.map(json.Any(it))) }

fn record_strings(values map[string]string) json.Any {
	mut result := Record{}
	for key, value in values { result[key] = value }
	return json.Any(result)
}

fn listing(path string) ![]string {
	if !os.is_dir(path) { return []string{} }
	mut names := os.ls(path)!
	names.sort()
	return names.map(join(path, it))
}

fn files(path string) ![]string {
	mut result := []string{}
	for entry in listing(path)! {
		if os.is_dir(entry) {
			if !os.is_link(entry) { result << files(entry)! }
		} else {
			result << entry
		}
	}
	result.sort()
	return result
}

fn relative(path string, base string) string {
	return path.trim_string_left(base.trim_right('/') + '/')
}

fn link_to(path string, source string) ! {
	if os.is_link(path) {
		if real(path) == real(source) { return }
		os.rm(path)!
	} else if os.is_dir(path) {
		return error('Refusing to replace directory with module link: ${path}')
	} else if exists(path) {
		os.rm(path)!
	}
	mkdir(os.dir(path))!
	os.symlink(absolute(source), path)!
}

fn link_files(path string, source string) ! {
	if os.is_link(path) || os.is_file(path) { os.rm(path)! }
	mkdir(path)!
	for entry in listing(source)! {
		target := join(path, os.file_name(entry))
		if os.is_dir(entry) { link_files(target, entry)! } else { link_to(target, entry)! }
	}
}

fn compiler() string {
	name := os.getenv_opt('V_BIN') or { 'v' }
	return os.find_abs_path_of_executable(name) or { join(os.home_dir(), 'code/v/v') }
}

fn platform() string { return if os.user_os() == 'macos' { 'v' } else { os.user_os() } }

fn state_dir(root string) string {
	return if os.user_os() == 'linux' {
		join(root, 'Build/linux/production-build')
	} else {
		join(root, 'Build/production-build')
	}
}

fn quote(value string) string { return "'" + value.replace("'", "'\\''") + "'" }

fn shell_join(args []string) string { return args.map(quote(it)).join(' ') }

fn shell_split(text string) ![]string {
	mut words := []string{}
	mut word := ''
	mut q := u8(0)
	mut escaped := false
	mut started := false
	for c in text.bytes() {
		if escaped {
			word += c.ascii_str()
			escaped = false
			started = true
			continue
		}
		if c == `\\` && q != `'` {
			escaped = true
			started = true
			continue
		}
		if q != 0 {
			if c == q { q = 0 } else { word += c.ascii_str() }
			continue
		}
		if c == `'` || c == `"` {
			q = c
			started = true
		} else if c.is_space() {
			if started {
				words << word
				word = ''
				started = false
			}
		} else {
			word += c.ascii_str()
			started = true
		}
	}
	if escaped || q != 0 { return error('Unterminated shell word') }
	if started { words << word }
	return words
}

fn capture(args []string) !string {
	if args.len == 0 { return error('Missing command') }
	mut p := os.new_process(args[0])
	p.set_args(args[1..])
	p.set_redirect_stdio()
	p.run()
	output := p.stdout_slurp()
	errors := p.stderr_slurp()
	p.wait()
	code := p.code
	p.close()
	if code != 0 {
		return error('Command failed (${code}): ${shell_join(args)}\n${errors}${output}')
	}
	return output
}

fn execute(args []string) int { return os.system_args(args) }

fn checked(args []string) ! {
	code := execute(args)
	if code != 0 { return error('Command failed (${code}): ${shell_join(args)}') }
}

fn git(root string, args ...string) !string {
	mut env := os.environ()
	for key, _ in env { if key.starts_with('GIT_') { env.delete(key) } }
	mut p := os.new_process('git')
	p.set_args(['-C', root, ...args])
	p.set_environment(env)
	p.set_redirect_stdio()
	p.run()
	output := p.stdout_slurp()
	errors := p.stderr_slurp()
	p.wait()
	code := p.code
	p.close()
	if code != 0 { return error('Git failed (${code}): ${errors}') }
	return output
}

fn fingerprint(paths []string) !map[string]string {
	mut result := map[string]string{}
	for path in paths { result[real(path)] = digest(path)! }
	return result
}

fn check_fingerprints(expected map[string]string) ! {
	for path, sha in expected {
		if !os.is_file(path) || digest(path)! != sha {
			return error('Frozen build input changed: ${path}')
		}
	}
}

fn replace_once(source string, old string, new string) !string {
	if source.count(old) != 1 {
		return error('Unsupported adapter source: expected one ${old.limit(100)}')
	}
	return source.replace_once(old, new)
}

fn function_span(source string, signature string) !(int, int) {
	start := source.index(signature) or { return error('Missing function: ${signature}') }
	if source[start + signature.len..].contains(signature) {
		return error('Ambiguous function: ${signature}')
	}
	end := source.index_after('\n}', start) or { return error('Missing function end: ${signature}') }
	return start, end + 2
}

fn replace_function(source string, signature string, replacement string) !string {
	start, end := function_span(source, signature)!
	return source[..start] + replacement.trim_space() + source[end..]
}

struct Args {
mut:
	options     map[string][]string
	positionals []string
	command     []string
}

fn arguments(args []string, flags []string) !Args {
	mut result := Args{}
	mut i := 0
	for i < args.len {
		arg := args[i]
		if arg in ['--', '--command'] {
			result.command = args[i + 1..].clone()
			break
		}
		if arg.starts_with('--') {
			if arg in flags {
				result.options[arg] << 'true'
			} else {
				i++
				if i >= args.len { return error('Missing value for ${arg}') }
				result.options[arg] << args[i]
			}
		} else {
			result.positionals << arg
		}
		i++
	}
	return result
}

fn (a Args) get(key string, fallback string) string {
	values := a.options[key]
	return if values.len > 0 { values.last() } else { fallback }
}

fn (a Args) has(key string) bool { return key in a.options }

fn (a Args) required(key string) !string {
	value := a.get(key, '')
	if value == '' { return error('Required argument: ${key}') }
	return value
}

fn (a Args) positional(index int, fallback string) string {
	return if index < a.positionals.len { a.positionals[index] } else { fallback }
}

fn trimmed_eq(value string, expected string) bool {
	text := value.trim_space()
	return text == expected
}

fn unique_strings(values []string) []string {
	mut result := []string{}
	for value in values { if value !in result { result << value } }
	return result
}

fn build_cache(parts ...string) string {
	base := os.getenv_opt('VOX_BUILD_TOOLS_CACHE_ROOT') or { join(root_dir(), 'Build') }
	mut path := base
	for part in parts { path = os.join_path(path, part) }
	return path
}
