module page

import compositor

fn test_page_client_retains_remote_child_frame_topology() {
	mut client := PageClient.create()
	client.page_did_create_child_frame(1, 22, 'origin=https://example.test')
	client.page_did_update_child_frame_viewport(22, PixelRect{ x: 4, y: 8, width: 320, height: 200 })
	client.set_remote_child_frame_compositor_context_id(22, compositor.CompositorContextId(90))
	frame := client.child_frame(22) or { panic('missing child frame') }
	assert frame.parent_id == 1
	assert frame.viewport == PixelRect{ x: 4, y: 8, width: 320, height: 200 }
	assert client.compositor_context_id_for_remote_child_frame(22)? == compositor.CompositorContextId(90)
	assert client.compositor_context_id_for_remote_child_frame(99) == none
	assert client.dump_site_isolation_process_tree_for_testing() == '1->22 context=90 crashed=false origin=https://example.test'

	client.crash_remote_frame_processes_for_testing()
	assert (client.child_frame(22)?).crashed
	client.page_did_destroy_child_frame(22)
	assert client.child_frame(22) == none
	client.page_did_destroy_child_frame(22)
	assert client.events.filter(it.name == 'destroy-child-frame').len == 1
}

fn test_page_client_records_navigation_population_failures() {
	mut client := PageClient.create()
	client.navigation_population_failed(71, 'navigation-a')
	assert client.navigation_population_failures() == [NavigationPopulationFailure{
		operation_id: 71
		navigation_id: 'navigation-a'
	}]
}
