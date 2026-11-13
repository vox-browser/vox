module buildtools

import os
import json2 as json

fn parallel_command(args []string) !int {
	a := arguments(args, []string{})!
	receipt := a.required('--receipt')!
	output := a.required('--output')!
	if a.command.len < 2 { return error('Expected -- V_COMPILER ... INPUT') }
	selected := a.command[0]
	options := a.command[1..a.command.len - 1]
	source := a.command.last()
	mut record := map[string]json.Any{
		'requested': 'parallel'
		'compiler':  selected
		'v_prod':    '-prod' in options
	}
	if !read(selected)!.contains('V3_PARALLEL_CC_REQUIRE_SPLIT') {
		record['mode'] = 'single'
		record['fallback'] = '${selected} cannot split programs with native project headers (no V3_PARALLEL_CC_REQUIRE_SPLIT support)'
		write_json(join(receipt, 'c-compile.json'), json.Any(record))!
		println('Parallel C: ' + (record['fallback'] or { json.Null{} }).str() + '; compiling one C unit.')
		return 0
	}
	mut env := os.environ()
	env['V3_PARALLEL_CC_REQUIRE_SPLIT'] = '1'
	mut process := os.new_process(selected)
	process.set_args([...options, '-parallel-cc', '-o', output, source])
	process.set_environment(env)
	process.set_redirect_stdio_merged()
	process.run()
	// Drain incrementally so an active compiler cannot fill its stdout pipe.
	mut text := ''
	for {
		line := process.stdout_read()
		if line.len > 0 {
			print(line)
			text += line
		}
		if !process.is_alive() {
			remaining := process.stdout_slurp()
			print(remaining)
			text += remaining
			break
		}
	}
	process.wait()
	code := process.code
	process.close()
	if code == 3 && text.contains('cannot split this program into C units') {
		remove(output)!
		reasons := text.split_into_lines().filter(it.starts_with('parallel C:') || it.starts_with('  ')).map(it.trim_space())
		record['mode'] = 'single'
		record['fallback'] = 'native code would be duplicated in every C unit'
		record['reasons'] = any_strings(reasons[..if reasons.len > 41 { 41 } else { reasons.len }])
		write_json(join(receipt, 'c-compile.json'), json.Any(record))!
		return 0
	}
	if code != 0 || !os.is_file(output) {
		record['mode'] = 'failed'
		record['exit'] = if code != 0 { code } else { 1 }
		write_json(join(receipt, 'c-compile.json'), json.Any(record))!
		return if code != 0 { code } else { 1 }
	}
	mut units := json.Any(json.Null{})
	for line in text.split_into_lines() {
		if line.starts_with('parallel C: ') && line.contains(' units') {
			units = line.all_after('parallel C: ').all_before(' units').int()
			break
		}
	}
	record['mode'] = 'parallel'
	record['units'] = units
	write_json(join(receipt, 'c-compile.json'), json.Any(record))!
	return 0
}
