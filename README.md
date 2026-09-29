# DuoCanvas

DuoCanvas is a native SwiftUI design canvas for iPhone Duo. You design on one screen and inspect on the other. It targets iOS 27.1 and later, and it also works on iPad.

The repository has two parts. `DuoCanvasCore` is the in-memory document, the command stack, and the plain layout decision. `DuoCanvas.xcodeproj` is the app: a fitted canvas, a contextual inspector, and the open or closed layout switch.

## Status

Milestone 3, full inspector. You can add a rectangle, rounded rectangle, circle, text, line, or photo, select it, and edit the properties that apply to that type. Appearance covers fill, stroke, stroke width, corner radius, and opacity. Typography covers font, size, weight, alignment, and colour, and it is shown only for text. Changes go through the editing session, so undo and redo stay one stack with the system gestures.

Not in this milestone: SwiftData, projects, export, grouping, and multi-window. Image bytes live in the session until persistence replaces that store.

## Layout

The package has three library targets:

| Target | Responsibility |
| --- | --- |
| `CanvasModel` | Value types for elements, geometry, colour, the in-memory document, and `CanvasLayoutContext` |
| `CanvasCommands` | Commands, the editing session, and its undo stack |
| `AdaptiveLayout` | Regular width uses a split. Compact width uses a sheet. No SwiftUI and no Duo types |

`CanvasCommands` and `AdaptiveLayout` depend on `CanvasModel`. Nothing in the package depends on SwiftUI, on iPhone Duo APIs, or on SwiftData.

The app is an Xcode target. It links the local package. Duo-only calls (`ArrangementView`, reserved regions, the hinge) live under `App/Duo` and are mapped to the plain types before they reach the canvas. The canvas sources do not name those APIs.

One open project is one `EditingSession`. That session owns the `CanvasDocument`, the in-memory image bytes, and the only undo stack for it. SwiftUI's `undoManager` environment value is get-only, so the app reads that instance and records into it. The toolbar and the system undo gestures then share it. Until that value appears, the session keeps a manager of its own so the toolbar still works.

## App

Open `DuoCanvas.xcodeproj` in Xcode 27.1. The run destination is the iPhone Duo simulator. The project does not set a development team or a signing identity.

The window is one `NavigationStack`. The arrangement sits inside it, not the other way around. Regular width uses `ArrangementView` with `.arrangementViewStyle(.split)`: canvas primary, inspector secondary. The system puts them side by side when the container is wider than it is tall, and stacks the canvas above the inspector when it is taller. Compact width shows the canvas and presents the inspector as a sheet from the Inspector toolbar item. The sheet uses medium and large detents, and the canvas stays interactive up through the medium detent.

The sample page is 800 by 600 points, with a rectangle, a rounded rectangle, a circle, a line, and a text label. The page is fitted to the pane. There is no pan or zoom yet. Dragging an element moves it as one undo step. A short press selects it. The selection mark is a system stroke plus square resize handles and a round rotate handle. A handle that would sit in an active reserved area slides along its edge.

With nothing selected, the inspector shows the page size and background. Those values are not editable yet. The Add menu inserts the shapes the model already has. Image uses the system photo picker. The bytes stay in the session's image store, keyed by `ImageRef`, so a later persistence pass can replace the store without changing the element.

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
3. Open, wider than tall: the canvas and the inspector sit side by side. Select a shape. Change fill, stroke, stroke width, and opacity. The canvas updates. Undo restores the previous value. Corner radius appears for the rounded rectangle and stays hidden for the circle, line, text, and image.
4. Select the text. The Typography section appears. Change the font, size, weight, alignment, and colour. Undo each one. Select a shape again and confirm Typography is gone.
5. Add an image from the photo picker. It appears on the page. Select it and move it, resize it, and change its opacity.
6. Drag a corner handle to resize, and the round handle to rotate. Undo returns the element. Fold partway, if Device Hub can, and confirm a handle near the fold slides aside instead of sitting in the reserved area.
7. Open, taller than wide (tabletop or portrait): the canvas is above the inspector.
8. Undo and redo after an inspector edit, a drag, and a handle resize. Shake and Edit > Undo should move the same step as the toolbar buttons. If the first edit happens before SwiftUI publishes an undo manager, only the toolbar has that step.
9. On the way from regular to compact, the sheet should not appear by itself. The Inspector button brings it back.

## Layer rules

- The canvas model does not know that it will be shown on iPhone Duo, iPhone, or iPad.
- Commands talk to the document. They do not talk to views.
- Undo is a command stack owned by the editing session. It is not SwiftData's undo, and this package does not import SwiftData.
- Views call `CommandManager` rather than mutating the document on their own. A direct mutation is not an undo step.
- Colours in the core are plain RGBA values. They are not SwiftUI colours.
- Do not hard-code Duo screen sizes. The default artboard (1200 by 800 points) is only a placeholder canvas size. The sample document uses 800 by 600 so the seeded shapes stay tappable when the page is fitted.

## Licence

[MIT](LICENSE). Copyright (c) 2026 Akintade Oluwaseun.
