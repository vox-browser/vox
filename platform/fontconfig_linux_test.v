module platform

import os

fn test_linux_font_discovery_supplies_real_faces_for_layout_and_replay() {
	sans := font_path_for_family('sans-serif', 400)?
	mono := font_path_for_family('monospace', 400)?
	bold := font_path_for_family('sans-serif', 700)?
	assert os.is_file(sans)
	assert os.is_file(mono)
	assert os.is_file(bold)
	assert sans != mono
	assert sans != bold
	assert !system_font_family_available('Vox Missing Font 7f253b8d')
}
