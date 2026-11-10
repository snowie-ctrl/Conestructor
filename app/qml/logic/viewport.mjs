// Zoom and pan for the canvas. World coordinates are photo pixels; a view { zoom, panX, panY } puts a world point
// at screen = pan + zoom × world. The window's size never changes the zoom, only how much is visible.
// Tests: tests/qml/tst_viewport.qml.

export const CONE_METRES = 10.5 * 0.0254

// The whole photo, centred, with a small margin.
export function fit(viewW, viewH, contentW, contentH) {
    if (!(viewW > 0 && viewH > 0 && contentW > 0 && contentH > 0))
        return { zoom: 1, panX: 0, panY: 0 }
    const zoom = Math.min(viewW / contentW, viewH / contentH) * 0.95
    return { zoom: zoom, panX: (viewW - contentW * zoom) / 2, panY: (viewH - contentH * zoom) / 2 }
}

// From half the whole-photo zoom out, down to one cone about 80 screen pixels across (16× before the ruler is set).
export function limits(fitZoom, metresPerPixel) {
    const min = fitZoom * 0.5
    const max = metresPerPixel > 0 ? Math.max(min, 80 * metresPerPixel / CONE_METRES) : Math.max(min, 16)
    return { min: min, max: max }
}

// Zooms by `factor` about the screen point (sx, sy), which keeps the same world point under it.
export function zoomAt(view, factor, sx, sy, min, max) {
    const zoom = Math.min(max, Math.max(min, view.zoom * factor))
    const k = zoom / view.zoom
    return { zoom: zoom, panX: sx - (sx - view.panX) * k, panY: sy - (sy - view.panY) * k }
}

export function toWorld(view, sx, sy) {
    return { x: (sx - view.panX) / view.zoom, y: (sy - view.panY) / view.zoom }
}

export function toScreen(view, wx, wy) {
    return { x: view.panX + wx * view.zoom, y: view.panY + wy * view.zoom }
}
