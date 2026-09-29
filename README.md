# DuoCanvas

DuoCanvas is a native SwiftUI design canvas for iPhone Duo. You design on one screen and inspect on the other. It targets iOS 27.1 and later, and it also works on iPad.

The repository has two parts. `DuoCanvasCore` is the in-memory document, the command stack, the plain layout decision, and the mapping between a canvas and flat project fields. `DuoCanvas.xcodeproj` is the app: projects, a fitted canvas, a contextual inspector, and the open or closed layout switch.

## Status

Milestone 4, persistence. The app opens on a project list. You can create a project, rename it, open it, and delete it after a confirmation. The list is ordered by when the project was last opened. The editor saves when a command commits, including undo and redo. A drag preview does not write. Image bytes are stored with the element and come back with the same id after a relaunch.

SwiftData undo stays off. The command stack is still the only undo history. The canvas package does not import SwiftData.

Not in this milestone: thumbnails, export, grouping, and multi-window. The thumbnail column exists and is left empty.

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

A new project is an empty 1200 by 800 point page. The page is fitted to the pane. There is no pan or zoom yet. Dragging an element moves it as one undo step. A short press selects it. The selection mark is a system stroke plus square resize handles and a round rotate handle. A handle that would sit in an active reserved area slides along its edge.

With nothing selected, the inspector shows the page size and background. Those values are not editable yet. The Add menu inserts the shapes the model already has. Image uses the system photo picker. The bytes stay in the session until the command commits, then they are stored with the element under the same `ImageRef` id.

## Build and test

The package tests need Swift 6. They were run with Swift 6.3.3 on Linux (75 tests). The app is not part of that build. This environment has no iOS 27.1 SDK, so the Duo target and the SwiftData container were not compiled here.

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

## Layer rules

- The canvas model does not know that it will be shown on iPhone Duo, iPhone, or iPad.
- Commands talk to the document. They do not talk to views.
- Undo is a command stack owned by the editing session. It is not SwiftData's undo, and this package does not import SwiftData.
- Views call `CommandManager` rather than mutating the document on their own. A direct mutation is not an undo step.
- Colours in the core are plain RGBA values. They are not SwiftUI colours.
- Do not hard-code Duo screen sizes. The default artboard (1200 by 800 points) is only a placeholder canvas size. The sample document uses 800 by 600 so the seeded shapes stay tappable when the page is fitted.

## Licence

[MIT](LICENSE). Copyright (c) 2026 Akintade Oluwaseun.
