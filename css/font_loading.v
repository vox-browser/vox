// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// CSS/FontLoading.cpp: format dispatch and vector-font preparation.
@[has_globals]
module css

import encoding.binary
import gfxfont
import platform
import sync
import threading

@[heap]
struct VectorFontPreparationCallback {
	@[required]
	on_complete fn (PreparedVectorFontData)
}

__global (
	vector_font_preparation_callbacks_       = map[u64]&VectorFontPreparationCallback{}
	vector_font_preparation_callbacks_mutex_ = sync.new_mutex()
)

pub struct PreparedVectorFontData {
pub:
	data          []u8
	error_message ?string
}

// CSS/FontLoading.cpp keeps the callback and any captured GC roots on the
// originating thread. The platform projection supplies its actual native loop.
pub fn prepare_vector_font_data_off_thread(data []u8, on_complete fn (PreparedVectorFontData)) bool {
	return prepare_vector_font_data_for_storage(data, on_complete, platform.current_retained_arena())
}

fn prepare_vector_font_data_for_computer(data []u8, on_complete fn (PreparedVectorFontData), computer ?&FontComputer) bool {
	storage := if owner := computer {
		if document := owner.document_ { document.native_storage() } else { unsafe { &platform.RetainedArena(nil) } }
	} else { unsafe { &platform.RetainedArena(nil) } }
	return prepare_vector_font_data_for_storage(data, on_complete, storage)
}

fn prepare_vector_font_data_for_storage(data []u8, on_complete fn (PreparedVectorFontData), storage &platform.RetainedArena) bool {
	invoker := platform.capture_native_deferred_invoker_for_storage(storage) or { return false }
	// Source allocates the callback on the origin thread and only the native
	// decoded bytes travel back from its worker. Keep owner roots out of work.
	callback := &VectorFontPreparationCallback{
		on_complete: on_complete
	}
	callback_id := u64(voidptr(callback))
	persistent := platform.enter_persistent()
	vector_font_preparation_callbacks_mutex_.lock()
	vector_font_preparation_callbacks_[callback_id] = callback
	vector_font_preparation_callbacks_mutex_.unlock()
	mut pool := threading.ThreadPool.the()
	platform.leave_persistent(persistent)
	queue_storage := platform.enter_persistent()
	pool.submit(fn [data, callback_id, invoker] () {
		mut prepared := PreparedVectorFontData{}
		if converted := gfxfont.convert_woff2_to_sfnt(data) {
			prepared = PreparedVectorFontData{ data: converted }
		} else {
			prepared = PreparedVectorFontData{
				error_message: err.msg()
			}
		}
		invoker.deferred_invoke(fn [callback_id, prepared] () {
			vector_font_preparation_callbacks_mutex_.lock()
			callback := vector_font_preparation_callbacks_[callback_id] or {
				vector_font_preparation_callbacks_mutex_.unlock()
				return
			}
			vector_font_preparation_callbacks_.delete(callback_id)
			vector_font_preparation_callbacks_mutex_.unlock()
			callback.on_complete(prepared)
		})
	})
	platform.leave_persistent(queue_storage)
	return true
}

pub fn requires_off_thread_vector_font_preparation(data []u8, mime_type_essence ?string) bool {
	if mime := mime_type_essence {
		if mime in ['font/woff2', 'application/font-woff2'] { return true }
	}
	if data.len < 4 { return false }
	return binary.big_endian_u32(data) == 0x774f4632
}

fn font_typeface_from_prepared_bytes(data []u8, family_name string) !&PlatformTypeface {
	if !gfxfont.typeface_data_is_valid(data, 0) { return error('Failed to load font') }
	path := platform.cache_prepared_font_data(data) or {
		return error('Failed to retain prepared font')
	}
	return &PlatformTypeface{
		family_name: family_name.clone()
		source_path: path.clone()
	}
}

pub fn try_load_vector_font(data []u8, mime_type_essence ?string, family_name string) !&PlatformTypeface {
	if mime := mime_type_essence {
		match mime {
			'font/ttf', 'application/x-font-ttf', 'font/otf' {
				return font_typeface_from_prepared_bytes(data, family_name)
			}
			'font/woff', 'application/font-woff', 'font/x-woff' {
				return font_typeface_from_prepared_bytes(gfxfont.convert_woff_to_sfnt(data)!,
					family_name)
			}
			'font/woff2', 'application/font-woff2' {
				return font_typeface_from_prepared_bytes(gfxfont.convert_woff2_to_sfnt(data)!,
					family_name)
			}
			else {}
		}
	} else {
		if result := font_typeface_from_prepared_bytes(data, family_name) { return result }
		if converted := gfxfont.convert_woff_to_sfnt(data) {
			if result := font_typeface_from_prepared_bytes(converted, family_name) { return result }
		}
		if converted := gfxfont.convert_woff2_to_sfnt(data) {
			if result := font_typeface_from_prepared_bytes(converted, family_name) { return result }
		}
	}
	return error('Automatic format detection failed')
}
