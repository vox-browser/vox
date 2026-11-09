module main

import os

struct BootstrapFixture {
	root     string
	script   string
	compiler string
	log      string
	template string
	source   string
}

fn bootstrap_fixture() !BootstrapFixture {
	root := make_temp_directory(os.temp_dir(), 'vox-bootstrap-test-')!
	script := os.join_path(root, 'tools/vox-build.sh')
	compiler := os.join_path(root, 'bin/v')
	log := os.join_path(root, 'compiler.log')
	template := os.join_path(root, 'tool.sh')
	source := os.join_path(root, 'tools/voxbuild/main.v')
	make_directory(os.dir(source))!
	make_directory(os.dir(compiler))!
	os.cp(os.join_path(@VMODROOT, '../vox-build.sh'), script)!
	os.write_file(source, 'module main\nfn main() {}\n')!
	os.write_file(template, [
		r'printf "compiler=%s\ncc=%s\nv_bin=%s\ntool=%s\narg=%s\n" "$compiled_id" "$compiled_cc" "${V_BIN-unset}" "$VOX_BUILD_TOOL" "${1-}"',
	].join('\n') + '\n')!
	os.write_file(compiler, [
		'#!/bin/sh',
		'set -eu',
		r'[ "$1" = -b ] && [ "$2" = c ] || exit 93',
		r'printf "%s\n" "$$" >> "$BOOTSTRAP_LOG"',
		r'if [ "${BOOTSTRAP_BARRIER:-0}" = 1 ]; then',
		'    attempts=0',
		r'    while [ "$(wc -l < "$BOOTSTRAP_LOG")" -lt 2 ]; do',
		r'        attempts=$((attempts + 1))',
		r'        [ "$attempts" -lt 100 ] || exit 95',
		'        sleep 0.05',
		'    done',
		'fi',
		'output=',
		r'while [ "$#" -gt 0 ]; do',
		r'    if [ "$1" = -o ]; then output=$2; break; fi',
		'    shift',
		'done',
		r'[ -n "$output" ] || exit 94',
		r'printf "compiler stdout\n"',
		r'printf "#!/bin/sh\ncompiled_id=%s\ncompiled_cc=%s\n" "$$" "$CC" > "$output"',
		r'cat "$BOOTSTRAP_TEMPLATE" >> "$output"',
		r'if [ "${BOOTSTRAP_CHANGE_INPUT:-0}" = 1 ]; then',
		r'    printf "// changed during compilation\n" >> "$BOOTSTRAP_SOURCE"',
		'fi',
	].join('\n') + '\n')!
	os.chmod(compiler, 0o755)!
	return BootstrapFixture{root, script, compiler, log, template, source}
}

fn bootstrap_command(fixture BootstrapFixture, extra map[string]string) []string {
	mut command := ['env', '-u', 'V_BIN', '-u', 'VFLAGS', '-u', 'VOX_BUILD_ROOT', '-u', 'VOX_BUILD_TOOL',
		'CC=cc', 'PATH=' + os.dir(fixture.compiler) + ':' + os.getenv('PATH'),
		'BOOTSTRAP_LOG=' + fixture.log, 'BOOTSTRAP_TEMPLATE=' + fixture.template,
		'BOOTSTRAP_SOURCE=' + fixture.source]
	for key, value in extra { command << key + '=' + value }
	command << ['sh', fixture.script, 'literal argument with spaces']
	return command
}

fn bootstrap_values(output string) map[string]string {
	mut values := map[string]string{}
	for line in output.split_into_lines() {
		assert line.contains('='), 'Bootstrap compiler output leaked into the stdout protocol: ${line}'
		values[line.all_before('=')] = line.all_after('=')
	}
	return values
}

fn test_bootstrap_keeps_implicit_and_explicit_compiler_selection_distinct() ! {
	fixture := bootstrap_fixture()!
	defer { os.rmdir_all(fixture.root) or {} }
	implicit := capture_result(bootstrap_command(fixture, {}))!
	assert implicit.exit_code == 0, implicit.stderr
	assert implicit.stderr.contains('compiler stdout')
	first := bootstrap_values(implicit.stdout)
	assert first['v_bin'] == 'unset'
	assert first['arg'] == 'literal argument with spaces'
	assert os.is_executable(first['tool'])
	assert !os.is_link(first['tool'])
	explicit := capture_result(bootstrap_command(fixture, {
		'V_BIN': fixture.compiler
	}))!
	assert explicit.exit_code == 0, explicit.stderr
	second := bootstrap_values(explicit.stdout)
	assert second['v_bin'] == fixture.compiler
	assert second['tool'] == first['tool']
	assert second['compiler'] == first['compiler']
	assert os.read_lines(fixture.log)!.len == 1
}

fn test_bootstrap_preserves_active_executables_when_inputs_change() ! {
	fixture := bootstrap_fixture()!
	defer { os.rmdir_all(fixture.root) or {} }
	before := bootstrap_values(capture_command(bootstrap_command(fixture, {}))!)
	old_path := before['tool']
	old_hash := hash_file(old_path)!
	os.write_file(fixture.source, 'module main\nfn main() { println("changed") }\n')!
	after := bootstrap_values(capture_command(bootstrap_command(fixture, {}))!)
	assert after['tool'] != old_path
	assert hash_file(old_path)! == old_hash
	old_run := capture_command(['env', 'VOX_BUILD_TOOL=' + old_path, old_path])!
	assert bootstrap_values(old_run)['compiler'] == before['compiler']
	assert os.read_lines(fixture.log)!.len == 2
	// Returning to a cached checkout must also refresh the convenient path
	// used by standalone integration checks, without rebuilding the tool.
	os.write_file(fixture.source, 'module main\nfn main() {}\n')!
	restored := bootstrap_values(capture_command(bootstrap_command(fixture, {}))!)
	assert restored['tool'] == old_path
	assert os.real_path(os.join_path(fixture.root, 'Build/tools/vox-build')) == old_path
	assert os.read_lines(fixture.log)!.len == 2
}

fn test_concurrent_bootstraps_publish_one_immutable_executable_per_identity() ! {
	fixture := bootstrap_fixture()!
	defer { os.rmdir_all(fixture.root) or {} }
	first := os.join_path(fixture.root, 'first.out')
	second := os.join_path(fixture.root, 'second.out')
	command := bootstrap_command(fixture, {
		'BOOTSTRAP_BARRIER': '1'
	})
	parallel := [
		r'first=$1; second=$2; shift 2',
		r'"$@" > "$first" & first_pid=$!',
		r'"$@" > "$second" & second_pid=$!',
		r'wait "$first_pid"; first_status=$?',
		r'wait "$second_pid"; second_status=$?',
		r'[ "$first_status" = 0 ] && [ "$second_status" = 0 ]',
	].join('\n')
	result := capture_result(['sh', '-c', parallel, 'parallel-bootstrap', first, second, ...command])!
	assert result.exit_code == 0, result.stderr
	left := bootstrap_values(os.read_file(first)!)
	right := bootstrap_values(os.read_file(second)!)
	assert left['tool'] == right['tool']
	assert left['compiler'] == right['compiler']
	assert !os.is_link(left['tool'])
	assert os.read_lines(fixture.log)!.len == 2
	stable := bootstrap_values(capture_command(bootstrap_command(fixture, {}))!)
	assert stable['tool'] == left['tool']
	assert stable['compiler'] == left['compiler']
	assert os.read_lines(fixture.log)!.len == 2
}

fn test_bootstrap_rejects_inputs_changed_during_compilation() ! {
	fixture := bootstrap_fixture()!
	defer { os.rmdir_all(fixture.root) or {} }
	result := capture_result(bootstrap_command(fixture, {
		'BOOTSTRAP_CHANGE_INPUT': '1'
	}))!
	assert result.exit_code != 0
	assert result.stderr.contains('Build tool sources changed during compilation')
	assert result.stdout == ''
	assert os.ls(os.join_path(fixture.root, 'Build/tools'))!.len == 0
}
