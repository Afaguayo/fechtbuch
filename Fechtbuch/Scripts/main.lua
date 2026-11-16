-- FECHTBUCH: combat HUD for Half Sword (UE4SS Lua mod)
--   * Your panel: body diagram (limbs colored by health, broken bones pulse, dislocations
--     violet, fresh hits flash), bars, injury list, damage summary.
--   * Press Z to tag the enemy under your crosshair (or the nearest one). Only the tagged
--     enemy gets a stats card (incl. weight, height, strength), a tag over their head and
--     floating damage numbers. Press Z on them again to untag. Unfocused enemies show nothing.
--   * Your panel also shows weight/height and strength + skill progress bars.
--   * Home opens the Fechtbuch menu: choose what shows, where panels go and how big they are.
--     Settings are saved to settings.txt next to this mod.
--
-- Keys:  Z tag enemy   Home menu (arrows + Enter inside)   F7 HUD on/off   F8 reset counters   F9 dump properties

local UEHelpers = require("UEHelpers")

local VERSION      = "1.2.1"

local TICK_MS      = 33     -- HUD refresh (~30 fps)
local SCAN_EVERY   = 300    -- look for new fighter classes every N ticks (~10 s)
local HIT_MIN      = 0.5    -- smallest health drop counted as a hit
local HIT_MERGE    = 6      -- drops within this many ticks count as one blow
local FOCUS_RANGE  = 20     -- meters

---------------------------------------------------------------------------
-- Property names (Early Access Willie_BP, checked on 0.6.1.5 and 0.7; matched ignoring
-- case/spaces/underscores). A name the game no longer has reads as nil and its readout shows "-".
---------------------------------------------------------------------------
local STATS = {
    hp        = { "Health" },
    cons      = { "Consciousness" },
    stamina   = { "Stamina" },
    energy    = { "SMH Energy" },                              -- 0.7 energy system, 0..1
    pain      = { "Pain" },
    bleed     = { "Bleeding" },
    dead      = { "DED" },
    team      = { "Team Int" },
    shock     = { "Pain Shock" },
    guts      = { "Guts Spilled" },
    locked    = { "Camera Locked" },
    lockFound = { "Lock On Found" },
    muscle    = { "Muscle Power" },
    muscleRate = { "Muscle Rate" },
    muscleDue = { "Muscle Rate Due", "Muscle Growth Due" },   -- renamed in 0.7
    wSkill    = { "Weapon Skill (Temp)" },
    wSkillDue = { "Weapon Skill Due (Temp)" },
    bSkill    = { "Body Skill (Temp)" },
    bSkillDue = { "Body Skill Due (Temp)" },
}
-- Equipment weight (kg) the game tracks per body area
local GEAR = { "Armor Weight Head", "Armor Weight Body", "Armor Weight Arm R", "Armor Weight Arm L", "Armor Weight Legs", "All Weapons Weights" }
local PARTS = {
    head  = { "Head Health" },
    neck  = { "Neck Health" },
    upper = { "Body Upper Health", "Body Health" },
    lower = { "Body Lower Health" },
    back  = { "Back Health" },
    heart = { "Heart Health" },                                -- new in 0.7
    armR  = { "Arm_R Health" }, armL = { "Arm_L Health" },
    legR  = { "Leg_R Health" }, legL = { "Leg_L Health" },
}
local BROKEN = {
    head = { "Head Broken" }, back = { "Back Broken" },
    armR = { "Arm R Broken" }, armL = { "Arm L Broken" },
    legR = { "Leg R Broken" }, legL = { "Leg L Broken" },
}
local DISLOCATED = {
    neck = { "Neck Dislocated" }, back = { "Spine Dislocated" },
    armR = { "Arm R Dislocated" }, armL = { "Arm L Dislocated" },
    legR = { "Leg R Dislocated" }, legL = { "Leg L Dislocated" },
}
local REGIONS = {
    { "head", "Head" }, { "neck", "Neck" }, { "upper", "Chest" }, { "heart", "Heart" }, { "lower", "Abdomen" }, { "back", "Back" },
    { "armR", "Right arm" }, { "armL", "Left arm" }, { "legR", "Right leg" }, { "legL", "Left leg" },
}

-- Body diagram, front view (the fighter's right side is on the left). Pixels at size 100%.
local SEGMENTS = {
    { id = "head",   x = 46, y = 0,   w = 28, h = 32, parts = { "head" },          broken = "head", round = 14 },
    { id = "neck",   x = 54, y = 33,  w = 12, h = 10, parts = { "neck" },          disloc = "neck" },
    { id = "chest",  x = 34, y = 44,  w = 52, h = 52, parts = { "upper", "back", "heart" }, broken = "back", disloc = "back", round = 6 },
    { id = "pelvis", x = 38, y = 97,  w = 44, h = 36, parts = { "lower" },         round = 6 },
    { id = "uArmR",  x = 16, y = 46,  w = 16, h = 46, parts = { "armR" }, broken = "armR", disloc = "armR", round = 6 },
    { id = "fArmR",  x = 12, y = 93,  w = 15, h = 44, parts = { "armR" }, broken = "armR", round = 6 },
    { id = "handR",  x = 10, y = 138, w = 15, h = 16, parts = { "armR" }, round = 6 },
    { id = "uArmL",  x = 88, y = 46,  w = 16, h = 46, parts = { "armL" }, broken = "armL", disloc = "armL", round = 6 },
    { id = "fArmL",  x = 93, y = 93,  w = 15, h = 44, parts = { "armL" }, broken = "armL", round = 6 },
    { id = "handL",  x = 95, y = 138, w = 15, h = 16, parts = { "armL" }, round = 6 },
    { id = "thighR", x = 38, y = 135, w = 20, h = 56, parts = { "legR" }, broken = "legR", disloc = "legR", round = 6 },
    { id = "shinR",  x = 39, y = 192, w = 18, h = 52, parts = { "legR" }, broken = "legR", round = 6 },
    { id = "footR",  x = 34, y = 245, w = 24, h = 12, parts = { "legR" }, round = 5 },
    { id = "thighL", x = 62, y = 135, w = 20, h = 56, parts = { "legL" }, broken = "legL", disloc = "legL", round = 6 },
    { id = "shinL",  x = 63, y = 192, w = 18, h = 52, parts = { "legL" }, broken = "legL", round = 6 },
    { id = "footL",  x = 62, y = 245, w = 24, h = 12, parts = { "legL" }, round = 5 },
}
local BODY_W, BODY_H = 120, 257

local COLORS = {
    text     = { R = 0.93, G = 0.89, B = 0.80, A = 1 },
    dim      = { R = 0.70, G = 0.66, B = 0.58, A = 0.85 },
    gold     = { R = 0.95, G = 0.78, B = 0.40, A = 1 },
    barBg    = { R = 0, G = 0, B = 0, A = 0.55 },
    hp       = { R = 0.78, G = 0.10, B = 0.07, A = 0.95 },
    cons     = { R = 0.55, G = 0.75, B = 0.95, A = 0.95 },
    stamina  = { R = 0.95, G = 0.70, B = 0.25, A = 0.95 },
    energy   = { R = 0.60, G = 0.85, B = 0.35, A = 0.95 },
    pain     = { R = 0.70, G = 0.40, B = 0.90, A = 0.95 },
    bleed    = { R = 0.55, G = 0.00, B = 0.02, A = 0.95 },
    unknown  = { R = 0.45, G = 0.45, B = 0.45, A = 0.30 },
    broken   = { R = 0.30, G = 0.00, B = 0.02, A = 0.98 },
    brokenHi = { R = 0.75, G = 0.05, B = 0.05, A = 0.98 },
    disloc   = { R = 0.62, G = 0.32, B = 0.95, A = 0.95 },
    hitBig   = { R = 1.00, G = 0.20, B = 0.10, A = 1 },
    hitMid   = { R = 1.00, G = 0.75, B = 0.25, A = 1 },
    hitLow   = { R = 1.00, G = 0.97, B = 0.90, A = 1 },
    on       = { R = 0.55, G = 0.90, B = 0.45, A = 1 },
    off      = { R = 0.55, G = 0.52, B = 0.48, A = 1 },
    menuBg   = { R = 0.03, G = 0.025, B = 0.02, A = 0.97 },
    menuSel  = { R = 0.95, G = 0.78, B = 0.40, A = 0.18 },
    strength = { R = 0.85, G = 0.45, B = 0.20, A = 0.95 },
    wSkill   = { R = 0.80, G = 0.80, B = 0.85, A = 0.95 },
    bSkill   = { R = 0.45, G = 0.80, B = 0.60, A = 0.95 },
    pending  = { R = 1.00, G = 1.00, B = 1.00, A = 0.30 },
}

local BAR_DEFS = {
    { key = "health",  title = "HEALTH",        color = COLORS.hp,      h = 8 },
    { key = "cons",    title = "CONSCIOUSNESS", color = COLORS.cons,    h = 6 },
    { key = "stamina", title = "STAMINA",       color = COLORS.stamina, h = 6 },
    { key = "energy",  title = "ENERGY",        color = COLORS.energy,  h = 6 },
    { key = "pain",    title = "PAIN",          color = COLORS.pain,    h = 6 },
    { key = "bleed",   title = "BLEEDING",      color = COLORS.bleed,   h = 6 },
}

local MOD_DIR = (debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)[/\\]Scripts[/\\]") or ".")
local function Log(fmt, ...) print(string.format("[Fechtbuch] " .. fmt .. "\n", ...)) end

---------------------------------------------------------------------------
-- Settings + menu definition
---------------------------------------------------------------------------
local POSITIONS = { "Top Left", "Top Center", "Top Right", "Middle Left", "Middle Right", "Bottom Left", "Bottom Center", "Bottom Right" }
local POS_ANCHOR = {
    ["Top Left"] = { 0, 0 }, ["Top Center"] = { 0.5, 0 }, ["Top Right"] = { 1, 0 },
    ["Middle Left"] = { 0, 0.5 }, ["Middle Right"] = { 1, 0.5 },
    ["Bottom Left"] = { 0, 1 }, ["Bottom Center"] = { 0.5, 1 }, ["Bottom Right"] = { 1, 1 },
}
local FOCUS_MODES = { "Z tag only", "Z tag + lock-on", "Z tag + crosshair", "Z tag + nearest" }

local function PanelItems(prefix, pos, scale)
    return {
        { key = prefix .. ".show",     label = "Show",              type = "bool",   default = true },
        { key = prefix .. ".pos",      label = "Position",          type = "choice", choices = POSITIONS, default = pos },
        { key = prefix .. ".scale",    label = "Size",              type = "num",    min = 0.4, max = 1.6, step = 0.05, default = scale, pct = true },
        { key = prefix .. ".offX",     label = "Nudge left/right",  type = "num",    min = -1500, max = 1500, step = 10, default = 0 },
        { key = prefix .. ".offY",     label = "Nudge up/down",     type = "num",    min = -1000, max = 1000, step = 10, default = 0 },
        { key = prefix .. ".body",     label = "Body diagram",      type = "bool",   default = true },
        { key = prefix .. ".health",   label = "Health bar",        type = "bool",   default = true },
        { key = prefix .. ".cons",     label = "Consciousness bar", type = "bool",   default = true },
        { key = prefix .. ".stamina",  label = "Stamina bar",       type = "bool",   default = true },
        { key = prefix .. ".energy",   label = "Energy bar",        type = "bool",   default = true },
        { key = prefix .. ".pain",     label = "Pain bar",          type = "bool",   default = true },
        { key = prefix .. ".bleed",    label = "Bleeding bar",      type = "bool",   default = true },
        { key = prefix .. ".injuries", label = "Injury list",       type = "bool",   default = true },
        { key = prefix .. ".damage",   label = "Damage summary",    type = "bool",   default = true },
        { key = prefix .. ".physique", label = "Weight / height / strength", type = "bool", default = true },
    }
end

local MENU = { { header = "GENERAL" },
    { key = "hud",       label = "Fechtbuch HUD (F7)", type = "bool", default = true },
    { key = "bgOpacity", label = "Panel background",    type = "num",  min = 0, max = 0.9, step = 0.05, default = 0.45, pct = true },
    { header = "YOUR PANEL" },
}
for _, it in ipairs(PanelItems("you", "Bottom Left", 0.75)) do table.insert(MENU, it) end
table.insert(MENU, { key = "you.progress", label = "Strength & skill progress", type = "bool", default = true })
table.insert(MENU, { key = "you.hit", label = "Damage taken pop-up", type = "bool", default = true })
table.insert(MENU, { header = "FOCUSED ENEMY" })
table.insert(MENU, { key = "enemy.focusMode", label = "Focus with", type = "choice", choices = FOCUS_MODES, default = "Z tag only" })
for _, it in ipairs(PanelItems("enemy", "Top Right", 0.65)) do
    if it.key == "enemy.show" then it.label = "Stats card" end
    table.insert(MENU, it)
end
table.insert(MENU, { key = "enemy.tag",      label = "Tag over their head", type = "bool", default = true })
table.insert(MENU, { key = "enemy.tagScale", label = "Tag size",            type = "num",  min = 0.5, max = 2, step = 0.1, default = 1, pct = true })
table.insert(MENU, { key = "enemy.numbers",  label = "Damage numbers",      type = "bool", default = true })
table.insert(MENU, { header = "" })
table.insert(MENU, { key = "reset", label = "Reset everything to defaults", type = "action" })
table.insert(MENU, { key = "close", label = "Close menu (Home)",             type = "action" })

local S = {}
local function Defaults()
    local d = {}
    for _, it in ipairs(MENU) do if it.key and it.default ~= nil then d[it.key] = it.default end end
    return d
end

local SETTINGS_FILE = MOD_DIR .. "\\settings.txt"

local function LoadSettings()
    S = Defaults()
    local f = io.open(SETTINGS_FILE, "r")
    if not f then return end
    for line in f:lines() do
        local k, v = line:match("^%s*([%w%.]+)%s*=%s*(.-)%s*$")
        if k and S[k] ~= nil then
            if type(S[k]) == "boolean" then S[k] = (v == "true")
            elseif type(S[k]) == "number" then S[k] = tonumber(v) or S[k]
            else S[k] = v end
        end
    end
    f:close()
end

local function SaveSettings()
    local f = io.open(SETTINGS_FILE, "w")
    if not f then return end
    f:write("-- Fechtbuch settings (edit in game with the Home key)\n")
    for _, it in ipairs(MENU) do
        if it.key and S[it.key] ~= nil then f:write(it.key .. " = " .. tostring(S[it.key]) .. "\n") end
    end
    f:close()
end

LoadSettings()

---------------------------------------------------------------------------
-- Object helpers
---------------------------------------------------------------------------
local function Valid(obj)
    local ok, v = pcall(function() return obj ~= nil and obj:IsValid() end)
    return ok and v
end

local function Addr(obj)
    local ok, a = pcall(function() return obj:GetAddress() end)
    return ok and a or tostring(obj)
end

local function ClassName(obj)
    local ok, n = pcall(function() return obj:GetClass():GetFName():ToString() end)
    return ok and n or "?"
end

local function Vec(v)
    if v == nil then return nil end
    local ok, r = pcall(function() return { X = v.X, Y = v.Y, Z = v.Z } end)
    if ok and type(r.X) == "number" and type(r.Z) == "number" then return r end
    return nil
end

local function ActorLocation(obj)
    local ok, l = pcall(function() return obj:K2_GetActorLocation() end)
    return ok and Vec(l) or nil
end

-- Half Sword characters are ragdolls, so ask the mesh where the head is
local function HeadLocation(obj)
    local ok, l = pcall(function() return obj.Mesh:GetSocketLocation(FName("head")) end)
    local v = ok and Vec(l) or nil
    if v and (v.X ~= 0 or v.Y ~= 0 or v.Z ~= 0) then return v end
    v = ActorLocation(obj)
    if v then v.Z = v.Z + 80 end
    return v
end

local function Dist(a, b)
    if not a or not b then return math.huge end
    return math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2 + (a.Z - b.Z) ^ 2) / 100
end

---------------------------------------------------------------------------
-- Property name resolution (per class, once)
---------------------------------------------------------------------------
local function Norm(s) return (s:lower():gsub("[%s_]", "")) end
local resolved = {}

local function ResolveClass(obj)
    local cname = ClassName(obj)
    if resolved[cname] then return resolved[cname] end
    local have = {}
    pcall(function()
        local cls = obj:GetClass()
        while Valid(cls) do
            local n = cls:GetFName():ToString()
            if n == "Character" or n == "Pawn" or n == "Actor" then break end
            cls:ForEachProperty(function(prop)
                local pn = prop:GetFName():ToString()
                have[Norm(pn)] = pn
            end)
            cls = cls:GetSuperStruct()
        end
    end)
    local function pick(list)
        for _, cand in ipairs(list) do
            local real = have[Norm(cand)]
            if real then return real end
        end
        return nil
    end
    local r = { stats = {}, parts = {}, broken = {}, disloc = {}, lockAt = have[Norm("Lock Camera At")], gear = {} }
    for _, g in ipairs(GEAR) do if have[Norm(g)] then table.insert(r.gear, have[Norm(g)]) end end
    for k, list in pairs(STATS) do r.stats[k] = pick(list) end
    for k, list in pairs(PARTS) do r.parts[k] = pick(list) end
    for k, list in pairs(BROKEN) do r.broken[k] = pick(list) end
    for k, list in pairs(DISLOCATED) do r.disloc[k] = pick(list) end
    resolved[cname] = r
    if r.stats.hp then
        local missing = {}
        for k in pairs(STATS) do if not r.stats[k] then table.insert(missing, "stat:" .. k) end end
        for k in pairs(PARTS) do if not r.parts[k] then table.insert(missing, "part:" .. k) end end
        for k in pairs(BROKEN) do if not r.broken[k] then table.insert(missing, "broken:" .. k) end end
        for k in pairs(DISLOCATED) do if not r.disloc[k] then table.insert(missing, "disloc:" .. k) end end
        Log("class %s resolved; missing: %s", cname, #missing > 0 and table.concat(missing, ", ") or "none")
        -- Game updates rename and add stats (0.7: energy, healing wounds, factions). List the
        -- candidates so the log alone is enough to extend the tables above.
        local used, extra = {}, {}
        for _, t in ipairs({ r.stats, r.parts, r.broken, r.disloc }) do for _, pn in pairs(t) do used[pn] = true end end
        for _, pn in pairs(have) do
            local l = pn:lower()
            if not used[pn] and #extra < 60 and (l:find("energy") or l:find("stamina") or l:find("muscle") or l:find("skill")
                or l:find("wound") or l:find("heal") or l:find("faction") or l:find("lock on") or l:find("exhaust") or l:find("fear")) then
                table.insert(extra, pn)
            end
        end
        table.sort(extra)
        if #extra > 0 then Log("class %s unmapped: %s", cname, table.concat(extra, " | ")) end
    end
    return r
end

local function Read(obj, name)
    if not name then return nil end
    local ok, v = pcall(function() return obj[name] end)
    if ok and (type(v) == "number" or type(v) == "boolean") then return v end
    return nil
end

---------------------------------------------------------------------------
-- Per-character tracking
---------------------------------------------------------------------------
local states = {}
local session = { dealt = 0, dealtHits = 0, maxDealt = 0, kills = 0 }
local tickNo = 0

local function NewState()
    return { max = {}, prev = {}, taken = 0, hits = 0, lastHit = 0, maxHit = 0,
             curHit = 0, curHitTick = -100, newHit = false, dead = false, seen = 0,
             dealtTo = 0, flash = {}, segPrev = {} }
end

local function Pct(v, mx)
    if type(v) ~= "number" or mx == nil or mx <= 0 then return nil end
    return math.max(0, math.min(100, v / mx * 100))
end

-- Everything only the panels show. Read for you and the focused enemy, not for the whole arena:
-- it is ~40 property reads plus bone lookups per fighter.
local function ReadDetails(c)
    if c.full then return c end
    c.full = true
    local obj, st, r = c.obj, c.st, c.r
    for k, name in pairs(r.stats) do if c[k] == nil then c[k] = Read(obj, name) end end
    -- the game uses a 0-100 scale; start there so a fighter first seen hurt still reads correctly
    for _, k in ipairs({ "cons", "stamina" }) do
        if type(c[k]) == "number" and (st.max[k] == nil or c[k] > st.max[k]) then st.max[k] = math.max(c[k], 100) end
    end
    for k, name in pairs(r.parts) do
        local v = Read(obj, name)
        if type(v) == "number" then
            local mk = "p_" .. k
            if st.max[mk] == nil or v > st.max[mk] then st.max[mk] = math.max(v, 100) end
            c.part[k] = Pct(v, st.max[mk])
        end
    end
    for k, name in pairs(r.broken) do c.broken[k] = Read(obj, name) == true end
    for k, name in pairs(r.disloc) do c.disloc[k] = Read(obj, name) == true end

    -- weight: physics mass of the whole body; gear: armor + weapons; height: head bone to feet
    if tickNo - (st.physTick or -1000) >= 30 then
        st.physTick = tickNo
        -- GetMass walks every physics body; doing it on a fighter being torn down crashed the game,
        -- so read it once, from a fighter that has been alive for a while
        st.aliveTicks = (st.aliveTicks or 0) + (c.isDead and 0 or 30)
        if not st.massKg and not c.isDead and st.aliveTicks >= 60 then
            pcall(function()
                local m = obj.Mesh:GetMass()
                if type(m) == "number" and m > 1 then st.massKg = m end
            end)
        end
        local gear = 0
        for _, g in ipairs(r.gear) do local v = Read(obj, g); if type(v) == "number" then gear = gear + v end end
        st.gearKg = gear
        if not c.isDead then
            pcall(function()
                local hz = obj.Mesh:GetSocketLocation(FName("head")).Z
                local fl = obj.Mesh:GetSocketLocation(FName("foot_l")).Z
                local fr = obj.Mesh:GetSocketLocation(FName("foot_r")).Z
                local h = hz - math.min(fl, fr) + 18   -- bone centers -> top of head / soles
                if h > 120 and h < 240 and h > (st.heightCm or 0) then st.heightCm = h end
            end)
        end
    end

    for _, s in ipairs(SEGMENTS) do
        local v = nil
        for _, p in ipairs(s.parts) do
            local pv = c.part[p]
            if pv and (v == nil or pv < v) then v = pv end
        end
        c.seg[s.id] = v
        local prev = st.segPrev[s.id]
        if v and prev and prev - v > 0.5 then st.flash[s.id] = 1 end
        st.segPrev[s.id] = v
        st.flash[s.id] = math.max(0, (st.flash[s.id] or 0) - 0.05)
    end
    return c
end

-- Vitals and hit tracking for any fighter; full = also read the panel details
local function ReadCharacter(obj, full)
    local a = Addr(obj)
    local st = states[a]
    if not st then st = NewState(); states[a] = st end
    st.seen = tickNo
    local r = ResolveClass(obj)

    local c = { obj = obj, st = st, r = r, part = {}, broken = {}, disloc = {}, seg = {} }
    c.hp, c.dead, c.team = Read(obj, r.stats.hp), Read(obj, r.stats.dead), Read(obj, r.stats.team)
    if type(c.hp) == "number" and (st.max.hp == nil or c.hp > st.max.hp) then st.max.hp = math.max(c.hp, 100) end
    c.isDead = (c.dead == true) or (type(c.hp) == "number" and c.hp <= 0)

    c.drop, st.newHit = 0, false
    if type(c.hp) == "number" then
        local prev = st.prev.hp
        st.prev.hp = c.hp
        if prev and prev - c.hp >= HIT_MIN then
            local drop = prev - c.hp
            c.drop = drop
            st.taken = st.taken + drop
            if tickNo - st.curHitTick <= HIT_MERGE then
                st.curHit = st.curHit + drop
            else
                st.curHit = drop
                st.hits = st.hits + 1
                st.newHit = true
            end
            st.curHitTick = tickNo
            st.lastHit = st.curHit
            if st.curHit > st.maxHit then st.maxHit = st.curHit end
        end
    end

    if full then ReadDetails(c) end
    return c
end

local function InjuryLabel(pct)
    if pct == nil then return nil end
    if pct <= 0 then return "Destroyed", 4 end
    if pct < 30 then return "Critical", 3 end
    if pct < 60 then return "Wounded", 2 end
    if pct < 90 then return "Bruised", 1 end
    return nil
end

local function Injuries(c)
    local list = {}
    if c.guts == true then table.insert(list, { text = "Guts spilled", sev = 4, rank = -3 }) end
    if c.shock == true and not c.isDead then table.insert(list, { text = "Pain shock", sev = 3, rank = -2 }) end
    for _, reg in ipairs(REGIONS) do
        local k, name = reg[1], reg[2]
        local pct = c.part[k]
        local tags = {}
        local sev, rank = 0, pct or 100
        if c.broken[k] then table.insert(tags, "BROKEN"); sev = 4; rank = -1 end
        if c.disloc[k] then table.insert(tags, "dislocated"); sev = math.max(sev, 3); rank = math.min(rank, 0) end
        local lbl, lsev = InjuryLabel(pct)
        if lbl then
            table.insert(tags, string.format("%s %d%%", lbl, math.floor(pct + 0.5)))
            sev = math.max(sev, lsev)
        end
        if #tags > 0 then table.insert(list, { text = name .. ": " .. table.concat(tags, ", "), sev = sev, rank = rank }) end
    end
    table.sort(list, function(a, b) return a.rank < b.rank end)
    return list
end

---------------------------------------------------------------------------
-- Finding characters
---------------------------------------------------------------------------

local function GetPlayerPawn()
    local ok, p = pcall(UEHelpers.GetPlayer)
    if ok and Valid(p) then return p end
    return nil
end

-- Fighter classes seen so far. Only class NAMES are kept between frames: holding a fighter
-- across frames and touching it after the game deleted it (corpse cleanup, new wave) crashed UE4SS.
local fighterClasses = { Willie_BP_C = true }
local discovered = false

local function DiscoverClasses(player)
    fighterClasses[ClassName(player)] = true
    pcall(function()
        local out = {}
        UEHelpers.GetGameplayStatics():GetAllActorsOfClass(player, StaticFindObject("/Script/Engine.Character"), out)
        for _, a in ipairs(out) do
            local o = a
            pcall(function() o = a:get() end)
            if Valid(o) and ResolveClass(o).stats.hp then fighterClasses[ClassName(o)] = true end
        end
    end)
end

local function FindFighters()
    local found, seen = {}, {}
    for n in pairs(fighterClasses) do
        local ok, list = pcall(FindAllOf, n)
        if ok and list then
            for _, o in ipairs(list) do
                if Valid(o) then
                    local a = Addr(o)
                    if not seen[a] then seen[a] = true; table.insert(found, o) end
                end
            end
        end
    end
    return found
end

---------------------------------------------------------------------------
-- Widget toolkit (UMG objects built at runtime; no pak needed)
---------------------------------------------------------------------------
local KEEP_FLAGS = 0x0E000000   -- stops the root widget from being garbage collected
local VIS_SHOW, VIS_HIDE = 3, 1 -- HitTestInvisible / Collapsed

local function New(cls, outer, name, keep)
    return StaticConstructObject(StaticFindObject(cls), outer, name and FName(name) or 0, 0, keep and KEEP_FLAGS or 0, false, false, nil, nil, nil)
end

local function Place(canvas, widget, x, y, w, h, anchor, align)
    local slot = canvas:AddChildToCanvas(widget)
    if anchor then pcall(function() slot:SetAnchors({ Minimum = { X = anchor[1], Y = anchor[2] }, Maximum = { X = anchor[1], Y = anchor[2] } }) end) end
    if align then pcall(function() slot:SetAlignment({ X = align[1], Y = align[2] }) end) end
    pcall(function() slot:SetPosition({ X = x, Y = y }) end)
    if w then
        pcall(function() slot:SetAutoSize(false) end)
        pcall(function() slot:SetSize({ X = w, Y = h }) end)
    else
        pcall(function() slot:SetAutoSize(true) end)
    end
    return slot
end

local function SameColor(a, b) return a ~= nil and a.R == b.R and a.G == b.G and a.B == b.B and a.A == b.A end

local function Rect(tree, canvas, x, y, w, h, color, round, anchor, align)
    local img = New("/Script/UMG.Image", tree)
    if round then
        pcall(function()
            img.Brush.DrawAs = 4                       -- RoundedBox
            img.Brush.OutlineSettings.RoundingType = 0 -- FixedRadius
            img.Brush.OutlineSettings.CornerRadii = { X = round, Y = round, Z = round, W = round }
        end)
    end
    local e = { w = img, slot = Place(canvas, img, x, y, w, h, anchor, align) }
    e.SetColor = function(self, c)
        if not SameColor(self.c, c) then self.c = c; pcall(function() self.w:SetColorAndOpacity(c) end) end
    end
    e:SetColor(color)
    return e
end

local function ToFText(s)
    if FText then return FText(s) end
    return UEHelpers.GetKismetTextLibrary():Conv_StringToText(s)
end

local function Label(tree, canvas, x, y, size, color, anchor, align)
    local tb = New("/Script/UMG.TextBlock", tree)
    pcall(function() tb.Font.Size = size end)
    pcall(function() tb.Font.OutlineSettings.OutlineSize = 1 end)
    pcall(function() tb.Font.OutlineSettings.OutlineColor = { R = 0, G = 0, B = 0, A = 0.9 } end)
    pcall(function() tb:SetShadowOffset({ X = 1, Y = 1 }) end)
    pcall(function() tb:SetShadowColorAndOpacity({ R = 0, G = 0, B = 0, A = 0.8 }) end)
    local e = { w = tb, slot = Place(canvas, tb, x, y, nil, nil, anchor, align) }
    e.SetText = function(self, s)
        if self.txt ~= s then self.txt = s; pcall(function() self.w:SetText(ToFText(s)) end) end
    end
    e.SetColor = function(self, c)
        if not SameColor(self.c, c) then self.c = c; pcall(function() self.w:SetColorAndOpacity({ SpecifiedColor = c, ColorUseRule = 0 }) end) end
    end
    e:SetColor(color)
    e:SetText("")
    return e
end

local function Panel(tree, parent, x, y, w, h, anchor, align)
    local p = New("/Script/UMG.CanvasPanel", tree)
    return { w = p, slot = Place(parent, p, x, y, w, h, anchor, align) }
end

local function SetVis(e, show)
    if e and e.vis ~= show then e.vis = show; pcall(function() e.w:SetVisibility(show and VIS_SHOW or VIS_HIDE) end) end
end

local function SetPos(e, x, y)
    pcall(function() e.slot:SetPosition({ X = x, Y = y }) end)
end

local function SetOpacity(e, a)
    if e.op ~= a then e.op = a; pcall(function() e.w:SetRenderOpacity(a) end) end
end

---------------------------------------------------------------------------
-- HUD pieces
---------------------------------------------------------------------------
local function Lerp(a, b, t) return a + (b - a) * t end
local function LerpColor(c1, c2, t)
    return { R = Lerp(c1.R, c2.R, t), G = Lerp(c1.G, c2.G, t), B = Lerp(c1.B, c2.B, t), A = Lerp(c1.A, c2.A, t) }
end

local HEALTH_STOPS = {
    { 100, { R = 0.90, G = 0.86, B = 0.76, A = 0.55 } },  -- healthy: bone
    { 75,  { R = 0.98, G = 0.82, B = 0.30, A = 0.75 } },  -- bruised: yellow
    { 45,  { R = 1.00, G = 0.45, B = 0.10, A = 0.85 } },  -- wounded: orange
    { 15,  { R = 0.85, G = 0.08, B = 0.05, A = 0.95 } },  -- critical: red
    { 0,   { R = 0.22, G = 0.00, B = 0.00, A = 0.95 } },  -- destroyed: dried blood
}

local function HealthColor(pct)
    if pct == nil then return COLORS.unknown end
    for i = 1, #HEALTH_STOPS - 1 do
        local hi, lo = HEALTH_STOPS[i], HEALTH_STOPS[i + 1]
        if pct >= lo[1] then return LerpColor(lo[2], hi[2], (pct - lo[1]) / (hi[1] - lo[1])) end
    end
    return HEALTH_STOPS[#HEALTH_STOPS][2]
end

local function Fmt(v, d)
    if type(v) ~= "number" then return "-" end
    return string.format("%." .. (d or 0) .. "f", v)
end

local function BuildBody(tree, canvas, ox, oy, s)
    local body = { segs = {} }
    for _, seg in ipairs(SEGMENTS) do
        body.segs[seg.id] = Rect(tree, canvas, ox + seg.x * s, oy + seg.y * s, seg.w * s, seg.h * s,
            COLORS.unknown, seg.round and math.max(2, seg.round * s) or nil)
    end
    return body
end

local function UpdateBody(body, c)
    local pulse = (math.sin(tickNo * 0.25) + 1) / 2
    for _, seg in ipairs(SEGMENTS) do
        local col = HealthColor(c.seg[seg.id])
        if seg.broken and c.broken[seg.broken] then
            col = LerpColor(COLORS.broken, COLORS.brokenHi, pulse)
        elseif seg.disloc and c.disloc[seg.disloc] then
            col = COLORS.disloc
        end
        local f = c.st.flash[seg.id] or 0
        if f > 0 then col = LerpColor(col, COLORS.hitBig, f) end
        body.segs[seg.id]:SetColor(col)
    end
end

local function BuildBar(tree, canvas, x, y, w, h, color, title, size, pending)
    local bar = { w = w, h = h }
    if title then
        bar.title = Label(tree, canvas, x, y - size - 4, size, COLORS.dim)
        bar.title:SetText(title)
        bar.value = Label(tree, canvas, x + w, y - size - 4, size, COLORS.text, nil, { 1, 0 })
    end
    bar.bg = Rect(tree, canvas, x, y, w, h, COLORS.barBg, h >= 5 and 2 or nil)
    if pending then bar.pend = Rect(tree, canvas, x, y, w, h, COLORS.pending, h >= 5 and 2 or nil) end
    bar.fill = Rect(tree, canvas, x, y, w, h, color, h >= 5 and 2 or nil)
    return bar
end

-- progress bar: solid part = current, faint extension = gain still pending
local function UpdateProgress(bar, frac, pendFrac, text)
    if not bar then return end
    if bar.pend then
        local pw = math.floor(bar.w * math.max(0, math.min(1, (frac or 0) + (pendFrac or 0))) + 0.5)
        if bar.lastPW ~= pw then
            bar.lastPW = pw
            pcall(function() bar.pend.slot:SetSize({ X = pw, Y = bar.h }) end)
            SetVis(bar.pend, pw > 0)
        end
    end
    local w = math.floor(bar.w * math.max(0, math.min(1, frac or 0)) + 0.5)
    if bar.lastW ~= w then
        bar.lastW = w
        pcall(function() bar.fill.slot:SetSize({ X = w, Y = bar.h }) end)
        SetVis(bar.fill, w > 0)
    end
    if bar.value then bar.value:SetText(text or "-") end
end

local function UpdateBar(bar, frac, text)
    if not bar then return end
    frac = math.max(0, math.min(1, frac or 0))
    local w = math.floor(bar.w * frac + 0.5)
    if bar.lastW ~= w then
        bar.lastW = w
        pcall(function() bar.fill.slot:SetSize({ X = w, Y = bar.h }) end)
        SetVis(bar.fill, w > 0)
    end
    if bar.value then bar.value:SetText(text or "-") end
end

local SEV_COLORS = {
    [1] = { R = 0.98, G = 0.85, B = 0.40, A = 1 },
    [2] = { R = 1.00, G = 0.55, B = 0.20, A = 1 },
    [3] = { R = 1.00, G = 0.25, B = 0.15, A = 1 },
    [4] = { R = 0.85, G = 0.10, B = 0.10, A = 1 },
}

local function UpdateInjuryList(list, inj)
    for i, lbl in ipairs(list) do
        local it = inj[i]
        if it then
            lbl:SetText(i == #list and #inj > #list and string.format("+%d more", #inj - #list + 1) or it.text)
            lbl:SetColor(SEV_COLORS[it.sev] or COLORS.text)
            SetVis(lbl, true)
        elseif i == 1 then
            lbl:SetText("No injuries"); lbl:SetColor(COLORS.dim); SetVis(lbl, true)
        else
            SetVis(lbl, false)
        end
    end
end

-- One stats panel (yours or the focused enemy's), laid out from the settings
local function BuildStatsPanel(tree, canvas, prefix, isYou)
    local s = S[prefix .. ".scale"]
    local function fs(n) return math.max(7, math.floor(n * s + 0.5)) end
    local pad = 14 * s
    local showBody = S[prefix .. ".body"]
    local bars = {}
    for _, b in ipairs(BAR_DEFS) do if S[prefix .. "." .. b.key] then table.insert(bars, b) end end
    local nInj = S[prefix .. ".injuries"] and (isYou and 4 or 3) or 0
    local showDmg = S[prefix .. ".damage"]
    local showPhys = S[prefix .. ".physique"]
    local showProg = isYou and S["you.progress"]

    local bodyW, bodyH = BODY_W * s, BODY_H * s
    local titleH = fs(14) + 10 * s
    local colX = pad + (showBody and (bodyW + 18 * s) or 0)
    local barW = 210 * s
    local barLabel = fs(10) + 4
    local gap = barLabel + 18 * s
    local injLine = fs(11) + 5 * s
    local dmgLine = fs(10) + 5 * s
    local colH = #bars * gap + nInj * injLine + (showDmg and (2 * dmgLine + 6 * s) or 0)
        + (showPhys and (2 * dmgLine + 8 * s) or 0) + (showProg and (3 * gap + 10 * s) or 0)
    local hasCol = colH > 0
    local contentH = math.max(showBody and bodyH or 0, colH)
    local w = hasCol and (colX + barW + pad) or (pad * 2 + (showBody and bodyW or 160 * s))
    local h = pad + titleH + contentH + pad

    local a = POS_ANCHOR[S[prefix .. ".pos"]] or { 0, 1 }
    local margin = 24
    local x = (a[1] == 0 and margin or a[1] == 1 and -margin or 0) + S[prefix .. ".offX"]
    local y = (a[2] == 0 and margin or a[2] == 1 and -margin or 0) + S[prefix .. ".offY"]

    local p = Panel(tree, canvas, x, y, w, h, a, a)
    p.bg = Rect(tree, p.w, 0, 0, w, h, { R = 0.02, G = 0.02, B = 0.02, A = S.bgOpacity }, 10 * s)
    p.title = Label(tree, p.w, pad, pad - 2 * s, fs(14), isYou and COLORS.text or COLORS.gold)
    if isYou then p.hit = Label(tree, p.w, w - pad, pad - 6 * s, fs(20), COLORS.hitBig, nil, { 1, 0 }) end

    local cy = pad + titleH
    if showBody then p.body = BuildBody(tree, p.w, pad, cy, s) end
    p.bars = {}
    for i, b in ipairs(bars) do
        p.bars[b.key] = BuildBar(tree, p.w, colX, cy + barLabel + (i - 1) * gap, barW, math.max(3, b.h * s), b.color, b.title, fs(10))
    end
    local iy = cy + #bars * gap
    if nInj > 0 then
        p.inj = {}
        for i = 1, nInj do p.inj[i] = Label(tree, p.w, colX, iy + (i - 1) * injLine, fs(11), COLORS.text) end
        iy = iy + nInj * injLine
    end
    if showDmg then
        p.dmg1 = Label(tree, p.w, colX, iy + 6 * s, fs(10), COLORS.text)
        p.dmg2 = Label(tree, p.w, colX, iy + 6 * s + dmgLine, fs(10), COLORS.text)
        iy = iy + 6 * s + 2 * dmgLine
    end
    if showPhys then
        p.phys1 = Label(tree, p.w, colX, iy + 8 * s, fs(10), COLORS.gold)
        p.phys2 = Label(tree, p.w, colX, iy + 8 * s + dmgLine, fs(10), COLORS.gold)
        iy = iy + 8 * s + 2 * dmgLine
    end
    if showProg then
        local py = iy + 10 * s + barLabel
        p.prog = {
            strength = BuildBar(tree, p.w, colX, py,           barW, math.max(3, 6 * s), COLORS.strength, "STRENGTH",     fs(10), true),
            wSkill   = BuildBar(tree, p.w, colX, py + gap,     barW, math.max(3, 5 * s), COLORS.wSkill,   "WEAPON SKILL", fs(10), true),
            bSkill   = BuildBar(tree, p.w, colX, py + 2 * gap, barW, math.max(3, 5 * s), COLORS.bSkill,   "BODY SKILL",   fs(10), true),
        }
    end
    return p
end

local function UpdateStatsPanel(p, c, title, dmg1, dmg2)
    p.title:SetText(title)
    if p.body then UpdateBody(p.body, c) end
    local b = p.bars
    UpdateBar(b.health,  (Pct(c.hp, c.st.max.hp) or 0) / 100, Fmt(c.hp, 0) .. " / " .. Fmt(c.st.max.hp, 0))
    UpdateBar(b.cons,    (Pct(c.cons, c.st.max.cons) or 0) / 100, Fmt(Pct(c.cons, c.st.max.cons), 0) .. "%")
    UpdateBar(b.stamina, (Pct(c.stamina, c.st.max.stamina) or 0) / 100, Fmt(Pct(c.stamina, c.st.max.stamina), 0) .. "%")
    local energy = type(c.energy) == "number" and c.energy or nil
    UpdateBar(b.energy,  energy or 0, energy and Fmt(energy * 100, 0) .. "%" or "-")
    UpdateBar(b.pain,    type(c.pain) == "number" and c.pain / 100 or 0, Fmt(c.pain, 1))
    -- Bleeding keeps climbing on corpses, so cap the readout and hide it once dead
    local bleed = (type(c.bleed) == "number" and not c.isDead) and c.bleed or nil
    UpdateBar(b.bleed, bleed and bleed / 100 or 0, bleed and (bleed > 999 and "999+" or Fmt(bleed, 1)) or "-")
    if p.inj and (p.injSt ~= c.st or tickNo - (p.injTick or -100) >= 6) then
        p.injSt, p.injTick = c.st, tickNo
        UpdateInjuryList(p.inj, Injuries(c))
    end
    if p.dmg1 then p.dmg1:SetText(dmg1 or ""); p.dmg2:SetText(dmg2 or "") end
    if p.phys1 then
        local st = c.st
        p.phys1:SetText(string.format("WEIGHT %s     HEIGHT %s",
            st.massKg and string.format("%.0f kg", st.massKg) or "-",
            st.heightCm and string.format("~%.0f cm", st.heightCm) or "-"))
        p.phys2:SetText(string.format("STRENGTH %s     GEAR %s", Fmt(c.muscle, 0),
            st.gearKg and string.format("%.1f kg", st.gearKg) or "-"))
    end
    if p.prog then
        local function pct(v) return type(v) == "number" and string.format("%.1f%%", v * 100) or "-" end
        local function due(v) return (type(v) == "number" and v > 0.0005) and string.format("  (+%.1f%%)", v * 100) or "" end
        UpdateProgress(p.prog.strength, c.muscleRate, c.muscleDue,
            string.format("%s power   %s%s", Fmt(c.muscle, 0), pct(c.muscleRate), due(c.muscleDue)))
        UpdateProgress(p.prog.wSkill, c.wSkill, c.wSkillDue, pct(c.wSkill) .. due(c.wSkillDue))
        UpdateProgress(p.prog.bSkill, c.bSkill, c.bSkillDue, pct(c.bSkill) .. due(c.bSkillDue))
    end
end

---------------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------------
local MENU_ROWS = 16
local menuOpen, menuSel, menuScroll = false, 2, 0

local function MenuValueText(it)
    if it.type == "bool" then return S[it.key] and "ON" or "OFF", S[it.key] and COLORS.on or COLORS.off end
    if it.type == "choice" then return "<  " .. tostring(S[it.key]) .. "  >", COLORS.gold end
    if it.type == "num" then
        local v = S[it.key]
        if it.pct then return string.format("<  %d%%  >", math.floor(v * 100 + 0.5)), COLORS.gold end
        return string.format("<  %+d  >", math.floor(v + 0.5)), COLORS.gold
    end
    return "", COLORS.text
end

local function BuildMenu(tree, canvas)
    local w, rowH, top = 520, 26, 78
    local h = top + MENU_ROWS * rowH + 50
    local m = Panel(tree, canvas, 0, 0, w, h, { 0.5, 0.5 }, { 0.5, 0.5 })
    Rect(tree, m.w, 0, 0, w, h, COLORS.menuBg, 14)
    Rect(tree, m.w, 0, 0, w, 4, COLORS.hp, 2)
    local title = Label(tree, m.w, 24, 16, 24, COLORS.gold)
    title:SetText("FECHTBUCH")
    local sub = Label(tree, m.w, 24, 50, 11, COLORS.dim)
    sub:SetText("Choose what shows, where it goes and how big it is. Saved automatically.")
    m.hl = Rect(tree, m.w, 12, top, w - 24, rowH, COLORS.menuSel, 5)
    m.rows = {}
    for i = 1, MENU_ROWS do
        local y = top + (i - 1) * rowH + 5
        m.rows[i] = { name = Label(tree, m.w, 26, y, 13, COLORS.text), value = Label(tree, m.w, w - 26, y, 13, COLORS.gold, nil, { 1, 0 }) }
    end
    m.scroll = Label(tree, m.w, w - 26, 26, 11, COLORS.dim, nil, { 1, 0 })
    local foot = Label(tree, m.w, 24, h - 34, 11, COLORS.dim)
    foot:SetText("Up/Down: select     Left/Right: change     Enter: toggle     Home: close")
    m.top, m.rowH = top, rowH
    return m
end

local function RenderMenu(m)
    if menuSel <= menuScroll then menuScroll = menuSel - 1 end
    if menuSel > menuScroll + MENU_ROWS then menuScroll = menuSel - MENU_ROWS end
    menuScroll = math.max(0, math.min(menuScroll, #MENU - MENU_ROWS))
    for i = 1, MENU_ROWS do
        local it, row = MENU[menuScroll + i], m.rows[i]
        if it and it.header then
            row.name:SetText(it.header); row.name:SetColor(COLORS.hp); row.value:SetText("")
        elseif it then
            row.name:SetText(it.label); row.name:SetColor(COLORS.text)
            local txt, col = MenuValueText(it)
            row.value:SetText(txt); row.value:SetColor(col)
        else
            row.name:SetText(""); row.value:SetText("")
        end
    end
    SetPos(m.hl, 12, m.top + (menuSel - menuScroll - 1) * m.rowH)
    m.scroll:SetText(string.format("%d / %d", menuSel, #MENU))
end

---------------------------------------------------------------------------
-- HUD assembly
---------------------------------------------------------------------------
local hud = nil
local hudDirty = false
local hudFailed = false
local menuDirty = true

local function RemoveOldHuds()
    pcall(function()
        local list = FindAllOf("UserWidget")
        if not list then return end
        for _, w in ipairs(list) do
            local n = w:GetFName():ToString()
            if n:find("^Fechtbuch_Root") or n:find("^BattleEye_Root") or n:find("^HSS_Root") then pcall(function() w:RemoveFromParent() end) end
        end
    end)
end

local function BuildHud()
    local gi = UEHelpers.GetGameInstance()
    if not Valid(gi) then return nil end
    RemoveOldHuds()

    local h = {}
    local root = New("/Script/UMG.UserWidget", gi, "Fechtbuch_Root_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)), true)
    local tree = New("/Script/UMG.WidgetTree", root)
    root.WidgetTree = tree
    local canvas = New("/Script/UMG.CanvasPanel", tree)
    tree.RootWidget = canvas
    h.root = root

    if S["you.show"] then h.you = BuildStatsPanel(tree, canvas, "you", true) end
    if S["enemy.show"] then h.enemy = BuildStatsPanel(tree, canvas, "enemy", false) end

    if S["enemy.tag"] then
        local ts = S["enemy.tagScale"]
        local t = Panel(tree, canvas, 0, 0, 150 * ts, 44 * ts, { 0, 0 }, { 0.5, 1 })
        t.name = Label(tree, t.w, 75 * ts, 0, math.max(7, math.floor(10 * ts)), COLORS.gold, nil, { 0.5, 0 })
        t.hp   = BuildBar(tree, t.w, 15 * ts, 18 * ts, 120 * ts, math.max(3, 6 * ts), COLORS.hp)
        t.cons = BuildBar(tree, t.w, 15 * ts, 26 * ts, 120 * ts, math.max(2, 3 * ts), COLORS.cons)
        t.status = Label(tree, t.w, 75 * ts, 31 * ts, math.max(7, math.floor(9 * ts)), COLORS.hitBig, nil, { 0.5, 0 })
        SetVis(t, false)
        h.tag = t
    end

    h.pops = {}
    if S["enemy.numbers"] then
        for i = 1, 8 do
            local p = Label(tree, canvas, 0, 0, math.floor(20 * S["enemy.tagScale"]), COLORS.hitLow, { 0, 0 }, { 0.5, 0.5 })
            p.life = 0
            SetVis(p, false)
            h.pops[i] = p
        end
    end

    h.toast = Label(tree, canvas, 0, 110, 18, COLORS.gold, { 0.5, 0 }, { 0.5, 0 })
    SetOpacity(h.toast, 0)

    h.menu = BuildMenu(tree, canvas)
    SetVis(h.menu, menuOpen)
    menuDirty = true

    root:SetVisibility(VIS_SHOW)
    root:AddToViewport(1000)
    Log("HUD built")
    return h
end

---------------------------------------------------------------------------
-- Screen projection and focus
---------------------------------------------------------------------------
local projWarned = false

local layoutLib = nil   -- a class default object: the engine never deletes it
local function LayoutLib()
    if not Valid(layoutLib) then layoutLib = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary") end
    return layoutLib
end

local function ViewportScale(ctx)
    local ok, s = pcall(function() return LayoutLib():GetViewportScale(ctx) end)
    if ok and type(s) == "number" and s > 0 then return s end
    return 1
end

local function ViewportSize(ctx)
    local ok, v = pcall(function() return LayoutLib():GetViewportSize(ctx) end)
    if ok and v then
        local ok2, x, y = pcall(function() return v.X, v.Y end)
        if ok2 and type(x) == "number" and x > 0 then return x, y end
    end
    return 2560, 1440
end

-- returns screen position in pixels
local function ToScreenPx(pc, loc)
    if not loc or not pc then return nil end
    local out = {}
    local ok, res = pcall(function() return pc:ProjectWorldLocationToScreen(loc, out, false) end)
    if ok and res and type(out.X) == "number" then return out.X, out.Y end
    if not projWarned and ok and res then
        projWarned = true
        Log("world-to-screen not available; enemy tag and damage numbers disabled")
    end
    return nil
end

local lastLockLog = nil
local taggedAddr = nil     -- enemy tagged with Z
local taggedMissing = 0
local zPressed = false
local toast = { text = "", life = 0 }

local function CrosshairEnemy(player, enemies, pc, radiusFrac)
    local vw, vh = ViewportSize(player)
    local best, bestD = nil, vh * radiusFrac
    for _, c in ipairs(enemies) do
        if c.dist <= FOCUS_RANGE then
            c.head = c.head or HeadLocation(c.obj)
            local x, y = ToScreenPx(pc, c.head)
            if x then
                local d = math.sqrt((x - vw / 2) ^ 2 + (y - vh / 2) ^ 2)
                if d < bestD then best, bestD = c, d end
            end
        end
    end
    return best
end

local function NearestEnemy(enemies)
    for _, c in ipairs(enemies) do
        if not c.isDead and c.dist <= FOCUS_RANGE then return c end
    end
    return nil
end

-- The game doesn't store who you're locked onto, only where the camera is locked
local function LockedEnemy(player, enemies, pc)
    local r = ResolveClass(player)
    local locked = Read(player, r.stats.locked) == true or Read(player, r.stats.lockFound) == true
    local lockAt = nil
    if r.lockAt then pcall(function() lockAt = Vec(player[r.lockAt]) end) end
    if lockAt and lockAt.X == 0 and lockAt.Y == 0 and lockAt.Z == 0 then lockAt = nil end
    if lastLockLog ~= locked then
        lastLockLog = locked
        Log("lock-on %s (Camera Locked=%s, Lock On Found=%s)", locked and "ON" or "off",
            tostring(Read(player, r.stats.locked)), tostring(Read(player, r.stats.lockFound)))
    end
    if not locked then return nil end
    if lockAt then
        local best, bestD = nil, 3.0
        for _, c in ipairs(enemies) do
            if c.dist <= FOCUS_RANGE then c.head = c.head or HeadLocation(c.obj) end
            local d = math.min(Dist(c.head, lockAt), Dist(c.loc, lockAt))
            if d < bestD then best, bestD = c, d end
        end
        if best then return best end
    end
    return CrosshairEnemy(player, enemies, pc, 0.3)
end

-- Z: tag the enemy under the crosshair (or the nearest); Z on the tagged one removes the tag
local function HandleZ(player, enemies, pc)
    zPressed = false
    local cand = CrosshairEnemy(player, enemies, pc, 0.35) or NearestEnemy(enemies)
    local ca = cand and Addr(cand.obj)
    if taggedAddr and (ca == nil or ca == taggedAddr) then
        taggedAddr = nil
        toast.text, toast.life = "TAG REMOVED", 1
    elseif cand then
        taggedAddr, taggedMissing = ca, 0
        toast.text, toast.life = "ENEMY TAGGED", 1
    else
        toast.text, toast.life = "NO ENEMY IN SIGHT", 1
    end
end

local function PickFocus(player, enemies, pc)
    if zPressed then HandleZ(player, enemies, pc) end
    if taggedAddr then
        for _, c in ipairs(enemies) do
            if Addr(c.obj) == taggedAddr then taggedMissing = 0; c.tagged = true; return c end
        end
        taggedMissing = taggedMissing + 1
        if taggedMissing > 90 then taggedAddr = nil end   -- gone for ~3 s: despawned
    end
    local mode = S["enemy.focusMode"]
    if mode == "Z tag + lock-on" then return LockedEnemy(player, enemies, pc) end
    if mode == "Z tag + crosshair" then return CrosshairEnemy(player, enemies, pc, 0.3) end
    if mode == "Z tag + nearest" then return NearestEnemy(enemies) end
    return nil
end

local function SpawnPop(x, y, amount, color)
    local best, oldest = nil, math.huge
    for _, p in ipairs(hud.pops) do
        if p.life <= 0 then best = p; break end
        if p.life < oldest then oldest = p.life; best = p end
    end
    if not best then return nil end
    best.life, best.x, best.y = 1, x + math.random(-14, 14), y
    best:SetText("-" .. Fmt(amount, 0))
    best:SetColor(color)
    SetVis(best, true)
    return best
end

local function UpdatePops()
    for _, p in ipairs(hud.pops) do
        if p.life > 0 then
            p.life = p.life - 0.03
            p.y = p.y - 1.2
            SetPos(p, p.x, p.y)
            SetOpacity(p, math.min(1, p.life * 2.5))
            if p.life <= 0 then SetVis(p, false) end
        end
    end
end

---------------------------------------------------------------------------
-- Per-tick update
---------------------------------------------------------------------------
local fileText = ""

local function Summary(c, title)
    local inj = {}
    for _, it in ipairs(Injuries(c)) do table.insert(inj, it.text) end
    return string.format("%s  HP %s/%s  Cons %s  Pain %s  Bleed %s  Stamina %s\n  Injuries: %s\n  Taken %s (hits %d, biggest %s)",
        title, Fmt(c.hp, 1), Fmt(c.st.max.hp, 0), Fmt(c.cons, 1), Fmt(c.pain, 1), Fmt(c.bleed, 2), Fmt(c.stamina, 1),
        #inj > 0 and table.concat(inj, ", ") or "none", Fmt(c.st.taken, 1), c.st.hits, Fmt(c.st.maxHit, 1))
end

local function HideCombat()
    SetVis(hud.you, false); SetVis(hud.enemy, false); SetVis(hud.tag, false)
end

-- Level loads and respawns tear fighters down; touching them then crashes the game
local cooldown = 0
local lastWorld, lastPawn = nil, nil

-- Assigned at the bottom of the file; Tick runs them on the game thread
local ProcessKeys, DumpProps
local dumpPending = true   -- one automatic property dump per game session

local function ResetWorldState(ticks)
    states = {}
    taggedAddr = nil
    cooldown = math.max(cooldown, ticks)
end

local function Tick()
    tickNo = tickNo + 1
    if ProcessKeys then ProcessKeys() end

    local world = nil
    pcall(function() world = UEHelpers.GetWorld() end)
    local wAddr = Valid(world) and Addr(world) or nil
    if wAddr ~= lastWorld then lastWorld = wAddr; ResetWorldState(60) end
    if cooldown > 0 then
        cooldown = cooldown - 1
        if hud then HideCombat() end
        return
    end

    if hudDirty and hud then
        pcall(function() hud.root:RemoveFromParent() end)
        hud = nil
    end
    hudDirty = false
    if not hudFailed and (hud == nil or not Valid(hud.root)) then
        local ok, h = pcall(BuildHud)
        if ok and h then hud = h
        elseif not ok then hudFailed = true; Log("HUD build failed: %s", tostring(h)) end
    end
    if not hud then return end
    pcall(function() if not hud.root:IsInViewport() then hud.root:AddToViewport(1000) end end)

    SetVis(hud.menu, menuOpen)
    if menuOpen and menuDirty then RenderMenu(hud.menu); menuDirty = false end

    local player = GetPlayerPawn()
    local pAddr = player and Addr(player) or nil
    if pAddr ~= lastPawn then
        lastPawn = pAddr
        ResetWorldState(30)
        HideCombat()
        return
    end
    local me = player and ReadCharacter(player, true)
    -- Property names change with game updates, so keep a fresh dump for troubleshooting (also F9)
    if dumpPending and DumpProps and me and type(me.hp) == "number" and (me.st.aliveTicks or 0) >= 60 then
        dumpPending = false
        pcall(DumpProps)
    end
    if not (me and type(me.hp) == "number") or not S.hud then
        HideCombat()
        if not (me and type(me.hp) == "number") then fileText = "Fechtbuch: waiting for your fighter..." end
        return
    end

    if tickNo % SCAN_EVERY == 1 or not discovered then discovered = true; DiscoverClasses(player) end
    local fighters = FindFighters()

    local myLoc = ActorLocation(player)
    local myAddr = Addr(player)
    local enemies = {}
    for _, o in ipairs(fighters) do
        if Addr(o) ~= myAddr then
            local c = ReadCharacter(o)
            if type(c.hp) == "number" then
                c.loc = ActorLocation(o) or HeadLocation(o)
                c.dist = Dist(c.loc, myLoc)
                c.enemy = (c.team == nil or me.team == nil or c.team ~= me.team)
                if c.enemy and c.drop > 0 then
                    -- enemies don't fight each other, so their health loss is credited to you
                    session.dealt = session.dealt + c.drop
                    c.st.dealtTo = c.st.dealtTo + c.drop
                    if c.st.newHit then session.dealtHits = session.dealtHits + 1 end
                    if c.st.curHit > session.maxDealt then session.maxDealt = c.st.curHit end
                end
                if c.enemy and c.isDead and not c.st.dead then session.kills = session.kills + 1 end
                c.st.dead = c.isDead
                if c.enemy then table.insert(enemies, c) end
            end
        end
    end
    table.sort(enemies, function(x, y)
        if x.isDead ~= y.isDead then return not x.isDead end
        return x.dist < y.dist
    end)

    local pc = nil
    pcall(function() pc = UEHelpers.GetPlayerController() end)
    local focus = PickFocus(player, enemies, pc)
    if focus then
        ReadDetails(focus)
        focus.head = focus.head or HeadLocation(focus.obj)
    end

    if toast.life > 0 then
        hud.toast:SetText(toast.text)
        toast.life = toast.life - 0.015
        SetOpacity(hud.toast, math.min(1, toast.life * 3))
    end

    -- your panel
    if hud.you then
        SetVis(hud.you, true)
        UpdateStatsPanel(hud.you, me, "YOU",
            string.format("DEALT %s     TAKEN %s", Fmt(session.dealt, 0), Fmt(me.st.taken, 0)),
            string.format("BEST HIT %s     KILLS %d", Fmt(session.maxDealt, 0), session.kills))
        if hud.you.hit then
            if me.drop > 0 and S["you.hit"] then hud.you.hit:SetText("-" .. Fmt(me.st.curHit, 0)); hud.youHitLife = 1 end
            hud.youHitLife = math.max(0, (hud.youHitLife or 0) - 0.02)
            SetOpacity(hud.you.hit, hud.youHitLife)
        end
    end

    -- focused enemy only; unfocused enemies show nothing
    if hud.enemy then
        if focus then
            SetVis(hud.enemy, true)
            UpdateStatsPanel(hud.enemy, focus,
                string.format("%s%s  %.1f m", focus.tagged and "TAGGED " or "", focus.isDead and "ENEMY - DEAD" or "ENEMY", focus.dist),
                string.format("YOU DEALT %s     HITS %d", Fmt(focus.st.dealtTo, 0), focus.st.hits),
                string.format("BEST HIT %s", Fmt(focus.st.maxHit, 0)))
        else
            SetVis(hud.enemy, false)
        end
    end

    local scale = ViewportScale(player)
    if hud.tag then
        local x, y = nil, nil
        if focus and focus.head then x, y = ToScreenPx(pc, { X = focus.head.X, Y = focus.head.Y, Z = focus.head.Z + 35 }) end
        if x then
            local t = hud.tag
            SetVis(t, true)
            SetPos(t, x / scale, y / scale)
            local anyBroken = false
            for _, v in pairs(focus.broken) do if v then anyBroken = true end end
            local status = ""
            if focus.isDead then status = "DEAD"
            elseif (Pct(focus.cons, focus.st.max.cons) or 100) < 8 then status = "UNCONSCIOUS"
            elseif focus.shock == true then status = "PAIN SHOCK"
            elseif focus.guts == true then status = "GUTS SPILLED"
            elseif anyBroken then status = "BROKEN BONE"
            elseif type(focus.bleed) == "number" and focus.bleed > 1 then status = "BLEEDING" end
            t.name:SetText(string.format("%.0f m", focus.dist))
            t.status:SetText(status)
            UpdateBar(t.hp, (Pct(focus.hp, focus.st.max.hp) or 0) / 100)
            UpdateBar(t.cons, (Pct(focus.cons, focus.st.max.cons) or 0) / 100)
            SetOpacity(t, focus.isDead and 0.5 or 1)
        else
            SetVis(hud.tag, false)
        end
    end

    if #hud.pops > 0 then
        if focus and focus.drop > 0 then
            local x, y = ToScreenPx(pc, focus.head)
            if x then
                local st = focus.st
                if st.newHit or not st.pop or st.pop.life <= 0 then
                    local col = st.curHit >= 50 and COLORS.hitBig or st.curHit >= 20 and COLORS.hitMid or COLORS.hitLow
                    st.pop = SpawnPop(x / scale, y / scale, st.curHit, col)
                else
                    st.pop:SetText("-" .. Fmt(st.curHit, 0))   -- same blow still landing
                    st.pop.life = math.max(st.pop.life, 0.9)
                end
            end
        end
        UpdatePops()
    end

    if tickNo % 30 == 0 then
        local lines = { Summary(me, "== YOU"),
            string.format("  Dealt %s (hits %d, best %s)  Kills %d", Fmt(session.dealt, 1), session.dealtHits, Fmt(session.maxDealt, 1), session.kills) }
        if focus then
            table.insert(lines, "")
            table.insert(lines, Summary(focus, string.format("== FOCUSED ENEMY (%.1f m)%s", focus.dist, focus.isDead and " DEAD" or "")))
        end
        fileText = table.concat(lines, "\n")
    end

    for a, st in pairs(states) do
        if tickNo - st.seen > 300 then states[a] = nil end
    end
end

local writtenText = nil
local function WriteFile()
    if fileText == writtenText then return end
    local f = io.open(MOD_DIR .. "\\stats.txt", "w")
    if f then f:write(fileText); f:close(); writtenText = fileText end
end

---------------------------------------------------------------------------
-- Property dump (F9)
---------------------------------------------------------------------------
DumpProps = function()
    local target = GetPlayerPawn()
    if not (target and ResolveClass(target).stats.hp) then
        target = nil
        for _, o in ipairs(FindFighters()) do target = o; break end
    end
    if not target then Log("dump: no fighter found"); return end
    local out = { "Class: " .. target:GetClass():GetFullName(), "" }
    local cls = target:GetClass()
    while Valid(cls) do
        local cname = cls:GetFName():ToString()
        if cname == "Character" or cname == "Pawn" then break end
        table.insert(out, "=== " .. cls:GetFullName())
        cls:ForEachProperty(function(prop)
            local n = prop:GetFName():ToString()
            local t = prop:GetClass():GetFName():ToString()
            -- read values of plain number/bool properties only; other kinds are listed by name
            local plain = t:find("Float") or t:find("Double") or t:find("Int") or t:find("Bool") or t:find("Byte")
            local ok, v = false, nil
            if plain then ok, v = pcall(function() return target[n] end) end
            if ok and (type(v) == "number" or type(v) == "boolean") then
                table.insert(out, string.format("  %-16s %-42s = %s", t, n, tostring(v)))
            else
                table.insert(out, string.format("  %-16s %s", t, n))
            end
        end)
        cls = cls:GetSuperStruct()
    end
    local f = io.open(MOD_DIR .. "\\props_dump.txt", "w")
    if f then f:write(table.concat(out, "\n")); f:close() end
    Log("dumped %d lines to props_dump.txt", #out)
end

---------------------------------------------------------------------------
-- Main loop and keys
---------------------------------------------------------------------------
local function SafeTick()
    local ok, err = pcall(Tick)
    if not ok then
        fileText = "Fechtbuch error: " .. tostring(err)
        if tickNo % 300 == 1 then Log("tick error: %s", tostring(err)) end
    end
    if tickNo % 30 == 0 then WriteFile() end
end

-- Run entirely on the game thread. LoopAsync + ExecuteInGameThread ran Lua on two threads at
-- once, which corrupted the Lua state and crashed the game at random.
if LoopInGameThreadWithDelay then
    LoopInGameThreadWithDelay(TICK_MS, SafeTick)
    Log("loop: LoopInGameThreadWithDelay")
elseif LoopInGameThreadAfterFrames then
    LoopInGameThreadAfterFrames(2, SafeTick)
    Log("loop: LoopInGameThreadAfterFrames")
else
    LoopAsync(TICK_MS, function() ExecuteInGameThread(SafeTick); return false end)
    Log("loop: LoopAsync (older UE4SS)")
end

local function MenuMove(dir)
    local i = menuSel
    repeat
        i = i + dir
        if i < 1 then i = #MENU elseif i > #MENU then i = 1 end
    until not MENU[i].header
    menuSel = i
    menuDirty = true
end

local function Changed()
    SaveSettings()
    hudDirty = true
    menuDirty = true
end

local function MenuChange(dir, enter)
    local it = MENU[menuSel]
    if not it or it.header then return end
    if it.type == "bool" then
        S[it.key] = not S[it.key]
    elseif it.type == "choice" then
        local idx = 1
        for i, v in ipairs(it.choices) do if v == S[it.key] then idx = i end end
        idx = ((idx - 1 + (dir ~= 0 and dir or 1)) % #it.choices) + 1
        S[it.key] = it.choices[idx]
    elseif it.type == "num" then
        if dir == 0 then return end
        local v = S[it.key] + dir * it.step
        v = math.floor(v / it.step + 0.5) * it.step
        S[it.key] = math.max(it.min, math.min(it.max, v))
    elseif it.type == "action" then
        if not enter then return end
        if it.key == "reset" then S = Defaults()
        elseif it.key == "close" then menuOpen = false; menuDirty = true; return end
    end
    Changed()
end

-- Key callbacks do not run on the game thread, and Lua running on two threads at once is what
-- crashed the game before. So a callback only bumps a counter in this pre-filled table (no
-- allocation, no game objects); Tick picks the presses up on the game thread.
local keys = { home = 0, up = 0, down = 0, left = 0, right = 0, enter = 0, z = 0, f7 = 0, f8 = 0, f9 = 0 }
local function Bind(key, name) RegisterKeyBind(key, function() keys[name] = keys[name] + 1 end) end

local function Take(name)
    local v = keys[name]
    if v > 0 then keys[name] = 0 end
    return math.min(v, 5)
end

ProcessKeys = function()
    if Take("home") % 2 == 1 then menuOpen = not menuOpen; menuDirty = true end
    local up, down, left, right, enter = Take("up"), Take("down"), Take("left"), Take("right"), Take("enter")
    if menuOpen then
        for _ = 1, up do MenuMove(-1) end
        for _ = 1, down do MenuMove(1) end
        for _ = 1, left do MenuChange(-1) end
        for _ = 1, right do MenuChange(1) end
        for _ = 1, enter do MenuChange(0, true) end
    end
    if Take("z") > 0 then zPressed = true end
    if Take("f7") % 2 == 1 then S.hud = not S.hud; Changed() end
    if Take("f8") > 0 then
        states = {}
        session = { dealt = 0, dealtHits = 0, maxDealt = 0, kills = 0 }
        Log("counters reset")
    end
    if Take("f9") > 0 then dumpPending = true end
end

Bind(Key.HOME, "home")
Bind(Key.UP_ARROW, "up")
Bind(Key.DOWN_ARROW, "down")
Bind(Key.LEFT_ARROW, "left")
Bind(Key.RIGHT_ARROW, "right")
Bind(Key.RETURN, "enter")
Bind(Key.Z, "z")
Bind(Key.F7, "f7")
Bind(Key.F8, "f8")
Bind(Key.F9, "f9")

Log("v%s loaded from %s", VERSION, MOD_DIR)
