if _G.__LOWKEY_SMITE_LOADED then return end
_G.__LOWKEY_SMITE_LOADED = true

local VERSION = "1.1"
local SCRIPT_NAME = "Lowkey Smite"

local MinionCount = Game.MinionCount
local Minion = Game.Minion
local CanUseSpell = Game.CanUseSpell
local IsChatOpen = Game.IsChatOpen
local SetCursorPos = Control.SetCursorPos
local KeyDown = Control.KeyDown
local KeyUp = Control.KeyUp
local UnderMouse = Game.GetUnderMouseObject
local floor = math.floor
local lower = string.lower
local format = string.format
local type = type
local pcall = pcall

local SmiteSpells = {
    summonersmite = { kind = "basic", range = 500 },
    summonersmite_jade = { kind = "basic", range = 760 },
    s5_summonersmiteduel = { kind = "unleashed", range = 500 },
    s5_summonersmiteplayerganker = { kind = "unleashed", range = 500 },
    summonersmiteavataroffensive = { kind = "primal", range = 500 },
    summonersmiteavatarutility = { kind = "primal", range = 500 },
    summonersmiteavatardefensive = { kind = "primal", range = 500 },
}

local KindDamage = { basic = 600, unleashed = 1000, primal = 1400 }

local Monsters = {
    sru_baron = { group = "baron", rank = 10 },
    sru_atakhan = { group = "atakhan", rank = 10 },
    sru_dragon_elder = { group = "elder", rank = 10 },
    sru_riftherald = { group = "herald", rank = 9 },
    sru_horde = { group = "grubs", rank = 9 },
    sru_red = { group = "buffs", rank = 7 },
    sru_blue = { group = "buffs", rank = 7 },
    sru_gromp = { group = "camps", rank = 5 },
    sru_murkwolf = { group = "camps", rank = 5 },
    sru_razorbeak = { group = "camps", rank = 5 },
    sru_krug = { group = "camps", rank = 5 },
    sru_crab = { group = "crab", rank = 4 },
    sru_scuttlecrab = { group = "crab", rank = 4 },
    sru_murkwolfmini = { group = "small", rank = 2 },
    sru_razorbeakmini = { group = "small", rank = 2 },
    sru_krugmini = { group = "small", rank = 2 },
    sru_krugminimini = { group = "small", rank = 1 },
}

local Epic = { baron = true, atakhan = true, elder = true, herald = true, grubs = true, dragon = true }

local AimOffsets = { { 0, 0 }, { 0, -25 }, { 0, -45 }, { -18, -35 }, { 18, -35 } }

local function HasSmite()
    for slot = SUMMONER_1, SUMMONER_2 do
        local d = myHero:GetSpellData(slot)
        local name = d and d.name
        if type(name) == "string" and SmiteSpells[lower(name)] then return true end
    end
    return false
end

local function cursorScreen()
    local c = Game.cursorPos
    local p = type(c) == "function" and c() or c
    if p and type(p.x) == "number" and type(p.y) == "number" then return { x = p.x, y = p.y } end
end

local function sameUnit(a, netID, handle)
    return a and a.networkID == netID and a.handle == handle
end

local resolved, resolvedCount = {}, 0

local function classify(charName)
    if type(charName) ~= "string" or charName == "" then return nil end
    local row = resolved[charName]
    if row ~= nil then
        if row == false then return nil end
        return row
    end
    if resolvedCount >= 512 then resolved, resolvedCount = {}, 0 end
    local key = lower(charName)
    local found = Monsters[key]
    if not found and key:find("sru_dragon", 1, true) then
        found = { group = "dragon", rank = 8 }
    end
    resolved[charName] = found or false
    resolvedCount = resolvedCount + 1
    return found
end

class "LowkeySmite"

function LowkeySmite:__init()
    self.rows = {}
    self.rowCount = 0
    self.state = {}
    self:LoadMenu()
    local hook = self:Hook()
    print("[" .. SCRIPT_NAME .. "] v" .. VERSION .. " loaded | hook " .. hook)
end

function LowkeySmite:LoadMenu()
    self.Menu = MenuElement({ type = MENU, id = "LowkeySmite", name = SCRIPT_NAME .. " v" .. VERSION })
    self.Menu:MenuElement({ id = "enabled", name = "Auto Smite", toggle = true, value = true, key = string.byte("N") })

    self.Menu:MenuElement({ type = MENU, id = "targets", name = "Targets" })
    self.Menu.targets:MenuElement({ id = "baron", name = "Baron Nashor", value = true })
    self.Menu.targets:MenuElement({ id = "atakhan", name = "Atakhan", value = true })
    self.Menu.targets:MenuElement({ id = "elder", name = "Elder Dragon", value = true })
    self.Menu.targets:MenuElement({ id = "dragon", name = "Dragons", value = true })
    self.Menu.targets:MenuElement({ id = "herald", name = "Rift Herald", value = true })
    self.Menu.targets:MenuElement({ id = "grubs", name = "Voidgrubs", value = true })
    self.Menu.targets:MenuElement({ id = "buffs", name = "Red / Blue buff", value = true })
    self.Menu.targets:MenuElement({ id = "camps", name = "Gromp, wolves, raptors, krugs", value = true })
    self.Menu.targets:MenuElement({ id = "crab", name = "Scuttle crab", value = false })
    self.Menu.targets:MenuElement({ id = "small", name = "Small camp monsters", value = false })

    self.Menu:MenuElement({ type = MENU, id = "damage", name = "Damage" })
    self.Menu.damage:MenuElement({ id = "margin", name = "Margin (epic)", value = 20, min = 0, max = 300, step = 5 })
    self.Menu.damage:MenuElement({ id = "marginOther", name = "Margin (buffs, camps)", value = 50, min = 0, max = 300, step = 5 })
    self.Menu.damage:MenuElement({ id = "override", name = "Damage override (0 = auto)", value = 0, min = 0, max = 2000, step = 50 })

    self.Menu:MenuElement({ type = MENU, id = "rules", name = "Rules" })
    self.Menu.rules:MenuElement({ id = "edge", name = "Range to hitbox edge", value = true })
    self.Menu.rules:MenuElement({ id = "saveCharge", name = "Keep a charge for epics", value = false })
    self.Menu.rules:MenuElement({ id = "ignoreChat", name = "Block while chat is open", value = true })

    self.Menu:MenuElement({ type = MENU, id = "draw", name = "Draw" })
    self.Menu.draw:MenuElement({ id = "range", name = "Smite range", value = true })
    self.Menu.draw:MenuElement({ id = "targets", name = "Monster health vs Smite", value = true })
    self.Menu.draw:MenuElement({ id = "status", name = "Smite status", value = true })
end

function LowkeySmite:Hook()
    local onTick = self:Guard(self.Tick, "tick")
    local onDraw = self:Guard(self.Draw, "draw")
    local sdk = _G.SDK
    local ticks = sdk and sdk.OnTick
    local draws = sdk and sdk.OnDraw
    if type(ticks) == "table" and type(draws) == "table" then
        ticks[#ticks + 1] = onTick
        draws[#draws + 1] = onDraw
        return "SDK"
    end
    Callback.Add("Tick", onTick)
    Callback.Add("Draw", onDraw)
    return "raw"
end

function LowkeySmite:Guard(fn, tag)
    local bound = function() return fn(self) end
    local lk = _G.Lowkey
    if lk and lk.Guard then return lk:Guard(SCRIPT_NAME, bound, tag) end
    local seen = {}
    return function()
        local ok, err = pcall(bound)
        if ok then return end
        local text = tostring(tag) .. ": " .. tostring(err)
        if seen[text] then return end
        seen[text] = true
        print("[" .. SCRIPT_NAME .. "] " .. text)
    end
end

function LowkeySmite:Resolve()
    local state = self.state
    state.slot = nil
    state.key = nil
    state.spell = nil
    state.kind = nil
    state.range = 0
    state.ammo = 0
    state.canUse = -1
    state.level = 0
    state.damage = 0
    state.ready = false
    for slot = SUMMONER_1, SUMMONER_2 do
        local d = myHero:GetSpellData(slot)
        local name = d and d.name
        local row = type(name) == "string" and SmiteSpells[lower(name)]
        if row then
            state.slot = slot
            state.key = slot == SUMMONER_1 and HK_SUMMONER_1 or HK_SUMMONER_2
            state.spell = name
            state.kind = row.kind
            state.range = row.range
            local ammo = d.ammo
            state.ammo = (type(ammo) == "number" and ammo >= 0 and ammo <= 10) and ammo or -1
            state.canUse = CanUseSpell(slot)
            state.level = d.level or 0
            local override = self.Menu.damage.override:Value()
            state.damage = override > 0 and override or KindDamage[row.kind] or 0
            state.ready = state.level > 0 and state.canUse == 0
            return state
        end
    end
    return state
end

function LowkeySmite:Allowed(group)
    local entry = self.Menu.targets[group]
    if not entry then return true end
    return entry:Value() == true
end

function LowkeySmite:Warp(point)
    if not point then return false end
    SetCursorPos(floor(point.x), floor(point.y))
    return true
end

function LowkeySmite:AimPoint(unit, index)
    local screen = unit.pos2D
    if not screen or not screen.onScreen then return nil end
    local size = Game.Resolution and Game.Resolution()
    local scale = 1
    if size and type(size.y) == "number" and size.y > 0 then scale = size.y / 1080 end
    if scale < 0.5 then scale = 0.5 end
    local offset = AimOffsets[index] or AimOffsets[1]
    local x = screen.x + offset[1] * scale
    local y = screen.y + offset[2] * scale
    if size and (x < 0 or y < 0 or x >= size.x or y >= size.y) then return nil end
    return { x = x, y = y }
end

function LowkeySmite:StartAim(state, unit)
    local point = self:AimPoint(unit, 1)
    if not point then return end
    self.aim = {
        unit = unit, netID = unit.networkID, handle = unit.handle, index = 2,
        restore = cursorScreen(), slot = state.slot, key = state.key,
    }
    self:Warp(point)
end

function LowkeySmite:ReleaseAim()
    local aim = self.aim
    if not aim then return end
    self.aim = nil
    if aim.restore then self:Warp(aim.restore) end
end

function LowkeySmite:Press(aim)
    KeyDown(aim.key)
    KeyUp(aim.key)
    aim.pressed = true
end

function LowkeySmite:Aim(state)
    local aim = self.aim
    local unit = aim.unit
    if state.slot ~= aim.slot then return self:ReleaseAim() end
    if not unit or not unit.valid or unit.dead or unit.networkID ~= aim.netID then
        return self:ReleaseAim()
    end
    if aim.pressed then return self:ReleaseAim() end

    local hovered = nil
    if type(UnderMouse) == "function" then
        local ok, obj = pcall(UnderMouse)
        if ok then hovered = obj end
    end
    if sameUnit(hovered, aim.netID, aim.handle) then
        return self:Press(aim)
    end

    if aim.index > #AimOffsets then
        return self:Press(aim)
    end

    local point = self:AimPoint(unit, aim.index)
    aim.index = aim.index + 1
    if not point then return self:ReleaseAim() end
    self:Warp(point)
end

function LowkeySmite:Tick()
    self.rowCount = 0
    if myHero.dead then return end
    local state = self:Resolve()
    if not state.slot then return end
    if not self.Menu.enabled:Value() then return end
    if self.Menu.rules.ignoreChat:Value() and IsChatOpen() then return end

    if self.aim then
        self:Aim(state)
        return
    end

    local canFire = state.ready
    local drawTargets = self.Menu.draw.targets:Value()
    local rows = self.rows
    local n = 0

    local damage = state.damage
    local marginEpic = self.Menu.damage.margin:Value()
    local marginOther = self.Menu.damage.marginOther:Value()
    local edge = self.Menu.rules.edge:Value()
    local saveCharge = self.Menu.rules.saveCharge:Value()
    local range = state.range
    local selfRadius = edge and (myHero.boundingRadius or 0) or 0
    local drawReach = range + selfRadius + 150
    local drawReach2 = drawReach * drawReach
    local hp = myHero.pos
    local hx, hz = hp.x, hp.z

    local best, bestRank = nil, -1

    for i = 1, MinionCount() do
        local m = Minion(i)
        if m and m.team == 300 and not m.dead and m.valid and m.health > 0 then
            local row = classify(m.charName)
            if row then
                local mp = m.pos
                local dx, dz = mp.x - hx, mp.z - hz
                local d2 = dx * dx + dz * dz
                if d2 <= drawReach2 and self:Allowed(row.group) then
                    local epic = Epic[row.group] == true
                    local lethal = damage - (epic and marginEpic or marginOther)
                    local reach = range + selfRadius + (edge and (m.boundingRadius or 0) or 0)
                    local inRange = d2 <= reach * reach
                    local killable = m.health <= lethal
                    if drawTargets then
                        n = n + 1
                        local entry = rows[n]
                        if not entry then entry = {}; rows[n] = entry end
                        entry.unit = m
                        entry.health = m.health
                        entry.lethal = lethal
                        entry.inRange = inRange
                        entry.killable = killable
                    end
                    if inRange and killable and canFire and m.visible and m.isTargetable
                        and not m.isImmortal then
                        local screen = m.pos2D
                        local hold = saveCharge and not epic and state.ammo >= 0 and state.ammo <= 1
                        if screen and screen.onScreen and not hold and row.rank > bestRank then
                            best, bestRank = m, row.rank
                        end
                    end
                end
            end
        end
    end

    self.rowCount = n
    if best then self:StartAim(state, best) end
end

function LowkeySmite:Draw()
    if myHero.dead then return end
    local state = self.state
    if not state.slot then return end

    if self.Menu.draw.range:Value() and state.ready then
        Draw.Circle(myHero.pos, state.range, 1, Draw.Color(200, 255, 220, 60))
    end

    if self.Menu.draw.status:Value() then
        local p = myHero.pos2D
        if p and p.onScreen then
            local text = (state.ready and format("Smite %d dmg", state.damage)) or "Smite not ready"
            Draw.Text(text, 18, p.x - 60, p.y + 30,
                (state.ready and Draw.Color(255, 255, 255, 255)) or Draw.Color(255, 255, 90, 90))
        end
    end

    if not self.Menu.draw.targets:Value() then return end
    local rows = self.rows
    for i = 1, self.rowCount do
        local entry = rows[i]
        local m = entry.unit
        if m and m.valid and not m.dead then
            local p = m.pos2D
            if p and p.onScreen then
                local color
                if entry.killable and entry.inRange then
                    color = Draw.Color(255, 255, 60, 60)
                elseif entry.killable then
                    color = Draw.Color(255, 255, 200, 60)
                else
                    color = Draw.Color(255, 160, 255, 160)
                end
                Draw.Text(format("%d / %d", floor(entry.health), floor(entry.lethal)), 16, p.x - 28, p.y - 26, color)
                if entry.killable and entry.inRange then
                    Draw.Circle(m.pos, m.boundingRadius or 60, 1, color)
                end
            end
        end
    end
end

if HasSmite() then
    LowkeySmite()
else
    local tries = 0
    local probe
    probe = function()
        tries = tries + 1
        if HasSmite() then
            Callback.Del("Tick", probe)
            LowkeySmite()
            return
        end
        if tries > 600 then Callback.Del("Tick", probe) end
    end
    Callback.Add("Tick", probe)
end
