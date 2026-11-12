module buildtools

import os

fn pointer_casts(source string) !string {
	mut text := source
	for text.contains('u64(usize(') {
		start := text.index('u64(usize(') or { break }
		mut depth := 1
		mut end := start + 10
		for end < text.len && depth > 0 {
			if text[end] == `(` { depth++ }
			if text[end] == `)` { depth-- }
			end++
		}
		if depth != 0 { return error('Unbalanced pointer conversion') }
		text = text[..start] + 'u64(' + text[start + 10..end - 1] + text[end..]
	}
	return text
}

fn condition_helpers(source string, names []string, condition string) !string {
	mut text := source
	for name in names {
		signature := 'fn ' + name + '('
		if !text.contains(signature) { continue }
		start, end := function_span(text, signature)!
		body := text[start..end].split_into_lines().map('\t' + it).join('\n')
		text = text[..start] + '\$if ' + condition + ' {\n' + body + '\n}' + text[end..]
	}
	return text
}

fn patch_linux_module(package string, source string) !string {
	mut text := source
	if package == 'sokol/sapp' {
		mut lines := text.split('\n')
		for i, line in lines {
			if line.trim_space().starts_with('canvas_selector ') && line.contains("c'#canvas'") {
				lines[i] = line.replace("c'#canvas'", "'#canvas'.str")
			}
		}
		text = lines.join('\n')
	}
	if package == 'stbi' {
		text = text.replace('import os\n', '\$if windows && clang {\n\timport os\n}\n')
	}
	if package in ['gg', 'net/openssl'] { text = pointer_casts(text)!.replace('usize(', 'uint(') }
	if package == 'gg' {
		text = text.replace('\tdesc := sapp.create_desc()\n', '\tmut desc := sapp.create_desc()\n\tif desc.sampler_pool_size < desc.image_pool_size {\n\t\tdesc.sampler_pool_size = desc.image_pool_size\n\t}\n')
		text = private_helper(text, 'gg_fail_fn')!
		text = condition_helpers(text, ['gg_poison_gfx_render_owner'], 'gg_multiwindow ? || test')!
		recorder := ['screenshot_stdout_payload', 'emit_recorded_frame_to_stdout',
			'new_gg_recorder_settings', 'parse_screenshot_frames', 'parse_screenshot_output',
			'recorder_env_value', 'new_gg_recorder_settings_from_env']
		has_recorder := recorder.any(text.contains('fn ' + it + '('))
		if has_recorder { text = condition_helpers(text, recorder, 'gg_record ? || test')! }
		mut lines := []string{}
		for line in text.split('\n') {
			if line.starts_with('const err_multiwindow_render_') && !line.starts_with('const err_multiwindow_render_device_lost ') {
				lines << '\$if gg_multiwindow ? || test {\n\t' + line + '\n}'
			} else if line.starts_with('const recorder_settings = ') || line.starts_with('const gg_record_stdout_prefix = ') || (has_recorder && line.starts_with('import ')) {
				lines << '\$if gg_record ? || test {\n\t' + line + '\n}'
			} else {
				lines << line
			}
		}
		text = lines.join('\n')
	}
	if package == 'net/openssl' {
		mut lines := text.split('\n')
		for i := 0; i + 1 < lines.len; i++ {
			if trimmed_eq(lines[i], 'unsafe {') && trimmed_eq(lines[i + 1], 'mut ptr_base := bytes') {
				indent := lines[i].all_before('unsafe {')
				lines[i] = indent + 'mut ptr_base := unsafe { bytes }'
				lines[i + 1] = indent + 'unsafe {'
			}
		}
		text = lines.join('\n')
	}
	return text
}

fn patch_fontstash(source string) !string {
	marker := '#include "@DIR/vox_fontstash_callbacks.h"'
	declarations := {
		'fn fons_render_update(uptr voidptr, rect &i32, data &u8) {':                             "@[export: 'vox_gg_fontstash_render_update']"
		'fn fons_render_draw(uptr voidptr, verts &f32, tcoords &f32, colors &u32, nverts i32) {': "@[export: 'vox_gg_fontstash_render_draw']"
	}
	if source.contains(marker) {
		if source.count(marker) != 1 || source.count('C.vox_gg_fontstash_callbacks(&params)') != 2 {
			return error('Incomplete GG Fontstash callback adapter')
		}
		for _, annotation in declarations {
			if source.count(annotation) != 1 { return error('Incomplete GG Fontstash exports') }
		}
		return source
	}
	mut text := source
	for signature, annotation in declarations {
		text = replace_once(text, signature, annotation + '\n' + signature)!
	}
	mut lines := text.split('\n')
	mut count := 0
	for i := 0; i + 1 < lines.len; i++ {
		if trimmed_eq(lines[i], 'params.renderUpdate = fons_render_update') && trimmed_eq(lines[i + 1], 'params.renderDraw = fons_render_draw') {
			indent := lines[i].all_before('params.')
			lines[i] = indent + 'C.vox_gg_fontstash_callbacks(&params)'
			lines.delete(i + 1)
			count++
		}
	}
	if count != 2 { return error('Expected two GG Fontstash callback assignments') }
	return replace_once(lines.join('\n'), 'module gg\n', 'module gg\n\n' + marker + '\n')! + '\nfn C.vox_gg_fontstash_callbacks(params &C.FONSparams)\n'
}

fn real_parents(target string, base string) ! {
	if os.dir(target) != base && os.dir(target).starts_with(base + '/') {
		real_parents(os.dir(target), base)!
	}
	parent := os.dir(target)
	if os.is_link(parent) { os.rm(parent)! }
	mkdir(parent)!
}

fn stage_linux_module(source string, target string, package string) ! {
	if os.is_link(target) { os.rm(target)! }
	mkdir(target)!
	mut expected := []string{}
	mut fontstash := false
	for path in files(source)! {
		if path.ends_with('_test.v') { continue }
		name := relative(path, source)
		expected << name
		destination := join(target, name)
		real_parents(destination, target)!
		if path.ends_with('.v') {
			mut text := patch_linux_module(package, read(path)!)!
			if package == 'gg' && name == 'text_rendering.c.v' {
				text = patch_fontstash(text)!
				fontstash = true
			}
			write_changed(destination, text)!
		} else {
			link_to(destination, real(path))!
		}
	}
	if fontstash {
		expected << 'vox_fontstash_callbacks.h'
		write_changed(join(target, 'vox_fontstash_callbacks.h'), read(join(root_dir(), 'tools/linux_fontstash_callbacks.h'))!)!
	}
	for path in files(target)! { if relative(path, target) !in expected { remove(path)! } }
}

fn prepare_linux(selected string) !string {
	work := build_cache('linux/native')
	mkdir(work)!
	vlib := compiler_vlib(selected, work)!
	cc := os.getenv_opt('CC') or { 'cc' }
	modules := build_cache('linux/modules')
	for package, directory in {
		'stbi': 'stb_image'
		'json': 'cJSON'
	} {
		name := if package == 'stbi' { 'stbi' } else { 'cJSON' }
		thirdparty := join(os.dir(vlib), 'thirdparty', directory)
		source := join(thirdparty, name + '.c')
		if !os.is_dir(join(vlib, package)) || !os.is_file(source) {
			remove(join(modules, package))!
			continue
		}
		mut bytes := capture([cc, '--version'])! + read(@FILE)!
		for header in (listing(thirdparty)!).filter(it.ends_with('.h')) { bytes += read(header)! }
		bytes += read(source)!
		sha := hash(bytes)
		archive := join(work, name + '.a')
		stamp := join(work, name + '.sha256')
		if !os.is_file(archive) || (read(stamp) or { '' }) != sha {
			object_file := join(work, name + '.o')
			checked([cc, '-O2', '-fPIC', '-c', source, '-o', object_file])!
			checked(['ar', 'rcs', archive, object_file])!
			atomic_write(stamp, sha)!
		}
		for path in (files(join(vlib, package))!).filter(it.ends_with('.v') && !it.ends_with('_test.v')) {
			text := patch_linux_module(package, read(path)!)!.replace('#flag @VEXEROOT/thirdparty/${directory}/${name}.o', '#flag ${archive}')
			write_changed(join(modules, package, relative(path, join(vlib, package))), text)!
		}
	}
	for package in ['gg', 'net/openssl', 'sokol/sapp'] {
		stage_linux_module(join(vlib, package), join(modules, package), package)!
	}
	return modules
}
