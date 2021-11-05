-- ==========================================================================
-- This file is part of Briefing Room for DCS World, a mission
-- generator for DCS World, by @akaAgar (https://github.com/akaAgar/briefing-room-for-dcs)

-- Briefing Room for DCS World is free software: you can redistribute it
-- and/or modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation, either version 3 of
-- the License, or (at your option) any later version.

-- Briefing Room for DCS World is distributed in the hope that it will
-- be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
-- of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with Briefing Room for DCS World. If not, see https://www.gnu.org/licenses/
-- ==========================================================================

-- ===================================================================================
-- SUMMARY
-- ===================================================================================

-- 1 - Core functions
--   1.1 - Constants and initialization
--   1.2 - Lua extensions
--     1.2.1 - Converters
--     1.2.2 - Math extensions
--     1.2.3 - String extensions
--     1.2.4 - Table extensions
--   1.3 - DCS World extensions
-- 2 - Tools
--   2.1 - Radio manager
--   2.2 - Aircraft activator
--   2.3 - Event handler
-- 3 - Mission
--   3.1 - Main BriefingRoom table and core functions
--   3.2 - Common F10 menu
--   3.3 - Objectives tables (generated by BriefingRoom)
--   3.4 - Objectives triggers (generated by BriefingRoom)
--   3.5 - Objectives features (generated by BriefingRoom)
--   3.6 - Mission features (generated by BriefingRoom)
--   3.7 - Startup

-- ***********************************************************************************
-- * 1 - CORE FUNCTIONS                                                              *
-- ***********************************************************************************

-- ===================================================================================
-- 1.1 - CONSTANTS AND INITIALIZATION
-- ===================================================================================

DEGREES_TO_RADIANS = 0.0174533 -- multiply by this constant to convert degrees to radians
LASER_CODE = 1688 -- laser code to use for AI target designation
METERS_TO_NM = 0.000539957 -- number of nautical miles in a meter
NM_TO_METERS = 1852.0 -- number of meters in a nautical mile
SMOKE_DURATION = 300 -- smoke markers last for 5 minutes (300 seconds) in DCS World
TWO_PI = math.pi * 2 -- two times Pi

briefingRoom = {} -- Main BriefingRoom table

-- Debug logging function
briefingRoom.printDebugMessages = false -- Disable debug messages logging, can be enabled later through mission features
function briefingRoom.debugPrint(message, duration)
  if not briefingRoom.printDebugMessages then return end -- Do not print debug messages if not in debug mode

  message = message or ""
  message = "BRIEFINGROOM: "..tostring(message)
  duration = duration or 3

  trigger.action.outText(message, duration, false)
  env.info(message, false)
end

-- ===================================================================================
-- 1.2 - LUA EXTENSIONS: Provides additional core functions to Lua
-- ===================================================================================

-- ==================
-- 1.2.1 - CONVERTERS
-- ==================

-- Converts a value to a boolean
function toboolean(val)
  if val == nil or val == 0 or val == false then return false end
  if type(val) == "string" and string.lower(val) == "false" then return false end
  return true
end

-- Like the built-in "tonumber" functions, but returns 0 instead of nil in case of an error
function tonumber0(val)
  local numVal = tonumber(val)
  if numVal == nil then return 0 end
  return numVal
end

-- =======================
-- 1.2.2 - MATH EXTENSIONS
-- =======================

-- Makes sure the value is between min and max and returns the clamped value
function math.clamp(val, min, max)
  return math.min(math.max(val, min), max)
end

-- Returns a random floating-point number between min and max
function math.randomFloat(min, max)
  if min >= max then return a end
  return min + math.random() * (max - min)
end

-- Returns a random floating point number between t[1] and t[2]
function math.randomFloatTable(t)
  return math.randomFloat(t[1], t[2])
end

-- Returns a random value from numerically-indexed table t
function math.randomFromTable(t)
  return t[math.random(#t)]
end

-- Returns a random point in circle of center center and of radius radius
function math.randomPointInCircle(center, radius)
  local dist = math.random() * radius
  local angle = math.random() * TWO_PI

  local x = center.x + math.cos(angle) * dist
  local y = center.y + math.sin(angle) * dist

  return { ["x"] = x, ["y"] = y }
end

-- =========================
-- 1.2.3 - STRING EXTENSIONS
-- =========================

-- Returns true if string str ends with needle
function string.endsWith(str, needle)
  return needle == "" or str:sub(-#needle) == needle
end

-- Search a string for all keys in a table and replace them with the matching value
function string.replace(str, repTable)
  for k,v in pairs(repTable) do
    str = string.gsub(str, k, v)
  end
  return str
end

-- Split string str in an array of substring, using the provided separator
function string.split(str, separator)
  separator = separator or "%s"

  local t = { }
  for s in string.gmatch(str, "([^"..separator.."]+)") do
    table.insert(t, s)
  end

  return t
end

-- Returns true if string str starts with needle
function string.startsWith(str, needle)
  return str:sub(1, #needle) == needle
end

-- Returns the value matching the case-insensitive key in enumTable
function string.toEnum(str, enumTable, defaultVal)
  local cleanStr = string.trim(string.lower(str))

  for key,val in pairs(enumTable) do
    if key:lower() == cleanStr then return val end
  end

  return defaultVal
end

-- Returns string str withtout leading and closing spaces
function string.trim(str)
  return str:match "^%s*(.-)%s*$"
end

-- ========================
-- 1.2.4 - TABLE EXTENSIONS
-- ========================

-- Returns true if table t contains value val
function table.contains(t, val)
  for _,v in pairs(t) do
    if v == val then return true end
  end
  return false
end

-- Returns true if table t contains key key
function table.containsKey(t, key)
  for k,_v in pairs(t) do
    if k == key then return true end
  end
  return false
end

-- Creates a new table which countains count elements from table valTable
function table.createFromRandomElements(valTable, count)
  local t = { }
  for i=1,count do table.insert(t, math.randomFromTable(valTable)) end
  return t
end

-- Creates a new table which countains count times the value val
function table.createFromSameElement(val, count)
  local t = { }
  for i=1,count do table.insert(t, val) end
  return t
end

-- Returns a deep copy of the table, doesn't work with recursive tables (code from http://lua-users.org/wiki/CopyTable)
function table.deepCopy(orig)
  if type(orig) ~= 'table' then return orig end

  local copy = {}
  for orig_key, orig_value in next, orig, nil do
    copy[table.deepCopy(orig_key)] = table.deepCopy(orig_value)
  end
  setmetatable(copy, table.deepCopy(getmetatable(orig)))

  return copy
end

-- Returns the key associated to a value in a table, or nil if not found
function table.getKeyFromValue(t, val)
  for k,v in pairs(t) do
    if v == val then return k end
  end
  return nil
end

-- Removes one instance of a value from a table
function table.removeValue(t, val)
  for k,v in pairs(t)do
    if v == val then
      table.remove(t, k)
      return
    end
  end
end

-- Shuffles a table
function table.shuffle(t)
  local len, random = #t, math.random
  for i = len, 2, -1 do
    local j = random( 1, i )
    t[i], t[j] = t[j], t[i]
  end
  return t
end

-- ===================================================================================
-- 1.3 - DCS WORLD EXTENSIONS: Provides additional functions to DCS World scripting
-- ===================================================================================

dcsExtensions = { } -- main dcsExtensions table

-- Returns an angle in degrees to the nearest cardinal direction, as a string
function dcsExtensions.degreesToCardinalDirection(angle)
  angle = math.clamp(angle % 360, 0, 359)
  local val = math.floor((angle / 22.5) + 0.5)
  local directions = array { "north", "north-north-east", "north-east", "east-north-east", "east", "east-south-east", "south-east", "south-south-east", "south", "south-south-west", "south-west", "west-south-west", "west", "west-north-west", "north-west", "north-north-west" }
  return directions[(val % 16) + 1]
end

-- Returns a table with all units controlled by a player
function dcsExtensions.getAllPlayers()
  local players = { }
  
  for i=1,2 do
    for _,g in pairs(coalition.getGroups(i)) do
      for __,u in pairs(g:getUnits()) do
        if u:getPlayerName() ~= nil then
          table.insert(players, u)
        end
      end
    end
  end

  return players
end

-- Returns the distance between two vec2s
function dcsExtensions.getDistance(vec2a, vec2b)
  return math.sqrt(math.pow(vec2a.x - vec2b.x, 2) + math.pow(vec2a.y - vec2b.y, 2))
end

-- Returns the group with ID id, or nil if no group with this ID is found
function dcsExtensions.getGroupByID(id)
  for i=1,2 do
    for _,g in pairs(coalition.getGroups(i)) do
      if g:getID() == id then return g end
    end
  end

  return nil
end

-- Is an unit alive?
function dcsExtensions.isUnitAlive(name)
  if name == nil then return false end
  local unit = Unit.getByName(name)
  if unit == nil then return false end
  if unit:isActive() == false then return false end
  if unit:getLife() < 1 then return false end

  return true
end

-- Returns the group with ID id, or nil if no group with this ID is found
function dcsExtensions.getStaticByID(id)
  for i=1,2 do
    for _,g in pairs(coalition.getStaticObjects(i)) do
      if tonumber(g:getID()) == tonumber(id) then return g end
    end
  end

  return nil
end

-- Returns the first unit alive in group with ID groupID, or nil if group doesn't exist or is completely destroyed
function dcsExtensions.getAliveUnitInGroup(groupID)
  local g = dcsExtensions.getGroupByID(groupID)
  if g == nil then return nil end

  for __,u in ipairs(g:getUnits()) do
    if u:getLife() >= 1 and u:isActive() then
      return u
    end
  end

  return nil
end

-- Returns all units belonging to the given coalition
function dcsExtensions.getCoalitionUnits(coalID)
  local units = { }
  for _,g in pairs(coalition.getGroups(coalID)) do
    for __,u in pairs(g:getUnits()) do
      if u:isActive() then
        if u:getLife() >= 1 then
          table.insert(units, u)
        end
      end
    end
  end

  return units
end

-- Returns the vec3 position of the first unit alive in group with ID id
function dcsExtensions.getGroupLocationByID(id)
  local g = dcsExtensions.getGroupByID(id)
  if g == nil then
    return nil
  end

  for _,unit in pairs(g:getUnits()) do
    if unit:getLife() >= 1 then return unit:getPoint() end
  end

  return nil
end

-- Returns the unit with ID id, or nil if no unit with this ID is found
function dcsExtensions.getUnitByID(id)
  for i=1,2 do
    for _,g in pairs(coalition.getGroups(i)) do
      for __,u in pairs(g:getUnits()) do
        if tonumber(u:getID()) == tonumber(id) then
          return u
        end
      end
    end
  end

  return nil
end

-- Converts a timecode (in seconds since midnight) in a hh:mm:ss string
function dcsExtensions.timeToHMS(timecode)
  local h = math.floor(timecode / 3600)
  timecode = timecode - h * 3600
  local m = math.floor(timecode / 60)
  timecode = timecode - m * 60
  local s = timecode

  return string.format("%.2i:%.2i:%.2i", h, m, s)
end

-- Converts a pair of x, y coordinates or a vec3 to a vec2
function dcsExtensions.toVec2(xOrVector, y)
  if y == nil then
    if xOrVector.z then return { ["x"] = xOrVector.x, ["y"] = xOrVector.z } end
    return { ["x"] = pxOrVector1.x, ["y"] = xOrVector.y } -- return xOrVector if it was already a vec2
  else
    return { ["x"] = xOrVector, ["y"] = y }
  end
end

-- Converts a triplet of x, y, z coordinates or a vec2 to a vec3
function dcsExtensions.toVec3(xOrVector, y, z)
  if y == nil or z == nil then
    if xOrVector.z then return { ["x"] = xOrVector.x, ["y"] = xOrVector.y, ["z"] = xOrVector.z } end  -- return xOrVector if it was already a vec3
    return { ["x"] = pxOrVector1.x, ["y"] = 0, ["z"] = xOrVector.y }
  else
    return { ["x"] = xOrVector, ["y"] = y, ["z"] = z }
  end
end

-- Converts a vec2 or ver3 into a human-readable string
function dcsExtensions.vectorToString(vec)
  if vec.z == nil then -- no Z coordinate, vec is a Vec2
    return tostring(vec.x)..","..tostring(vec.y)
  else
    return tostring(vec.x)..","..tostring(vec.y)..","..tostring(vec.z)
  end
end

-- Turns a vec2 to a string with LL/MGRS coordinates
-- Based on code by Bushmanni - https://forums.eagle.ru/showthread.php?t=99480
function dcsExtensions.vec2ToStringCoordinates(vec2)
  local pos = { x = vec2.x, y = 0, z = vec2.y }
  local cooString = ""

  local LLposN, LLposE = coord.LOtoLL(pos)
  local LLposfixN, LLposdegN = math.modf(LLposN)
  LLposdegN = LLposdegN * 60
  local LLposdegN2, LLposdegN3 = math.modf(LLposdegN)
  local LLposdegN3Decimal = LLposdegN3 * 1000
  LLposdegN3 = LLposdegN3 * 60

  local LLposfixE, LLposdegE = math.modf(LLposE)
  LLposdegE = LLposdegE * 60
  local LLposdegE2, LLposdegE3 = math.modf(LLposdegE)
  local LLposdegE3Decimal = LLposdegE3 * 1000
  LLposdegE3 = LLposdegE3 * 60

  local LLns = "N"
  if LLposfixN < 0 then LLns = "S" end
  local LLew = "E"
  if LLposfixE < 0 then LLew = "W" end

  local LLposNstring = LLns.." "..string.format("%.2i°%.2i'%.2i''", LLposfixN, LLposdegN2, LLposdegN3)
  local LLposEstring = LLew.." "..string.format("%.3i°%.2i'%.2i''", LLposfixE, LLposdegE2, LLposdegE3)
  cooString = "L/L: "..LLposNstring.." "..LLposEstring

  local LLposNstring = LLns.." "..string.format("%.2i°%.2i.%.3i", LLposfixN, LLposdegN2, LLposdegN3Decimal)
  local LLposEstring = LLew.." "..string.format("%.3i°%.2i.%.3i", LLposfixE, LLposdegE2, LLposdegE3Decimal)
  cooString = cooString.."\nL/L: "..LLposNstring.." "..LLposEstring

  local mgrs = coord.LLtoMGRS(LLposN, LLposE)
  local mgrsString = mgrs.MGRSDigraph.." "..mgrs.UTMZone.." "..tostring(mgrs.Easting).." "..tostring(mgrs.Northing)
  cooString = cooString.."\nMGRS: "..mgrsString

  return cooString
end

-- ***********************************************************************************
-- * 2 - TOOLS                                                                       *
-- ***********************************************************************************

-- ===================================================================================
-- 2.1 - RADIO MANAGER : plays radio messages (text and audio)
-- ===================================================================================

briefingRoom.radioManager = { } -- Main radio manager table
briefingRoom.radioManager.ANSWER_DELAY = { 4, 6 } -- Min/max time to get a answer to a radio message, in seconds
briefingRoom.radioManager.enableAudioMessages = $ENABLEAUDIORADIOMESSAGES$ -- Should audio radio messages be played?

function briefingRoom.radioManager.getAnswerDelay()
  return math.randomFloat(briefingRoom.radioManager.ANSWER_DELAY[1], briefingRoom.radioManager.ANSWER_DELAY[2])
end

-- Estimates the time (in seconds) required for the player to read a message
function briefingRoom.radioManager.getReadingTime(message)
  message = message or ""
  messsage = tostring(message)

  return math.max(5.0, #message / 8.7) -- 10.7 letters per second, minimum length 3.0 seconds
end

function briefingRoom.radioManager.play(message, oggFile, delay, functionToRun, functionParameters)
  delay = delay or 0
  local argsTable = { ["message"] = message, ["oggFile"] = oggFile, ["functionToRun"] = functionToRun, ["functionParameters"] = functionParameters }

  if delay > 0 then -- a delay was provided, schedule the radio message
    timer.scheduleFunction(briefingRoom.radioManager.doRadioMessage, argsTable, timer.getTime() + delay)
  else -- no delay, play the message at once
    briefingRoom.radioManager.doRadioMessage(argsTable, nil)
  end
end

function briefingRoom.radioManager.doRadioMessage(args, time)
  if args.message ~= nil then -- a message was provided, print it
    args.message = tostring(args.message)
    local duration = briefingRoom.radioManager.getReadingTime(args.message)
    trigger.action.outTextForCoalition($LUAPLAYERCOALITION$, args.message, duration, false)
  end

  if args.oggFile ~= nil and briefingRoom.radioManager.enableAudioMessages then -- a sound was provided and radio sounds are enabled, play it
    trigger.action.outSoundForCoalition($LUAPLAYERCOALITION$, args.oggFile..".ogg")
  else -- else play the default sound
    trigger.action.outSoundForCoalition($LUAPLAYERCOALITION$, "Radio0.ogg")
  end

  if args.functionToRun ~= nil then -- a function was provided, run it
    args.functionToRun(args.functionParameters)
  end

  return nil -- disable scheduling, if any
end

-- ===================================================================================
-- 2.2 - AIRCRAFT ACTIVATOR: activates aircraft flight groups gradually during the mission
-- ===================================================================================

briefingRoom.aircraftActivator = { }
briefingRoom.aircraftActivator.INTERVAL = { 10, 20 } -- min/max interval (in seconds) between two updates
briefingRoom.aircraftActivator.currentQueue = { $AIRCRAFTACTIVATORCURRENTQUEUE$ } -- current queue of aircraft group IDs to spawn every INTERVAL seconds
briefingRoom.aircraftActivator.reserveQueue = { $AIRCRAFTACTIVATORRESERVEQUEUE$ } -- additional aircraft group IDs to be added to the queue later

function briefingRoom.aircraftActivator.getRandomInterval()
  return math.random(briefingRoom.aircraftActivator.INTERVAL[1], briefingRoom.aircraftActivator.INTERVAL[2])
end

function briefingRoom.aircraftActivator.pushFromReserveQueue()
  if #briefingRoom.aircraftActivator.reserveQueue == 0 then -- no extra queues available
    briefingRoom.debugPrint("Tried to push extra aircraft to the activation queue, but found none")
    return
  end

  -- add aircraft groups from the reserve queue to the current queue
  local numberOfGroupsToAdd = math.max(1, math.min(briefingRoom.aircraftActivator.reserveQueueInitialCount / (#briefingRoom.mission.objectives + 1), #briefingRoom.aircraftActivator.reserveQueue))

  for i=0,numberOfGroupsToAdd do
    briefingRoom.debugPrint("Pushed aircraft group #"..tostring(briefingRoom.aircraftActivator.reserveQueue[1]).." into the activation queue")
    table.insert(briefingRoom.aircraftActivator.currentQueue, briefingRoom.aircraftActivator.reserveQueue[1])
    table.remove(briefingRoom.aircraftActivator.reserveQueue, 1)
  end
end

function briefingRoom.aircraftActivator.spawnGroup(groupID)
  local acGroup = dcsExtensions.getGroupByID(groupID) -- get the group
  if acGroup ~= nil then -- activate the group, if it exists
    acGroup:activate()
    briefingRoom.debugPrint("Activating aircraft group "..acGroup:getName())
  else
    briefingRoom.debugPrint("Failed to activate aircraft group "..tostring(briefingRoom.aircraftActivator.currentQueue[1]))
  end
  return nil
end

-- Every INTERVAL seconds, check for aircraft groups to activate in the queue
function briefingRoom.aircraftActivator.update(args, time)
  briefingRoom.debugPrint("Looking for aircraft groups to activate, found "..tostring(#briefingRoom.aircraftActivator.currentQueue), 1)
  if #briefingRoom.aircraftActivator.currentQueue == 0 then -- no aircraft in the queue at the moment
    return time + briefingRoom.aircraftActivator.getRandomInterval() -- schedule next update and return
  end

  local acGroup = dcsExtensions.getGroupByID(briefingRoom.aircraftActivator.currentQueue[1]) -- get the group
  if acGroup ~= nil then -- activate the group, if it exists
    acGroup:activate()
    briefingRoom.debugPrint("Activating aircraft group "..acGroup:getName())
  else
    briefingRoom.debugPrint("Failed to activate aircraft group "..tostring(briefingRoom.aircraftActivator.currentQueue[1]))
  end
  table.remove(briefingRoom.aircraftActivator.currentQueue, 1) -- remove the ID from the queue

  return time + briefingRoom.aircraftActivator.getRandomInterval() -- schedule next update
end

briefingRoom.aircraftActivator.reserveQueueInitialCount = #briefingRoom.aircraftActivator.reserveQueue

-- ===================================================================================
-- 2.3 - EVENT HANDLER: common event handler used during the mission
-- ===================================================================================

briefingRoom.eventHandler = {}

function briefingRoom.handleGeneralKill(event) 
  if event.id == world.event.S_EVENT_DEAD or event.id == world.event.S_EVENT_CRASH then
    if event.initiator == nil then return end -- no initiator
    if event.initiator:getCategory() ~= Object.Category.UNIT and event.initiator:getCategory() ~= Object.Category.STATIC then return end -- initiator was not an unit or static
    
    if event.initiator:getCoalition() ~= $LUAPLAYERCOALITION$ then -- unit is an enemy, radio some variation of a "enemy destroyed" message
      local soundName = "UnitDestroyed"
      local messages = { "Weapon was effective.", "Good hit! Good hit!", "They're going down.", "Splashed one!" }
      local messageIndex = math.random(1, 2)
      local messageIndexOffset = 0



      local targetType = "Ground"
      if event.id == world.event.S_EVENT_CRASH then
        messageIndexOffset = 2
        if event.initiator:inAir() then
          targetType = "Air"
          messageIndexOffset = 2
        elseif unitWasAMissionTarget then
          return -- No "target splashed" message when destroying a target aircraft on the ground (mostly for OCA missions)
        end
      end

      briefingRoom.radioManager.play(messages[messageIndex + messageIndexOffset], "RadioHQ"..soundName..targetType..tostring(messageIndex), math.random(1, 3))
    end
  end
end

function briefingRoom.eventHandler:onEvent(event)
  if event.id == world.event.S_EVENT_TAKEOFF and -- unit took off
    event.initiator:getPlayerName() ~= nil then -- unit is a pleyr
      briefingRoom.mission.coreFunctions.beginMission() -- first player to take off triggers the mission start
  end

  local eventHandled = false
  -- Pass the event to the completion trigger of all objectives that have one
  for i=1,#briefingRoom.mission.objectives do
    if briefingRoom.mission.objectiveTriggers[i] ~= nil then
      local didHandle = briefingRoom.mission.objectiveTriggers[i](event)
      if didHandle then
        eventHandled = true
      end
    end
  end 
  if eventHandled == false then
    briefingRoom.handleGeneralKill(event)
  end
end

-- ***********************************************************************************
-- * 3 - MISSION                                                                     *
-- ***********************************************************************************

-- ===================================================================================
-- 3.1 - MAIN BRIEFINGROOM TABLE AND CORE FUNCTIONS
-- ===================================================================================

briefingRoom.mission = {} -- Main BriefingRoom mission table
briefingRoom.mission.complete = false -- Is the mission complete?
briefingRoom.mission.coreFunctions = { }
briefingRoom.mission.hasStarted = false -- has at least one player taken off?

-- Marks objective with index index as complete, and completes the mission itself if all objectives are complete
function briefingRoom.mission.coreFunctions.completeObjective(index)
  if briefingRoom.mission.complete then return end -- mission already complete
  if briefingRoom.mission.objectives[index].complete then return end -- objective already complete

  briefingRoom.debugPrint("Objective "..tostring(index).." marked as complete")
  briefingRoom.mission.objectives[index].complete = true
  briefingRoom.mission.objectivesLeft = briefingRoom.mission.objectivesLeft - 1
  briefingRoom.aircraftActivator.pushFromReserveQueue() -- activate next batch of aircraft (so more CAP will pop up)

  -- Remove objective menu from the F10 menu
  if briefingRoom.f10Menu.objectives[index] ~= nil then
    missionCommands.removeItemForCoalition($LUAPLAYERCOALITION$, briefingRoom.f10Menu.objectives[index])
    briefingRoom.f10Menu.objectives[index] = nil
  end

  -- Add a little delay before playing the "mission/objective complete" sounds to make sure all "target destroyed", "target photographed", etc. sounds are done playing
  if briefingRoom.mission.objectivesLeft <= 0 then
    briefingRoom.debugPrint("Mission marked as complete")
    briefingRoom.mission.complete = true
    briefingRoom.radioManager.play("Excellent work! Mission complete, you may return to base.", "RadioHQMissionComplete", math.random(6, 8))
    trigger.action.setUserFlag(1, true) -- Mark the mission complete internally, so campaigns can move to the next mission
  else
    briefingRoom.radioManager.play("Good job! Objective complete, proceed to next objective.", "RadioHQObjectiveComplete", math.random(6, 8))
  end
end

-- Begins the mission (called when the first player takes off)
function briefingRoom.mission.coreFunctions.beginMission()
  if briefingRoom.mission.hasStarted then return end -- mission has already started, do nothing

  briefingRoom.debugPrint("Mission has started")

  -- enable the aircraft activator and start spawning aircraft
  briefingRoom.mission.hasStarted = true
  briefingRoom.aircraftActivator.pushFromReserveQueue()
  timer.scheduleFunction(briefingRoom.aircraftActivator.update, nil, timer.getTime() + briefingRoom.aircraftActivator.getRandomInterval())
end

-- ===================================================================================
-- 3.2 - COMMON F10 MENU
-- ===================================================================================

-- Mission F10 menu hierarchy
briefingRoom.f10Menu = { }
briefingRoom.f10Menu.objectives = { }

 -- Mission F10 menu functions
briefingRoom.f10MenuCommands = { }
briefingRoom.f10MenuCommands.missionFeatures = { }

 -- Mission status menu
function briefingRoom.f10MenuCommands.missionStatus()
  local msnStatus = ""
  local msnSound = ""

  if briefingRoom.mission.complete then
    msnStatus = "Mission complete, you may return to base.\n\n"
    msnSound = "RadioHQMissionStatusComplete"
  else
    msnStatus = "Mission is still in progress.\n\n"
    msnSound = "RadioHQMissionStatusInProgress"
  end

  for i,o in ipairs(briefingRoom.mission.objectives) do
    if o.complete then
      msnStatus = msnStatus.."[X]"
    else
      msnStatus = msnStatus.."[ ]"
    end

    local objectiveProgress = ""
    if o.unitsCount > 0 and o.hideTargetCount ~= true then
      local targetsDone = math.max(0, o.unitsCount - #o.unitsID)
      objectiveProgress = " ("..tostring(targetsDone).."/"..tostring(o.unitsCount)..")"
    end

    msnStatus = msnStatus.." "..o.task..objectiveProgress.."\n"
  end

  briefingRoom.radioManager.play("Command, require update on mission status.", "RadioPilotMissionStatus")
  briefingRoom.radioManager.play(msnStatus, msnSound, briefingRoom.radioManager.getAnswerDelay())
end

function briefingRoom.f10MenuCommands.getWaypointCoordinates(index)
  local cooMessage = dcsExtensions.vec2ToStringCoordinates(briefingRoom.mission.objectives[index].waypoint)
  briefingRoom.radioManager.play("Command, request confirmation of waypoint "..briefingRoom.mission.objectives[index].name.." coordinates.", "RadioPilotWaypointCoordinates")
  briefingRoom.radioManager.play("Acknowledged, transmitting waypoint "..briefingRoom.mission.objectives[index].name.." coordinates.\n\n"..cooMessage, "RadioHQWaypointCoordinates", briefingRoom.radioManager.getAnswerDelay())
end

-- Common mission menu (mission status and mission features)
briefingRoom.f10Menu.missionMenu = missionCommands.addSubMenuForCoalition($LUAPLAYERCOALITION$, "Mission", nil)
missionCommands.addCommandForCoalition($LUAPLAYERCOALITION$, "Mission status", briefingRoom.f10Menu.missionMenu, briefingRoom.f10MenuCommands.missionStatus, nil)

-- ===================================================================================
-- 3.3 - OBJECTIVES TABLES (generated by BriefingRoom)
-- ===================================================================================

briefingRoom.mission.objectives = { } -- Main objective table
$SCRIPTOBJECTIVES$
briefingRoom.mission.objectivesLeft = #briefingRoom.mission.objectives -- Store the total of objective left to complete

for i=1,#briefingRoom.mission.objectives do
  missionCommands.addCommandForCoalition($LUAPLAYERCOALITION$, "Request waypoint coordinates", briefingRoom.f10Menu.objectives[i], briefingRoom.f10MenuCommands.getWaypointCoordinates, i)
end

-- ===================================================================================
-- 3.4 - OBJECTIVES TRIGGERS (generated by BriefingRoom)
-- ===================================================================================

briefingRoom.mission.objectiveTriggers = { } -- Objective triggers (checks objective completion)
briefingRoom.mission.objectiveTimers = { } -- Objective timers (called every second)

function briefingRoom.mission.objectiveTimerSchedule(args, time)
  for i=1,#briefingRoom.mission.objectives do
    if briefingRoom.mission.objectiveTimers[i] ~= nil then
      briefingRoom.mission.objectiveTimers[i]()
    end
  end

  return time + 1
end

timer.scheduleFunction(briefingRoom.mission.objectiveTimerSchedule, nil, timer.getTime() + 1)
$SCRIPTOBJECTIVESTRIGGERS$

-- ===================================================================================
-- 3.5 - OBJECTIVES FEATURES (generated by BriefingRoom)
-- ===================================================================================

briefingRoom.mission.objectiveFeatures = { } -- Objective features
briefingRoom.mission.objectiveFeaturesCommon = { } -- Common objective features functions
for i=1,#briefingRoom.mission.objectives do briefingRoom.mission.objectiveFeatures[i] = {} end
$SCRIPTOBJECTIVESFEATURES$

-- ===================================================================================
-- 3.6 - MISSION FEATURES (generated by BriefingRoom)
-- ===================================================================================

briefingRoom.mission.missionFeatures = { } -- Mission features
briefingRoom.mission.missionFeatures.groupsID = { } -- Mission features group ID
$SCRIPTMISSIONFEATURES$

-- ===================================================================================
-- 3.7 - STARTUP
-- ===================================================================================

-- All done, enable event handler so the mission can begin
world.addEventHandler(briefingRoom.eventHandler)
