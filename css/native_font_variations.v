module css

import platform

fn (settings &FontVariationSettings) native_axes() []platform.FontVariationAxis {
	mut values := settings.axis_values()
	if 'wght' !in values { values['wght'] = settings.weight }
	if 'wdth' !in values { values['wdth'] = settings.width }
	if size := settings.opsz {
		if 'opsz' !in values { values['opsz'] = size }
	}
	mut tags := values.keys()
	tags.sort()
	mut axes := []platform.FontVariationAxis{}
	for tag in tags {
		if tag.len != 4 { continue }
		packed := u32(tag[0]) << 24 | u32(tag[1]) << 16 | u32(tag[2]) << 8 | u32(tag[3])
		axes << platform.FontVariationAxis{ tag: packed, value: f32(values[tag]) }
	}
	return axes
}
