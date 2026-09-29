import CanvasModel
import Testing

@Suite("Inspector fields")
struct InspectorFieldSetTests {
    @Test func rectangleShowsFillStrokeAndOpacity() {
        let fields = InspectorFieldSet.forType(.rectangle)
        #expect(fields.fill)
        #expect(fields.stroke)
        #expect(!fields.cornerRadius)
        #expect(fields.opacity)
        #expect(!fields.typography)
    }

    @Test func roundedRectangleIsTheOnlyCornerRadiusType() {
        #expect(InspectorFieldSet.forType(.roundedRectangle).cornerRadius)
        for type in CanvasElementType.allCases where type != .roundedRectangle {
            #expect(!InspectorFieldSet.forType(type).cornerRadius)
        }
    }

    @Test func circleHidesCornerRadiusAndTypography() {
        let fields = InspectorFieldSet.forType(.circle)
        #expect(fields.fill)
        #expect(fields.stroke)
        #expect(!fields.cornerRadius)
        #expect(!fields.typography)
    }

    @Test func textShowsTypographyAndHidesShapeFields() {
        let fields = InspectorFieldSet.forType(.text)
        #expect(fields.typography)
        #expect(fields.opacity)
        #expect(!fields.fill)
        #expect(!fields.stroke)
        #expect(!fields.cornerRadius)
    }

    @Test func imageAndGroupShowOpacityOnly() {
        for type in [CanvasElementType.image, .group] {
            let fields = InspectorFieldSet.forType(type)
            #expect(fields.opacity)
            #expect(!fields.fill)
            #expect(!fields.stroke)
            #expect(!fields.cornerRadius)
            #expect(!fields.typography)
        }
    }

    @Test func lineShowsStrokeAndHidesFill() {
        let fields = InspectorFieldSet.forType(.line)
        #expect(fields.stroke)
        #expect(fields.opacity)
        #expect(!fields.fill)
        #expect(!fields.typography)
    }
}
