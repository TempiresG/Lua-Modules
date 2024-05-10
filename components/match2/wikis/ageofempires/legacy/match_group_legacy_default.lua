---
-- @Liquipedia
-- wiki=ageofempires
-- page=Module:MatchGroup/Legacy/Default
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local MatchGroupLegacyDefault = {}

local Logic = require('Module:Logic')
local String = require('Module:StringUtils')

local MAX_NUM_MAPS = 20
local MAX_NUM_OPPONENTS = 2

local _roundData

function MatchGroupLegacyDefault.get(templateid, bracketType)
	local LowerHeader = {}
	local matches = mw.ext.Brackets.getCommonsBracketTemplate(templateid)

	assert(type(matches) == 'table')
	local bracketData = {}
	_roundData = _roundData or {}
	local lastround = 0
	for _, match in ipairs(matches) do
		bracketData, lastround, LowerHeader =
			MatchGroupLegacyDefault.getMatchMapping(match, bracketData, bracketType, LowerHeader)
	end

	bracketData['hideRoundTitles'] = 'hideroundtitles'

	-- add reference for map mappings
	bracketData['$$map'] = {
		['$notEmpty$'] = 'map$1$',
		map = 'map$1$',
		mode = 'map$1$mode',
		winner = 'map$1$win',
		civs1 = 'map$1$p1civ',
		civs2 = 'map$1$p2civ',
		vod = 'vodgame$1$',
		date = 'date$1$',
	}

	if bracketType == 'team' then
		-- Original input happens as |matchX={{MatchTeam|...}}
		-- and is already flattened in BracketMatchSummary
		bracketData['$$map'] = {
			['$notEmpty$'] = 'match$1$map',
			map = 'match$1$map',
			mode = 'match$1$mapmode',
			winner = 'match$1$win',
			players1 = 'match$1$t1players',
			players2 = 'match$1$t2players',
			civs1 = 'match$1$t1civs',
			civs2 = 'match$1$t2civs',
			vod = 'vodgame$1$',
			date = 'date$1$',
		}
	end

	for n=1,lastround do
		bracketData['R' .. n .. 'M1header'] = 'R' .. n
		if LowerHeader[n] then
			bracketData['R' .. n .. 'M' .. LowerHeader[n] .. 'header'] = 'L' .. n
		end
	end

	return bracketData
end

local lastRound
function MatchGroupLegacyDefault.getMatchMapping(match, bracketData, bracketType, LowerHeader)
	local id = String.split(match.match2id, '_')[2] or match.match2id
	id = id:gsub('0*([1-9])', '%1'):gsub('%-', '')
	local bd = match.match2bracketdata

	local roundNum
	local round
	local reset = false
	if id == 'RxMTP' then
		round = lastRound
	elseif id == 'RxMBR' then
		round = lastRound
		round.G = round.G - 2
		round.W = round.W - 2
		round.D = round.D - 2
		reset = true
	else
		roundNum = id:match('R%d*'):gsub('R', '')
		roundNum = tonumber(roundNum)
		round = _roundData[roundNum] or { R = roundNum, G = 0, D = 1, W = 1 }
	end
	round.G = round.G + 1

	if string.match(bd.header or '', '^!l') then
		LowerHeader[roundNum or ''] = round.G
	end

	local readOpponent = function(prefix)
		return {
			['type'] = 'type',
			prefix,
			template = prefix .. 'team',
			p1flag = prefix .. 'flag',
			p1link = prefix .. 'link',
			score = prefix .. 'score' .. (reset and '2' or ''),
			win = prefix .. 'win',
			['$notEmpty$'] = bracketType == 'team' and (prefix .. 'team') or prefix,
		}
	end

	local opponents = {}
	local finished = {}
	for opponentIndex = 1, MAX_NUM_OPPONENTS do
		local prefix
		if not reset and
			(Logic.isEmpty(bd.toupper) and opponentIndex == 1 or
			Logic.isEmpty(bd.tolower) and opponentIndex == 2) then

			prefix = 'R' .. round.R .. 'D' .. round.D
			round.D = round.D + 1
		else
			prefix = 'R' .. round.R .. 'W' .. round.W
			round.W = round.W + 1
		end

		opponents[opponentIndex] = readOpponent(prefix)
		finished[opponentIndex] = prefix .. 'win'
	end

	match = {
		opponent1 = opponents[1],
		opponent2 = opponents[2],
		finished = finished[1] .. '|' .. finished[2],
		-- reference to variables that shall be flattened
		['$flatten$'] = {reset and 'resetDetails' or ('R' .. round.R .. 'G' .. round.G .. 'details')}
	}

	bracketData[id] = MatchGroupLegacyDefault.addMaps(match)
	lastRound = round
	_roundData[round.R] = round

	return bracketData, round.R, LowerHeader
end

--[[
custom mappings are used to overwrite the default mappings
in the cases where the default mappings do not fit the
parameter format of the old bracket
]]--

--this can be used for custom mappings too
function MatchGroupLegacyDefault.addMaps(match)
	for mapIndex = 1, MAX_NUM_MAPS do
		match['map' .. mapIndex] = {
			['$ref$'] = 'map',
			['$1$'] = mapIndex,
		}
	end
	return match
end

--this is for custom mappings
---@param data {opp1: string, opp2: string, details: string}
---@param bracketType string
---@return table
function MatchGroupLegacyDefault.matchMappingFromCustom(data, bracketType)
	--data has the form {opp1, opp2, details}

	local readOpponent = function(prefix)
		return {
			['type'] = 'type',
			['$notEmpty$'] = bracketType == 'team' and (prefix .. 'team') or prefix,
			prefix,
			template = prefix .. 'team',
			p1flag = prefix .. 'flag',
			p1link = prefix .. 'link',
			score = prefix .. 'score',
			win = prefix .. 'win',
		}
	end

	local mapping = {
		['$flatten$'] = {data.details .. 'details'},
		['finished'] = data.opp1 .. 'win|' .. data.opp2 .. 'win',
		opponent1 = readOpponent(data.opp1),
		opponent2 = readOpponent(data.opp2),
	}
	mapping = MatchGroupLegacyDefault.addMaps(mapping)

	return mapping
end

--this is for custom mappings for Reset finals matches
--it switches score2 into the place of score
--and sets flatten to nil
function MatchGroupLegacyDefault.matchResetMappingFromCustom(mapping)
	local mappingReset = mw.clone(mapping)
	mappingReset.opponent1.score = mapping.opponent1.score .. '2'
	mappingReset.opponent2.score = mapping.opponent2.score .. '2'
	mappingReset['$flatten$'] = nil
	return mappingReset
end

return MatchGroupLegacyDefault
