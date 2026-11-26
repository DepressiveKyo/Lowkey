if _G.__LOWKEY_THRESH_LOADED then return end
_G.__LOWKEY_THRESH_LOADED = true
if myHero.charName ~= "Thresh" then return end

local VERSION = "1.3"
local SCRIPT_NAME = "Lowkey Thresh"

local PredTries = 0

local math_sqrt = math.sqrt
local math_max = math.max
local math_huge = math.huge
local math_floor = math.floor
local string_format = string.format
local string_lower = string.lower
local type = type
local pcall = pcall

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
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - TEAM_ALLY

local Q_RANGE, Q_RANGE2 = 1100, 1100 * 1100
local Q_DELAY, Q_SPEED, Q_RADIUS = 0.5, 1900, 70
local W_RANGE, W_RANGE2 = 950, 950 * 950
local E_RANGE, E_RANGE2 = 450, 450 * 450
local E_DELAY, E_RADIUS = 0.389, 110
local R_RADIUS, R_RADIUS2 = 400, 400 * 400
local R_DELAY = 0.45
local LEAP_HOLD = 0.4
local HOOK_MARK = 1.5

local Q_BASE = { 100, 150, 200, 250, 300 }
local Q_AP = 0.9
local E_BASE = { 65, 110, 155, 200, 245 }
local E_AP = 0.6
local R_BASE = { 250, 400, 550 }
local R_AP = 1.0

local NAME_Q = "ThreshQ"
local NAME_QLEAP = "ThreshQLeap"
local BUFF_HOOK = "threshq"

local SELF_CAST = {}

local COL_Q = DrawColor(255, 90, 200, 255)
local COL_W = DrawColor(150, 255, 220, 120)
local COL_E = DrawColor(150, 120, 255, 180)
local COL_R = DrawColor(200, 255, 90, 90)
local COL_HOOK = DrawColor(255, 255, 230, 80)
local COL_BG = DrawColor(180, 10, 10, 15)
local COL_BORD = DrawColor(255, 200, 50, 50)
local COL_RDY = DrawColor(255, 120, 255, 120)
local COL_CD = DrawColor(255, 200, 200, 200)
local COL_OFF = DrawColor(255, 130, 130, 130)

local PANEL_NAMES = { "Q", "W", "E", "R" }

local TICK = 0
local NOW = 0

local S = {
    x = 0, y = 0, z = 0,
    ap = 0,
    manaPct = 100, hpPct = 100,
    qLv = 0, wLv = 0, eLv = 0, rLv = 0,
    qCd = 0, wCd = 0, eCd = 0, rCd = 0,
    qR = false, wR = false, eR = false, rR = false,
    qRaw = 0, eRaw = 0, rRaw = 0,
    hooked = false,
    hookLeft = 0,
    casting = false,
    attacking = false,
    mode = 0,
    ti = 0,
}

local SentTick = {}

local EHo, EHx, EHz, EHd2 = {}, {}, {}, {}
local EHhp, EHmr, EHnoSpell = {}, {}, {}
local EHdash, EHdx, EHdz = {}, {}, {}
local EHnear = {}
local EHn = 0

local AHo, AHx, AHz, AHhpP = {}, {}, {}, {}
local AHn = 0

local EList, EListN = {}, 0
local AList, AListN = {}, 0
local HeroSeen = -1

local PredQ, PredE = nil, nil
local Pos = { x = 0, y = 0, z = 0 }

local Menu = MenuElement({ type = MENU, id = "LowkeyThresh", name = SCRIPT_NAME .. " v" .. VERSION })
Menu:MenuElement({ name = "info", drop = { "Death Sentence + Dark Passage" } })

Menu:MenuElement({ type = MENU, id = "pred", name = "Prediction" })
Menu.pred:MenuElement({ id = "qHit", name = "Q Hit Chance", value = 2, drop = { "Normal", "High", "Immobile" } })
Menu.pred:MenuElement({ id = "eHit", name = "E Hit Chance", value = 1, drop = { "Normal", "High", "Immobile" } })

Menu:MenuElement({ type = MENU, id = "combo", name = "Combo" })
Menu.combo:MenuElement({ id = "useQ", name = "Use Q (hook)", value = true })
Menu.combo:MenuElement({ id = "qSafety", name = "Q range safety margin", value = 100, min = 0, max = 250, step = 10 })
Menu.combo:MenuElement({ id = "useE", name = "Use E (flay)", value = true })
Menu.combo:MenuElement({ id = "ePull", name = "E pulls toward me", value = true })
Menu.combo:MenuElement({ id = "useR", name = "Use R (box)", value = true })
Menu.combo:MenuElement({ id = "rCount", name = "R if enemies inside >=", value = 2, min = 1, max = 5 })

Menu:MenuElement({ type = MENU, id = "leap", name = "Q2 Leap" })
Menu.leap:MenuElement({ id = "enable", name = "Fly to hooked target", value = false })
Menu.leap:MenuElement({ id = "minHP", name = "Only if my HP% above", value = 40, min = 0, max = 100, step = 5, identifier = "%" })

Menu:MenuElement({ type = MENU, id = "lantern", name = "W Lantern" })
Menu.lantern:MenuElement({ id = "enable", name = "Throw to low ally", value = true })
Menu.lantern:MenuElement({ id = "allyHP", name = "Ally HP% below", value = 35, min = 5, max = 100, step = 5, identifier = "%" })

Menu:MenuElement({ type = MENU, id = "autoE", name = "Auto E" })
Menu.autoE:MenuElement({ id = "antiDash", name = "Flay dashes toward me", value = true })
Menu.autoE:MenuElement({ id = "interrupt", name = "Flay channels in range", value = true })

Menu:MenuElement({ type = MENU, id = "ks", name = "Killsteal" })
Menu.ks:MenuElement({ id = "useQ", name = "Q killsteal", value = true })
Menu.ks:MenuElement({ id = "useE", name = "E killsteal", value = true })
Menu.ks:MenuElement({ id = "useR", name = "R killsteal", value = false })

Menu:MenuElement({ type = MENU, id = "draw", name = "Drawings" })
Menu.draw:MenuElement({ id = "enable", name = "Enable drawings", value = true })
Menu.draw:MenuElement({ id = "panel", name = "Status panel", value = true })
Menu.draw:MenuElement({ id = "qRange", name = "Q range", value = true })
Menu.draw:MenuElement({ id = "wRange", name = "W range", value = false })
Menu.draw:MenuElement({ id = "eRange", name = "E range", value = true })
Menu.draw:MenuElement({ id = "rRange", name = "R radius", value = true })

local function MagicMul(mr)
    local v = mr or 0
    local pct = myHero.magicPenPercent
    if pct and pct > 0 then v = v * pct end
    local flat = myHero.magicPen
    if flat and flat > 0 then v = v - flat end
    if v >= 0 then return 100 / (100 + v) end
    return 2 - 100 / (100 - v)
end

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

local function IsAttacking()
    local sdk = _G.SDK
    if not sdk or not sdk.Orbwalker or not sdk.Orbwalker.IsAutoAttacking then return false end
    local ok, r = pcall(sdk.Orbwalker.IsAutoAttacking, sdk.Orbwalker)
    return ok and r == true
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
        Type = gg.SPELLTYPE_LINE, Delay = Q_DELAY, Radius = Q_RADIUS,
        Range = Q_RANGE, Speed = Q_SPEED, Collision = true, MaxCollision = 0,
        CollisionTypes = { gg.COLLISION_MINION, gg.COLLISION_YASUOWALL },
    })
    PredE = gg:SpellPrediction({
        Type = gg.SPELLTYPE_LINE, Delay = E_DELAY, Radius = E_RADIUS,
        Range = E_RANGE, Speed = math_huge, Collision = false,
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
    EListN, AListN = 0, 0
    for i = 1, n do
        local h = GameHero(i)
        if h then
            if h.team == TEAM_ENEMY then
                EListN = EListN + 1
                EList[EListN] = h
            elseif h.networkID ~= myHero.networkID then
                AListN = AListN + 1
                AList[AListN] = h
            end
        end
    end
end

local function SyncSelf()
    NOW = GameTimer()
    local p = myHero.pos
    S.x, S.y, S.z = p.x, p.y, p.z
    S.ap = myHero.ap or 0
    local mm = myHero.maxMana
    S.manaPct = (mm > 0 and myHero.mana / mm * 100) or 100
    local mh = myHero.maxHealth
    S.hpPct = (mh > 0 and myHero.health / mh * 100) or 100

    local q = myHero:GetSpellData(SQ)
    local w = myHero:GetSpellData(SW)
    local e = myHero:GetSpellData(SE)
    local r = myHero:GetSpellData(SR)
    S.qLv, S.wLv, S.eLv, S.rLv = q.level, w.level, e.level, r.level
    S.qCd, S.wCd, S.eCd, S.rCd = q.currentCd, w.currentCd, e.currentCd, r.currentCd
    S.wR = S.wLv > 0 and GameCanUseSpell(SW) == 0
    S.eR = S.eLv > 0 and GameCanUseSpell(SE) == 0
    S.rR = S.rLv > 0 and GameCanUseSpell(SR) == 0

    local qName = q.name
    S.hooked = qName == NAME_QLEAP
    S.qR = S.qLv > 0 and GameCanUseSpell(SQ) == 0 and not S.hooked

    if SELF_CAST.ready == nil then
        SELF_CAST.ready = true
        SELF_CAST[NAME_Q] = true
        SELF_CAST[e.name or "ThreshE"] = true
        SELF_CAST[r.name or "ThreshRPenta"] = true
    end

    S.casting = false
    local act = myHero.activeSpell
    if act and act.valid and not act.isStopped then
        local an = act.name
        if an and SELF_CAST[an] then S.casting = true end
    end

    S.qRaw = (S.qLv > 0 and Q_BASE[S.qLv] + Q_AP * S.ap) or 0
    S.eRaw = (S.eLv > 0 and E_BASE[S.eLv] + E_AP * S.ap) or 0
    S.rRaw = (S.rLv > 0 and R_BASE[S.rLv] + R_AP * S.ap) or 0

    S.attacking = IsAttacking()
    S.mode = OrbMode()
end

local function SyncEnemies()
    local prev = EHn
    local n = 0
    local sx, sz = S.x, S.z
    local tgt = nil
    local sdk = _G.SDK
    if sdk and sdk.TargetSelector then
        local t = sdk.TargetSelector:GetTarget(Q_RANGE)
        if t and t.team == TEAM_ENEMY and IsValidUnit(t) then tgt = t end
    end
    local tgtId = tgt and tgt.networkID
    local ti = 0

    S.hookLeft = 0

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
            EHhp[n] = h.health + (h.shieldAP or 0)
            EHmr[n] = h.magicResist
            EHnoSpell[n] = false

            if tgtId and h.networkID == tgtId then ti = n end

            local path = h.pathing
            if path and path.isDashing and path.endPos then
                EHdash[n] = true
                EHdx[n], EHdz[n] = path.endPos.x, path.endPos.z
            else
                EHdash[n] = false
            end

            local bc = h.buffCount
            if bc then
                for b = 0, bc - 1 do
                    local buff = h:GetBuff(b)
                    if buff and buff.count and buff.count > 0 and buff.name then
                        local bn = string_lower(buff.name)
                        if bn == BUFF_HOOK then
                            local exp = buff.expireTime
                            if exp and exp > NOW then S.hookLeft = exp - NOW end
                        end
                    end
                end
            end
        end
    end

    for i = n + 1, prev do EHo[i] = nil end
    EHn = n
    S.ti = ti

    for i = 1, n do EHnear[i] = 1 end
    for i = 1, n - 1 do
        local ix, iz = EHx[i], EHz[i]
        for j = i + 1, n do
            local jx, jz = EHx[j] - ix, EHz[j] - iz
            if jx * jx + jz * jz <= R_RADIUS2 then
                EHnear[i] = EHnear[i] + 1
                EHnear[j] = EHnear[j] + 1
            end
        end
    end
end

local function SyncAllies()
    local n = 0
    local sx, sz = S.x, S.z
    for k = 1, AListN do
        local a = AList[k]
        if a and a.valid and a.visible and not a.dead and (a.maxHealth or 0) > 0 then
            local p = a.pos
            local dx, dz = p.x - sx, p.z - sz
            if dx * dx + dz * dz <= W_RANGE2 then
                n = n + 1
                AHo[n] = a
                AHx[n], AHz[n] = p.x, p.z
                AHhpP[n] = a.health / a.maxHealth * 100
            end
        end
    end
    for i = n + 1, AHn do AHo[i] = nil end
    AHn = n
end

local function QDamage(i) return S.qRaw * MagicMul(EHmr[i]) end
local function EDamage(i) return S.eRaw * MagicMul(EHmr[i]) end
local function RDamage(i) return S.rRaw * MagicMul(EHmr[i]) end

local function Send(hk, slot, x, z)
    Pos.x, Pos.y, Pos.z = x, S.y, z
    CastSpell(hk, Pos)
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

local function QCastRange()
    local r = Q_RANGE - Menu.combo.qSafety:Value()
    if r < 200 then r = 200 end
    return r
end

local function CastQ(i)
    if i == 0 or not S.qR or SentTick[SQ] == TICK or S.attacking then return false end
    local cast = QCastRange()
    local cast2 = cast * cast
    if EHd2[i] > cast2 then return false end
    if PredQ then PredQ.Range = cast end
    local x, z = PredictAt(PredQ, i, HitOf(Menu.pred.qHit:Value()), cast2)
    if not x then return false end
    return Send(HK_Q, SQ, x, z)
end

local function CastE(i, pull)
    if i == 0 or not S.eR or SentTick[SE] == TICK then return false end
    if EHd2[i] > E_RANGE2 then return false end
    local lim = E_RANGE + 20
    local x, z = PredictAt(PredE, i, HitOf(Menu.pred.eHit:Value()), lim * lim)
    if not x then return false end
    if pull then
        local dx, dz = x - S.x, z - S.z
        local len = math_sqrt(dx * dx + dz * dz)
        if len > 1 then
            x = S.x - dx / len * 200
            z = S.z - dz / len * 200
        end
    end
    return Send(HK_E, SE, x, z)
end

local function CastEAt(x, z)
    if not S.eR or SentTick[SE] == TICK then return false end
    local dx, dz = x - S.x, z - S.z
    if dx * dx + dz * dz > E_RANGE2 then return false end
    return Send(HK_E, SE, x, z)
end

local function LanternTarget()
    if not Menu.lantern.enable:Value() or not S.wR or SentTick[SW] == TICK then return 0 end
    local limit = Menu.lantern.allyHP:Value()
    local best, bestHp = 0, limit
    for i = 1, AHn do
        if AHhpP[i] <= bestHp then
            bestHp = AHhpP[i]
            best = i
        end
    end
    return best
end

local function KillSteal()
    local ks = Menu.ks
    if ks.useQ:Value() and S.qR and SentTick[SQ] ~= TICK then
        for i = 1, EHn do
            if EHd2[i] <= Q_RANGE2 and EHhp[i] < QDamage(i) then
                if CastQ(i) then return true end
            end
        end
    end
    if ks.useE:Value() and S.eR and SentTick[SE] ~= TICK then
        for i = 1, EHn do
            if EHd2[i] <= E_RANGE2 and EHhp[i] < EDamage(i) then
                if CastE(i, false) then return true end
            end
        end
    end
    if ks.useR:Value() and S.rR and SentTick[SR] ~= TICK then
        for i = 1, EHn do
            if EHd2[i] <= R_RADIUS2 and EHhp[i] < RDamage(i) then
                CastSpell(HK_R)
                SentTick[SR] = TICK
                return true
            end
        end
    end
    return false
end

local function AutoE()
    if not S.eR or SentTick[SE] == TICK then return false end
    local autoE = Menu.autoE

    if autoE.antiDash:Value() then
        for i = 1, EHn do
            if EHdash[i] then
                local dx, dz = EHdx[i] - S.x, EHdz[i] - S.z
                if dx * dx + dz * dz < 160000 and EHd2[i] <= E_RANGE2 then
                    if CastE(i, false) then return true end
                end
            end
        end
    end

    if autoE.interrupt:Value() then
        for i = 1, EHn do
            if EHd2[i] <= E_RANGE2 then
                local act = EHo[i].activeSpell
                if act and act.valid and not act.isStopped and act.isChanneling then
                    if CastE(i, false) then return true end
                end
            end
        end
    end

    return false
end

local function BoxWorth()
    local need = Menu.combo.rCount:Value()
    for i = 1, EHn do
        if EHd2[i] <= R_RADIUS2 and EHnear[i] >= need then return true end
    end
    return false
end

local function RunCombo()
    local combo = Menu.combo
    local ti = S.ti

    local ally = LanternTarget()
    if ally ~= 0 then
        Pos.x, Pos.y, Pos.z = AHx[ally], S.y, AHz[ally]
        CastSpell(HK_W, Pos)
        SentTick[SW] = TICK
        return
    end

    if combo.useQ:Value() and CastQ(ti) then return end

    if combo.useE:Value() and ti ~= 0 and CastE(ti, combo.ePull:Value()) then return end

    if combo.useR:Value() and S.rR and SentTick[SR] ~= TICK and BoxWorth() then
        CastSpell(HK_R)
        SentTick[SR] = TICK
    end
end

local function RunLeap()
    if not Menu.leap.enable:Value() or not S.hooked then return false end
    if S.hpPct < Menu.leap.minHP:Value() then return false end
    if SentTick[SQ] == TICK then return false end
    if S.hookLeft > LEAP_HOLD then return false end
    CastSpell(HK_Q)
    SentTick[SQ] = TICK
    return true
end

local PC = {
    res = false, x = 810, y = 870,
    cdText = { "Q", "W", "E", "R" },
    cdReady = { false, false, false, false },
    lastCd = {}, lastLv = {},
}

local function PanelCell(i, cd, ready, lvl)
    PC.cdReady[i] = false
    if lvl == 0 then
        if PC.lastLv[i] ~= 0 then
            PC.lastLv[i] = 0
            PC.lastCd[i] = -1
            PC.cdText[i] = PANEL_NAMES[i] .. " --"
        end
        return
    end
    PC.lastLv[i] = lvl
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
    DrawText((S.hooked and "HOOKED") or "hook", 12, x + 10, y + 8, (S.hooked and COL_HOOK) or COL_OFF)
    DrawText((AHn > 0 and string_format("ALLIES %d", AHn)) or "allies 0", 12, x + 110, y + 8, COL_OFF)

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
    if draw.qRange:Value() then DrawCircle(pos, Q_RANGE - Menu.combo.qSafety:Value(), 1, COL_Q) end
    if draw.wRange:Value() then DrawCircle(pos, W_RANGE, 1, COL_W) end
    if draw.eRange:Value() then DrawCircle(pos, E_RANGE, 1, COL_E) end
    if draw.rRange:Value() then DrawCircle(pos, R_RADIUS, 1, COL_R) end
end

local function OnTick()
    if myHero.dead then return end
    TICK = TICK + 1
    InitPred()
    BuildLists()
    SyncSelf()
    SyncEnemies()
    SyncAllies()

    if GameIsChatOpen() or S.casting or myHero.isChanneling then return end

    if RunLeap() then return end
    if AutoE() then return end
    if KillSteal() then return end

    if S.mode == 1 then
        RunCombo()
    elseif S.mode == 2 then
        if Menu.combo.useQ:Value() then CastQ(S.ti) end
    end
end

local function Hook()
    local sdk = _G.SDK
    local ticks = sdk and sdk.OnTick
    local draws = sdk and sdk.OnDraw
    if type(ticks) == "table" and type(draws) == "table" then
        ticks[#ticks + 1] = OnTick
        draws[#draws + 1] = OnDraw
        return "SDK"
    end
    Callback.Add("Tick", OnTick)
    Callback.Add("Draw", OnDraw)
    return "raw"
end

local HOOK = Hook()

InitPred()
print("[" .. SCRIPT_NAME .. "] v" .. VERSION .. " loaded | pred "
    .. ((PredQ and "on") or "waiting") .. " | hook " .. HOOK)
