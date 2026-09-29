# Decisions

Notes on judgment calls. Milestone 1 is the in-memory model and undo stack. Milestone 2 is the rough editor: canvas, transform inspector, and the open or closed layout.

## Package shape

The core is a Swift package, `DuoCanvasCore`, with three library targets: `CanvasModel`, `CanvasCommands`, and `AdaptiveLayout`. The manifest sets iOS 27.1 as the platform floor. The package sources do not import Apple UI frameworks, so `swift test` runs on Linux. The iOS app is the Xcode target, not a package target.

`CanvasModel` does not import the command target. Commands are the only layer that records undo.

## Undo stack

`Foundation.UndoManager.registerUndo(withTarget:handler:)` is the API the app should use on Apple platforms. Its current signature is a main-actor method that takes a class target and a main-actor handler. `groupsByEvent` defaults to true and closes a group when the run loop turn ends.

That type is not in the Swift 6.4 Linux toolchain. `import Foundation` does not provide `UndoManager` (the compiler reports it as missing, and the Foundation library has no such symbol). swift-foundation's Linux build does not include it.

`SessionUndoManager` is the stand-in, one per `CommandManager`, and one `CommandManager` per `EditingSession`. It uses the same registration shape: `registerUndo(withTarget:handler:)`, then `setActionName`. A handler that runs during undo is recorded as redo. A handler that runs during redo is recorded as undo. A new registration at rest clears the redo stack. Each registration is one step. There is no run-loop grouping, because the tests have no run loop and because gesture grouping is explicit (see below).

`SessionUndoManager` stays internal. `CommandManager` exposes `canUndo`, `canRedo`, `undo()`, `redo()`, `undoActionName`, and `redoActionName`, and it records through the public `UndoRecording` protocol. Action names are the bare verb ("Move", "Fill"), matching `UndoManager.undoActionName`, not the menu title "Undo Move".

The app passes a recorder that forwards to `Foundation.UndoManager`. That type still cannot live in this package, because it cannot be compiled or tested on Linux. See Milestone 2.

There is no SwiftData in this package, and no second undo channel.

## What one user action records

A call such as `move`, `resize`, `rotate`, or `updateStyle` applies one command and registers its inverse. The inverse is stored on the command. It does not read the document, so it stays valid after the document changes.

A drag or a slider is a `CoalescedEdit`: `begin`, any number of `preview` calls, then `end` or `cancel`.

- Preview writes the live document so the value is already updated.
- Preview does not register undo and does not advance `revision`.
- `end` registers one step named by the caller ("Move", "Opacity", …) from the value at `begin` to the value at `end`.
- `cancel` puts the document back and registers nothing.
- If the value at `end` matches the start, `end` registers nothing.
- A committed edit clears redo. A cancelled edit does not.

Controls with no end callback, such as a colour picker, use `recordContinuousEdit`. The key is the element plus the property. Further changes to the same key are the same step while less than 0.5 seconds have passed since the previous change. At 0.5 seconds the open step is recorded and a new one starts. The window is `CommandManager.defaultIdleInterval` and the clock is injectable (`ManualClock` in tests, `SystemCoalescingClock` otherwise). Calling `undo`, `redo`, or `perform` records any open continuous edit first, so a half-finished colour change is still one undoable step. A sequence that comes back to its starting value records nothing.

`revision` counts recorded mutations, including undo and redo. Persistence can watch it later. Equality of two documents compares id, elements, z-order, and canvas config. It ignores `revision`, so undo restores an equal document even though the counter has moved.

## Model

Elements are structs keyed by `UUID`. `order` is a separate array, back to front: index 0 is the back, the last index is the front. Delete remembers that index and undo inserts the same element there. Nothing in Foundation promises a stable order for a dictionary, so the array is the order.

`CanvasColor` is straight RGBA in 0...1. It is not clamped. `CanvasPoint`, `CanvasSize`, and `CanvasRotation` are our own types so the core does not need Core Graphics. Rotation is degrees, clockwise, and is not wrapped into a range.

A line is a position plus a size. The size is the end point minus the start, so width or height may be negative. Rectangle width and height are not forced positive either.

`ImageRef` is an id only. Image bytes are out of scope. `parentID` and `childIDs` are stored and round-trip through insert and delete. They are not kept in sync when a child is removed. Grouping commands are later.

The default artboard is 1200 by 800 points with a white background. That is a placeholder canvas, not a phone or Duo size.

Shape factories start with an opaque black fill. Text factories use Helvetica Neue at 17 points as plain data. They do not look up a system font.

`CanvasDocument` is an `@Observable` class. The Observation library ships with the Swift 6.4 Linux toolchain, so the macro is compiled and tested here rather than hidden behind a platform check. The class is main-actor isolated, like the editing session and like `UndoManager` on Apple platforms. `==` is a nonisolated `Equatable` witness that reads the document with `MainActor.assumeIsolated`, so two documents can be compared in tests without making the conformance cross actors.

Document mutation methods are public because the command target is a separate module. The editing rule is still: the session's `CommandManager` is what records history. A direct `insert` or `update` changes the document and `revision`, and it is not an undo step.

An edit that does not change stored content, such as a move to the current position, is not pushed onto the stack.

## Left out of Milestone 1 on purpose

No views, no selection type, no hit testing, no Duo types, no SwiftData models, no app project, and no dependency on a third-party package.

## Milestone 2

### Where the app lives

The app is an Xcode target, `DuoCanvas.xcodeproj`, linking this package. A Swift package executable is not an iOS app the Duo simulator can run. The package stays free of SwiftUI so `swift test` still runs on Linux. The iOS 27.1 SDK is not installed here, so the app target was not compiled in this environment.

Availability is the deployment target, iOS 27.1. A redundant `#available(iOS 27.1, *)` check would be dead and would warn. There is no second layout path for older systems.

The project file does not set a development team or a code signing identity.

### Layout

`EditorArrangement` maps regular width to `.split` and both compact and unspecified to `.sheet`. Unspecified is the sheet so the app does not build an `ArrangementView` before the size class exists.

`App/Duo/DuoSplit.swift` is the only view that constructs `ArrangementView`. The style is `.arrangementViewStyle(.split)`. Axes are not restricted. `.split.axes(.horizontal)` can hide the secondary view when the container is taller than it is wide, which would drop the inspector in portrait and tabletop.

The inspector carries `splitArrangementLayoutSize` of 280–320–400 points wide and 240–320–480 points tall. Width applies to a horizontal split and height to a vertical split. `layoutPriority(1)` on the canvas asks the split to give leftover space to the page. Whether a fold overrides these sizes is unconfirmed until Device Hub.

The navigation stack is outside the arrangement. The compact inspector sheet has its own navigation stack for the title and Done button. That stack is a sheet, not a child of `ArrangementView`.

Going from regular to compact dismisses the sheet flag and does not present the sheet again. The Inspector toolbar item is shown only for the sheet arrangement. It has a title and a symbol.

### Reserved regions and the hinge

`ReservedRegionMapping` calls `reservedRegions(kind:options:)` for `.division` and `.occlusion`, both with `[.includeInactive]`. It does not pass a layout-direction behaviour, so frames stay mirrored with the rest of SwiftUI. `region.margins` is read as `top`, `leading`, `bottom`, and `trailing`. Region ids are stored with `String(describing:)`. If either of those shapes differs from the 27.1 SDK, this is the file that will fail to compile.

The canvas receives `CanvasLayoutContext` and does not name the system types. An active reserved area that crosses an element's unrotated frame thickens the selection stroke by one point. The element itself does not move. There are no selection handles, so nothing is displaced along an edge. That waits.

`onHingeChange` only cancels an in-flight drag when the status string changes. It does not choose the layout. The first callback is the current status and does not cancel.

### Editing

X and Y commit with `MoveElementCommand`. W and H commit with `ResizeElementCommand`. Rotation commits with `RotateElementCommand`, named "Rotate". Rotation is not part of `ElementStyle`, so it is not an `UpdateStyleCommand`.

A field keeps keystrokes locally and commits when editing ends or the stepper moves. The decimal pad has no Return key, so the inspector adds a keyboard Done button that resigns first responder. That is UIKit, used because SwiftUI does not offer a Return key on that pad.

Dragging an element uses `beginCoalescedEdit` / `preview` / `end`, so one drag is one undo step named "Move". The gesture lives on the page, not on each shape. A movement under 10 points is a tap. Hit testing uses the unrotated bounding box. A circle is drawn as an ellipse, so width and height both apply. A line is a stroke through the centre of its box, then the element rotation is applied. An element with no paint still gets a faint fill so it can be selected. Image bytes are still absent; an image element draws a placeholder. Groups draw a dashed box. Neither is in the sample document.

The sample page is 800 by 600 points. The model default stays 1200 by 800. The smaller page is only so the seeded shapes stay tappable when the whole page is fitted. There is no pan or zoom.

The selection mark is an accent-coloured stroke. Increased contrast uses a thicker stroke. VoiceOver gets a label and the selected trait. The stroke is a shape, so the selection is not colour alone.

### Undo bridge

`CommandManager` records into an `UndoRecording`. Tests keep `SessionUndoManager`. The app starts with `SystemUndoRecording` around a private `UndoManager` (`groupsByEvent` left on). `EnvironmentValues.undoManager` is `UndoManager?` with a getter only, so `.environment(\.undoManager, ...)` does not compile on the iOS 27.1 SDK. `EditorRoot` reads that value and, while the stack is still empty, retargets the session at it. Shake and the Edit menu call that same object. A later edit does not move history onto a different manager. A drag that is still open is cancelled before undo or redo, so the unfinished drag is not a step.

### Left out of Milestone 2 on purpose

No appearance or typography inspector, no font picker, no colour picker, no image insert, no custom handles, no SwiftData, no export, no grouping commands, no extra windows, and no design-system controls.

## Milestone 3

### Inspector

`InspectorFieldSet` decides which controls a type shows. The view does not invent a second set of rules.

- Rectangle, rounded rectangle, and circle: fill, stroke, opacity. Corner radius only on the rounded rectangle. The plain rectangle renderer ignores `cornerRadius`, so the control stays on the type that draws it.
- Line: stroke and opacity. No fill. A line always has a stroke, so the inspector does not offer to remove it.
- Text: opacity, plus the typography section. Fill and stroke stay hidden. Text colour is the typography colour.
- Image and group: opacity only.
- Nothing selected: the document section from Milestone 2. Canvas size and background are still not editable.

The transform block keeps the element name as its header. Appearance and Typography are the sections under it.

Fill and stroke colour pickers use `supportsOpacity: false`. Element opacity is the separate slider, so the picker does not add a second opacity control. A picker change keeps the colour's existing alpha. Values within 1/512 in each channel count as the same colour, so a picker that echoes its current value does not record a step.

Sliders (opacity, stroke width, corner radius) use one coalesced edit per drag, the same path as a move. Numeric fields and steppers commit one command when editing ends. Colour pickers have no end callback, so they use `recordContinuousEdit` and the 0.5 second idle window. The editor flushes that window about 0.6 seconds after the last change, which is what makes the undo button show the step without waiting for the next command.

Shapes with no stroke show Add Stroke. Remove Stroke deletes it. A new shape from the Add menu already has a fill.

### Typography

There is still no SwiftUI font picker. `FontFamilyPicker` wraps `UIFontPickerViewController` and leaves `includeFaces` off, so the control chooses a family. The weight picker is what changes the face, and the canvas draws `Font.custom(family).weight(...)`. The stored `fontName` is `UIFont.familyName`.

Size, weight, alignment, and colour are native controls. Weight uses a menu picker so it does not push a list through the arrangement. Alignment is segmented. The text string is a field too: the model already stores it, and an inserted label would otherwise stay stuck on "Text". That field commits when editing ends, like the numeric fields.

`UpdateTextCommand` is the reversible edit. One changed field names the step ("Font", "Size", "Weight", "Alignment", "Text Color"). Several fields at once are "Text".

### Images

`PhotosPicker` sits in the Add menu. The picked bytes go into `CanvasImageStore` on the editing session, under a new `ImageRef` id. The document still stores the id only. Undo of the insert removes the element and leaves the bytes, so redo can draw the same id. Milestone 4 should replace this map with SwiftData external storage and keep the id. The canvas draws the bytes with a resizable image, clipped to the element frame. Until the bytes exist, the placeholder remains.

A new image is fitted so its longer side is 240 points. The page has no zoom yet, so a full-resolution photo would be an untappable sliver once the page is fitted.

### Selection handles

The overlay is custom. No system control draws resize handles on a canvas object. Handles are hidden from VoiceOver; the transform fields do the same job.

Eight square handles resize. A circle above the top edge rotates, so the two jobs are different shapes and not colour alone. The drawn mark is about 8 points. The hit box is 44 points. Increased contrast thickens the stroke and uses the primary colour.

A drag on a handle is one Resize or Rotate step. Resize keeps the opposite edge fixed in canvas space, including when the element is rotated. Shapes stop at 8 points on a side. A line stops at 1 point, because its size is the end offset and a larger minimum would fight a short stroke.

If a handle's hit box meets an active reserved area, the handle slides along its edge to the nearest clear sample, in 2 point steps. A corner may use either edge. If the whole edge is blocked, the handle stays put. The numeric fields are still there. Inactive areas do not move anything. The element itself does not move.

The hit shape is only the handle boxes, so a drag that starts on the element body still moves it.

### Add menu

Rectangle, rounded rectangle, circle, text, line, and image. Group stays out. There is no grouping command yet, and the prompt leaves that for later.

### Left out on purpose

No SwiftData, no projects, no PNG export, no design-system wrappers, and no change to how the split and the sheet are chosen. The undo bridge still reads `EnvironmentValues.undoManager` and does not assign it.
