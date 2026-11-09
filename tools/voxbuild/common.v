module main

import crypto.sha256
import hash
import os
import rand
import strings

struct CommandResult {
	exit_code int
	stdout    string
	stderr    string
}

fn make_directory(path string) ! {
	os.mkdir_all(path)!
}

fn make_temp_directory(parent string, prefix string) !string {
	make_directory(parent)!
	for _ in 0 .. 10 {
		path := os.join_path(parent, prefix + rand.uuid_v4())
		os.mkdir(path, mode: 0o700) or { continue }
		return path
	}
	return error('Cannot create a temporary directory in ${parent}')
}

fn write_if_changed(path string, content string) ! {
	if os.is_link(path) {
		os.rm(path)!
	}
	if os.is_file(path) && os.read_file(path)! == content {
		return
	}
	make_directory(os.dir(path))!
	os.write_file(path, content)!
}

fn hash_file(path string) !string {
	mut digest := sha256.new()
	return file_digest(path, mut digest)
}

// Generated C and native archives can be large. The tool has no collector,
// so reuse and release one bounded buffer instead of retaining whole files.
fn file_digest(path string, mut digest hash.Hash) !string {
	defer { unsafe { digest.free() } }
	mut file := os.open(path)!
	defer { file.close() }
	mut buffer := []u8{len: 1024 * 1024}
	defer { unsafe { buffer.free() } }
	for {
		count := file.read(mut buffer) or {
			if err is os.Eof { break }
			return err
		}
		if count == 0 { break }
		digest.write(buffer[..count])!
	}
	return digest.sum([]u8{}).hex()
}

fn shell_quote(value string) string {
	return "'" + value.replace("'", '\'"\'"\'') + "'"
}

fn command_line(args []string) string {
	return args.map(shell_quote(it)).join(' ')
}

// Parse literal shell words as used by pkg-config and CC/CXX, without evaluating
// variables, substitutions, globs, or any other shell code.
fn shell_split(text string) ![]string {
	mut words := []string{}
	mut word := strings.new_builder(text.len)
	mut quote := u8(0)
	mut active := false
	mut index := 0
	for index < text.len {
		ch := text[index]
		if quote == `'` {
			if ch == `'` { quote = 0 } else { word.write_u8(ch) }
		} else if ch == `\\` {
			if index + 1 == text.len { return error('Trailing escape in command flags') }
			if quote == `"` && text[index + 1] !in [`$`, u8(96), `"`, `\\`, `\n`] {
				word.write_u8(ch)
			} else {
				index++
				if text[index] != `\n` { word.write_u8(text[index]) }
			}
			active = true
		} else if quote == `"` {
			if ch == `"` { quote = 0 } else { word.write_u8(ch) }
		} else if ch in [`'`, `"`] {
			quote = ch
			active = true
		} else if ch in [` `, `\t`, `\r`, `\n`] {
			if active {
				words << word.str()
				word = strings.new_builder(text.len - index)
				active = false
			}
		} else {
			word.write_u8(ch)
			active = true
		}
		index++
	}
	if quote != 0 { return error('Unterminated quote in command flags') }
	if active { words << word.str() }
	return words
}

fn run_command(args []string) ! {
	if args.len == 0 { return error('Empty command') }
	code := os.system_args(args)
	if code != 0 { return error('Command failed (exit ${code}): ${command_line(args)}') }
}

// File redirection keeps both streams independent and avoids full-pipe
// deadlocks. Arguments are passed literally; the shell program is constant.
fn capture_result(args []string) !CommandResult {
	if args.len == 0 { return error('Empty command') }
	work := make_temp_directory(os.temp_dir(), 'vox-build-capture-')!
	defer { os.rmdir_all(work) or {} }
	out := os.join_path(work, 'stdout')
	err := os.join_path(work, 'stderr')
	code := os.system_args(['sh', '-c', r'out=$1; err=$2; shift 2; exec "$@" >"$out" 2>"$err"',
		'vox-build-capture', out, err, ...args])
	return CommandResult{
		exit_code: code
		stdout:    os.read_file(out) or { '' }
		stderr:    os.read_file(err) or { '' }
	}
}

fn capture_command(args []string) !string {
	result := capture_result(args)!
	if result.exit_code != 0 {
		return error('Command failed (exit ${result.exit_code}): ${command_line(args)}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}')
	}
	return result.stdout
}

fn compiler_vlib(compiler string, work string) !string {
	temporary := make_temp_directory(work, 'compiler-root-')!
	defer { os.rmdir_all(temporary) or {} }
	probe := os.join_path(temporary, 'compiler_root.v')
	os.write_file(probe, 'module main\nfn main() { println(@VEXEROOT) }\n')!
	// The probe can live below Vox's v.mod. Its introspection needs the checked
	// frontend even when the browser selects FastC.
	mut command := [compiler, '-b', 'c', '-memory-limit', '10G', '-gc', 'none']
	$if linux {
		command << ['-cc', env_default('CC', 'clang')]
	}
	command << ['run', probe]
	result := capture_result(command)!
	diagnostics := 'Command: ${command_line(command)}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}'
	if result.exit_code != 0 {
		return error('V compiler root probe failed (exit ${result.exit_code}).\n${diagnostics}\nCheck that V_BIN selects a current V compiler and its C toolchain is available.')
	}
	root := result.stdout.trim_space()
	if root.split_into_lines().len != 1 || !os.is_abs_path(root) {
		return error('V compiler root probe did not report one absolute root.\n${diagnostics}')
	}
	vlib := os.join_path(os.real_path(root), 'vlib')
	if !os.is_dir(vlib) {
		return error('V compiler root probe reported a root without a vlib directory: ${vlib}\n${diagnostics}')
	}
	return vlib
}

fn env_default(name string, fallback string) string {
	value := os.getenv(name)
	return if value.len > 0 { value } else { fallback }
}

fn option_value(args []string, name string, fallback string) !string {
	index := args.index(name)
	if index < 0 { return fallback }
	if index + 1 >= args.len { return error('Missing value for ${name}') }
	return args[index + 1]
}

fn required_option(args []string, name string) !string {
	value := option_value(args, name, '')!
	if value == '' { return error('Missing required option ${name}') }
	return value
}

fn repeated_options(args []string, name string) ![]string {
	mut values := []string{}
	for index, token in args {
		if token == name {
			if index + 1 == args.len { return error('Missing value for ${name}') }
			values << args[index + 1]
		}
	}
	return values
}

fn command_after(args []string, marker string) ![]string {
	index := args.index(marker)
	if index < 0 || index + 1 >= args.len { return error('Expected ${marker} COMMAND...') }
	return args[index + 1..].clone()
}
