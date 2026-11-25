local root = assert(COMMON_PATH, "COMMON_PATH is unavailable")
if not root:match("[/\\]$") then root = root .. "/" end

local bootstrap = root .. "Lowkey/bootstrap.lua"
local file = io.open(bootstrap, "r")
if not file then
    print("[Lowkey] bootstrap.lua missing, run the installer again")
    return
end
file:close()

local loader, reason = loadfile(bootstrap)
if not loader then
    print("[Lowkey] bootstrap.lua failed to parse: " .. tostring(reason))
    return
end

return loader()
