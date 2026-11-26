local __version__ = 1.0
local __name__ = "LowkeyOrbwalker"

if _G.__LOWKEY_ORBWALKER then return end
if _G.SDK then
    print("[LowkeyOrbwalker] an SDK is already registered, aborting load")
    return
end
_G.__LOWKEY_ORBWALKER = true

local HUGE = math.huge
local PI = math.pi
local sqrt = math.sqrt
local floor = math.floor
local format = string.format
local concat = table.concat
local ceil = math.ceil
local atan = math.atan

local myHero = myHero
local Game = Game
local Draw = Draw
local Control = Control
local Vector = Vector
local Callback = Callback
local pairs = pairs
local type = type
local pcall = pcall
local print = print
local tostring = tostring

local Timer = Game.Timer
local Latency = Game.Latency
local ChatOpen = Game.IsChatOpen
local OnTop = Game.IsOnTop
local Resolution = Game.Resolution
local CursorPos = Game.cursorPos
local MousePos = Game.mousePos
local HeroCount = Game.HeroCount
local HeroAt = Game.Hero
local MinionCount = Game.MinionCount
local MinionAt = Game.Minion
local TurretCount = Game.TurretCount
local TurretAt = Game.Turret
local WardCount = Game.WardCount
local WardAt = Game.Ward
local ObjectCount = Game.ObjectCount
local ObjectAt = Game.Object

local MODE_NONE = -1
local MODE_COMBO = 0
local MODE_HARASS = 1
local MODE_LANECLEAR = 2
local MODE_JUNGLECLEAR = 3
local MODE_LASTHIT = 4
local MODE_FLEE = 5

local DMG_PHYSICAL = 0
local DMG_MAGICAL = 1
local DMG_TRUE = 2

local PICK_AUTO = 1
local PICK_CLOSEST = 2
local PICK_MOUSE = 3
local PICK_LOWHP = 4
local PICK_LOWMAXHP = 5
local PICK_PRIORITY = 6
local PICK_MOSTAD = 7
local PICK_MOSTAP = 8

local SCAN_RANGE = 2000
local SCAN_RANGE2 = SCAN_RANGE * SCAN_RANGE
local MELEE_CUT = 300
local DEFAULT_WINDUP_RATIO = 0.25
local DEFAULT_BASE_AS = 0.625
local MAX_PREDICT_HITS = 8
local ACK_TOLERANCE2 = 10000
local POST_WINDOW = 1.0
local BUFF_PRUNE_MASK = 255
local BUFF_PRUNE_AGE = 400
local BUILDING_RETRY_MASK = 31

local MY_TEAM = myHero.team
local ENEMY_TEAM = 300 - MY_TEAM
local JUNGLE_TEAM = 300
local MY_NAME = myHero.charName

local ITEM_SLOTS = { ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7 }

local MINION_RANGE = {
    ["SRU_ChaosMinionMelee"] = 110,
    ["SRU_ChaosMinionRanged"] = 550,
    ["SRU_ChaosMinionSiege"] = 300,
    ["SRU_ChaosMinionSuper"] = 170,
    ["SRU_OrderMinionMelee"] = 110,
    ["SRU_OrderMinionRanged"] = 550,
    ["SRU_OrderMinionSiege"] = 300,
    ["SRU_OrderMinionSuper"] = 170,
    ["HA_ChaosMinionMelee"] = 110,
    ["HA_ChaosMinionRanged"] = 550,
    ["HA_ChaosMinionSiege"] = 300,
    ["HA_ChaosMinionSuper"] = 170,
    ["HA_OrderMinionMelee"] = 110,
    ["HA_OrderMinionRanged"] = 550,
    ["HA_OrderMinionSiege"] = 300,
    ["HA_OrderMinionSuper"] = 170,
}

local CRIT_BASE = {
    ["Ashe"] = 1.0,
    ["Jhin"] = 1.5,
    ["Senna"] = 1.6,
    ["Yasuo"] = 1.9,
    ["Yone"] = 1.9,
}

local BLOCK_MOVE_TYPES = {
    [5] = true, [8] = true, [9] = true, [12] = true, [23] = true,
    [25] = true, [29] = true, [30] = true, [31] = true, [35] = true,
}

local BLOCK_ATTACK_TYPES = {
    [5] = true, [8] = true, [9] = true, [23] = true, [25] = true,
    [26] = true, [29] = true, [30] = true, [31] = true, [32] = true, [35] = true,
}

local NOT_ATTACK = {
    ["JarvanIVDragonStrike"] = true,
    ["MonkeyKingDoubleAttack"] = true,
    ["XinZhaoQ"] = true,
    ["ViQ"] = true,
    ["RengarQ"] = true,
    ["NasusQ"] = true,
    ["GarenQ"] = true,
    ["TrundleQ"] = true,
    ["WarwickQ"] = true,
}

local IS_ATTACK = {
    ["CaitlynHeadshotMissile"] = true,
    ["CaitlynPassiveMissile"] = true,
    ["JhinPassiveAttack"] = true,
    ["KalistaBasicAttack"] = true,
    ["ApheliosCrescendumAttack"] = true,
    ["ApheliosSeverumAttack"] = true,
    ["ApheliosGravitumAttack"] = true,
    ["ApheliosInfernumAttack"] = true,
    ["ApheliosCalibrumAttack"] = true,
    ["ZeriQ"] = true,
    ["ZeriW"] = true,
}

local ModeState = {
    [MODE_COMBO] = false,
    [MODE_HARASS] = false,
    [MODE_LANECLEAR] = false,
    [MODE_JUNGLECLEAR] = false,
    [MODE_LASTHIT] = false,
    [MODE_FLEE] = false,
}

local function Pos2(u)
    local p = u.pos or u
    return p.x, (p.z or p.y)
end

local function DistSq(a, b)
    local ax, az = Pos2(a)
    local bx, bz = Pos2(b)
    local dx, dz = ax - bx, az - bz
    return dx * dx + dz * dz
end

local function Dist(a, b)
    return sqrt(DistSq(a, b))
end

local function Within(a, b, r)
    return DistSq(a, b) <= r * r
end

local function Polar(v)
    local x = v.x
    local z = v.z or v.y
    if x == 0 then
        if z > 0 then return 90 end
        if z < 0 then return 270 end
        return 0
    end
    local t = atan(z / x) * (180 / PI)
    if x < 0 then t = t + 180 end
    if t < 0 then t = t + 360 end
    return t
end

local function AngleGap(a, b)
    local t = Polar(a) - Polar(b)
    if t < 0 then t = t + 360 end
    if t > 180 then t = 360 - t end
    return t
end

local function Facing(src, dst, angle)
    local d = src.dir
    if not d then return true end
    local sp = src.pos
    local p = dst.pos or dst
    return AngleGap(d, { x = p.x - sp.x, z = (p.z or p.y) - (sp.z or sp.y) }) < (angle or 90)
end

local function Trim(t, keep, high)
    for i = high, keep + 1, -1 do
        t[i] = nil
    end
end

local function Alive(u)
    return (u and u.valid and u.visible and u.isTargetable and not u.dead) and true or false
end

local function Attackable(u)
    return (u and u.valid and u.visible and u.isTargetable and not u.dead and not u.isImmortal) and true or false
end

local function OnScreen(u)
    local p = u.pos2D
    return p ~= nil and p.onScreen == true
end

local ScreenW, ScreenH = 0, 0

local function Screen()
    if ScreenW > 0 then return ScreenW, ScreenH end
    local res = Resolution and Resolution()
    if res and res.x and res.y and res.x > 0 then
        ScreenW, ScreenH = res.x, res.y
    end
    return ScreenW, ScreenH
end

local function IsEnemyUnit(u) return u.isEnemy end
local function IsAllyUnit(u) return u.isAlly end
local function IsNotTurret(u) return u.type ~= Obj_AI_Turret end

local Menu = {}

local function BuildMenu()
    local root = MenuElement({ id = "LowkeyOrbwalker", name = "Lowkey Orbwalker", type = MENU })
    Menu.root = root

    root:MenuElement({ id = "enabled", name = "Enabled", value = true })

    root:MenuElement({ id = "keys", name = "Keys", type = MENU })
    Menu.keys = root.keys
    root.keys:MenuElement({ id = "combo", name = "Combo", key = string.byte(" ") })
    root.keys:MenuElement({ id = "harass", name = "Harass", key = string.byte("C") })
    root.keys:MenuElement({ id = "lasthit", name = "Last Hit", key = string.byte("X") })
    root.keys:MenuElement({ id = "laneclear", name = "Lane Clear", key = string.byte("V") })
    root.keys:MenuElement({ id = "jungle", name = "Jungle Clear", key = string.byte("V") })
    root.keys:MenuElement({ id = "flee", name = "Flee", key = string.byte("A") })

    root:MenuElement({ id = "walk", name = "Walker", type = MENU })
    Menu.walk = root.walk
    root.walk:MenuElement({ id = "attack", name = "Attacks enabled", value = true })
    root.walk:MenuElement({ id = "move", name = "Movement enabled", value = true })
    root.walk:MenuElement({ id = "reset", name = "Honour attack resets", value = true })
    root.walk:MenuElement({ id = "safety", name = "Range safety margin", value = 25, min = 0, max = 60, step = 1 })
    root.walk:MenuElement({ id = "windup", name = "Windup bias [ms]", value = 0, min = -30, max = 80, step = 5 })
    root.walk:MenuElement({ id = "spacing", name = "Move order spacing", value = 180, min = 0, max = 400, step = 10 })
    root.walk:MenuElement({ id = "hold", name = "Hold radius", value = 90, min = 0, max = 300, step = 10 })
    root.walk:MenuElement({ id = "confirm", name = "Click confirm frames", value = 2, min = 1, max = 5, step = 1 })
    root.walk:MenuElement({ id = "tco", name = "Hold target-champions-only in combo", value = true })

    root:MenuElement({ id = "farm", name = "Farming", type = MENU })
    Menu.farm = root.farm
    root.farm:MenuElement({ id = "delay", name = "Farm delay [ms]", value = 0, min = -80, max = 80, step = 5 })
    root.farm:MenuElement({ id = "lastHitFirst", name = "Last hit before harass", value = true })
    root.farm:MenuElement({ id = "clearHeroes", name = "Hit heroes while clearing", value = true })
    root.farm:MenuElement({ id = "harassFarm", name = "Farm in harass mode", value = true })
    root.farm:MenuElement({ id = "wards", name = "Attack wards", value = true })
    root.farm:MenuElement({ id = "structures", name = "Attack structures", value = true })

    root:MenuElement({ id = "target", name = "Target Selector", type = MENU })
    Menu.target = root.target
    root.target:MenuElement({
        id = "mode" .. MY_NAME,
        name = "Mode",
        value = 1,
        drop = { "Auto", "Closest", "Near Mouse", "Lowest HP", "Lowest MaxHP", "Priority", "Most AD", "Most AP" },
    })
    root.target:MenuElement({ id = "sticky", name = "Stick to clicked target", value = true })
    root.target:MenuElement({ id = "stickyOnly", name = "Clicked target only", value = false })
    root.target:MenuElement({ id = "prio", name = "Priorities", type = MENU })
    Menu.prio = root.target.prio

    root:MenuElement({ id = "draws", name = "Drawings", type = MENU })
    Menu.draws = root.draws
    root.draws:MenuElement({ id = "enabled", name = "Enabled", value = true })
    root.draws:MenuElement({ id = "range", name = "My attack range", value = true })
    root.draws:MenuElement({ id = "enemyRange", name = "Enemy attack range", value = false })
    root.draws:MenuElement({ id = "hold", name = "Hold radius", value = false })
    root.draws:MenuElement({ id = "farm", name = "Last hittable minions", value = true })
    root.draws:MenuElement({ id = "selected", name = "Clicked target", value = true })
    root.draws:MenuElement({ id = "cursor", name = "Cursor", value = false })
    root.draws:MenuElement({ id = "mode", name = "Active mode", value = true })
    root.draws:MenuElement({ id = "profile", name = "Frame cost (ms per section)", value = false })

    root:MenuElement({ name = "", type = SPACE, id = "gap" })
    root:MenuElement({
        id = "attackKey",
        name = "In-game attack-target key",
        key = string.byte("U"),
        tooltip = "Must match your League keybind",
    })
    root:MenuElement({ id = "ping", name = "Fallback ping [ms]", value = 45, min = 0, max = 150, step = 1 })
    root:MenuElement({ name = "version " .. __version__, type = SPACE, id = "ver" })
end

BuildMenu()

local Palette = {
    range = Draw.Color(190, 120, 220, 255),
    enemyRange = Draw.Color(190, 255, 110, 110),
    hold = Draw.Color(160, 150, 240, 170),
    killable = Draw.Color(255, 120, 255, 140),
    nearly = Draw.Color(255, 255, 215, 110),
    selected = Draw.Color(255, 255, 90, 90),
    cursor = Draw.Color(140, 140, 200, 255),
    text = Draw.Color(255, 230, 235, 245),
    dim = Draw.Color(255, 120, 130, 145),
}

local Frame = { n = 0, draw = 0 }

local CLOCK = os and os.clock
local PROF_WINDOW = 256
local PROF_KEYS = { "world", "select", "farm", "champT", "input", "walk", "ownD", "champD" }
local PROF_N = 8
local Prof = { frames = 0, text = "profile warming up" }
for i = 1, PROF_N do Prof[PROF_KEYS[i]] = 0 end

local function ProfOn()
    return CLOCK ~= nil and Menu.draws ~= nil and Menu.draws.profile:Value() == true
end

local function ProfAdd(key, started)
    Prof[key] = Prof[key] + (CLOCK() - started)
end

local function ProfRoll(counts)
    Prof.frames = Prof.frames + 1
    if Prof.frames < PROF_WINDOW then return end
    local total = 0
    local parts = Prof.parts
    if not parts then
        parts = {}
        Prof.parts = parts
    end
    for i = 1, PROF_N do
        local key = PROF_KEYS[i]
        local ms = Prof[key] * 1000 / Prof.frames
        total = total + ms
        parts[i] = format("%s %.2f", key, ms)
        Prof[key] = 0
    end
    Prof.text = format("frame %.2fms | %s", total, concat(parts, "  "))
    Prof.frames = 0
    local lk = _G.Lowkey
    if lk and lk.Log then
        lk:Log("perf", (counts and (Prof.text .. " | " .. counts)) or Prof.text)
    end
end

local Net = { ms = 45, s = 0.045, half = 0.0225, grace = 0.14 }

function Net:Refresh()
    local raw = Latency()
    if not raw or raw <= 0 or raw >= 250 then
        raw = Menu.root.ping:Value()
    end
    self.ms = raw
    self.s = raw * 0.001
    self.half = self.s * 0.5
    self.grace = self.s * 2 + 0.05
    _G.LATENCY = raw
end

Net:Refresh()

local Hooks = {
    BaseRange = nil,
    ExtraRange = nil,
    InRange = nil,
    MissileSpeed = nil,
    Windup = nil,
    Animation = nil,
    Melee = nil,
    Channeling = nil,
    AllowMoveWhileChanneling = nil,
    BlockAttack = nil,
    BlockMove = nil,
    ForceMove = nil,
    AttackReset = nil,
    PriorityTarget = nil,
    StaticDamage = nil,
    BonusAutoAttackDamage = nil,
    Untargetable = nil,
}

local Buffs = { store = {}, pruneFrame = -1 }

function Buffs:Prune()
    local store = self.store
    local cut = Frame.n - BUFF_PRUNE_AGE
    for id, e in pairs(store) do
        if e.stamp < cut then store[id] = nil end
    end
end

function Buffs:Entry(u)
    if not u or not u.valid then return nil end
    local id = u.networkID
    if not id then return nil end
    local e = self.store[id]
    if not e then
        e = { stamp = -1, list = {}, map = {}, n = 0 }
        self.store[id] = e
    elseif e.stamp == Frame.n then
        return e
    end
    e.stamp = Frame.n
    local list, map = e.list, e.map
    for k in pairs(map) do map[k] = nil end
    local n = 0
    local total = u.buffCount
    if total and total > 0 and total < 512 then
        for i = 0, total do
            local b = u:GetBuff(i)
            if b and b.count and b.count > 0 and b.name then
                local raw = b.name
                local key = raw:lower()
                n = n + 1
                local rec = list[n]
                if not rec then
                    rec = {}
                    list[n] = rec
                end
                rec.name = raw
                rec.key = key
                rec.count = b.count
                rec.stacks = b.stacks
                rec.duration = b.duration
                rec.type = b.type
                rec.startTime = b.startTime
                rec.expireTime = b.expireTime
                map[key] = rec
            end
        end
    end
    Trim(list, n, e.n)
    e.n = n
    return e
end

function Buffs:Has(u, name)
    local e = self:Entry(u)
    if not e then return false end
    return e.map[name:lower()] ~= nil
end

function Buffs:Get(u, name)
    local e = self:Entry(u)
    if not e then return nil end
    return e.map[name:lower()]
end

function Buffs:Duration(u, name)
    local b = self:Get(u, name)
    if not b then return 0 end
    return b.duration or 0
end

function Buffs:List(u)
    local e = self:Entry(u)
    if not e then return {}, 0 end
    return e.list, e.n
end

function Buffs:AnyType(u, types)
    local e = self:Entry(u)
    if not e then return false end
    local list = e.list
    for i = 1, e.n do
        local t = list[i].type
        if t and types[t] then return true end
    end
    return false
end

local function Shield(u)
    return (u.shieldAD or 0) + (u.shieldAP or 0)
end

local function TurretPen(u)
    local n = u.charName
    if n and n:find("Shrine", 1, true) then return 0.75 end
    return 0.3
end

local function Mitigation(src, tgt, kind)
    if kind == DMG_TRUE then return 1 end
    local base, bonus, flat, pct, bpct
    if kind == DMG_MAGICAL then
        bonus = tgt.bonusMagicResist or 0
        base = (tgt.magicResist or 0) - bonus
        flat = src.magicPen or 0
        pct = src.magicPenPercent or 1
        bpct = 1
    else
        bonus = tgt.bonusArmor or 0
        base = (tgt.armor or 0) - bonus
        flat = src.armorPen or 0
        pct = src.armorPenPercent or 1
        bpct = src.bonusArmorPenPercent or 1
    end
    if base < 0 then base = 0 end
    local st = src.type
    if st == Obj_AI_Minion then
        flat, pct, bpct = 0, 1, 1
    elseif st == Obj_AI_Turret then
        flat, pct, bpct = 0, TurretPen(src), 1
    end
    local res = base + bonus
    if res > 0 then
        res = base * pct + bonus * pct * bpct - flat
    end
    if res >= 0 then return 100 / (100 + res) end
    return 2 - 100 / (100 - res)
end

local Combat = {}

function Combat:CalculateDamage(from, target, kind, raw, isAbility, isTargeted)
    if not from or not target or not raw then return 0 end
    if kind == DMG_TRUE then return raw end
    if isAbility == nil then isAbility = true end
    local out = raw * Mitigation(from, target, kind)
    local targetIsMinion = target.type == Obj_AI_Minion
    if from.type == Obj_AI_Minion and targetIsMinion then
        out = out * (1 + (from.bonusDamagePercent or 0))
    end
    if not isAbility and targetIsMinion then
        out = out - (target.flatDamageReduction or 0)
    end
    if out < 0 then return 0 end
    return out
end

function Combat:CritMultiplier(from)
    local base = CRIT_BASE[from.charName] or 2.0
    if base < 2.0 then return base end
    for i = 1, 7 do
        local ok, data = pcall(from.GetItemData, from, ITEM_SLOTS[i])
        if ok and data then
            local id = data.itemID
            if id == 773031 then return 2.5 end
            if id == 3031 then return 2.3 end
        end
    end
    return base
end

function Combat:GetStaticAutoAttackDamage(from, targetIsMinion)
    local args = {
        From = from,
        RawTotal = from.totalDamage or 0,
        RawPhysical = 0,
        RawMagical = 0,
        CalculatedTrue = 0,
        CalculatedPhysical = 0,
        CalculatedMagical = 0,
        DamageType = DMG_PHYSICAL,
        TargetIsMinion = targetIsMinion,
    }
    local hook = Hooks.StaticDamage
    if hook then hook(args) end
    return args
end

function Combat:GetAutoAttackDamage(from, target, respectPassives, static)
    if not from or not target then return 0 end
    local targetIsMinion = target.type == Obj_AI_Minion
    if targetIsMinion and (target.maxHealth or 0) <= 6 then return 1 end
    local raw = (static and static.RawTotal) or (from.totalDamage or 0)
    local extraPhys = (static and static.RawPhysical) or 0
    local extraMagic = (static and static.RawMagical) or 0
    local extraTrue = (static and static.CalculatedTrue) or 0
    if from.type == Obj_AI_Hero and respectPassives ~= false then
        if (from.critChance or 0) >= 1 then
            raw = raw * self:CritMultiplier(from)
        end
        local hook = Hooks.BonusAutoAttackDamage
        if hook then
            local p, m, t = hook(from, target, raw)
            extraPhys = extraPhys + (p or 0)
            extraMagic = extraMagic + (m or 0)
            extraTrue = extraTrue + (t or 0)
        end
    end
    local out = extraTrue
    local phys = raw + extraPhys
    if phys > 0 then
        out = out + self:CalculateDamage(from, target, DMG_PHYSICAL, phys, false, true)
    end
    if extraMagic > 0 then
        out = out + self:CalculateDamage(from, target, DMG_MAGICAL, extraMagic, false, true)
    end
    return out
end

local World = {
    frame = -1,
    heroN = 0, hero = {},
    enemyN = 0, enemy = {},
    allyN = 0, ally = {},
    laneN = 0, lane = {},
    jungleN = 0, jungle = {},
    allyMinN = 0, allyMin = {},
    wardN = 0, ward = {},
    turretN = 0, turret = {},
    structN = 0, struct = {},
    allyTurret = nil,
    allyTurretHandle = nil,
    handleN = 0, handleKeys = {}, handleMap = {},
    seen = {},
    enemyCb = {},
    allyCb = {},
    highHero = 0, highEnemy = 0, highAlly = 0, highLane = 0,
    highJungle = 0, highAllyMin = 0, highWard = 0, highTurret = 0, highStruct = 0,
    buildings = {}, buildingN = 0, buildingDone = false,
}

function World:HeroArgs(u)
    return {
        valid = true,
        unit = u,
        charName = u.charName,
        networkID = u.networkID,
        team = u.team,
        isEnemy = u.isEnemy,
        isAlly = u.isAlly,
    }
end

function World:OnEnemyHeroLoad(cb)
    self.enemyCb[#self.enemyCb + 1] = cb
    for i = 1, self.enemyN do
        cb(self:HeroArgs(self.enemy[i]))
    end
end

function World:OnAllyHeroLoad(cb)
    self.allyCb[#self.allyCb + 1] = cb
    for i = 1, self.allyN do
        cb(self:HeroArgs(self.ally[i]))
    end
end

function World:Announce(u)
    local id = u.networkID
    if not id or self.seen[id] then return end
    local name = u.charName
    if not name then return end
    local team = u.team
    if not team or team < 100 or team > 200 then return end
    if u.isEnemy == u.isAlly then return end
    self.seen[id] = true
    local args = self:HeroArgs(u)
    local list = u.isEnemy and self.enemyCb or self.allyCb
    for i = 1, #list do
        list[i](args)
    end
end

function World:ScanBuildings()
    if self.buildingDone then return end
    if Frame.n % BUILDING_RETRY_MASK ~= 1 then return end
    local total = ObjectCount()
    if not total or total <= 0 or total > 100000 then return end
    local n = 0
    local out = self.buildings
    for i = 1, total do
        local o = ObjectAt(i)
        if o then
            local t = o.type
            if t == Obj_AI_Barracks or t == Obj_AI_Nexus then
                n = n + 1
                out[n] = o
            end
        end
    end
    Trim(out, n, self.buildingN)
    self.buildingN = n
    if n > 0 then self.buildingDone = true end
end

function World:Refresh()
    if self.frame == Frame.n then return end
    self.frame = Frame.n

    local mx, mz = Pos2(myHero)
    local heroN, enemyN, allyN = 0, 0, 0
    local hero, enemy, ally = self.hero, self.enemy, self.ally

    local hc = HeroCount()
    if hc and hc > 0 and hc < 64 then
        for i = 1, hc do
            local u = HeroAt(i)
            if u and u.valid then
                self:Announce(u)
                if u.visible and u.isTargetable and not u.dead then
                    heroN = heroN + 1
                    hero[heroN] = u
                    if u.isEnemy then
                        enemyN = enemyN + 1
                        enemy[enemyN] = u
                    elseif u.isAlly then
                        allyN = allyN + 1
                        ally[allyN] = u
                    end
                end
            end
        end
    end
    Trim(hero, heroN, self.highHero)
    Trim(enemy, enemyN, self.highEnemy)
    Trim(ally, allyN, self.highAlly)
    self.highHero, self.highEnemy, self.highAlly = heroN, enemyN, allyN
    self.heroN, self.enemyN, self.allyN = heroN, enemyN, allyN

    local laneN, jungleN, allyMinN = 0, 0, 0
    local lane, jungle, allyMin = self.lane, self.jungle, self.allyMin
    local handleN = 0
    local handleKeys, handleMap = self.handleKeys, self.handleMap
    for k in pairs(handleMap) do handleMap[k] = nil end

    local mc = MinionCount()
    if mc and mc > 0 and mc < 1000 then
        for i = 1, mc do
            local u = MinionAt(i)
            if u and u.valid and u.visible and u.isTargetable and not u.dead and not u.isImmortal then
                local x, z = Pos2(u)
                local dx, dz = x - mx, z - mz
                if dx * dx + dz * dz <= SCAN_RANGE2 then
                    local team = u.team
                    handleN = handleN + 1
                    local h = u.handle
                    handleKeys[handleN] = h
                    handleMap[h] = u
                    if team == ENEMY_TEAM then
                        laneN = laneN + 1
                        lane[laneN] = u
                    elseif team == JUNGLE_TEAM then
                        jungleN = jungleN + 1
                        jungle[jungleN] = u
                    elseif team == MY_TEAM then
                        allyMinN = allyMinN + 1
                        allyMin[allyMinN] = u
                    end
                end
            end
        end
    end
    Trim(lane, laneN, self.highLane)
    Trim(jungle, jungleN, self.highJungle)
    Trim(allyMin, allyMinN, self.highAllyMin)
    self.highLane, self.highJungle, self.highAllyMin = laneN, jungleN, allyMinN
    self.laneN, self.jungleN, self.allyMinN = laneN, jungleN, allyMinN

    local wardN = 0
    local ward = self.ward
    if Menu.farm.wards:Value() then
        local wc = WardCount()
        if wc and wc > 0 and wc < 500 then
            for i = 1, wc do
                local u = WardAt(i)
                if u and u.isEnemy and Attackable(u) then
                    local x, z = Pos2(u)
                    local dx, dz = x - mx, z - mz
                    if dx * dx + dz * dz <= SCAN_RANGE2 then
                        wardN = wardN + 1
                        ward[wardN] = u
                    end
                end
            end
        end
    end
    Trim(ward, wardN, self.highWard)
    self.highWard = wardN
    self.wardN = wardN

    local turretN, structN = 0, 0
    local turret, struct = self.turret, self.struct
    self.allyTurret, self.allyTurretHandle = nil, nil
    local tc = TurretCount()
    if tc and tc > 0 and tc < 200 then
        for i = 1, tc do
            local u = TurretAt(i)
            if u and Attackable(u) then
                local x, z = Pos2(u)
                local dx, dz = x - mx, z - mz
                if dx * dx + dz * dz <= SCAN_RANGE2 then
                    turretN = turretN + 1
                    turret[turretN] = u
                    local h = u.handle
                    handleN = handleN + 1
                    handleKeys[handleN] = h
                    handleMap[h] = u
                    if u.isEnemy then
                        structN = structN + 1
                        struct[structN] = u
                    elseif self.allyTurret == nil then
                        self.allyTurret = u
                        self.allyTurretHandle = h
                    end
                end
            end
        end
    end

    self:ScanBuildings()
    for i = 1, self.buildingN do
        local u = self.buildings[i]
        if u and u.isEnemy and Attackable(u) then
            local x, z = Pos2(u)
            local dx, dz = x - mx, z - mz
            if dx * dx + dz * dz <= SCAN_RANGE2 then
                structN = structN + 1
                struct[structN] = u
            end
        end
    end

    Trim(turret, turretN, self.highTurret)
    Trim(struct, structN, self.highStruct)
    self.highTurret, self.highStruct = turretN, structN
    self.turretN, self.structN = turretN, structN
    self.handleN = handleN

    if Frame.n % BUFF_PRUNE_MASK == 0 then
        Buffs:Prune()
    end
end

function World:Collect(src, n, filter, range, bbox)
    local out = {}
    local k = 0
    local r2 = range and range * range or nil
    for i = 1, n do
        local u = src[i]
        if u and u.valid then
            local ok = true
            if filter then ok = filter(u) end
            if ok and r2 then
                local extra = bbox and (u.boundingRadius or 0) or 0
                if extra > 0 then
                    local lim = range + extra
                    ok = DistSq(u, myHero) <= lim * lim
                else
                    ok = DistSq(u, myHero) <= r2
                end
            end
            if ok then
                k = k + 1
                out[k] = u
            end
        end
    end
    return out
end

local Objects = {}

function Objects:IsValid(u) return Alive(u) end
function Objects:IsFacing(src, dst, angle) return Facing(src, dst, angle) end
function Objects:OnEnemyHeroLoad(cb) World:OnEnemyHeroLoad(cb) end
function Objects:OnAllyHeroLoad(cb) World:OnAllyHeroLoad(cb) end

function Objects:IsHeroImmortal(u)
    if not u then return false end
    local hook = Hooks.Untargetable
    if hook and hook(u) then return true end
    return u.isImmortal and true or false
end

function Objects:GetEnemyHeroes(range, bbox)
    return World:Collect(World.enemy, World.enemyN, nil, range or nil, bbox)
end

function Objects:GetAllyHeroes(range, bbox)
    return World:Collect(World.ally, World.allyN, nil, range or nil, bbox)
end

function Objects:GetHeroes(range, bbox)
    return World:Collect(World.hero, World.heroN, nil, range or nil, bbox)
end

function Objects:GetEnemyMinions(range, bbox)
    return World:Collect(World.lane, World.laneN, nil, range or nil, bbox)
end

function Objects:GetAllyMinions(range, bbox)
    return World:Collect(World.allyMin, World.allyMinN, nil, range or nil, bbox)
end

function Objects:GetMonsters(range, bbox)
    return World:Collect(World.jungle, World.jungleN, nil, range or nil, bbox)
end

function Objects:GetMinions(range, bbox)
    local a = self:GetEnemyMinions(range, bbox)
    local b = self:GetAllyMinions(range, bbox)
    local n = #a
    for i = 1, #b do a[n + i] = b[i] end
    return a
end

function Objects:GetTurrets(range, bbox)
    return World:Collect(World.turret, World.turretN, nil, range or nil, bbox)
end

function Objects:GetEnemyTurrets(range, bbox)
    return World:Collect(World.turret, World.turretN, IsEnemyUnit, range or nil, bbox)
end

function Objects:GetAllyTurrets(range, bbox)
    return World:Collect(World.turret, World.turretN, IsAllyUnit, range or nil, bbox)
end

function Objects:GetEnemyBuildings(range, bbox)
    return World:Collect(World.struct, World.structN, IsNotTurret, range or nil, bbox)
end

function Objects:GetOtherEnemyMinions(range)
    return World:Collect(World.ward, World.wardN, nil, range or nil, false)
end

function Objects:GetPlants() return {} end

local function BoundingOf(u)
    local t = u.type
    if t == Obj_AI_Barracks then return 270 end
    if t == Obj_AI_Nexus then return 380 end
    return u.boundingRadius or 0
end

local function BaseRangeOf(u)
    local t = u.type
    if t == Obj_AI_Minion then
        return MINION_RANGE[u.charName] or 0
    end
    if t == Obj_AI_Turret then
        return 750
    end
    return u.range or 0
end

local function AttackRange(from, target)
    local base = BaseRangeOf(from)
    if from.isMe then
        local hook = Hooks.BaseRange
        if hook then
            local v = hook()
            if v then base = v end
        end
    end
    local r = base + (from.boundingRadius or 0)
    if not target then
        return r + 35
    end
    r = r + BoundingOf(target)
    if from.isMe and target.type == Obj_AI_Hero then
        local hook = Hooks.ExtraRange
        if hook then
            r = r + (hook(target) or 0)
        end
    end
    return r
end

local function MyAttackRange(target)
    return AttackRange(myHero, target) - Menu.walk.safety:Value()
end

local function InAttackRange(target)
    if not target then return false end
    local r = MyAttackRange(target)
    if DistSq(myHero, target) <= r * r then return true end
    local hook = Hooks.InRange
    if hook and hook(target) then return true end
    return false
end

local Timing = {
    castEnd = 0,
    serverStart = 0,
    windupAtCast = 0,
    animAtCast = 0,
    ratio = nil,
    reset = false,
    pending = false,
    pendingUntil = 0,
    attackCb = {},
}

function Timing:Animation()
    local ad = myHero.attackData
    local a = ad and ad.animationTime
    local hook = Hooks.Animation
    if hook then
        local v = hook(a)
        if v then return v end
    end
    if a and a > 0.05 then return a end
    local mult = myHero.attackSpeed
    if not mult or mult <= 0 then mult = 1 end
    return 1 / (DEFAULT_BASE_AS * mult)
end

function Timing:Windup()
    local hook = Hooks.Windup
    if hook then
        local w = hook()
        if w then return w end
    end
    local ad = myHero.attackData
    local w = ad and ad.windUpTime
    local a = ad and ad.animationTime
    if w and w > 0 and a and a > 0.05 then
        self.ratio = w / a
    end
    local anim = self:Animation()
    if self.ratio then
        return anim * self.ratio
    end
    if w and w > 0 then return w end
    return anim * DEFAULT_WINDUP_RATIO
end

function Timing:ProjectileSpeed()
    local hook = Hooks.MissileSpeed
    if hook then
        local s = hook()
        if s then return s end
    end
    local melee = Hooks.Melee
    if melee then
        if melee() then return HUGE end
    elseif (myHero.range or 0) < MELEE_CUT then
        return HUGE
    end
    local ad = myHero.attackData
    local s = ad and ad.projectileSpeed
    if s and s > 0 then return s end
    return HUGE
end

function Timing:Bias()
    return Menu.walk.windup:Value() * 0.001
end

function Timing:IsAttackName(name)
    if not name then return false end
    if IS_ATTACK[name] then return true end
    if NOT_ATTACK[name] then return false end
    return name:lower():find("attack") ~= nil
end

function Timing:Observe()
    if self.seenFrame == Frame.n then return end
    self.seenFrame = Frame.n
    local s = myHero.activeSpell
    if
        s
        and s.valid
        and s.target
        and s.target > 0
        and s.castEndTime
        and s.castEndTime > self.castEnd
        and (s.isAutoAttack or self:IsAttackName(s.name))
    then
        self.reset = false
        self.pending = false
        self.castEnd = s.castEndTime
        local w = s.windup
        local a = s.animation
        if not w or w <= 0 then w = self:Windup() end
        if not a or a <= 0.05 then a = self:Animation() end
        self.windupAtCast = w
        self.animAtCast = a
        self.serverStart = self.castEnd - w
        local cbs = self.attackCb
        for i = 1, #cbs do cbs[i]() end
        return
    end
    if self.pending and Timer() >= self.pendingUntil then
        self.pending = false
    end
end

function Timing:MarkIssued()
    self.pending = true
    self.pendingUntil = Timer() + Net.grace
end

function Timing:WindupEnd()
    return self.serverStart + self.windupAtCast - Net.half + self:Bias()
end

function Timing:CycleEnd()
    return self.serverStart + self.animAtCast - Net.s
end

function Timing:IsActive(extra)
    if self.pending then return true end
    if self.castEnd <= 0 then return false end
    return Timer() < self:WindupEnd() + (extra or 0)
end

function Timing:IsReady()
    if self.pending then return false end
    if self.castEnd <= 0 then return true end
    if Timer() >= self:CycleEnd() then
        self.reset = false
        return true
    end
    if self.reset and Menu.walk.reset:Value() then
        local p = myHero.pathing
        if not self:IsActive() and not (p and p.isDashing) then
            return true
        end
    end
    return false
end

function Timing:IsBefore(mult)
    return Timer() > self.serverStart + (mult or 0) * self.animAtCast
end

function Timing:CastTime(extra)
    return self:Windup() - Net.half + (extra or 0) + self:Bias()
end

local function Channeling()
    local hook = Hooks.Channeling
    if hook and hook() then return true end
    return false
end

local function SelfCanMove()
    local block = Hooks.BlockMove
    if block and block() then return false end
    if Channeling() then
        local allow = Hooks.AllowMoveWhileChanneling
        if not (allow and allow()) then return false end
    end
    if Buffs:AnyType(myHero, BLOCK_MOVE_TYPES) then return false end
    return true
end

local function SelfCanAttack()
    if Channeling() then return false end
    local p = myHero.pathing
    if p and p.isDashing then return false end
    local s = myHero.activeSpell
    if
        s
        and s.valid
        and s.castEndTime
        and s.castEndTime > Timer()
        and not (s.isAutoAttack or Timing:IsAttackName(s.name))
    then
        return false
    end
    local block = Hooks.BlockAttack
    if block and block() then return false end
    if Buffs:AnyType(myHero, BLOCK_ATTACK_TYPES) then return false end
    return true
end

local Selector = {
    frame = -1,
    n = 0,
    unit = {},
    key = {},
    high = 0,
    mode = PICK_AUTO,
    clicked = nil,
    damageType = DMG_PHYSICAL,
    sortBuf = {},
    sortKey = {},
}

local function InferPriority(u)
    local dps = (u.totalDamage or 0) * (u.attackSpeed or 1) + (u.ap or 0) * 0.5
    local bulk = (u.maxHealth or 1) / 100 + (u.armor or 0) + (u.magicResist or 0)
    if bulk <= 0 then bulk = 1 end
    local ratio = dps / bulk
    if ratio > 1.10 then return 1 end
    if ratio > 0.75 then return 2 end
    if ratio > 0.45 then return 3 end
    if ratio > 0.25 then return 4 end
    return 5
end

function Selector:Priority(u)
    local name = u.charName
    local el = name and Menu.prio[name]
    if el then
        local v = el:Value()
        if v and v > 0 then return v end
    end
    return InferPriority(u)
end

function Selector:GetPriority(u)
    return self:Priority(u)
end

function Selector:Score(u)
    local ehp = (u.health or 0) + Shield(u)
    local mit = Mitigation(myHero, u, self.damageType)
    if mit > 0 then ehp = ehp / mit end
    if ehp < 1 then ehp = 1 end
    local lvl = (u.levelData and u.levelData.lvl) or 1
    local threat = (u.totalDamage or 0) * (u.attackSpeed or 1) + (u.ap or 0) * 0.6 + 14 * lvl
    local weight = 1.9 - 0.18 * self:Priority(u)
    if weight < 0.2 then weight = 0.2 end
    return threat / ehp * weight
end

function Selector:KeyOf(u)
    local m = self.mode
    if m == PICK_CLOSEST then return -DistSq(u, myHero) end
    if m == PICK_MOUSE then return -DistSq(u, MousePos()) end
    if m == PICK_LOWHP then return -(u.health or 0) end
    if m == PICK_LOWMAXHP then return -(u.maxHealth or 0) end
    if m == PICK_PRIORITY then return -self:Priority(u) * 1000 + self:Score(u) end
    if m == PICK_MOSTAD then return u.totalDamage or 0 end
    if m == PICK_MOSTAP then return u.ap or 0 end
    return self:Score(u)
end

function Selector:Refresh()
    if self.frame == Frame.n then return end
    self.frame = Frame.n
    self.mode = Menu.target["mode" .. MY_NAME]:Value()
    local n = 0
    local unit, key = self.unit, self.key
    local hook = Hooks.Untargetable
    for i = 1, World.enemyN do
        local u = World.enemy[i]
        if u.valid and not u.isImmortal and not (hook and hook(u)) then
            n = n + 1
            unit[n] = u
            key[n] = self:KeyOf(u)
        end
    end
    Trim(unit, n, self.high)
    Trim(key, n, self.high)
    self.high = n
    self.n = n
end

function Selector:Sticky(range, pool)
    if not Menu.target.sticky:Value() then return nil, false end
    local pick = self.clicked
    if not Alive(pick) or pick.isImmortal then return nil, false end
    local ok = false
    if pool then
        local id = pick.networkID
        for i = 1, #pool do
            if pool[i].networkID == id then
                ok = true
                break
            end
        end
    elseif range then
        ok = DistSq(myHero, pick) <= range * range
    else
        ok = true
    end
    if ok then return pick, true end
    return nil, Menu.target.stickyOnly:Value()
end

function Selector:Best(range, pool)
    self:Refresh()
    local pick, block = self:Sticky(range, pool)
    if pick then return pick end
    if block then return nil end

    local best, bestKey = nil, nil
    if pool then
        for i = 1, #pool do
            local u = pool[i]
            if Alive(u) and not u.isImmortal then
                local k = self:KeyOf(u)
                if bestKey == nil or k > bestKey then
                    bestKey = k
                    best = u
                end
            end
        end
        return best
    end

    local r2 = range and range * range or nil
    for i = 1, self.n do
        local u = self.unit[i]
        if Alive(u) and (not r2 or DistSq(myHero, u) <= r2) then
            local k = self.key[i]
            if bestKey == nil or k > bestKey then
                bestKey = k
                best = u
            end
        end
    end
    return best
end

function Selector:GetTarget(a, kind)
    if kind then self.damageType = kind end
    if type(a) == "table" then return self:Best(nil, a) end
    return self:Best(a or 20000, nil)
end

function Selector:GetTargets(a, kind)
    if kind then self.damageType = kind end
    self:Refresh()
    local buf, keys = self.sortBuf, self.sortKey
    local n = 0
    if type(a) == "table" then
        for i = 1, #a do
            local u = a[i]
            if Alive(u) and not u.isImmortal then
                n = n + 1
                buf[n] = u
                keys[n] = self:KeyOf(u)
            end
        end
    else
        local range = a or 20000
        local r2 = range * range
        for i = 1, self.n do
            local u = self.unit[i]
            if Alive(u) and DistSq(myHero, u) <= r2 then
                n = n + 1
                buf[n] = u
                keys[n] = self.key[i]
            end
        end
    end
    if n == 0 then return nil end
    for i = 2, n do
        local u, k = buf[i], keys[i]
        local j = i - 1
        while j >= 1 and keys[j] < k do
            buf[j + 1] = buf[j]
            keys[j + 1] = keys[j]
            j = j - 1
        end
        buf[j + 1] = u
        keys[j + 1] = k
    end
    local out = {}
    for i = 1, n do out[i] = buf[i] end
    return out
end

function Selector:GetComboTarget(kind)
    self.damageType = kind or DMG_PHYSICAL
    self:Refresh()
    if Menu.target.sticky:Value() then
        local pick = self.clicked
        if Alive(pick) and not pick.isImmortal and InAttackRange(pick) then
            return pick
        end
        if Alive(pick) and Menu.target.stickyOnly:Value() then return nil end
    end
    local best, bestKey = nil, nil
    for i = 1, self.n do
        local u = self.unit[i]
        if Alive(u) then
            local r = MyAttackRange(u)
            if DistSq(myHero, u) <= r * r then
                local k = self.key[i]
                if bestKey == nil or k > bestKey then
                    bestKey = k
                    best = u
                end
            end
        end
    end
    return best
end

function Selector:WndMsg(msg)
    if msg ~= WM_LBUTTONDOWN then return end
    if not Menu.target.sticky:Value() then return end
    local mouse = MousePos()
    local best, bestD = nil, 150 * 150
    for i = 1, World.enemyN do
        local u = World.enemy[i]
        local p = u.pos
        if p and p:ToScreen().onScreen then
            local d = DistSq(p, mouse)
            if d < bestD then
                bestD = d
                best = u
            end
        end
    end
    self.clicked = best
end

local Farm = {
    frame = -1,
    atkN = 0, atkHigh = 0,
    atkTarget = {}, atkSpeed = {}, atkStart = {}, atkWindup = {},
    atkAnim = {}, atkEnd = {}, atkSrc = {}, atkIsTurret = {},
    dmgBySrc = {},
    minionN = 0, minionHigh = 0,
    minion = {}, predHP = {}, killable = {}, nearly = {}, soon = {}, unkillable = {}, atTurret = {},
    anyKillable = false,
    waitFrame = -1,
    inRangeLaneN = 0, inRangeLane = {}, inRangeLaneHigh = 0,
    inRangeJungleN = 0, inRangeJungle = {}, inRangeJungleHigh = 0,
    inRangeWardN = 0, inRangeWard = {}, inRangeWardHigh = 0,
    inRangeStructN = 0, inRangeStruct = {}, inRangeStructHigh = 0,
    unkillableCb = {},
    static = nil,
}

function Farm:CachedDamage(idx, src, target)
    local bucket = self.dmgBySrc[idx]
    if not bucket then
        bucket = { stamp = -1 }
        self.dmgBySrc[idx] = bucket
    end
    if bucket.stamp ~= Frame.n then
        bucket.stamp = Frame.n
        for k in pairs(bucket) do
            if k ~= "stamp" then bucket[k] = nil end
        end
    end
    local h = target.handle
    local v = bucket[h]
    if v == nil then
        v = Combat:GetAutoAttackDamage(src, target)
        bucket[h] = v
    end
    return v
end

function Farm:Predict(target, horizon)
    if not target or not target.valid then return 0, false end
    if horizon < 0 then horizon = 0 end
    local hp = (target.health or 0) + Shield(target)
    local handle = target.handle
    local now = Timer()
    local turret = false

    for i = 1, self.atkN do
        if self.atkTarget[i] == handle then
            local src = self.atkSrc[i]
            if src and src.valid and src.visible and not src.dead then
                local anim = self.atkAnim[i]
                if anim and anim > 0.05 then
                    local speed = self.atkSpeed[i]
                    local fly = 0
                    if speed and speed > 0 and speed < HUGE then
                        fly = Dist(src, target) / speed
                    end
                    local first = self.atkStart[i] + self.atkWindup[i] + fly - now
                    if first < 0 then
                        local nextStart = self.atkEnd[i]
                        if nextStart < now then nextStart = now end
                        first = (nextStart - now) + self.atkWindup[i] + fly
                    end
                    if first < horizon then
                        local hits = floor((horizon - first) / anim) + 1
                        if hits > MAX_PREDICT_HITS then hits = MAX_PREDICT_HITS end
                        if self.atkIsTurret[i] then
                            turret = true
                        else
                            hp = hp - hits * self:CachedDamage(i, src, target)
                        end
                    end
                end
            end
        end
    end

    for i = 1, World.allyMinN do
        local m = World.allyMin[i]
        if m.valid and m.visible and not m.dead then
            local ad = m.attackData
            if ad then
                local committed = ad.target == handle and ad.endTime and ad.endTime > now
                if not committed then
                    local anim = ad.animationTime or 0
                    if anim > 0.05 then
                        local range = AttackRange(m, target)
                        local p = m.pathing
                        local extra = (p and p.hasMovePath) and 250 or 0
                        local d = Dist(m, target)
                        local speed = ad.projectileSpeed
                        if not speed or speed <= 0 then
                            speed = (BaseRangeOf(m) < MELEE_CUT) and HUGE or nil
                        end
                        local windup = ad.windUpTime
                        if d < range + extra and speed and windup and windup > 0 then
                            local reach = d > range and range or d
                            local fly = (speed < HUGE) and reach / speed or 0
                            local first = windup + fly
                            if first < horizon then
                                local hits = floor((horizon - first) / anim) + 1
                                if hits > MAX_PREDICT_HITS then hits = MAX_PREDICT_HITS end
                                hp = hp - hits * self:CachedDamage(-i, m, target)
                            end
                        end
                    end
                end
            end
        end
    end

    return hp, turret
end

function Farm:ClearLists()
    Trim(self.minion, 0, self.minionHigh)
    self.minionHigh, self.minionN = 0, 0
    Trim(self.inRangeLane, 0, self.inRangeLaneHigh)
    self.inRangeLaneHigh, self.inRangeLaneN = 0, 0
    Trim(self.inRangeJungle, 0, self.inRangeJungleHigh)
    self.inRangeJungleHigh, self.inRangeJungleN = 0, 0
    Trim(self.inRangeWard, 0, self.inRangeWardHigh)
    self.inRangeWardHigh, self.inRangeWardN = 0, 0
    Trim(self.inRangeStruct, 0, self.inRangeStructHigh)
    self.inRangeStructHigh, self.inRangeStructN = 0, 0
    Trim(self.atkSrc, 0, self.atkHigh)
    self.atkHigh, self.atkN = 0, 0
end

function Farm:Refresh()
    if self.frame == Frame.n then return end
    self.frame = Frame.n
    self.anyKillable = false

    local idle = not (ModeState[MODE_HARASS] or ModeState[MODE_LANECLEAR]
        or ModeState[MODE_JUNGLECLEAR] or ModeState[MODE_LASTHIT])
    if idle then
        self:ClearLists()
        return
    end

    local now = Timer()
    local atkN = 0
    local keys, map = World.handleKeys, World.handleMap
    for i = 1, World.handleN do
        local src = map[keys[i]]
        if src then
            local s = src.activeSpell
            if s and s.valid and s.isAutoAttack and s.target and s.target > 0 then
                local endTime = s.endTime
                local ad = src.attackData
                local anim = s.animation
                if not anim or anim <= 0.05 then
                    anim = ad and ad.animationTime
                end
                local windup = s.windup
                if not windup or windup <= 0 then
                    windup = ad and ad.windUpTime
                end
                local speed = s.speed
                if not speed or speed <= 0 then
                    speed = ad and ad.projectileSpeed
                end
                if not speed or speed <= 0 then
                    speed = (BaseRangeOf(src) < MELEE_CUT) and HUGE or nil
                end
                if
                    endTime
                    and endTime > now
                    and anim and anim > 0.05
                    and windup and windup > 0
                    and speed
                then
                    atkN = atkN + 1
                    self.atkTarget[atkN] = s.target
                    self.atkSpeed[atkN] = speed
                    self.atkEnd[atkN] = endTime
                    self.atkAnim[atkN] = anim
                    self.atkWindup[atkN] = windup
                    self.atkStart[atkN] = endTime - anim
                    self.atkSrc[atkN] = src
                    self.atkIsTurret[atkN] = (src.handle == World.allyTurretHandle)
                end
            end
        end
    end
    Trim(self.atkSrc, atkN, self.atkHigh)
    self.atkHigh = atkN
    self.atkN = atkN

    local laneN = 0
    local lane = self.inRangeLane
    for i = 1, World.laneN do
        local u = World.lane[i]
        local r = MyAttackRange(u)
        if DistSq(myHero, u) <= r * r then
            laneN = laneN + 1
            lane[laneN] = u
        end
    end
    Trim(lane, laneN, self.inRangeLaneHigh)
    self.inRangeLaneHigh = laneN
    self.inRangeLaneN = laneN

    local jungleN = 0
    local jungle = self.inRangeJungle
    for i = 1, World.jungleN do
        local u = World.jungle[i]
        local r = MyAttackRange(u)
        if DistSq(myHero, u) <= r * r then
            jungleN = jungleN + 1
            jungle[jungleN] = u
        end
    end
    Trim(jungle, jungleN, self.inRangeJungleHigh)
    self.inRangeJungleHigh = jungleN
    self.inRangeJungleN = jungleN

    local wardN = 0
    local ward = self.inRangeWard
    for i = 1, World.wardN do
        local u = World.ward[i]
        local r = MyAttackRange(u)
        if DistSq(myHero, u) <= r * r then
            wardN = wardN + 1
            ward[wardN] = u
        end
    end
    Trim(ward, wardN, self.inRangeWardHigh)
    self.inRangeWardHigh = wardN
    self.inRangeWardN = wardN

    local structN = 0
    local struct = self.inRangeStruct
    if Menu.farm.structures:Value() then
        for i = 1, World.structN do
            local u = World.struct[i]
            local r = MyAttackRange(u)
            if DistSq(myHero, u) <= r * r then
                structN = structN + 1
                struct[structN] = u
            end
        end
    end
    Trim(struct, structN, self.inRangeStructHigh)
    self.inRangeStructHigh = structN
    self.inRangeStructN = structN

    self.static = Combat:GetStaticAutoAttackDamage(myHero, true)
    local windup = Timing:Windup()
    local anim = Timing:Animation()
    local speed = Timing:ProjectileSpeed()
    local base = windup + Net.half - Menu.farm.delay:Value() * 0.001
    local slack = (1.5 - anim) * 0.3
    if slack < 0 then slack = 0 end

    local mn = 0
    for i = 1, laneN do
        local u = lane[i]
        local fly = 0
        if speed < HUGE then
            fly = Dist(myHero, u) / speed
        end
        local horizon = base + fly
        local dmg = Combat:GetAutoAttackDamage(myHero, u, true, self.static)
        local hp, turret = self:Predict(u, horizon)
        local killable, nearly, soon, dead = false, false, false, false
        if hp < 0 then
            dead = true
            local cbs = self.unkillableCb
            for c = 1, #cbs do cbs[c](u) end
        elseif hp - dmg < 0 then
            killable = true
            self.anyKillable = true
        else
            local name = u.charName
            local siege = name and name:lower():find("minionsiege", 1, true)
            local soonHorizon = anim + (siege and horizon * 1.4 or horizon) + slack
            local hp2 = self:Predict(u, soonHorizon)
            if hp2 < 0 then
                nearly = true
                self.waitFrame = Frame.n
            elseif hp2 - dmg < 0 then
                nearly = true
            else
                local hp3 = self:Predict(u, 1.25 * anim + 1.25 * horizon + 0.5 + slack)
                if hp3 - dmg < 0 then soon = true end
            end
        end
        mn = mn + 1
        self.minion[mn] = u
        self.predHP[mn] = hp
        self.killable[mn] = killable
        self.nearly[mn] = nearly
        self.soon[mn] = soon
        self.unkillable[mn] = dead
        self.atTurret[mn] = turret
    end
    Trim(self.minion, mn, self.minionHigh)
    self.minionHigh = mn
    self.minionN = mn
end

function Farm:ShouldWait()
    return self.waitFrame >= 0 and Frame.n - self.waitFrame <= 8
end

function Farm:OnUnkillable(cb)
    self.unkillableCb[#self.unkillableCb + 1] = cb
end

local function MinionTier(u)
    local name = u.charName
    if not name then return 3 end
    local n = name:lower()
    if n:find("minionsiege", 1, true) or n:find("minionsuper", 1, true) then return 1 end
    if n:find("minionmelee", 1, true) then return 2 end
    return 3
end

function Farm:GetLastHitTarget()
    self:Refresh()
    local best, bestTier, bestHP = nil, 99, HUGE
    for i = 1, self.minionN do
        local u = self.minion[i]
        if self.killable[i] and Alive(u) and InAttackRange(u) then
            local tier = MinionTier(u)
            local hp = self.predHP[i]
            if tier < bestTier or (tier == bestTier and hp < bestHP) then
                bestTier = tier
                bestHP = hp
                best = u
            end
        end
    end
    return best
end

function Farm:GetLaneMinion()
    self:Refresh()
    local best, bestHP = nil, HUGE
    for i = 1, self.minionN do
        local u = self.minion[i]
        if Alive(u) and not self.nearly[i] and not self.soon[i] and not self.unkillable[i] and InAttackRange(u) then
            local hp = self.predHP[i]
            if hp < bestHP then
                bestHP = hp
                best = u
            end
        end
    end
    return best
end

function Farm:FirstValid(list, n)
    for i = 1, n do
        if Alive(list[i]) then return list[i] end
    end
    return nil
end

function Farm:FattestValid(list, n)
    local best, bestHP = nil, -1
    for i = 1, n do
        local u = list[i]
        if Alive(u) then
            local hp = u.maxHealth or 0
            if hp > bestHP then
                bestHP = hp
                best = u
            end
        end
    end
    return best
end

function Farm:GetJungleTarget()
    self:Refresh()
    local m = self:FattestValid(self.inRangeJungle, self.inRangeJungleN)
    if m then return m end
    return self:FirstValid(self.inRangeWard, self.inRangeWardN)
end

function Farm:GetHarassTarget()
    self:Refresh()
    if not Menu.farm.harassFarm:Value() then
        return Selector:GetComboTarget()
    end
    local priority = Menu.farm.lastHitFirst:Value()
    local structure = self:FirstValid(self.inRangeStruct, self.inRangeStructN)
    if not priority then
        if structure then return structure end
        local hero = Selector:GetComboTarget()
        if hero then return hero end
    end
    if self.anyKillable then
        local m = self:GetLastHitTarget()
        if m then return m end
    end
    if self:ShouldWait() then return nil end
    if structure then return structure end
    return Selector:GetComboTarget()
end

function Farm:GetLaneClearTarget()
    self:Refresh()
    local monster = self:FattestValid(self.inRangeJungle, self.inRangeJungleN)
    if monster then return monster end

    local priority = Menu.farm.lastHitFirst:Value()
    local heroes = Menu.farm.clearHeroes:Value()
    local structure = self:FirstValid(self.inRangeStruct, self.inRangeStructN)
    local ward = self:FirstValid(self.inRangeWard, self.inRangeWardN)

    if not priority then
        if structure then return structure end
        if heroes then
            local hero = Selector:GetComboTarget()
            if hero then return hero end
        end
    end

    if self.anyKillable then
        local m = self:GetLastHitTarget()
        if m then return m end
    end

    if self:ShouldWait() then return nil end

    if structure then return structure end
    if heroes then
        local hero = Selector:GetComboTarget()
        if hero then return hero end
    end

    local m = self:GetLaneMinion()
    if m then return m end
    if ward then return ward end
    return nil
end

function Farm:GetPrediction(target, time)
    self:Refresh()
    local hp = self:Predict(target, time or 0)
    return hp
end

local Input = {
    step = 0,
    wait = 0,
    savedX = 0,
    savedY = 0,
    tcoDown = false,
    forceTcoUp = false,
}

local function ScreenOf(a)
    if not a then return nil end
    if a.pos then
        if not a.valid then return nil end
        local p = a.pos:To2D()
        if not p then return nil end
        local name = a.charName
        if name then
            local low = name:lower()
            if low:find("chaosminion", 1, true) or low:find("orderminion", 1, true) then
                local _, sh = Screen()
                if sh > 0 then
                    p.y = p.y - (25 / 1440) * sh
                end
            end
        end
        return p
    end
    if a.z ~= nil then
        return Vector(a.x, a.y or 0, a.z):To2D()
    end
    if a.x ~= nil then
        return { x = a.x, y = a.y, onScreen = true }
    end
    return nil
end

function Input:Busy()
    return self.step ~= 0
end

function Input:ReleaseTco()
    if Control.IsKeyDown(HK_TCO) then
        Control.KeyUp(HK_TCO)
    end
    self.tcoDown = false
end

function Input:HoldTco(want)
    if want then
        if not self.tcoDown and not self.forceTcoUp then
            Control.KeyDown(HK_TCO)
            self.tcoDown = true
        end
    elseif self.tcoDown then
        self:ReleaseTco()
    end
end

function Input:Tap(key)
    local s = myHero.activeSpell
    if Control.IsKeyDown(key) and s and s.isCharging then
        Control.KeyUp(key)
        return
    end
    Control.KeyDown(key)
    Control.KeyUp(key)
end

function Input:Send(keys, at)
    if self.step ~= 0 then return false end
    local screen = ScreenOf(at)
    if not screen then return false end
    if screen.onScreen == false then return false end

    local cur = CursorPos()
    self.savedX, self.savedY = cur.x, cur.y

    Control.SetCursorPos(screen.x, screen.y)

    local isClick = keys == MOUSEEVENTF_RIGHTDOWN
    if not isClick then
        local now = CursorPos()
        local dx, dy = now.x - screen.x, now.y - screen.y
        if dx * dx + dy * dy > 25 then
            Control.SetCursorPos(self.savedX, self.savedY)
            return false
        end
    end

    if at.type and at.type ~= Obj_AI_Hero then
        self.forceTcoUp = true
        if Control.IsKeyDown(HK_TCO) then
            Control.KeyUp(HK_TCO)
            self.tcoDown = false
        end
    end

    if isClick then
        Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
        Control.mouse_event(MOUSEEVENTF_RIGHTUP)
    elseif type(keys) == "table" then
        for i = 1, #keys do
            self:Tap(keys[i])
        end
    else
        self:Tap(keys)
    end

    self.step = 1
    self.wait = Menu.walk.confirm:Value()
    return true
end

function Input:OnTick()
    if self.step == 0 then return end
    self.wait = self.wait - 1
    if self.wait > 0 then return end
    Control.SetCursorPos(self.savedX, self.savedY)
    self.step = 0
    self.forceTcoUp = false
end

local Mover = {
    pending = false,
    px = 0,
    pz = 0,
    deadline = 0,
    orderFrame = -1,
}

function Mover:Acked()
    if not self.pending then return true end
    local p = myHero.pathing
    if p and p.hasMovePath and p.endPos then
        local e = p.endPos
        local dx, dz = e.x - self.px, (e.z or e.y) - self.pz
        if dx * dx + dz * dz < ACK_TOLERANCE2 then
            self.pending = false
            return true
        end
    end
    if Timer() >= self.deadline then
        self.pending = false
        return true
    end
    return false
end

function Mover:AlreadyGoing(x, z)
    local p = myHero.pathing
    if not (p and p.hasMovePath and p.endPos) then return false end
    local e = p.endPos
    local dx, dz = e.x - x, (e.z or e.y) - z
    local spacing = Menu.walk.spacing:Value()
    if spacing <= 0 then return false end
    return dx * dx + dz * dz < spacing * spacing
end

function Mover:Order(dest)
    if Input:Busy() then return false end
    if not self:Acked() then return false end
    local pos
    if dest then
        pos = dest.pos or dest
    else
        pos = MousePos()
    end
    if not pos or not pos.x then return false end
    local x, z = pos.x, (pos.z or pos.y)
    if self:AlreadyGoing(x, z) then return false end
    if dest then
        if not Input:Send(MOUSEEVENTF_RIGHTDOWN, pos) then return false end
    else
        Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
        Control.mouse_event(MOUSEEVENTF_RIGHTUP)
    end
    self.pending = true
    self.px, self.pz = x, z
    self.deadline = Timer() + Net.grace
    self.orderFrame = Frame.n
    return true
end

function Mover:Reset()
    self.pending = false
    self.deadline = 0
end

local MODE_KEYS = {
    [MODE_COMBO] = {},
    [MODE_HARASS] = {},
    [MODE_LANECLEAR] = {},
    [MODE_JUNGLECLEAR] = {},
    [MODE_LASTHIT] = {},
    [MODE_FLEE] = {},
}

local Walker = {
    Modes = ModeState,
    MenuKeys = MODE_KEYS,
    IsNone = true,
    LastTarget = nil,
    ForceTarget = nil,
    ForceMovement = nil,
    AttackEnabled = true,
    MovementEnabled = true,
    OnPreAttackCb = {},
    OnPostAttackCb = {},
    OnPostAttackTickCb = {},
    OnMoveCb = {},
    postPending = false,
    postTime = -1,
    canAttackC = nil,
    canMoveC = nil,
}

function Walker:RegisterKey(mode, el)
    local t = MODE_KEYS[mode]
    t[#t + 1] = el
end

function Walker:HasMode(mode)
    if mode == MODE_NONE then
        return not (ModeState[MODE_COMBO] or ModeState[MODE_HARASS] or ModeState[MODE_LANECLEAR]
            or ModeState[MODE_JUNGLECLEAR] or ModeState[MODE_LASTHIT] or ModeState[MODE_FLEE])
    end
    local keys = MODE_KEYS[mode]
    if not keys then return false end
    for i = 1, #keys do
        if keys[i]:Value() then return true end
    end
    return false
end

function Walker:GetModes()
    if self.modeFrame == Frame.n then return ModeState end
    self.modeFrame = Frame.n
    ModeState[MODE_COMBO] = self:HasMode(MODE_COMBO)
    ModeState[MODE_HARASS] = self:HasMode(MODE_HARASS)
    ModeState[MODE_LANECLEAR] = self:HasMode(MODE_LANECLEAR)
    ModeState[MODE_JUNGLECLEAR] = self:HasMode(MODE_JUNGLECLEAR)
    ModeState[MODE_LASTHIT] = self:HasMode(MODE_LASTHIT)
    ModeState[MODE_FLEE] = self:HasMode(MODE_FLEE)
    self.IsNone = not (ModeState[MODE_COMBO] or ModeState[MODE_HARASS] or ModeState[MODE_LANECLEAR]
        or ModeState[MODE_JUNGLECLEAR] or ModeState[MODE_LASTHIT] or ModeState[MODE_FLEE])
    return ModeState
end

function Walker:OnPreAttack(f) self.OnPreAttackCb[#self.OnPreAttackCb + 1] = f end
function Walker:OnPostAttack(f) self.OnPostAttackCb[#self.OnPostAttackCb + 1] = f end
function Walker:OnPostAttackTick(f) self.OnPostAttackTickCb[#self.OnPostAttackTickCb + 1] = f end
function Walker:OnAttack(f) Timing.attackCb[#Timing.attackCb + 1] = f end
function Walker:OnPreMovement(f) self.OnMoveCb[#self.OnMoveCb + 1] = f end
function Walker:OnUnkillableMinion(f) Farm:OnUnkillable(f) end
function Walker:CanAttackEvent(f) self.canAttackC = f end
function Walker:CanMoveEvent(f) self.canMoveC = f end
function Walker:SetAttack(v) self.AttackEnabled = v and true or false end
function Walker:SetMovement(v) self.MovementEnabled = v and true or false end
function Walker:IsEnabled() return Menu.root.enabled:Value() end
function Walker:ResetMovement() Mover:Reset() end

function Walker:__OnAutoAttackReset()
    Timing.reset = true
end

function Walker:IsAutoAttacking(unit)
    if unit == nil or unit.isMe then
        return Timing:IsActive()
    end
    local ad = unit.attackData
    if not ad then return false end
    return Timer() < (ad.endTime or 0) - (ad.windDownTime or 0)
end

function Walker:CanAttack(unit)
    if unit == nil or unit.isMe then
        if self.canAttackC and not self.canAttackC() then return false end
        if (JustEvade and JustEvade.Evading()) or (ExtLibEvade and ExtLibEvade.Evading) then return false end
        if not SelfCanAttack() then return false end
        return Timing:IsReady()
    end
    local ad = unit.attackData
    if not ad then return true end
    return Timer() > (ad.endTime or 0)
end

function Walker:CanMove(unit)
    if unit == nil or unit.isMe then
        if self.canMoveC and not self.canMoveC() then return false end
        if (JustEvade and JustEvade.Evading()) or (ExtLibEvade and ExtLibEvade.Evading) then return false end
        if not SelfCanMove() then return false end
        local force = Hooks.ForceMove
        if force and force() then return true end
        return not Timing:IsActive()
    end
    local ad = unit.attackData
    if not ad then return true end
    return Timer() > (ad.endTime or 0) - (ad.windDownTime or 0)
end

function Walker:GetTarget()
    local forced = self.ForceTarget
    if Alive(forced) and not forced.isImmortal then
        return forced
    end
    if ModeState[MODE_FLEE] then return nil end
    local hook = Hooks.PriorityTarget
    if hook then
        local u = hook(ModeState)
        if Alive(u) and InAttackRange(u) then return u end
    end
    if ModeState[MODE_COMBO] then return Selector:GetComboTarget() end
    if ModeState[MODE_LASTHIT] then return Farm:GetLastHitTarget() end
    if ModeState[MODE_JUNGLECLEAR] then
        local j = Farm:GetJungleTarget()
        if j then return j end
    end
    if ModeState[MODE_LANECLEAR] then return Farm:GetLaneClearTarget() end
    if ModeState[MODE_HARASS] then return Farm:GetHarassTarget() end
    return nil
end

function Walker:Attack(unit)
    if not Menu.walk.attack:Value() or not self.AttackEnabled then return false end
    if Control.IsKeyDown(0x11) or Control.IsKeyDown(0x12) then return false end
    if not Alive(unit) then return false end
    if not self:CanAttack() then return false end

    local p = unit.pos
    if not p then return false end
    local screen = p:To2D()
    if not screen or screen.onScreen == false then return false end

    self.LastTarget = unit

    local args = { Target = unit, Process = true }
    local cbs = self.OnPreAttackCb
    for i = 1, #cbs do
        cbs[i](args)
    end
    if not args.Process then return false end

    local target = args.Target
    if not Alive(target) then return false end
    if not InAttackRange(target) then return false end

    self.LastTarget = target
    if not Input:Send(Menu.root.attackKey:Key(), target) then return false end

    Timing:MarkIssued()
    Mover:Reset()
    self.postPending = true
    return true
end

function Walker:Move()
    if not Menu.walk.move:Value() or not self.MovementEnabled then return end
    if not self:CanMove() then return end

    local settled = not Timing:IsActive(0.02)

    if self.postPending and settled then
        local cbs = self.OnPostAttackCb
        for i = 1, #cbs do cbs[i]() end
        self.postPending = false
        self.postTime = Timer()
    end

    if settled and self.postTime >= 0 and Timer() < self.postTime + POST_WINDOW then
        local cbs = self.OnPostAttackTickCb
        for i = 1, #cbs do cbs[i](self.postTime) end
    end

    local args = { Target = nil, Process = true }
    local cbs = self.OnMoveCb
    for i = 1, #cbs do cbs[i](args) end
    if not args.Process then return end

    if self.ForceMovement ~= nil then
        Mover:Order(self.ForceMovement)
        return
    end

    if args.Target ~= nil then
        Mover:Order(args.Target)
        return
    end

    local hold = Menu.walk.hold:Value()
    if hold > 0 and Within(myHero, MousePos(), hold) then
        return
    end

    Mover:Order(nil)
end

function Walker:Orbwalk()
    if not self:Attack(self:GetTarget()) then
        self:Move()
    end
end

function Walker:OnTick()
    if not Menu.root.enabled:Value() then
        Input:HoldTco(false)
        return
    end
    self:GetModes()

    local combo = ModeState[MODE_COMBO] and not myHero.dead and Menu.walk.tco:Value()
    Input:HoldTco(combo)

    if Input:Busy() then return end
    if ChatOpen() or not OnTop() then return end
    if (JustEvade and JustEvade.Evading()) or (ExtLibEvade and ExtLibEvade.Evading) then return end
    if myHero.dead or self.IsNone then return end

    if Timing.reset then
        local p = myHero.pathing
        if p and p.isDashing then return end
    end

    self:Orbwalk()
end

function Walker:OnDraw()
    local d = Menu.draws
    if not d.enabled:Value() then return end
    local pos = myHero.pos
    if not pos then return end

    if d.range:Value() then
        Draw.Circle(pos, MyAttackRange(nil), 1, Palette.range)
    end
    if d.hold:Value() then
        Draw.Circle(pos, Menu.walk.hold:Value(), 1, Palette.hold)
    end
    if d.cursor:Value() then
        Draw.Circle(MousePos(), 120, 1, Palette.cursor)
    end
    if d.enemyRange:Value() then
        for i = 1, World.enemyN do
            local u = World.enemy[i]
            if u.valid and OnScreen(u) then
                local p = u.pos
                if p then
                    local r = AttackRange(u, myHero)
                    local inside = DistSq(u, myHero) <= r * r
                    Draw.Circle(p, r, 1, inside and Palette.enemyRange or Palette.range)
                end
            end
        end
    end
    if d.selected:Value() then
        local c = Selector.clicked
        if Alive(c) and c.pos then
            Draw.Circle(c.pos, 140, 2, Palette.selected)
        end
    end
    if d.farm:Value() then
        for i = 1, Farm.minionN do
            local kill = Farm.killable[i]
            local near = kill or Farm.nearly[i]
            if near then
                local u = Farm.minion[i]
                if Alive(u) and OnScreen(u) then
                    local p = u.pos
                    if p then
                        local r = u.boundingRadius or 62
                        if r < 62 then r = 62 end
                        Draw.Circle(p, r, (kill and 2) or 1, (kill and Palette.killable) or Palette.nearly)
                    end
                end
            end
        end
    end
    if d.mode:Value() then
        local sw, sh = Screen()
        if sw > 0 then
            local label = "idle"
            if ModeState[MODE_COMBO] then label = "combo"
            elseif ModeState[MODE_HARASS] then label = "harass"
            elseif ModeState[MODE_LASTHIT] then label = "last hit"
            elseif ModeState[MODE_JUNGLECLEAR] then label = "jungle"
            elseif ModeState[MODE_LANECLEAR] then label = "lane clear"
            elseif ModeState[MODE_FLEE] then label = "flee" end
            Draw.Text(label, 14, sw / 2 - 30, sh - 240, self.IsNone and Palette.dim or Palette.text)
        end
    end
    if d.profile:Value() then
        local sw, sh = Screen()
        if sw > 0 then
            Draw.Text(Prof.text, 13, 20, sh - 300, Palette.text)
        end
    end
end

Walker:RegisterKey(MODE_COMBO, Menu.keys.combo)
Walker:RegisterKey(MODE_HARASS, Menu.keys.harass)
Walker:RegisterKey(MODE_LASTHIT, Menu.keys.lasthit)
Walker:RegisterKey(MODE_LANECLEAR, Menu.keys.laneclear)
Walker:RegisterKey(MODE_JUNGLECLEAR, Menu.keys.jungle)
Walker:RegisterKey(MODE_FLEE, Menu.keys.flee)

local Snapshot = { frame = -1, heroes = nil, minions = nil, wards = nil, turrets = nil }

local Cached = {}

local function SnapshotGate()
    if Snapshot.frame ~= Frame.n then
        Snapshot.frame = Frame.n
        Snapshot.heroes = nil
        Snapshot.minions = nil
        Snapshot.wards = nil
        Snapshot.turrets = nil
    end
end

function Cached:Reset() Snapshot.frame = -1 end
function Cached:WndMsg() end

function Cached:GetHeroes()
    SnapshotGate()
    if not Snapshot.heroes then
        Snapshot.heroes = Objects:GetHeroes()
    end
    return Snapshot.heroes
end

function Cached:GetMinions()
    SnapshotGate()
    if not Snapshot.minions then
        local out = Objects:GetEnemyMinions()
        local n = #out
        for i = 1, World.allyMinN do out[n + i] = World.allyMin[i] end
        n = n + World.allyMinN
        for i = 1, World.jungleN do out[n + i] = World.jungle[i] end
        Snapshot.minions = out
    end
    return Snapshot.minions
end

function Cached:GetWards()
    SnapshotGate()
    if not Snapshot.wards then
        Snapshot.wards = Objects:GetOtherEnemyMinions()
    end
    return Snapshot.wards
end

function Cached:GetTurrets()
    SnapshotGate()
    if not Snapshot.turrets then
        Snapshot.turrets = Objects:GetTurrets()
    end
    return Snapshot.turrets
end

function Cached:GetPlants() return {} end

function Cached:GetBuffs(u)
    local list = Buffs:List(u)
    return list
end

function Cached:GetBuffMap(u)
    local e = Buffs:Entry(u)
    if not e then return {} end
    return e.map
end

local Facade = {}

function Facade:GetLatency() return Net.s end
function Facade:GetAutoAttackRange(from, target) return AttackRange(from, target) end

function Facade:IsInAutoAttackRange(from, target, extra)
    if not from or not target then return false end
    local r = AttackRange(from, target) + (extra or 0)
    return DistSq(from, target) <= r * r
end

function Facade:IsMelee()
    local hook = Hooks.Melee
    if hook then return hook() and true or false end
    return (myHero.range or 0) < MELEE_CUT
end

function Facade:GetTotalShield(u) return Shield(u) end
function Facade:IsAttack(name) return Timing:IsAttackName(name) end

function Facade:Stop()
    return ChatOpen() or not OnTop()
        or (ExtLibEvade and ExtLibEvade.Evading)
        or (JustEvade and JustEvade.Evading())
end

local AttackApi = {}

function AttackApi:IsActive(extra) return Timing:IsActive(extra) end
function AttackApi:IsReady() return Timing:IsReady() end
function AttackApi:IsBefore(m) return Timing:IsBefore(m) end
function AttackApi:GetWindup() return Timing:Windup() end
function AttackApi:GetAnimation() return Timing:Animation() end
function AttackApi:GetProjectileSpeed() return Timing:ProjectileSpeed() end
function AttackApi:GetAttackCastTime(extra) return Timing:CastTime(extra) end
function AttackApi:GetAttackSpeed() return 1 / Timing:Animation() end

local BuffApi = {}

function BuffApi:HasBuff(u, name) return Buffs:Has(u, name) end
function BuffApi:GetBuff(u, name) return Buffs:Get(u, name) end
function BuffApi:GetBuffDuration(u, name) return Buffs:Duration(u, name) end
function BuffApi:HasBuffTypes(u, types) return Buffs:AnyType(u, types) end

function BuffApi:GetBuffs(u)
    local list = Buffs:List(u)
    return list
end

function BuffApi:GetBuffStartTime(u, name)
    local b = Buffs:Get(u, name)
    if not b then return 0 end
    return b.startTime or 0
end

function BuffApi:ContainsBuffs(u, names)
    if type(names) ~= "table" then return Buffs:Has(u, names) end
    for i = 1, #names do
        if Buffs:Has(u, names[i]) then return true end
    end
    return false
end

local ticks = {}
local draws = {}
local wndmsgs = {}

_G.SDK = {
    LowkeyVersion = __version__,
    OnTick = ticks,
    OnDraw = draws,
    OnWndMsg = wndmsgs,
    Menu = Menu,
    Color = Palette,
    Hooks = Hooks,
    Cached = Cached,
    BuffManager = BuffApi,
    Damage = Combat,
    Data = Facade,
    ObjectManager = Objects,
    TargetSelector = Selector,
    HealthPrediction = Farm,
    Attack = AttackApi,
    Orbwalker = Walker,
    Movement = Mover,
    Cursor = Input,
    Frame = Frame,
    DAMAGE_TYPE_PHYSICAL = DMG_PHYSICAL,
    DAMAGE_TYPE_MAGICAL = DMG_MAGICAL,
    DAMAGE_TYPE_TRUE = DMG_TRUE,
    ORBWALKER_MODE_NONE = MODE_NONE,
    ORBWALKER_MODE_COMBO = MODE_COMBO,
    ORBWALKER_MODE_HARASS = MODE_HARASS,
    ORBWALKER_MODE_LANECLEAR = MODE_LANECLEAR,
    ORBWALKER_MODE_JUNGLECLEAR = MODE_JUNGLECLEAR,
    ORBWALKER_MODE_LASTHIT = MODE_LASTHIT,
    ORBWALKER_MODE_FLEE = MODE_FLEE,
    IsRecalling = function(unit)
        if unit == nil then return false end
        if Buffs:Has(unit, "recall") then return true end
        local s = unit.activeSpell
        if s and s.valid and s.name == "recall" then return true end
        return false
    end,
}

World:OnEnemyHeroLoad(function(args)
    local name = args.charName
    if not name then return end
    if Menu.prio[name] then return end
    Menu.prio:MenuElement({
        id = name,
        name = name,
        value = 0,
        min = 0,
        max = 5,
        step = 1,
        tooltip = "0 = auto",
    })
end)

do
    local attackKey = Menu.root.attackKey

    _G.Control.Attack = function(target)
        if not target then return false end
        return Input:Send(attackKey:Key(), target)
    end

    _G.Control.Move = function(a, b, c)
        if Input:Busy() then return false end
        local dest
        if a and b and c then
            dest = { x = a, y = b, z = c }
        elseif a and b then
            dest = { x = a, y = b }
        elseif a then
            dest = a.pos or a
        end
        return Mover:Order(dest)
    end

    _G.Control.CastSpell = function(key, a, b, c)
        if a == nil then
            if Input:Busy() then return false end
            Input:Tap(key)
            return true
        end
        local at
        if type(a) == "number" then
            if type(b) == "number" and type(c) == "number" then
                at = { x = a, y = b, z = c }
            elseif type(b) == "number" then
                at = { x = a, y = b }
            end
        elseif a.pos or a.x then
            at = a
        end
        if not at then return false end
        return Input:Send(key, at)
    end

    _G.Control.Evade = function(a)
        if not a then return false end
        local dest = a.pos or a
        return Input:Send(MOUSEEVENTF_RIGHTDOWN, dest)
    end
end

_G.LevelUpKeyTimer = 0

Callback.Add("WndMsg", function(msg, wParam)
    if msg == HK_LUS or wParam == HK_LUS then
        _G.LevelUpKeyTimer = GetTickCount()
    end
    Selector:WndMsg(msg, wParam)
    for i = 1, #wndmsgs do
        wndmsgs[i](msg, wParam)
    end
end)

Callback.Add("Tick", function()
    Frame.n = Frame.n + 1
    Net:Refresh()
    local prof = ProfOn()
    local t = prof and CLOCK()
    World:Refresh()
    Walker:GetModes()
    Timing:Observe()
    local resetHook = Hooks.AttackReset
    if resetHook and resetHook() then
        Timing.reset = true
    end
    if prof then
        ProfAdd("world", t)
        t = CLOCK()
    end
    Selector:Refresh()
    if prof then
        ProfAdd("select", t)
        t = CLOCK()
    end
    Farm:Refresh()
    if prof then
        ProfAdd("farm", t)
        t = CLOCK()
    end
    for i = 1, #ticks do
        ticks[i]()
    end
    if prof then ProfAdd("champT", t) end
end)

Callback.Add("Draw", function()
    if World.frame < 0 then return end
    Frame.draw = Frame.draw + 1
    local prof = ProfOn()
    local t = prof and CLOCK()
    Input:OnTick()
    Timing:Observe()
    if prof then
        ProfAdd("input", t)
        t = CLOCK()
    end
    Walker:OnTick()
    if prof then
        ProfAdd("walk", t)
        t = CLOCK()
    end
    Walker:OnDraw()
    if prof then
        ProfAdd("ownD", t)
        t = CLOCK()
    end
    for i = 1, #draws do
        draws[i]()
    end
    if prof then
        ProfAdd("champD", t)
        ProfRoll(format("enemies %d lane %d jungle %d farm %d",
            World.enemyN or 0, World.laneN or 0, World.jungleN or 0, Farm.minionN or 0))
    end
end)

Callback.Add("UnLoad", function()
    Input:ReleaseTco()
end)

print("[LowkeyOrbwalker] v" .. __version__ .. " ready | " .. MY_NAME
    .. " | range " .. tostring(floor(MyAttackRange(nil)))
    .. " | ping " .. tostring(Net.ms) .. "ms")

return _G.SDK
