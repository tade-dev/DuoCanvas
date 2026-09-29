# DuoCanvas

DuoCanvas is a native SwiftUI design canvas for iPhone Duo. You design on one screen and inspect on the other. It targets iOS 27.1 and later, and it also works on iPad.

The repository has two parts. `DuoCanvasCore` is the in-memory document, the command stack, and the plain layout decision. `DuoCanvas.xcodeproj` is the app: a fitted canvas, a transform inspector, and the open or closed layout switch.

## Status

Milestone 2, rough Duo split. You can select an element, open the inspector, change X, Y, W, H, or rotation, and undo that edit. The canvas and the inspector share one editing session, so the page updates from the command path.

Not in this milestone: appearance and typography controls, the font picker, selection handles, image insert, SwiftData, export, grouping, and multi-window.

## Layout

The package has three library targets:

| Target | Responsibility |
| --- | --- |
| `CanvasModel` | Value types for elements, geometry, colour, the in-memory document, and `CanvasLayoutContext` |
| `CanvasCommands` | Commands, the editing session, and its undo stack |
| `AdaptiveLayout` | Regular width uses a split. Compact width uses a sheet. No SwiftUI and no Duo types |

`CanvasCommands` and `AdaptiveLayout` depend on `CanvasModel`. Nothing in the package depends on SwiftUI, on iPhone Duo APIs, or on SwiftData.

The app is an Xcode target. It links the local package. Duo-only calls (`ArrangementView`, reserved regions, the hinge) live under `App/Duo` and are mapped to the plain types before they reach the canvas. The canvas sources do not name those APIs.

One open project is one `EditingSession`. That session owns the `CanvasDocument` and the only undo stack for it. SwiftUI's `undoManager` environment value is get-only, so the app reads that instance and records into it. The toolbar and the system undo gestures then share it. Until that value appears, the session keeps a manager of its own so the toolbar still works.

## App

Open `DuoCanvas.xcodeproj` in Xcode 27.1. The run destination is the iPhone Duo simulator. The project does not set a development team or a signing identity.

The window is one `NavigationStack`. The arrangement sits inside it, not the other way around. Regular width uses `ArrangementView` with `.arrangementViewStyle(.split)`: canvas primary, inspector secondary. The system puts them side by side when the container is wider than it is tall, and stacks the canvas above the inspector when it is taller. Compact width shows the canvas and presents the inspector as a sheet from the Inspector toolbar item. The sheet uses medium and large detents, and the canvas stays interactive up through the medium detent.

The sample page is 800 by 600 points, with a rectangle, a rounded rectangle, a circle, a line, and a text label. The page is fitted to the pane. There is no pan or zoom yet. Dragging an element moves it as one undo step. A short press selects it. The selection mark is a system stroke, not a set of handles.

With nothing selected, the inspector shows the page size and background. Those values are not editable yet.

## Build and test

The package tests need Swift 6. They were run with Swift 6.4 on Linux. The app is not part of that build. This environment has no iOS 27.1 SDK, so the Duo target was not compiled here.

```sh
swift build
swift test
```

No Xcode project is required for the core. The iOS deployment target is 27.1.

## Device Hub

Check these on the iPhone Duo simulator in Xcode 27.1. This environment could not run them.

1. Open `DuoCanvas.xcodeproj` and run it on the Duo simulator.
2. Closed, or any compact width: the canvas is alone. Tap Inspector. The sheet appears. Change X or Y and leave the field. The element moves. Dismiss the sheet. The selection stays.
3. Open, wider than tall: the canvas and the inspector sit side by side. Select an element. Change W or H. The element resizes.
4. Open, taller than wide (tabletop or portrait): the canvas is above the inspector.
5. Undo and redo after an inspector edit, and after a drag. Shake and Edit > Undo should move the same step as the toolbar buttons. If the first edit happens before SwiftUI publishes an undo manager, only the toolbar has that step.
6. Fold partway, if Device Hub can. The split should follow the fold. Nothing should crash. Confirm whether the inspector keeps the 320 point preference or the system forces a half-and-half split.
7. On the way from regular to compact, the sheet should not appear by itself. The Inspector button brings it back.

## Layer rules

- The canvas model does not know that it will be shown on iPhone Duo, iPhone, or iPad.
- Commands talk to the document. They do not talk to views.
- Undo is a command stack owned by the editing session. It is not SwiftData's undo, and this package does not import SwiftData.
- Views call `CommandManager` rather than mutating the document on their own. A direct mutation is not an undo step.
- Colours in the core are plain RGBA values. They are not SwiftUI colours.
- Do not hard-code Duo screen sizes. The default artboard (1200 by 800 points) is only a placeholder canvas size. The sample document uses 800 by 600 so the seeded shapes stay tappable when the page is fitted.

## Licence

[MIT](LICENSE). Copyright (c) 2026 Akintade Oluwaseun.
