module layout

import css

fn test_measurement_chunk_growth_keeps_records_stable_and_initialized() {
	mut arena := &MeasurementUsedValuesArena{}
	for cycle in 0 .. 2 {
		mut records := []&UsedValues{}
		for index in 0 .. 97 {
			mut value := arena.allocate()
			assert value.content_width() == CSSPixels.new(0)
			assert value.line_boxes.len == 0
			assert voidptr(value.inline_end_snapshot_arena_) == voidptr(arena)
			value.set_content_width(CSSPixels.new(index + cycle))
			records << value
		}
		for index, value in records {
			assert value.content_width() == CSSPixels.new(index + cycle)
			for earlier in 0 .. index {
				assert voidptr(value) != voidptr(records[earlier])
			}
		}
		arena.release()
		assert arena.chunks.len == 0
		assert arena.inline_end_snapshots.len == 0
	}
}

fn test_populated_measurement_chunks_preserve_source_and_destination_ownership() {
	mut source := UsedValues{}
	source.set_content_width(CSSPixels.new(123))
	source.set_content_height(CSSPixels.new(45))
	source.line_boxes << LineBox.new(.rtl, .horizontal_tb)
	mut first := &MeasurementUsedValuesArena{}
	mut second := &MeasurementUsedValuesArena{}
	for _ in 0 .. 49 {
		mut value := first.allocate_populated(&source)
		other := second.allocate_populated(&source)
		assert value.content_width() == CSSPixels.new(123)
		assert value.content_height() == CSSPixels.new(45)
		assert value.line_boxes.len == 0
		assert voidptr(value) != voidptr(other)
		assert voidptr(value.inline_end_snapshot_arena_) == voidptr(first)
		assert voidptr(other.inline_end_snapshot_arena_) == voidptr(second)
		value.set_content_width(CSSPixels.new(7))
		assert other.content_width() == CSSPixels.new(123)
		assert source.content_width() == CSSPixels.new(123)
		assert source.line_boxes.len == 1
	}
	first.release()
	second.release()
}

fn test_inline_end_snapshots_survive_chunk_growth_and_release_independently() {
	mut arena := &MeasurementUsedValuesArena{}
	for _ in 0 .. 2 {
		mut snapshots := []&StaticPositionRect{}
		for index in 0 .. 193 {
			position := StaticPositionRect{
				rect: css.CSSPixelRect.new(index, 2, 3, 4)
			}
			snapshots << arena.allocate_inline_end_snapshot(position)
		}
		for index, snapshot in snapshots {
			assert snapshot.rect.x == CSSPixels.new(index)
			assert snapshot.rect.y == CSSPixels.new(2)
			assert snapshot.rect.width == CSSPixels.new(3)
			assert snapshot.rect.height == CSSPixels.new(4)
		}
		assert arena.chunks.len == 0
		arena.release()
		assert arena.inline_end_snapshots.len == 0
	}
}
