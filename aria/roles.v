// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/ARIA/Roles.{h,cpp}.
module aria

pub enum Role {
	alert
	alertdialog
	application
	article
	banner
	blockquote
	button
	caption
	cell
	checkbox
	code
	columnheader
	combobox
	command
	complementary
	composite
	contentinfo
	definition
	deletion
	dialog
	directory
	document
	emphasis
	feed
	figure
	form
	generic
	graphicsdocument
	graphicsobject
	graphicssymbol
	grid
	gridcell
	group
	heading
	image
	img
	input
	insertion
	landmark
	link
	list
	listbox
	listitem
	log
	main
	mark
	marquee
	math
	meter
	menu
	menubar
	menuitem
	menuitemcheckbox
	menuitemradio
	navigation
	none_
	note
	option
	paragraph
	presentation
	progressbar
	radio
	radiogroup
	range_
	region
	roletype
	row
	rowgroup
	rowheader
	scrollbar
	search
	searchbox
	section
	sectionfooter
	sectionhead
	sectionheader
	select_
	separator
	slider
	spinbutton
	status
	strong
	structure
	subscript
	suggestion
	superscript
	switch_
	tab
	table
	tablist
	tabpanel
	term
	textbox
	time
	timer
	toolbar
	tooltip
	tree
	treegrid
	treeitem
	widget
	window_
}

pub const all_roles = [
	Role.alert,
	Role.alertdialog,
	Role.application,
	Role.article,
	Role.banner,
	Role.blockquote,
	Role.button,
	Role.caption,
	Role.cell,
	Role.checkbox,
	Role.code,
	Role.columnheader,
	Role.combobox,
	Role.command,
	Role.complementary,
	Role.composite,
	Role.contentinfo,
	Role.definition,
	Role.deletion,
	Role.dialog,
	Role.directory,
	Role.document,
	Role.emphasis,
	Role.feed,
	Role.figure,
	Role.form,
	Role.generic,
	Role.graphicsdocument,
	Role.graphicsobject,
	Role.graphicssymbol,
	Role.grid,
	Role.gridcell,
	Role.group,
	Role.heading,
	Role.image,
	Role.img,
	Role.input,
	Role.insertion,
	Role.landmark,
	Role.link,
	Role.list,
	Role.listbox,
	Role.listitem,
	Role.log,
	Role.main,
	Role.mark,
	Role.marquee,
	Role.math,
	Role.meter,
	Role.menu,
	Role.menubar,
	Role.menuitem,
	Role.menuitemcheckbox,
	Role.menuitemradio,
	Role.navigation,
	Role.none_,
	Role.note,
	Role.option,
	Role.paragraph,
	Role.presentation,
	Role.progressbar,
	Role.radio,
	Role.radiogroup,
	Role.range_,
	Role.region,
	Role.roletype,
	Role.row,
	Role.rowgroup,
	Role.rowheader,
	Role.scrollbar,
	Role.search,
	Role.searchbox,
	Role.section,
	Role.sectionfooter,
	Role.sectionhead,
	Role.sectionheader,
	Role.select_,
	Role.separator,
	Role.slider,
	Role.spinbutton,
	Role.status,
	Role.strong,
	Role.structure,
	Role.subscript,
	Role.suggestion,
	Role.superscript,
	Role.switch_,
	Role.tab,
	Role.table,
	Role.tablist,
	Role.tabpanel,
	Role.term,
	Role.textbox,
	Role.time,
	Role.timer,
	Role.toolbar,
	Role.tooltip,
	Role.tree,
	Role.treegrid,
	Role.treeitem,
	Role.widget,
	Role.window_,
]

pub fn role_name(role Role) string {
	return match role {
		.graphicsdocument { 'graphics-document' }
		.graphicsobject { 'graphics-object' }
		.graphicssymbol { 'graphics-symbol' }
		.none_ { 'none' }
		.range_ { 'range' }
		.select_ { 'select' }
		.switch_ { 'switch' }
		.window_ { 'window' }
		else { role.str() }
	}
}

pub fn role_from_string(name string) ?Role {
	lower := name.to_lower_ascii()
	for role in all_roles {
		if role_name(role) == lower {
			return role
		}
	}
	return none
}

// https://www.w3.org/TR/wai-aria-1.2/#abstract_roles
pub fn is_abstract_role(role Role) bool {
	return role in [.command, .composite, .input, .landmark, .range_, .roletype, .section,
		.sectionhead, .select_, .structure, .widget, .window_]
}

// https://www.w3.org/TR/wai-aria-1.2/#widget_roles
pub fn is_widget_role(role Role) bool {
	return role in [.button, .checkbox, .gridcell, .link, .menuitem, .menuitemcheckbox,
		.menuitemradio, .option, .progressbar, .radio, .scrollbar, .searchbox, .separator, .slider,
		.spinbutton, .switch_, .tab, .tabpanel, .textbox, .treeitem, .combobox, .grid, .listbox,
		.menu, .menubar, .radiogroup, .tablist, .tree, .treegrid]
}

// https://www.w3.org/TR/wai-aria-1.2/#document_structure_roles
pub fn is_document_structure_role(role Role) bool {
	return role in [.application, .article, .blockquote, .caption, .cell, .code, .columnheader,
		.definition, .deletion, .directory, .document, .emphasis, .feed, .figure, .generic, .group,
		.heading, .img, .insertion, .list, .listitem, .math, .meter, .none_, .note, .paragraph,
		.presentation, .row, .rowgroup, .rowheader, .separator, .strong, .subscript, .suggestion,
		.superscript, .table, .term, .time, .toolbar, .tooltip]
}

pub fn is_landmark_role(role Role) bool {
	return role in [.banner, .complementary, .contentinfo, .form, .main, .navigation, .region,
		.search]
}

pub fn is_live_region_role(role Role) bool {
	return role in [.alert, .log, .marquee, .status, .timer]
}

pub fn is_window_role(role Role) bool {
	return role in [.alertdialog, .dialog]
}

// https://www.w3.org/TR/wai-aria-1.2/#namefromcontent
pub fn allows_name_from_content(role Role) bool {
	return role in [.button, .cell, .checkbox, .columnheader, .gridcell, .heading, .link, .menuitem,
		.menuitemcheckbox, .menuitemradio, .option, .radio, .row, .rowheader, .sectionhead, .switch_,
		.tab, .tooltip, .treeitem]
}
