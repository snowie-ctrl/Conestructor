import QtQuick
import QtTest
import "../../qml/logic/units.mjs" as Units

TestCase {
    name: "Units"

    function test_format_data() {
        return [
            { tag: "feet and inches", metres: 3.81, unit: "ftin", text: "12' 6\"" },
            { tag: "rounds to the inch", metres: 3.83, unit: "ftin", text: "12' 7\"" },
            { tag: "inches carry into feet", metres: 0.3, unit: "ftin", text: "1' 0\"" },
            { tag: "zero", metres: 0, unit: "ftin", text: "0' 0\"" },
            { tag: "negative feet and inches", metres: -1.2192, unit: "ftin", text: "-4' 0\"" },
            { tag: "tiny negative is zero", metres: -0.001, unit: "ftin", text: "0' 0\"" },
            { tag: "decimal feet", metres: 3.81, unit: "ft", text: "12.5 ft" },
            { tag: "whole decimal feet", metres: 6.096, unit: "ft", text: "20 ft" },
            { tag: "metres", metres: 3.81, unit: "m", text: "3.81 m" },
            { tag: "whole metres", metres: 20, unit: "m", text: "20 m" },
            { tag: "negative metres", metres: -4, unit: "m", text: "-4 m" },
            { tag: "negative zero metres", metres: -0.001, unit: "m", text: "0 m" }
        ]
    }

    function test_format(row) {
        compare(Units.format(row.metres, row.unit), row.text)
    }

    function test_parse_data() {
        return [
            { tag: "feet and inches", text: "12' 6\"", unit: "ftin", metres: 3.81 },
            { tag: "no space", text: "12'6\"", unit: "ftin", metres: 3.81 },
            { tag: "words", text: "12 ft 6 in", unit: "m", metres: 3.81 },
            { tag: "no inch mark", text: "12' 6", unit: "ftin", metres: 3.81 },
            { tag: "inches only", text: "6\"", unit: "ftin", metres: 0.1524 },
            { tag: "decimal feet", text: "12.5 ft", unit: "m", metres: 3.81 },
            { tag: "decimal feet with a prime", text: "12.5'", unit: "m", metres: 3.81 },
            { tag: "metres", text: "3.81 m", unit: "ftin", metres: 3.81 },
            { tag: "centimetres", text: "381 cm", unit: "ftin", metres: 3.81 },
            { tag: "bare number in ft-in is feet", text: "12.5", unit: "ftin", metres: 3.81 },
            { tag: "bare number in decimal feet", text: "12.5", unit: "ft", metres: 3.81 },
            { tag: "bare number in metres", text: "12.5", unit: "m", metres: 12.5 },
            { tag: "trailing point", text: "12.", unit: "m", metres: 12 },
            { tag: "negative feet and inches", text: "-4' 0\"", unit: "ftin", metres: -1.2192 },
            { tag: "typographic minus", text: "\u22124 m", unit: "ftin", metres: -4 },
            { tag: "spaces and capitals", text: "  20 M ", unit: "ftin", metres: 20 },
            { tag: "curly quotes", text: "12\u2019 6\u201d", unit: "m", metres: 3.81 }
        ]
    }

    function test_parse(row) {
        fuzzyCompare(Units.parse(row.text, row.unit), row.metres, 1e-9)
    }

    function test_parseRejects_data() {
        return [
            { tag: "empty", text: "" },
            { tag: "words", text: "abc" },
            { tag: "trailing junk", text: "12' 6\" 3" },
            { tag: "two points", text: "1..2" },
            { tag: "unit alone", text: "ft" },
            { tag: "two numbers", text: "12 6" }
        ]
    }

    function test_parseRejects(row) {
        verify(isNaN(Units.parse(row.text, "ftin")), row.text)
    }

    function test_roundTrip_data() {
        const rows = []
        const precision = { ftin: Units.INCH / 2, ft: Units.FOOT * 0.005, m: 0.005 }
        for (const unit of Units.UNITS)
            for (const metres of [0, 0.5, 3.81, 20, 123.4, -7.25])
                rows.push({ tag: unit + " " + metres, unit: unit, metres: metres, tolerance: precision[unit] })
        return rows
    }

    function test_roundTrip(row) {
        fuzzyCompare(Units.parse(Units.format(row.metres, row.unit), row.unit), row.metres, row.tolerance)
    }

    function test_anglesAndCounts() {
        compare(Units.formatAngle(90), "90°")
        compare(Units.formatAngle(22.25), "22.3°")
        compare(Units.parseAngle("90°"), 90)
        compare(Units.parseAngle("45 deg"), 45)
        compare(Units.parseAngle(" 12.5 "), 12.5)
        verify(isNaN(Units.parseAngle("left")))
        compare(Units.parseCount("4"), 4)
        verify(isNaN(Units.parseCount("4.5")))
        verify(isNaN(Units.parseCount("")))
    }

    function test_byKind() {
        compare(Units.formatValue("length", 3.81, "ftin"), "12' 6\"")
        compare(Units.formatValue("angle", 180, "ftin"), "180°")
        compare(Units.formatValue("count", 4, "m"), "4")
        fuzzyCompare(Units.parseValue("length", "3.81 m", "ftin"), 3.81, 1e-9)
        compare(Units.parseValue("angle", "90", "m"), 90)
        compare(Units.parseValue("count", "3", "m"), 3)
        compare(Units.stepFor("length", "ftin"), Units.INCH)
        fuzzyCompare(Units.stepFor("length", "ft"), Units.FOOT / 10, 1e-12)
        compare(Units.stepFor("length", "m"), 0.1)
        compare(Units.stepFor("angle", "m"), 5)
        compare(Units.stepFor("count", "m"), 1)
    }
}
