if _G.__LOWKEY_YASUO_LOADED then return end
_G.__LOWKEY_YASUO_LOADED = true
if myHero.charName ~= "Yasuo" then return end

local VERSION = "1.0"
local SCRIPT_NAME = "Lowkey Yasuo"

local PredTries = 0

local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local math_sqrt = math.sqrt
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
local GameMissileCount = Game.MissileCount
local GameMissile = Game.Missile

local CastSpell = Control.CastSpell
local DrawCircle = Draw.Circle
local DrawText = Draw.Text
local DrawColor = Draw.Color

local SQ, SW, SE, SR = _Q, _W, _E, _R
local TEAM_ENEMY = 300 - myHero.team

local Q_RANGE, Q_RANGE2 = 475, 475 * 475
local Q_RADIUS = 40
local Q_DELAY_MAX, Q_DELAY_MIN, Q_AS_CAP = 0.40, 0.133, 0.67
local Q_BASE = { 20, 45, 70, 95, 120 }
local Q_AD = 1.05

local Q3_RANGE, Q3_RANGE2 = 1100, 1100 * 1100
local Q3_RADIUS, Q3_SPEED = 90, 1200

local E_RANGE, E_RANGE2 = 475, 475 * 475
local E_BASE = { 60, 70, 80, 90, 100 }
local E_AD, E_AP = 0.20, 0.60

local W_RANGE = 400
local W_CAST = 0.25
local MISSILE_PAD = 70

local R_RANGE, R_RANGE2 = 1400, 1400 * 1400
local R_BASE = { 200, 350, 500 }
local R_AD = 1.50
local R_ARMOR_PEN = 0.50

local TURRET_RANGE2 = 915 * 915

local Q3_WRAPPER = "YasuoQ3Wrapper"
local BUFF_QSTACK = "yasuoq3stacks"
local EMARKS = { "yasuoe", "yasuoedebuff", "yasuodashwrapper" }
local KNOCK_TYPES = { [30] = true, [31] = true }

local SELF_CAST = {}

local COL_Q = DrawColor(150, 255, 160, 160)
local COL_Q3 = DrawColor(230, 120, 220, 255)
local COL_E = DrawColor(150, 140, 255, 180)
local COL_R = DrawColor(120, 255, 90, 90)
local COL_MARK = DrawColor(255, 255, 90, 90)
local COL_FREE = DrawColor(255, 120, 255, 120)
local COL_BG = DrawColor(180, 10, 10, 15)
local COL_BORD = DrawColor(255, 200, 50, 50)
local COL_RDY = DrawColor(255, 120, 255, 120)
local COL_CD = DrawColor(255, 200, 200, 200)
local COL_OFF = DrawColor(255, 130, 130, 130)

local PANEL_NAMES = { "Q", "W", "E", "R" }

local TICK = 0

local S = {
    x = 0, y = 0, z = 0,
    ad = 0, ap = 0,
    hpPct = 100,
    qLv = 0, wLv = 0, eLv = 0, rLv = 0,
    qCd = 0, wCd = 0, eCd = 0, rCd = 0,
    qR = false, wR = false, eR = false, rR = false,
    qRaw = 0, eRaw = 0, rRaw = 0,
    qDelay = Q_DELAY_MAX,
    qStacks = 0,
    hasQ3 = false,
    casting = false,
    mode = 0,
    ti = 0,
    knocked = 0,
    why = "",
}

local SentTick = {}
local PendCt = {}
local PendUntil = {}

local EHo, EHx, EHz, EHd2 = {}, {}, {}, {}
local EHhp, EHarm = {}, {}
local EHmark, EHknock = {}, {}
local EHn = 0

local EList, EListN = {}, 0
local HeroSeen = -1

local EnemyHandles = {}
local HandleTick = -1
local WallX, WallZ, WallTick = 0, 0, -1

local TurX, TurZ = {}, {}
local TurN = 0
local TurTick = -1

local PredQ, PredQ3 = nil, nil
local Pos = { x = 0, y = 0, z = 0 }

local Menu = MenuElement({ type = MENU, id = "LowkeyYasuo", name = SCRIPT_NAME .. " v" .. VERSION })
Menu:MenuElement({ name = "info", drop = { "Steel Tempest and Sweeping Blade" } })

Menu:MenuElement({ type = MENU, id = "pred", name = "Prediction" })
Menu.pred:MenuElement({ id = "qHit", name = "Q Hit Chance", value = 1, drop = { "Normal", "High", "Immobile" } })
Menu.pred:MenuElement({ id = "q3Hit", name = "Q3 Hit Chance", value = 2, drop = { "Normal", "High", "Immobile" } })

Menu:MenuElement({ type = MENU, id = "combo", name = "Combo" })
Menu.combo:MenuElement({ id = "useQ", name = "Use Q", value = true })
Menu.combo:MenuElement({ id = "useQ3", name = "Use Q3 tornado", value = true })
Menu.combo:MenuElement({ id = "q3Only", name = "Hold Q3 for a target in range", value = true })
Menu.combo:MenuElement({ id = "useE", name = "Use E", value = true })
Menu.combo:MenuElement({ id = "eQ", name = "Q right after an E dash", value = true })

Menu:MenuElement({ type = MENU, id = "dash", name = "E Dashing" })
Menu.dash:MenuElement({ id = "minRange", name = "Only E beyond", value = 0, min = 0, max = 475, step = 25 })
Menu.dash:MenuElement({ id = "turretRule", name = "Into enemy turret", value = 2, drop = { "Never", "Smart", "Always" } })
Menu.dash:MenuElement({ id = "diveHP", name = "Smart: target HP% below", value = 40, min = 5, max = 100, step = 5, identifier = "%" })
Menu.dash:MenuElement({ id = "diveMine", name = "Smart: my HP% above", value = 50, min = 0, max = 100, step = 5, identifier = "%" })
Menu.dash:MenuElement({ id = "crowd", name = "Skip if enemies at landing >=", value = 3, min = 1, max = 5, step = 1 })

Menu:MenuElement({ type = MENU, id = "wall", name = "W Wind Wall" })
Menu.wall:MenuElement({ id = "key", name = "Cast toward cursor", key = string.byte("G") })
Menu.wall:MenuElement({ id = "auto", name = "Block incoming skillshots", value = true })
Menu.wall:MenuElement({ id = "attacks", name = "Also block basic attacks", value = false })
Menu.wall:MenuElement({ id = "window", name = "React when impact within", value = 0.5, min = 0.2, max = 1.2, step = 0.05 })
Menu.wall:MenuElement({ id = "pad", name = "Extra hit radius", value = 30, min = 0, max = 150, step = 10 })

Menu:MenuElement({ type = MENU, id = "ult", name = "R Last Breath" })
Menu.ult:MenuElement({ id = "use", name = "Use R on knocked up", value = true })
Menu.ult:MenuElement({ id = "count", name = "Only if knocked up >=", value = 1, min = 1, max = 5, step = 1 })

Menu:MenuElement({ type = MENU, id = "harass", name = "Harass" })
Menu.harass:MenuElement({ id = "useQ", name = "Use Q", value = true })
Menu.harass:MenuElement({ id = "q3Only", name = "Only the Q3 tornado", value = true })

Menu:MenuElement({ type = MENU, id = "clear", name = "Clear" })
Menu.clear:MenuElement({ id = "useQ", name = "Use Q", value = true })

Menu:MenuElement({ type = MENU, id = "ks", name = "Killsteal" })
Menu.ks:MenuElement({ id = "useQ", name = "Q killsteal", value = true })
Menu.ks:MenuElement({ id = "useR", name = "R killsteal", value = false })

Menu:MenuElement({ type = MENU, id = "draw", name = "Drawings" })
Menu.draw:MenuElement({ id = "enable", name = "Enable drawings", value = true })
Menu.draw:MenuElement({ id = "panel", name = "Status panel", value = true })
Menu.draw:MenuElement({ id = "qRange", name = "Q range", value = true })
Menu.draw:MenuElement({ id = "eRange", name = "E range", value = true })
Menu.draw:MenuElement({ id = "rRange", name = "R range", value = false })
Menu.draw:MenuElement({ id = "marks", name = "Mark dashable enemies", value = true })
Menu.draw:MenuElement({ id = "wall", name = "Mark the missile W would block", value = true })

local function PhysMul(armor, pen)
    local v = armor or 0
    if pen and pen > 0 then v = v * (1 - pen) end
    local pct = myHero.armorPenPercent
    if pct and pct > 0 then v = v * pct end
    local bonus = myHero.bonusArmorPenPercent
    if bonus and bonus > 0 then v = v * bonus end
    local flat = myHero.armorPen
    if flat and flat > 0 then v = v - flat end
    if v >= 0 then return 100 / (100 + v) end
    return 2 - 100 / (100 - v)
end

local function IsValidUnit(obj)
    return obj ~= nil and obj.valid and obj.visible and obj.isTargetable
        and not obj.dead and not obj.isImmortal and obj.health > 0
end

local BuffSrc = nil
local BuffApi = nil

local function BuffMapOf(unit)
    if BuffSrc == nil then
        local sdk = _G.SDK
        local c = sdk and sdk.Cached
        BuffSrc = (c and c.GetBuffMap and c) or false
    end
    if not BuffSrc then return nil end
    return BuffSrc:GetBuffMap(unit)
end

local function HasKnock(unit)
    if BuffApi == nil then
        local sdk = _G.SDK
        local b = sdk and sdk.BuffManager
        BuffApi = (b and b.HasBuffTypes and b) or false
    end
    if not BuffApi then return false end
    local ok, r = pcall(BuffApi.HasBuffTypes, BuffApi, unit, KNOCK_TYPES)
    return ok and r == true
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
    if PredQ then return end
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
        Type = gg.SPELLTYPE_LINE, Delay = Q_DELAY_MAX, Radius = Q_RADIUS,
        Range = Q_RANGE, Speed = math_huge, Collision = false,
    })
    PredQ3 = gg:SpellPrediction({
        Type = gg.SPELLTYPE_LINE, Delay = Q_DELAY_MAX, Radius = Q3_RADIUS,
        Range = Q3_RANGE, Speed = Q3_SPEED, Collision = false,
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
    S.ad = myHero.bonusDamage or 0
    S.ap = myHero.ap or 0
    local mh = myHero.maxHealth
    S.hpPct = (mh and mh > 0 and myHero.health / mh * 100) or 100

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

    S.hasQ3 = q.name == Q3_WRAPPER

    if SELF_CAST.ready == nil then
        SELF_CAST.ready = true
        SELF_CAST["YasuoQ1"] = true
        SELF_CAST["YasuoQ2"] = true
        SELF_CAST["YasuoQ3"] = true
        SELF_CAST[r.name or "YasuoR"] = true
    end

    S.casting = false
    local act = myHero.activeSpell
    if act and act.valid and not act.isStopped then
        local an = act.name
        if an and SELF_CAST[an] then S.casting = true end
    end

    local bonus = (myHero.attackSpeed or 1) - 1
    if bonus < 0 then bonus = 0 end
    S.qDelay = math_max(Q_DELAY_MIN, Q_DELAY_MAX * (1 - math_min(bonus, Q_AS_CAP)))

    S.qStacks = 0
    local map = BuffMapOf(myHero)
    if map then
        local st = map[BUFF_QSTACK]
        if st then S.qStacks = st.count or 0 end
    end
    if S.qStacks == 0 then
        local ammo = myHero.hudAmmo
        if ammo and ammo > 0 and ammo <= 2 then S.qStacks = ammo end
    end

    S.qRaw = (S.qLv > 0 and Q_BASE[S.qLv] + Q_AD * (myHero.totalDamage or 0)) or 0
    S.eRaw = (S.eLv > 0 and E_BASE[S.eLv] + E_AD * S.ad + E_AP * S.ap) or 0
    S.rRaw = (S.rLv > 0 and R_BASE[S.rLv] + R_AD * S.ad) or 0

    S.mode = OrbMode()
end

local function SyncEnemies()
    local prev = EHn
    local n = 0
    local sx, sz = S.x, S.z
    local knocked = 0
    local tgt = nil
    local sdk = _G.SDK
    if sdk and sdk.TargetSelector then
        local t = sdk.TargetSelector:GetTarget(R_RANGE)
        if t and t.team == TEAM_ENEMY and IsValidUnit(t) then tgt = t end
    end
    local tgtId = tgt and tgt.networkID
    local ti = 0

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
            EHhp[n] = h.health + (h.shieldAD or 0)
            EHarm[n] = h.armor

            local mark, knock = false, false
            if d2 <= R_RANGE2 then
                local map = BuffMapOf(h)
                if map then
                    for m = 1, 3 do
                        if map[EMARKS[m]] then
                            mark = true
                            break
                        end
                    end
                end
                knock = HasKnock(h)
                if knock then knocked = knocked + 1 end
            end
            EHmark[n] = mark
            EHknock[n] = knock

            if tgtId and h.networkID == tgtId then ti = n end
        end
    end

    for i = n + 1, prev do EHo[i] = nil end
    EHn = n
    S.ti = ti
    S.knocked = knocked
end

local function EnemyTurrets()
    if TurTick == TICK then return end
    TurTick = TICK
    TurN = 0
    local sdk = _G.SDK
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

local function QDamage(i) return S.qRaw * PhysMul(EHarm[i]) end
local function RDamage(i) return S.rRaw * PhysMul(EHarm[i], R_ARMOR_PEN) end

local function AckWindow()
    local sdk = _G.SDK
    local d = sdk and sdk.Data
    if d and d.GetLatency then
        local ok, lat = pcall(d.GetLatency, d)
        if ok and type(lat) == "number" and lat > 0 then return lat * 2 + 0.05 end
    end
    return 0.2
end

local function SlotFree(slot)
    local pc = PendCt[slot]
    if pc == nil then return true end
    local data = myHero:GetSpellData(slot)
    local ct = data and data.castTime
    if ct ~= pc then
        PendCt[slot] = nil
        return true
    end
    if GameCanUseSpell(slot) ~= 0 then
        PendCt[slot] = nil
        return true
    end
    if GameTimer() >= PendUntil[slot] then
        PendCt[slot] = nil
        return true
    end
    return false
end

local function MarkSent(slot)
    local data = myHero:GetSpellData(slot)
    PendCt[slot] = (data and data.castTime) or 0
    PendUntil[slot] = GameTimer() + AckWindow()
    SentTick[slot] = TICK
end

local function Send(hk, slot, x, z)
    if not SlotFree(slot) then return false end
    Pos.x, Pos.y, Pos.z = x, S.y, z
    if CastSpell(hk, Pos) == false then return false end
    MarkSent(slot)
    return true
end

local function SendUnit(hk, slot, unit)
    if not SlotFree(slot) then return false end
    if CastSpell(hk, unit) == false then return false end
    MarkSent(slot)
    return true
end

local function PredictAt(pred, i, want, range2)
    if not pred then return EHx[i], EHz[i] end
    pred.Delay = S.qDelay
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
    if S.hasQ3 then
        if EHd2[i] > Q3_RANGE2 then return false end
        local x, z = PredictAt(PredQ3, i, HitOf(Menu.pred.q3Hit:Value()), Q3_RANGE2)
        if not x then return false end
        return Send(HK_Q, SQ, x, z)
    end
    if EHd2[i] > Q_RANGE2 then return false end
    local x, z = PredictAt(PredQ, i, HitOf(Menu.pred.qHit:Value()), Q_RANGE2)
    if not x then return false end
    return Send(HK_Q, SQ, x, z)
end

local function DashAllowed(i)
    local x, z = EHx[i], EHz[i]
    if not UnderTurret(x, z) then
        if CrowdAt(x, z, Menu.dash.crowd:Value()) then return false, "crowded" end
        return true, ""
    end
    local rule = Menu.dash.turretRule:Value()
    if rule == 1 then return false, "turret" end
    if rule == 3 then return true, "dive" end
    if S.hpPct <= Menu.dash.diveMine:Value() then return false, "my hp" end
    local mh = EHo[i].maxHealth
    local pct = (mh and mh > 0 and EHo[i].health / mh * 100) or 100
    if pct > Menu.dash.diveHP:Value() then return false, "target hp" end
    if CrowdAt(x, z, Menu.dash.crowd:Value()) then return false, "crowded" end
    return true, "dive"
end

local function CastE(i)
    if i == 0 or not S.eR or S.casting or SentTick[SE] == TICK then return false end
    if EHmark[i] then
        S.why = "marked"
        return false
    end
    local d2 = EHd2[i]
    if d2 > E_RANGE2 then return false end
    local min = Menu.dash.minRange:Value()
    if d2 < min * min then
        S.why = "too close"
        return false
    end
    local ok, why = DashAllowed(i)
    S.why = why
    if not ok then return false end
    return SendUnit(HK_E, SE, EHo[i])
end

local function CastR()
    if not Menu.ult.use:Value() or not S.rR or S.casting or SentTick[SR] == TICK then return false end
    if S.mode ~= 1 then return false end
    if S.knocked < Menu.ult.count:Value() then return false end
    for i = 1, EHn do
        if EHknock[i] and EHd2[i] <= R_RANGE2 then
            return SendUnit(HK_R, SR, EHo[i])
        end
    end
    return false
end

local function EnemyHandleSet()
    if HandleTick == TICK then return EnemyHandles end
    HandleTick = TICK
    for k in pairs(EnemyHandles) do EnemyHandles[k] = nil end
    for i = 1, EListN do
        local u = EList[i]
        local h = u and u.handle
        if h then EnemyHandles[h] = true end
    end
    return EnemyHandles
end

local function WillHitMe(mx, mz, ex, ez, radius)
    local dx, dz = ex - mx, ez - mz
    local px, pz = S.x - mx, S.z - mz
    local len2 = dx * dx + dz * dz
    if len2 < 1 then
        return px * px + pz * pz <= radius * radius
    end
    local t = (px * dx + pz * dz) / len2
    if t < 0 then return false end
    if t > 1 then t = 1 end
    local cx = mx + dx * t - S.x
    local cz = mz + dz * t - S.z
    return cx * cx + cz * cz <= radius * radius
end

local function CastWAt(x, z)
    if not S.wR or S.casting or SentTick[SW] == TICK then return false end
    local dx, dz = x - S.x, z - S.z
    local len = dx * dx + dz * dz
    if len < 1 then return false end
    len = math_sqrt(len)
    local k = W_RANGE / len
    return Send(HK_W, SW, S.x + dx * k, S.z + dz * k)
end

local function FindThreat()
    if EListN == 0 then return nil end
    local total = GameMissileCount()
    if not total or total <= 0 or total > 20000 then return nil end

    local mine = myHero.handle
    local owners = EnemyHandleSet()
    local blockAttacks = Menu.wall.attacks:Value()
    local radius = MISSILE_PAD + (myHero.boundingRadius or 65) + Menu.wall.pad:Value()
    local window = Menu.wall.window:Value()

    local lat = 0.05
    local sdk = _G.SDK
    local dat = sdk and sdk.Data
    if dat and dat.GetLatency then
        local ok, v = pcall(dat.GetLatency, dat)
        if ok and type(v) == "number" and v > 0 then lat = v end
    end
    local floorLead = W_CAST + lat

    local bestX, bestZ, bestLead = nil, nil, math_huge
    for i = total, 1, -1 do
        local ms = GameMissile(i)
        local d = ms and ms.missileData
        if d and d.owner ~= mine and owners[d.owner] then
            local targeted = d.target ~= nil and d.target ~= 0
            if blockAttacks or not targeted then
                local sp = ms.pos
                local ep = d.endPos
                if sp and ep then
                    local mx, mz = sp.x, sp.z or sp.y
                    local dx, dz = S.x - mx, S.z - mz
                    local gap = math_sqrt(dx * dx + dz * dz)
                    local speed = d.speed
                    if not speed or speed <= 0 then speed = 1500 end
                    local lead = gap / speed
                    if lead >= floorLead and lead <= window and lead < bestLead then
                        local ex, ez = ep.x, ep.z or ep.y
                        if targeted or WillHitMe(mx, mz, ex, ez, radius) then
                            bestX, bestZ, bestLead = mx, mz, lead
                        end
                    end
                end
            end
        end
    end
    return bestX, bestZ
end

local function RunWall()
    if Menu.wall.key:Value() then
        local m = Game.mousePos()
        if m then return CastWAt(m.x, m.z or m.y) end
    end
    if not Menu.wall.auto:Value() then return false end
    if not S.wR or S.casting or SentTick[SW] == TICK then return false end

    local mx, mz = FindThreat()
    if not mx then return false end

    WallX, WallZ, WallTick = mx, mz, TICK

    local dx, dz = mx - S.x, mz - S.z
    local gap = math_sqrt(dx * dx + dz * dz)
    if gap < 1 then return false end
    local reach = gap * 0.6
    if reach < 100 then reach = 100 end
    if reach > W_RANGE then reach = W_RANGE end
    local k = reach / gap
    return Send(HK_W, SW, S.x + dx * k, S.z + dz * k)
end

local function KillSteal()
    local node = Menu.ks
    if node.useQ:Value() and S.qR then
        for i = 1, EHn do
            if QDamage(i) >= EHhp[i] then
                if CastQ(i) then return true end
            end
        end
    end
    if node.useR:Value() and S.rR and S.knocked > 0 then
        for i = 1, EHn do
            if EHknock[i] and EHd2[i] <= R_RANGE2 and RDamage(i) >= EHhp[i] then
                if SendUnit(HK_R, SR, EHo[i]) then return true end
            end
        end
    end
    return false
end

local function Q3Worth()
    if not Menu.combo.q3Only:Value() then return true end
    for i = 1, EHn do
        if EHd2[i] <= Q3_RANGE2 then return true end
    end
    return false
end

local function RunCombo()
    local node = Menu.combo
    local i = S.ti

    if node.useE:Value() and i ~= 0 and CastE(i) then
        if node.eQ:Value() and S.qR then CastQ(i) end
        return
    end

    if S.hasQ3 then
        if node.useQ3:Value() and Q3Worth() and CastQ(i) then return end
        return
    end

    if node.useQ:Value() and CastQ(i) then return end
end

local function RunHarass()
    if not Menu.harass.useQ:Value() then return end
    if Menu.harass.q3Only:Value() and not S.hasQ3 then return end
    CastQ(S.ti)
end

local PC = {
    res = false, x = 810, y = 870,
    cdText = { "Q", "W", "E", "R" },
    cdReady = { false, false, false, false },
    lastCd = {}, lastLv = {},
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

    local tempest = (S.hasQ3 and "TORNADO") or string_format("Q %d/2", S.qStacks)
    DrawText(tempest, 12, x + 10, y + 8, (S.hasQ3 and COL_Q3) or COL_OFF)
    if S.knocked > 0 then
        DrawText(string_format("AIR %d", S.knocked), 12, x + 110, y + 8, COL_RDY)
    end
    if S.why ~= "" then
        DrawText(S.why, 12, x + 190, y + 8, COL_OFF)
    end

    for i = 1, 4 do
        DrawText(PC.cdText[i], 12, x + 10 + (i - 1) * 72, y + 32, (PC.cdReady[i] and COL_RDY) or COL_CD)
    end
end

local function OnDraw()
    local draw = Menu.draw
    if myHero.dead or not draw.enable:Value() then return end
    if draw.panel:Value() then DrawPanel() end
    if not myHero.visible then return end
    local pos = myHero.pos

    if draw.qRange:Value() then
        if S.hasQ3 then
            DrawCircle(pos, Q3_RANGE, 1, COL_Q3)
        else
            DrawCircle(pos, Q_RANGE, 1, COL_Q)
        end
    end
    if draw.eRange:Value() then DrawCircle(pos, E_RANGE, 1, COL_E) end
    if draw.rRange:Value() then DrawCircle(pos, R_RANGE, 1, COL_R) end

    if draw.wall:Value() and WallTick >= 0 and TICK - WallTick < 60 then
        Pos.x, Pos.y, Pos.z = WallX, S.y, WallZ
        DrawCircle(Pos, 90, 2, COL_MARK)
    end

    if draw.marks:Value() then
        for i = 1, EHn do
            if EHd2[i] <= E_RANGE2 then
                local u = EHo[i]
                local p = u.pos2D
                if p and p.onScreen then
                    DrawCircle(u.pos, (u.boundingRadius or 65) + 15, 2,
                        (EHmark[i] and COL_MARK) or COL_FREE)
                end
            end
        end
    end
end

local function OnTick()
    if myHero.dead then return end
    TICK = TICK + 1
    InitPred()
    BuildLists()
    SyncSelf()
    SyncEnemies()

    if GameIsChatOpen() then return end

    if RunWall() then return end

    if S.casting then return end

    if CastR() then return end
    if KillSteal() then return end

    if S.mode == 1 then
        RunCombo()
    elseif S.mode == 2 then
        RunHarass()
    elseif S.mode == 3 then
        if Menu.clear.useQ:Value() and S.qR and S.ti ~= 0 then CastQ(S.ti) end
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
    .. ((PredQ and "on") or "waiting") .. " | hook " .. HOOK)
