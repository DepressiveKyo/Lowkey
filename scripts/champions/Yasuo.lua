if _G.__LOWKEY_YASUO_LOADED then return end
_G.__LOWKEY_YASUO_LOADED = true
if myHero.charName ~= "Yasuo" then return end

local VERSION = "2.0"
local SCRIPT_NAME = "Lowkey Yasuo"

local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt
local math_modf = math.modf
local math_floor = math.floor
local pcall = pcall
local type = type
local tonumber = tonumber
local tostring = tostring
local string_format = string.format
local string_byte = string.byte
local string_find = string.find
local table_sort = table.sort

local Game = _G.Game
local Control = _G.Control
local Draw = _G.Draw

local GameTimer = Game.Timer
local GameCanUseSpell = Game.CanUseSpell
local GameIsChatOpen = Game.IsChatOpen
local GameLatency = Game.Latency
local GameResolution = Game.Resolution
local GameMissileCount = Game.MissileCount
local GameMissile = Game.Missile
local CastSpell = Control.CastSpell

local SQ, SW, SE, SR = _Q, _W, _E, _R
local HKQ = HK_Q or 0
local HKW = HK_W or 1
local HKE = HK_E or 2
local HKR = HK_R or 3
local SUM_1 = SUMMONER_1 or 4
local SUM_2 = SUMMONER_2 or 5
local HK_SUM_1 = HK_SUMMONER_1 or 4
local HK_SUM_2 = HK_SUMMONER_2 or 5

local TEAM_JUNGLE = 300

local DMG_PHYS = 0
local DMG_MAGIC = 1

local INVULN_TYPE = 18
local KNOCKUP_TYPE = 30
local KNOCKBACK_TYPE = 31

local KIT = {
    qRange = 475,
    qRadius = 40,
    qSpeed = math_huge,
    qDelayMax = 0.40,
    qDelayMin = 0.133,
    qASCap = 0.67,
    qBase = { 20, 45, 70, 95, 120 },
    qAD = 1.05,
    qCircle = 230,

    q3Range = 1100,
    q3Radius = 90,
    q3Speed = 1200,

    eRange = 475,
    eDash = 475,
    eSpeed = 750,
    eMsShare = 0.90,
    eBase = { 60, 70, 80, 90, 100 },
    eAD = 0.20,
    eAP = 0.60,
    eRamp = 0.25,
    eRampMax = 2,

    rRange = 1400,
    rBase = { 200, 350, 500 },
    rAD = 1.50,
    rArmorPen = 0.50,

    baseAS = 0.697,
    critBonus = 0.675,
    towerRange = 838.5,
    igniteRange = 600,
    wallProbe = 400,
    wallPassFrac = 0.70,
}

local Q_RANGE2 = KIT.qRange * KIT.qRange
local Q3_RANGE2 = KIT.q3Range * KIT.q3Range
local QCIRCLE2 = KIT.qCircle * KIT.qCircle

local F_ERAMP = 2
local F_SHIELD = 4
local F_KNOCK = 8
local F_QSTACK = 16

local BUFF_FLAG = {
    yasuodashscalar = F_ERAMP,
    yasuopassiveshield = F_SHIELD,
    yasuoq3stacks = F_QSTACK,
    yasuoq3mis = F_KNOCK,
    yasuoq3 = F_KNOCK,
    yasuorknockupcomboremove = F_KNOCK,
    yasuorknockup = F_KNOCK,
}

local Q3_WRAPPER = "YasuoQ3Wrapper"

local EMARK_NAMES = {
    yasuoe = true,
    yasuoedebuff = true,
    yasuodashwrapper = true,
}

local LIM = {
    emarkPart = "_E_timer",
    emarkOwner = "Yasuo",
    emarkSlack = 40,
    particleCap = 2048,
    partMemoCap = 4000,
    nameLogCap = 256,
    selfPartSqr = 22500,
    minionScan = 1200,
    stateScan = KIT.rRange + 200,
    nearScan = KIT.eRange + 125,
    turretSqr = 4000000,
    cellScale = 0.03030303,
    cellSize = 33,
    wjQuant = 64,
    wjSpread = 160,
}

local P_EMARK = 1
local P_SHIELD = 2
local P_QSTACK = 4
local P_ERAMP = 8

local SELF_PART = {
    { "Passive_Shield", P_SHIELD },
    { "_Q_stack", P_QSTACK },
    { "_E_stack", P_ERAMP },
}
local SELF_PART_N = 3

local DANGER = {
    RocketGrab = 10,
    ThreshQMissile = 10,
    EnchantedCrystalArrow = 10,
    MorganaQ = 10,
    FizzR = 10,
    VeigarR = 10,
    SyndraR = 10,
    UrgotR = 10,
    NautilusAnchorDragMissile = 9,
    SejuaniR = 9,
    LuxLightBinding = 9,
    AhriSeduce = 9,
    EliseHumanE = 9,
    BraumR = 9,
    VarusR = 9,
    PykeQRange = 9,
    ZoeE = 9,
    NautilusGrandLine = 9,
    LeonaZenithBlade = 8,
    NeekoE = 8,
    IreliaR = 8,
    LeblancE = 8,
    LeblancRE = 8,
    SylasE2 = 8,
    BandageToss = 8,
    BardQ = 8,
    NamiRMissile = 8,
    EzrealR = 8,
    JinxR = 8,
    DravenRCast = 8,
    HeimerdingerEUlt = 8,
    VayneCondemn = 8,
    GoldCardPreAttack = 8,
    BlindMonkQOne = 7,
    IvernQ = 7,
    HowlingGaleSpell = 7,
    GravesChargeShot = 7,
    FlashFrostSpell = 7,
    GragasR = 7,
    IllaoiE = 7,
    SennaR = 7,
    XerathMageSpear = 7,
    ZyraE = 7,
    AnnieQ = 7,
    TristanaR = 7,
    PoppyRSpell = 7,
    YasuoQ3Mis = 7,
    AatroxW = 7,
    ApheliosR = 7,
    ShyvanaFireballDragon2 = 7,
    FioraW = 7,
    NamiQ = 7,
    SyndraE = 7,
    CaitlynEntrapment = 6,
    JayceShockBlastWallMis = 6,
    KarmaQMantra = 6,
    RengarE = 6,
    SennaW = 6,
    ZoeQMis2 = 6,
    BrandQ = 6,
    BraumQ = 6,
    EkkoQ = 6,
    JhinRShot = 6,
    KledQ = 6,
    JavelinToss = 6,
    HeimerdingerE = 6,
    AkaliE = 6,
    DravenDoubleShot = 6,
    CamilleE = 6,
    FiddleSticksQ = 6,
    BrandR = 6,
    CaitlynPiltoverPeacemaker = 5,
    JinxWMissile = 5,
    KaisaW = 5,
    AhriOrbofDeception = 5,
    JayceShockBlast = 5,
    KarmaQ = 5,
    KennenShurikenHurlMissile1 = 5,
    LissandraQMissile = 5,
    ZedQ = 5,
    ZoeQMissile = 5,
    TalonW = 5,
    GnarBigQMissile = 5,
    PantheonQ = 5,
    QuinnQ = 5,
    RekSaiQBurrowed = 5,
    ShyvanaFireball = 5,
    SionE = 5,
    SkarnerFractureMissile = 5,
    TahmKenchQ = 5,
    VarusQMissile = 5,
    ViktorDeathRayMissile = 5,
    LuluWTwo = 5,
    MissileBarrageMissile2 = 5,
    RedCardPreAttack = 5,
    DianaQ = 5,
    Frostbite = 5,
    BlindingDart = 5,
    ApheliosCalibrumQ = 5,
    EzrealQ = 4,
    SivirQ = 4,
    Volley = 4,
    GragasQ = 4,
    LuluQ = 4,
    NeekoQ = 4,
    NocturneDuskbringer = 4,
    OlafAxeThrowCast = 4,
    RyzeQ = 4,
    VeigarBalefulStrike = 4,
    VelkozQ = 4,
    KogMawVoidOozeMissile = 4,
    GangplankQProceed = 4,
    KayleQ = 4,
    CassiopeiaE = 4,
    PhosphorusBomb = 4,
    MissileBarrageMissile = 4,
    InfectedCleaverMissile = 4,
    EliseHumanQ = 4,
    EvelynnQ = 4,
    GnarQMissile = 4,
    NullLance = 4,
    KalistaMysticShot = 4,
    KhazixW = 4,
    LeblancQ = 4,
    SeismicShard = 4,
    MaokaiQ = 4,
    MissFortuneRicochetShot = 4,
    RumbleGrenade = 4,
    TaliyahQMis = 4,
    WildCards = 4,
    XayahQ = 4,
    SowTheWind = 4,
    GalioQ = 4,
    GravesSmokeGrenade = 4,
    EzrealW = 3,
    NamiW = 3,
    KatarinaQ = 3,
    KogMawQ = 3,
    LissandraEMissile = 3,
    LucianW = 3,
    RyzeE = 3,
    TwoShivPoison = 3,
    VelkozW = 3,
    ZiggsQ = 3,
    RakanQ = 3,
    BlueCardPreAttack = 3,
}

local DANGER_NAMES = {}
local DANGER_COUNT = 0
for name in pairs(DANGER) do
    DANGER_COUNT = DANGER_COUNT + 1
    DANGER_NAMES[DANGER_COUNT] = name
end
table_sort(DANGER_NAMES)

local MODE_NONE, MODE_COMBO, MODE_HARASS, MODE_CLEAR, MODE_LASTHIT, MODE_FLEE = 0, 1, 2, 3, 4, 5

local TICK = 0
local NOW = 0

local S = {
    myX = 0, myY = 0, myZ = 0,
    hp = 1, maxHp = 1, hpPct = 1,
    ms = 325, br = 65,
    ad = 0, bonusAD = 0, ap = 0, crit = 0,
    aaRange = 175,
    qLv = 0, eLv = 0, rLv = 0,
    qR = false, wR = false, eR = false, rR = false,
    qCd = 0, wCd = 0, eCd = 0, rCd = 0,
    qDelay = 0.40,
    hasQ3 = false,
    qStacks = 0,
    eRampStacks = 0,
    shield = false,
    flowPct = 0,
    dashing = false,
    casting = false,
    towerSqr = 0,
    shieldPart = false,
    qStackPart = 0,
    eRampPart = 0,
    mode = MODE_NONE,
    lat = 0.03,
    eDelay = 0.30,
    nearE = 0,
    nearA = 0,
}

local EHo, EHx, EHz, EHd, EHbr = {}, {}, {}, {}, {}
local EHh, EHhp, EHknock, EHmark, EHinvuln = {}, {}, {}, {}, {}
local EHn, EHhigh = 0, 0

local CMo, CMx, CMz, CMbr = {}, {}, {}, {}
local CMpx, CMpz, CMps = {}, {}, {}
local CMn, CMhigh = 0, 0

local JMo, JMx, JMz, JMbr = {}, {}, {}, {}
local JMn, JMhigh = 0, 0

local EMX, EMZ = {}, {}
local EMn = 0

local PartIsMark = {}
local PartSeen = 0
local PartNameSeen = {}
local PartNameN = 0

local DUo, DUx, DUz, DUsafe, DUwall, DUhero = {}, {}, {}, {}, {}, {}
local DUn, DUhigh = 0, 0

local TTx, TTz = {}, {}
local TTn = 0

local MissileThreat = {}
local MissileSeen = 0

local MEMO = {
    cx = nil, cz = nil, hit = false,
    rank = {}, stamp = {},
    missSeen = {}, missN = 0,
}

local PQs, PQx, PQz = {}, {}, {}
local P3s, P3x, P3z = {}, {}, {}
local DMs, DMv = {}, {}

local MapPos = nil
local tsTick = -1
local tsIdx = 0

local qHeld = false
local attackOn = nil
local dumpHeld = false
local wjDraw = false
local seenBuff = {}
local seenBuffN = 0
local cursorBackX, cursorBackY = nil, nil

local Pos = { x = 0, y = 0, z = 0 }
local PendUntil = {}
local SentTick = {}

local Menu = MenuElement({ type = MENU, id = "LowkeyYasuo", name = "Lowkey Yasuo" })
Menu:MenuElement({ name = " ", drop = { "The Wind Samurai v" .. VERSION } })

Menu:MenuElement({ type = MENU, id = "combo", name = "Combo" })
Menu.combo:MenuElement({ id = "useQ", name = "Use Q1/Q2", value = true })
Menu.combo:MenuElement({ id = "useQ3", name = "Use Q3", value = true })
Menu.combo:MenuElement({ id = "useE", name = "Use E", value = true })
Menu.combo:MenuElement({ id = "eMode", name = "E logic", value = 3, drop = { "Towards target", "Towards cursor", "Smart" } })
Menu.combo:MenuElement({ id = "eGapRange", name = "E gap close range", value = 900, min = 475, max = 1800, step = 25 })
Menu.combo:MenuElement({ id = "noETower", name = "Do not E into tower", value = true })
Menu.combo:MenuElement({ id = "qInDash", name = "Q while dashing", value = true })
Menu.combo:MenuElement({ id = "eEngage", name = "E engage through minions", value = true })
Menu.combo:MenuElement({ id = "stackQ", name = "Stack Q on minions with no target", value = true })
Menu.combo:MenuElement({ id = "eMarkBySource", name = "E mark fallback: any buff of mine", value = false })

Menu.combo:MenuElement({ type = MENU, id = "ign", name = "Ignite" })
Menu.combo.ign:MenuElement({ id = "use", name = "Use ignite", value = true })
Menu.combo.ign:MenuElement({ id = "mode", name = "Mode", value = 2, drop = { "Kill steal only", "In fight if killable" } })

Menu.combo:MenuElement({ type = MENU, id = "trade", name = "Trade optimizer" })
Menu.combo.trade:MenuElement({ id = "enable", name = "Enable", value = true })
Menu.combo.trade:MenuElement({ id = "shield", name = "Prefer trading with flow shield", value = true })
Menu.combo.trade:MenuElement({ id = "flowPct", name = "Min flow% to engage", value = 80, min = 0, max = 100, step = 5, identifier = "%" })
Menu.combo.trade:MenuElement({ id = "antiGank", name = "Limit E if outnumbered", value = true })

Menu:MenuElement({ type = MENU, id = "ult", name = "Ultimate" })
Menu.ult:MenuElement({ id = "team", name = "R on airborne", value = true })
Menu.ult:MenuElement({ id = "teamMin", name = "Min enemies airborne", value = 2, min = 1, max = 5 })
Menu.ult:MenuElement({ id = "airblade", name = "Airblade: E towards airborne then R", value = true })
Menu.ult:MenuElement({ id = "noRDash", name = "Do not R while dashing", value = true })

Menu:MenuElement({ type = MENU, id = "harass", name = "Harass" })
Menu.harass:MenuElement({ id = "useQ", name = "Use Q1/Q2", value = true })
Menu.harass:MenuElement({ id = "useQ3", name = "Use Q3", value = true })
Menu.harass:MenuElement({ id = "stackQ", name = "Stack Q on minions", value = true })

Menu:MenuElement({ type = MENU, id = "clear", name = "Lane and jungle clear" })
Menu.clear:MenuElement({ id = "useQ", name = "Use Q1/Q2", value = true })
Menu.clear:MenuElement({ id = "useQ3", name = "Use Q3", value = true })
Menu.clear:MenuElement({ id = "q3Min", name = "Min minions for Q3", value = 3, min = 1, max = 7 })
Menu.clear:MenuElement({ id = "useE", name = "Use E", value = true })
Menu.clear:MenuElement({ id = "eLH", name = "E logic", value = 1, drop = { "Last hit only", "Always" } })
Menu.clear:MenuElement({ id = "noETower", name = "Do not E into tower", value = true })

Menu:MenuElement({ type = MENU, id = "lasthit", name = "Last hit" })
Menu.lasthit:MenuElement({ id = "useQ", name = "Use Q1/Q2", value = true })
Menu.lasthit:MenuElement({ id = "useE", name = "Use E", value = true })
Menu.lasthit:MenuElement({ id = "noETower", name = "Do not E into tower", value = true })

Menu:MenuElement({ type = MENU, id = "flee", name = "Flee" })
Menu.flee:MenuElement({ id = "useE", name = "Use E to flee", value = true })
Menu.flee:MenuElement({ id = "noETower", name = "Do not E into tower", value = true })
Menu.flee:MenuElement({ id = "useQ3", name = "Use Q3 while fleeing", value = true })
Menu.flee:MenuElement({ id = "useQ", name = "Use Q1/Q2 while fleeing", value = true })

Menu:MenuElement({ type = MENU, id = "walljump", name = "Wall jump" })
Menu.walljump:MenuElement({ id = "key", name = "Wall jump key", key = string_byte("Z") })
Menu.walljump:MenuElement({ id = "range", name = "Cursor search radius", value = 350, min = 100, max = 900, step = 25 })
Menu.walljump:MenuElement({ id = "push", name = "Allow push through wall", value = true })
Menu.walljump:MenuElement({ id = "draw", name = "Show wall jump indicator", value = true })

Menu:MenuElement({ type = MENU, id = "windwall", name = "Wind wall" })
Menu.windwall:MenuElement({ id = "enable", name = "Auto wind wall", value = true })
Menu.windwall:MenuElement({ id = "onlyCombo", name = "Only in combo", value = false })
Menu.windwall:MenuElement({ id = "minThreat", name = "Min threat to block", value = 5, min = 1, max = 10 })
Menu.windwall:MenuElement({ id = "hpSafe", name = "Always block below HP%", value = 40, min = 5, max = 100, step = 5, identifier = "%" })
Menu.windwall:MenuElement({ type = MENU, id = "spells", name = "Spells to block" })
for i = 1, DANGER_COUNT do
    local nm = DANGER_NAMES[i]
    Menu.windwall.spells:MenuElement({ id = nm, name = nm, value = true })
end

Menu:MenuElement({ type = MENU, id = "pred", name = "Prediction" })
Menu.pred:MenuElement({ name = " ", drop = { "Engine: GGPrediction" } })
Menu.pred:MenuElement({ id = "hcQ", name = "Hitchance Q", value = 1, drop = { "Normal", "High", "Immobile" } })
Menu.pred:MenuElement({ id = "hcQ3", name = "Hitchance Q3", value = 2, drop = { "Normal", "High", "Immobile" } })

Menu:MenuElement({ type = MENU, id = "debug", name = "Debug" })
Menu.debug:MenuElement({ id = "watch", name = "Print each new buff name once", value = false })
Menu.debug:MenuElement({ id = "dumpKey", name = "Dump every buff now", key = string_byte("J") })
Menu.debug:MenuElement({ id = "particles", name = "Also dump particles near units", value = false })
Menu.debug:MenuElement({ id = "partNames", name = "Log new particle names with Yasuo", value = false })
Menu.debug:MenuElement({ id = "missNames", name = "Log unknown enemy missile names", value = false })

Menu:MenuElement({ type = MENU, id = "draw", name = "Drawings" })
Menu.draw:MenuElement({ id = "enable", name = "Enable drawings", value = true })
Menu.draw:MenuElement({ id = "qRange", name = "Q range", value = true })
Menu.draw:MenuElement({ id = "q3Range", name = "Q3 range", value = true })
Menu.draw:MenuElement({ id = "eRange", name = "E range", value = true })
Menu.draw:MenuElement({ id = "eGap", name = "E gap close range", value = false })
Menu.draw:MenuElement({ id = "rRange", name = "R range", value = false })
Menu.draw:MenuElement({ id = "killable", name = "Kill indicator", value = true })
Menu.draw:MenuElement({ id = "flow", name = "Flow shield status", value = true })
Menu.draw:MenuElement({ id = "qStacks", name = "Q stacks", value = true })
Menu.draw:MenuElement({ id = "eDashPos", name = "E dash positions", value = true })
Menu.draw:MenuElement({ id = "panel", name = "Status panel", value = true })

local function DistSqr(ax, az, bx, bz)
    local dx, dz = ax - bx, az - bz
    return dx * dx + dz * dz
end

local function Whole(v)
    if type(v) ~= "number" or v ~= v or v < -32000 or v > 32000 then return nil end
    return math_floor(v)
end

local function Warp(x, y)
    local wx, wy = Whole(x), Whole(y)
    if wx == nil or wy == nil then return false end
    Control.SetCursorPos(wx, wy)
    return true
end

local function SaveCursor()
    if cursorBackX then return end
    local cp = _G.cursorPos
    if cp == nil then return end
    local bx, by = Whole(cp.x), Whole(cp.y)
    if bx == nil or by == nil then return end
    cursorBackX, cursorBackY = bx, by
end

local function RestoreCursor()
    if cursorBackX == nil then return end
    local bx, by = cursorBackX, cursorBackY
    cursorBackX, cursorBackY = nil, nil
    Warp(bx, by)
end

local function MouseXZ()
    local mp = _G.mousePos
    if mp == nil then mp = Game.mousePos end
    if mp == nil then return nil, nil end
    local x, z = mp.x, mp.z
    if type(x) ~= "number" or type(z) ~= "number" then return nil, nil end
    return x, z
end

local function AckWindow()
    return S.lat * 4 + 0.30
end

local function SlotFree(slot)
    local deadline = PendUntil[slot]
    if deadline == nil then return true end
    if GameCanUseSpell(slot) ~= 0 then
        PendUntil[slot] = nil
        return true
    end
    if NOW >= deadline then
        PendUntil[slot] = nil
        return true
    end
    return false
end

local function MarkSent(slot)
    PendUntil[slot] = NOW + AckWindow()
    SentTick[slot] = TICK
end

local function SendAt(hk, slot, x, z)
    if type(x) ~= "number" or x ~= x then return false end
    if type(z) ~= "number" or z ~= z then return false end
    if not SlotFree(slot) then return false end
    Pos.x, Pos.y, Pos.z = x, S.myY, z
    SaveCursor()
    if CastSpell(hk, Pos) == false then
        RestoreCursor()
        return false
    end
    MarkSent(slot)
    return true
end

local function SendAtUnit(hk, slot, unit)
    if unit == nil then return false end
    local p2 = unit.pos2D
    if p2 == nil or p2.onScreen ~= true then return false end
    local p = unit.pos
    if p == nil then return false end
    if not SlotFree(slot) then return false end
    SaveCursor()
    if CastSpell(hk, p) == false then
        RestoreCursor()
        return false
    end
    MarkSent(slot)
    return true
end

local function SafeCd(sd)
    local v = sd and sd.currentCd
    if type(v) ~= "number" or v ~= v or v < 0 or v > 1000 then return 0 end
    return v
end

local CdTotal = {}
local CdStart = {}
local CdBusy = {}

local function CdSane(x)
    return type(x) == "number" and x == x and x >= 0 and x <= 1000
end

local function PanelCd(sd, slot)
    local key = sd and sd.name
    if key == nil then return 0 end

    local total = sd.cd
    if CdSane(total) and total > 0 then CdTotal[key] = total end

    if GameCanUseSpell(slot) == 0 then
        if CdBusy[key] then
            local started = CdStart[key]
            if started and NOW > started then CdTotal[key] = NOW - started end
            CdBusy[key] = false
        end
        return 0
    end

    if not CdBusy[key] then
        CdBusy[key] = true
        CdStart[key] = NOW
    end

    local cur = sd.currentCd
    if CdSane(cur) then return cur end

    local t, s = CdTotal[key], CdStart[key]
    if t == nil or s == nil then return 0 end
    local left = s + t - NOW
    if left <= 0 then return 0 end
    return left
end

local function IsValid(unit)
    if unit == nil or not unit.valid or not unit.visible then return false end
    if unit.dead or not unit.isTargetable then return false end
    local hp = unit.health
    return hp ~= nil and hp > 0
end

local function IsValidUnit(unit)
    if unit == nil or not unit.valid or unit.dead then return false end
    if not unit.isTargetable then return false end
    local hp = unit.health
    return hp ~= nil and hp > 0
end

local function ShouldWait()
    if myHero.dead or GameIsChatOpen() then return true end
    local je = _G.JustEvade
    if je and je.Evading and je:Evading() then return true end
    local ee = _G.ExtLibEvade
    if ee and ee.Evading then return true end
    return false
end

local function OrbMode()
    local sdk = _G.SDK
    if not sdk or not sdk.Orbwalker or not sdk.Orbwalker.Modes then return MODE_NONE end
    local m = sdk.Orbwalker.Modes
    if m[sdk.ORBWALKER_MODE_COMBO] then return MODE_COMBO end
    if m[sdk.ORBWALKER_MODE_HARASS] then return MODE_HARASS end
    if m[sdk.ORBWALKER_MODE_LANECLEAR] then return MODE_CLEAR end
    if m[sdk.ORBWALKER_MODE_JUNGLECLEAR] then return MODE_CLEAR end
    if m[sdk.ORBWALKER_MODE_LASTHIT] then return MODE_LASTHIT end
    if m[sdk.ORBWALKER_MODE_FLEE] then return MODE_FLEE end
    return MODE_NONE
end

local function CanMove()
    local sdk = _G.SDK
    local ow = sdk and sdk.Orbwalker
    if ow and ow.CanMove then return ow:CanMove(myHero) ~= false end
    return true
end

local function AllowAttack(on)
    if attackOn == on then return end
    local sdk = _G.SDK
    local ow = sdk and sdk.Orbwalker
    if ow and ow.SetAttack then ow:SetAttack(on) end
    attackOn = on
end

local function IsCasting()
    local cast = myHero.activeSpell
    if cast == nil or cast.valid ~= true then return false end
    local a, b = cast.startTime, cast.castEndTime
    if type(a) ~= "number" or type(b) ~= "number" then return false end
    return NOW >= a and NOW <= b
end

local function Mitigate(target, kind, raw)
    if raw <= 0 then return 0 end
    local sdk = _G.SDK
    local dmg = sdk and sdk.Damage
    if dmg and dmg.CalculateDamage then
        local ok, v = pcall(dmg.CalculateDamage, dmg, myHero, target, kind, raw)
        if ok and type(v) == "number" then return v end
    end
    local res = (kind == DMG_PHYS and target.armor or target.magicResist) or 0
    if res >= 0 then return raw * 100 / (100 + res) end
    return raw * (2 - 100 / (100 - res))
end

local function MitigatePen(target, raw, pen)
    if raw <= 0 then return 0 end
    local res = (target.armor or 0) * (1 - pen)
    if res >= 0 then return raw * 100 / (100 + res) end
    return raw * (2 - 100 / (100 - res))
end

local function HasFlag(flags, flag)
    return flags % (flag * 2) >= flag
end

local function BuffList(unit)
    local sdk = _G.SDK
    local c = sdk and sdk.Cached
    if c and c.GetBuffs then
        local ok, list = pcall(c.GetBuffs, c, unit)
        if ok and type(list) == "table" then return list end
    end
    return nil
end

local function Lower(s)
    if type(s) ~= "string" then return nil end
    return s:lower()
end

local function ScanUnit(unit)
    local knock, invuln, flags, ramp, qst = false, false, 0, 0, 0
    local buffs = BuffList(unit)
    if buffs then
        for i = 1, #buffs do
            local b = buffs[i]
            local t = b.type
            if t == KNOCKUP_TYPE or t == KNOCKBACK_TYPE then
                knock = true
            elseif t == INVULN_TYPE then
                invuln = true
            end
            local f = BUFF_FLAG[Lower(b.name)]
            if f then
                local c = tonumber(b.count) or 0
                if c > 0 then
                    if f == F_KNOCK then
                        knock = true
                    elseif f == F_ERAMP then
                        ramp = c
                    elseif f == F_QSTACK then
                        qst = c
                    else
                        flags = flags + f
                    end
                end
            end
        end
        return knock, invuln, flags, ramp, qst
    end
    local total = unit.buffCount
    if type(total) ~= "number" then return knock, invuln, flags, ramp, qst end
    for i = 0, total - 1 do
        local b = unit:GetBuff(i)
        if b then
            local c = tonumber(b.count) or 0
            if c > 0 then
                local t = b.type
                if t == KNOCKUP_TYPE or t == KNOCKBACK_TYPE then
                    knock = true
                elseif t == INVULN_TYPE then
                    invuln = true
                end
                local f = BUFF_FLAG[Lower(b.name)]
                if f then
                    if f == F_KNOCK then
                        knock = true
                    elseif f == F_ERAMP then
                        ramp = c
                    elseif f == F_QSTACK then
                        qst = c
                    else
                        flags = flags + f
                    end
                end
            end
        end
    end
    return knock, invuln, flags, ramp, qst
end

local function SourceIsMine(b)
    local nid = b.sourcenID
    if nid ~= nil and nid == myHero.networkID then return true end
    local nm = b.sourceName
    if type(nm) == "string" and nm ~= "" and nm == myHero.charName then return true end
    return false
end

local function AnyDashable()
    local base = KIT.eRange
    local mx, mz = S.myX, S.myZ
    for i = 1, CMn do
        local r = base + CMbr[i]
        if DistSqr(CMx[i], CMz[i], mx, mz) <= r * r then return true end
    end
    for i = 1, JMn do
        local r = base + JMbr[i]
        if DistSqr(JMx[i], JMz[i], mx, mz) <= r * r then return true end
    end
    for i = 1, EHn do
        local r = base + EHbr[i]
        if DistSqr(EHx[i], EHz[i], mx, mz) <= r * r then return true end
    end
    return false
end

local function PartOwnerLabel(px, pz)
    for k = 1, EHn do
        if DistSqr(px, pz, EHx[k], EHz[k]) <= 160000 then
            return EHo[k].charName or "hero"
        end
    end
    for k = 1, CMn do
        if DistSqr(px, pz, CMx[k], CMz[k]) <= 40000 then return "minion" end
    end
    for k = 1, JMn do
        if DistSqr(px, pz, JMx[k], JMz[k]) <= 40000 then return "monster" end
    end
    if DistSqr(px, pz, S.myX, S.myZ) <= LIM.selfPartSqr then return "MYSELF" end
    return nil
end

local function ClassifyParticle(nm)
    if nm == nil then return 0 end
    if string_find(nm, LIM.emarkOwner, 1, true) == nil then return 0 end
    if string_find(nm, LIM.emarkPart, 1, true) ~= nil then return P_EMARK end
    for i = 1, SELF_PART_N do
        local e = SELF_PART[i]
        if string_find(nm, e[1], 1, true) ~= nil then return e[2] end
    end
    return 0
end

local function ScanParticles()
    EMn = 0
    local mode = S.mode
    local needSelf = mode == MODE_COMBO or mode == MODE_HARASS
    local needMark = S.eR and AnyDashable()
    local needNames = Menu.debug.partNames:Value() == true
    if needSelf then
        S.shieldPart = false
        S.qStackPart = 0
        S.eRampPart = 0
    end
    if not needMark and not needSelf and not needNames then return end
    if type(Game.ParticleCount) ~= "function" or type(Game.Particle) ~= "function" then return end
    local total = Game.ParticleCount()
    if type(total) ~= "number" or total <= 0 then return end
    local cap = LIM.particleCap
    if total > cap then total = cap end
    if PartSeen > LIM.partMemoCap then
        PartIsMark = {}
        PartSeen = 0
    end
    local n = 0
    local mx, mz = S.myX, S.myZ
    local selfSqr = LIM.selfPartSqr
    for i = 1, total do
        local p = Game.Particle(i)
        if p then
            local id = p.networkID
            local code
            if id ~= nil then code = PartIsMark[id] end
            if code == nil then
                local nm = p.name
                code = ClassifyParticle(nm)
                if id ~= nil then
                    PartIsMark[id] = code
                    PartSeen = PartSeen + 1
                end
                if needNames and nm ~= nil and PartNameSeen[nm] == nil
                    and string_find(nm, LIM.emarkOwner, 1, true) ~= nil then
                    if PartNameN > LIM.nameLogCap then
                        PartNameSeen = {}
                        PartNameN = 0
                    end
                    PartNameSeen[nm] = true
                    PartNameN = PartNameN + 1
                    local pos = p.pos
                    print(string_format("[%s] PNAME %q code=%d on=%s", SCRIPT_NAME, nm, code,
                        (pos and PartOwnerLabel(pos.x, pos.z)) or "far"))
                end
            end
            if code == P_EMARK then
                if needMark then
                    local pos = p.pos
                    if pos then
                        n = n + 1
                        EMX[n], EMZ[n] = pos.x, pos.z
                    end
                end
            elseif code ~= 0 and needSelf then
                local pos = p.pos
                if pos and DistSqr(pos.x, pos.z, mx, mz) <= selfSqr then
                    if code == P_SHIELD then
                        S.shieldPart = true
                    elseif code == P_QSTACK then
                        S.qStackPart = S.qStackPart + 1
                    else
                        S.eRampPart = S.eRampPart + 1
                    end
                end
            end
        end
    end
    EMn = n
    if not needSelf then return end
    if S.shieldPart then S.shield = true end
    if S.qStackPart > 0 and S.qStacks == 0 then S.qStacks = S.qStackPart end
    if S.eRampPart > 0 and S.eRampStacks == 0 then
        S.eRampStacks = math_min(S.eRampPart, KIT.eRampMax)
    end
end

local function MarkedByParticle(ux, uz, br)
    if EMn == 0 then return false end
    local reach = br + LIM.emarkSlack
    local rs = reach * reach
    for i = 1, EMn do
        if DistSqr(ux, uz, EMX[i], EMZ[i]) <= rs then return true end
    end
    return false
end

local function MineAndOwned(b, name)
    if type(name) ~= "string" then return false end
    if string_find(name, LIM.emarkOwner, 1, true) == nil then return false end
    local t = b.type
    if t == KNOCKUP_TYPE or t == KNOCKBACK_TYPE then return false end
    return SourceIsMine(b)
end

local function MarkedByBuff(unit, bySource)
    local sourced = false
    local buffs = BuffList(unit)
    if buffs then
        for i = 1, #buffs do
            local b = buffs[i]
            local n = b.name
            if n ~= nil and EMARK_NAMES[Lower(n)] and (tonumber(b.count) or 1) > 0 then
                return true
            end
            if bySource and not sourced and MineAndOwned(b, n) then sourced = true end
        end
        return sourced
    end
    local total = unit.buffCount
    if type(total) ~= "number" then return false end
    for i = 0, total - 1 do
        local b = unit:GetBuff(i)
        if b then
            local n = b.name
            if n ~= nil and EMARK_NAMES[Lower(n)] and (tonumber(b.count) or 1) > 0 then
                return true
            end
            if bySource and not sourced and MineAndOwned(b, n) then sourced = true end
        end
    end
    return sourced
end

local function MarkedByE(unit, ux, uz, br)
    if MarkedByParticle(ux, uz, br) then return true end
    return MarkedByBuff(unit, Menu.combo.eMarkBySource:Value() == true)
end

local function SyncSelf()
    local p = myHero.pos
    S.myX, S.myY, S.myZ = p.x, p.y, p.z
    S.hp = myHero.health
    S.maxHp = math_max(myHero.maxHealth or 1, 1)
    S.hpPct = S.hp / S.maxHp
    S.ms = math_max(myHero.ms or 325, 1)
    S.br = myHero.boundingRadius or 65
    S.ad = math_max(myHero.totalDamage or 0, 0)
    S.bonusAD = math_max(myHero.bonusDamage or 0, 0)
    S.ap = math_max(myHero.ap or 0, 0)
    S.crit = math_min(math_max(myHero.critChance or 0, 0), 1)
    S.aaRange = (myHero.range or 175) + S.br
    S.lat = ((GameLatency and GameLatency()) or 30) * 0.0005

    local q = myHero:GetSpellData(SQ)
    local w = myHero:GetSpellData(SW)
    local e = myHero:GetSpellData(SE)
    local r = myHero:GetSpellData(SR)

    S.qLv, S.eLv, S.rLv = q.level, e.level, r.level
    S.qCd = PanelCd(q, SQ)
    S.qR = SafeCd(q) == 0 and q.level > 0 and GameCanUseSpell(SQ) == 0
    S.wCd = PanelCd(w, SW)
    S.wR = SafeCd(w) == 0 and w.level > 0 and GameCanUseSpell(SW) == 0
    S.eCd = PanelCd(e, SE)
    S.eR = e.level > 0 and GameCanUseSpell(SE) == 0
    S.rCd = PanelCd(r, SR)
    S.rR = SafeCd(r) == 0 and r.level > 0 and GameCanUseSpell(SR) == 0
    S.hasQ3 = q.name == Q3_WRAPPER

    local as = myHero.attackSpeed or KIT.baseAS
    local bonus = math_max(0, as / KIT.baseAS - 1)
    local delay = math_max(KIT.qDelayMin, KIT.qDelayMax * (1 - math_min(bonus, KIT.qASCap)))
    local cast = myHero.activeSpell
    if cast and cast.valid == true and type(cast.windup) == "number" and cast.windup > 0 then
        local nm = cast.name
        if nm == "YasuoQ1" or nm == "YasuoQ2" or nm == "YasuoQ3" then
            delay = cast.windup
        end
    end
    S.qDelay = delay

    local path = myHero.pathing
    S.dashing = path ~= nil and path.isDashing == true
    S.casting = IsCasting()
    S.mode = OrbMode()

    local flow = myHero.maxMana
    S.flowPct = (flow and flow > 0 and myHero.mana / flow * 100) or 0

    local _, _, flags, ramp, qst = ScanUnit(myHero)
    S.shield = HasFlag(flags, F_SHIELD)
    S.eRampStacks = ramp
    S.qStacks = qst

    local ammo = tonumber(q.ammo)
    if ammo and ammo > 0 and ammo <= 2 and S.qStacks == 0 then S.qStacks = ammo end

    S.eDelay = KIT.eDash / (KIT.eSpeed + S.ms * KIT.eMsShare) + S.lat
end

local function SyncEnemies()
    local sdk = _G.SDK
    local w = sdk and sdk.Snapshot
    local n, near, allies = 0, 0, 0
    local mx, mz = S.myX, S.myZ
    local stateScan = LIM.stateScan

    if w then
        for i = 1, (w.enemyN or 0) do
            local h = w.enemy[i]
            if IsValid(h) then
                local p = h.pos
                n = n + 1
                EHo[n] = h
                EHh[n] = h.handle
                EHx[n], EHz[n] = p.x, p.z
                local d = h.distance
                if type(d) ~= "number" then
                    d = math_sqrt(DistSqr(p.x, p.z, mx, mz))
                end
                EHd[n] = d
                EHbr[n] = h.boundingRadius or 0
                EHhp[n] = h.health
                if d <= stateScan then
                    local knock, invuln = ScanUnit(h)
                    EHknock[n] = knock
                    EHinvuln[n] = invuln
                else
                    EHknock[n] = false
                    EHinvuln[n] = false
                end
                if d <= KIT.rRange then near = near + 1 end
            end
        end
        for i = 1, (w.allyN or 0) do
            local a = w.ally[i]
            if a ~= myHero and IsValid(a) then
                local p = a.pos
                if DistSqr(p.x, p.z, mx, mz) <= 1960000 then allies = allies + 1 end
            end
        end
    end

    for i = n + 1, EHhigh do EHo[i] = nil end
    EHhigh = n
    EHn = n
    S.nearE = near
    S.nearA = allies
end

local function SyncMarks()
    for i = 1, EHn do
        EHmark[i] = EHd[i] <= KIT.rRange and MarkedByE(EHo[i], EHx[i], EHz[i], EHbr[i]) or false
    end
end

local function SyncMinions()
    local sdk = _G.SDK
    local w = sdk and sdk.Snapshot
    local scan = (S.mode == MODE_CLEAR and LIM.minionScan) or LIM.nearScan
    local scan2 = scan * scan
    local mx, mz = S.myX, S.myZ
    local n, m = 0, 0

    if w then
        for i = 1, (w.laneN or 0) do
            local u = w.lane[i]
            if u then
                local inside
                local d = u.distance
                if type(d) == "number" then
                    inside = d <= scan
                else
                    local p = u.pos
                    inside = p ~= nil and DistSqr(p.x, p.z, mx, mz) <= scan2
                end
                if inside and u.team ~= TEAM_JUNGLE and IsValidUnit(u) then
                    local p = u.pos
                    if p then
                        n = n + 1
                        CMo[n] = u
                        CMx[n], CMz[n] = p.x, p.z
                        CMbr[n] = u.boundingRadius or 0
                    end
                end
            end
        end
        for i = 1, (w.jungleN or 0) do
            local u = w.jungle[i]
            if u then
                local inside
                local d = u.distance
                if type(d) == "number" then
                    inside = d <= scan
                else
                    local p = u.pos
                    inside = p ~= nil and DistSqr(p.x, p.z, mx, mz) <= scan2
                end
                if inside and IsValidUnit(u) then
                    local p = u.pos
                    if p then
                        m = m + 1
                        JMo[m] = u
                        JMx[m], JMz[m] = p.x, p.z
                        JMbr[m] = u.boundingRadius or 60
                    end
                end
            end
        end
    end

    for i = n + 1, CMhigh do CMo[i] = nil end
    CMhigh = n
    CMn = n
    for i = m + 1, JMhigh do JMo[i] = nil end
    JMhigh = m
    JMn = m
end

local function SyncTurrets()
    local sdk = _G.SDK
    local om = sdk and sdk.ObjectManager
    local n = 0
    if om and om.GetEnemyTurrets then
        local ok, list = pcall(om.GetEnemyTurrets, om)
        if ok and type(list) == "table" then
            local mx, mz = S.myX, S.myZ
            for i = 1, #list do
                local t = list[i]
                if t and not t.dead then
                    local p = t.pos
                    if p and DistSqr(p.x, p.z, mx, mz) <= LIM.turretSqr then
                        n = n + 1
                        TTx[n], TTz[n] = p.x, p.z
                    end
                end
            end
        end
    end
    TTn = n
    local r = KIT.towerRange + S.br * 0.5
    S.towerSqr = r * r
end

local function SafeFromTurrets(x, z)
    if TTn == 0 then return true end
    local rs = S.towerSqr
    for i = 1, TTn do
        if DistSqr(x, z, TTx[i], TTz[i]) < rs then return false end
    end
    return true
end

local WALL_PROBE = { x = 0, y = 0, z = 0 }

local function WallMap()
    if MapPos then return MapPos end
    MapPos = _G.MapPosition
    if not MapPos then
        pcall(require, "MapPositionGOS")
        MapPos = _G.MapPosition
    end
    return MapPos
end

local function CellWall(map, cx, cz)
    if cx == MEMO.cx and cz == MEMO.cz then return MEMO.hit end
    WALL_PROBE.x, WALL_PROBE.z = cx, cz
    local ok, hit = pcall(map.inWall, map, WALL_PROBE, true)
    if not ok then hit = false end
    hit = hit ~= nil and hit ~= false and hit ~= 0
    MEMO.cx, MEMO.cz, MEMO.hit = cx, cz, hit
    return hit
end

local function ScanWall(dx, dz)
    local map = WallMap()
    if not map then return false end

    local size = LIM.cellSize
    local px, pz = S.myX, S.myZ
    local cx = math_modf(px * LIM.cellScale)
    local cz = math_modf(pz * LIM.cellScale)

    local stepX = (dx > 0 and 1) or (dx < 0 and -1) or 0
    local stepZ = (dz > 0 and 1) or (dz < 0 and -1) or 0

    local tMaxX, tDeltaX = math_huge, math_huge
    if stepX ~= 0 then
        local edge = (stepX > 0 and (cx + 1) or cx) * size
        tMaxX = (edge - px) / dx
        tDeltaX = size / (dx < 0 and -dx or dx)
    end

    local tMaxZ, tDeltaZ = math_huge, math_huge
    if stepZ ~= 0 then
        local edge = (stepZ > 0 and (cz + 1) or cz) * size
        tMaxZ = (edge - pz) / dz
        tDeltaZ = size / (dz < 0 and -dz or dz)
    end

    if tDeltaX == math_huge and tDeltaZ == math_huge then return false end

    local land = KIT.eDash
    local limit = land + KIT.wallProbe
    local t, enter, leave = 0, -1, -1

    while t < limit do
        if enter < 0 and t >= land then return false end
        local hit = CellWall(map, cx, cz)
        if hit then
            if enter < 0 then
                if t <= 0 then return false end
                enter = t
            end
        elseif enter >= 0 then
            leave = t
            break
        end
        if tMaxX < tMaxZ then
            t = tMaxX
            cx = cx + stepX
            tMaxX = tMaxX + tDeltaX
        else
            t = tMaxZ
            cz = cz + stepZ
            tMaxZ = tMaxZ + tDeltaZ
        end
    end

    if enter < 0 or enter >= land then return false end
    if leave < 0 then return false end
    if leave <= land then return 1 end
    if land - enter > (leave - enter) * KIT.wallPassFrac then return 2 end
    return false
end

local function DashCrossesWall(ex, ez)
    if not WallMap() then return false end
    local dx, dz = ex - S.myX, ez - S.myZ
    local len = math_sqrt(dx * dx + dz * dz)
    if len < 1 then return false end
    dx, dz = dx / len, dz / len
    local q = LIM.wjQuant
    local key = (math_modf(dx * q) + q) * LIM.wjSpread + math_modf(dz * q) + q
    local stamp, rankOf = MEMO.stamp, MEMO.rank
    if stamp[key] == TICK then return rankOf[key] end
    local rank = ScanWall(dx, dz)
    stamp[key] = TICK
    rankOf[key] = rank
    return rank
end

local EBlk = {}
local EBlkN = 0

local function ClearEBlock()
    if EBlkN == 0 then return end
    EBlk = {}
    EBlkN = 0
end

local function BlockE(unit)
    local h = unit.handle
    if h == nil or EBlk[h] ~= nil then return end
    EBlk[h] = true
    EBlkN = EBlkN + 1
end

local function IsEBlocked(unit)
    if EBlkN == 0 then return false end
    local h = unit.handle
    return h ~= nil and EBlk[h] ~= nil
end

local function PushDash(n, unit, ux, uz, isHero, needWall, marked)
    if marked then return n end
    local dx, dz = ux - S.myX, uz - S.myZ
    local len = math_sqrt(dx * dx + dz * dz)
    if len < 1 then return n end
    local ex = S.myX + dx / len * KIT.eDash
    local ez = S.myZ + dz / len * KIT.eDash
    n = n + 1
    DUo[n] = unit
    DUx[n], DUz[n] = ex, ez
    DUsafe[n] = SafeFromTurrets(ex, ez)
    DUwall[n] = needWall and DashCrossesWall(ex, ez) or false
    DUhero[n] = isHero
    return n
end

local function SyncDashTargets(needWall)
    if S.dashing or not S.eR then ClearEBlock() end
    local n, blocked = 0, 0
    local base = KIT.eRange
    local mx, mz = S.myX, S.myZ

    for i = 1, CMn do
        local reach = base + CMbr[i]
        if DistSqr(CMx[i], CMz[i], mx, mz) <= reach * reach then
            local u = CMo[i]
            if IsEBlocked(u) then
                blocked = blocked + 1
            else
                n = PushDash(n, u, CMx[i], CMz[i], false, needWall,
                    MarkedByE(u, CMx[i], CMz[i], CMbr[i]))
            end
        end
    end
    for i = 1, JMn do
        local reach = base + JMbr[i]
        if DistSqr(JMx[i], JMz[i], mx, mz) <= reach * reach then
            local u = JMo[i]
            if IsEBlocked(u) then
                blocked = blocked + 1
            else
                n = PushDash(n, u, JMx[i], JMz[i], false, needWall,
                    MarkedByE(u, JMx[i], JMz[i], JMbr[i]))
            end
        end
    end
    for i = 1, EHn do
        local reach = base + EHbr[i]
        if DistSqr(EHx[i], EHz[i], mx, mz) <= reach * reach then
            local u = EHo[i]
            if IsEBlocked(u) then
                blocked = blocked + 1
            else
                n = PushDash(n, u, EHx[i], EHz[i], true, needWall, EHmark[i])
            end
        end
    end

    for i = n + 1, DUhigh do DUo[i] = nil end
    DUhigh = n
    DUn = n
    if n == 0 and blocked > 0 then ClearEBlock() end
end

local function PredictXZ(unit, delay, kx, kz)
    local px, pz = kx, kz
    if px == nil then
        local p = unit.pos
        if p == nil then return nil, nil end
        px, pz = p.x, p.z
    end
    if delay <= 0 then return px, pz end
    local path = unit.pathing
    if path == nil then return px, pz end
    if path.isDashing then
        local e = path.endPos
        if e then return e.x, e.z end
        return px, pz
    end
    if not path.hasMovePath then return px, pz end
    local ms = unit.ms
    if ms == nil or ms <= 0 then return px, pz end
    local remain = delay
    local lx, lz = px, pz
    for i = path.pathIndex, path.pathCount do
        local node = unit:GetPath(i)
        if node == nil then break end
        local nx, nz = node.x, node.z
        local seg = math_sqrt(DistSqr(nx, nz, lx, lz))
        if seg < 1 then
            lx, lz = nx, nz
        else
            local segTime = seg / ms
            if remain > segTime then
                remain = remain - segTime
                lx, lz = nx, nz
            else
                local t = ms * remain / seg
                return lx + (nx - lx) * t, lz + (nz - lz) * t
            end
        end
    end
    return lx, lz
end

local function HealthAfter(unit, t)
    local sdk = _G.SDK
    local hp = sdk and sdk.HealthPrediction
    if hp and hp.GetPrediction then
        local ok, v = pcall(hp.GetPrediction, hp, unit, t)
        if ok and type(v) == "number" then return v end
    end
    return unit.health or 0
end

local function ProjectOnSegment(ax, az, bx, bz, cx, cz)
    local abx, abz = bx - ax, bz - az
    local denom = abx * abx + abz * abz
    if denom < 1 then return ax, az, false end
    local raw = ((cx - ax) * abx + (cz - az) * abz) / denom
    local clamped = (raw < 0 and 0) or (raw > 1 and 1) or raw
    return ax + clamped * abx, az + clamped * abz, clamped == raw
end

local GGPredQ, GGPredQ3 = nil, nil
local PredTries = 0

local function EnsurePred()
    if GGPredQ then return true end
    local gg = _G.GGPrediction
    if not gg or type(gg.SpellPrediction) ~= "function" then
        PredTries = PredTries + 1
        if PredTries == 300 then
            print("[" .. SCRIPT_NAME .. "] GGPrediction unavailable, Q will not fire")
        end
        return false
    end
    GGPredQ = gg:SpellPrediction({
        Type = gg.SPELLTYPE_LINE, Delay = KIT.qDelayMax, Radius = KIT.qRadius,
        Range = KIT.qRange, Speed = KIT.qSpeed, Collision = false,
    })
    GGPredQ3 = gg:SpellPrediction({
        Type = gg.SPELLTYPE_LINE, Delay = KIT.qDelayMax, Radius = KIT.q3Radius,
        Range = KIT.q3Range, Speed = KIT.q3Speed, Collision = false,
    })
    return true
end

local function HitChanceOf(menuVal)
    local gg = _G.GGPrediction
    if not gg then return 0 end
    if menuVal == 1 then return gg.HITCHANCE_NORMAL end
    if menuVal == 2 then return gg.HITCHANCE_HIGH end
    return gg.HITCHANCE_IMMOBILE
end

local function Evaluate(pred, target, want)
    pred.Delay = S.qDelay
    local ok = pcall(pred.GetPrediction, pred, target, myHero)
    if not ok then return nil, nil end
    local cp = pred.CastPosition
    if cp == nil or cp.x == nil or cp.z == nil then return nil, nil end
    local got, can = pcall(pred.CanHit, pred, want)
    if not got or not can then return nil, nil end
    return cp.x, cp.z
end

local function PredQ(i, want)
    if PQs[i] ~= TICK then
        PQs[i] = TICK
        if EnsurePred() then
            PQx[i], PQz[i] = Evaluate(GGPredQ, EHo[i], want)
        else
            PQx[i], PQz[i] = nil, nil
        end
    end
    return PQx[i], PQz[i]
end

local function PredQ3(i, want)
    if P3s[i] ~= TICK then
        P3s[i] = TICK
        if EnsurePred() then
            P3x[i], P3z[i] = Evaluate(GGPredQ3, EHo[i], want)
        else
            P3x[i], P3z[i] = nil, nil
        end
    end
    return P3x[i], P3z[i]
end

local function LibDamage(key, target)
    local fn = _G.getdmg
    if type(fn) ~= "function" then return 0 end
    local ok, dmg = pcall(fn, key, target, myHero)
    if ok and type(dmg) == "number" and dmg > 0 then return dmg end
    return 0
end

local function ERawDamage()
    local lv = S.eLv
    if lv == 0 then return 0 end
    local ramp = 1 + KIT.eRamp * math_min(S.eRampStacks, KIT.eRampMax)
    return KIT.eBase[lv] * ramp + KIT.eAD * S.bonusAD + KIT.eAP * S.ap
end

local function QDamage(i)
    if S.qLv == 0 then return 0 end
    local target = EHo[i]
    local dmg = LibDamage("Q", target)
    if dmg > 0 then return dmg end
    return Mitigate(target, DMG_PHYS, KIT.qBase[S.qLv] + KIT.qAD * S.ad)
end

local function EDamage(i)
    if S.eLv == 0 then return 0 end
    local target = EHo[i]
    local dmg = LibDamage("E", target)
    if dmg > 0 then
        return dmg * (1 + KIT.eRamp * math_min(S.eRampStacks, KIT.eRampMax))
    end
    return Mitigate(target, DMG_MAGIC, ERawDamage())
end

local function RDamage(i)
    if S.rLv == 0 then return 0 end
    local raw = KIT.rBase[S.rLv] + KIT.rAD * S.bonusAD
    return MitigatePen(EHo[i], raw, KIT.rArmorPen)
end

local function AADamage(i)
    local target = EHo[i]
    local mod = 1 + S.crit * KIT.critBonus
    local raw = LibDamage("AA", target)
    if raw > 0 then return raw * mod end
    return Mitigate(target, DMG_PHYS, S.ad * mod)
end

local function IgniteSlot()
    if myHero:GetSpellData(SUM_1).name == "SummonerDot" and GameCanUseSpell(SUM_1) == 0 then
        return SUM_1, HK_SUM_1
    end
    if myHero:GetSpellData(SUM_2).name == "SummonerDot" and GameCanUseSpell(SUM_2) == 0 then
        return SUM_2, HK_SUM_2
    end
    return nil, nil
end

local function IgniteDamage()
    local slot = IgniteSlot()
    if slot == nil then return 0 end
    local ld = myHero.levelData
    return 50 + 20 * ((ld and ld.lvl) or 1)
end

local function ComboDamage(i)
    if DMs[i] == TICK then return DMv[i] end
    DMs[i] = TICK
    local total = 0
    if S.qR then
        total = total + QDamage(i) * (S.hasQ3 and 1 or 2)
    end
    if S.eR and not EHmark[i] then
        total = total + EDamage(i)
    end
    local rUseful = S.rR and (S.hasQ3 or EHknock[i])
    if rUseful then
        total = total + RDamage(i)
    end
    local aa = AADamage(i)
    total = total + aa * ((rUseful or S.hasQ3) and 3 or 2)
    DMv[i] = total
    return total
end

local function Killable(i)
    return ComboDamage(i) >= EHhp[i]
end

local function Pick()
    if tsTick == TICK then return tsIdx end
    tsTick = TICK
    tsIdx = 0
    local sdk = _G.SDK
    if not sdk or not sdk.TargetSelector or not sdk.ObjectManager then return 0 end
    local widest = Menu.combo.eGapRange:Value()
    if KIT.q3Range > widest then widest = KIT.q3Range end
    local ok, heroes = pcall(sdk.ObjectManager.GetEnemyHeroes, sdk.ObjectManager, widest, false)
    if not ok or type(heroes) ~= "table" then return 0 end
    local got, picked = pcall(sdk.TargetSelector.GetTarget, sdk.TargetSelector, heroes)
    if got and picked then
        local h = picked.handle
        for i = 1, EHn do
            if EHh[i] == h then
                tsIdx = i
                break
            end
        end
    end
    return tsIdx
end

local function InRange(i, range)
    return EHd[i] <= range + EHbr[i]
end

local function Target(range)
    local i = Pick()
    if i ~= 0 and not EHinvuln[i] and InRange(i, range) then return i end
    local best, bestHp = 0, math_huge
    for k = 1, EHn do
        if not EHinvuln[k] and InRange(k, range) and EHhp[k] < bestHp then
            best, bestHp = k, EHhp[k]
        end
    end
    return best
end

local function TradeOk()
    local node = Menu.combo.trade
    if not node.enable:Value() then return true end
    if node.antiGank:Value() and S.nearE >= S.nearA + 2 then return false end
    if node.shield:Value() and not S.shield then
        if S.flowPct < node.flowPct:Value() then return false end
    end
    return true
end

local function EQWillHit(ex, ez, px, pz, br)
    local reach = KIT.qCircle + br
    return DistSqr(ex, ez, px, pz) <= reach * reach
end

local function BestEToTarget(i, avoidTower)
    local px, pz = PredictXZ(EHo[i], S.eDelay, EHx[i], EHz[i])
    if px == nil then return 0, math_huge, false, 0 end
    local br = EHbr[i]
    local currentSqr = DistSqr(S.myX, S.myZ, px, pz)
    local qSoon = S.qCd <= S.eDelay + 0.1 and S.qLv > 0
    local bestIdx, bestDistSqr, bestEQ = 0, math_huge, false
    for k = 1, DUn do
        if not (avoidTower and not DUsafe[k]) then
            local ex, ez = DUx[k], DUz[k]
            local d2 = DistSqr(ex, ez, px, pz)
            local eq = qSoon and EQWillHit(ex, ez, px, pz, br)
            if eq then
                if not bestEQ or d2 < bestDistSqr then
                    bestIdx, bestDistSqr, bestEQ = k, d2, true
                end
            elseif not bestEQ and d2 < bestDistSqr and d2 < currentSqr then
                bestIdx, bestDistSqr = k, d2
            end
        end
    end
    return bestIdx, bestDistSqr, bestEQ, currentSqr
end

local function BestEToCursor(avoidTower)
    local mx, mz = MouseXZ()
    if mx == nil then return 0, math_huge end
    local bestIdx, bestDistSqr = 0, math_huge
    for k = 1, DUn do
        if not (avoidTower and not DUsafe[k]) then
            local d2 = DistSqr(DUx[k], DUz[k], mx, mz)
            if d2 < bestDistSqr then
                bestIdx, bestDistSqr = k, d2
            end
        end
    end
    return bestIdx, bestDistSqr
end

local function BestEToward(tx, tz, avoidTower, preferHero)
    local current = DistSqr(S.myX, S.myZ, tx, tz)
    local bestIdx, bestDistSqr, bestHero = 0, math_huge, false
    for k = 1, DUn do
        if not (avoidTower and not DUsafe[k]) then
            local d2 = DistSqr(DUx[k], DUz[k], tx, tz)
            if d2 < current then
                local isHero = DUhero[k]
                if bestIdx == 0
                    or (preferHero and isHero and not bestHero)
                    or (d2 < bestDistSqr and (not preferHero or isHero == bestHero)) then
                    bestIdx, bestDistSqr, bestHero = k, d2, isHero
                end
            end
        end
    end
    return bestIdx
end

local function CastE(k)
    if not S.eR or S.dashing or SentTick[SE] == TICK then return false end
    if not SlotFree(SE) then return false end
    local unit = DUo[k]
    if unit == nil then return false end
    if CastSpell(HKE, unit) == false then return false end
    MarkSent(SE)
    BlockE(unit)
    return true
end

local function CastEAimed(k)
    if not S.eR or S.dashing or SentTick[SE] == TICK then return false end
    local unit = DUo[k]
    if unit == nil then return false end
    if not SendAtUnit(HKE, SE, unit) then return false end
    BlockE(unit)
    return true
end

local function CastQ(i, want)
    if not S.qR or S.dashing or S.hasQ3 or S.casting then return false end
    if SentTick[SQ] == TICK or not CanMove() then return false end
    if not InRange(i, KIT.qRange) then return false end
    local cx, cz = PredQ(i, want)
    if cx == nil then return false end
    return SendAt(HKQ, SQ, cx, cz)
end

local function CastQ3(i, want)
    if not S.qR or S.dashing or not S.hasQ3 or S.casting then return false end
    if SentTick[SQ] == TICK or not CanMove() then return false end
    if not InRange(i, KIT.q3Range) then return false end
    local cx, cz = PredQ3(i, want)
    if cx == nil then return false end
    return SendAt(HKQ, SQ, cx, cz)
end

local function CastQAt(x, z)
    if not S.qR or S.dashing or S.casting then return false end
    if SentTick[SQ] == TICK or not CanMove() then return false end
    return SendAt(HKQ, SQ, x, z)
end

local function HoldQ()
    if not S.qR then return false end
    Control.KeyDown(HKQ)
    qHeld = true
    AllowAttack(false)
    return true
end

local function ReleaseQ()
    if not qHeld then return end
    Control.KeyUp(HKQ)
    qHeld = false
    AllowAttack(true)
end

local function CountCircle(cx, cz, n, xs, zs)
    local count = 0
    for i = 1, n do
        if DistSqr(xs[i], zs[i], cx, cz) <= QCIRCLE2 then count = count + 1 end
    end
    return count
end

local function MinionPred(i)
    if CMps[i] ~= TICK then
        CMps[i] = TICK
        local d = math_sqrt(DistSqr(CMx[i], CMz[i], S.myX, S.myZ))
        CMpx[i], CMpz[i] = PredictXZ(CMo[i], S.qDelay + d / KIT.q3Speed, CMx[i], CMz[i])
    end
    return CMpx[i], CMpz[i]
end

local function CountQ3Line(tx, tz)
    local count = 0
    local reachBase = KIT.q3Radius
    local mx, mz = S.myX, S.myZ
    for i = 1, CMn do
        if DistSqr(CMx[i], CMz[i], mx, mz) <= Q3_RANGE2 then
            local px, pz = MinionPred(i)
            if px then
                local jx, jz, onSeg = ProjectOnSegment(mx, mz, tx, tz, px, pz)
                if onSeg then
                    local reach = reachBase + CMbr[i]
                    if DistSqr(px, pz, jx, jz) <= reach * reach then count = count + 1 end
                end
            end
        end
    end
    return count
end

local function StackQ()
    if not S.qR or S.hasQ3 or S.dashing or S.casting then return false end
    local reach = KIT.qRange + 20
    local rs = reach * reach
    local mx, mz = S.myX, S.myZ
    local bx, bz, best, bestD = nil, nil, 0, math_huge
    for i = 1, CMn do
        local d2 = DistSqr(CMx[i], CMz[i], mx, mz)
        if d2 <= rs then
            local c = CountCircle(CMx[i], CMz[i], CMn, CMx, CMz)
            if c > best or (c == best and d2 < bestD) then
                bx, bz, best, bestD = CMx[i], CMz[i], c, d2
            end
        end
    end
    if bx then return CastQAt(bx, bz) end
    for i = 1, JMn do
        local d2 = DistSqr(JMx[i], JMz[i], mx, mz)
        if d2 <= rs then
            local c = CountCircle(JMx[i], JMz[i], JMn, JMx, JMz)
            if c > best or (c == best and d2 < bestD) then
                bx, bz, best, bestD = JMx[i], JMz[i], c, d2
            end
        end
    end
    if bx then return CastQAt(bx, bz) end
    return false
end

local function DashQ()
    if not S.dashing or not S.qR then return false end
    if not Menu.combo.qInDash:Value() then return false end
    local mx, mz = S.myX, S.myZ
    for i = 1, EHn do
        if not EHinvuln[i] then
            local px, pz = PredictXZ(EHo[i], S.lat, EHx[i], EHz[i])
            if px and EQWillHit(mx, mz, px, pz, EHbr[i]) then return HoldQ() end
        end
    end
    for i = 1, CMn do
        if DistSqr(mx, mz, CMx[i], CMz[i]) <= QCIRCLE2 then return HoldQ() end
    end
    for i = 1, JMn do
        if DistSqr(mx, mz, JMx[i], JMz[i]) <= QCIRCLE2 then return HoldQ() end
    end
    return false
end

local function Ultimate()
    if not S.rR or S.rLv == 0 then return false end
    local node = Menu.ult
    if not node.team:Value() then return false end
    if S.dashing and node.noRDash:Value() then return false end
    if SentTick[SR] == TICK then return false end
    local need = node.teamMin:Value()
    local bestIdx, bestCount = 0, 0
    for i = 1, EHn do
        if EHknock[i] and not EHinvuln[i] and InRange(i, KIT.rRange) then
            local count = 1
            for j = 1, EHn do
                if j ~= i and EHknock[j]
                    and DistSqr(EHx[i], EHz[i], EHx[j], EHz[j]) < 160000 then
                    count = count + 1
                end
            end
            if count > bestCount then bestIdx, bestCount = i, count end
        end
    end
    if bestIdx == 0 then return false end
    if bestCount < need and not Killable(bestIdx) then return false end
    return SendAtUnit(HKR, SR, EHo[bestIdx])
end

local function Airblade()
    if not Menu.ult.airblade:Value() then return false end
    if not S.rR or not S.eR or S.dashing then return false end
    local bestIdx = 0
    for i = 1, EHn do
        if EHknock[i] and not EHinvuln[i] and InRange(i, KIT.rRange) then
            bestIdx = i
            break
        end
    end
    if bestIdx == 0 then return false end
    if EHd[bestIdx] <= KIT.rRange - KIT.eDash then return false end
    local k = BestEToward(EHx[bestIdx], EHz[bestIdx], Menu.combo.noETower:Value(), true)
    if k == 0 then return false end
    return CastE(k)
end

local function Ignite()
    local node = Menu.combo.ign
    if not node.use:Value() then return false end
    local slot, key = IgniteSlot()
    if slot == nil then return false end
    if SentTick[slot] == TICK or not SlotFree(slot) then return false end
    local ignite = IgniteDamage()
    local killOnly = node.mode:Value() == 1
    for i = 1, EHn do
        if not EHinvuln[i] and InRange(i, KIT.igniteRange) then
            if ignite >= EHhp[i] then return SendAtUnit(key, slot, EHo[i]) end
            if not killOnly and ComboDamage(i) + ignite >= EHhp[i] then
                return SendAtUnit(key, slot, EHo[i])
            end
        end
    end
    return false
end

local function Combo()
    local node = Menu.combo
    local trade = TradeOk()

    if node.useE:Value() and S.eR and trade and not S.dashing then
        local gap = node.eGapRange:Value()
        local i = Target(gap)
        if i ~= 0 then
            local mode = node.eMode:Value()
            if mode == 3 then
                mode = (EHd[i] > S.aaRange + 100 and 1) or 2
            end
            if mode == 1 then
                local k, d2, eq, currentSqr = BestEToTarget(i, node.noETower:Value())
                if k ~= 0 then
                    local closes = d2 < currentSqr
                    local onTarget = DUo[k] == EHo[i]
                    local allow = closes or eq or onTarget
                    if allow and (EHd[i] > S.aaRange or eq or node.eEngage:Value() or onTarget) then
                        if CastE(k) then return true end
                    end
                end
            else
                local k, d2 = BestEToCursor(node.noETower:Value())
                local mx, mz = MouseXZ()
                if k ~= 0 and mx then
                    local cursorSqr = DistSqr(S.myX, S.myZ, mx, mz)
                    if d2 < cursorSqr and CastE(k) then return true end
                end
            end
        end
    end

    if node.useQ3:Value() and S.hasQ3 then
        local want = HitChanceOf(Menu.pred.hcQ3:Value())
        local bestIdx, bestHp = 0, math_huge
        for i = 1, EHn do
            if not EHinvuln[i] and InRange(i, KIT.q3Range) then
                if Killable(i) and EHhp[i] < bestHp then bestIdx, bestHp = i, EHhp[i] end
            end
        end
        if bestIdx == 0 then bestIdx = Target(KIT.q3Range) end
        if bestIdx ~= 0 and CastQ3(bestIdx, want) then return true end
    end

    if node.useQ:Value() and not S.hasQ3 then
        local want = HitChanceOf(Menu.pred.hcQ:Value())
        local i = Target(KIT.qRange)
        if i ~= 0 and CastQ(i, want) then return true end
        if node.stackQ:Value() and StackQ() then return true end
    end

    return Ignite()
end

local function Harass()
    local node = Menu.harass
    if node.useQ3:Value() and S.hasQ3 then
        local i = Target(KIT.q3Range)
        if i ~= 0 and CastQ3(i, HitChanceOf(Menu.pred.hcQ3:Value())) then return true end
    end
    if node.useQ:Value() and not S.hasQ3 then
        local i = Target(KIT.qRange)
        if i ~= 0 and CastQ(i, HitChanceOf(Menu.pred.hcQ:Value())) then return true end
    end
    if node.stackQ:Value() then return StackQ() end
    return false
end

local function Clear()
    local node = Menu.clear
    local mx, mz = S.myX, S.myZ

    if JMn > 0 then
        if node.useQ3:Value() and S.hasQ3 then
            local bx, bz, best = nil, nil, 0
            for i = 1, JMn do
                if DistSqr(JMx[i], JMz[i], mx, mz) <= Q3_RANGE2 then
                    local c = CountCircle(JMx[i], JMz[i], JMn, JMx, JMz)
                    if c > best then bx, bz, best = JMx[i], JMz[i], c end
                end
            end
            if bx and CastQAt(bx, bz) then return true end
        end
        if node.useQ:Value() and not S.hasQ3 then
            local reach = KIT.qRange + 20
            local rs = reach * reach
            for i = 1, JMn do
                if DistSqr(JMx[i], JMz[i], mx, mz) <= rs then
                    if CastQAt(JMx[i], JMz[i]) then return true end
                end
            end
        end
        if node.useE:Value() and S.eR and not S.dashing and CanMove() then
            local k = 0
            for j = 1, DUn do
                if not DUhero[j] and (not node.noETower:Value() or DUsafe[j]) then
                    k = j
                    break
                end
            end
            if k ~= 0 and CastE(k) then return true end
        end
        return false
    end

    if node.useQ3:Value() and S.hasQ3 then
        local bx, bz, best = nil, nil, node.q3Min:Value()
        for i = 1, CMn do
            if DistSqr(CMx[i], CMz[i], mx, mz) <= Q3_RANGE2 then
                local c = CountQ3Line(CMx[i], CMz[i])
                if c >= best then bx, bz, best = CMx[i], CMz[i], c end
            end
        end
        if bx and CastQAt(bx, bz) then return true end
    end

    if node.useQ:Value() and not S.hasQ3 then
        local bx, bz, best = nil, nil, 0
        for i = 1, CMn do
            if DistSqr(CMx[i], CMz[i], mx, mz) <= Q_RANGE2 then
                local c = CountCircle(CMx[i], CMz[i], CMn, CMx, CMz)
                if c > best then bx, bz, best = CMx[i], CMz[i], c end
            end
        end
        if bx and CastQAt(bx, bz) then return true end
    end

    if node.useE:Value() and S.eR and not S.dashing and CanMove() then
        local lastHitOnly = node.eLH:Value() == 1
        local eRaw = ERawDamage()
        for k = 1, DUn do
            if not DUhero[k] and (not node.noETower:Value() or DUsafe[k]) then
                local unit = DUo[k]
                if not lastHitOnly then
                    if CastE(k) then return true end
                elseif eRaw > 0 and HealthAfter(unit, S.eDelay)
                    <= Mitigate(unit, DMG_MAGIC, eRaw) then
                    if CastE(k) then return true end
                end
            end
        end
    end
    return false
end

local function LastHit()
    local node = Menu.lasthit
    local mx, mz = S.myX, S.myZ

    if node.useQ:Value() and not S.hasQ3 and S.qR then
        local reach = KIT.qRange + 20
        local rs = reach * reach
        local qDmg = (KIT.qBase[math_max(S.qLv, 1)] or 0) + KIT.qAD * S.ad
        for i = 1, CMn do
            if DistSqr(CMx[i], CMz[i], mx, mz) <= rs then
                if HealthAfter(CMo[i], S.qDelay) <= qDmg then
                    if CastQAt(CMx[i], CMz[i]) then return true end
                end
            end
        end
    end

    if node.useE:Value() and S.eR and not S.dashing and CanMove() then
        local eRaw = ERawDamage()
        for k = 1, DUn do
            if not DUhero[k] and (not node.noETower:Value() or DUsafe[k]) then
                local unit = DUo[k]
                if eRaw > 0 and HealthAfter(unit, S.eDelay)
                    <= Mitigate(unit, DMG_MAGIC, eRaw) then
                    if CastE(k) then return true end
                end
            end
        end
    end
    return false
end

local function Flee()
    local node = Menu.flee
    if node.useE:Value() and S.eR and not S.dashing then
        local mx, mz = MouseXZ()
        if mx then
            local k, d2 = BestEToCursor(node.noETower:Value())
            if k ~= 0 and d2 < DistSqr(S.myX, S.myZ, mx, mz) then
                if CastE(k) then return true end
            end
        end
    end
    if node.useQ3:Value() and S.hasQ3 then
        local i = Target(KIT.q3Range)
        if i ~= 0 and CastQ3(i, HitChanceOf(Menu.pred.hcQ3:Value())) then return true end
    end
    if node.useQ:Value() and not S.hasQ3 then
        local i = Target(KIT.qRange)
        if i ~= 0 and CastQ(i, HitChanceOf(Menu.pred.hcQ:Value())) then return true end
        return StackQ()
    end
    return false
end

local function WallJump()
    if not S.eR or S.dashing then return false end
    local mx, mz = MouseXZ()
    if mx == nil then return false end
    local reach = Menu.walljump.range:Value()
    local reachSqr = reach * reach
    local allowPush = Menu.walljump.push:Value()
    local bestIdx, bestDistSqr, bestRank = 0, 0, 3
    for k = 1, DUn do
        local rank = DUwall[k]
        if rank and (rank == 1 or allowPush) then
            local d2 = DistSqr(DUx[k], DUz[k], mx, mz)
            if d2 <= reachSqr and (rank < bestRank or (rank == bestRank and d2 < bestDistSqr)) then
                bestIdx, bestDistSqr, bestRank = k, d2, rank
            end
        end
    end
    if bestIdx == 0 then return false end
    return CastEAimed(bestIdx)
end

local function WindWall()
    local node = Menu.windwall
    local logMiss = Menu.debug.missNames:Value() == true
    local canCast = node.enable:Value() == true and S.wR and SentTick[SW] ~= TICK
        and not (node.onlyCombo:Value() and S.mode ~= MODE_COMBO)
    if not canCast and not logMiss then return false end

    local minThreat = node.minThreat:Value()
    local lowHp = S.hpPct * 100 < node.hpSafe:Value()
    local bestThreat, bestX, bestZ = 0, nil, nil
    local scanSqr = 2800 * 2800
    local hitBase = S.br * 1.3
    local mx, mz = S.myX, S.myZ

    if MissileSeen > LIM.partMemoCap then
        MissileThreat = {}
        MissileSeen = 0
    end

    local count = (GameMissileCount and GameMissileCount()) or 0
    for i = 1, count do
        local m = GameMissile(i)
        if m and m.valid and m.isEnemy then
            local mp = m.pos
            if mp and DistSqr(mp.x, mp.z, mx, mz) < scanSqr then
                local id = m.networkID
                local rank
                if id ~= nil then rank = MissileThreat[id] end
                if rank == nil then
                    local nm = m.name
                    rank = DANGER[nm] or false
                    if id ~= nil then
                        MissileThreat[id] = rank
                        MissileSeen = MissileSeen + 1
                    end
                    if not rank and logMiss and type(nm) == "string" and nm ~= ""
                        and MEMO.missSeen[nm] == nil then
                        if MEMO.missN > LIM.nameLogCap then
                            MEMO.missSeen = {}
                            MEMO.missN = 0
                        end
                        MEMO.missSeen[nm] = true
                        MEMO.missN = MEMO.missN + 1
                        print(string_format("[%s] MISSILE %q from %s", SCRIPT_NAME, nm,
                            PartOwnerLabel(mp.x, mp.z) or "far"))
                    end
                end
                if rank then
                    local threat = rank + (lowHp and 3 or 0)
                    local gate = node.spells[m.name]
                    if (not gate or gate:Value()) and threat > bestThreat
                        and (threat >= minThreat or lowHp) then
                        local a, b = m.startPos, m.endPos
                        if a and b then
                            local jx, jz, onSeg = ProjectOnSegment(a.x, a.z, b.x, b.z, mx, mz)
                            if onSeg and (jx - mp.x) * (b.x - a.x) + (jz - mp.z) * (b.z - a.z) > 0 then
                                local reach = (m.width or 70) * 0.5 + hitBase
                                if DistSqr(mx, mz, jx, jz) < reach * reach then
                                    bestThreat, bestX, bestZ = threat, mp.x, mp.z
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for i = 1, EHn do
        if EHd[i] * EHd[i] < scanSqr then
            local spell = EHo[i].activeSpell
            if spell and spell.valid == true then
                local rank = DANGER[spell.name]
                if rank then
                    local threat = rank + (lowHp and 3 or 0)
                    local gate = node.spells[spell.name]
                    if (not gate or gate:Value()) and threat > bestThreat
                        and (threat >= minThreat or lowHp) then
                        local hit = false
                        local tgt = spell.target
                        if tgt ~= nil and (tgt == myHero or tgt == myHero.handle
                            or tgt == myHero.networkID) then
                            hit = true
                        else
                            local sp = spell.startPos
                            local ep = spell.toPos or spell.placementPos
                            local sx = (sp and sp.x) or EHx[i]
                            local sz = (sp and sp.z) or EHz[i]
                            local ex = (ep and ep.x) or mx
                            local ez = (ep and ep.z) or mz
                            if DistSqr(ex, ez, EHx[i], EHz[i]) < 2500 then
                                ex, ez = mx, mz
                            end
                            local jx, jz, onSeg = ProjectOnSegment(sx, sz, ex, ez, mx, mz)
                            if onSeg then
                                local reach = (spell.width or 100) * 0.5 + hitBase
                                hit = DistSqr(mx, mz, jx, jz) < reach * reach
                            end
                        end
                        if hit then bestThreat, bestX, bestZ = threat, EHx[i], EHz[i] end
                    end
                end
            end
        end
    end

    if bestX == nil or not canCast then return false end
    return SendAt(HKW, SW, bestX, bestZ)
end

local function DumpUnit(who, unit, everything)
    local total = unit.buffCount
    local p = unit.pos
    local br = unit.boundingRadius or 60
    print(string_format("[%s] %s nID=%s buffCount=%s marked=%s byPart=%s", SCRIPT_NAME,
        who, tostring(unit.networkID), tostring(total),
        tostring(MarkedByE(unit, p.x, p.z, br)),
        tostring(MarkedByParticle(p.x, p.z, br))))
    if type(total) ~= "number" then return end
    for i = 0, total - 1 do
        local b = unit:GetBuff(i)
        if b then
            local n = b.name
            local nt = type(n)
            local nlen = (nt == "string" and #n) or -1
            local key = who .. "|" .. i .. "|" .. tostring(n) .. "|" .. tostring(b.type)
            if everything or not seenBuff[key] then
                if seenBuffN > LIM.nameLogCap then
                    seenBuff = {}
                    seenBuffN = 0
                end
                seenBuff[key] = true
                seenBuffN = seenBuffN + 1
                print(string_format(
                    "[%s]   [%d] name=%q nt=%s len=%d count=%s stacks=%s type=%s srcName=%s srcID=%s",
                    SCRIPT_NAME, i, tostring(n), nt, nlen, tostring(b.count), tostring(b.stacks),
                    tostring(b.type), tostring(b.sourceName), tostring(b.sourcenID)))
            end
        end
    end
end

local function DumpParticles()
    if type(Game.ParticleCount) ~= "function" or type(Game.Particle) ~= "function" then
        print("[" .. SCRIPT_NAME .. "] particle API missing")
        return
    end
    local total = Game.ParticleCount()
    if type(total) ~= "number" or total <= 0 then
        print("[" .. SCRIPT_NAME .. "] ParticleCount=" .. tostring(total))
        return
    end
    print(string_format("[%s] ParticleCount=%d", SCRIPT_NAME, total))
    if total > LIM.particleCap then total = LIM.particleCap end
    local near = 0
    for i = 1, total do
        local p = Game.Particle(i)
        if p and p.pos then
            local who = PartOwnerLabel(p.pos.x, p.pos.z)
            if who then
                near = near + 1
                print(string_format("[%s]   PART on %s name=%q type=%s code=%d", SCRIPT_NAME,
                    who, tostring(p.name), tostring(p.type), ClassifyParticle(p.name)))
            end
        end
    end
    print(string_format("[%s] particles near units: %d", SCRIPT_NAME, near))
end

local function Debug()
    local node = Menu.debug
    local key = node.dumpKey:Value() == true
    local edge = key and not dumpHeld
    dumpHeld = key
    if not edge and not node.watch:Value() then return end

    for i = 1, EHn do
        if EHd[i] <= 1200 then DumpUnit(EHo[i].charName or "enemy", EHo[i], edge) end
    end
    for k = 1, DUn do
        local u = DUo[k]
        DumpUnit(tostring(u.charName or u.name or "unit"), u, edge)
    end
    if not edge then return end

    print(string_format("[%s] SELF nID=%s charName=%s dashCands=%d eMarks=%d eR=%s eCd=%.2f canUseE=%s dashing=%s",
        SCRIPT_NAME, tostring(myHero.networkID), tostring(myHero.charName),
        DUn, EMn, tostring(S.eR), S.eCd, tostring(GameCanUseSpell(SE)), tostring(S.dashing)))
    local q = myHero:GetSpellData(SQ)
    print(string_format("[%s] QDATA name=%s ammo=%s ammoTime=%s ammoCd=%s ammoCurrentCd=%s toggle=%s",
        SCRIPT_NAME, tostring(q.name), tostring(q.ammo), tostring(q.ammoTime),
        tostring(q.ammoCd), tostring(q.ammoCurrentCd), tostring(q.toggleState)))
    print(string_format("[%s] SELFFLAGS shield=%s qStacks=%s eRamp=%s shieldPart=%s qPart=%s ePart=%s",
        SCRIPT_NAME, tostring(S.shield), tostring(S.qStacks), tostring(S.eRampStacks),
        tostring(S.shieldPart), tostring(S.qStackPart), tostring(S.eRampPart)))
    DumpUnit("MYSELF", myHero, true)
    if node.particles:Value() then DumpParticles() end
end

local function OnTick()
    TICK = TICK + 1
    NOW = GameTimer()

    RestoreCursor()
    if qHeld then ReleaseQ() end

    if ShouldWait() then
        wjDraw = false
        AllowAttack(true)
        return
    end

    SyncSelf()
    SyncMinions()
    SyncEnemies()
    ScanParticles()
    SyncMarks()
    SyncTurrets()

    local wjHeld = Menu.walljump.key:Value() == true and S.eR and not S.dashing
    local wjShow = not S.dashing and Menu.walljump.draw:Value() and Menu.draw.eDashPos:Value()
    wjDraw = wjHeld or wjShow
    SyncDashTargets(wjDraw)

    Debug()
    WindWall()

    if DashQ() then return end
    if wjHeld and WallJump() then return end

    local mode = S.mode
    if mode == MODE_NONE then return end

    if mode == MODE_COMBO then
        if Ultimate() then return end
        if Airblade() then return end
        Combo()
    elseif mode == MODE_HARASS then
        Harass()
    elseif mode == MODE_CLEAR then
        Clear()
    elseif mode == MODE_LASTHIT then
        LastHit()
    elseif mode == MODE_FLEE then
        Flee()
    end
end

local DrawColor = Draw.Color
local DrawCircle = Draw.Circle
local DrawText = Draw.Text

local COL_Q = DrawColor(80, 255, 255, 255)
local COL_Q3 = DrawColor(80, 255, 100, 100)
local COL_E = DrawColor(80, 100, 255, 100)
local COL_EGAP = DrawColor(50, 100, 200, 255)
local COL_R = DrawColor(50, 255, 200, 50)
local COL_SHIELD = DrawColor(255, 50, 200, 255)
local COL_KILL = DrawColor(255, 255, 30, 30)
local COL_WALL = DrawColor(200, 255, 0, 255)
local COL_PUSH = DrawColor(200, 255, 170, 0)
local COL_DASH = DrawColor(90, 150, 150, 150)
local COL_UNSAFE = DrawColor(180, 255, 0, 0)

local COL_BG = DrawColor(180, 10, 10, 15)
local COL_BORD = DrawColor(255, 200, 50, 50)
local COL_RDY = DrawColor(255, 50, 255, 50)
local COL_CD = DrawColor(255, 255, 80, 80)
local COL_OFF = DrawColor(255, 130, 130, 130)
local COL_MARK = DrawColor(255, 255, 80, 255)
local COL_FLOW = DrawColor(255, 255, 255, 0)
local COL_FLOWON = DrawColor(255, 0, 255, 0)

local PC = {
    tick = -1,
    res = false,
    x = 810,
    y = 870,
    marked = -1,
    markText = "MARK 0",
    flowText = "FLOW 0",
    flowRaw = -2,
    shield = false,
    cdText = { "Q", "W", "E", "R" },
    cdReady = { false, false, false, false },
    cdKey = { -9, -9, -9, -9 },
    cdName = { "Q", "W", "E", "R" },
}

local DashPos = { x = 0, y = 0, z = 0 }

local function PanelCell(i, name, cd, ready)
    PC.cdReady[i] = ready
    local key
    if ready then
        key = -1
    else
        local sane = type(cd) == "number" and cd == cd and cd >= 0 and cd < 1000
        key = (sane and math_floor(cd * 10)) or -2
    end
    if PC.cdKey[i] == key and PC.cdName[i] == name then return end
    PC.cdKey[i] = key
    PC.cdName[i] = name
    if ready then
        PC.cdText[i] = name .. " RDY"
    elseif key == -2 then
        PC.cdText[i] = name .. " ..."
    else
        PC.cdText[i] = string_format("%s %.1f", name, cd)
    end
end

local function DrawPanel()
    if not PC.res then
        PC.res = true
        local res = GameResolution and GameResolution()
        if res and res.x and res.y then
            PC.x = res.x / 2 - 150
            PC.y = res.y - 210
        end
    end

    if PC.tick ~= TICK then
        PC.tick = TICK

        local marked = 0
        for i = 1, EHn do
            if EHmark[i] then marked = marked + 1 end
        end
        if marked ~= PC.marked then
            PC.marked = marked
            PC.markText = string_format("MARK %d", marked)
        end

        local flowRaw = (S.shield and -1) or math_floor(S.flowPct)
        if flowRaw ~= PC.flowRaw then
            PC.flowRaw = flowRaw
            PC.flowText = (S.shield and "SHIELD") or string_format("FLOW %d", flowRaw)
        end
        PC.shield = S.shield

        PanelCell(1, (S.hasQ3 and "Q3") or "Q", S.qCd, S.qR)
        PanelCell(2, "W", S.wCd, S.wR)
        PanelCell(3, "E", S.eCd, S.eR)
        PanelCell(4, "R", S.rCd, S.rR)
    end

    local x, y = PC.x, PC.y

    if Draw.Rect then
        Draw.Rect(x, y, 300, 56, COL_BG)
        Draw.Rect(x, y, 300, 2, COL_BORD)
    end

    local wallOn = Menu.windwall.enable:Value() == true
    local wallCol = (wallOn and COL_RDY) or COL_OFF
    DrawText("WALL", 12, x + 10, y + 8, wallCol)
    DrawText((wallOn and "ON") or "off", 12, x + 62, y + 8, wallCol)
    DrawText(PC.markText, 12, x + 110, y + 8, (PC.marked > 0 and COL_MARK) or COL_OFF)
    DrawText(PC.flowText, 12, x + 200, y + 8, (PC.shield and COL_FLOWON) or COL_FLOW)

    for i = 1, 4 do
        DrawText(PC.cdText[i], 12, x + 10 + (i - 1) * 72, y + 32,
            (PC.cdReady[i] and COL_RDY) or COL_CD)
    end
end

local function OnDraw()
    if myHero.dead then return end
    local node = Menu.draw
    if not node.enable:Value() then return end

    if node.panel:Value() then DrawPanel() end
    if not myHero.visible then return end

    local hasQ3 = S.hasQ3
    local wantQ = node.qRange:Value() and not hasQ3
    local wantQ3 = node.q3Range:Value() and hasQ3
    local wantE = node.eRange:Value()
    local wantGap = node.eGap:Value()
    local wantR = node.rRange:Value()

    if wantQ or wantQ3 or wantE or wantGap or wantR then
        local pos = myHero.pos
        if wantQ then DrawCircle(pos, KIT.qRange, 1, COL_Q) end
        if wantQ3 then DrawCircle(pos, KIT.q3Range, 1, COL_Q3) end
        if wantE then DrawCircle(pos, KIT.eRange, 1, COL_E) end
        if wantGap then DrawCircle(pos, Menu.combo.eGapRange:Value(), 1, COL_EGAP) end
        if wantR then DrawCircle(pos, KIT.rRange, 1, COL_R) end
    end

    if node.eDashPos:Value() then
        for k = 1, DUn do
            local rank = DUwall[k]
            local col = (rank == 1 and COL_WALL) or (rank == 2 and COL_PUSH)
                or (DUsafe[k] and COL_DASH) or COL_UNSAFE
            DashPos.x, DashPos.y, DashPos.z = DUx[k], S.myY, DUz[k]
            DrawCircle(DashPos, 55, 2, col)
        end
    elseif wjDraw and Menu.walljump.draw:Value() then
        for k = 1, DUn do
            local rank = DUwall[k]
            if rank then
                DashPos.x, DashPos.y, DashPos.z = DUx[k], S.myY, DUz[k]
                DrawCircle(DashPos, 55, 2, (rank == 2 and COL_PUSH) or COL_WALL)
            end
        end
    end

    if node.killable:Value() then
        for i = 1, EHn do
            if not EHinvuln[i] then
                local p2 = EHo[i].pos2D
                if p2 ~= nil and p2.onScreen == true and Killable(i) then
                    DrawText("KILL", 22, p2.x - 18, p2.y - 36, COL_KILL)
                end
            end
        end
    end

    local wantFlow = node.flow:Value()
    local wantStacks = node.qStacks:Value() and not hasQ3
    if wantFlow or wantStacks then
        local p2 = myHero.pos2D
        if p2 and p2.onScreen then
            if wantFlow then
                local txt = (S.shield and "SHIELD") or string_format("%d%%", S.flowPct)
                DrawText(txt, 18, p2.x - 20, p2.y + 24, COL_SHIELD)
            end
            if wantStacks then
                DrawText("Q " .. S.qStacks .. "/2", 18, p2.x - 16, p2.y + 44, COL_Q3)
            end
        end
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
    if sdk and sdk.OnTick and sdk.OnDraw then
        sdk.OnTick[#sdk.OnTick + 1] = onTick
        sdk.OnDraw[#sdk.OnDraw + 1] = onDraw
        return "sdk"
    end
    Callback.Add("Tick", onTick)
    Callback.Add("Draw", onDraw)
    return "raw"
end

local how = Hook()
print("[" .. SCRIPT_NAME .. "] v" .. VERSION .. " loaded | wall " ..
    tostring(_G.MapPosition ~= nil) .. " | hook " .. how)
