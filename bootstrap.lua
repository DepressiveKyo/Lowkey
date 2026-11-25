local REPO = "DepressiveKyo/Lowkey"
local BRANCH = "main"
local BASE_URL = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH .. "/"

local AUTO_UPDATE = true

local NO_AUTO_UPDATE = {}

if _G.__LOWKEY_LOADED then return _G.Lowkey end
_G.__LOWKEY_LOADED = true

local LOCAL_ROOT = COMMON_PATH
if not LOCAL_ROOT:match("[/\\]$") then LOCAL_ROOT = LOCAL_ROOT .. "/" end
LOCAL_ROOT = LOCAL_ROOT .. "Lowkey/"

local MANIFEST_LOCAL = LOCAL_ROOT .. "manifest.lua"
local MANIFEST_URL = BASE_URL .. "manifest.lua"
local MANIFEST_LIMIT = 1048576

local floor = math.floor
local format = string.format
local concat = table.concat
local byte = string.byte
local char = string.char
local rep = string.rep

local native = _G.bit32 or _G.bit
local MOD = 4294967296

local xor4 = {}
for a = 0, 15 do
    xor4[a] = {}
    for b = 0, 15 do
        local x, y, v, place = a, b, 0, 1
        for _ = 1, 4 do
            if x % 2 ~= y % 2 then v = v + place end
            x = floor(x / 2)
            y = floor(y / 2)
            place = place * 2
        end
        xor4[a][b] = v
    end
end

local function bxor(a, b)
    if native then return native.bxor(a, b) % MOD end
    local v, place = 0, 1
    for _ = 1, 8 do
        v = v + xor4[a % 16][b % 16] * place
        a = floor(a / 16)
        b = floor(b / 16)
        place = place * 16
    end
    return v
end

local function band(a, b)
    if native then return native.band(a, b) % MOD end
    return (a + b - bxor(a, b)) / 2
end

local function rotr(a, n)
    return floor(a / 2 ^ n) + (a % 2 ^ n) * 2 ^ (32 - n)
end

local function xor3(a, b, c)
    return bxor(bxor(a, b), c)
end

local K = {
    1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221,
    3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580,
    3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
    2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895,
    666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037,
    2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344,
    430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779,
    1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298,
}

local function Sha256(msg)
    local len = #msg
    local tail = char(128) .. rep("\0", (55 - len) % 64)
    local bits = len * 8
    for shift = 7, 0, -1 do
        tail = tail .. char(floor(bits / 256 ^ shift) % 256)
    end
    msg = msg .. tail

    local h = { 1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225 }
    local w = {}

    for start = 1, #msg, 64 do
        for i = 0, 15 do
            local a, b, c, d = byte(msg, start + i * 4, start + i * 4 + 3)
            w[i] = ((a * 256 + b) * 256 + c) * 256 + d
        end
        for i = 16, 63 do
            local a, b = w[i - 15], w[i - 2]
            w[i] = (w[i - 16]
                + xor3(rotr(a, 7), rotr(a, 18), floor(a / 8))
                + w[i - 7]
                + xor3(rotr(b, 17), rotr(b, 19), floor(b / 1024))) % MOD
        end
        local a, b, c, d, e, f, g, k = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
        for i = 0, 63 do
            local t1 = (k
                + xor3(rotr(e, 6), rotr(e, 11), rotr(e, 25))
                + bxor(band(e, f), band(MOD - 1 - e, g))
                + K[i + 1] + w[i]) % MOD
            local t2 = (xor3(rotr(a, 2), rotr(a, 13), rotr(a, 22))
                + xor3(band(a, b), band(a, c), band(b, c))) % MOD
            k = g; g = f; f = e; e = (d + t1) % MOD
            d = c; c = b; b = a; a = (t1 + t2) % MOD
        end
        local v = { a, b, c, d, e, f, g, k }
        for i = 1, 8 do h[i] = (h[i] + v[i]) % MOD end
    end

    local out = {}
    for i = 1, 8 do out[i] = format("%08x", h[i]) end
    return concat(out)
end

local function ReadFile(path, limit)
    local f = io.open(path, "rb")
    if not f then return nil end
    local body = f:read(limit or MANIFEST_LIMIT)
    f:close()
    return body
end

local function FileSize(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local size = f:seek("end")
    f:close()
    return size
end

local pending = 0

local function Download(url, path, cb)
    pending = pending + 1
    DownloadFileAsync(url, path, function()
        DelayAction(function()
            pending = pending - 1
            if cb then cb() end
        end, 0.05)
    end)
end

local Lowkey = {
    repo = REPO,
    branch = BRANCH,
    root = LOCAL_ROOT,
    manifest = nil,
    loaded = {},
    failed = {},
    state = "manifest",
}
_G.Lowkey = Lowkey

function Lowkey:Sha256(data)
    return Sha256(data)
end

local function ParseManifest()
    local body = ReadFile(MANIFEST_LOCAL, MANIFEST_LIMIT)
    if not body or #body < 2 then return nil, "manifest missing" end
    local chunk, reason = loadstring(body, "@Lowkey/manifest")
    if not chunk then return nil, tostring(reason) end
    local ok, data = pcall(chunk)
    if not ok then return nil, tostring(data) end
    if type(data) ~= "table" or data.api ~= 1 or type(data.scripts) ~= "table" then
        return nil, "unsupported manifest"
    end
    return data
end

local function WantsThisChampion(entry)
    local champ = entry.champion
    if champ == nil then return true end
    local name = myHero and myHero.charName
    if type(champ) == "string" then return name == champ end
    if type(champ) == "table" then
        for i = 1, #champ do
            if champ[i] == name then return true end
        end
        return false
    end
    return true
end

local function LocalPathOf(entry)
    return LOCAL_ROOT .. entry.file
end

local function NeedsDownload(entry)
    local path = LocalPathOf(entry)
    if NO_AUTO_UPDATE[entry.file] and FileSize(path) then return false end
    local size = FileSize(path)
    if size == nil then return true end
    if entry.bytes and size ~= entry.bytes then return true end
    return false
end

local Downloaded = {}

local function VerifyEntry(entry, full)
    local path = LocalPathOf(entry)
    local size = FileSize(path)
    if size == nil then return false, "missing" end
    if entry.bytes and size ~= entry.bytes then return false, "size mismatch" end
    if not full or not entry.sha256 then return true end
    local body = ReadFile(path, size + 1)
    if not body then return false, "unreadable" end
    if Sha256(body) ~= entry.sha256 then return false, "hash mismatch" end
    return true
end

local function RunEntry(name, entry)
    local path = LocalPathOf(entry)
    local ok, reason = VerifyEntry(entry, Downloaded[name] == true)
    if not ok then
        Lowkey.failed[name] = reason
        print("[Lowkey] " .. name .. " rejected: " .. reason)
        return
    end
    local loaded, err = loadfile(path)
    if not loaded then
        Lowkey.failed[name] = tostring(err)
        print("[Lowkey] " .. name .. " failed to parse: " .. tostring(err))
        return
    end
    local ran, why = pcall(loaded)
    if not ran then
        Lowkey.failed[name] = tostring(why)
        print("[Lowkey] " .. name .. " error: " .. tostring(why))
        return
    end
    Lowkey.loaded[name] = true
end

local function SortedNames(scripts)
    local names = {}
    for name in pairs(scripts) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        local pa = scripts[a].order or 100
        local pb = scripts[b].order or 100
        if pa ~= pb then return pa < pb end
        return a < b
    end)
    return names
end

local function LoadAll()
    local manifest = Lowkey.manifest
    local names = SortedNames(manifest.scripts)
    local count = 0
    for i = 1, #names do
        local name = names[i]
        local entry = manifest.scripts[name]
        if WantsThisChampion(entry) then
            RunEntry(name, entry)
            if Lowkey.loaded[name] then count = count + 1 end
        end
    end
    local bad = 0
    for _ in pairs(Lowkey.failed) do bad = bad + 1 end
    Lowkey.state = "ready"
    print(format("[Lowkey] %s@%s ready | %d loaded | %d failed",
        REPO, tostring(manifest.version or "?"), count, bad))
end

local function FetchScripts()
    local manifest = Lowkey.manifest
    local queued = 0
    for name, entry in pairs(manifest.scripts) do
        if WantsThisChampion(entry) and NeedsDownload(entry) then
            queued = queued + 1
            Downloaded[name] = true
            Download(BASE_URL .. entry.file, LocalPathOf(entry))
        end
    end
    if queued > 0 then
        print("[Lowkey] downloading " .. queued .. " file(s)")
    end
    Lowkey.state = "waiting"
end

local function AfterManifest()
    local manifest, reason = ParseManifest()
    if not manifest then
        print("[Lowkey] manifest unusable: " .. tostring(reason))
        Lowkey.state = "error"
        return
    end
    Lowkey.manifest = manifest
    FetchScripts()
end

local function Start()
    if AUTO_UPDATE then
        Download(MANIFEST_URL, MANIFEST_LOCAL, AfterManifest)
    else
        AfterManifest()
    end
end

local ticks = 0

local function OnTick()
    if Lowkey.state == "ready" or Lowkey.state == "error" then
        Callback.Del("Tick", OnTick)
        return
    end
    if pending > 0 then return end
    if Lowkey.state == "waiting" and Lowkey.manifest then
        LoadAll()
        return
    end
    ticks = ticks + 1
    if ticks > 600 then
        print("[Lowkey] timed out waiting for downloads")
        Lowkey.state = "error"
    end
end

Callback.Add("Tick", OnTick)
Start()

return Lowkey
