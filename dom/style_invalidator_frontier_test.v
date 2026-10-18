module dom

fn frontier_test_clear(node &Node) {
 mut mutable_node := unsafe { &Node(node) }
 mutable_node.set_needs_style_update_internal(false)
 mutable_node.set_child_needs_style_update(false)
 mutable_node.set_entire_subtree_needs_style_update(false)
 for child in node.children { frontier_test_clear(child) }
 if element := node.as_element() {
  if shadow := element.shadow_root() { frontier_test_clear(unsafe { &Node(shadow) }) }
 }
}

fn frontier_test_append(parent &Node, child &Node) {
 mut mutable_parent := unsafe { &Node(parent) }
 mutable_parent.append_child(child) or { panic(err) }
}

fn frontier_test_fixture(count int) (&Document, &Element, []&Element, []&Element) {
 mut document := Document.create(url_about_blank())
 root := document.create_element_ns('http://www.w3.org/1999/xhtml','main') or { panic(err) }
 frontier_test_append(document.as_node(),root.as_node())
 mut branches := []&Element{}
 mut leaves := []&Element{}
 for _ in 0..count {
  mut branch := document.create_element_ns('http://www.w3.org/1999/xhtml','section') or { panic(err) }
  branch.set_attribute_value('class','branch')
  mut leaf := document.create_element_ns('http://www.w3.org/1999/xhtml','span') or { panic(err) }
  leaf.set_attribute_value('class','leaf')
  frontier_test_append(root.as_node(),branch.as_node())
  frontier_test_append(branch.as_node(),leaf.as_node())
  branches << branch
  leaves << leaf
 }
 frontier_test_clear(document.as_node())
 document.set_needs_full_style_update(false)
 return document,root,branches,leaves
}

fn frontier_test_leaf_rule() DescendantInvalidationRule {
 return DescendantInvalidationRule{
  match_set: StyleInvalidationSet{properties:[InvalidationProperty{type_:.class,name:'leaf'}]}
  payload: InvalidationPlan{invalidate_self:true}
 }
}

fn test_pending_descendant_rules_publish_their_ancestor_frontier_and_can_be_requeued() {
 mut document,root,branches,leaves := frontier_test_fixture(64)
 defer { document.finalize() }
 mut invalidator := StyleInvalidator{}
 for index in [17,49] {
  frontier_test_clear(document.as_node())
  assert !root.as_node().child_needs_style_update()
  invalidator.enqueue_invalidation_plan(branches[index].as_node(),.other,InvalidationPlan{
   descendant_rules:[frontier_test_leaf_rule()]
  })
  assert branches[index].as_node().child_needs_style_update()
  assert root.as_node().child_needs_style_update()
  assert document.as_node().child_needs_style_update()
  mut document_node := document.as_node()
  invalidator.invalidate(mut document_node)
  for leaf_index,leaf in leaves { assert leaf.needs_style_update() == (leaf_index==index) }
  assert invalidator.pending_invalidations.len == 0
  assert invalidator.active_descendant_invalidations.len == 0
 }
}

fn test_sibling_rules_queued_during_a_sparse_drain_reach_later_subtrees() {
 mut document,root,_,leaves := frontier_test_fixture(3)
 defer { document.finalize() }
 mut invalidator := StyleInvalidator{}
 invalidator.enqueue_invalidation_plan(root.as_node(),.other,InvalidationPlan{
  descendant_rules:[DescendantInvalidationRule{
   match_set:StyleInvalidationSet{properties:[InvalidationProperty{type_:.class,name:'branch'}]}
   payload:InvalidationPlan{
    sibling_rules:[SiblingInvalidationRule{
     match_any:true
     reach:.adjacent
     payload:InvalidationPlan{descendant_rules:[frontier_test_leaf_rule()]}
    }]
   }
  }]
 })
 mut document_node := document.as_node()
 invalidator.invalidate(mut document_node)
 assert !leaves[0].needs_style_update()
 assert leaves[1].needs_style_update()
 assert leaves[2].needs_style_update()
 assert invalidator.pending_invalidations.len == 0
 assert invalidator.active_descendant_invalidations.len == 0
}

fn test_sparse_drain_keeps_self_cleanup_and_whole_subtree_invalidation() {
 mut document,_,branches,leaves := frontier_test_fixture(3)
 defer { document.finalize() }
 mut leaf := leaves[0]
 leaf.removed_attributes_for_style_invalidation = ['data-old']
 leaf.set_needs_style_update(true)
 mut whole_branch := branches[2].as_node()
 whole_branch.set_entire_subtree_needs_style_update(true)
 mark_ancestors_as_having_child_needing_style_update(whole_branch)
 mut invalidator := StyleInvalidator{}
 mut document_node := document.as_node()
 invalidator.invalidate(mut document_node)
 assert leaves[0].removed_attributes_for_style_invalidation.len == 0
 assert leaves[0].needs_style_update()
 assert !leaves[1].needs_style_update()
 assert leaves[2].needs_style_update()
 assert !whole_branch.entire_subtree_needs_style_update()
}

fn test_sparse_drain_repairs_dirty_shadow_root_paths_and_processes_shadow_rules() {
 mut document,_,branches,_ := frontier_test_fixture(2)
 defer { document.finalize() }
 mut host := branches[0]
 shadow := host.attach_shadow(ShadowRootInit{mode:.open}) or { panic(err) }
 mut leaf := document.create_element_ns('http://www.w3.org/1999/xhtml','span') or { panic(err) }
 leaf.set_attribute_value('class','leaf')
 shadow_node := unsafe { &Node(shadow) }
 frontier_test_append(shadow_node,leaf.as_node())
 frontier_test_clear(document.as_node())
 mut mutable_shadow := unsafe { &Node(shadow) }
 mutable_shadow.set_needs_style_update_internal(true)
 mut invalidator := StyleInvalidator{}
 mut document_node := document.as_node()
 invalidator.invalidate(mut document_node)
 assert host.as_node().child_needs_style_update()
 assert document_node.child_needs_style_update()
 frontier_test_clear(document.as_node())
 invalidator.enqueue_invalidation_plan(shadow_node,.other,InvalidationPlan{
  descendant_rules:[frontier_test_leaf_rule()]
 })
 invalidator.invalidate(mut document_node)
 assert leaf.needs_style_update()
 assert !branches[1].needs_style_update()
}
