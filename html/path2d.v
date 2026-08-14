// Copyright (c) 2023, MacDue <macdue@dueutil.tech>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/Path2D.cpp.
// Path2D is a PlatformObject that also mixes in CanvasPath; here it embeds CanvasPath and gains
// all of its path-building methods. The SVG-path-data constructor variant depends on the
// (untranslated) SVG::AttributeParser and is left as a documented FIXME.
module html

// https://html.spec.whatwg.org/multipage/canvas.html#path2d
@[heap]
pub struct Path2D {
	CanvasPath
}

// path is not given → an empty Path2D.
pub fn Path2D.create() &Path2D {
	return &Path2D{}
}

// path is a Path2D → a copy of its subpaths.
pub fn Path2D.create_from_path(other &Path2D) &Path2D {
	mut output := &Path2D{}
	output.CanvasPath.set_path(other.path())
	return output
}

// path is a string → parse as SVG 2 path data.
pub fn Path2D.create_from_svg_path_data(path_data string) &Path2D {
	// FIXME: SVG::AttributeParser::parse_path_data is not translated in this port; the resulting
	//        Path2D is empty. Steps 5-7 (seeding a subpath at svgPath's last point) are skipped.
	_ = path_data
	return &Path2D{}
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-path2d-addpath
// The DOMMatrix2DInit transform is represented as an already-built CanvasAffineTransform
// (m11/m12/m21/m22/m41/m42 → a/b/c/d/e/f); building the matrix from the dictionary is binding-layer.
pub fn (mut a Path2D) add_path(path &Path2D, transform CanvasAffineTransform) {
	// 1. If path has no subpaths, then return.
	if path.path().is_empty() {
		return
	}
	// 3. If any of the transform's used components are infinite or NaN, then return.
	if !is_finite(transform.a) || !is_finite(transform.b) || !is_finite(transform.c)
		|| !is_finite(transform.d) || !is_finite(transform.e) || !is_finite(transform.f) {
		return
	}
	// 4-5. Copy path's subpaths and transform them by matrix.
	copy := path.path().copy_transformed(transform)
	// 6. Let (x, y) be the last point of the copy.
	xy := copy.last_point()
	// 7. Add all the subpaths in the copy to a.
	a.CanvasPath.path_.append_path(copy)
	// 8. Create a new subpath in a with (x, y) as the only point.
	a.move_to(xy.x, xy.y)
}
