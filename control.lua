-- control.lua
-- Radar Marker
--
-- To do: Have separate files for the event registration versus the main logic.

local RadarMarker = {}

local debugging = false

local plannedLayout, announceConfig, placedRadarsConfig

-- Should clutter avoidance range be a setting?
RadarMarker.ClutterAvoidanceRange = 15 -- A range of 15 equates to approximately: "within the same chunk".

local function NotifyIf(verbose, msg)
	if verbose then game.print(msg) end
	if debugging then log(msg) end
end

function RadarMarker.CacheSettings()
	plannedLayout = {
		enabled = (settings.global['radarmarker-mark-planned-radars'].value ~= "None"),
		missing = (settings.global['radarmarker-mark-planned-radars'].value == "Missing"),
		spacing = settings.global['radarmarker-planned-radars-spacing'].value,
		dx = settings.global['radarmarker-planned-radars-x-offset'].value,
		dy = settings.global['radarmarker-planned-radars-y-offset'].value,
		labelled = settings.global['radarmarker-label-planned-radars'].value,
	}
	announceConfig = {
		placement = settings.global['radarmarker-announce-placement'].value,
		removal = settings.global['radarmarker-announce-removal'].value,
	}
	placedRadarsConfig = {
		mark = (settings.global['radarmarker-mark-placed-radars'].value ~= "None"),
		missaligned = (settings.global['radarmarker-mark-placed-radars'].value == "Misalligned"),
	}
end

function RadarMarker.ToChunkPosition(pos)
  local x, y = math.floor(pos.x / 32), math.floor(pos.y / 32)
  return {x=x,y=y}
end

function RadarMarker.XIndexToPosition(xindex, offset)
	return offset + (xindex * plannedLayout.spacing)
end

function RadarMarker.IndexToPosition(index)
	return {
		x = RadarMarker.XIndexToPosition(index[1], plannedLayout.dx),
		y = RadarMarker.XIndexToPosition(index[2], plannedLayout.dy),
	}
end

function RadarMarker.XPositionToIndex(xpos, offset)
	return math.floor((xpos - offset) / plannedLayout.spacing)
end

function RadarMarker.PositionToIndex(pos)
	return {
		RadarMarker.XPositionToIndex(pos.x + (plannedLayout.spacing / 2),
			plannedLayout.dx),
		RadarMarker.XPositionToIndex(pos.y + (plannedLayout.spacing / 2),
			plannedLayout.dy)
	}
end

function RadarMarker.XChunkToPlannedPosition(xchunk, offset)
	local x1 = (32 * xchunk) - 1
	local x2 = 32 + x1
	local i1 = RadarMarker.XPositionToIndex(x1, offset)
	local i2 = RadarMarker.XPositionToIndex(x2, offset)
	return i2 > i1
		and RadarMarker.XIndexToPosition(i2, offset)
		or nil
end

function RadarMarker.ChunkToPlannedPosition(chunk)
	local pos = {
		x = RadarMarker.XChunkToPlannedPosition(chunk.x, plannedLayout.dx),
		y = RadarMarker.XChunkToPlannedPosition(chunk.y, plannedLayout.dy),
	}
	return pos.x ~= nil and pos.y ~= nil
		and pos
		or nil
end

function RadarMarker.MarkRadarAt(position, quiet, label) -- Planned or existing
	game.forces.player.add_chart_tag(
		1, -- nauvis
		{
			position = position,
			icon = {type = 'item', name = 'radar'},
			text = label
		}
	)
	local index = RadarMarker.PositionToIndex(position)
	NotifyIf(announceConfig.placement and not quiet,
		'Added radar marker at ' .. serpent.line(position) .. ' index ' .. serpent.line(index))
end

function RadarMarker.FindTagsAt (position, range)
	range = range or 0.1
	return game.forces.player.find_chart_tags(1, -- nauvis
		{{position.x - range, position.y - range}, {position.x + range, position.y + range}})
end

function RadarMarker.MarkPlacedRadar(entity, quiet)
	local position = entity.position
	-- Avoid cluttering the map if there is another nearby marker
	local tags = RadarMarker.FindTagsAt(position, RadarMarker.ClutterAvoidanceRange)
	if #tags > 0 then
		local index = RadarMarker.PositionToIndex(position)
		NotifyIf(announceConfig.placement and not quiet,
			'Skipping duplicate radar marker at ' .. serpent.line(position) .. ' index ' .. serpent.line(index))
		return 0
	end
	if not placedRadarsConfig.missaligned
		or (RadarMarker.ChunkToPlannedPosition(RadarMarker.ToChunkPosition(position)) == nil)
	then
		RadarMarker.MarkRadarAt(position, quiet)
		return 1
	end
	return 0
end

function RadarMarker.GetMarkerLabel (position)
	local index = RadarMarker.PositionToIndex(position)
	return index[1] .. ', ' .. index[2]
end

function RadarMarker.UnmarkRadarAt (position, quiet)
	local label = RadarMarker.GetMarkerLabel(position)
	local tags = RadarMarker.FindTagsAt(position)
	for i = 1, #tags do
		local tag = tags[i]
		if tag.text and (tag.text == '' or tag.text == label)
			and tag.icon and tag.icon.type == 'item' and tag.icon.name == 'radar'
		then
			NotifyIf(announceConfig.removal and not quiet,
				'Removed radar marker at ' .. serpent.line(tag.position) .. ' index {' .. label .. '}')
			tag.destroy()
			return 1
		end
	end
	return 0
end

function RadarMarker.EnsureChunkRadarMarked(chunkpos, quiet, position)
	position = position or RadarMarker.ChunkToPlannedPosition(chunkpos)
	if position then
		local tags = RadarMarker.FindTagsAt(position)
		if #tags == 0 then
			local label = nil
			if plannedLayout.labelled then
				label = RadarMarker.GetMarkerLabel(position)
			end
			RadarMarker.MarkRadarAt(position, quiet, label)
			return 1
		end
	end
	return 0
end

function RadarMarker.UnmarkChunkRadar(chunkpos, quiet, position)
	position = position or RadarMarker.ChunkToPlannedPosition(chunkpos)
	if position then
		return RadarMarker.UnmarkRadarAt(position, quiet)
	end
	return 0
end

function RadarMarker.MarkAllPlacedRadars()
	NotifyIf(announceConfig.placement,
		'Marking existing radars on the map.')
	local allRadars = game.surfaces[1].find_entities_filtered({name='radar', type='radar'})
	local numDone = 0
	for i = 1, #allRadars do
		numDone = numDone + RadarMarker.MarkPlacedRadar(allRadars[i], true)
	end
	NotifyIf(announceConfig.placement,
		'Added ' .. numDone .. ' markers for ' .. #allRadars .. ' existing radars on the map.')
end

function RadarMarker.UnmarkAllPlacedRadars()
	local allRadars = game.surfaces[1].find_entities_filtered({name='radar', type='radar'})
	NotifyIf(announceConfig.removal,
		'Removing map markers for ' .. #allRadars .. ' existing radars.')
	for i = 1, #allRadars do
		RadarMarker.UnmarkRadarAt(allRadars[i].position, true)
	end
end

function RadarMarker.ForEachPlannedRadar(action)
	local numChunks = 0
	local numCandidates = 0
	local numDone = 0
	for chunkpos in game.surfaces[1].get_chunks() do
		numChunks = numChunks + 1
		if game.forces.player.is_chunk_charted(1,chunkpos) then
			local pos = RadarMarker.ChunkToPlannedPosition(chunkpos)
			if pos then
				numCandidates = numCandidates + 1
				numDone = numDone + action(chunkpos, true, pos)
			end
		end
	end
	return {
		numChunks = numChunks,
		numCandidates = numCandidates,
		numDone = numDone,
		}
end

function RadarMarker.MarkAllPlannedRadars()
	local result = RadarMarker.ForEachPlannedRadar(RadarMarker.EnsureChunkRadarMarked)
	NotifyIf(announceConfig.placement,
		'Added ' .. result.numDone .. ' radar markers to '
			.. result.numCandidates .. ' planned radar locations across ' .. result.numChunks .. ' chunks.')
end

function RadarMarker.UnmarkAllPlannedRadars()
	local result = RadarMarker.ForEachPlannedRadar(RadarMarker.UnmarkChunkRadar)
	NotifyIf(announceConfig.removal,
		'Removed ' .. result.numDone .. ' radar markers from '
			.. result.numCandidates .. ' planned radar locations across ' .. result.numChunks .. ' chunks.')
end

-- Register events

-- Construction events

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity},
	function(e)
		if e.created_entity.name == 'radar' and e.created_entity.type == 'radar'
			and placedRadarsConfig.mark
		then

			-- There have been some spurious markers showing up.
			-- Log some details to help track down the problem.
			if (debugging) then
				local entity = e.created_entity
				log('Radar built, event ' .. e.name
					.. ', entity valid: ' .. serpent.line(entity.valid)
					.. ', surface: ' .. entity.surface.index .. ' ' .. entity.surface.name
					.. ', position: ' .. serpent.line(entity.position)
					.. ', bounding box: ' .. serpent.line(entity.bounding_box)
				)
			end

			RadarMarker.MarkPlacedRadar(e.created_entity)
		end
	end
)

-- Destruction events
--
-- To do: Consider behaviour when radar killed by biter or by player weapon.
-- ... Based on tracking existing radars, the marker should be removed,
--     but as a planning marker, it should remain. (Also consider whether it was a planned chunk.)

script.on_event({defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity},
	function(e)
		if e.entity.name == 'radar' and e.entity.type == 'radar'
			and placedRadarsConfig.mark
		then
			RadarMarker.UnmarkRadarAt(e.entity.position)
		end
	end
)

-- Chunk events

script.on_event(defines.events.on_chunk_charted,
	function(chunk)
		if plannedLayout.enabled
		then
			RadarMarker.EnsureChunkRadarMarked(chunk.position)
		end
	end
)

-- Mod version change, etc.

script.on_configuration_changed(RadarMarker.CacheSettings)

-- When loading a save game and the mod existed in that save game:

script.on_load(RadarMarker.CacheSettings)

-- Handling first time loading in a new or existing map:

script.on_init(
	function()
		RadarMarker.CacheSettings()

		if
			placedRadarsConfig.mark or plannedLayout.enabled
		then
			NotifyIf(announceConfig.placement,
				'Initialising Radar Markers.')
			if placedRadarsConfig.mark then
				RadarMarker.MarkAllPlacedRadars()
			end
			if plannedLayout.enabled then
				RadarMarker.MarkAllPlannedRadars()
			end
		end
	end
)





-- Configuration change

function RadarMarker.ChangePlannedLayout()
	-- This is called for each individual setting that is changed,
	-- but we want to rearrange the markers only once.
	-- So check and exit if all relevant settings have already been saved/cached/updated.
	if placedRadarsConfig.mark == (settings.global['radarmarker-mark-placed-radars'].value ~= "None")
	and placedRadarsConfig.missaligned == (settings.global['radarmarker-mark-placed-radars'].value == "Misalligned")
	and plannedLayout.enabled == (settings.global['radarmarker-mark-planned-radars'].value ~= "None")
	and plannedLayout.missing == (settings.global['radarmarker-mark-planned-radars'].value == "Missing")
	and plannedLayout.spacing == settings.global['radarmarker-planned-radars-spacing'].value
	and plannedLayout.dx == settings.global['radarmarker-planned-radars-x-offset'].value
	and plannedLayout.dy == settings.global['radarmarker-planned-radars-y-offset'].value
	and plannedLayout.labelled == settings.global['radarmarker-label-planned-radars'].value
	then
		return
	end
	-- Update announcement settings before calling functions with announcements
	announceConfig.placement = settings.global['radarmarker-announce-placement'].value
	announceConfig.removal = settings.global['radarmarker-announce-removal'].value
	-- If previously enabled, remove markers using the previous settings
	if placedRadarsConfig.mark then
		-- Some placed radar markers might become unnecessary due to a revised planned grid
		RadarMarker.UnmarkAllPlacedRadars()
	end
	if plannedLayout.enabled then
		RadarMarker.UnmarkAllPlannedRadars()
	end
	-- Save/cache updated settings
	placedRadarsConfig.mark = (settings.global['radarmarker-mark-placed-radars'].value ~= "None")
	placedRadarsConfig.missaligned = (settings.global['radarmarker-mark-placed-radars'].value == "Misalligned")
	plannedLayout.enabled = (settings.global['radarmarker-mark-planned-radars'].value ~= "None")
	plannedLayout.missing = (settings.global['radarmarker-mark-planned-radars'].value == "Missing")
	plannedLayout.spacing = settings.global['radarmarker-planned-radars-spacing'].value
	plannedLayout.dx = settings.global['radarmarker-planned-radars-x-offset'].value
	plannedLayout.dy = settings.global['radarmarker-planned-radars-y-offset'].value
	plannedLayout.labelled = settings.global['radarmarker-label-planned-radars'].value
	-- If currently enabled, add markers using the new settings
	if plannedLayout.enabled then
		RadarMarker.MarkAllPlannedRadars()
	end
	-- There could be placed radars missing their markers due to being on the previously planned grid
	-- This could be due to grid positioning changes and/or ".enabled" changes.
	if placedRadarsConfig.mark then
		RadarMarker.MarkAllPlacedRadars()
	end
end

script.on_event(defines.events.on_runtime_mod_setting_changed,
	function(e)
		if e.setting == 'radarmarker-announce-placement' then
			announceConfig.placement = settings.global['radarmarker-announce-placement'].value
		elseif e.setting == 'radarmarker-announce-removal' then
			announceConfig.removal = settings.global['radarmarker-announce-removal'].value
		elseif e.setting == 'radarmarker-mark-placed-radars'
			-- Might have already been actioned by ChangePlannedLayout().
			and (
				placedRadarsConfig.mark ~= (settings.global['radarmarker-mark-placed-radars'].value ~= "None")
				or placedRadarsConfig.missaligned ~= (settings.global['radarmarker-mark-placed-radars'].value == "Misalligned")
			)
			then
			-- Add or remove placed radar map markers according to the new setting value.
			placedRadarsConfig.mark = (settings.global['radarmarker-mark-placed-radars'].value ~= "None")
			placedRadarsConfig.missaligned = (settings.global['radarmarker-mark-placed-radars'].value == "Misalligned")
			RadarMarker.UnmarkAllPlacedRadars()
			if placedRadarsConfig.mark then
				RadarMarker.MarkAllPlacedRadars()
			end
		elseif e.setting == 'radarmarker-mark-planned-radars'
		or e.setting == 'radarmarker-planned-radars-spacing'
		or e.setting == 'radarmarker-planned-radars-x-offset'
		or e.setting == 'radarmarker-planned-radars-y-offset'
		or e.setting == 'radarmarker-label-planned-radars'
		then
			RadarMarker.ChangePlannedLayout()
		end
	end
)

-- Export interfaces:

remote.add_interface(script.mod_name,
	{
		DumpLog = RadarMarker.DumpLog,
		MarkAllPlacedRadars = RadarMarker.MarkAllPlacedRadars,
		UnmarkAllPlacedRadars = RadarMarker.UnmarkAllPlacedRadars,
		MarkAllPlannedRadars = RadarMarker.MarkAllPlannedRadars,
		UnmarkAllPlannedRadars = RadarMarker.UnmarkAllPlannedRadars,
	}
)

