// CanvasCommandPlayer/PainterSkia native ABI service.
module skia

$if macos {
	$if arm64 {
		#flag -I @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/include/skia
		#flag -I @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/include
		#flag -L @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/lib
		#flag -Wl,-rpath,@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/lib
	} $else {
		#flag -I @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/include/skia
		#flag -I @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/include
		#flag -L @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/lib
		#flag -Wl,-rpath,@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/lib
	}
	#flag -lc++
	#flag -lskia
} $else {
	#pkgconfig skia
	#flag -lstdc++
}

$if linux {
	#flag @DIR/../Build/linux/native/skia.a
} $else {
	#flag @DIR/canvas_raster.o
}
// Older cached skia.pc files omit this direct dependency of the static library.
#flag linux -lm
#include "canvas_raster.h"

pub struct Path {
pub:
	segments []f32
	even_odd bool
}

pub struct Style {
pub:
	kind                int
	color               u32
	x0                  f32
	y0                  f32
	r0                  f32
	x1                  f32
	y1                  f32
	r1                  f32
	angle               f32
	stops               []f32
	pattern             []u8
	pattern_width       int
	pattern_height      int
	pattern_pitch       int
	pattern_alpha       int
	pattern_color_space int
	repetition          int
	pattern_transform   [6]f32 = [f32(1), 0, 0, 1, 0, 0]!
}

pub struct Filter {
pub:
	kind     int
	radius   f32
	offset_x f32
	offset_y f32
	color    u32
	matrix   [20]f32
	clamp    bool
	graph    SvgFilterGraph
}

pub struct Command {
pub:
	operation    int
	chromium     bool
	destination  [4]f32
	source       [4]f32
	smoothing    bool
	path         Path
	style        Style
	transform    [6]f32 = [f32(1), 0, 0, 1, 0, 0]!
	clips        []Path
	stroke       bool
	cap          int
	join         int
	composite    int
	width        f32
	miter        f32
	global_alpha f32 = 1
	blur         f32
	dashes       []f32
	dash_offset  f32
	filters      []Filter
}

struct C.VoxCanvasPath {
	segments &f32
	count    int
	even_odd int
}

struct C.VoxCanvasStyle {
	kind                int
	color               u32
	x0                  f32
	y0                  f32
	r0                  f32
	x1                  f32
	y1                  f32
	r1                  f32
	angle               f32
	stops               &f32
	stop_count          int
	pattern             &u8
	pattern_width       int
	pattern_height      int
	pattern_pitch       int
	pattern_alpha       int
	pattern_color_space int
	repetition          int
	pattern_transform   [6]f32
}

struct C.VoxCanvasSvgFilterNode {
	kind        int
	inputs      &i32
	input_count int
	x           f32
	y           f32
	matrix      [20]f32
}

struct C.VoxCanvasFilter {
	kind                   int
	radius                 f32
	offset_x               f32
	offset_y               f32
	color                  u32
	matrix                 [20]f32
	clamp                  int
	graph_nodes            &C.VoxCanvasSvgFilterNode
	graph_count            int
	graph_root             int
	graph_region           [4]f32
	graph_object_bounds    int
	graph_primitive_bounds int
}

struct C.VoxCanvasCommand {
	operation    int
	destination  [4]f32
	source       [4]f32
	smoothing    int
	path         C.VoxCanvasPath
	style        C.VoxCanvasStyle
	transform    [6]f32
	clips        &C.VoxCanvasPath
	clip_count   int
	stroke       int
	cap          int
	join         int
	composite    int
	width        f32
	miter        f32
	global_alpha f32
	blur         f32
	dashes       &f32
	dash_count   int
	dash_offset  f32
	filters      &C.VoxCanvasFilter
	filter_count int
}

fn C.vox_skia_canvas_path(pixels &u8, width int, height int, pitch int, alpha_type int, command &C.VoxCanvasCommand) bool
fn C.vox_skia_canvas_path_chromium(pixels &u8, width int, height int, pitch int, alpha_type int, command &C.VoxCanvasCommand) bool

pub struct GlyphRun {
pub:
	font_path string
	face_index int
	font_size f32
	glyphs []u16
	positions []f32
	translation [2]f32
}

struct C.VoxCanvasGlyphRun {
	font_path &char
	face_index int
	count int
	font_size f32
	translation [2]f32
	glyphs &u16
	positions &f32
}

fn C.vox_skia_canvas_glyphs(&u8, int, int, int, int, &C.VoxCanvasCommand, &C.VoxCanvasGlyphRun) bool

fn native_path(path Path) C.VoxCanvasPath {
	return C.VoxCanvasPath{path.segments.data, path.segments.len / 12, int(path.even_odd)}
}

pub fn draw_path(mut pixels []u8, width int, height int, pitch int, alpha_type int, command Command) bool {
	return draw_canvas_command(mut pixels, width, height, pitch, alpha_type, command, none)
}

pub fn draw_glyph_run(mut pixels []u8, width int, height int, pitch int, alpha_type int, command Command, glyphs GlyphRun) bool {
	return draw_canvas_command(mut pixels, width, height, pitch, alpha_type, command, glyphs)
}

fn draw_canvas_command(mut pixels []u8, width int, height int, pitch int, alpha_type int, command Command, glyphs ?GlyphRun) bool {
	mut clips := []C.VoxCanvasPath{cap: command.clips.len}
	for clip in command.clips {
		clips << native_path(clip)
	}
	mut filters := []C.VoxCanvasFilter{cap: command.filters.len}
	// Keep every graph and its input arrays alive until native drawing returns.
	mut graph_storage := [][]C.VoxCanvasSvgFilterNode{}
	mut input_storage := [][]i32{}
	for filter in command.filters {
		mut nodes := []C.VoxCanvasSvgFilterNode{}
		for node in filter.graph.nodes {
			inputs := node.inputs.map(i32(it))
			input_storage << inputs
			nodes << C.VoxCanvasSvgFilterNode{
				kind:        int(node.kind)
				inputs:      inputs.data
				input_count: inputs.len
				x:           node.x
				y:           node.y
				matrix:      node.matrix
			}
		}
		graph_storage << nodes
		filters << C.VoxCanvasFilter{
			kind:                   filter.kind
			radius:                 filter.radius
			offset_x:               filter.offset_x
			offset_y:               filter.offset_y
			color:                  filter.color
			matrix:                 filter.matrix
			clamp:                  int(filter.clamp)
			graph_nodes:            nodes.data
			graph_count:            nodes.len
			graph_root:             filter.graph.root
			graph_region:           filter.graph.region
			graph_object_bounds:    int(filter.graph.object_bounds)
			graph_primitive_bounds: int(filter.graph.primitive_bounds)
		}
	}
	style := command.style
	native_style := C.VoxCanvasStyle{
		kind:                style.kind
		color:               style.color
		x0:                  style.x0
		y0:                  style.y0
		r0:                  style.r0
		x1:                  style.x1
		y1:                  style.y1
		r1:                  style.r1
		angle:               style.angle
		stops:               style.stops.data
		stop_count:          style.stops.len / 5
		pattern:             style.pattern.data
		pattern_width:       style.pattern_width
		pattern_height:      style.pattern_height
		pattern_pitch:       style.pattern_pitch
		pattern_alpha:       style.pattern_alpha
		pattern_color_space: style.pattern_color_space
		repetition:          style.repetition
		pattern_transform:   style.pattern_transform
	}
	native_command := C.VoxCanvasCommand{
		operation:    command.operation
		destination:  command.destination
		source:       command.source
		smoothing:    int(command.smoothing)
		path:         native_path(command.path)
		style:        native_style
		transform:    command.transform
		clips:        clips.data
		clip_count:   clips.len
		stroke:       int(command.stroke)
		cap:          command.cap
		join:         command.join
		composite:    command.composite
		width:        command.width
		miter:        command.miter
		global_alpha: command.global_alpha
		blur:         command.blur
		dashes:       command.dashes.data
		dash_count:   command.dashes.len
		dash_offset:  command.dash_offset
		filters:      filters.data
		filter_count: filters.len
	}
	if run := glyphs {
		native := C.VoxCanvasGlyphRun{ run.font_path.str, run.face_index, run.glyphs.len, run.font_size, run.translation, run.glyphs.data, run.positions.data }
		return C.vox_skia_canvas_glyphs(pixels.data, width, height, pitch, alpha_type, &native_command, &native)
	}
	if command.chromium && C.vox_skia_canvas_path_chromium(pixels.data, width, height, pitch, alpha_type, &native_command) {
		return true
	}
	return C.vox_skia_canvas_path(pixels.data, width, height, pitch, alpha_type, &native_command)
}
