-- Author: IB_U_Z_Z_A_R_Dl
-- Description: Plugin for GTA V Session Sniffer project on GitHub.
-- Allows you to automatically have every usernames showing up on GTA V Session Sniffer project, by logging all players from your sessions to "Cherax\Lua\GTA_V_Session_Sniffer-plugin\log.txt".
-- GitHub Repository: https://github.com/Illegal-Services/GTA_V_Session_Sniffer-plugin-Cherax-Lua

-- DISCLAIMER:
-- Cherax API is trash, I've no idea how to create these things because Lua repos are closed-source so impossible for me to code them:
-- create_tick_handler() OR threads where we can use yield() inside.
----- I've created a dummy toogle option in "Lua Content" tab literally only for that purpose, it makes literally no sense but wathever.
-- event listeners (eCallbackTrigger.OnPlayerLeave) how tf am I supposed to use that?? no examples. I get how to assign it to a Feature but how about literally any thread/function? lol
----- I've removed a part of the code using that cuz I simply cannot magically find out how to code it.

-- Globals START
---- Global variables START
local player_join__timestamps = {}
---- Global variables END

---- Global constants START
local SCRIPT_NAME <const> = "GTA_V_Session_Sniffer-plugin.lua"
local SCRIPT_TITLE <const> = "GTA V Session Sniffer"
local SCRIPT_LOG__PATH <const> = FileMgr.GetMenuRootPath() .. "\\Lua\\GTA_V_Session_Sniffer-plugin\\log.txt"
local NATIVES <const> = {
    --[[
    Scrapped from: https://alloc8or.re/gta5/nativedb/

    This is up-to-date for b3351
    ]]
    NETWORK_IS_SESSION_STARTED = 0x9DE624D2FC4B603F
}
---- Global constants END

---- Global functions START
-- Function to escape special characters in a string for Lua patterns
local function escape_magic_characters(string)
    local matches = {
        ["^"] = "%^",
        ["$"] = "%$",
        ["("] = "%(",
        [")"] = "%)",
        ["%"] = "%%",
        ["."] = "%.",
        ["["] = "%[",
        ["]"] = "%]",
        ["*"] = "%*",
        ["+"] = "%+",
        ["-"] = "%-",
        ["?"] = "%?"
    }
    return (string:gsub(".", matches))
end

function is_file_string_need_newline_ending(str)
    if #str == 0 then
        return false
    end

    return str:sub(-1) ~= "\n"
end

function read_file(file_path)
    local file, err = io.open(file_path, "r")
    if err then
        return nil, err
    end

    local content = file:read("*a")

    file:close()

    return content, nil
end

local function handle_script_exit(params)
    params = params or {}
    if params.hasScriptCrashed == nil then
        params.hasScriptCrashed = false
    end

    if params.hasScriptCrashed then
        GUI.AddToast(SCRIPT_TITLE, "Oh no... Script crashed:(\nYou gotta restart it manually.", 10000)
    end

    SetShouldUnload()
end

local function create_empty_file(filepath)
    -- Extract the directory part from the filepath
    local dir = filepath:match("^(.*)[/\\]") -- Match up to the last slash or backslash

    if dir then
        -- Create only the directory
        FileMgr.CreateDir(dir)
    end

    -- Create the file
    local file, err = io.open(filepath, "w")
    if err then
        handle_script_exit({ hasScriptCrashed = true })
        return
    end

    file:close()
end
---- Global functions END
-- Globals END


-- === Main Menu Features === --
local function loggerPreTask(player_entries_to_log, log__content, currentTimestamp, playerID, playerSCID, playerName, playerIP)
    if not player_join__timestamps[playerID] then
        player_join__timestamps[playerID] = Time.GetEpoche()
    end

    if (
        not playerSCID
        or not playerName
        or not playerIP
        or playerIP == "255.255.255.255"
    ) then
        return
    end

    local entry_pattern = string.format("user:(%s), scid:(%d), ip:(%s), timestamp:(%%d+)", escape_magic_characters(playerName), playerSCID, escape_magic_characters(playerIP))
    if
        not log__content:find("^" .. entry_pattern)
        and not log__content:find("\n" .. entry_pattern)
    then
        table.insert(player_entries_to_log, string.format("user:%s, scid:%d, ip:%s, timestamp:%d", playerName, playerSCID, playerIP, currentTimestamp))
    end
end

local function write_to_log_file(player_entries_to_log)
    if not FileMgr.DoesFileExist(SCRIPT_LOG__PATH) then
        create_empty_file(SCRIPT_LOG__PATH)
    end

    local log_file, err = io.open(SCRIPT_LOG__PATH, "a")
    if err then
        handle_script_exit({ hasScriptCrashed = true })
        return
    end

    local combined_entries = table.concat(player_entries_to_log, "\n")
    log_file:write(combined_entries .. "\n")
    log_file:close()
end


SessionSnifferLogging_Feat = FeatureMgr.AddFeature(Utils.Joaat("SessionSnifferLogging"), "Toggle Session Sniffer Logging", eFeatureType.Toggle, "Toggle Session Sniffer Logging", function()
    if FeatureMgr.IsFeatureToggled(Utils.Joaat("SessionSnifferLogging")) then
        if not FileMgr.DoesFileExist(SCRIPT_LOG__PATH) then
            create_empty_file(SCRIPT_LOG__PATH)
        end

        local log__content, err = read_file(SCRIPT_LOG__PATH)
        if err then
            handle_script_exit({ hasScriptCrashed = true })
            return
        end

        if is_file_string_need_newline_ending(log__content) then
            local file, err = io.open(SCRIPT_LOG__PATH, "a")
            if err then
                handle_script_exit({ hasScriptCrashed = true })
                return
            end

            file:write("\n")
            file:close()
        end

        if Natives.InvokeBool(NATIVES.NETWORK_IS_SESSION_STARTED) then
            local player_entries_to_log = {}
            local currentTimestamp = Time.GetEpoche()
            for _, playerID in pairs(Players.Get()) do
                -- Getting the player SCID and IP in Cherax is cringe
                local CNetGamePlayer = Players.GetById(playerID)
                if CNetGamePlayer then
                    local GamerInfo = CNetGamePlayer:GetGamerInfo()
                    if GamerInfo then
                        if GamerInfo.RockstarId then
                            local playerSCID = GamerInfo.RockstarId
                            local playerName = Players.GetName(playerID)
                            local playerIPString = Players.GetIPString(playerID)
                            local playerIP
                            if playerIPString then
                                playerIP = playerIPString:match("^(%d+%.%d+%.%d+%.%d+) %(Direct%)") -- Cherax API is really cringe
                            end

                            loggerPreTask(player_entries_to_log, log__content, currentTimestamp, playerID, playerSCID, playerName, playerIP)
                        end
                    end
                end
            end

            if #player_entries_to_log > 0 then
                write_to_log_file(player_entries_to_log)
            end

        else
            player_join__timestamps = {}
        end
    end
end)

ClickGUI.AddTab(SCRIPT_TITLE, function()
	if ClickGUI.BeginCustomChildWindow("Session Sniffer Logging") then
    	ClickGUI.RenderFeature(Utils.Joaat("SessionSnifferLogging"))
		ClickGUI.EndCustomChildWindow()
	end
end)


-- === Main Loop === --
SessionSnifferLogging_Feat:RegisterCallbackTrigger(eCallbackTrigger.OnTick)
