// A small JSON Schema checker covering the keywords docs/cone-format.schema.json uses: type, const, enum, required,
// properties, items, minimum, anyOf and $ref to "#/$defs/<name>". Other keywords ($schema, title, description,
// format, contentEncoding) are notes and are ignored. problems() lists what does not fit; empty means it fits.

function typeOf(v) {
    if (v === null)
        return "null"
    if (Array.isArray(v))
        return "array"
    if (typeof v === "number")
        return Number.isInteger(v) ? "integer" : "number"
    return typeof v
}

function fits(type, v) {
    const t = typeOf(v)
    return type === t || (type === "number" && t === "integer")
}

function check(root, s, v, where, out) {
    if (s.$ref) {
        check(root, root.$defs[s.$ref.replace("#/$defs/", "")], v, where, out)
        return
    }
    if (s.anyOf) {
        const ok = s.anyOf.some(option => {
            const inner = []
            check(root, option, v, where, inner)
            return inner.length === 0
        })
        if (!ok)
            out.push(where + ": fits none of its choices")
    }
    if (s.type !== undefined) {
        const types = Array.isArray(s.type) ? s.type : [s.type]
        if (!types.some(t => fits(t, v))) {
            out.push(where + ": should be " + types.join(" or "))
            return
        }
    }
    if (s.const !== undefined && v !== s.const)
        out.push(where + ": should be " + JSON.stringify(s.const))
    if (s.enum && s.enum.indexOf(v) < 0)
        out.push(where + ": should be one of " + JSON.stringify(s.enum))
    if (s.minimum !== undefined && typeof v === "number" && v < s.minimum)
        out.push(where + ": below " + s.minimum)
    if (typeOf(v) === "object") {
        for (const key of s.required || [])
            if (!(key in v))
                out.push(where + ": missing " + key)
        for (const key in s.properties || {})
            if (key in v)
                check(root, s.properties[key], v[key], where + "." + key, out)
    }
    if (Array.isArray(v) && s.items)
        v.forEach((item, i) => check(root, s.items, item, where + "[" + i + "]", out))
}

export function problems(schema, value) {
    const out = []
    check(schema, schema, value, "$", out)
    return out
}
