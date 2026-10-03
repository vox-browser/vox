# Page ownership during Document creation

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.

`HTML/BrowsingContext.cpp:134–214` constructs its browsing context with the
actual `Page`, creates the Window environment with that Page, and passes it
into the initial Document. `DOM/Document.cpp:592–633` stores `m_page` before
creating the font set or initializing the document. Navigation creation at
`DOM/Document.cpp:327–446` obtains this owner from the selected browsing
context, independently of the browsing-context group's Page.

Feature commit `a12a0587` translates this ownership into the existing V model.
`BrowsingContextModel` retains its constructor Page. Its owner takes precedence
over the compatibility group lookup. The Document constructor accepting an
existing Window now accepts the actual Page and retains it before eager fonts
and DOM initialization. Navigation through an existing context keeps that
context's Page, including nested ownership when a top-level Page is supplied
as a host hint. Existing navigation entry points preserve the prior owner's
identity when they reconstruct their context.

The native `install_loaded_page()` passes its actual Page into Document
creation before parsing. The final response URL still precedes parsing and
parser-created `<base>` freezing. Disabled scripting is therefore visible to
the parser's real `<noscript>` mode during native page startup. The new native
font-construction observation verifies the actual owner and final URL before
the document element exists.

Validation in `Build/audit-fixes/worktrees/06-canvas-animation/Build/audit-fixes/`:

- `source-page-document-owner-default.log`: 2/2 files passed, including five
  focused owner tests across `html/page_document_owner_test.v` and
  `main_page_document_owner_test.v`.
- `source-page-document-owner-gc-none.log`: 4/4 files passed, adding the existing
  native document/font creation and browsing-context neighbors.

The standalone constructors with no supplied Page remain explicit host
adapters. Full source GC ownership and cross-process browsing-context creation
are separate audit boundaries. This slice changes the creation graph; the
compact script execution gate and other callback entry paths need their own
source comparisons and tests.
