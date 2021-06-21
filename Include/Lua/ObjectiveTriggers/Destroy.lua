-- Triggers the completion of objective $OBJECTIVEINDEX$ when all targets are destroyed
briefingRoom.mission.objectiveTriggers[$OBJECTIVEINDEX$] = function(event)
  -- Mission complete, nothing to do
  if briefingRoom.mission.complete then return end

  -- Objective complete, nothing to do
  if briefingRoom.mission.objectives[$OBJECTIVEINDEX$].complete then return end

  -- Not a "destruction" event
  if event.id ~= world.event.S_EVENT_DEAD and event.id ~= world.event.S_EVENT_CRASH then return end

  -- Destroyed unit wasn't a target
  if not table.contains(briefingRoom.mission.objectives[$OBJECTIVEINDEX$].unitsID, event.initiator) then return end

  -- Remove the unit from the list of targets
  table.removeValue(briefingRoom.mission.objectives[index].unitsID, unitID)

  -- Play "target destroyed" radio message
  local soundName = "TargetDestroyed"
  local messages = { "Target destroyed.", "Good hit on target.", "Target splashed.", "Target shot down!" }
  local targetType = "Ground"
  local messageIndex = math.random(1, 2)
  local messageIndexOffset = 0
  if event.id == world.event.S_EVENT_CRASH and event.initiator:inAir() then
    targetType = "Air"
    messageIndexOffset = 2
  end
  briefingRoom.radioManager.play(messages[messageIndex + messageIndexOffset], "RadioHQ"..soundName..targetType..tostring(messageIndex), math.random(1, 3))

  -- Mark the objective as complete if all targets have been destroyed
  if #briefingRoom.mission.objectives[$OBJECTIVEINDEX$].unitsID < 1 then -- all target units destroyed, objective complete
    briefingRoom.mission.coreFunctions.completeObjective(index)
  end
end