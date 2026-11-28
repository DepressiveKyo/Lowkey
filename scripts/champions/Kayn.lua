if _G.__LOWKEY_KAYN_LOADED then return end
_G.__LOWKEY_KAYN_LOADED = true
if myHero.charName ~= "Kayn" then return end

local VERSION = "1.0"
local SCRIPT_NAME = "Lowkey Kayn"

local PredTries = 0

local math_huge = math.huge
local math_floor = math.floor
local string_format = string.format
local string_lower = string.lower
local type = type
local pcall = pcall

local Game = Game
local myHero = myHero

local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameCanUseSpell = Game.CanUseSpell
local GameIsChatOpen = Game.IsChatOpen

local CastSpell = Control.CastSpell
local SetCursorPos = Control.SetCursorPos
local DrawCircle = Draw.Circle
local DrawText = Draw.Text
local DrawColor = Draw.Color

local SQ, SW, SE, SR = _Q, _W, _E, _R
local TEAM_ENEMY = 300 - myHero.team

local Q_RANGE, Q_RANGE2 = 350, 350 * 350
local Q_RADIUS = 50
local Q_DELAY = 0.15

local W_RADIUS = 45
local W_BASE_RANGE = 700
local W_ASSASSIN_RANGE = 900
local W_DELAY = 0.55

local E_RANGE = 650

local FORM_NONE, FORM_RHAAST, FORM_ASSASSIN = 0, 1, 2
local R_REACH = { [FORM_NONE] = 525, [FORM_RHAAST] = 525, [FORM_ASSASSIN] = 725 }

local BUFF_ASSASSIN = "kaynpassiveass"
local BUFF_RHAAST = "kaynpassiveslay"

local SELF_CAST = { KaynQ = true, KaynW = true, KaynAssW = true, KaynNewW = true, KaynR = true }

local COL_Q = DrawColor(150, 255, 120, 120)
local COL_W = DrawColor(150, 120, 200, 255)
local COL_R = DrawColor(200, 255, 90, 90)
local COL_BG = DrawColor(180, 10, 10, 15)
local COL_BORD = DrawColor(255, 200, 50, 50)
local COL_RDY = DrawColor(255, 120, 255, 120)
local COL_CD = DrawColor(255, 200, 200, 200)
local COL_OFF = DrawColor(255, 130, 130, 130)

local PANEL_NAMES = { "Q", "W", "E", "R" }

local TICK = 0

local S = {
    x = 0, y = 0, z = 0,
    qLv = 0, wLv = 0, eLv = 0, rLv = 0,
    qCd = 0, wCd = 0, eCd = 0, rCd = 0,
    qR = false, wR = false, eR = false, rR = false,
    wRange = W_BASE_RANGE,
    wRange2 = W_BASE_RANGE * W_BASE_RANGE,
    rReach2 = 525 * 525,
    form = FORM_NONE,
    casting = false,
    mode = 0,
}

local SentTick = {}
local CursorBackX, CursorBackY = nil, nil

local EHo, EHx, EHz, EHd2 = {}, {}, {}, {}
local EHhp, EHhpP = {}, {}
local EHn = 0

local EList, EListN = {}, 0
local HeroSeen = -1

local TgtTick, TgtCache = -1, {}

local PredQ, PredW = nil, nil
local Pos = { x = 0, y = 0, z = 0 }

local Menu = MenuElement({ type = MENU, id = "LowkeyKayn", name = SCRIPT_NAME .. " v" .. VERSION })
Menu:MenuElement({ name = "info", drop = { "Reaping Slash and Blade's Reach" } })

Menu:MenuElement({ type = MENU, id = "pred", name = "Prediction" })
Menu.pred:MenuElement({ id = "qHit", name = "Q Hit Chance", value = 1, drop = { "Normal", "High", "Immobile" } })
Menu.pred:MenuElement({ id = "wHit", name = "W Hit Chance", value = 2, drop = { "Normal", "High", "Immobile" } })

Menu:MenuElement({ type = MENU, id = "combo", name = "Combo" })
Menu.combo:MenuElement({ id = "useQ", name = "Use Q", value = true })
Menu.combo:MenuElement({ id = "useW", name = "Use W", value = true })
Menu.combo:MenuElement({ id = "useE", name = "Use E to close the gap", value = false })
Menu.combo:MenuElement({ id = "eMin", name = "E only beyond", value = 500, min = 300, max = 1200, step = 50 })

Menu:MenuElement({ type = MENU, id = "ult", name = "R Umbral Trespass" })
Menu.ult:MenuElement({ id = "use", name = "Use R", value = true })
Menu.ult:MenuElement({ id = "hp", name = "Only if target HP% below", value = 35, min = 5, max = 90, step = 5 })

Menu:MenuElement({ type = MENU, id = "harass", name = "Harass" })
Menu.harass:MenuElement({ id = "useW", name = "Use W", value = true })
Menu.harass:MenuElement({ id = "useQ", name = "Use Q", value = false })

Menu:MenuElement({ type = MENU, id = "clear", name = "Clear" })
Menu.clear:MenuElement({ id = "useQ", name = "Use Q", value = true })
Menu.clear:MenuElement({ id = "qMin", name = "Q if units in range >=", value = 2, min = 1, max = 6, step = 1 })

Menu:MenuElement({ type = MENU, id = "ks", name = "Killsteal" })
Menu.ks:MenuElement({ id = "useQ", name = "Q killsteal", value = true })
Menu.ks:MenuElement({ id = "useW", name = "W killsteal", value = true })

Menu:MenuElement({ type = MENU, id = "draw", name = "Drawings" })
Menu.draw:MenuElement({ id = "shown", name = "Draw anything at all", value = false })
Menu.draw:MenuElement({ id = "panel", name = "Status panel", value = true })
Menu.draw:MenuElement({ id = "qRange", name = "Q range", value = true })
Menu.draw:MenuElement({ id = "wRange", name = "W range", value = true })
Menu.draw:MenuElement({ id = "rRange", name = "R range", value = false })

local function IsValidUnit(obj)
    return obj ~= nil and obj.valid and obj.visible and obj.isTargetable
        and not obj.dead and not obj.isImmortal and obj.health > 0
end

local function OrbMode()
    local sdk = _G.SDK
    if not sdk or not sdk.Orbwalker or not sdk.Orbwalker.Modes then return 0 end
    local m = sdk.Orbwalker.Modes
    if m[sdk.ORBWALKER_MODE_COMBO] then return 1 end
    if m[sdk.ORBWALKER_MODE_HARASS] then return 2 end
    if m[sdk.ORBWALKER_MODE_LANECLEAR] then return 3 end
    if m[sdk.ORBWALKER_MODE_JUNGLECLEAR] then return 3 end
    if m[sdk.ORBWALKER_MODE_LASTHIT] then return 4 end
    if m[sdk.ORBWALKER_MODE_FLEE] then return 5 end
    return 0
end

local function BuffMapOf(unit)
    local sdk = _G.SDK
    local c = sdk and sdk.Cached
    if not c or not c.GetBuffMap then return nil end
    local ok, map = pcall(c.GetBuffMap, c, unit)
    if ok then return map end
    return nil
end

local function InitPred()
    if PredW then return end
    local gg = _G.GGPrediction
    if not gg then
        PredTries = PredTries + 1
        if PredTries == 300 then
            print("[" .. SCRIPT_NAME .. "] GGPrediction unavailable, casting without prediction")
        end
        return
    end
    if PredTries > 0 then
        print("[" .. SCRIPT_NAME .. "] prediction ready after " .. PredTries .. " ticks")
    end
    PredQ = gg:SpellPrediction({
        Type = gg.SPELLTYPE_CIRCLE, Delay = Q_DELAY, Radius = Q_RADIUS,
        Range = Q_RANGE, Speed = math_huge, Collision = false,
    })
    PredW = gg:SpellPrediction({
        Type = gg.SPELLTYPE_LINE, Delay = W_DELAY, Radius = W_RADIUS,
        Range = W_ASSASSIN_RANGE, Speed = math_huge, Collision = false,
    })
end

local function HitOf(v)
    local gg = _G.GGPrediction
    if not gg then return 0 end
    if v == 3 then return gg.HITCHANCE_IMMOBILE end
    if v == 2 then return gg.HITCHANCE_HIGH end
    return gg.HITCHANCE_NORMAL
end

local function BuildLists()
    local n = GameHeroCount()
    if n == HeroSeen then return end
    HeroSeen = n
    EListN = 0
    for i = 1, n do
        local h = GameHero(i)
        if h and h.team == TEAM_ENEMY then
            EListN = EListN + 1
            EList[EListN] = h
        end
    end
end

local function SyncSelf()
    local p = myHero.pos
    S.x, S.y, S.z = p.x, p.y, p.z

    local q = myHero:GetSpellData(SQ)
    local w = myHero:GetSpellData(SW)
    local e = myHero:GetSpellData(SE)
    local r = myHero:GetSpellData(SR)
    S.qLv, S.wLv, S.eLv, S.rLv = q.level, w.level, e.level, r.level
    S.qCd, S.wCd, S.eCd, S.rCd = q.currentCd, w.currentCd, e.currentCd, r.currentCd
    S.qR = S.qLv > 0 and GameCanUseSpell(SQ) == 0
    S.wR = S.wLv > 0 and GameCanUseSpell(SW) == 0
    S.eR = S.eLv > 0 and GameCanUseSpell(SE) == 0
    S.rR = S.rLv > 0 and GameCanUseSpell(SR) == 0

    local form = FORM_NONE
    local map = BuffMapOf(myHero)
    if map then
        if map[BUFF_ASSASSIN] then
            form = FORM_ASSASSIN
        elseif map[BUFF_RHAAST] then
            form = FORM_RHAAST
        end
    end
    if form == FORM_NONE then
        local wr = w.range
        if wr == W_ASSASSIN_RANGE then
            form = FORM_ASSASSIN
        elseif wr == W_BASE_RANGE and w.name ~= "KaynW" then
            form = FORM_RHAAST
        end
    end
    S.form = form

    local reach = (form == FORM_ASSASSIN and W_ASSASSIN_RANGE) or W_BASE_RANGE
    local wr = w.range
    if type(wr) == "number" and wr >= W_BASE_RANGE and wr <= W_ASSASSIN_RANGE then reach = wr end
    S.wRange = reach
    S.wRange2 = reach * reach

    local rr = R_REACH[form] or 525
    S.rReach2 = rr * rr

    S.casting = false
    local act = myHero.activeSpell
    if act and act.valid and not act.isStopped then
        local an = act.name
        if an and SELF_CAST[an] then S.casting = true end
    end

    S.mode = OrbMode()
end

local function SyncEnemies()
    local prev = EHn
    local n = 0
    local sx, sz = S.x, S.z
    for k = 1, EListN do
        local h = EList[k]
        if IsValidUnit(h) then
            local p = h.pos
            local px, pz = p.x, p.z
            local dx, dz = px - sx, pz - sz
            n = n + 1
            EHo[n] = h
            EHx[n], EHz[n] = px, pz
            EHd2[n] = dx * dx + dz * dz
            local hp = h.health
            EHhp[n] = hp + (h.shieldAD or 0)
            local mh = h.maxHealth
            EHhpP[n] = (mh and mh > 0 and hp / mh * 100) or 100
        end
    end
    for i = n + 1, prev do EHo[i] = nil end
    EHn = n
end

local function Target(range, range2)
    if TgtTick ~= TICK then
        TgtTick = TICK
        for k in pairs(TgtCache) do TgtCache[k] = nil end
    end
    local hit = TgtCache[range]
    if hit then return hit end

    local pick = 0
    local sdk = _G.SDK
    local ts = sdk and sdk.TargetSelector
    if ts then
        local ok, t = pcall(ts.GetTarget, ts, range)
        if ok and t and t.team == TEAM_ENEMY and IsValidUnit(t) then
            local id = t.networkID
            for i = 1, EHn do
                if EHo[i].networkID == id and EHd2[i] <= range2 then
                    pick = i
                    break
                end
            end
        end
    end
    if pick == 0 then
        local bestD = math_huge
        for i = 1, EHn do
            local d2 = EHd2[i]
            if d2 <= range2 and d2 < bestD then
                pick, bestD = i, d2
            end
        end
    end
    TgtCache[range] = pick
    return pick
end

local function SaveCursor()
    if CursorBackX then return end
    local cp = _G.cursorPos
    if not cp then return end
    local x, y = cp.x, cp.y
    if type(x) ~= "number" or x ~= x or type(y) ~= "number" or y ~= y then return end
    CursorBackX, CursorBackY = math_floor(x), math_floor(y)
end

local function RestoreCursor()
    local x, y = CursorBackX, CursorBackY
    CursorBackX, CursorBackY = nil, nil
    if x and y then SetCursorPos(x, y) end
end

local function SendAt(hk, slot, x, z)
    if SentTick[slot] == TICK then return false end
    if type(x) ~= "number" or x ~= x or type(z) ~= "number" or z ~= z then return false end
    Pos.x, Pos.y, Pos.z = x, S.y, z
    if CastSpell(hk, Pos) == false then return false end
    SentTick[slot] = TICK
    return true
end

local function SendOn(hk, slot, unit)
    if SentTick[slot] == TICK then return false end
    local p = unit.pos
    if p == nil then return false end
    local p2 = unit.pos2D
    if p2 == nil or p2.onScreen ~= true then return false end
    SaveCursor()
    if CastSpell(hk, p) == false then return false end
    SentTick[slot] = TICK
    return true
end

local function PredictAt(pred, i, want, range2)
    if not pred then return EHx[i], EHz[i] end
    pred:GetPrediction(EHo[i], myHero)
    if not pred:CanHit(want) then return nil end
    local cp = pred.CastPosition
    if not (cp and cp.x and cp.z) then return nil end
    local dx, dz = cp.x - S.x, cp.z - S.z
    if range2 and dx * dx + dz * dz > range2 then return nil end
    return cp.x, cp.z
end

local function CastQ(i)
    if i == 0 or not S.qR or S.casting then return false end
    if EHd2[i] > Q_RANGE2 then return false end
    local x, z = PredictAt(PredQ, i, HitOf(Menu.pred.qHit:Value()), Q_RANGE2)
    if not x then return false end
    return SendAt(HK_Q, SQ, x, z)
end

local function CastW(i)
    if i == 0 or not S.wR or S.casting then return false end
    if EHd2[i] > S.wRange2 then return false end
    if PredW then PredW.Range = S.wRange end
    local x, z = PredictAt(PredW, i, HitOf(Menu.pred.wHit:Value()), S.wRange2)
    if not x then return false end
    return SendAt(HK_W, SW, x, z)
end

local function CastR(i)
    if i == 0 or not S.rR or S.casting then return false end
    if not Menu.ult.use:Value() then return false end
    if EHd2[i] > S.rReach2 then return false end
    if EHhpP[i] > Menu.ult.hp:Value() then return false end
    return SendOn(HK_R, SR, EHo[i])
end

local function CastE(i)
    if i == 0 or not S.eR or S.casting then return false end
    if not Menu.combo.useE:Value() then return false end
    local reach = Menu.combo.eMin:Value()
    if EHd2[i] < reach * reach then return false end
    return SendAt(HK_E, SE, EHx[i], EHz[i])
end

local function KillSteal()
    local node = Menu.ks
    local hpCut = Menu.ult.hp:Value()
    for i = 1, EHn do
        if S.rR and Menu.ult.use:Value() and EHhpP[i] <= hpCut and EHd2[i] <= S.rReach2 then
            if SendOn(HK_R, SR, EHo[i]) then return true end
        end
        if node.useQ:Value() and S.qR and EHd2[i] <= Q_RANGE2 and EHhpP[i] <= hpCut then
            if CastQ(i) then return true end
        end
        if node.useW:Value() and S.wR and EHd2[i] <= S.wRange2 and EHhpP[i] <= hpCut then
            if CastW(i) then return true end
        end
    end
    return false
end

local function RunCombo()
    local node = Menu.combo
    local ri = Target(R_REACH[S.form] or 525, S.rReach2)
    if ri ~= 0 and CastR(ri) then return end

    if node.useQ:Value() then
        local qi = Target(Q_RANGE, Q_RANGE2)
        if qi ~= 0 and CastQ(qi) then return end
    end
    if node.useW:Value() then
        local wi = Target(S.wRange, S.wRange2)
        if wi ~= 0 and CastW(wi) then return end
    end
    if node.useE:Value() then
        local ei = Target(E_RANGE, E_RANGE * E_RANGE)
        if ei ~= 0 and CastE(ei) then return end
    end
end

local function RunHarass()
    local node = Menu.harass
    if node.useW:Value() then
        local wi = Target(S.wRange, S.wRange2)
        if wi ~= 0 and CastW(wi) then return end
    end
    if node.useQ:Value() then
        local qi = Target(Q_RANGE, Q_RANGE2)
        if qi ~= 0 and CastQ(qi) then return end
    end
end

local function RunClear()
    if not Menu.clear.useQ:Value() or not S.qR or S.casting then return end
    local sdk = _G.SDK
    local w = sdk and sdk.Snapshot
    if not w then return end
    local need = Menu.clear.qMin:Value()
    local sx, sz = S.x, S.z
    local hits, bx, bz = 0, nil, nil
    for pass = 1, 2 do
        local list = (pass == 1 and w.jungle) or w.lane
        local total = (pass == 1 and w.jungleN) or w.laneN
        if list and total then
            for i = 1, total do
                local u = list[i]
                if u and u.valid and not u.dead then
                    local p = u.pos
                    if p then
                        local dx, dz = p.x - sx, p.z - sz
                        if dx * dx + dz * dz <= Q_RANGE2 then
                            hits = hits + 1
                            if not bx then bx, bz = p.x, p.z end
                        end
                    end
                end
            end
        end
        if hits >= need and bx then
            SendAt(HK_Q, SQ, bx, bz)
            return
        end
    end
end

local PC = {
    res = false,
    x = 810,
    y = 870,
    cdText = { "Q", "W", "E", "R" },
    cdReady = { false, false, false, false },
    lastCd = { -1, -1, -1, -1 },
}

local function PanelCell(i, cd, ready, lv)
    PC.cdReady[i] = ready
    if lv == 0 then
        if PC.lastCd[i] ~= -1 then
            PC.lastCd[i] = -1
            PC.cdText[i] = PANEL_NAMES[i] .. " -"
        end
        return
    end
    if ready then
        if PC.lastCd[i] ~= 0 then
            PC.lastCd[i] = 0
            PC.cdText[i] = PANEL_NAMES[i] .. " up"
        end
        return
    end
    local sane = type(cd) == "number" and cd == cd and cd > 0 and cd < 1000
    local tenth = (sane and math_floor(cd * 10)) or -2
    if PC.lastCd[i] ~= tenth then
        PC.lastCd[i] = tenth
        PC.cdText[i] = (sane and string_format("%s %.1f", PANEL_NAMES[i], cd)) or (PANEL_NAMES[i] .. " ...")
    end
end

local function DrawPanel()
    if not PC.res then
        PC.res = true
        local res = Game.Resolution and Game.Resolution()
        if res and res.x and res.y then
            PC.x = res.x / 2 - 150
            PC.y = res.y - 210
        end
    end
    PanelCell(1, S.qCd, S.qR, S.qLv)
    PanelCell(2, S.wCd, S.wR, S.wLv)
    PanelCell(3, S.eCd, S.eR, S.eLv)
    PanelCell(4, S.rCd, S.rR, S.rLv)

    local x, y = PC.x, PC.y
    if Draw.Rect then
        Draw.Rect(x, y, 300, 56, COL_BG)
        Draw.Rect(x, y, 300, 2, COL_BORD)
    end
    local label = "no form"
    if S.form == FORM_ASSASSIN then
        label = "ASSASSIN"
    elseif S.form == FORM_RHAAST then
        label = "RHAAST"
    end
    DrawText(label, 12, x + 10, y + 8, (S.form == FORM_NONE and COL_OFF) or COL_RDY)
    DrawText(string_format("W %d", S.wRange), 12, x + 120, y + 8, COL_OFF)
    DrawText(string_format("R %d", R_REACH[S.form] or 525), 12, x + 210, y + 8, COL_OFF)

    for i = 1, 4 do
        DrawText(PC.cdText[i], 12, x + 10 + (i - 1) * 72, y + 32, (PC.cdReady[i] and COL_RDY) or COL_CD)
    end
end

local function OnDraw()
    local node = Menu.draw
    if myHero.dead or not node.shown:Value() then return end
    if node.panel:Value() then DrawPanel() end
    if not myHero.visible then return end
    local pos = myHero.pos
    if node.qRange:Value() then DrawCircle(pos, Q_RANGE, 1, COL_Q) end
    if node.wRange:Value() then DrawCircle(pos, S.wRange, 1, COL_W) end
    if node.rRange:Value() then DrawCircle(pos, R_REACH[S.form] or 525, 1, COL_R) end
end

local function OnTick()
    RestoreCursor()
    if myHero.dead then return end
    TICK = TICK + 1
    InitPred()
    BuildLists()
    SyncSelf()
    SyncEnemies()

    if GameIsChatOpen() then return end
    if S.casting then return end

    if KillSteal() then return end

    local mode = S.mode
    if mode == 1 then
        RunCombo()
    elseif mode == 2 then
        RunHarass()
    elseif mode == 3 then
        RunClear()
    end
end

local function Guard(fn, tag)
    local lk = _G.Lowkey
    if lk and lk.Guard then return lk:Guard(SCRIPT_NAME, fn, tag) end
    local seen = {}
    return function(...)
        local ok, err = pcall(fn, ...)
        if ok then return end
        local text = tostring(tag) .. ": " .. tostring(err)
        if seen[text] then return end
        seen[text] = true
        print("[" .. SCRIPT_NAME .. "] " .. text)
    end
end

local function Hook()
    local onTick = Guard(OnTick, "tick")
    local onDraw = Guard(OnDraw, "draw")
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

local HOOK = Hook()

InitPred()
print("[" .. SCRIPT_NAME .. "] v" .. VERSION .. " loaded | pred "
    .. ((PredW and "on") or "waiting") .. " | hook " .. HOOK)
