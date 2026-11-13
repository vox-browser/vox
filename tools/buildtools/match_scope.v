module buildtools

import os
import json2 as json

fn needs_match_fix(source string) bool {
	signature := 'fn (mut t Transformer) lower_remaining_matches_in_used_fns() {'
	if !source.contains(signature) { return false }
	return !source.all_after(signature).all_before('\n}').contains('seed_generated_fn_body_context')
}

fn patch_match_compiler(source string) !(string, bool) {
	mut matches := []string{}
	for prefix in ['transform__Transformer', 'v__transform__Transformer'] {
		signature := 'void ${prefix}__lower_remaining_matches_in_used_fns('
		if source.contains(signature) { matches << prefix }
	}
	if matches.len == 0 { return source, false }
	if matches.len != 1 { return error('Ambiguous V late-match implementation') }
	prefix := matches[0]
	start, end := function_span(source, 'void ${prefix}__lower_remaining_matches_in_used_fns(')!
	mut body := source[start..end]
	if body.contains('vox_outer_match_locals') { return source, true }
	body = replace_once(body, 'string old_file = t->cur_file;', 'string old_file = t->cur_file;\n    string vox_outer_match_fn = t->cur_fn_name;\n    __typeof__(t->cur_fn_ret_type) vox_outer_match_ret = t->cur_fn_ret_type;\n    __auto_type vox_outer_match_locals = ${prefix}__detach_function_local_state(t);')!
	body = replace_once(body, 'epoch++;', '\n            t->cur_file = ${prefix}__node_file_or(t, i, old_file);\n            ${prefix}__seed_generated_fn_body_context(t, (i32)i);\n            epoch++;')!
	body = replace_once(body, 't->cur_file = old_file;', 't->cur_file = old_file;\n    t->cur_fn_name = vox_outer_match_fn;\n    ${prefix}__set_cur_fn_ret_type(t, vox_outer_match_ret);\n    ${prefix}__restore_function_local_state(t, vox_outer_match_locals);')!
	return source[..start] + body + source[end..], true
}

fn match_cc(args []string) !int {
	for argument in args {
		if argument.ends_with('.c') && os.is_file(argument) {
			patched, found := patch_match_compiler(read(argument)!)!
			if found {
				os.write_file(argument, patched)!
				atomic_write(os.getenv('VOX_MATCH_SCOPE_RECEIPT'), 'patched\n')!
			}
		}
	}
	return execute([os.getenv('VOX_MATCH_SCOPE_CC'), ...args])
}

fn prepare_match(selected string) !string {
	resolved := real(selected)
	previous := join(os.dir(resolved), 'manifest.json')
	if os.is_file(previous) && os.is_file(join(os.dir(resolved), 'patched.txt')) && (maybe_load(previous)['sha256'] or { json.Null{} }).str() == digest(resolved)! {
		return resolved
	}
	tmp := temporary(os.temp_dir(), 'vox-v-root-')!
	defer { remove(tmp) or {} }
	vlib := compiler_vlib(resolved, tmp)!
	transform := join(vlib, 'v/transform/transform.v')
	if !os.is_file(transform) || !needs_match_fix(read(transform)!) { return resolved }
	wrapper := join(root_dir(), 'tools/v_match_scope_cc.sh')
	mut bytes := read(resolved)! + read(wrapper)! + read(@FILE)!
	for path in (files(join(vlib, 'v'))!).filter(it.ends_with('.v') && !it.ends_with('_test.v')) {
		bytes += relative(path, vlib) + '\x00' + read(path)!
	}
	cache := os.getenv_opt('XDG_CACHE_HOME') or { join(os.home_dir(), '.cache') }
	root := join(cache, 'vox/compilers', 'match-scope-' + hash(bytes)[..24])
	mkdir(root)!
	mut held := acquire(join(root, 'prepare.lock'), false)!
	defer { held.release() }
	target := join(root, 'v')
	manifest := join(root, 'manifest.json')
	if os.is_file(target) && (maybe_load(manifest)['sha256'] or { json.Null{} }).str() == digest(target)! {
		return target
	}
	for name in ['vlib', 'thirdparty', 'cmd', 'v.mod'] {
		link_to(join(root, name), if name == 'vlib' { vlib } else { join(os.dir(vlib), name) })!
	}
	remove(join(root, 'patched.txt'))!
	mut env := os.environ()
	env['VFLAGS'] = ''
	env['V_MACOS_V3_NO_FALLBACK'] = '1'
	env['VOX_MATCH_SCOPE_CC'] = os.find_abs_path_of_executable('clang') or { 'cc' }
	env['VOX_MATCH_SCOPE_RECEIPT'] = join(root, 'patched.txt')
	scratch := temporary(root, 'build-')!
	defer { remove(scratch) or {} }
	mut command := [resolved, '-b', 'c', '-nocache', '-memory-limit', '10G', '-cc', wrapper, '-prod',
		'-o', join(scratch, 'v')]
	for backend in ['fastc', 'x64', 'amd64', 'arm64', 'ssa', 'eval', 'wasm'] {
		command << ['-d', 'skip_' + backend]
	}
	command << join(os.dir(vlib), 'cmd/v')
	guarded := ['sh', join(root_dir(), 'tools/run_v_tool.sh'), 'run_memory_bounded', '--lock',
		join(scratch, 'compile.lock'), '--report', join(scratch, 'compile.json'), '--', ...command]
	code := supervised_command(os.dir(vlib), guarded, env, join(root, 'build.log'))!
	if code != 0 || !os.is_file(join(root, 'patched.txt')) {
		return error('V compiler scope fix failed; see ' + join(root, 'build.log'))
	}
	os.rename(join(scratch, 'v'), target)!
	write_json(manifest, json.Any(map[string]json.Any{
		'bootstrap': resolved
		'vlib':      vlib
		'sha256':    digest(target)!
	}))!
	return target
}
