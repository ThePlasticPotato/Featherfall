local PlatformActionUtils = {
    id = "PlatformActionUtils",
}

PlatformActionUtils.default_presentation = {
    any = {label = "ACT", color = {1, 1, 0}},
    all = {label = "ACT", color = {1, 1, 0}},
    kris = {label = "Check", color = {0, 1, 1}, label_color = {0, 1, 1}},
    soul = {label = "ACT", color = {0, 1, 1}, label_color = {0, 1, 1}},
    none = {label = "No ACT", color = {0.5, 0.5, 0.5}, label_color = {0.5, 0.5, 0.5}},
}

function PlatformActionUtils.normalizeKind(kind)
    return string.lower(tostring(kind or "any"))
end

function PlatformActionUtils.parseColor(value)
    if type(value) == "table" then
        return value
    elseif type(value) == "number" then
        return {
            math.floor(value / 65536) / 255,
            (math.floor(value / 256) % 256) / 255,
            (value % 256) / 255,
        }
    elseif type(value) ~= "string" then
        return
    end

    local hex = value:match("^#?(%x%x)(%x%x)(%x%x)$")
    if hex then
        local r, g, b = value:match("^#?(%x%x)(%x%x)(%x%x)$")
        return {tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255}
    end

    local r, g, b = value:match("^%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*$")
    if r and g and b then
        r, g, b = tonumber(r), tonumber(g), tonumber(b)
        if r and g and b then
            if r > 1 or g > 1 or b > 1 then
                return {r / 255, g / 255, b / 255}
            end
            return {r, g, b}
        end
    end
end

function PlatformActionUtils.copyPresentation(target, source)
    if type(source) ~= "table" then
        return
    end

    for _, key in ipairs({"label", "name", "color", "label_color", "gradient", "afterimage_color", "inactive_message"}) do
        if source[key] ~= nil then
            target[key] = source[key]
        end
    end
end

function PlatformActionUtils.resolveValue(value, kind, target, state, data)
    if type(value) == "function" then
        return value(kind, target, state, data)
    end
    return value
end

function PlatformActionUtils.sampleGradient(gradient)
    if not (gradient and #gradient > 0) then
        return
    end

    local ratio = (Kristal.getTime() * 0.25) % 1
    local scaled = ratio * #gradient
    local index = math.floor(scaled) + 1
    local next_index = (index % #gradient) + 1
    local lerp = scaled - math.floor(scaled)
    local a = gradient[index]
    local b = gradient[next_index]
    return {
        MathUtils.lerp(a[1], b[1], lerp),
        MathUtils.lerp(a[2], b[2], lerp),
        MathUtils.lerp(a[3], b[3], lerp),
    }
end

return PlatformActionUtils
