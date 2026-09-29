# Decisions

Notes on judgment calls in the Milestone 1 command core. This is the in-memory model and undo stack only.

## Package shape

The core is a Swift package, `DuoCanvasCore`, with two library targets: `CanvasModel` and `CanvasCommands`. There is no app target and no SwiftUI. The manifest sets iOS 27.1 as the platform floor for the future app. The sources do not import Apple UI frameworks, so `swift test` runs on Linux.

`CanvasModel` does not import the command target. Commands are the only layer that records undo.

## Undo stack

`Foundation.UndoManager.registerUndo(withTarget:handler:)` is the API the app should use on Apple platforms. Its current signature is a main-actor method that takes a class target and a main-actor handler. `groupsByEvent` defaults to true and closes a group when the run loop turn ends.

That type is not in the Swift 6.4 Linux toolchain. `import Foundation` does not provide `UndoManager` (the compiler reports it as missing, and the Foundation library has no such symbol). swift-foundation's Linux build does not include it.

`SessionUndoManager` is the stand-in, one per `CommandManager`, and one `CommandManager` per `EditingSession`. It uses the same registration shape: `registerUndo(withTarget:handler:)`, then `setActionName`. A handler that runs during undo is recorded as redo. A handler that runs during redo is recorded as undo. A new registration at rest clears the redo stack. Each registration is one step. There is no run-loop grouping, because the tests have no run loop and because gesture grouping is explicit (see below).

The stack is internal. `CommandManager` exposes `canUndo`, `canRedo`, `undo()`, `redo()`, `undoActionName`, and `redoActionName`. Action names are the bare verb ("Move", "Fill"), matching `UndoManager.undoActionName`, not the menu title "Undo Move".

When an app target exists, this stack should be bridged to a real `UndoManager` so the system undo gestures hit the same history. That bridge is not in this package, because it cannot be compiled or tested here.

There is no SwiftData in this package, and no second undo channel.

## What one user action records

A call such as `move` or `updateStyle` applies one command and registers its inverse. The inverse is stored on the command. It does not read the document, so it stays valid after the document changes.

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

## Left out on purpose

No views, no selection type, no hit testing, no Duo types, no SwiftData models, no app project, and no dependency on a third-party package.
