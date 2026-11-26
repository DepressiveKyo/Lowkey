if _G.__LOWKEY_LILLIA_LOADED then return end
_G.__LOWKEY_LILLIA_LOADED = true
if myHero.charName ~= "Lillia" then return end

local VERSION = "1.3"
local SCRIPT_NAME = "Lowkey Lillia"

local PredTries = 0

local math_sqrt = math.sqrt
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
local GameLatency = Game.Latency

local CastSpell = Control.CastSpell
local DrawCircle = Draw.Circle
local DrawText = Draw.Text
local DrawColor = Draw.Color

local SQ, SW, SE, SR = _Q, _W, _E, _R
local TEAM_ENEMY = 300 - myHero.team

local Q_OUTER = 485
local Q_INNER = 225
local Q_CAST = 0.25
local Q_BASE = { 35, 45, 55, 65, 75 }
local Q_AP = 0.35

local W_RANGE, W_RANGE2 = 500, 500 * 500
local W_INNER = 65
local W_DELAY = 0.767
local W_BASE = { 80, 100, 120, 140, 160 }
local W_AP = 0.35
local W_CBASE = { 240, 300, 360, 420, 480 }
local W_CAP = 1.05

local E_RANGE = 700
local E_RADIUS = 60
local E_DELAY = 0.4
local E_SPEED = 1400
local E_REACH = 1400
local E_BASE = { 60, 85, 110, 135, 160 }
local E_AP = 0.5

local NAME_Q = "LilliaQ"
local NAME_W = "LilliaW"
local NAME_E = "LilliaE"
local NAME_R = "LilliaR"
local BUFF_DUST = "lilliapdot"
local BUFF_PRANCE = "lilliaprancestack"
local BUFF_SLEEP = "lilliarsleep"
local DUST_LEN = #BUFF_DUST
local SLEEP_LEN = #BUFF_SLEEP
local SCAN_REACH2 = (E_REACH + 100) * (E_REACH + 100)

local SELF_CAST = {}

local COL_QIN = DrawColor(120, 255, 170, 220)
local COL_QOUT = DrawColor(255, 255, 90, 200)
local COL_W = DrawColor(150, 120, 255, 180)
local COL_E = DrawColor(150, 255, 220, 120)
local COL_DUST = DrawColor(255, 200, 120, 255)
local COL_BG = DrawColor(180, 10, 10, 15)
local COL_BORD = DrawColor(255, 200, 50, 50)
local COL_RDY = DrawColor(255, 120, 255, 120)
local COL_CD = DrawColor(255, 200, 200, 200)
local COL_OFF = DrawColor(255, 130, 130, 130)

local PANEL_NAMES = { "Q", "W", "E", "R" }

local TICK = 0

local S = {
    x = 0, y = 0, z = 0,
    ap = 0, lat = 0.03,
    qLv = 0, wLv = 0, eLv = 0, rLv = 0,
    qCd = 0, wCd = 0, eCd = 0, rCd = 0,
    qR = false, wR = false, eR = false, rR = false,
    qRaw = 0, wRaw = 0, wcRaw = 0, eRaw = 0,
    prance = 0,
    casting = false,
    mode = 0,
    ti = 0,
    dusted = 0,
    edge = 0,
    lo = 0,
    hi = 0,
}

local SentTick = {}

local EHo, EHx, EHz, EHd2 = {}, {}, {}, {}
local EHhp, EHmr = {}, {}
local EHdust, EHsleep, EHband = {}, {}, {}
local EHn = 0

local EList, EListN = {}, 0
local HeroSeen = -1

local PredW, PredE = nil, nil
local Pos = { x = 0, y = 0, z = 0 }

local Menu = MenuElement({ type = MENU, id = "LowkeyLillia", name = SCRIPT_NAME .. " v" .. VERSION })
Menu:MenuElement({ name = "info", drop = { "Blooming Blows on the outer edge" } })

Menu:MenuElement({ type = MENU, id = "edge", name = "Edge Q" })
Menu.edge:MenuElement({ id = "only", name = "Only Q on the outer edge", value = true })
Menu.edge:MenuElement({ id = "margin", name = "Band safety margin", value = 30, min = 0, max = 100, step = 5 })
Menu.edge:MenuElement({ id = "multi", name = "Q anyway if edge hits >=", value = 2, min = 1, max = 5, step = 1 })
Menu.edge:MenuElement({ id = "inner", name = "Allow inner Q to finish a kill", value = true })
Menu.edge:MenuElement({ id = "asleep", name = "Allow inner Q on sleeping targets", value = true })

Menu:MenuElement({ type = MENU, id = "pred", name = "Prediction" })
Menu.pred:MenuElement({ id = "wHit", name = "W Hit Chance", value = 2, drop = { "Normal", "High", "Immobile" } })
Menu.pred:MenuElement({ id = "eHit", name = "E Hit Chance", value = 1, drop = { "Normal", "High", "Immobile" } })

Menu:MenuElement({ type = MENU, id = "combo", name = "Combo" })
Menu.combo:MenuElement({ id = "useQ", name = "Use Q", value = true })
Menu.combo:MenuElement({ id = "useW", name = "Use W", value = true })
Menu.combo:MenuElement({ id = "wCenter", name = "Only W on the epicenter", value = true })
Menu.combo:MenuElement({ id = "useE", name = "Use E", value = true })
Menu.combo:MenuElement({ id = "eMin", name = "E only beyond", value = 450, min = 0, max = 700, step = 50 })

Menu:MenuElement({ type = MENU, id = "harass", name = "Harass" })
Menu.harass:MenuElement({ id = "useQ", name = "Use Q", value = true })
Menu.harass:MenuElement({ id = "useE", name = "Use E", value = true })

Menu:MenuElement({ type = MENU, id = "clear", name = "Clear" })
Menu.clear:MenuElement({ id = "useQ", name = "Use Q", value = true })
Menu.clear:MenuElement({ id = "qMin", name = "Q if units in band >=", value = 1, min = 1, max = 6, step = 1 })
Menu.clear:MenuElement({ id = "useW", name = "Use W", value = true })

Menu:MenuElement({ type = MENU, id = "ks", name = "Killsteal" })
Menu.ks:MenuElement({ id = "useQ", name = "Use Q", value = true })
Menu.ks:MenuElement({ id = "useW", name = "Use W", value = true })
Menu.ks:MenuElement({ id = "useE", name = "Use E", value = true })

Menu:MenuElement({ type = MENU, id = "draw", name = "Drawings" })
Menu.draw:MenuElement({ id = "enable", name = "Enable drawings", value = true })
Menu.draw:MenuElement({ id = "panel", name = "Status panel", value = true })
Menu.draw:MenuElement({ id = "qBand", name = "Q edge band", value = true })
Menu.draw:MenuElement({ id = "wRange", name = "W range", value = false })
Menu.draw:MenuElement({ id = "eRange", name = "E range", value = true })
Menu.draw:MenuElement({ id = "dust", name = "Mark dusted enemies", value = true })

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
    PredW = gg:SpellPrediction({
        Type = gg.SPELLTYPE_CIRCLE, Delay = W_DELAY, Radius = W_INNER,
        Range = W_RANGE, Speed = math_huge, Collision = false,
    })
    PredE = gg:SpellPrediction({
        Type = gg.SPELLTYPE_LINE, Delay = E_DELAY, Radius = E_RADIUS,
        Range = E_REACH, Speed = E_SPEED, Collision = false,
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

local function PredictXZ(unit, delay)
    local p = unit.pos
    local px, pz = p.x, p.z
    if delay <= 0 then return px, pz end
    local path = unit.pathing
    if not path then return px, pz end
    if path.isDashing then
        local e = path.endPos
        if e then return e.x, e.z end
        return px, pz
    end
    if not path.hasMovePath then return px, pz end
    local ms = unit.ms
    if not ms or ms <= 0 then return px, pz end
    local remain = delay
    local lx, lz = px, pz
    for i = path.pathIndex, path.pathCount do
        local node = unit:GetPath(i)
        if not node then break end
        local nx, nz = node.x, node.z
        local ax, az = nx - lx, nz - lz
        local seg = math_sqrt(ax * ax + az * az)
        if seg < 1 then
            lx, lz = nx, nz
        else
            local segTime = seg / ms
            if remain > segTime then
                remain = remain - segTime
                lx, lz = nx, nz
            else
                local t = remain / segTime
                return lx + ax * t, lz + az * t
            end
        end
    end
    return lx, lz
end

local function SyncSelf()
    local p = myHero.pos
    S.x, S.y, S.z = p.x, p.y, p.z
    S.ap = myHero.ap or 0
    S.lat = (GameLatency and GameLatency() or 30) * 0.0005

    local margin = Menu.edge.margin:Value()
    local lo = Q_INNER + margin
    local hi = Q_OUTER - margin
    if hi < lo then hi = lo end
    S.lo, S.hi = lo, hi

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
        SELF_CAST[NAME_Q] = true
        SELF_CAST[NAME_W] = true
        SELF_CAST[NAME_E] = true
        SELF_CAST[NAME_R] = true
    end

    S.casting = false
    local act = myHero.activeSpell
    if act and act.valid and not act.isStopped then
        local an = act.name
        if an and SELF_CAST[an] then S.casting = true end
    end

    S.prance = 0
    local bc = myHero.buffCount
    if bc then
        for b = 0, bc - 1 do
            local buff = myHero:GetBuff(b)
            if buff and buff.name and string_lower(buff.name) == BUFF_PRANCE then
                local c = buff.count
                if c and c > 0 then S.prance = c end
            end
        end
    end

    S.qRaw = (S.qLv > 0 and Q_BASE[S.qLv] + Q_AP * S.ap) or 0
    S.wRaw = (S.wLv > 0 and W_BASE[S.wLv] + W_AP * S.ap) or 0
    S.wcRaw = (S.wLv > 0 and W_CBASE[S.wLv] + W_CAP * S.ap) or 0
    S.eRaw = (S.eLv > 0 and E_BASE[S.eLv] + E_AP * S.ap) or 0

    S.mode = OrbMode()
end

local function SyncEnemies()
    local prev = EHn
    local n = 0
    local sx, sz = S.x, S.z
    local lead = Q_CAST + S.lat
    local lo2, hi2 = S.lo * S.lo, S.hi * S.hi

    local tgt = nil
    local sdk = _G.SDK
    if sdk and sdk.TargetSelector then
        local t = sdk.TargetSelector:GetTarget(E_RANGE)
        if t and t.team == TEAM_ENEMY and IsValidUnit(t) then tgt = t end
    end
    local tgtId = tgt and tgt.networkID
    local ti = 0
    local dusted, edge = 0, 0

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

            local qx, qz = PredictXZ(h, lead)
            local ax, az = qx - sx, qz - sz
            local pd2 = ax * ax + az * az

            local band = 0
            if pd2 <= hi2 then
                band = (pd2 >= lo2 and 2) or 1
            end
            EHband[n] = band
            if band == 2 then edge = edge + 1 end

            local dust, sleep = false, false
            if EHd2[n] <= SCAN_REACH2 then
                local bc = h.buffCount
                if bc then
                    for b = 0, bc - 1 do
                        local buff = h:GetBuff(b)
                        if buff and buff.count and buff.count > 0 then
                            local nm = buff.name
                            local ln = nm and #nm
                            if ln == DUST_LEN or ln == SLEEP_LEN then
                                local bn = string_lower(nm)
                                if bn == BUFF_DUST then
                                    dust = true
                                    if sleep then break end
                                elseif bn == BUFF_SLEEP then
                                    sleep = true
                                    if dust then break end
                                end
                            end
                        end
                    end
                end
            end
            EHdust[n] = dust
            EHsleep[n] = sleep
            if dust then dusted = dusted + 1 end

            if tgtId and h.networkID == tgtId then ti = n end
        end
    end

    for i = n + 1, prev do EHo[i] = nil end
    EHn = n
    S.ti = ti
    S.dusted = dusted
    S.edge = edge
end

local function QDamage(i, edge)
    local mul = MagicMul(EHmr[i])
    if edge then return S.qRaw * mul + S.qRaw end
    return S.qRaw * mul
end

local function WDamage(i, center)
    local raw = (center and S.wcRaw) or S.wRaw
    return raw * MagicMul(EHmr[i])
end

local function EDamage(i) return S.eRaw * MagicMul(EHmr[i]) end

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

local function QReady()
    return S.qR and not S.casting and SentTick[SQ] ~= TICK
end

local function EdgeQ(i)
    if not QReady() then return false end
    local node = Menu.edge
    if i ~= 0 then
        local band = EHband[i]
        if band == 2 then return SendSelf(HK_Q, SQ) end
        if band == 1 then
            if not node.only:Value() then return SendSelf(HK_Q, SQ) end
            if node.asleep:Value() and EHsleep[i] then return SendSelf(HK_Q, SQ) end
            if node.inner:Value() and QDamage(i, false) >= EHhp[i] then
                return SendSelf(HK_Q, SQ)
            end
        end
    end
    if S.edge >= node.multi:Value() then return SendSelf(HK_Q, SQ) end
    return false
end

local function CastW(i)
    if not S.wR or S.casting or SentTick[SW] == TICK then return false end
    if i == 0 or EHd2[i] > W_RANGE2 then return false end
    local x, z = PredictAt(PredW, i, HitOf(Menu.pred.wHit:Value()), W_RANGE2)
    if x then return Send(HK_W, SW, x, z) end
    if Menu.combo.wCenter:Value() then return false end
    return Send(HK_W, SW, EHx[i], EHz[i])
end

local function CastE(i)
    if not S.eR or S.casting or SentTick[SE] == TICK then return false end
    if i == 0 then return false end
    local x, z = PredictAt(PredE, i, HitOf(Menu.pred.eHit:Value()), nil)
    if not x then return false end
    local dx, dz = x - S.x, z - S.z
    local len = math_sqrt(dx * dx + dz * dz)
    if len < 1 then return false end
    if len > E_RANGE then
        local k = E_RANGE / len
        x, z = S.x + dx * k, S.z + dz * k
    end
    return Send(HK_E, SE, x, z)
end

local function KillSteal()
    local node = Menu.ks
    for i = 1, EHn do
        local hp = EHhp[i]
        local band = EHband[i]
        if node.useQ:Value() and band ~= 0 and QReady() then
            if QDamage(i, band == 2) >= hp and SendSelf(HK_Q, SQ) then return true end
        end
        if node.useE:Value() and S.eR and EDamage(i) >= hp then
            if CastE(i) then return true end
        end
        if node.useW:Value() and S.wR and EHd2[i] <= W_RANGE2 then
            if WDamage(i, true) >= hp and CastW(i) then return true end
        end
    end
    return false
end

local function RunCombo()
    local node = Menu.combo
    local i = S.ti
    if node.useQ:Value() and EdgeQ(i) then return end
    if i == 0 then return end
    if node.useW:Value() and CastW(i) then return end
    if node.useE:Value() then
        local reach = node.eMin:Value()
        if EHd2[i] >= reach * reach and CastE(i) then return end
    end
end

local function RunHarass()
    local node = Menu.harass
    local i = S.ti
    if node.useQ:Value() and EdgeQ(i) then return end
    if i == 0 then return end
    if node.useE:Value() and CastE(i) then return end
end

local function BandCount(list, lo2, hi2)
    local hits = 0
    if not list then return 0 end
    for k = 1, #list do
        local m = list[k]
        if m and m.valid and not m.dead then
            local p = m.pos
            local dx, dz = p.x - S.x, p.z - S.z
            local d2 = dx * dx + dz * dz
            if d2 >= lo2 and d2 <= hi2 then hits = hits + 1 end
        end
    end
    return hits
end

local function RunClear()
    local node = Menu.clear
    local sdk = _G.SDK
    local om = sdk and sdk.ObjectManager
    if not om then return end

    if node.useQ:Value() and QReady() then
        local lo2, hi2 = S.lo * S.lo, S.hi * S.hi
        local hits = BandCount(om:GetEnemyMinions(Q_OUTER), lo2, hi2)
        if om.GetMonsters then
            hits = hits + BandCount(om:GetMonsters(Q_OUTER), lo2, hi2)
        end
        if hits >= node.qMin:Value() and SendSelf(HK_Q, SQ) then return end
    end

    if node.useW:Value() and S.wR and not S.casting and SentTick[SW] ~= TICK then
        local best, bx, bz = 0, nil, nil
        if om.GetMonsters then
            local mobs = om:GetMonsters(W_RANGE)
            if mobs then
                for k = 1, #mobs do
                    local m = mobs[k]
                    if m and m.valid and not m.dead then
                        local hp = m.maxHealth or 0
                        if hp > best then
                            local p = m.pos
                            best, bx, bz = hp, p.x, p.z
                        end
                    end
                end
            end
        end
        if bx and Send(HK_W, SW, bx, bz) then return end
        local minions = om:GetEnemyMinions(W_RANGE)
        if minions then
            local cx, cz, c = 0, 0, 0
            for k = 1, #minions do
                local m = minions[k]
                if m and m.valid and not m.dead then
                    local p = m.pos
                    cx, cz, c = cx + p.x, cz + p.z, c + 1
                end
            end
            if c >= 3 and Send(HK_W, SW, cx / c, cz / c) then return end
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
    DrawText((S.edge > 0 and string_format("EDGE %d", S.edge)) or "edge 0", 12, x + 10, y + 8,
        (S.edge > 0 and COL_QOUT) or COL_OFF)
    DrawText((S.dusted > 0 and string_format("DUST %d", S.dusted)) or "dust 0", 12, x + 110, y + 8,
        (S.dusted > 0 and COL_DUST) or COL_OFF)
    DrawText(string_format("MS %d", S.prance), 12, x + 210, y + 8,
        (S.prance > 0 and COL_RDY) or COL_OFF)

    for i = 1, 4 do
        DrawText(PC.cdText[i], 12, x + 10 + (i - 1) * 72, y + 32, (PC.cdReady[i] and COL_RDY) or COL_CD)
    end
end

local function OnDraw()
    local node = Menu.draw
    if myHero.dead or not node.enable:Value() then return end
    if node.panel:Value() then DrawPanel() end
    if not myHero.visible then return end
    local pos = myHero.pos
    if node.qBand:Value() then
        DrawCircle(pos, S.lo, 1, COL_QIN)
        DrawCircle(pos, S.hi, 2, COL_QOUT)
    end
    if node.wRange:Value() then DrawCircle(pos, W_RANGE, 1, COL_W) end
    if node.eRange:Value() then DrawCircle(pos, E_RANGE, 1, COL_E) end
    if node.dust:Value() then
        for i = 1, EHn do
            if EHdust[i] then
                local p2 = EHo[i].pos2D
                if p2 and p2.onScreen then
                    DrawText("DUST", 16, p2.x - 16, p2.y - 32, COL_DUST)
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
    if S.casting or myHero.isChanneling then return end

    if KillSteal() then return end

    if S.mode == 1 then
        RunCombo()
    elseif S.mode == 2 then
        RunHarass()
    elseif S.mode == 3 then
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
