if _G.__LOWKEY_DRAVEN_LOADED then return end
_G.__LOWKEY_DRAVEN_LOADED = true
if myHero.charName ~= "Draven" then return end

local VERSION = "1.2"
local SCRIPT_NAME = "Lowkey Draven"

local PredTries = 0

local math_huge = math.huge
local math_floor = math.floor
local string_format = string.format
local string_lower = string.lower
local type = type
local pcall = pcall
local tostring = tostring

local Game = Game
local myHero = myHero

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

local MAX_AXES = 2

local E_RANGE, E_RANGE2 = 1050, 1050 * 1050
local E_RADIUS, E_DELAY, E_SPEED = 130, 0.25, 1400
local R_REACH, R_REACH2 = 3000, 3000 * 3000
local R_RADIUS, R_DELAY, R_SPEED = 160, 0.4, 2000
local TURRET_RANGE2 = 915 * 915

local E_BASE = { 75, 110, 145, 180, 215 }
local E_AD = 0.5
local R_BASE = { 175, 275, 375 }
local R_AD = 1.1

local AXE_MISSILE = "DravenSpinningReturn"
local BUFF_SPIN = "dravenspinning"
local BUFF_FURY = "dravenfury"
local BUFF_RDOUBLE = "dravenrdoublecast"

local SELF_CAST = {}

local COL_AXE = DrawColor(255, 255, 200, 70)
local COL_AXE_FAR = DrawColor(150, 160, 140, 90)
local COL_E = DrawColor(150, 255, 140, 140)
local COL_R = DrawColor(120, 255, 90, 90)
local COL_BG = DrawColor(180, 10, 10, 15)
local COL_BORD = DrawColor(255, 200, 50, 50)
local COL_RDY = DrawColor(255, 120, 255, 120)
local COL_CD = DrawColor(255, 200, 200, 200)
local COL_OFF = DrawColor(255, 130, 130, 130)

local PANEL_NAMES = { "Q", "W", "E", "R" }

local TICK = 0

local S = {
    x = 0, y = 0, z = 0,
    ad = 0,
    qLv = 0, wLv = 0, eLv = 0, rLv = 0,
    qCd = 0, wCd = 0, eCd = 0, rCd = 0,
    qR = false, wR = false, eR = false, rR = false,
    eRaw = 0, rRaw = 0,
    spinning = 0,
    fury = false,
    rDouble = false,
    casting = false,
    mode = 0,
    ti = 0,
    hpPct = 100,
    catching = false,
    catchD2 = 0,
    why = "",
}

local SentTick = {}

local EHo, EHx, EHz, EHd2 = {}, {}, {}, {}
local EHhp, EHarm, EHhpP = {}, {}, {}
local EHn = 0

local EList, EListN = {}, 0
local HeroSeen = -1

local AxeX, AxeZ, AxeD2 = {}, {}, {}
local AxeN = 0
local CatchX, CatchZ = 0, 0

local TurX, TurZ = {}, {}
local TurN = 0
local TurTick = -1

local PredE, PredR = nil, nil
local Pos = { x = 0, y = 0, z = 0 }
local MovePos = { x = 0, y = 0, z = 0 }

local Menu = MenuElement({ type = MENU, id = "LowkeyDraven", name = SCRIPT_NAME .. " v" .. VERSION })
Menu:MenuElement({ name = "info", drop = { "Spinning Axe catching + Stand Aside" } })

Menu:MenuElement({ type = MENU, id = "axe", name = "Axe Catching" })
Menu.axe:MenuElement({ id = "enable", name = "Catch axes", value = true })
Menu.axe:MenuElement({ id = "selfRange", name = "Catch within", value = 700, min = 100, max = 1300, step = 50 })
Menu.axe:MenuElement({ id = "stopRange", name = "Stop when closer than", value = 80, min = 0, max = 300, step = 10 })
Menu.axe:MenuElement({ id = "comboLeash", name = "In combo, stay near target", value = true })
Menu.axe:MenuElement({ id = "targetRange", name = "Leash distance", value = 900, min = 200, max = 1600, step = 50 })
Menu.axe:MenuElement({
    id = "turretRule",
    name = "Under enemy turret",
    value = 2,
    drop = { "Never go", "Smart", "Always go" },
})
Menu.axe:MenuElement({ id = "diveHP", name = "Smart: target HP% below", value = 40, min = 5, max = 100, step = 5, identifier = "%" })
Menu.axe:MenuElement({ id = "diveMine", name = "Smart: my HP% above", value = 50, min = 0, max = 100, step = 5, identifier = "%" })
Menu.axe:MenuElement({ id = "diveReach", name = "Smart: axe must keep target in range", value = true })
Menu.axe:MenuElement({ id = "diveCrowd", name = "Smart: skip if enemies near axe >=", value = 3, min = 1, max = 5, step = 1 })
Menu.axe:MenuElement({ id = "wChase", name = "W to reach a far axe", value = true })
Menu.axe:MenuElement({ id = "wChaseAt", name = "W if axe further than", value = 550, min = 200, max = 1300, step = 50 })

Menu:MenuElement({ type = MENU, id = "pred", name = "Prediction" })
Menu.pred:MenuElement({ id = "eHit", name = "E Hit Chance", value = 2, drop = { "Normal", "High", "Immobile" } })
Menu.pred:MenuElement({ id = "rHit", name = "R Hit Chance", value = 3, drop = { "Normal", "High", "Immobile" } })

Menu:MenuElement({ type = MENU, id = "combo", name = "Combo" })
Menu.combo:MenuElement({ id = "useQ", name = "Keep axes up", value = true })
Menu.combo:MenuElement({ id = "qCount", name = "Axes to hold", value = 2, min = 1, max = 2, step = 1 })
Menu.combo:MenuElement({ id = "useW", name = "Use W", value = true })
Menu.combo:MenuElement({ id = "useE", name = "Use E", value = false })
Menu.combo:MenuElement({ id = "eMin", name = "E only beyond", value = 300, min = 0, max = 1050, step = 50 })

Menu:MenuElement({ type = MENU, id = "harass", name = "Harass" })
Menu.harass:MenuElement({ id = "useQ", name = "Keep axes up", value = true })
Menu.harass:MenuElement({ id = "useE", name = "Use E", value = false })

Menu:MenuElement({ type = MENU, id = "clear", name = "Clear" })
Menu.clear:MenuElement({ id = "useQ", name = "Keep axes up", value = true })

Menu:MenuElement({ type = MENU, id = "autoE", name = "Auto E" })
Menu.autoE:MenuElement({ id = "antiDash", name = "Knock back dashes toward me", value = true })
Menu.autoE:MenuElement({ id = "interrupt", name = "Knock back channels in range", value = true })

Menu:MenuElement({ type = MENU, id = "ks", name = "Killsteal" })
Menu.ks:MenuElement({ id = "useE", name = "E killsteal", value = true })
Menu.ks:MenuElement({ id = "useR", name = "R killsteal", value = true })
Menu.ks:MenuElement({ id = "rMin", name = "R only beyond", value = 1200, min = 0, max = 3000, step = 100 })

Menu:MenuElement({ type = MENU, id = "draw", name = "Drawings" })
Menu.draw:MenuElement({ id = "enable", name = "Enable drawings", value = true })
Menu.draw:MenuElement({ id = "panel", name = "Status panel", value = true })
Menu.draw:MenuElement({ id = "axes", name = "Axe landing spots", value = true })
Menu.draw:MenuElement({ id = "catch", name = "Catch radius", value = true })
Menu.draw:MenuElement({ id = "eRange", name = "E range", value = true })
Menu.draw:MenuElement({ id = "rRange", name = "R range", value = false })

local function PhysMul(armor)
    local v = armor or 0
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

local function SetForceMove(x, z)
    local sdk = _G.SDK
    local w = sdk and sdk.Orbwalker
    if not w then return end
    if x == nil then
        w.ForceMovement = nil
        return
    end
    MovePos.x, MovePos.y, MovePos.z = x, S.y, z
    w.ForceMovement = MovePos
end

local function DropCatch()
    if not S.catching then return end
    S.catching = false
    SetForceMove(nil)
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
        Range = E_RANGE, Speed = E_SPEED, Collision = false,
    })
    PredR = gg:SpellPrediction({
        Type = gg.SPELLTYPE_LINE, Delay = R_DELAY, Radius = R_RADIUS,
        Range = R_REACH, Speed = R_SPEED, Collision = false,
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

    if SELF_CAST.ready == nil then
        SELF_CAST.ready = true
        SELF_CAST[q.name or "DravenSpinning"] = true
        SELF_CAST[w.name or "DravenFury"] = true
        SELF_CAST[r.name or "DravenRCast"] = true
    end

    S.casting = false
    local act = myHero.activeSpell
    if act and act.valid and not act.isStopped then
        local an = act.name
        if an and SELF_CAST[an] then S.casting = true end
    end

    S.spinning = 0
    S.fury = false
    S.rDouble = false
    local map = BuffMapOf(myHero)
    if map then
        local spin = map[BUFF_SPIN]
        if spin then S.spinning = spin.count or 0 end
        S.fury = map[BUFF_FURY] ~= nil
        S.rDouble = map[BUFF_RDOUBLE] ~= nil
    else
        local bc = myHero.buffCount
        if bc then
            for b = 0, bc - 1 do
                local buff = myHero:GetBuff(b)
                if buff and buff.name and buff.count and buff.count > 0 then
                    local bn = string_lower(buff.name)
                    if bn == BUFF_SPIN then
                        S.spinning = buff.count
                    elseif bn == BUFF_FURY then
                        S.fury = true
                    elseif bn == BUFF_RDOUBLE then
                        S.rDouble = true
                    end
                end
            end
        end
    end

    S.eRaw = (S.eLv > 0 and E_BASE[S.eLv] + E_AD * S.ad) or 0
    S.rRaw = (S.rLv > 0 and R_BASE[S.rLv] + R_AD * S.ad) or 0

    S.mode = OrbMode()
end

local function SyncEnemies()
    local prev = EHn
    local n = 0
    local sx, sz = S.x, S.z
    local tgt = nil
    local sdk = _G.SDK
    if sdk and sdk.TargetSelector then
        local t = sdk.TargetSelector:GetTarget(R_REACH)
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
            n = n + 1
            EHo[n] = h
            EHx[n], EHz[n] = px, pz
            EHd2[n] = dx * dx + dz * dz
            EHhp[n] = h.health + (h.shieldAD or 0)
            EHarm[n] = h.armor
            local mh = h.maxHealth
            EHhpP[n] = (mh and mh > 0 and h.health / mh * 100) or 100
            if tgtId and h.networkID == tgtId then ti = n end
        end
    end

    for i = n + 1, prev do EHo[i] = nil end
    EHn = n
    S.ti = ti
end

local function SyncAxes()
    local n = 0
    local sx, sz = S.x, S.z
    local mine = myHero.handle
    local total = GameMissileCount()
    if total and total > 0 and total < 20000 then
        for i = total, 1, -1 do
            local m = GameMissile(i)
            local d = m and m.missileData
            if d and d.owner == mine and d.name == AXE_MISSILE then
                local ep = d.endPos
                if ep and ep.x then
                    local ax, az = ep.x, ep.z or ep.y
                    local dx, dz = ax - sx, az - sz
                    n = n + 1
                    AxeX[n], AxeZ[n] = ax, az
                    AxeD2[n] = dx * dx + dz * dz
                end
            end
        end
    end
    AxeN = n
end

local function EnemyTurrets()
    if TurTick == TICK then return end
    TurTick = TICK
    TurN = 0
    local sdk = _G.SDK
    local om = sdk and sdk.ObjectManager
    if not om or not om.GetEnemyTurrets then return end
    local ok, list = pcall(om.GetEnemyTurrets, om, R_REACH)
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

local function AttackReachTo(unit)
    local sdk = _G.SDK
    local d = sdk and sdk.Data
    if d and d.GetAutoAttackRange then
        local ok, r = pcall(d.GetAutoAttackRange, d, myHero, unit)
        if ok and type(r) == "number" and r > 0 then return r end
    end
    return (myHero.range or 550) + (myHero.boundingRadius or 65) + (unit.boundingRadius or 65)
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

local function DiveAllowed(x, z)
    local rule = Menu.axe.turretRule:Value()
    if rule == 3 then return true, "dive" end
    if rule == 1 then return false, "turret" end

    if S.hpPct <= Menu.axe.diveMine:Value() then return false, "my hp" end

    local i = S.ti
    if i == 0 then return false, "no target" end
    if EHhpP[i] > Menu.axe.diveHP:Value() then return false, "target hp" end

    if Menu.axe.diveReach:Value() then
        local reach = AttackReachTo(EHo[i])
        local dx, dz = EHx[i] - x, EHz[i] - z
        if dx * dx + dz * dz > reach * reach then return false, "no reach" end
    end

    if CrowdAt(x, z, Menu.axe.diveCrowd:Value()) then return false, "crowded" end

    return true, "dive"
end

local function EDamage(i) return S.eRaw * PhysMul(EHarm[i]) end

local function RDamage(i)
    local raw = S.rRaw
    if S.rDouble then raw = raw * 2 end
    return raw * PhysMul(EHarm[i])
end

local function Send(hk, slot, x, z)
    Pos.x, Pos.y, Pos.z = x, S.y, z
    if CastSpell(hk, Pos) == false then return false end
    SentTick[slot] = TICK
    return true
end

local function SendSelf(hk, slot)
    if CastSpell(hk) == false then return false end
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

local function WantAxes()
    local node
    local mode = S.mode
    if mode == 1 then
        node = Menu.combo
    elseif mode == 2 then
        node = Menu.harass
    elseif mode == 3 or mode == 4 then
        node = Menu.clear
    else
        return 0
    end
    if not node.useQ:Value() then return 0 end
    local want = Menu.combo.qCount:Value()
    if want > MAX_AXES then want = MAX_AXES end
    return want
end

local function CastQ()
    if not S.qR or SentTick[SQ] == TICK then return false end
    local want = WantAxes()
    if want == 0 then return false end
    if S.spinning >= want then return false end
    return SendSelf(HK_Q, SQ)
end

local function CastE(i)
    if i == 0 or not S.eR or S.casting or SentTick[SE] == TICK then return false end
    if EHd2[i] > E_RANGE2 then return false end
    local x, z = PredictAt(PredE, i, HitOf(Menu.pred.eHit:Value()), E_RANGE2)
    if not x then return false end
    return Send(HK_E, SE, x, z)
end

local function CastR(i)
    if i == 0 or not S.rR or S.casting or SentTick[SR] == TICK then return false end
    if EHd2[i] > R_REACH2 then return false end
    local x, z = PredictAt(PredR, i, HitOf(Menu.pred.rHit:Value()), R_REACH2)
    if not x then return false end
    return Send(HK_R, SR, x, z)
end

local function PickAxe()
    S.why = ""
    if not Menu.axe.enable:Value() then return false end
    if AxeN == 0 then return false end

    local reach = Menu.axe.selfRange:Value()
    local reach2 = reach * reach
    local leash = Menu.axe.comboLeash:Value() and S.mode == 1 and S.ti ~= 0
    local leashRange = Menu.axe.targetRange:Value()
    local leash2 = leashRange * leashRange
    local tx, tz = 0, 0
    if leash then tx, tz = EHx[S.ti], EHz[S.ti] end

    local best, bestD = 0, math_huge
    local bestDive = false
    local refusal = ""
    for i = 1, AxeN do
        local d2 = AxeD2[i]
        if d2 <= reach2 and d2 < bestD then
            local ax, az = AxeX[i], AxeZ[i]
            local ok, dive = true, false
            if leash then
                local dx, dz = ax - tx, az - tz
                ok = dx * dx + dz * dz <= leash2
                if not ok then refusal = "leashed" end
            end
            if ok and UnderTurret(ax, az) then
                local allow, reason = DiveAllowed(ax, az)
                ok, dive = allow, allow
                if not allow then refusal = reason end
            end
            if ok then
                best, bestD, bestDive = i, d2, dive
            end
        end
    end

    if best == 0 then
        S.why = refusal
        return false
    end
    S.why = (bestDive and "dive") or ""
    CatchX, CatchZ = AxeX[best], AxeZ[best]
    S.catchD2 = bestD
    return true
end

local function RunCatch()
    if not PickAxe() then
        DropCatch()
        return false
    end

    local stop = Menu.axe.stopRange:Value()
    if S.catchD2 <= stop * stop then
        DropCatch()
        return false
    end

    S.catching = true
    SetForceMove(CatchX, CatchZ)

    if Menu.axe.wChase:Value() and S.wR and SentTick[SW] ~= TICK and not S.fury then
        local at = Menu.axe.wChaseAt:Value()
        if S.catchD2 > at * at then SendSelf(HK_W, SW) end
    end
    return true
end

local function KillSteal()
    local node = Menu.ks
    if node.useE:Value() and S.eR then
        for i = 1, EHn do
            if EHd2[i] <= E_RANGE2 and EDamage(i) >= EHhp[i] then
                if CastE(i) then return true end
            end
        end
    end
    if node.useR:Value() and S.rR then
        local min = node.rMin:Value()
        local min2 = min * min
        for i = 1, EHn do
            if EHd2[i] >= min2 and RDamage(i) >= EHhp[i] then
                if CastR(i) then return true end
            end
        end
    end
    return false
end

local function AutoE()
    if not S.eR or S.casting or SentTick[SE] == TICK then return false end
    local node = Menu.autoE

    if node.antiDash:Value() then
        for i = 1, EHn do
            local u = EHo[i]
            local path = u.pathing
            if path and path.isDashing and path.endPos then
                local e = path.endPos
                local dx, dz = e.x - S.x, (e.z or e.y) - S.z
                if dx * dx + dz * dz < 160000 and EHd2[i] <= E_RANGE2 then
                    if CastE(i) then return true end
                end
            end
        end
    end

    if node.interrupt:Value() then
        for i = 1, EHn do
            if EHd2[i] <= E_RANGE2 then
                local act = EHo[i].activeSpell
                if act and act.valid and not act.isStopped and act.isChanneling then
                    if CastE(i) then return true end
                end
            end
        end
    end

    return false
end

local function RunCombo()
    local node = Menu.combo
    local i = S.ti
    if i == 0 then return end

    if node.useW:Value() and S.wR and SentTick[SW] ~= TICK and not S.fury then
        if EHd2[i] <= E_RANGE2 then SendSelf(HK_W, SW) end
    end

    if node.useE:Value() then
        local min = node.eMin:Value()
        if EHd2[i] >= min * min and CastE(i) then return end
    end
end

local function RunHarass()
    if Menu.harass.useE:Value() and CastE(S.ti) then return end
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
    local tag = (S.catching and "CATCH") or "catch"
    if S.why ~= "" then tag = tag .. " " .. S.why end
    DrawText(tag, 12, x + 10, y + 8, (S.catching and COL_AXE) or COL_OFF)
    if S.rDouble then
        DrawText("Rx2", 12, x + 268, y + 8, COL_RDY)
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

    if draw.catch:Value() and Menu.axe.enable:Value() then
        DrawCircle(pos, Menu.axe.selfRange:Value(), 1, COL_AXE_FAR)
    end
    if draw.eRange:Value() then DrawCircle(pos, E_RANGE, 1, COL_E) end
    if draw.rRange:Value() then DrawCircle(pos, R_REACH, 1, COL_R) end

    if draw.axes:Value() then
        local reach = Menu.axe.selfRange:Value()
        local reach2 = reach * reach
        for i = 1, AxeN do
            Pos.x, Pos.y, Pos.z = AxeX[i], S.y, AxeZ[i]
            DrawCircle(Pos, 120, 2, (AxeD2[i] <= reach2 and COL_AXE) or COL_AXE_FAR)
        end
        if S.catching then
            Pos.x, Pos.y, Pos.z = CatchX, S.y, CatchZ
            DrawCircle(Pos, 150, 3, COL_AXE)
        end
    end
end

local function OnTick()
    if myHero.dead then
        DropCatch()
        return
    end
    TICK = TICK + 1
    InitPred()
    BuildLists()
    SyncSelf()
    SyncEnemies()
    SyncAxes()

    if GameIsChatOpen() then
        DropCatch()
        return
    end

    RunCatch()

    if S.casting then return end

    if KillSteal() then return end
    if AutoE() then return end

    if S.mode == 1 then
        RunCombo()
    elseif S.mode == 2 then
        RunHarass()
    end
end

local function OnPreAttack()
    if myHero.dead or S.casting then return end
    CastQ()
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
    if sdk and sdk.Orbwalker and sdk.Orbwalker.OnPreAttack then
        sdk.Orbwalker:OnPreAttack(Guard(OnPreAttack, "preattack"))
    end
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

Callback.Add("UnLoad", function()
    SetForceMove(nil)
end)

local HOOK = Hook()

InitPred()
print("[" .. SCRIPT_NAME .. "] v" .. VERSION .. " loaded | pred "
    .. ((PredE and "on") or "waiting") .. " | hook " .. HOOK)
