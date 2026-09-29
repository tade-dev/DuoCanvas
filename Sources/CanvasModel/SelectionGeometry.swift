import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// A resize or rotate affordance on the selection overlay.
public enum SelectionHandle: Equatable, Hashable, Sendable, CaseIterable {
    case topLeading
    case top
    case topTrailing
    case leading
    case trailing
    case bottomLeading
    case bottom
    case bottomTrailing
    case rotate
}

/// Where one handle is drawn, in the element's visual frame.
///
/// The origin is the top-left of the unrotated box. Y increases downward.
/// Units match `localSize` passed to the layout, which the view expresses in pane points.
public struct SelectionHandlePlacement: Equatable, Hashable, Sendable {
    public var handle: SelectionHandle
    public var center: CanvasPoint

    public init(handle: SelectionHandle, center: CanvasPoint) {
        self.handle = handle
        self.center = center
    }
}

/// Positions selection handles and slides any that sit in an active reserved area.
///
/// The slide stays on the handle's edge. A corner may travel along either edge that
/// meets there. If the whole edge is blocked, the handle stays on its ideal point;
/// the inspector's numeric fields remain the way to resize.
public enum SelectionHandleLayout {
    /// Hit box, in the same units as the placements. Matches the 44 point control minimum.
    public static let hitExtent: Double = 44
    /// How far the rotate handle sits above the top edge.
    public static let rotateGap: Double = 36

    public static func placements(
        localSize: CanvasSize,
        rotationDegrees: Double,
        paneOrigin: CanvasPoint,
        reservedAreas: [CanvasReservedArea],
        hitExtent: Double = SelectionHandleLayout.hitExtent
    ) -> [SelectionHandlePlacement] {
        let width = abs(localSize.width)
        let height = abs(localSize.height)
        let active = reservedAreas.filter(\.isActive)
        return SelectionHandle.allCases.map { handle in
            let ideal = idealCenter(handle, width: width, height: height)
            let center = resolvedCenter(
                handle: handle,
                ideal: ideal,
                width: width,
                height: height,
                rotationDegrees: rotationDegrees,
                paneOrigin: paneOrigin,
                reservedAreas: active,
                hitExtent: hitExtent
            )
            return SelectionHandlePlacement(handle: handle, center: center)
        }
    }

    /// The handle whose hit box contains `local`, preferring the closest center when boxes overlap.
    public static func hitHandle(
        at local: CanvasPoint,
        centers: [SelectionHandle: CanvasPoint],
        hitExtent: Double = SelectionHandleLayout.hitExtent
    ) -> SelectionHandle? {
        let half = hitExtent / 2
        var bestHandle: SelectionHandle?
        var bestDistance = Double.greatestFiniteMagnitude
        for (handle, center) in centers {
            let dx = abs(local.x - center.x)
            let dy = abs(local.y - center.y)
            guard dx <= half, dy <= half else { continue }
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                bestHandle = handle
            }
        }
        return bestHandle
    }

    private static func idealCenter(_ handle: SelectionHandle, width: Double, height: Double) -> CanvasPoint {
        switch handle {
        case .topLeading:
            CanvasPoint(x: 0, y: 0)
        case .top:
            CanvasPoint(x: width / 2, y: 0)
        case .topTrailing:
            CanvasPoint(x: width, y: 0)
        case .leading:
            CanvasPoint(x: 0, y: height / 2)
        case .trailing:
            CanvasPoint(x: width, y: height / 2)
        case .bottomLeading:
            CanvasPoint(x: 0, y: height)
        case .bottom:
            CanvasPoint(x: width / 2, y: height)
        case .bottomTrailing:
            CanvasPoint(x: width, y: height)
        case .rotate:
            CanvasPoint(x: width / 2, y: -rotateGap)
        }
    }

    private static func resolvedCenter(
        handle: SelectionHandle,
        ideal: CanvasPoint,
        width: Double,
        height: Double,
        rotationDegrees: Double,
        paneOrigin: CanvasPoint,
        reservedAreas: [CanvasReservedArea],
        hitExtent: Double
    ) -> CanvasPoint {
        guard !reservedAreas.isEmpty else { return ideal }
        func blocked(_ local: CanvasPoint) -> Bool {
            let pane = panePoint(
                local: local,
                width: width,
                height: height,
                rotationDegrees: rotationDegrees,
                paneOrigin: paneOrigin
            )
            let half = hitExtent / 2
            let hit = CanvasRect(
                origin: CanvasPoint(x: pane.x - half, y: pane.y - half),
                size: CanvasSize(width: hitExtent, height: hitExtent)
            )
            return reservedAreas.contains { $0.frame.intersects(hit) }
        }
        guard blocked(ideal) else { return ideal }
        var best = ideal
        var bestDistance = Double.greatestFiniteMagnitude
        var found = false
        for sample in samples(for: handle, width: width, height: height) {
            guard !blocked(sample) else { continue }
            let dx = sample.x - ideal.x
            let dy = sample.y - ideal.y
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                best = sample
                found = true
            }
        }
        return found ? best : ideal
    }

    /// Samples along the edges a handle is allowed to travel. Step is 2 points.
    private static func samples(for handle: SelectionHandle, width: Double, height: Double) -> [CanvasPoint] {
        var points: [CanvasPoint] = []
        func horizontal(y: Double) {
            append(range: 0...max(width, 0), at: y, horizontal: true, into: &points)
        }
        func vertical(x: Double) {
            append(range: 0...max(height, 0), at: x, horizontal: false, into: &points)
        }
        switch handle {
        case .top:
            horizontal(y: 0)
        case .bottom:
            horizontal(y: height)
        case .leading:
            vertical(x: 0)
        case .trailing:
            vertical(x: width)
        case .topLeading:
            horizontal(y: 0)
            vertical(x: 0)
        case .topTrailing:
            horizontal(y: 0)
            vertical(x: width)
        case .bottomLeading:
            horizontal(y: height)
            vertical(x: 0)
        case .bottomTrailing:
            horizontal(y: height)
            vertical(x: width)
        case .rotate:
            append(range: 0...max(width, 0), at: -rotateGap, horizontal: true, into: &points)
        }
        return points
    }

    private static func append(
        range: ClosedRange<Double>,
        at fixed: Double,
        horizontal: Bool,
        into points: inout [CanvasPoint]
    ) {
        let step = 2.0
        let lower = range.lowerBound
        let upper = range.upperBound
        guard upper > lower else {
            points.append(horizontal ? CanvasPoint(x: lower, y: fixed) : CanvasPoint(x: fixed, y: lower))
            return
        }
        var cursor = lower
        while cursor < upper {
            points.append(horizontal ? CanvasPoint(x: cursor, y: fixed) : CanvasPoint(x: fixed, y: cursor))
            cursor += step
        }
        points.append(horizontal ? CanvasPoint(x: upper, y: fixed) : CanvasPoint(x: fixed, y: upper))
    }

    private static func panePoint(
        local: CanvasPoint,
        width: Double,
        height: Double,
        rotationDegrees: Double,
        paneOrigin: CanvasPoint
    ) -> CanvasPoint {
        let centerX = paneOrigin.x + width / 2
        let centerY = paneOrigin.y + height / 2
        let (rx, ry) = rotateClockwise(
            x: local.x - width / 2,
            y: local.y - height / 2,
            degrees: rotationDegrees
        )
        return CanvasPoint(x: centerX + rx, y: centerY + ry)
    }
}

/// Resize and rotate math shared by the canvas overlay.
///
/// Resize keeps the opposite edge fixed in canvas space, including while the element
/// is rotated. Translation is expressed in the element's local axes, in canvas points.
public enum SelectionGeometry {
    public struct Box: Equatable, Sendable {
        public var position: CanvasPoint
        public var size: CanvasSize

        public init(position: CanvasPoint, size: CanvasSize) {
            self.position = position
            self.size = size
        }
    }

    public static func resized(
        handle: SelectionHandle,
        position: CanvasPoint,
        size: CanvasSize,
        rotationDegrees: Double,
        localTranslation: CanvasPoint,
        minimumLength: Double
    ) -> Box {
        guard handle != .rotate else {
            return Box(position: position, size: size)
        }
        let box = CanvasRect(origin: position, size: size).standardized
        let startWidth = box.size.width
        let startHeight = box.size.height
        var width = startWidth
        var height = startHeight
        switch handle {
        case .trailing, .topTrailing, .bottomTrailing:
            width = startWidth + localTranslation.x
        case .leading, .topLeading, .bottomLeading:
            width = startWidth - localTranslation.x
        default:
            break
        }
        switch handle {
        case .bottom, .bottomLeading, .bottomTrailing:
            height = startHeight + localTranslation.y
        case .top, .topLeading, .topTrailing:
            height = startHeight - localTranslation.y
        default:
            break
        }
        let floor = max(minimumLength, 0)
        width = max(floor, width)
        height = max(floor, height)

        let startAnchor = anchor(for: handle, width: startWidth, height: startHeight)
        let anchorCanvas = canvasPoint(
            localX: startAnchor.x,
            localY: startAnchor.y,
            position: box.origin,
            size: box.size,
            rotationDegrees: rotationDegrees
        )
        let newSize = CanvasSize(width: width, height: height)
        let newAnchor = anchor(for: handle, width: width, height: height)
        let (rotatedX, rotatedY) = rotateClockwise(
            x: newAnchor.x - width / 2,
            y: newAnchor.y - height / 2,
            degrees: rotationDegrees
        )
        let center = CanvasPoint(x: anchorCanvas.x - rotatedX, y: anchorCanvas.y - rotatedY)
        let origin = CanvasPoint(x: center.x - width / 2, y: center.y - height / 2)
        return Box(position: origin, size: newSize)
    }

    /// Converts a drag in artboard points into canvas points along the element's axes.
    public static func localTranslation(
        artboardX: Double,
        artboardY: Double,
        scale: Double,
        rotationDegrees: Double
    ) -> CanvasPoint {
        guard scale > 0 else { return .zero }
        let canvasX = artboardX / scale
        let canvasY = artboardY / scale
        let (x, y) = rotateCounterClockwise(x: canvasX, y: canvasY, degrees: rotationDegrees)
        return CanvasPoint(x: x, y: y)
    }

    /// Maps an artboard point into the element's visual frame.
    public static func localPoint(
        artboardX: Double,
        artboardY: Double,
        centerX: Double,
        centerY: Double,
        rotationDegrees: Double,
        visualWidth: Double,
        visualHeight: Double
    ) -> CanvasPoint {
        let (x, y) = rotateCounterClockwise(
            x: artboardX - centerX,
            y: artboardY - centerY,
            degrees: rotationDegrees
        )
        return CanvasPoint(x: x + visualWidth / 2, y: y + visualHeight / 2)
    }

    /// A point in the unrotated box, mapped into canvas space. `position` is the box's top-left.
    public static func canvasPoint(
        localX: Double,
        localY: Double,
        position: CanvasPoint,
        size: CanvasSize,
        rotationDegrees: Double
    ) -> CanvasPoint {
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2
        let (rx, ry) = rotateClockwise(
            x: localX - size.width / 2,
            y: localY - size.height / 2,
            degrees: rotationDegrees
        )
        return CanvasPoint(x: centerX + rx, y: centerY + ry)
    }

    /// Shortest clockwise change, in degrees. Positive is clockwise, matching `CanvasRotation`.
    public static func clockwiseDeltaDegrees(from previousRadians: Double, to nextRadians: Double) -> Double {
        var delta = nextRadians - previousRadians
        let turn = Double.pi * 2
        while delta > Double.pi {
            delta -= turn
        }
        while delta <= -Double.pi {
            delta += turn
        }
        return delta * 180 / Double.pi
    }

    private static func anchor(for handle: SelectionHandle, width: Double, height: Double) -> CanvasPoint {
        switch handle {
        case .topLeading:
            CanvasPoint(x: width, y: height)
        case .top:
            CanvasPoint(x: width / 2, y: height)
        case .topTrailing:
            CanvasPoint(x: 0, y: height)
        case .leading:
            CanvasPoint(x: width, y: height / 2)
        case .trailing:
            CanvasPoint(x: 0, y: height / 2)
        case .bottomLeading:
            CanvasPoint(x: width, y: 0)
        case .bottom:
            CanvasPoint(x: width / 2, y: 0)
        case .bottomTrailing:
            CanvasPoint(x: 0, y: 0)
        case .rotate:
            CanvasPoint(x: width / 2, y: height / 2)
        }
    }
}

/// Clockwise rotation in a y-down space. Positive degrees match `rotationEffect`.
private func rotateClockwise(x: Double, y: Double, degrees: Double) -> (Double, Double) {
    let theta = degrees * Double.pi / 180
    let c = cos(theta)
    let s = sin(theta)
    return (x * c - y * s, x * s + y * c)
}

private func rotateCounterClockwise(x: Double, y: Double, degrees: Double) -> (Double, Double) {
    let theta = degrees * Double.pi / 180
    let c = cos(theta)
    let s = sin(theta)
    return (x * c + y * s, -x * s + y * c)
}
