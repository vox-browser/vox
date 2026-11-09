module main

import os

// These stages keep source trees separate from mutable compatibility outputs.
// Never write through a symlink left by another stage.
fn stage_link(path string, source string) ! {
	if os.is_link(path) {
		if os.real_path(path) == os.real_path(source) {
			return
		}
		os.rm(path)!
	} else if os.is_dir(path) {
		os.rmdir_all(path)!
	} else if os.exists(path) {
		os.rm(path)!
	}
	os.symlink(source, path)!
}

fn staging_real_directory(path string) ! {
	if os.is_link(path) || os.is_file(path) {
		os.rm(path)!
	}
	make_directory(path)!
}

fn staging_link_directory_files(path string, source string) ! {
	staging_real_directory(path)!
	for name in os.ls(source)! {
		entry := os.join_path(source, name)
		target := os.join_path(path, name)
		if os.is_dir(entry) {
			staging_link_directory_files(target, entry)!
		} else {
			stage_link(target, entry)!
		}
	}
}

// pathlib.rglob semantics: list directory links, but do not descend through them.
fn staging_tree_paths(root string) ![]string {
	mut result := []string{}
	if !os.is_dir(root) {
		return result
	}
	for name in os.ls(root)! {
		path := os.join_path(root, name)
		result << path
		if os.is_dir(path) && !os.is_link(path) {
			result << staging_tree_paths(path)!
		}
	}
	return result
}

// Match the exact declaration and its column-zero closing brace. These are
// source compatibility adapters: reject changed or ambiguous upstream shapes.
fn staging_function_range(source string, signature string) !(int, int, int) {
	mut offset := 0
	mut matches := 0
	mut start := 0
	mut opening := 0
	mut closing := 0
	for offset < source.len {
		index := source.index_after(signature, offset) or { break }
		offset = index + signature.len
		mut brace := offset
		for brace < source.len && source[brace].is_space() {
			brace++
		}
		if brace >= source.len || source[brace] != `{` {
			continue
		}
		end := source.index_after('\n}', brace) or { continue }
		matches++
		start, opening, closing = index, brace, end + 1
	}
	if matches != 1 {
		return error('Unsupported V source: expected one ${signature}, found ${matches}')
	}
	return start, opening, closing
}

fn staging_gg_native_includes(source string, source_dir string, target_dir string) !string {
	mut result := ''
	mut offset := 0
	marker := '#include "@DIR/'
	for offset < source.len {
		start := source.index_after(marker, offset) or { break }
		name_start := start + marker.len
		name_end := source.index_after('"', name_start) or { break }
		name := source[name_start..name_end]
		result += source[offset..start]
		if name.ends_with('.h') && !name.contains('\n') && (name.contains('darwin') || name == 'path_math.h') {
			wrapper := 'vox_' + os.file_name(name).all_before_last('.') + '.m'
			header := os.real_path(os.join_path(source_dir, name))
			if !os.is_file(header) {
				return error('Missing GG native helper: ${header}')
			}
			write_if_changed(os.join_path(target_dir, wrapper), '#include "${header}"\n')!
			result += '#include "@DIR/${wrapper}"'
		} else {
			result += source[start..name_end + 1]
		}
		offset = name_end + 1
	}
	return result + source[offset..]
}

fn staging_gg_gradient(modules string, vlib string) ! {
	source := os.join_path(vlib, 'gg')
	gradient := os.join_path(source, 'canvas/gpu_gradient.v')
	if !os.is_file(gradient) {
		return
	}
	original := r"(snippets['bodies_tile'] + snippets['body_colorize_${stops}']).replace('_skTemp',"
	replacement := r"tile_source := snippets['bodies_tile'] + snippets['body_colorize_${stops}']" + '\n' +
		r"\tbodies_tile := tile_source.replace('_skTemp',".replace(r'\t', '\t')
	text := os.read_file(gradient)!.replace('bodies_tile := ' + original, replacement)
	target := os.join_path(modules, 'gg')
	make_directory(target)!
	for name in os.ls(source)! {
		if name == 'canvas' {
			continue
		}
		entry := os.join_path(source, name)
		if os.is_dir(entry) {
			staging_link_directory_files(os.join_path(target, name), entry)!
		} else {
			stage_link(os.join_path(target, name), entry)!
		}
	}
	canvas := os.join_path(target, 'canvas')
	make_directory(canvas)!
	for name in os.ls(os.join_path(source, 'canvas'))! {
		entry := os.join_path(source, 'canvas', name)
		output := os.join_path(canvas, name)
		if name == os.file_name(gradient) {
			write_if_changed(output, text)!
		} else if os.is_file(entry) && name.ends_with('.v') && os.read_file(entry)!.contains('fn C.') {
			context := staging_gg_native_includes(os.read_file(entry)!, os.dir(entry), canvas)!
			write_if_changed(output, context)!
		} else if os.is_dir(entry) {
			staging_link_directory_files(output, entry)!
		} else {
			stage_link(output, entry)!
		}
	}
}

fn prepare_ui2(repo string, compiler string) !string {
	modules := os.getenv_opt('VMODULES') or { os.join_path(os.home_dir(), '.vmodules') }
	source := os.real_path(os.getenv_opt('UI2_SOURCE_DIR') or { os.join_path(modules, 'ui2') })
	for name in ['v.mod', 'ui/ui.v', 'ui/embedding.v'] {
		if !os.is_file(os.join_path(source, name)) {
			return error('UI2 is missing its embedding API. Install or update the latest UI2 with v install ui2 / v up ui2, or set UI2_SOURCE_DIR to your current UI2 checkout.')
		}
	}
	platform_dir := $if linux { 'linux' } $else $if windows { 'windows' } $else { 'v' }
	target := os.join_path(repo, 'Build', platform_dir, 'modules')
	make_directory(target)!
	stage_link(os.join_path(target, 'ui2'), source)!
	vlib := compiler_vlib(compiler, target)!
	staging_gg_gradient(target, vlib)!
	$if macos {
		macos_source := os.join_path(vlib, 'macos')
		if !os.is_file(os.join_path(macos_source, 'objc_bridge.h')) {
			return error('UI2 requires a current V checkout with vlib/macos.')
		}
		stage_link(os.join_path(target, 'macos'), macos_source)!
	}
	return target
}
