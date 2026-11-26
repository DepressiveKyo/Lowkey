local __version__ = 1.0
local __name__ = "LowkeyChampions"

if _G.__LOWKEY_CHAMPIONS then return end

local sdk = _G.SDK
if not sdk or type(sdk.Hooks) ~= "table" then
    print("[LowkeyChampions] SDK.Hooks missing, orbwalker did not load first")
    return
end

_G.__LOWKEY_CHAMPIONS = true

local H = sdk.Hooks
local Buff = sdk.BuffManager
local AttackApi = sdk.Attack
local Objects = sdk.ObjectManager
local Walker = sdk.Orbwalker
local Health = sdk.HealthPrediction
local Net = sdk.Data
local Frame = sdk.Frame

local myHero = myHero
local Game = Game
local HUGE = math.huge
local sqrt = math.sqrt
local floor = math.floor
local max = math.max

local Timer = Game.Timer
local CanUseSpell = Game.CanUseSpell
local ObjectCount = Game.ObjectCount
local ObjectAt = Game.Object
local MissileCount = Game.MissileCount
local MissileAt = Game.Missile

local NAME = myHero.charName

local function DistSq(a, b)
    local p = a.pos or a
    local q = b.pos or b
    local dx = p.x - q.x
    local dz = (p.z or p.y) - (q.z or q.y)
    return dx * dx + dz * dz
end

local function Dist(a, b)
    return sqrt(DistSq(a, b))
end

local function Has(name)
    return Buff:HasBuff(myHero, name)
end

local function Ammo()
    return myHero.hudAmmo
end

local CHANNELING = {
    ["Caitlyn"] = function() return Has("CaitlynAceintheHole") end,
    ["FiddleSticks"] = function() return Has("Drain") or Has("Crowstorm") end,
    ["Galio"] = function() return Has("GalioIdolOfDurand") end,
    ["Janna"] = function() return Has("ReapTheWhirlwind") end,
    ["Kaisa"] = function() return Has("KaisaE") end,
    ["Karthus"] = function() return Has("karthusfallenonecastsound") end,
    ["Katarina"] = function() return Has("katarinarsound") end,
    ["Lucian"] = function() return Has("LucianR") end,
    ["Malzahar"] = function() return Has("alzaharnethergraspsound") end,
    ["MissFortune"] = function() return Has("missfortunebulletsound") end,
    ["Nunu"] = function() return Has("AbsoluteZero") end,
    ["Pantheon"] = function() return Has("pantheonesound") or Has("PantheonRJump") end,
    ["Shen"] = function() return Has("shenstandunitedlock") end,
    ["TwistedFate"] = function() return Has("Destiny") end,
    ["Urgot"] = function() return Has("UrgotSwap2") end,
    ["Varus"] = function() return Has("VarusQ") end,
    ["Velkoz"] = function() return Has("VelkozR") end,
    ["Vi"] = function() return Has("ViQ") end,
    ["Vladimir"] = function() return Has("VladimirE") end,
    ["Warwick"] = function() return Has("infiniteduresssound") end,
    ["Xerath"] = function() return Has("XerathArcanopulseChargeUp") or Has("XerathLocusOfPower2") end,
}

local ALLOW_MOVE_CHANNEL = {
    ["Kaisa"] = function() return Has("KaisaE") end,
    ["Lucian"] = function() return Has("LucianR") end,
    ["Varus"] = function() return Has("VarusQ") end,
    ["Vi"] = function() return Has("ViQ") end,
    ["Vladimir"] = function() return Has("VladimirE") end,
    ["Xerath"] = function() return Has("XerathArcanopulseChargeUp") end,
}

local BLOCK_ATTACK = {
    ["Renata"] = function() return Has("renataqselfroot") or Has("RenataQRecast") end,
    ["Urgot"] = function() return Has("UrgotW") end,
    ["Darius"] = function() return Has("dariusqcast") end,
    ["Graves"] = function() return Ammo() == 0 end,
    ["Jhin"] = function() return Ammo() == 0 end,
    ["Sion"] = function() return Has("sionpassivedelay") end,
}

local BLOCK_MOVE = {
    ["Sion"] = function() return Has("sionpassivedelay") end,
}

local FORCE_MOVE = {
    ["Kalista"] = function() return true end,
    ["Kaisa"] = function() return Has("KaisaE") end,
    ["Aphelios"] = function() return Has("ApheliosSeverumQ") end,
}

local MISSILE_SPEED = {
    ["Anivia"] = function() return 1600 end,
    ["Graves"] = function() return 3800 end,
    ["Hwei"] = function() return 2800 end,
    ["Seraphine"] = function() return 1800 end,
    ["Aphelios"] = function()
        if Has("ApheliosCrescendumManager") then return 3500 end
        if Has("ApheliosCalibrumManager") then return 3000 end
        if Has("ApheliosInfernumManager") then return 1700 end
        if Has("ApheliosSeverumManager") then return HUGE end
        return 1500
    end,
    ["Caitlyn"] = function()
        if Has("caitlynpassivedriver") then return 3000 end
        return nil
    end,
    ["Illaoi"] = function()
        if Has("IllaoiW") then return 1600 end
        return nil
    end,
    ["Jayce"] = function()
        local data = myHero:GetSpellData(_Q)
        if data and data.name == "JayceShockBlast" then return 2000 end
        return nil
    end,
    ["Jhin"] = function()
        if Ammo() == 1 then return 3000 end
        return nil
    end,
    ["Jinx"] = function()
        if Has("JinxQ") then return 2000 end
        return nil
    end,
    ["Kaisa"] = function()
        if Has("kaisaeattackspeed") then return 2500 end
        return nil
    end,
    ["Kayle"] = function()
        if Has("KayleE") then return 1750 end
        return nil
    end,
    ["Poppy"] = function()
        if Has("poppypassivebuff") then return 1600 end
        return nil
    end,
    ["Twitch"] = function()
        if Has("TwitchFullAutomatic") then return 5000 end
        return nil
    end,
    ["Viktor"] = function()
        if Has("ViktorQReturn") then return 5000 end
        return nil
    end,
    ["Yunara"] = function()
        if Has("YunaraQ") then return 10000 end
        return nil
    end,
}

local WINDUP = {
    ["Yunara"] = function()
        if Has("YunaraQ") then return 0.09 end
        return nil
    end,
    ["TwistedFate"] = function()
        if Has("BlueCardPreAttack") or Has("RedCardPreAttack") or Has("GoldCardPreAttack") then
            return 0.125
        end
        return nil
    end,
    ["Jayce"] = function()
        if Has("JayceHyperCharge") then return 0.125 end
        return nil
    end,
    ["Graves"] = function()
        local ad = myHero.attackData
        local w = ad and ad.windUpTime
        if w and w > 0 then return w * 0.2 end
        return nil
    end,
    ["Aphelios"] = function()
        if not Has("ApheliosCrescendumManager") then return nil end
        local s = myHero.activeSpell
        if s and s.valid and s.name == "ApheliosCrescendumAttack" then
            return s.windup
        end
        local as = AttackApi:GetAttackSpeed()
        if as and as > 0 then return 0.1067 / as end
        return nil
    end,
}

local ANIMATION = {
    ["Graves"] = function(live)
        if live and live > 0.05 then return live * 0.9 end
        return nil
    end,
}

local SPECIAL_MELEE = {
    ["Elise"] = true,
    ["Gnar"] = true,
    ["Jayce"] = true,
    ["Kayle"] = true,
    ["Nidalee"] = true,
    ["Jade_Kayle"] = true,
    ["Jade_Nidalee"] = true,
}

local BASE_RANGE = {
    ["Zeri"] = function() return 550 end,
}

local UNDYING_ALWAYS = {
    ["Mel"] = { "melwreflect" },
    ["Kayle"] = { "kayler" },
    ["Taric"] = { "taricr" },
    ["Fiora"] = { "fioraw" },
    ["Aatrox"] = { "aatroxpassivedeath" },
    ["Vladimir"] = { "vladimirsanguinepool" },
    ["KogMaw"] = { "kogmawicathiansurprise" },
    ["Karthus"] = { "karthusdeathdefiedbuff" },
    ["Samira"] = { "samiraw" },
    ["Jade_KogMaw"] = { "jade_kogmawicathiansurprise" },
    ["Jade_Karthus"] = { "jade_karthusdeathdefiedbuff" },
}

local UNDYING_LOW_HP = {
    ["Kindred"] = { "kindredrnodeathbuff" },
    ["Zilean"] = { "chronoshift", "chronorevive" },
    ["Tryndamere"] = { "undyingrage" },
    ["Jade_Zilean"] = { "jade_zilean_chronoshift" },
    ["Jade_Tryndamere"] = { "jade_tryndamereundyingrage" },
}

local UNDYING_ON_ATTACK = {
    ["Jax"] = { "jaxe" },
    ["Shen"] = { "shenwbuff" },
    ["Jade_Jax"] = { "jade_jaxe" },
}

local LOW_HP_CUT = 15
local KINDRED_CUT = 10.1

local undyingAlways = {}
local undyingLowHp = {}
local undyingOnAttack = {}
local undyingAny = false
local hasGwenEnemy = false
local hasGangplankEnemy = false

local function AddSet(set, names)
    for i = 1, #names do
        set[names[i]] = true
        undyingAny = true
    end
end

Objects:OnEnemyHeroLoad(function(args)
    local name = args.charName
    if not name then return end
    if name == "Gwen" or name == "Jade_Gwen" then hasGwenEnemy = true end
    if name == "Gangplank" or name == "Jade_Gangplank" then hasGangplankEnemy = true end
    local a = UNDYING_ALWAYS[name]
    if a then AddSet(undyingAlways, a) end
    local b = UNDYING_LOW_HP[name]
    if b then AddSet(undyingLowHp, b) end
    local c = UNDYING_ON_ATTACK[name]
    if c then AddSet(undyingOnAttack, c) end
end)

local gwenMist = nil
local gwenScanFrame = -1

local function GwenMistValid()
    if not gwenMist then return false end
    if not gwenMist.valid then
        gwenMist = nil
        return false
    end
    local n = gwenMist.name
    if not n or not n:find("_W_MistArea", 1, true) then
        gwenMist = nil
        return false
    end
    return true
end

local function FindGwenMist(unit)
    if gwenScanFrame == Frame.n then return end
    gwenScanFrame = Frame.n
    local total = ObjectCount()
    if not total or total <= 0 or total > 100000 then return end
    local pos = unit.pos
    if not pos then return end
    for i = 1, total do
        local o = ObjectAt(i)
        if o then
            local n = o.name
            if n and n:find("_W_MistArea", 1, true) then
                local p = o.pos
                if p and DistSq(pos, p) < 600 * 600 then
                    gwenMist = o
                    return
                end
            end
        end
    end
end

local function GwenHidesTarget(unit)
    if not Buff:HasBuff(unit, "gwenwuntargetabilitymanager") then return false end
    if not GwenMistValid() then
        FindGwenMist(unit)
    end
    if not GwenMistValid() then return false end
    return DistSq(gwenMist, myHero) >= 425 * 425
end

local function TimeToHit(unit)
    local speed = AttackApi:GetProjectileSpeed()
    local fly = 0
    if speed and speed > 0 and speed < HUGE then
        fly = Dist(myHero, unit) / speed
    end
    return AttackApi:GetWindup() + fly + Net:GetLatency() * 0.5
end

local function Untargetable(unit)
    if not unit then return false end
    if hasGwenEnemy and GwenHidesTarget(unit) then return true end
    if not undyingAny then return false end
    local maxHp = unit.maxHealth
    if not maxHp or maxHp <= 0 then return false end
    local pct = 100 * (unit.health or 0) / maxHp
    local lowHp = pct < LOW_HP_CUT
    local list, n = Buff:GetBuffs(unit)
    if n == nil then n = #list end
    local horizon = nil
    for i = 1, n do
        local rec = list[i]
        local key = rec.key or (rec.name and rec.name:lower())
        if key then
            local active = false
            if undyingAlways[key] or undyingOnAttack[key] then
                active = true
            elseif undyingLowHp[key] then
                if key == "kindredrnodeathbuff" then
                    active = pct <= KINDRED_CUT
                else
                    active = lowHp
                end
            end
            if active then
                if horizon == nil then horizon = TimeToHit(unit) end
                if (rec.duration or 0) >= horizon then return true end
            end
        end
    end
    return false
end

local RESETS = {
    ["Aatrox"] = { { slot = _E, cancel = true } },
    ["Ashe"] = { { slot = _Q } },
    ["Blitzcrank"] = { { slot = _E } },
    ["Camille"] = { { slot = _Q } },
    ["Chogath"] = { { slot = _E } },
    ["Darius"] = { { slot = _W } },
    ["DrMundo"] = { { slot = _E } },
    ["Ekko"] = { { slot = _E, buff = { "ekkoeattackbuff" }, cancel = true } },
    ["Elise"] = { { slot = _W, name = "EliseSpiderW" } },
    ["Fiora"] = { { slot = _E } },
    ["Jade_Fiora"] = { { slot = _E } },
    ["Fizz"] = { { slot = _W } },
    ["Garen"] = { { slot = _Q } },
    ["Graves"] = { { slot = _E, cancel = true } },
    ["Gwen"] = { { slot = _E, cancel = true } },
    ["Illaoi"] = { { slot = _W } },
    ["Jax"] = { { slot = _W } },
    ["Jayce"] = { { slot = _W, name = "JayceHyperCharge" } },
    ["Kassadin"] = { { slot = _W } },
    ["Katarina"] = { { slot = _E, cancel = true } },
    ["Kayle"] = { { slot = _E } },
    ["Kindred"] = { { slot = _Q, cancel = true } },
    ["KSante"] = { { slot = _Q } },
    ["Leona"] = { { slot = _Q } },
    ["Jade_Leona"] = { { slot = _Q } },
    ["Lucian"] = { { slot = _E, cancel = true } },
    ["Malphite"] = { { slot = _W } },
    ["MasterYi"] = { { slot = _W } },
    ["MonkeyKing"] = { { slot = _Q } },
    ["Nasus"] = { { slot = _Q } },
    ["Nautilus"] = { { slot = _W } },
    ["Nidalee"] = { { slot = _Q, name = "Takedown" } },
    ["Nilah"] = { { slot = _E, cancel = true } },
    ["Olaf"] = { { slot = _W } },
    ["Quinn"] = { { slot = _E, cancel = true } },
    ["RekSai"] = { { slot = _Q, name = "RekSaiQ" } },
    ["Renekton"] = { { slot = _W } },
    ["Rengar"] = { { slot = _Q } },
    ["Sejuani"] = { { slot = _E, name = "SejuaniE2" } },
    ["Sett"] = { { slot = _Q } },
    ["Shyvana"] = { { slot = _Q } },
    ["Jade_Shyvana"] = { { slot = _Q } },
    ["Sivir"] = { { slot = _W } },
    ["Talon"] = { { slot = _Q, cancel = true } },
    ["Trundle"] = { { slot = _Q } },
    ["TwistedFate"] = {
        { slot = _W, name = "GoldCardLock", buff = { "goldcardpreattack" }, cancel = true },
        { slot = _W, name = "BlueCardLock", buff = { "bluecardpreattack" }, cancel = true },
        { slot = _W, name = "RedCardLock", buff = { "redcardpreattack" }, cancel = true },
    },
    ["Vayne"] = { { slot = _Q, buff = { "vaynetumblebonus" }, cancel = true } },
    ["Jade_Vayne"] = { { slot = _Q, buff = { "jade_vayneq_bonus" }, cancel = true } },
    ["Vi"] = { { slot = _E } },
    ["Volibear"] = { { slot = _Q } },
    ["XinZhao"] = { { slot = _Q } },
    ["Jade_XinZhao"] = { { slot = _Q } },
    ["Yorick"] = { { slot = _Q, name = "YorickQ" } },
    ["Yunara"] = {
        { slot = _Q },
        { slot = _E, name = "YunaraE2", cancel = true },
        { slot = _R, blockBuff = "yunaraq" },
    },
    ["Zaahen"] = {
        { slot = _Q, name = "ZaahenQ" },
        { slot = _Q, name = "ZaahenQ2" },
    },
}

local function InstallResets(entries)
    local count = #entries
    local lastSpell = {}
    local lastCastTime = {}
    local pending = {}
    for i = 1, count do
        lastSpell[i] = 0
        lastCastTime[i] = nil
        pending[i] = false
    end

    H.AttackReset = function()
        local fired = false
        local s = myHero.activeSpell
        local spellName, spellEnd
        if s and s.valid then
            spellName = s.name
            spellEnd = s.castEndTime or 0
        end
        for i = 1, count do
            local e = entries[i]
            local data = myHero:GetSpellData(e.slot)
            local level = data and data.level or 0
            if level > 0 then
                local castTime = data.castTime
                if lastCastTime[i] == nil then lastCastTime[i] = castTime end
                local blocked = e.blockBuff and Has(e.blockBuff)
                if blocked then
                    pending[i] = false
                else
                    local want = e.name or data.name
                    local nameOk = (not e.name) or (data.name == e.name)
                    if spellName and want and spellName == want and spellEnd > lastSpell[i] then
                        lastSpell[i] = spellEnd
                        pending[i] = true
                    elseif nameOk and castTime and castTime ~= lastCastTime[i] then
                        pending[i] = true
                    end
                    if pending[i] then
                        if not e.buff then
                            pending[i] = false
                            fired = true
                        elseif Buff:ContainsBuffs(myHero, e.buff) then
                            pending[i] = false
                            fired = true
                        elseif CanUseSpell(e.slot) == 0 then
                            pending[i] = false
                        end
                    end
                end
                lastCastTime[i] = castTime
            end
        end
        return fired
    end
end

local Sweep = {
    active = false,
    index = 1,
    total = 0,
    slices = 24,
    building = {},
    buildingN = 0,
    seen = {},
    found = {},
    foundN = 0,
    wanted = {},
    any = false,
}

function Sweep:Want(name)
    self.wanted[name] = true
    self.any = true
end

function Sweep:Step()
    if not self.any then return end
    if not self.active then
        local total = ObjectCount()
        if not total or total <= 0 or total > 100000 then return end
        self.active = true
        self.index = 1
        self.total = total
        self.buildingN = 0
        for k in pairs(self.seen) do self.seen[k] = nil end
    end

    local budget = floor(self.total / self.slices)
    if budget < 1 then budget = 1 end
    local last = self.index + budget - 1
    if last > self.total then last = self.total end

    local wanted = self.wanted
    local building = self.building
    local n = self.buildingN
    local seen = self.seen
    for i = self.index, last do
        local o = ObjectAt(i)
        if o and o.type == Obj_AI_Minion and o.valid and o.visible and not o.dead and not o.isImmortal then
            local cn = o.charName
            if cn then
                local key = cn:lower()
                if wanted[key] then
                    local id = o.networkID or o.handle
                    if id and not seen[id] then
                        seen[id] = true
                        n = n + 1
                        building[n] = o
                    end
                end
            end
        end
    end
    self.buildingN = n

    if last >= self.total then
        self.active = false
        self.index = 1
        local swap = self.found
        self.found = self.building
        self.foundN = n
        self.building = swap
        self.buildingN = 0
        for i = n + 1, #self.found do self.found[i] = nil end
    else
        self.index = last + 1
    end
end

function Sweep:Each(name, fn)
    for i = 1, self.foundN do
        local o = self.found[i]
        if o and o.valid and o.visible and not o.dead then
            local cn = o.charName
            if cn and cn:lower() == name then
                local r = fn(o)
                if r then return r end
            end
        end
    end
    return nil
end

local function BarrelDecayRate(gp)
    local lvl = (gp.levelData and gp.levelData.lvl) or 1
    if lvl >= 13 then return 0.5 end
    if lvl >= 7 then return 1 end
    return 2
end

local gangplank = nil

local function PickBarrel()
    local gp = gangplank
    if not gp or not gp.valid then return nil end
    local decay = BarrelDecayRate(gp)
    local now = Timer()
    return Sweep:Each("gangplankbarrel", function(barrel)
        local hp = barrel.health or 0
        if hp <= 1 then return barrel end
        if hp <= 2 then
            local start = Buff:GetBuffStartTime(barrel, "gangplankebarrelactive")
            if start and start > 0 then
                local next1 = start + decay
                local nextDecay = (now < next1) and next1 or (start + decay * 2)
                if nextDecay <= now + TimeToHit(barrel) then
                    return barrel
                end
            end
        end
        return nil
    end)
end

local function PickSoul()
    if Health.anyKillable then return nil end
    return Sweep:Each("sennasoul", function(soul) return soul end)
end

local azirSoldiers = {}
local azirN = 0

local function AzirRefresh()
    local n = 0
    for i = 1, azirN do
        local s = azirSoldiers[i]
        if s and s.valid and s.name == "AzirSoldier" and (s.health or 0) > 0 then
            n = n + 1
            azirSoldiers[n] = s
        end
    end
    for i = n + 1, azirN do azirSoldiers[i] = nil end
    azirN = n

    local s = myHero.activeSpell
    if not (s and s.valid and s.name == "AzirWSpawnSoldier") then return end

    local total = ObjectCount()
    if not total or total <= 0 or total > 100000 then return end
    for i = 1, total do
        local o = ObjectAt(i)
        if o and o.name == "AzirSoldier" and o.pos and DistSq(myHero, o) <= 1000 * 1000 then
            local exists = false
            local h = o.handle
            for j = 1, azirN do
                if azirSoldiers[j].handle == h then
                    exists = true
                    break
                end
            end
            if not exists then
                azirN = azirN + 1
                azirSoldiers[azirN] = o
            end
        end
    end
end

local function AzirInRange(target)
    if azirN == 0 then return false end
    local command = (myHero.range == 575) and 830 or 780
    local c2 = command * command
    for i = 1, azirN do
        local s = azirSoldiers[i]
        if s and s.valid and (s.health or 0) > 0 then
            if DistSq(s, myHero) < c2 and DistSq(s, target) < 350 * 350 then
                return true
            end
        end
    end
    return false
end

local function CrescendumBusy()
    local total = MissileCount()
    if not total or total <= 0 or total > 20000 then return false end
    local mine = myHero.handle
    for i = total, 1, -1 do
        local m = MissileAt(i)
        local d = m and m.missileData
        if d and d.owner == mine then
            local n = d.name
            if n == "ApheliosCrescendumAttackMisOut" or n == "ApheliosCrescendumAttackMisIn" then
                return true
            end
        end
    end
    return false
end

local caitlynMarkE = {}
local caitlynMarkW = {}

local function CaitlynExtraRange(target)
    if not target then return 0 end
    local id = target.networkID
    if not id then return 0 end
    local eStart = Buff:GetBuffStartTime(target, "eternals_caitlyneheadshottracker")
    local wStart = Buff:GetBuffStartTime(target, "caitlynwsight")
    local hasE = eStart > 0 and caitlynMarkE[id] ~= eStart
    local hasW = wStart > 0
        and Buff:GetBuffDuration(target, "caitlynwsight") > 0.75
        and caitlynMarkW[id] ~= wStart
    if hasE or hasW then
        return max(0, 1300 - myHero.range - myHero.boundingRadius - (target.boundingRadius or 0))
    end
    return 0
end

local function CaitlynConsume()
    local s = myHero.activeSpell
    if not (s and s.valid and s.name == "CaitlynPassiveMissile") then return end
    local target = Walker.LastTarget
    if not target or not target.valid then return end
    if s.target and target.handle ~= s.target then return end
    local id = target.networkID
    if not id then return end
    local eStart = Buff:GetBuffStartTime(target, "eternals_caitlyneheadshottracker")
    if eStart > 0 and caitlynMarkE[id] ~= eStart then
        caitlynMarkE[id] = eStart
        return
    end
    local wStart = Buff:GetBuffStartTime(target, "caitlynwsight")
    if wStart > 0 and caitlynMarkW[id] ~= wStart then
        caitlynMarkW[id] = wStart
    end
end

local function ApheliosExtraRange(target)
    if not target then return 0 end
    if not Has("aphelioscalibrumbonusrangebuff") then return 0 end
    if not Buff:HasBuff(target, "aphelioscalibrumbonusrangedebuff") then return 0 end
    return max(0, 1800 - myHero.range - myHero.boundingRadius - (target.boundingRadius or 0))
end

local function GravesBonus(from, target, raw)
    local br = target.boundingRadius or 0
    local pointBlank = br > 0 and DistSq(from, target) < (br / 0.212) * (br / 0.212)
    if pointBlank then return raw, 0, 0 end
    return raw * 0.33, 0, 0
end

local installed = {}

local function Note(what)
    installed[#installed + 1] = what
end

local Menu = MenuElement({ type = MENU, id = "LowkeyChampions", name = "Lowkey Champion Quirks" })
Menu:MenuElement({ id = "barrel", name = "Attack Gangplank barrels", value = true })
Menu:MenuElement({ id = "soul", name = "Collect Senna souls", value = true })
Menu:MenuElement({ id = "undying", name = "Skip undying enemies", value = true })
Menu:MenuElement({ id = "reset", name = "Detect ability attack resets", value = true })

local channel = CHANNELING[NAME]
if channel then
    H.Channeling = channel
    Note("channel")
end

local allowMove = ALLOW_MOVE_CHANNEL[NAME]
if allowMove then
    H.AllowMoveWhileChanneling = allowMove
    Note("channelmove")
end

local blockMove = BLOCK_MOVE[NAME]
if blockMove then
    H.BlockMove = blockMove
    Note("blockmove")
end

local forceMove = FORCE_MOVE[NAME]
if forceMove then
    H.ForceMove = forceMove
    Note("forcemove")
end

local missile = MISSILE_SPEED[NAME]
if missile then
    H.MissileSpeed = missile
    Note("missile")
end

local windup = WINDUP[NAME]
if windup then
    H.Windup = windup
    Note("windup")
end

local animation = ANIMATION[NAME]
if animation then
    H.Animation = animation
    Note("animation")
end

local baseRange = BASE_RANGE[NAME]
if baseRange then
    H.BaseRange = baseRange
    Note("baserange")
end

if SPECIAL_MELEE[NAME] then
    H.Melee = function() return myHero.range < 200 end
    Note("melee")
end

local blockAttack = BLOCK_ATTACK[NAME]
if NAME == "Aphelios" then
    H.BlockAttack = function()
        if Has("ApheliosCrescendumManager") and CrescendumBusy() then return true end
        return false
    end
    Note("crescendum")
elseif blockAttack then
    H.BlockAttack = blockAttack
    Note("blockattack")
end

if NAME == "Caitlyn" then
    H.ExtraRange = CaitlynExtraRange
    Walker:OnAttack(CaitlynConsume)
    Note("caitlynmark")
elseif NAME == "Aphelios" then
    H.ExtraRange = ApheliosExtraRange
    Note("calibrum")
end

if NAME == "Graves" then
    H.BonusAutoAttackDamage = GravesBonus
    Note("shotgun")
end

local resets = RESETS[NAME]
if resets then
    InstallResets(resets)
    local detect = H.AttackReset
    H.AttackReset = function()
        if not Menu.reset:Value() then return false end
        return detect()
    end
    Note("reset")
end

if NAME == "Azir" then
    H.InRange = AzirInRange
    Note("soldiers")
end

local wantBarrel = false
local wantSoul = NAME == "Senna"
if wantSoul then
    Sweep:Want("sennasoul")
    Note("souls")
end

Objects:OnEnemyHeroLoad(function(args)
    if args.charName == "Gangplank" or args.charName == "Jade_Gangplank" then
        gangplank = args.unit
        if not wantBarrel then
            wantBarrel = true
            Sweep:Want("gangplankbarrel")
        end
    end
end)

H.Untargetable = function(unit)
    if not Menu.undying:Value() then return false end
    return Untargetable(unit)
end

Note("undying")

H.PriorityTarget = function(modes)
    if wantBarrel and Menu.barrel:Value() then
        local barrel = PickBarrel()
        if barrel then return barrel end
    end
    if wantSoul and Menu.soul:Value() then
        if modes[sdk.ORBWALKER_MODE_LASTHIT]
            or modes[sdk.ORBWALKER_MODE_LANECLEAR]
            or modes[sdk.ORBWALKER_MODE_HARASS]
        then
            local soul = PickSoul()
            if soul then return soul end
        end
    end
    return nil
end

local ticks = sdk.OnTick
ticks[#ticks + 1] = function()
    if NAME == "Azir" then
        AzirRefresh()
    end
    Sweep:Step()
end

local tag = "none"
if #installed > 0 then
    tag = table.concat(installed, ",")
end

print("[LowkeyChampions] v" .. __version__ .. " | " .. NAME .. " | " .. tag)
