// SPDX-License-Identifier: BSD-2-Clause
// Verify the independent, checked-in reference records through V modules.
module main

import flag
import json2
import os
import time

const regex_corpus_cases = [
	'libjs/regex_assertion_corpus_test.v',
	'libjs/regex_backtrack_corpus_test.v',
	'libjs/regex_class_corpus_test.v',
	'libjs/regex_core_corpus_test.v',
	'libjs/regex_engine_corpus_test.v',
	'libjs/regex_hints_corpus_test.v',
	'libjs/regex_matching_corpus_test.v',
	'libjs/regex_predicate_corpus_test.v',
	'libjs/regex_property_corpus_test.v',
	'libjs/regex_scan_corpus_test.v',
	'libjs/regex_state_corpus_test.v',
	'libjs/regex_parser_test.v',
	'libjs/regex_parser_flags_test.v',
	'libjs/regex_compile_execute_test.v',
	'libjs/regex_empty_set_repetition_test.v',
	'libjs/regexp_preparation_corpus_test.v',
	'libregex',
]

fn corpus_cases(suite string) ![]string {
	return match suite {
		'encoding' { ['encoding'] }
		'replacement' { ['encoding/replacement_decoder_test.v'] }
		'regex' { regex_corpus_cases.clone() }
		'yuv' { ['yuv'] }
		'gb18030' { ['tools/gb18030gen'] }
		'all' {
			mut selected := ['encoding', 'yuv', 'tools/gb18030gen']
			selected << regex_corpus_cases
			selected
		}
		else {
			return error('Unknown suite: ${suite}. Choose all, encoding, replacement, regex, yuv or gb18030.')
		}
	}
}

fn check_corpora() int {
	mut options := flag.new_flag_parser(os.args)
	options.application('check_translation_corpora')
	options.description('Check frozen independent reference records using V. This command never refreshes reference data.')
	options.skip_executable()
	suite := options.string('suite', `s`, 'all', 'Reference group: all, encoding, replacement, regex, yuv, gb18030')
	gc_mode := options.string('gc', 0, 'boehm', 'Heap mode: boehm or none')
	default_compiler := os.getenv_opt('V_BIN') or { os.getenv_opt('VEXE') or { 'v' } }
	compiler := options.string('compiler', 0, default_compiler, 'Current V compiler executable')
	jobs := options.int('jobs', `j`, 1, 'V test compilation jobs (1 through 4)')
	dry_run := options.bool('dry-run', 0, false, 'Print the exact test argv without running it')
	remaining := options.finalize() or {
		eprintln(err)
		return 1
	}
	if remaining.len > 0 || gc_mode !in ['boehm', 'none'] || jobs < 1 || jobs > 4 {
		eprintln('Use --gc boehm|none and --jobs 1..4; positional arguments are not supported.')
		return 1
	}
	cases := corpus_cases(suite) or {
		eprintln(err)
		return 1
	}
	for path in cases {
		if !os.exists(os.join_path(@VMODROOT, path)) {
			eprintln('Missing corpus test: ${path}')
			return 1
		}
	}
	mut command := [compiler, '-memory-limit', '10G', '-enable-globals', '-b', 'c', '-cc', 'clang',
		'-gc', gc_mode, 'test']
	command << cases
	if dry_run {
		println(json2.encode(command, escape_unicode: true, time_as_unix: true))
		return 0
	}
	job := os.join_path(@VMODROOT, 'Build', 'translation-corpora-${os.getpid()}-${time.now().unix_milli()}')
	lock_path := job + '.lock'
	report_path := job + '.json'
	defer {
		os.rm(lock_path) or {}
		os.rm(report_path) or {}
	}
	os.setenv('VJOBS', jobs.str(), true)
	os.setenv('V_MACOS_V3_NO_FALLBACK', '1', true)
	mut process := os.new_process('python3')
	process.set_work_folder(@VMODROOT)
	mut guarded := [os.join_path(@VMODROOT, 'tools/run_memory_bounded.py'), '--lock', lock_path,
		'--report', report_path, '--limit-gib', '3', '--']
	guarded << command
	process.set_args(guarded)
	process.run()
	process.wait()
	code := process.code
	process.close()
	return code
}

fn main() { exit(check_corpora()) }
