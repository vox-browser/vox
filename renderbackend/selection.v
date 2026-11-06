// Runtime selection of the currently ported document-rendering adapters.
module renderbackend

import os

pub struct Selection {
pub:
	text   bool
	shapes bool
	paths  bool
}

// A legacy renderer request takes precedence over individual adapter switches.
// Explicit zeroes remain useful when isolating one port in differential checks.
pub fn select(use_skia string, text string, shapes string, paths string) Selection {
	if use_skia == '1' {
		return Selection{}
	}
	return Selection{
		text:   text != '0'
		shapes: shapes != '0'
		paths:  paths != '0'
	}
}

pub fn from_environment() Selection {
	return select(os.getenv('VOX_USE_SKIA'), os.getenv('VOX_GG_TEXT'),
		os.getenv('VOX_GG_SHAPES'), os.getenv('VOX_GG_PATHS'))
}
