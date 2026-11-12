// Cone density: five notches that scale the largest gap between cones. Notch 3, "SAE standard", is the spacing the app
// has always used (it meets the SCCA course-design guidance; the FSAE rules give no spacing). A track has one notch; an
// element may have its own. Slalom apex cones and lines keep their own spacing settings. Tests: tests/qml/tst_density.qml.
export const NOTCHES = [1, 2, 3, 4, 5]
export const NAMES = { 1: "Fewest", 2: "Fewer", 3: "SAE standard", 4: "More", 5: "Most" }
export const FACTORS = { 1: 2, 2: 1.5, 3: 1, 4: 0.75, 5: 0.5 }
export const STANDARD = 3

// The track's notch: its own when it is one of the five, otherwise SAE standard (a track from before part 4).
export function trackNotch(track) {
    return NOTCHES.indexOf(track.density) >= 0 ? track.density : STANDARD
}

// An element's notch: its own Cone density setting when it has one (1 to 5), otherwise the track's (0 or none).
export function elementNotch(el, trackNotch) {
    const own = el.props ? el.props.density : 0
    return NOTCHES.indexOf(own) >= 0 ? own : trackNotch
}

// What a notch multiplies the largest gap by.
export function factor(notch) {
    return FACTORS[notch] || 1
}
