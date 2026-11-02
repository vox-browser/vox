module ui2

$if (linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import math

	fn embedded_button_image_layout(el Element) ButtonImageLayout {
		if el.button_image_size <= 0 || el.image_path.trim_space() == '' {
			return button_image_layout(el.frame.width, el.frame.height, el.text, el.image_path)
		}
		icon := embedded_button_image_frame(el)
		return ButtonImageLayout{
			visible: icon.width > 0
			image:   icon
			text:    if el.text == '' {
				rect(0, 0, 0, 0)
			} else {
				rect(icon.width + 9, 0, math.max(el.frame.width - icon.width - 13, 0.0), el.frame.height)
			}
		}
	}
}
