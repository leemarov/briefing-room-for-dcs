briefingRoom.f10MenuCommands.debug = { } -- Create F10 debug sub-menu
briefingRoom.printDebugMessages = true -- Enable debug messages

function briefingRoom.f10MenuCommands.debug.activateAllAircraft()
  if #briefingRoom.aircraftActivator.reserveQueue == 0 then
    briefingRoom.debugPrint("No groups in the reserve queue")
    return
  end

  while #briefingRoom.aircraftActivator.reserveQueue > 0 do
    briefingRoom.aircraftActivator.pushFromReserveQueue()
  end
end

-- Destroys the next active target unit
function briefingRoom.f10MenuCommands.debug.destroyTargetUnit()
  for index,objective in ipairs(briefingRoom.mission.objectives) do
    if (#objective.unitsID > 0) then
      local u = dcsExtensions.getUnitByID(objective.unitsID[1])
      if u ~= nil then
        trigger.action.outText("Destroyed "..u:getName(), 2)
        trigger.action.explosion(u:getPoint(), 100)
        return
      end
    end
  end

  trigger.action.outText("No target units found", 2)
end

-- Destroys the next active enemy unit
-- function briefingRoom.extensions.debug.destroyEnemyUnit()
  -- for _,g in ipairs(coalition.getGroups($ENEMYCOALITION$)) do
    -- for __,u in ipairs(g:getUnits()) do
      -- if u:getLife() > 0 then
        -- trigger.action.outText("Destroyed "..u:getName(), 2)
        -- trigger.action.explosion(u:getPoint(), 100)
        -- return
      -- end
    -- end
  -- end
  -- trigger.action.outText("No enemy units found", 2)
-- end

-- Create the debug menu
do
  briefingRoom.f10Menu.debug = missionCommands.addSubMenu("(DEBUG MENU)", nil)
  missionCommands.addCommand("Destroy target unit", briefingRoom.f10Menu.debug, briefingRoom.f10MenuCommands.debug.destroyTargetUnit)
  missionCommands.addCommand("Simulate player takeoff (start mission)", briefingRoom.f10Menu.debug, briefingRoom.mission.coreFunctions.beginMission)
  missionCommands.addCommand("Activate all aircraft groups", briefingRoom.f10Menu.debug, briefingRoom.f10MenuCommands.debug.activateAllAircraft)

  -- missionCommands.addCommand("Destroy enemy unit", briefingRoom.extensions.debug.menu, briefingRoom.extensions.debug.destroyEnemyUnit)
  -- missionCommands.addCommand("Destroy enemy structure", briefingRoom.extensions.debug.menu, briefingRoom.extensions.debug.destroyEnemyStructure)
end
