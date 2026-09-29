# DuoCanvas

DuoCanvas is a native SwiftUI design canvas for iPhone Duo. You design on one screen and inspect on the other. It targets iOS 27.1 and later, and it also works on iPad.

The repository has two parts. `DuoCanvasCore` is the in-memory document, the command stack, the plain layout decision, and the mapping between a canvas and flat project fields. `DuoCanvas.xcodeproj` is the app: projects, a fitted canvas, a contextual inspector, and the open or closed layout switch.

## Status

Milestone 6, editing. Duplicate, group, and ungroup are commands on the same undo stack. A selection can hold more than one element; the inspector edits the primary, and the others are marked with a dashed stroke and no handles. Copy and paste use a Transferable clipboard. Delete, the arrow keys, and ⌘D edit the selection. ⌘Z and ⇧⌘Z still go through the system undo manager. Export PNG shares the committed page. A drag preview still does not write.

Milestone 4, persistence, is unchanged. The app opens on a project list. You can create a project, rename it, open it, and delete it after a confirmation. The list is ordered by when the project was last opened. The editor saves when a command commits, including undo and redo. Image bytes are stored with the element and come back with the same id after a relaunch.

SwiftData undo stays off. The command stack is still the only undo history. The canvas package does not import SwiftData.

Not in this milestone: thumbnails, hinge hardening, and multi-window. The thumbnail column exists and is left empty.

## Layout

The package has three library targets:

| Target | Responsibility |
| --- | --- |
| `CanvasModel` | Value types for elements, geometry, colour, the in-memory document, and `CanvasLayoutContext` |
| `CanvasCommands` | Commands, the editing session, and its undo stack |
| `AdaptiveLayout` | Regular width uses a split. Compact width uses a sheet. No SwiftUI and no Duo types |
| `PersistenceMapping` | Flat project fields, document round trip, and recents order. No SwiftData |

`CanvasCommands` and `AdaptiveLayout` depend on `CanvasModel`. Nothing in the package depends on SwiftUI, on iPhone Duo APIs, or on SwiftData.

The app is an Xcode target. It links the local package. Duo-only calls (`ArrangementView`, reserved regions, the hinge) live under `App/Duo` and are mapped to the plain types before they reach the canvas. The canvas sources do not name those APIs. SwiftData models live under `App/Persistence`.

One open project is one `EditingSession`. That session owns the `CanvasDocument`, the in-memory image bytes, and the only undo stack for it. SwiftUI's `undoManager` environment value is get-only, so the app reads that instance and records into it. The toolbar and the system undo gestures then share it. Until that value appears, the session keeps a manager of its own so the toolbar still works. The model context's undo manager stays nil.

## App

Open `DuoCanvas.xcodeproj` in Xcode 27.1. The run destination is the iPhone Duo simulator. The project does not set a development team or a signing identity.

The window is one `NavigationStack`. Home is the root. The arrangement sits inside the editor, not the other way around. Regular width uses `ArrangementView` with `.arrangementViewStyle(.split)`: canvas primary, inspector secondary. The system puts them side by side when the container is wider than it is tall, and stacks the canvas above the inspector when it is taller. Compact width shows the canvas and presents the inspector as a sheet from the Inspector toolbar item. The sheet uses medium and large detents, and the canvas stays interactive up through the medium detent.

A new project is an empty 1200 by 800 point page. The page is fitted to the pane. There is no pan or zoom yet. Hold a press on an element for about a quarter second, then drag, to move it as one undo step. A short press selects it and does not resize. Square resize handles and the round rotate handle respond as soon as they are dragged; they do not wait for that hold. A drag that starts on the element body does not resize it. A handle that would sit in an active reserved area slides along its edge.

With nothing selected, the inspector shows the page size and background. Those values are not editable yet. The Add menu inserts the shapes the model already has. Image uses the system photo picker. The bytes stay in the session until the command commits, then they are stored with the element under the same `ImageRef` id.

Arrange duplicates the selection, or groups and ungroups it. A tap on a grouped element selects the group. Shift-tap adds or removes an element. The inspector keeps editing the primary selection. Arrow keys nudge by one point. Delete removes the selection. ⌘D duplicates, and ⌘C / ⌘V copy and paste, when the canvas is focused. Export PNG shares the page without selection marks.

## Build and test

The package tests need Swift 6. They were run with Swift 6.4 on Linux (99 tests). The app is not part of that build. This environment has no iOS 27.1 SDK, so the Duo target, the SwiftData container, Transferable, and ImageRenderer were not compiled here.

```sh
swift build
swift test
```

No Xcode project is required for the core. The iOS deployment target is 27.1.

## Device Hub

Check these on the iPhone Duo simulator in Xcode 27.1. This environment could not run them.

1. Pull this branch, open `DuoCanvas.xcodeproj`, and run it on the Duo simulator.
2. Home: create a project. It appears in Recents.
3. Open it. Add a shape, edit it, and add an image from the photo picker. Stop the app and launch it again. The project, the shape, and the image are still there.
4. Rename a project. Delete one, and confirm the dialog is required. Recents follows the last time a project was opened.
5. Undo and redo a canvas edit. Shake and Edit > Undo should move the same step as the toolbar. SwiftData should not add a second undo step.
6. Closed, or any compact width: the canvas is alone. Inspector opens as a sheet. Open, wider than tall: canvas and inspector sit side by side. Open, taller than wide: the canvas is above the inspector.
7. On the way from regular to compact, the sheet should not appear by itself.
8. Thumbnails are not generated. Rows show the name and the last-opened time.
9. On the canvas, a short press selects an element. Hold about a quarter second, then drag, to move it. Drag a resize handle and it changes width or height immediately. Dragging the element body does not resize it.
10. Select an element and duplicate it from Arrange or with ⌘D. Undo removes the copy in one step. The original stays.
11. Select two elements and group them. The group moves as one object, including its children. Ungroup puts the elements back. Undo and redo each of those as one step.
12. Shift-tap a second element. The inspector still edits the primary. The other element has a dashed outline and no handles. Add to Selection works from VoiceOver.
13. Copy and paste the selection. The paste sits slightly down and to the right. An image still draws. Undo removes the pasted elements.
14. With the canvas focused, Delete removes the selection, and the arrow keys nudge it by one point. ⌘Z and ⇧⌘Z still undo and redo the same stack as the toolbar.
15. Export PNG and share it. The image is the page, without selection handles. A drag that has not been released is not in the file. After a committed edit, stop the app and open the project again. The duplicate, the group, and the paste are still there.

## Layer rules

- The canvas model does not know that it will be shown on iPhone Duo, iPhone, or iPad.
- Commands talk to the document. They do not talk to views.
- Undo is a command stack owned by the editing session. It is not SwiftData's undo, and this package does not import SwiftData.
- Views call `CommandManager` rather than mutating the document on their own. A direct mutation is not an undo step.
- Colours in the core are plain RGBA values. They are not SwiftUI colours.
- Do not hard-code Duo screen sizes. The default artboard (1200 by 800 points) is only a placeholder canvas size. The sample document uses 800 by 600 so the seeded shapes stay tappable when the page is fitted.

## Licence

[MIT](LICENSE). Copyright (c) 2026 Akintade Oluwaseun.
