if _G.__LOWKEY_AKALI_LOADED then return end
_G.__LOWKEY_AKALI_LOADED = true
if myHero.charName ~= "Akali" then return end

local VERSION = "1.4"
local SCRIPT_NAME = "Lowkey Akali"

local PredTries = 0

local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local string_format = string.format
local type = type
local pcall = pcall
local tostring = tostring

local Game = Game
local myHero = myHero

local GameTimer = Game.Timer
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameCanUseSpell = Game.CanUseSpell
local GameIsChatOpen = Game.IsChatOpen

local CastSpell = Control.CastSpell
local DrawCircle = Draw.Circle
local DrawText = Draw.Text
local DrawColor = Draw.Color

local SQ, SW, SE, SR = _Q, _W, _E, _R
local TEAM_ENEMY = 300 - myHero.team

local Q_RANGE, Q_RANGE2 = 500, 500 * 500
local Q_RADIUS, Q_DELAY = 80, 0.25
local Q_BASE = { 45, 70, 95, 120, 145 }
local Q_AD, Q_AP = 0.65, 0.60


local E_RANGE, E_RANGE2 = 650, 650 * 650
local E_RADIUS, E_DELAY, E_SPEED = 60, 0.25, 1800
local E1_BASE = { 30, 56.25, 82.5, 108.75, 135 }
local E1_AD, E1_AP = 0.255, 0.36
local E2_BASE = { 70, 131.25, 192.5, 253.75, 315 }
local E2_AD, E2_AP = 0.595, 0.84

local R1_RANGE, R1_RANGE2 = 750, 750 * 750
local R1_BASE = { 80, 220, 360 }
local R1_AD, R1_AP = 0.50, 0.30
local R2_RANGE2 = 750 * 750
local R2_BASE = { 60, 130, 200 }
local R2_AP = 0.30
local R2_EXEC_CAP = 0.70

local Q_CLUSTER2 = 250 * 250
local TURRET_RANGE2 = 880 * 880

local NAME_E2 = "AkaliEb"
local NAME_R1 = "AkaliR"
local NAME_R2 = "AkaliRb"
local BUFF_EMARK = "akaliemis"
local BUFF_SHROUD = "akaliw"
local BUFF_SMOKE = "akalismokebomb"

local SELF_CAST = {}

local COL_Q = DrawColor(150, 255, 160, 200)
local COL_E = DrawColor(150, 140, 255, 220)
local COL_R = DrawColor(130, 255, 90, 90)
local COL_MARK = DrawColor(255, 255, 110, 220)
local COL_BG = DrawColor(180, 10, 10, 15)
local COL_BORD = DrawColor(255, 200, 50, 50)
local COL_RDY = DrawColor(255, 120, 255, 120)
local COL_CD = DrawColor(255, 200, 200, 200)
local COL_OFF = DrawColor(255, 130, 130, 130)

local PANEL_NAMES = { "Q", "W", "E", "R" }

local TICK = 0

local S = {
    x = 0, y = 0, z = 0,
    ad = 0, bonusAd = 0, ap = 0,
    penPct = 1, penFlat = 0,
    hpPct = 100, energy = 100,
    qLv = 0, wLv = 0, eLv = 0, rLv = 0,
    qCd = 0, wCd = 0, eCd = 0, rCd = 0,
    qR = false, wR = false, eR = false, rR = false,
    hasE2 = false, hasR1 = false, hasR2 = false,
    shrouded = false,
    casting = false,
    mode = 0,
    why = "",
}

local SentTick = {}
local PendUntil = {}

local EHo, EHx, EHz, EHd2 = {}, {}, {}, {}
local EHhp, EHmr, EHhpP = {}, {}, {}
local EHmark = {}
local EHn = 0

local EList, EListN = {}, 0
local HeroSeen = -1

local TurX, TurZ = {}, {}
local TurN = 0
local TurTick = -1

local TgtTick, TgtCache = -1, {}

local PredQ, PredE = nil, nil
local Pos = { x = 0, y = 0, z = 0 }

local Menu = MenuElement({ type = MENU, id = "LowkeyAkali", name = SCRIPT_NAME .. " v" .. VERSION })
Menu:MenuElement({ name = "info", drop = { "Five Point Strike and Shuriken Flip" } })

Menu:MenuElement({ type = MENU, id = "pred", name = "Prediction" })
Menu.pred:MenuElement({ id = "qHit", name = "Q Hit Chance", value = 1, drop = { "Normal", "High", "Immobile" } })
Menu.pred:MenuElement({ id = "eHit", name = "E Hit Chance", value = 2, drop = { "Normal", "High", "Immobile" } })

Menu:MenuElement({ type = MENU, id = "combo", name = "Combo" })
Menu.combo:MenuElement({ id = "useQ", name = "Use Q", value = true })
Menu.combo:MenuElement({ id = "useE1", name = "Use E to mark", value = true })
Menu.combo:MenuElement({ id = "useE2", name = "Use E2 to dash in", value = true })
Menu.combo:MenuElement({ id = "energy", name = "Do not open below energy%", value = 30, min = 0, max = 100, step = 5, identifier = "%" })

Menu:MenuElement({ type = MENU, id = "ult", name = "R Perfect Execution" })
Menu.ult:MenuElement({ id = "useR1", name = "R1 to engage", value = false })
Menu.ult:MenuElement({ id = "r1Min", name = "R1 only beyond", value = 300, min = 0, max = 750, step = 50 })
Menu.ult:MenuElement({ id = "r1Rule", name = "R1 into enemy turret", value = 2, drop = { "Never", "Smart", "Always" } })
Menu.ult:MenuElement({ id = "r1HP", name = "Smart: target HP% below", value = 50, min = 5, max = 100, step = 5, identifier = "%" })
Menu.ult:MenuElement({ id = "r1Mine", name = "Smart: my HP% above", value = 50, min = 0, max = 100, step = 5, identifier = "%" })
Menu.ult:MenuElement({ id = "r1Crowd", name = "Skip if enemies at target >=", value = 3, min = 1, max = 5, step = 1 })
Menu.ult:MenuElement({ id = "useR2", name = "R2 to execute", value = true })
Menu.ult:MenuElement({ id = "r2Lethal", name = "R2 only when it kills", value = true })

Menu:MenuElement({ type = MENU, id = "shroud", name = "W Twilight Shroud" })
Menu.shroud:MenuElement({ id = "key", name = "Cast at my feet", key = string.byte("G") })
Menu.shroud:MenuElement({ id = "auto", name = "Auto shroud", value = true })
Menu.shroud:MenuElement({ id = "energy", name = "Below energy%", value = 50, min = 0, max = 100, step = 5, identifier = "%" })
Menu.shroud:MenuElement({ id = "energyNear", name = "Energy shroud needs an enemy near", value = true })
Menu.shroud:MenuElement({ id = "hp", name = "Below my HP% with an enemy near", value = 35, min = 0, max = 100, step = 5, identifier = "%" })
Menu.shroud:MenuElement({ id = "count", name = "Enemies within 500 >=", value = 3, min = 1, max = 5, step = 1 })

Menu:MenuElement({ type = MENU, id = "harass", name = "Harass" })
Menu.harass:MenuElement({ id = "useQ", name = "Use Q", value = true })
Menu.harass:MenuElement({ id = "useE1", name = "Use E to poke", value = false })
Menu.harass:MenuElement({ id = "energyMin", name = "Keep energy above", value = 30, min = 0, max = 100, step = 5, identifier = "%" })

Menu:MenuElement({ type = MENU, id = "clear", name = "Clear" })
Menu.clear:MenuElement({ id = "useQ", name = "Use Q", value = true })
Menu.clear:MenuElement({ id = "qMin", name = "Q if it kills >=", value = 2, min = 1, max = 6, step = 1 })
Menu.clear:MenuElement({ id = "push", name = "Q to push when nothing is killable", value = false })
Menu.clear:MenuElement({ id = "pushMin", name = "Pushing: units in the cone >=", value = 3, min = 1, max = 6, step = 1 })
Menu.clear:MenuElement({ id = "energyMin", name = "Keep energy above", value = 20, min = 0, max = 100, step = 5, identifier = "%" })

Menu:MenuElement({ type = MENU, id = "lasthit", name = "Last Hit" })
Menu.lasthit:MenuElement({ id = "useQ", name = "Q a minion Q would kill", value = true })
Menu.lasthit:MenuElement({ id = "energyMin", name = "Keep energy above", value = 0, min = 0, max = 100, step = 5, identifier = "%" })

Menu:MenuElement({ type = MENU, id = "ks", name = "Killsteal" })
Menu.ks:MenuElement({ id = "useQ", name = "Q killsteal", value = true })
Menu.ks:MenuElement({ id = "useE", name = "E killsteal", value = true })
Menu.ks:MenuElement({ id = "useR1", name = "R1 into R2 killsteal", value = false })
Menu.ks:MenuElement({ id = "useR2", name = "R2 killsteal", value = true })

Menu:MenuElement({ type = MENU, id = "draw", name = "Drawings" })
Menu.draw:MenuElement({ id = "enable", name = "Enable drawings", value = true })
Menu.draw:MenuElement({ id = "shown", name = "Draw anything at all", value = false })
Menu.draw:MenuElement({ id = "panel", name = "Status panel", value = true })
Menu.draw:MenuElement({ id = "qRange", name = "Q range", value = true })
Menu.draw:MenuElement({ id = "eRange", name = "E range", value = true })
Menu.draw:MenuElement({ id = "rRange", name = "R range", value = false })
Menu.draw:MenuElement({ id = "marks", name = "Mark E-marked enemies", value = true })

local function MagicMul(mr)
    local v = mr or 0
    local pct = S.penPct
    if pct > 0 then v = v * pct end
    local flat = S.penFlat
    if flat > 0 then v = v - flat end
    if v >= 0 then return 100 / (100 + v) end
    return 2 - 100 / (100 - v)
end

local function IsValidUnit(obj)
    return obj ~= nil and obj.valid and obj.visible and obj.isTargetable
        and not obj.dead and not obj.isImmortal and obj.health > 0
end

local BuffSrc = nil

local function BuffMapOf(unit)
    if BuffSrc == nil then
        local sdk = _G.SDK
        local c = sdk and sdk.Cached
        BuffSrc = (c and c.GetBuffMap and c) or false
    end
    if not BuffSrc then return nil end
    return BuffSrc:GetBuffMap(unit)
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

local function InitPred()
    if PredE then return end
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
    PredE = gg:SpellPrediction({
        Type = gg.SPELLTYPE_LINE, Delay = E_DELAY, Radius = E_RADIUS,
        Range = E_RANGE, Speed = E_SPEED, Collision = true, MaxCollision = 0,
        CollisionTypes = { gg.COLLISION_MINION, gg.COLLISION_YASUOWALL },
    })
    PredQ = gg:SpellPrediction({
        Type = gg.SPELLTYPE_LINE, Delay = Q_DELAY, Radius = Q_RADIUS,
        Range = Q_RANGE, Speed = math_huge, Collision = false,
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
    S.ad = myHero.totalDamage or 0
    S.bonusAd = math_max(0, S.ad - (myHero.baseDamage or 0))
    S.ap = myHero.ap or 0
    local pct = myHero.magicPenPercent
    S.penPct = (type(pct) == "number" and pct > 0 and pct) or 1
    local flat = myHero.magicPen
    S.penFlat = (type(flat) == "number" and flat > 0 and flat) or 0

    local mh = myHero.maxHealth
    S.hpPct = (mh and mh > 0 and myHero.health / mh * 100) or 100
    local me = myHero.maxMana
    S.energy = (me and me > 0 and myHero.mana / me * 100) or 100

    local q = myHero:GetSpellData(SQ)
    local w = myHero:GetSpellData(SW)
    local e = myHero:GetSpellData(SE)
    local r = myHero:GetSpellData(SR)
    S.qLv, S.wLv, S.eLv, S.rLv = q.level, w.level, e.level, r.level
    S.qCd, S.wCd, S.eCd, S.rCd = q.currentCd, w.currentCd, e.currentCd, r.currentCd

    local mana = myHero.mana or 0
    S.qR = S.qLv > 0 and GameCanUseSpell(SQ) == 0 and (q.mana or 0) <= mana
    S.wR = S.wLv > 0 and GameCanUseSpell(SW) == 0 and (w.mana or 0) <= mana
    S.eR = S.eLv > 0 and GameCanUseSpell(SE) == 0 and (e.mana or 0) <= mana
    S.rR = S.rLv > 0 and GameCanUseSpell(SR) == 0

    S.hasE2 = e.name == NAME_E2
    S.hasR1 = r.name == NAME_R1
    S.hasR2 = r.name == NAME_R2

    if SELF_CAST.ready == nil then
        SELF_CAST.ready = true
        SELF_CAST[q.name or "AkaliQ"] = true
        SELF_CAST[w.name or "AkaliW"] = true
    end

    S.casting = false
    local act = myHero.activeSpell
    if act and act.valid and not act.isStopped then
        local an = act.name
        if an and SELF_CAST[an] then S.casting = true end
    end

    S.shrouded = false
    local map = BuffMapOf(myHero)
    if map then
        S.shrouded = map[BUFF_SHROUD] ~= nil or map[BUFF_SMOKE] ~= nil
    end

    S.mode = OrbMode()
end

local function SyncEnemies()
    local prev = EHn
    local n = 0
    local sx, sz = S.x, S.z
    local wantMark = S.hasE2 or (S.rR and S.hasR2)

    for k = 1, EListN do
        local h = EList[k]
        if IsValidUnit(h) then
            local p = h.pos
            local px, pz = p.x, p.z
            local dx, dz = px - sx, pz - sz
            local d2 = dx * dx + dz * dz
            n = n + 1
            EHo[n] = h
            EHx[n], EHz[n] = px, pz
            EHd2[n] = d2
            local hp = h.health
            EHhp[n] = hp + (h.shieldAP or 0)
            EHmr[n] = h.magicResist
            local mh = h.maxHealth
            EHhpP[n] = (mh and mh > 0 and hp / mh * 100) or 100

            local mark = false
            if wantMark and d2 <= R2_RANGE2 then
                local map = BuffMapOf(h)
                if map then mark = map[BUFF_EMARK] ~= nil end
            end
            EHmark[n] = mark
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

    local sdk = _G.SDK
    local ts = sdk and sdk.TargetSelector
    if ts then
        local ok, t = pcall(ts.GetTarget, ts, range)
        if ok and t and t.team == TEAM_ENEMY and IsValidUnit(t) then
            local id = t.networkID
            for i = 1, EHn do
                if EHo[i].networkID == id and EHd2[i] <= range2 then
                    TgtCache[range] = i
                    return i
                end
            end
        end
    end

    local best, bestD = 0, math_huge
    for i = 1, EHn do
        local d2 = EHd2[i]
        if d2 <= range2 and d2 < bestD then
            best, bestD = i, d2
        end
    end
    TgtCache[range] = best
    return best
end

local function EnemyTurrets()
    if TurTick == TICK then return end
    TurTick = TICK
    TurN = 0
    local sdk = _G.SDK
    local w = sdk and sdk.Snapshot
    if w and w.turret and w.turretN then
        local list, total = w.turret, w.turretN
        for i = 1, total do
            local t = list[i]
            local p = t and t.pos
            if p then
                TurN = TurN + 1
                TurX[TurN], TurZ[TurN] = p.x, p.z or p.y
            end
        end
        return
    end
    local om = sdk and sdk.ObjectManager
    if not om or not om.GetEnemyTurrets then return end
    local ok, list = pcall(om.GetEnemyTurrets, om, 3000)
    if not ok or type(list) ~= "table" then return end
    for i = 1, #list do
        local t = list[i]
        local p = t and t.pos
        if p then
            TurN = TurN + 1
            TurX[TurN], TurZ[TurN] = p.x, p.z or p.y
        end
    end
end

local function UnderTurret(x, z)
    EnemyTurrets()
    for i = 1, TurN do
        local dx, dz = x - TurX[i], z - TurZ[i]
        if dx * dx + dz * dz <= TURRET_RANGE2 then return true end
    end
    return false
end

local function CrowdAt(x, z, limit)
    local n = 0
    for i = 1, EHn do
        local dx, dz = EHx[i] - x, EHz[i] - z
        if dx * dx + dz * dz <= 1000000 then
            n = n + 1
            if n >= limit then return true end
        end
    end
    return false
end

local function NearCount(range2)
    local n = 0
    for i = 1, EHn do
        if EHd2[i] <= range2 then n = n + 1 end
    end
    return n
end

local function QDamage(i)
    if S.qLv == 0 then return 0 end
    local raw = Q_BASE[S.qLv] + Q_AD * S.ad + Q_AP * S.ap
    return raw * MagicMul(EHmr[i])
end

local function E1Damage(i)
    if S.eLv == 0 then return 0 end
    local raw = E1_BASE[S.eLv] + E1_AD * S.ad + E1_AP * S.ap
    return raw * MagicMul(EHmr[i])
end

local function E2Damage(i)
    if S.eLv == 0 then return 0 end
    local raw = E2_BASE[S.eLv] + E2_AD * S.ad + E2_AP * S.ap
    return raw * MagicMul(EHmr[i])
end

local function R1Damage(i)
    if S.rLv == 0 then return 0 end
    local raw = R1_BASE[S.rLv] + R1_AD * S.bonusAd + R1_AP * S.ap
    return raw * MagicMul(EHmr[i])
end

local function R2Damage(i)
    if S.rLv == 0 then return 0 end
    local missing = 1 - EHhpP[i] * 0.01
    if missing < 0 then missing = 0 end
    if missing > 1 then missing = 1 end
    local mult = 1 + 2 * math_min(1, missing / R2_EXEC_CAP)
    local raw = (R2_BASE[S.rLv] + R2_AP * S.ap) * mult
    return raw * MagicMul(EHmr[i])
end

local function AckWindow()
    local sdk = _G.SDK
    local d = sdk and sdk.Data
    if d and d.GetLatency then
        local ok, lat = pcall(d.GetLatency, d)
        if ok and type(lat) == "number" and lat > 0 then return lat * 2 + 0.30 end
    end
    return 0.45
end

local function SlotFree(slot)
    if not PendUntil[slot] then return true end
    if GameCanUseSpell(slot) ~= 0 then
        PendUntil[slot] = nil
        return true
    end
    if GameTimer() >= PendUntil[slot] then
        PendUntil[slot] = nil
        return true
    end
    return false
end

local function MarkSent(slot)
    PendUntil[slot] = GameTimer() + AckWindow()
    SentTick[slot] = TICK
end

local function Send(hk, slot, x, z)
    if type(x) ~= "number" or x ~= x or type(z) ~= "number" or z ~= z then return false end
    if not SlotFree(slot) then return false end
    Pos.x, Pos.y, Pos.z = x, S.y, z
    if CastSpell(hk, Pos) == false then return false end
    MarkSent(slot)
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
    if i == 0 or not S.qR or S.casting or SentTick[SQ] == TICK then return false end
    if EHd2[i] > Q_RANGE2 then return false end
    local x, z = PredictAt(PredQ, i, HitOf(Menu.pred.qHit:Value()), Q_RANGE2)
    if not x then return false end
    return Send(HK_Q, SQ, x, z)
end

local function CastQAt(x, z)
    if not S.qR or S.casting or SentTick[SQ] == TICK then return false end
    local dx, dz = x - S.x, z - S.z
    if dx * dx + dz * dz > Q_RANGE2 then return false end
    return Send(HK_Q, SQ, x, z)
end

local function CastE1(i)
    if i == 0 or not S.eR or S.hasE2 or S.casting or SentTick[SE] == TICK then return false end
    if EHd2[i] > E_RANGE2 then return false end
    local x, z = PredictAt(PredE, i, HitOf(Menu.pred.eHit:Value()), E_RANGE2)
    if not x then return false end
    return Send(HK_E, SE, x, z)
end

local function R1Allowed(i)
    local x, z = EHx[i], EHz[i]
    if not UnderTurret(x, z) then
        if CrowdAt(x, z, Menu.ult.r1Crowd:Value()) then return false, "crowded" end
        return true, ""
    end
    local rule = Menu.ult.r1Rule:Value()
    if rule == 1 then return false, "turret" end
    if rule == 3 then return true, "dive" end
    if S.hpPct <= Menu.ult.r1Mine:Value() then return false, "my hp" end
    if EHhpP[i] > Menu.ult.r1HP:Value() then return false, "target hp" end
    if CrowdAt(x, z, Menu.ult.r1Crowd:Value()) then return false, "crowded" end
    return true, "dive"
end

local function CastE2(gated)
    if not S.hasE2 or not S.eR or S.casting or SentTick[SE] == TICK then return false end
    for i = 1, EHn do
        if EHmark[i] and EHd2[i] <= E_RANGE2 then
            if not gated then
                return Send(HK_E, SE, EHx[i], EHz[i])
            end
            local ok, why = R1Allowed(i)
            S.why = why
            if ok then return Send(HK_E, SE, EHx[i], EHz[i]) end
        end
    end
    return false
end

local function CastR1(i)
    if i == 0 or not S.rR or not S.hasR1 or S.casting or SentTick[SR] == TICK then return false end
    local d2 = EHd2[i]
    if d2 > R1_RANGE2 then return false end
    local min = Menu.ult.r1Min:Value()
    if d2 < min * min then
        S.why = "too close"
        return false
    end
    local ok, why = R1Allowed(i)
    S.why = why
    if not ok then return false end
    return Send(HK_R, SR, EHx[i], EHz[i])
end

local function CastR2(lethalOnly)
    if not S.rR or not S.hasR2 or S.casting or SentTick[SR] == TICK then return false end
    local best, bestHp = 0, math_huge
    for i = 1, EHn do
        if EHd2[i] <= R2_RANGE2 then
            local hp = EHhp[i]
            if not lethalOnly or R2Damage(i) >= hp then
                if hp < bestHp then best, bestHp = i, hp end
            end
        end
    end
    if best == 0 then return false end
    return Send(HK_R, SR, EHx[best], EHz[best])
end

local function RunShroud()
    if Menu.shroud.key:Value() then
        if not S.wR or S.casting or SentTick[SW] == TICK then return false end
        return Send(HK_W, SW, S.x, S.z)
    end
    if not Menu.shroud.auto:Value() then return false end
    if not S.wR or S.shrouded or S.casting or SentTick[SW] == TICK then return false end

    local near = NearCount(Q_RANGE2)

    if not S.qR and S.energy <= Menu.shroud.energy:Value() then
        if near > 0 or not Menu.shroud.energyNear:Value() then
            S.why = "shroud energy"
            return Send(HK_W, SW, S.x, S.z)
        end
    end

    if near == 0 then return false end

    if near >= Menu.shroud.count:Value() then
        S.why = "shroud crowd"
        return Send(HK_W, SW, S.x, S.z)
    end
    if S.hpPct <= Menu.shroud.hp:Value() then
        S.why = "shroud hp"
        return Send(HK_W, SW, S.x, S.z)
    end
    return false
end

local function KillSteal()
    local node = Menu.ks
    if node.useR2:Value() and S.hasR2 and S.rR then
        if CastR2(true) then return true end
    end
    if node.useR1:Value() and S.hasR1 and S.rR then
        local min = Menu.ult.r1Min:Value()
        local min2 = min * min
        for i = 1, EHn do
            local d2 = EHd2[i]
            if d2 <= R1_RANGE2 and d2 >= min2 and R1Damage(i) + R2Damage(i) >= EHhp[i] then
                if CastR1(i) then return true end
            end
        end
    end
    if node.useQ:Value() and S.qR then
        for i = 1, EHn do
            if EHd2[i] <= Q_RANGE2 and QDamage(i) >= EHhp[i] then
                if CastQ(i) then return true end
            end
        end
    end
    if node.useE:Value() and S.eR then
        if S.hasE2 then
            for i = 1, EHn do
                if EHmark[i] and EHd2[i] <= E_RANGE2 and E2Damage(i) >= EHhp[i] then
                    if Send(HK_E, SE, EHx[i], EHz[i]) then return true end
                end
            end
        else
            for i = 1, EHn do
                if EHd2[i] <= E_RANGE2 and E1Damage(i) >= EHhp[i] then
                    if CastE1(i) then return true end
                end
            end
        end
    end
    return false
end

local function RunCombo()
    local node = Menu.combo
    if S.energy < node.energy:Value() then
        S.why = "energy"
        return
    end

    if node.useE2:Value() and CastE2(true) then return end

    local qi = Target(Q_RANGE, Q_RANGE2)
    if node.useQ:Value() and CastQ(qi) then return end

    if Menu.ult.useR2:Value() and S.hasR2 then
        if CastR2(Menu.ult.r2Lethal:Value()) then return end
    end

    if Menu.ult.useR1:Value() and S.hasR1 then
        local ri = Target(R1_RANGE, R1_RANGE2)
        if CastR1(ri) then return end
    end

    if node.useE1:Value() then
        local ei = Target(E_RANGE, E_RANGE2)
        if CastE1(ei) then return end
    end
end

local function RunHarass()
    local node = Menu.harass
    if S.energy < node.energyMin:Value() then
        S.why = "energy"
        return
    end
    if node.useQ:Value() and CastQ(Target(Q_RANGE, Q_RANGE2)) then return end
    if node.useE1:Value() and CastE1(Target(E_RANGE, E_RANGE2)) then return end
end

local function HealthAfter(unit, delay)
    local sdk = _G.SDK
    local hp = sdk and sdk.HealthPrediction
    if hp and hp.GetPrediction then
        local ok, v = pcall(hp.GetPrediction, hp, unit, delay)
        if ok and type(v) == "number" then return v end
    end
    return unit.health or 0
end

local function QRaw()
    if S.qLv == 0 then return 0 end
    return Q_BASE[S.qLv] + Q_AD * S.ad + Q_AP * S.ap
end

local function QKills(unit, raw)
    local shield = unit.shieldAP or 0
    if (unit.health or 0) + shield > raw * 2 then return false end
    return HealthAfter(unit, Q_DELAY) + shield <= raw * MagicMul(unit.magicResist)
end

local FMo, FMx, FMz = {}, {}, {}
local FMkill = {}
local FMn, FMhigh = 0, 0

local FarmByDist = nil

local function FarmSnapshot()
    local sdk = _G.SDK
    local w = sdk and sdk.Snapshot
    local n = 0
    if w then
        local raw = QRaw()
        local sx, sz = S.x, S.z
        local reach2 = Q_RANGE2
        for pass = 1, 2 do
            local src = (pass == 1 and w.jungle) or w.lane
            local srcN = (pass == 1 and (w.jungleN or 0)) or (w.laneN or 0)
            for i = 1, srcN do
                local u = src[i]
                if u then
                    if FarmByDist == nil then
                        FarmByDist = type(u.distance) == "number"
                    end
                    local near, px, pz
                    if FarmByDist then
                        local d = u.distance
                        near = d ~= nil and d <= Q_RANGE
                    else
                        local pp = u.pos
                        if pp then
                            px, pz = pp.x, pp.z
                            local dx, dz = px - sx, pz - sz
                            near = dx * dx + dz * dz <= reach2
                        end
                    end
                    if near and u.valid and u.visible and not u.dead
                        and u.isTargetable and not u.isImmortal then
                        if px == nil then
                            local pp = u.pos
                            if pp then px, pz = pp.x, pp.z end
                        end
                        if px then
                            n = n + 1
                            FMo[n] = u
                            FMx[n], FMz[n] = px, pz
                            FMkill[n] = raw > 0 and QKills(u, raw) or false
                        end
                    end
                end
            end
        end
    end
    for i = n + 1, FMhigh do FMo[i] = nil end
    FMhigh = n
    FMn = n
    return n
end

local function BestCluster(killsOnly)
    local bx, bz, best = nil, nil, 0
    for i = 1, FMn do
        local px, pz = FMx[i], FMz[i]
        local c = 0
        for j = 1, FMn do
            if not killsOnly or FMkill[j] then
                local ex, ez = FMx[j] - px, FMz[j] - pz
                if ex * ex + ez * ez <= Q_CLUSTER2 then c = c + 1 end
            end
        end
        if c > best then bx, bz, best = px, pz, c end
    end
    return bx, bz, best
end

local function RunClear()
    local node = Menu.clear
    if not node.useQ:Value() then return end
    if S.energy < node.energyMin:Value() then
        S.why = "energy"
        return
    end
    if not S.qR or S.casting or SentTick[SQ] == TICK then return end
    if FarmSnapshot() == 0 then return end

    local bx, bz, kills = BestCluster(true)
    if bx and kills >= node.qMin:Value() then
        CastQAt(bx, bz)
        return
    end

    if not node.push:Value() then
        S.why = "no kill"
        return
    end
    local px, pz, count = BestCluster(false)
    if px and count >= node.pushMin:Value() then
        CastQAt(px, pz)
        return
    end
    S.why = "no kill"
end

local function RunLastHit()
    local node = Menu.lasthit
    if not node.useQ:Value() then return end
    if S.energy < node.energyMin:Value() then
        S.why = "energy"
        return
    end
    if not S.qR or S.casting or SentTick[SQ] == TICK then return end
    if FarmSnapshot() == 0 then return end

    local bx, bz, kills = BestCluster(true)
    if bx and kills >= 1 then
        CastQAt(bx, bz)
        return
    end
    S.why = "no kill"
end

local PC = {
    res = false, x = 810, y = 870,
    cdText = { "Q", "W", "E", "R" },
    cdReady = { false, false, false, false },
    lastCd = {}, lastLv = {},
    tag = "", tagE2 = nil, tagR2 = nil, tagWhy = nil,
}

local function PanelCell(i, cd, ready, lv)
    PC.cdReady[i] = false
    if lv == 0 then
        if PC.lastLv[i] ~= 0 then
            PC.lastLv[i] = 0
            PC.lastCd[i] = -1
            PC.cdText[i] = PANEL_NAMES[i] .. " --"
        end
        return
    end
    PC.lastLv[i] = lv
    if ready then
        PC.cdReady[i] = true
        if PC.lastCd[i] ~= 0 then
            PC.lastCd[i] = 0
            PC.cdText[i] = PANEL_NAMES[i] .. " RDY"
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

    local e2, r2, why = S.hasE2, S.hasR2, S.why
    if PC.tagE2 ~= e2 or PC.tagR2 ~= r2 or PC.tagWhy ~= why then
        PC.tagE2, PC.tagR2, PC.tagWhy = e2, r2, why
        local t = ""
        if e2 then t = "E2" end
        if r2 then t = (t ~= "" and t .. " R2") or "R2" end
        if why ~= "" then t = (t ~= "" and t .. " " .. why) or why end
        PC.tag = t
    end
    if PC.tag ~= "" then
        DrawText(PC.tag, 12, x + 10, y + 8, (e2 or r2) and COL_MARK or COL_OFF)
    end

    for i = 1, 4 do
        DrawText(PC.cdText[i], 12, x + 10 + (i - 1) * 72, y + 32, (PC.cdReady[i] and COL_RDY) or COL_CD)
    end
end

local function OnDraw()
    local draw = Menu.draw
    if myHero.dead or not draw.enable:Value() then return end
    if not draw.shown:Value() then return end
    if draw.panel:Value() then DrawPanel() end
    local q, e, r = draw.qRange:Value(), draw.eRange:Value(), draw.rRange:Value()
    local marks = draw.marks:Value()
    if not (q or e or r or marks) then return end
    if not myHero.visible then return end

    if q or e or r then
        local pos = myHero.pos
        if q then DrawCircle(pos, Q_RANGE, 1, COL_Q) end
        if e then DrawCircle(pos, E_RANGE, 1, COL_E) end
        if r then DrawCircle(pos, R1_RANGE, 1, COL_R) end
    end

    if marks then
        for i = 1, EHn do
            if EHmark[i] then
                local u = EHo[i]
                local p = u.pos2D
                if p and p.onScreen then
                    DrawCircle(u.pos, (u.boundingRadius or 65) + 20, 2, COL_MARK)
                end
            end
        end
    end
end

local function OnTick()
    if myHero.dead then return end
    TICK = TICK + 1
    S.why = ""
    InitPred()
    BuildLists()
    SyncSelf()
    SyncEnemies()

    if GameIsChatOpen() then return end

    if RunShroud() then return end

    if S.casting then return end

    if KillSteal() then return end

    local mode = S.mode
    if mode == 1 then
        RunCombo()
    elseif mode == 2 then
        RunHarass()
    elseif mode == 3 then
        RunClear()
    elseif mode == 4 then
        RunLastHit()
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
    .. ((PredE and "on") or "waiting") .. " | hook " .. HOOK)
