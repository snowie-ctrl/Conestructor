// Lengths on screen: format metres as feet and inches, decimal feet or metres, and read back what people type.
// Pure functions, table-tested in tests/qml/tst_units.qml. Files always hold metres; this is display only.

export const FOOT = 0.3048
export const INCH = 0.0254
export const UNITS = ["ftin", "ft", "m"]
export const LABELS = { ftin: "Feet and inches", ft: "Decimal feet", m: "Metres" }

const NUMBER = "(-?(?:\\d+(?:\\.\\d*)?|\\.\\d+))"
const FEET_WORD = "(?:'|ft|feet|foot)"
const INCH_WORD = "(?:\"|in|inch|inches)"
const METRE_WORD = "(?:m|metre|metres|meter|meters)"
const FEET_AND_INCHES = new RegExp("^" + NUMBER + "\\s*" + FEET_WORD + "\\s*" + NUMBER + "\\s*" + INCH_WORD + "?$")
const FEET = new RegExp("^" + NUMBER + "\\s*" + FEET_WORD + "$")
const INCHES = new RegExp("^" + NUMBER + "\\s*" + INCH_WORD + "$")
const METRES = new RegExp("^" + NUMBER + "\\s*" + METRE_WORD + "$")
const CENTIMETRES = new RegExp("^" + NUMBER + "\\s*cm$")
const BARE = new RegExp("^" + NUMBER + "$")
const ANGLE = new RegExp("^" + NUMBER + "\\s*(?:°|deg|degrees)?$")

// Up to `places` decimals without trailing zeros (12.5, 12, 3.81), and never "-0".
function trimmed(value, places) {
    const n = Number(value.toFixed(places))
    return String(n === 0 ? 0 : n)
}

// Typographic minus signs, primes and curly quotes become their plain forms.
function clean(text) {
    return String(text).trim().toLowerCase()
        .replace(/[\u2212\u2013]/g, "-")
        .replace(/[\u2032\u2019]/g, "'")
        .replace(/[\u2033\u201d]/g, "\"")
}

export function format(metres, unit) {
    if (unit === "m")
        return trimmed(metres, 2) + " m"
    if (unit === "ft")
        return trimmed(metres / FOOT, 2) + " ft"
    const totalInches = Math.round(Math.abs(metres) / INCH)
    const sign = metres < 0 && totalInches > 0 ? "-" : ""
    return sign + Math.floor(totalInches / 12) + "' " + (totalInches % 12) + "\""
}

// Metres, or NaN when the text is not a length. A bare number is in the current unit (feet for ft-in).
export function parse(text, unit) {
    const s = clean(text)
    let m = s.match(FEET_AND_INCHES)
    if (m) {
        const sign = m[1].startsWith("-") ? -1 : 1
        return sign * (Math.abs(Number(m[1])) * FOOT + Math.abs(Number(m[2])) * INCH)
    }
    if ((m = s.match(FEET)))
        return Number(m[1]) * FOOT
    if ((m = s.match(INCHES)))
        return Number(m[1]) * INCH
    if ((m = s.match(METRES)))
        return Number(m[1])
    if ((m = s.match(CENTIMETRES)))
        return Number(m[1]) / 100
    if ((m = s.match(BARE)))
        return Number(m[1]) * (unit === "m" ? 1 : FOOT)
    return NaN
}

export function formatAngle(degrees) {
    return trimmed(degrees, 1) + "°"
}

export function parseAngle(text) {
    const m = clean(text).match(ANGLE)
    return m ? Number(m[1]) : NaN
}

export function parseCount(text) {
    const m = clean(text).match(/^-?\d+$/)
    return m ? Number(m[0]) : NaN
}

// The three kinds of typed setting: "length" (metres), "angle" (degrees) and "count" (a whole number).
export function formatValue(kind, value, unit) {
    if (kind === "length")
        return format(value, unit)
    if (kind === "angle")
        return formatAngle(value)
    if (kind === "count")
        return String(Math.round(value))
    return String(value)
}

export function parseValue(kind, text, unit) {
    if (kind === "length")
        return parse(text, unit)
    if (kind === "angle")
        return parseAngle(text)
    if (kind === "count")
        return parseCount(text)
    return NaN
}

// What one press of an up or down arrow adds: an inch, a tenth of a foot or a tenth of a metre; 5°; 1.
export function stepFor(kind, unit) {
    if (kind === "length")
        return unit === "ftin" ? INCH : unit === "ft" ? FOOT / 10 : 0.1
    if (kind === "angle")
        return 5
    return 1
}
