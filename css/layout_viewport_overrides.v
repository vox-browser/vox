module css

// Viewport propagation changes box values, while the originating element's
// computed style remains the input to later cascades and CSSOM queries.
pub fn (values &ComputedValues) with_viewport_overrides(overflow_x Overflow, overflow_y Overflow, writing_mode WritingMode, direction Direction, scrollbar_width ScrollbarWidth) &ComputedValues {
	if values.overflow_x() == overflow_x && values.overflow_y() == overflow_y
		&& values.writing_mode() == writing_mode && values.direction() == direction
		&& values.scrollbar_width() == scrollbar_width {
		return unsafe { values }
	}
	source := unsafe { &ComputedProperties(values) }
	source.share_computed_layout_cache()
	mut clone := &ComputedProperties{
		...source
	}
	owns_write := clone.begin_computed_layout_cache_write()
	defer { clone.finish_computed_layout_cache_write(owns_write) }
	mut result := unsafe { &MutableComputedValues(clone) }
	result.set_overflow_x(overflow_x)
	result.set_overflow_y(overflow_y)
	result.set_writing_mode(writing_mode)
	result.set_direction(direction)
	result.set_scrollbar_width(scrollbar_width)
	return unsafe { &ComputedValues(clone) }
}
