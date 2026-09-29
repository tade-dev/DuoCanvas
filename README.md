# DuoCanvas

DuoCanvas is a native SwiftUI design canvas for iPhone Duo. You design on one screen and inspect on the other. It targets iOS 27.1 and later, and it also works on iPad.

This repository is the start of that app. It currently contains the editing core only: an in-memory canvas document and a command stack with undo and redo. There is no application target, no SwiftUI views, and no SwiftData yet.

The core is early. It is enough to insert, delete, move, resize, and restyle elements, and to undo those edits as single named steps.

## Status

Milestone 1, command core. Later milestones add the canvas UI, the inspector, project persistence, and the Duo layout. Those are not in this package.

## Layout

The package has two library targets:

| Target | Responsibility |
| --- | --- |
| `CanvasModel` | Value types for elements, geometry, colour, and the in-memory document |
| `CanvasCommands` | Commands, the editing session, and its undo stack |

`CanvasCommands` depends on `CanvasModel`. Nothing in either target depends on SwiftUI, on iPhone Duo APIs, or on SwiftData.

One open project is one `EditingSession`. That session owns the `CanvasDocument` and the only undo stack for it. Two sessions do not share history.

## Build and test

You need Swift 6. The package manifest uses tools version 6.0. These tests were run with Swift 6.4 on Linux.

```sh
swift build
swift test
```

No Xcode project is required for the core. The iOS deployment target in `Package.swift` is 27.1, which is what the future app will use. The sources themselves stay free of Apple-only frameworks so the tests run on Linux.

## Layer rules

- The canvas model does not know that it will be shown on iPhone Duo, iPhone, or iPad.
- Commands talk to the document. They do not talk to views.
- Undo is a command stack owned by the editing session. It is not SwiftData's undo, and this package does not import SwiftData.
- Views, when they exist, should call `CommandManager` rather than mutating the document on their own. A direct mutation is not an undo step.
- Colours in the core are plain RGBA values. They are not SwiftUI colours.
- Do not hard-code Duo screen sizes. The default artboard (1200 by 800 points) is only a placeholder canvas size.

## Licence

[MIT](LICENSE). Copyright (c) 2026 Akintade Oluwaseun.
