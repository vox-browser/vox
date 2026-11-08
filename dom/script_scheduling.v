module dom

pub fn (mut document Document) remove_script_to_execute_as_soon_as_possible(script &HTMLScriptElement) {
	document.scripts_to_execute_as_soon_as_possible = document.scripts_to_execute_as_soon_as_possible.filter(voidptr(it) != voidptr(script))
}
