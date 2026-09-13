--[[
	veteran
	product UI library — splash, top bar, themes, environment, watermark,
	configurations window, keybinds

	Loaded by VeteranLoader.lua (or example_uni_merge.lua).
	Do not inject this file on its own.
]]

-- false = leave Roblox chat / backpack / players / emotes / Unibar alone
-- unless an owner/dev turns on rewrite in themes. veteran never get it.
-- rewrite on: 3-lines opens the veteran tray.
-- rewrite off: Roblox topbar stays hidden until the 3-lines is pressed.
local CoreGui_Redesign = false

local tween_service = game:GetService("TweenService")
local starter_gui = game:GetService("StarterGui")
local core_gui = game:GetService("CoreGui")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local uis = game:GetService("UserInputService")
local gui_service = game:GetService("GuiService")
local http_service = game:GetService("HttpService")
local teleport_service = game:GetService("TeleportService")
local run_service = game:GetService("RunService")
local stats_service = game:GetService("Stats")
local text_chat = game:GetService("TextChatService")
local replicated_storage = game:GetService("ReplicatedStorage")

local theme = {
	Accent = Color3.fromRGB(132, 120, 148),
	["Window Background"] = Color3.fromRGB(30, 30, 30),
	["Window Border"] = Color3.fromRGB(45, 45, 45),
	["Tab Background"] = Color3.fromRGB(20, 20, 20),
	["Tab Border"] = Color3.fromRGB(45, 45, 45),
	["Tab Toggle Background"] = Color3.fromRGB(28, 28, 28),
	["Section Background"] = Color3.fromRGB(18, 18, 18),
	["Section Border"] = Color3.fromRGB(35, 35, 35),
	["Text"] = Color3.fromRGB(200, 200, 200),
	["Disabled Text"] = Color3.fromRGB(110, 110, 110),
	["Object Background"] = Color3.fromRGB(25, 25, 25),
	["Object Border"] = Color3.fromRGB(35, 35, 35),
	["Dropdown Option Background"] = Color3.fromRGB(19, 19, 19),
}

local BAR_HEIGHT = 34
local INFO_WIDTH = 320
local TEXT_SIZE = 14
local TITLE_SIZE = 15
local TAB_SIZE = 16
local ROW_H = 18
local BOX = 12
local TWEEN = 0.14
local VERSION = "1.3.0"

-- Flags keep underscores. Visible labels never do.
local function display_name(name, flag, fallback)
	local text
	if type(name) == "string" then
		text = name
	elseif type(flag) == "string" and flag ~= "" then
		text = flag
	else
		text = fallback or ""
	end
	return (string.gsub(text, "_", " "))
end

local function bind_tab(section)
	return (section.page and section.page.name) or "main"
end

local veteran = {
	name = "veteran",
	version = VERSION,
	changelog = {},
	theme = theme,
	accent = theme.Accent,
	connections = {},
	gui = nil,
	topbar = nil,
	topbar_holder = nil,
	themes_panel = nil,
	environment_panel = nil,
	preview_panel = nil,
	watermark_panel = nil,
	watermark = nil,
	config_window = nil,
	staff_panel = nil,
	report_panel = nil,
	picker = nil,
	theme_name = "current",
	theme_autoload = false,
	open_tabs = {},
	_front_z = 50,
	relations = {},
	veteran_ids = {},
	player_rows = {},
	booted = false,
	hidden_guis = {},
	feature_map = {},
	_coregui_rewrite = false,
	layout = {
		hotbar_size = 36,
		hotbar_spacing = 5,
		topbar_autohide = false,
		hide_fullscreen_exit = true,
	},
	layout_packs = {},
}

if getgenv().veteran and getgenv().veteran.unload then
	pcall(function()
		getgenv().veteran:unload()
	end)
end
if getgenv().veteran and getgenv().veteran.unload and getgenv().veteran ~= getgenv().veteran then
	pcall(function()
		getgenv().veteran:unload()
	end)
end

local THEME_KEYS = {
	"Accent",
	"Window Background",
	"Window Border",
	"Tab Background",
	"Tab Border",
	"Tab Toggle Background",
	"Section Background",
	"Section Border",
	"Text",
	"Disabled Text",
	"Object Background",
	"Object Border",
	"Dropdown Option Background",
}

local DEFAULT_THEME = {}
for _, key in ipairs(THEME_KEYS) do
	DEFAULT_THEME[key] = theme[key]
end

local LAYOUT_DEFAULTS = {
	hotbar_size = 36,
	hotbar_spacing = 5,
	topbar_autohide = false,
	hide_fullscreen_exit = true,
}
local LAYOUT_MIN = 1
local LAYOUT_MAX = 100
local LAYOUT_STEP = 0.01

local ROOT_DIR = "veteran"
local THEME_DIR = "veteran/themes/"
local CONFIG_DIR = "veteran/configs/"
local RELATION_FILE = "veteran/environment.json"
local REWRITE_FILE = "veteran/coregui_rewrite.txt"

-- Forced roles. Not settable from Environment — only these ids.
local OWNER_IDS = {
	[3514759344] = true, -- amtrue1z
}

local DEV_IDS = {
}

local NATIVE_CORE_TYPES = {
	chat = Enum.CoreGuiType.Chat,
	backpack = Enum.CoreGuiType.Backpack,
	players = Enum.CoreGuiType.PlayerList,
	emotes = Enum.CoreGuiType.EmotesMenu,
}

local theme_binds = {}
local theme_swatches = {}

local function clock_text()
	local date_text, time_text
	local ok = pcall(function()
		date_text = os.date("%m/%d/%Y")
		time_text = os.date("%H:%M:%S")
	end)
	if ok and type(date_text) == "string" and type(time_text) == "string" then
		return date_text, time_text
	end

	ok = pcall(function()
		local now = DateTime.now()
		date_text = now:FormatLocalTime("MM/dd/yyyy", "en-us")
		time_text = now:FormatLocalTime("HH:mm:ss", "en-us")
	end)
	if ok and date_text and time_text then
		return date_text, time_text
	end

	return "--/--/----", "--:--:--"
end

local function env_table()
	return (getgenv and getgenv()) or _G
end

function veteran:apply_session()
	local env = env_table()
	local session = env.veteran_session
	if type(session) ~= "table" then
		session = {}
	end
	local key = session.key or env.script_key
	if type(key) == "string" and key ~= "" then
		self.script_key = key
		session.key = key
	end
	local license_id = tonumber(session.user_id or session.id or session.license_id)
	if license_id then
		self.license_id = license_id
		self.user_id = license_id
		session.user_id = license_id
		session.id = license_id
	elseif not self.user_id then
		self.user_id = self:local_user_id()
	end
	local role = session.role
	if role ~= "owner" and role ~= "dev" and role ~= "veteran" then
		role = session.owner == true and "owner" or "veteran"
	end
	self._session_role = role
	self._session_owner = role == "owner"
	self._session_dev = role == "dev" or role == "owner"
	session.role = role
	session.owner = self._session_owner
	session.dev = self._session_dev
	env.veteran_session = session
	if self.script_key then
		env.script_key = self.script_key
	end
	self:refresh_info_license()
	return session
end

function veteran:local_user_id()
	local lp = players.LocalPlayer
	if lp then
		return lp.UserId
	end
	return self.license_id
end

function veteran:is_owner()
	if self._session_owner then
		return true
	end
	local id = tonumber(self:local_user_id())
	if id and OWNER_IDS[id] then
		return true
	end
	return false
end

function veteran:is_dev()
	if self._session_dev or self:is_owner() then
		return true
	end
	local id = tonumber(self:local_user_id())
	if id and DEV_IDS[id] then
		return true
	end
	return false
end

function veteran:license_role()
	if self._session_role == "owner" or self._session_role == "dev" or self._session_role == "veteran" then
		return self._session_role
	end
	if self:is_owner() then
		return "owner"
	end
	if self:is_dev() then
		return "dev"
	end
	return "veteran"
end

function veteran:can_staff_panel()
	return self:is_dev()
end

local GATE_FALLBACK = "https://xjzrdbnwxdxtirmiowtd.supabase.co/functions/v1"
local SUPABASE_ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhqenJkYm53eGR4dGlybWlvd3RkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwNDg2MjQsImV4cCI6MjEwNDYyNDYyNH0.MVmTZ9wsNfm2huAtbm8JEsUNI7XqCRXl1Woov1ujM7c"

local REPORT_OPTIONS = {
	"request game support",
	"report another veteran",
	"request assistance from dev / owner",
}

local REPORT_KIND = {
	["request game support"] = "game_support",
	["report another veteran"] = "report_veteran",
	["request assistance from dev / owner"] = "dev_assist",
}

local function gate_url()
	local env = env_table()
	local gate = env.veteran_gate
	if type(gate) == "string" and gate ~= "" then
		return gate
	end
	return GATE_FALLBACK
end

local function first_fn(...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "function" then
			return value
		end
	end
	return nil
end

local function resolve_request()
	local env = env_table()
	local syn = env.syn
	local http = env.http
	local flux = env.fluxus
	local krnl = env.krnl
	return first_fn(
		type(syn) == "table" and syn.request,
		type(syn) == "table" and syn.http_request,
		env.http_request,
		env.request,
		type(http) == "table" and (http.request or http.Request),
		type(flux) == "table" and flux.request,
		type(krnl) == "table" and krnl.request
	)
end

local function normalize_http(response)
	if type(response) == "string" then
		return { StatusCode = 200, Body = response }
	end
	if type(response) ~= "table" then
		return nil
	end
	local status = response.StatusCode or response.Status or response.status_code or response.status or 200
	local body = response.Body or response.body
	if type(body) ~= "string" then
		body = body == nil and "" or tostring(body)
	end
	return { StatusCode = tonumber(status) or 200, Body = body }
end

function veteran:http_json(method, url, body)
	local payload = body and http_service:JSONEncode(body) or nil
	local headers = {
		apikey = SUPABASE_ANON,
		Authorization = "Bearer " .. SUPABASE_ANON,
		["Content-Type"] = "application/json",
	}
	method = string.upper(tostring(method or "GET"))
	local request_fn = resolve_request()
	if request_fn then
		local specs = {
			{ Url = url, Method = method, Headers = headers, Body = payload },
			{ url = url, method = method, headers = headers, body = payload },
		}
		for _, spec in ipairs(specs) do
			local ok, response = pcall(request_fn, spec)
			if ok then
				local normalized = normalize_http(response)
				if normalized then
					return normalized
				end
			end
		end
	end
	if method == "POST" and payload then
		local tries = {
			function()
				return game:HttpPost(url, payload, "application/json")
			end,
			function()
				return game:HttpPostAsync(url, payload, "application/json")
			end,
		}
		for _, fn in ipairs(tries) do
			local ok, result = pcall(fn)
			if ok and result ~= nil then
				return normalize_http(result)
			end
		end
	end
	return nil, "no http request"
end

function veteran:ops_payload(action, extra)
	local lp = players.LocalPlayer
	local payload = {
		key = self.script_key,
		username = lp and lp.Name or "",
		user_id = self:local_user_id(),
		place_id = game.PlaceId,
		job_id = tostring(game.JobId),
		action = action,
	}
	if type(extra) == "table" then
		for name, value in pairs(extra) do
			payload[name] = value
		end
	end
	return payload
end

function veteran:ops(action, extra)
	local key = self.script_key
	if type(key) ~= "string" or key == "" then
		return nil, "missing key"
	end
	local response, err = self:http_json("POST", gate_url() .. "/veteran-ops", self:ops_payload(action, extra))
	if not response then
		return nil, err or "request failed"
	end
	local ok, decoded = pcall(function()
		return http_service:JSONDecode(response.Body)
	end)
	if not ok or type(decoded) ~= "table" then
		return nil, "bad response"
	end
	decoded._status = response.StatusCode
	return decoded
end

local function format_cooldown(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	if seconds <= 0 then
		return "ready"
	end
	return string.format("cooldown %d:%02d", math.floor(seconds / 60), seconds % 60)
end

function veteran:can_coregui_rewrite()
	return self:is_dev()
end

function veteran:wants_coregui_redesign()
	if not self:can_coregui_rewrite() then
		return false
	end
	if CoreGui_Redesign then
		return true
	end
	return self._coregui_rewrite == true
end

function veteran:load_rewrite_pref()
	local ok, body = self:fs("readfile", REWRITE_FILE)
	if ok and type(body) == "string" then
		local text = string.lower((body:gsub("%s+", "")))
		if text == "1" or text == "true" then
			self._coregui_rewrite = true
			return
		end
		if text == "0" or text == "false" then
			self._coregui_rewrite = false
			return
		end
	end
	self._coregui_rewrite = false
end

function veteran:save_rewrite_pref()
	self:ensure_theme_dir()
	self:fs("writefile", REWRITE_FILE, self._coregui_rewrite and "true" or "false")
end

function veteran:set_coregui_rewrite(on)
	if not self:can_coregui_rewrite() then
		on = false
	end
	on = on and true or false
	if self._coregui_rewrite ~= on then
		self._coregui_rewrite = on
		self:save_rewrite_pref()
	end
	self:apply_coregui_rewrite()
end

function veteran:ensure_coregui_rewrite_ui()
	if self._rewrite_ui_built then
		return
	end
	self._rewrite_ui_built = true
	self:build_chat_panel()
	self:build_backpack_panel()
	self:build_hotbar()
	self:build_players_panel()
	self:build_emotes_panel()
end

function veteran:reset_utilities()
	self.utility_open = {}
	for _, name in ipairs({ "chat", "backpack", "players", "emotes" }) do
		local panel = self.utility_panels and self.utility_panels[name]
		if panel then
			self:set_window_open(panel, false)
		end
	end
	self:refresh_left_chrome()
end

function veteran:hide_coregui_rewrite_ui()
	self:reset_utilities()
	if self.hotbar then
		self.hotbar.Visible = false
	end
end

function veteran:apply_coregui_rewrite()
	if not self.gui then
		self:refresh_left_chrome()
		return
	end
	if self:wants_coregui_redesign() then
		self._roblox_bar_open = false
		self._roblox_menu_open = false
		self:lift_roblox_chrome(false)
		self:ensure_coregui_rewrite_ui()
		self:reset_utilities()
		if self.hotbar then
			self.hotbar.Visible = true
		end
		self:hide_roblox_topbar(true)
	else
		self:set_chrome_menu_open(false)
		self:hide_coregui_rewrite_ui()
		self._roblox_bar_open = false
		self._roblox_menu_open = false
		self:lift_roblox_chrome(false)
		if self._topbar_hide then
			self:restore_roblox_topbar()
		end
		self:hide_roblox_topbar(false)
		self:sync_native_tray()
	end
	self:refresh_left_chrome()
	if self.rewrite_toggle and self.rewrite_toggle.refresh then
		self.rewrite_toggle.refresh(true)
	end
end

function veteran:create(class_name, props)
	local key = props.Theme
	local prop = props.ThemeProp
	local border_key = props.ThemeBorder
	local text_key = props.ThemeText
	props.Theme = nil
	props.ThemeProp = nil
	props.ThemeBorder = nil
	props.ThemeText = nil
	if key and prop and theme[key] then
		props[prop] = theme[key]
	end
	if border_key and theme[border_key] then
		props.BorderColor3 = theme[border_key]
	end
	if text_key and theme[text_key] then
		props.TextColor3 = theme[text_key]
	end
	local inst = Instance.new(class_name)
	for name, value in next, props do
		inst[name] = value
	end
	if key and prop then
		self:bind_theme(inst, key, prop)
	end
	if border_key then
		self:bind_theme(inst, border_key, "BorderColor3")
	end
	if text_key then
		self:bind_theme(inst, text_key, "TextColor3")
	end
	return inst
end

function veteran:bind_theme(inst, key, prop)
	theme_binds[key] = theme_binds[key] or {}
	table.insert(theme_binds[key], { inst = inst, prop = prop })
end

local function rgb_string(color)
	return string.format(
		"%d, %d, %d",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function color_from_rgb_table(value)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) ~= "table" then
		return nil
	end
	local r = value[1] or value.r or value.R
	local g = value[2] or value.g or value.G
	local b = value[3] or value.b or value.B
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return nil
	end
	if r <= 1 and g <= 1 and b <= 1 then
		return Color3.new(r, g, b)
	end
	return Color3.fromRGB(r, g, b)
end

local function rgb_table_from(color)
	if typeof(color) == "Color3" then
		return {
			math.floor(color.R * 255 + 0.5),
			math.floor(color.G * 255 + 0.5),
			math.floor(color.B * 255 + 0.5),
		}
	end
	if type(color) == "table" then
		return {
			tonumber(color[1]) or tonumber(color.r) or 255,
			tonumber(color[2]) or tonumber(color.g) or 255,
			tonumber(color[3]) or tonumber(color.b) or 255,
		}
	end
	return { 255, 255, 255 }
end

local function lighten(color, amount)
	return Color3.new(
		math.clamp(color.R + amount, 0, 1),
		math.clamp(color.G + amount, 0, 1),
		math.clamp(color.B + amount, 0, 1)
	)
end

function veteran:refresh_tabs()
	for tab_name, pack in pairs(self.tab_buttons or {}) do
		local on = self.open_tabs and self.open_tabs[tab_name] == true
		pack.button.BackgroundColor3 = on and theme["Tab Toggle Background"] or theme["Tab Background"]
		pack.label.TextColor3 = on and theme.Text or theme["Disabled Text"]
		if pack.accent then
			pack.accent.Visible = true
			self:tween(pack.accent, {
				Size = on and UDim2.new(1, 0, 0, 1) or UDim2.new(0, 0, 0, 1),
			}, 0.14)
		end
	end
end

function veteran:bring_front(panel)
	if not panel then
		return
	end
	self._front_z = (self._front_z or 50) + 1
	panel.ZIndex = self._front_z
end

function veteran:set_window_open(panel, open)
	if not panel then
		return
	end
	if panel == self.info_panel then
		self:set_info_open(open)
		return
	end
	if open then
		panel.Visible = true
		self:bring_front(panel)
		local scale = panel:FindFirstChild("veterancale")
		if not scale then
			scale = self:create("UIScale", {
				Parent = panel,
				Name = "veterancale",
				Scale = 1,
			})
		end
		scale.Scale = 0.96
		self:tween(scale, { Scale = 1 }, 0.14)
	else
		panel.Visible = false
	end
end

function veteran:tab_panel(name)
	if name == "info" then
		return self.info_panel
	end
	if name == "Themes" then
		return self.themes_panel
	end
	if name == "Environment" then
		return self.environment_panel
	end
	if name == "Previews" then
		return self.preview_panel
	end
	if name == "Watermark" then
		return self.watermark_panel
	end
	if name == "Configurations" then
		return self.config_panel
	end
	if name == "Keybinds" then
		return self.keybinds_panel
	end
	if name == "panel" then
		return self.staff_panel
	end
	return nil
end

function veteran:animate_button(btn, get_base)
	if not btn then
		return btn
	end
	local hovering = false
	local pressing = false

	local function rest_color()
		if type(get_base) == "function" then
			return get_base()
		end
		return get_base or theme["Object Background"]
	end

	local function apply()
		local color = rest_color()
		if pressing then
			self:tween(btn, { BackgroundColor3 = lighten(color, -0.05) }, 0.08)
		elseif hovering then
			self:tween(btn, { BackgroundColor3 = lighten(color, 0.07) }, 0.12)
		else
			self:tween(btn, { BackgroundColor3 = color }, 0.12)
		end
	end

	self:connect(btn.MouseEnter, function()
		hovering = true
		apply()
	end)
	self:connect(btn.MouseLeave, function()
		hovering = false
		pressing = false
		apply()
	end)
	self:connect(btn.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressing = true
			apply()
		end
	end)
	self:connect(btn.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressing = false
			apply()
		end
	end)

	return btn
end

function veteran:set_theme(key, color)
	if not theme[key] or typeof(color) ~= "Color3" then
		return
	end
	theme[key] = color
	if key == "Accent" then
		self.accent = color
	end
	local list = theme_binds[key]
	if list then
		for i = #list, 1, -1 do
			local bind = list[i]
			if bind.inst and bind.inst.Parent then
				bind.inst[bind.prop] = color
			else
				table.remove(list, i)
			end
		end
	end
	local swatch = theme_swatches[key]
	if swatch then
		if swatch.fill then
			swatch.fill.BackgroundColor3 = color
		end
		if swatch.rgb then
			swatch.rgb.Text = rgb_string(color)
		end
	end
	if key == "Tab Background" or key == "Tab Toggle Background" or key == "Text" or key == "Disabled Text" then
		self:refresh_tabs()
	end
	if key == "Accent" or key == "Object Background" or key == "Text" or key == "Disabled Text" or key == "Object Border" then
		self:refresh_autoload_toggle()
		self:refresh_environment_colors()
		self:refresh_watermark()
		self:refresh_option_packs()
		self:refresh_left_chrome()
	end
	self:queue_theme_save()
end

function veteran:fs(name, ...)
	local fn
	pcall(function()
		fn = getgenv()[name]
	end)
	if type(fn) ~= "function" then
		fn = _G[name]
	end
	if type(fn) ~= "function" then
		return false
	end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		return false
	end
	return true, a, b
end

function veteran:ensure_theme_dir()
	self:fs("makefolder", ROOT_DIR)
	self:fs("makefolder", THEME_DIR)
	self:fs("makefolder", CONFIG_DIR)
end

function veteran:theme_path(name)
	name = tostring(name or "current"):gsub("[^%w%-%._ ]", "")
	if name == "" then
		name = "current"
	end
	return THEME_DIR .. name .. ".json"
end

function veteran:serialize_theme()
	local payload = {}
	for _, key in ipairs(THEME_KEYS) do
		local color = theme[key]
		payload[key] = {
			math.floor(color.R * 255 + 0.5),
			math.floor(color.G * 255 + 0.5),
			math.floor(color.B * 255 + 0.5),
		}
	end
	payload.layout = {}
	for key, fallback in pairs(LAYOUT_DEFAULTS) do
		payload.layout[key] = self:layout_value(key)
	end
	return http_service:JSONEncode(payload)
end

function veteran:layout_value(key)
	local fallback = LAYOUT_DEFAULTS[key]
	if fallback == nil then
		fallback = LAYOUT_MIN
	end
	local value = self.layout and self.layout[key]
	if type(fallback) == "boolean" then
		if value == nil then
			return fallback
		end
		if type(value) == "number" then
			return value ~= 0
		end
		return value and true or false
	end
	value = tonumber(value) or fallback
	value = math.clamp(value, LAYOUT_MIN, LAYOUT_MAX)
	return math.floor(value / LAYOUT_STEP + 0.5) * LAYOUT_STEP
end

function veteran:set_layout(key, value)
	if LAYOUT_DEFAULTS[key] == nil then
		return
	end
	self.layout = self.layout or {}
	if type(LAYOUT_DEFAULTS[key]) == "boolean" then
		if type(value) == "number" then
			value = value ~= 0
		end
		self.layout[key] = value and true or false
	else
		value = tonumber(value) or LAYOUT_DEFAULTS[key]
		value = math.clamp(value, LAYOUT_MIN, LAYOUT_MAX)
		value = math.floor(value / LAYOUT_STEP + 0.5) * LAYOUT_STEP
		self.layout[key] = value
	end
	local packs = self.layout_packs and self.layout_packs[key]
	if packs then
		if packs.refresh then
			packs.refresh(true)
		else
			for _, pack in ipairs(packs) do
				if pack.refresh then
					pack.refresh(true)
				end
			end
		end
	end
	if key == "hotbar_size" or key == "hotbar_spacing" then
		self:apply_hotbar_layout()
	elseif key == "topbar_autohide" then
		self:apply_topbar_autohide()
	elseif key == "hide_fullscreen_exit" then
		self:apply_fullscreen_title()
	end
	if not self._theme_lock then
		self:queue_theme_save()
	end
end

function veteran:bind_layout_pack(key, pack)
	self.layout_packs = self.layout_packs or {}
	local current = self.layout_packs[key]
	if type(current) == "table" and current.refresh then
		self.layout_packs[key] = { current }
	elseif type(current) ~= "table" then
		self.layout_packs[key] = {}
	end
	table.insert(self.layout_packs[key], pack)
end

function veteran:make_layout_sliders(parent)
	local size_pack = self:make_slider(parent, {
		name = "box size",
		layout_order = 1,
		min = LAYOUT_MIN,
		max = LAYOUT_MAX,
		interval = LAYOUT_STEP,
		get = function()
			return self:layout_value("hotbar_size")
		end,
		set = function(value)
			self:set_layout("hotbar_size", value)
		end,
	})
	local gap_pack = self:make_slider(parent, {
		name = "spacing",
		layout_order = 2,
		min = LAYOUT_MIN,
		max = LAYOUT_MAX,
		interval = LAYOUT_STEP,
		get = function()
			return self:layout_value("hotbar_spacing")
		end,
		set = function(value)
			self:set_layout("hotbar_spacing", value)
		end,
	})
	self:bind_layout_pack("hotbar_size", size_pack)
	self:bind_layout_pack("hotbar_spacing", gap_pack)
end

function veteran:apply_theme_map(map)
	if type(map) ~= "table" then
		return
	end
	self._theme_lock = true
	for _, key in ipairs(THEME_KEYS) do
		local color = color_from_rgb_table(map[key])
		if color then
			self:set_theme(key, color)
		end
	end
	if type(map.layout) == "table" then
		for key in pairs(LAYOUT_DEFAULTS) do
			if map.layout[key] ~= nil then
				self:set_layout(key, map.layout[key])
			end
		end
	end
	self._theme_lock = false
end

function veteran:write_theme_file(name)
	self:ensure_theme_dir()
	name = name or self.theme_name or "current"
	self.theme_name = name
	return self:fs("writefile", self:theme_path(name), self:serialize_theme())
end

function veteran:read_theme_file(name)
	local ok, body = self:fs("readfile", self:theme_path(name))
	if not ok or type(body) ~= "string" or body == "" then
		return nil
	end
	local decoded
	local parse_ok = pcall(function()
		decoded = http_service:JSONDecode(body)
	end)
	if parse_ok and type(decoded) == "table" then
		return decoded
	end
	return nil
end

function veteran:load_theme_file(name)
	local map = self:read_theme_file(name)
	if not map then
		return false
	end
	self.theme_name = name
	self:apply_theme_map(map)
	if self.theme_name_box then
		self.theme_name_box.Text = name
	end
	self:refresh_theme_list()
	return true
end

function veteran:delete_theme_file(name)
	self:fs("delfile", self:theme_path(name))
	if self.theme_name == name then
		self.theme_name = "current"
		if self.theme_name_box then
			self.theme_name_box.Text = "current"
		end
	end
	self:refresh_theme_list()
end

function veteran:list_theme_files()
	local names = {}
	local seen = {}
	local ok, files = self:fs("listfiles", THEME_DIR)
	if ok and type(files) == "table" then
		for _, path in ipairs(files) do
			local file_name = tostring(path):match("([^/\\]+)%.json$")
			if file_name and file_name ~= "autoload" and not seen[file_name] then
				seen[file_name] = true
				table.insert(names, file_name)
			end
		end
	end
	table.sort(names)
	if #names == 0 then
		table.insert(names, self.theme_name or "current")
	end
	return names
end

function veteran:set_autoload(name)
	self:ensure_theme_dir()
	if name then
		self.theme_autoload = true
		self.theme_name = name
		self:write_theme_file(name)
		self:fs("writefile", THEME_DIR .. "autoload.txt", name)
	else
		self.theme_autoload = false
		self:fs("delfile", THEME_DIR .. "autoload.txt")
		self:fs("delfile", "veteran/themes/autoload.txt")
	end
	self:refresh_autoload_toggle()
end

function veteran:read_autoload()
	local ok, body = self:fs("readfile", THEME_DIR .. "autoload.txt")
	if not ok or type(body) ~= "string" then
		ok, body = self:fs("readfile", "veteran/themes/autoload.txt")
	end
	if ok and type(body) == "string" then
		body = body:gsub("%s+", "")
		if body ~= "" then
			return body
		end
	end
	return nil
end

function veteran:queue_theme_save()
	if self._theme_lock or not self.theme_autoload then
		return
	end
	self._theme_dirty = true
	if self._theme_save_queued then
		return
	end
	self._theme_save_queued = true
	task.delay(0.35, function()
		self._theme_save_queued = false
		if not self._theme_dirty then
			return
		end
		self._theme_dirty = false
		self:write_theme_file(self.theme_name or "current")
	end)
end

function veteran:reset_theme()
	self._theme_lock = true
	for _, key in ipairs(THEME_KEYS) do
		self:set_theme(key, DEFAULT_THEME[key])
	end
	for key, value in pairs(LAYOUT_DEFAULTS) do
		self:set_layout(key, value)
	end
	self._theme_lock = false
	self:write_theme_file(self.theme_name or "current")
end

function veteran:close_picker()
	if self._picker_conns then
		for _, connection in ipairs(self._picker_conns) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		self._picker_conns = nil
	end
	if self.picker then
		self.picker:Destroy()
		self.picker = nil
	end
	self.picker_key = nil
	self:close_slider_entry()
end

-- AbsolutePosition is GUI space (below GuiInset). GetMouseLocation is
-- screen space and includes that inset, so it reads ~36px too low if
-- used raw. Mouse InputObject.Position is already GUI space — that is
-- what the first picker used, then over-subtracted inset and sat high.
local function gui_mouse(input_obj)
	if input_obj then
		local pos = input_obj.Position
		return pos.X, pos.Y
	end
	local mouse = uis:GetMouseLocation()
	local inset = Vector2.zero
	pcall(function()
		inset = gui_service:GetGuiInset()
	end)
	return mouse.X - inset.X, mouse.Y - inset.Y
end

local function point_in(inst, mx, my)
	if not inst or not inst.Parent then
		return false
	end
	local pos = inst.AbsolutePosition
	local size = inst.AbsoluteSize
	return mx >= pos.X and mx <= pos.X + size.X and my >= pos.Y and my <= pos.Y + size.Y
end

function veteran:open_picker(anchor, spec)
	self:close_dropdown()
	self:close_picker()
	self.picker_key = spec
	self._picker_conns = {}

	local function current()
		if type(spec) == "string" then
			return theme[spec]
		end
		if type(spec) == "table" and spec.get then
			local color = spec.get()
			if typeof(color) == "Color3" then
				return color
			end
			return color_from_rgb_table(color) or theme.Accent
		end
		return theme.Accent
	end

	local function commit(color)
		if type(spec) == "string" then
			self:set_theme(spec, color)
		elseif type(spec) == "table" and spec.set then
			spec.set(color)
		end
	end

	local color = current()
	local h, s, v = color:ToHSV()

	local picker = self:create("Frame", {
		Parent = self.gui,
		Name = "ThemePicker",
		Size = UDim2.fromOffset(168, 158),
		BackgroundColor3 = theme["Window Background"],
		Theme = "Window Background",
		ThemeProp = "BackgroundColor3",
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		ZIndex = 90,
	})
	self.picker = picker
	self:accent_cap(picker, 96)

	local inner = self:create("Frame", {
		Parent = picker,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 91,
	})

	local sat_btn = self:create("TextButton", {
		Parent = inner,
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -46),
		BackgroundColor3 = Color3.fromHSV(h, 1, 1),
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 92,
	})

	local sat_white = self:create("Frame", {
		Parent = sat_btn,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 93,
	})
	self:create("UIGradient", {
		Parent = sat_white,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})

	local sat_black = self:create("Frame", {
		Parent = sat_white,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 94,
	})
	self:create("UIGradient", {
		Parent = sat_black,
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
	})

	local sat_cursor = self:create("Frame", {
		Parent = sat_black,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 1,
		ZIndex = 95,
	})

	local hue_btn = self:create("TextButton", {
		Parent = inner,
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.new(0, 4, 1, -38),
		Size = UDim2.new(1, -8, 0, 10),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 92,
	})
	self:create("UIGradient", {
		Parent = hue_btn,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
	})

	local hue_cursor = self:create("Frame", {
		Parent = hue_btn,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 1,
		ZIndex = 93,
	})

	local input = self:create("TextBox", {
		Parent = inner,
		Position = UDim2.new(0, 4, 1, -24),
		Size = UDim2.new(1, -8, 0, 18),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		ThemeText = "Text",
		BorderSizePixel = 1,
		Font = Enum.Font.SourceSans,
		TextSize = TEXT_SIZE,
		Text = rgb_string(color),
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 92,
	})

	local dragging_sat = false
	local dragging_hue = false

	local function apply_hsv()
		local next_color = Color3.fromHSV(h, s, v)
		sat_btn.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		sat_cursor.Position = UDim2.fromScale(s, 1 - v)
		hue_cursor.Position = UDim2.fromScale(h, 0)
		input.Text = rgb_string(next_color)
		commit(next_color)
	end

	local function sat_input(input_obj)
		local mx, my = gui_mouse(input_obj)
		local abs = sat_btn.AbsolutePosition
		local size = sat_btn.AbsoluteSize
		s = math.clamp((mx - abs.X) / math.max(size.X, 1), 0, 1)
		v = 1 - math.clamp((my - abs.Y) / math.max(size.Y, 1), 0, 1)
		apply_hsv()
	end

	local function hue_input(input_obj)
		local mx, my = gui_mouse(input_obj)
		local abs = hue_btn.AbsolutePosition
		local size = hue_btn.AbsoluteSize
		h = math.clamp((mx - abs.X) / math.max(size.X, 1), 0, 1)
		apply_hsv()
	end

	local function track(connection)
		table.insert(self._picker_conns, connection)
		return connection
	end

	track(sat_btn.InputBegan:Connect(function(input_obj)
		if input_obj.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging_sat = true
			sat_input(input_obj)
		end
	end))
	track(hue_btn.InputBegan:Connect(function(input_obj)
		if input_obj.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging_hue = true
			hue_input(input_obj)
		end
	end))
	track(uis.InputChanged:Connect(function(input_obj)
		if input_obj.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if dragging_sat then
			sat_input(input_obj)
		elseif dragging_hue then
			hue_input(input_obj)
		end
	end))
	track(uis.InputEnded:Connect(function(input_obj)
		if input_obj.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging_sat = false
			dragging_hue = false
		end
	end))
	track(input.FocusLost:Connect(function()
		local values = {}
		for value in string.gmatch(input.Text, "[^,]+") do
			local num = tonumber(value)
			if num then
				table.insert(values, num)
			end
		end
		if #values >= 3 then
			local parsed = Color3.fromRGB(values[1], values[2], values[3])
			h, s, v = parsed:ToHSV()
			apply_hsv()
		else
			input.Text = rgb_string(current())
		end
	end))

	local function place()
		if not anchor or not anchor.Parent then
			return
		end
		local pos = anchor.AbsolutePosition
		local size = anchor.AbsoluteSize
		local x = pos.X
		local y = pos.Y + size.Y + 4
		local camera = workspace.CurrentCamera
		local view = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		if x + 168 > view.X - 8 then
			x = view.X - 176
		end
		if y + 158 > view.Y - 8 then
			y = pos.Y - 162
		end
		picker.Position = UDim2.fromOffset(math.max(8, x), math.max(BAR_HEIGHT + 4, y))
	end
	place()
	apply_hsv()
end

function veteran:mini_button(parent, text, layout_order, callback)
	local btn = self:create("TextButton", {
		Parent = parent,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 18),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = layout_order or 0,
		ZIndex = 56,
	})
	self:create("UIPadding", {
		Parent = btn,
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	self:create("TextLabel", {
		Parent = btn,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Font = Enum.Font.SourceSans,
		Text = text,
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 57,
	})
	self:connect(btn.MouseButton1Click, callback)
	self:animate_button(btn, function()
		return theme["Object Background"]
	end)
	return btn
end

function veteran:ensure_window_drag()
	if self._window_drag_hooked then
		return
	end
	self._window_drag_hooked = true
	self:connect(uis.InputChanged, function(input)
		local job = self._window_drag
		if not job or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local delta = input.Position - job.start_input
		job.frame.Position = UDim2.new(
			job.start.X.Scale,
			job.start.X.Offset + delta.X,
			job.start.Y.Scale,
			job.start.Y.Offset + delta.Y
		)
	end)
	self:connect(uis.InputEnded, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local job = self._window_drag
		self._window_drag = nil
		if job and job.on_stop then
			job.on_stop(job.frame.Position)
		end
	end)
end

function veteran:make_draggable(frame, handle, on_stop)
	handle = handle or frame
	frame.Active = true
	handle.Active = true
	self:ensure_window_drag()

	self:connect(handle.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		self._window_drag = {
			frame = frame,
			start = frame.Position,
			start_input = input.Position,
			on_stop = on_stop,
		}
		self:bring_front(frame)
	end)
end

function veteran:drag_handle(panel, height, on_stop)
	local handle = self:create("Frame", {
		Parent = panel,
		Name = "DragHandle",
		Size = UDim2.new(1, 0, 0, height or 26),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 80,
	})
	self:make_draggable(panel, handle, on_stop)
	return handle
end

-- UI chrome only (menu key, watermark). Product options live in
-- veteran/configs/<build>/*.cfg and only return on inject when that
-- folder's autoload.txt is set. Themes use veteran/themes/autoload.txt.
local CONFIG_FILE = "veteran/configs/current.json"
local LEGACY_CONFIG_FILE = "veteran/config.json"

local KEY_NAMES = {
	[Enum.KeyCode.LeftShift] = "LSHIFT",
	[Enum.KeyCode.RightShift] = "RSHIFT",
	[Enum.KeyCode.LeftControl] = "LCTRL",
	[Enum.KeyCode.RightControl] = "RCTRL",
	[Enum.KeyCode.LeftAlt] = "LALT",
	[Enum.KeyCode.RightAlt] = "RALT",
	[Enum.KeyCode.Insert] = "INS",
	[Enum.KeyCode.Delete] = "DEL",
	[Enum.KeyCode.Backspace] = "BS",
	[Enum.KeyCode.Return] = "ENTER",
	[Enum.KeyCode.Escape] = "ESC",
	[Enum.KeyCode.CapsLock] = "CAPS",
	[Enum.KeyCode.Tab] = "TAB",
	[Enum.KeyCode.Space] = "SPACE",
	[Enum.KeyCode.Backquote] = "`",
	[Enum.KeyCode.Period] = ".",
	[Enum.UserInputType.MouseButton2] = "MB2",
	[Enum.UserInputType.MouseButton3] = "MB3",
}

local function key_label(key)
	if not key then
		return "none"
	end
	return KEY_NAMES[key] or (typeof(key) == "EnumItem" and key.Name) or tostring(key)
end

local function input_to_key(input)
	if input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
		return input.KeyCode
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
		return input.UserInputType
	end
	return nil
end

local function key_to_token(key)
	if typeof(key) == "EnumItem" then
		return key.EnumType == Enum.KeyCode and ("k:" .. key.Name) or ("u:" .. key.Name)
	end
	return nil
end

local function token_to_key(token)
	if type(token) ~= "string" then
		return nil
	end
	local kind, name = token:match("^(%a):(.+)$")
	if kind == "k" then
		local ok, key = pcall(function()
			return Enum.KeyCode[name]
		end)
		if ok then
			return key
		end
	elseif kind == "u" then
		local ok, key = pcall(function()
			return Enum.UserInputType[name]
		end)
		if ok then
			return key
		end
	end
	return nil
end

function veteran:make_swatch(parent, props)
	props = props or {}
	local z = props.z or 56
	local btn = self:create("TextButton", {
		Parent = parent,
		Size = props.size or UDim2.fromOffset(20, 12),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = props.layout_order,
		ZIndex = z,
	})
	local fill = self:create("Frame", {
		Parent = btn,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = props.color or theme.Accent,
		BorderSizePixel = 0,
		ZIndex = z + 1,
	})
	return btn, fill
end

function veteran:make_shell(parent, props)
	props = props or {}
	local z = props.z or 55
	local shell = self:create("Frame", {
		Parent = parent,
		Size = props.size or UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 0,
		LayoutOrder = props.layout_order,
		ZIndex = z,
	})
	local well = self:create("Frame", {
		Parent = shell,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = props.fill or theme["Object Background"],
		Theme = props.theme or "Object Background",
		ThemeProp = "BackgroundColor3",
		BorderColor3 = theme["Object Border"],
		BorderSizePixel = 1,
		ZIndex = z + 1,
	})
	return shell, well
end

function veteran:paint_toggle(pack, on, instant)
	if not pack then
		return
	end
	on = on and true or false
	local dur = (instant or pack._seeded ~= true) and 0 or TWEEN
	pack._seeded = true
	local text = on and theme.Text or theme["Disabled Text"]
	if pack.label then
		if dur == 0 then
			pack.label.TextColor3 = text
		else
			self:tween(pack.label, { TextColor3 = text }, dur)
		end
	end
	if pack.fill then
		pack.fill.BackgroundColor3 = theme.Accent
		if dur == 0 then
			pack.fill.BackgroundTransparency = on and 0 or 1
		else
			self:tween(pack.fill, { BackgroundTransparency = on and 0 or 1 }, dur)
		end
	end
	if pack.well then
		local border = on and theme.Accent or theme["Object Border"]
		if dur == 0 then
			pack.well.BorderColor3 = border
		else
			self:tween(pack.well, { BorderColor3 = border }, dur)
		end
	end
end

function veteran:make_option_row(parent, props)
	local row = self:create("TextButton", {
		Parent = parent,
		Name = props.name_tag or "OptionRow",
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = props.layout_order or 0,
		ZIndex = 55,
	})

	local box, well, fill
	if props.led ~= false then
		box = self:create("Frame", {
			Parent = row,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(BOX, BOX),
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			BorderSizePixel = 0,
			ZIndex = 56,
		})
		well = self:create("Frame", {
			Parent = box,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
			BackgroundColor3 = theme["Object Background"],
			Theme = "Object Background",
			ThemeProp = "BackgroundColor3",
			BorderColor3 = theme["Object Border"],
			BorderSizePixel = 1,
			ZIndex = 57,
		})
		fill = self:create("Frame", {
			Parent = well,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = theme.Accent,
			Theme = "Accent",
			ThemeProp = "BackgroundColor3",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 58,
		})
	end

	local label = self:create("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, box and (BOX + 6) or 0, 0.5, 0),
		Size = UDim2.new(1, box and -(BOX + 24) or -24, 0, ROW_H),
		Font = Enum.Font.SourceSans,
		Text = display_name(props.name),
		TextSize = TEXT_SIZE,
		TextColor3 = theme["Disabled Text"],
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 56,
	})

	local right = self:create("Frame", {
		Parent = row,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, ROW_H),
		BackgroundTransparency = 1,
		ZIndex = 57,
	})
	self:create("UIListLayout", {
		Parent = right,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	return {
		row = row,
		box = box,
		well = well,
		fill = fill,
		led = fill,
		label = label,
		right = right,
	}
end

function veteran:make_toggle(parent, props)
	local get = props.get or function()
		return false
	end
	local set = props.set or function() end
	local pack = self:make_option_row(parent, {
		name = props.name or "toggle",
		layout_order = props.layout_order,
		led = true,
	})

	function pack.refresh(instant)
		local on = get() and true or false
		self:paint_toggle(pack, on, instant)
		if pack.bind then
			local meta = props.flag and self.option_meta and self.option_meta[props.flag]
			local binding = self._binding == props.flag
			pack.bind.Text = binding and "[...]" or ("[" .. key_label(meta and meta.key) .. "]")
			if instant then
				pack.bind.TextColor3 = binding and theme.Accent or theme["Disabled Text"]
			else
				self:tween(pack.bind, {
					TextColor3 = binding and theme.Accent or theme["Disabled Text"],
				}, TWEEN)
			end
		end
	end

	self:connect(pack.row.MouseButton1Click, function()
		if self._binding then
			return
		end
		set(not get())
		pack.refresh()
	end)

	pack.get = get
	pack.set = set
	if props.color then
		self:attach_color(pack, props.color, props.section)
	end
	if props.show_bind and props.flag then
		pack.bind = self:bind_chip(pack.right, props.flag)
		pack.bind.LayoutOrder = 1
	end
	if props.flag then
		local meta = self.option_meta and self.option_meta[props.flag]
		if meta then
			meta.pack = pack
		end
	end
	pack.refresh(true)
	return pack
end

function veteran:attach_color(pack, spec, section_name)
	spec = spec or {}
	local flag = spec.flag
	if flag then
		self:add_option({
			flag = flag,
			name = display_name(spec.name, flag, pack.label and pack.label.Text),
			section = section_name,
			kind = "color",
			default = rgb_table_from(spec.default or spec.color or theme.Accent),
			set = spec.callback or spec.set,
		})
	end

	local swatch, fill = self:make_swatch(pack.right, {
		layout_order = 3,
		z = 56,
	})

	local function current()
		if spec.get then
			return spec.get()
		end
		if flag then
			return color_from_rgb_table(self:get_option(flag)) or spec.default or theme.Accent
		end
		return spec.default or theme.Accent
	end

	local function commit(color)
		if flag then
			self:set_option(flag, color)
		elseif spec.callback then
			spec.callback(color)
		elseif spec.set then
			spec.set(color)
		end
	end

	local old_refresh = pack.refresh
	function pack.refresh(instant)
		if old_refresh then
			old_refresh(instant)
		end
		local color = current()
		if typeof(color) ~= "Color3" then
			color = color_from_rgb_table(color) or theme.Accent
		end
		if instant then
			fill.BackgroundColor3 = color
		else
			self:tween(fill, { BackgroundColor3 = color }, TWEEN)
		end
	end

	self:connect(swatch.MouseButton1Click, function()
		self:open_picker(swatch, {
			get = current,
			set = function(color)
				commit(color)
				pack.refresh()
			end,
		})
	end)

	pack.swatch = swatch
	pack.swatch_fill = fill
	if flag then
		local meta = self.option_meta and self.option_meta[flag]
		if meta then
			meta.pack = meta.pack or pack
			meta.swatch = swatch
		end
	end
	pack.refresh(true)
	return swatch
end

function veteran:make_color(parent, props)
	local get = props.get or function()
		return theme.Accent
	end
	local set = props.set or function() end
	local pack = self:make_option_row(parent, {
		name = type(props.name) == "string" and props.name or "color",
		layout_order = props.layout_order,
		led = false,
	})
	pack.label.TextColor3 = theme.Text

	local swatch, fill = self:make_swatch(pack.right, {
		layout_order = 3,
		z = 56,
	})

	function pack.refresh(instant)
		local color = get()
		if typeof(color) ~= "Color3" then
			color = color_from_rgb_table(color) or theme.Accent
		end
		if instant then
			fill.BackgroundColor3 = color
			pack.label.TextColor3 = theme.Text
		else
			self:tween(fill, { BackgroundColor3 = color }, TWEEN)
			self:tween(pack.label, { TextColor3 = theme.Text }, TWEEN)
		end
	end

	self:connect(pack.row.MouseButton1Click, function()
		if self._binding then
			return
		end
		self:open_picker(swatch, {
			get = get,
			set = function(color)
				set(color)
				pack.refresh()
			end,
		})
	end)

	pack.swatch = swatch
	pack.swatch_fill = fill
	pack.get = get
	pack.set = set
	if props.flag then
		local meta = self.option_meta and self.option_meta[props.flag]
		if meta then
			meta.pack = pack
		end
	end
	pack.refresh(true)
	return pack
end

function veteran:make_action(parent, props)
	local pack = self:make_option_row(parent, {
		name = props.name or "run",
		layout_order = props.layout_order,
		led = false,
	})
	pack.label.TextColor3 = theme.Text

	local run = self:create("TextLabel", {
		Parent = pack.right,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, ROW_H),
		Font = Enum.Font.SourceSans,
		Text = "run",
		TextSize = TEXT_SIZE,
		TextColor3 = theme["Disabled Text"],
		LayoutOrder = 2,
		ZIndex = 55,
	})

	function pack.refresh(instant)
		if instant then
			pack.label.TextColor3 = theme.Text
			run.TextColor3 = theme["Disabled Text"]
		else
			self:tween(pack.label, { TextColor3 = theme.Text }, TWEEN)
			self:tween(run, { TextColor3 = theme["Disabled Text"] }, TWEEN)
		end
		if pack.bind then
			local meta = props.flag and self.option_meta and self.option_meta[props.flag]
			local binding = self._binding == props.flag
			pack.bind.Text = binding and "[...]" or ("[" .. key_label(meta and meta.key) .. "]")
			if instant then
				pack.bind.TextColor3 = binding and theme.Accent or theme["Disabled Text"]
			else
				self:tween(pack.bind, {
					TextColor3 = binding and theme.Accent or theme["Disabled Text"],
				}, TWEEN)
			end
		end
	end

	self:connect(pack.row.MouseButton1Click, function()
		if self._binding then
			return
		end
		self:tween(pack.label, { TextColor3 = theme.Accent }, 0.08)
		self:tween(run, { TextColor3 = theme.Accent }, 0.08)
		task.delay(0.12, function()
			if pack.label.Parent then
				self:tween(pack.label, { TextColor3 = theme.Text }, TWEEN)
				self:tween(run, { TextColor3 = theme["Disabled Text"] }, TWEEN)
			end
		end)
		if props.set then
			props.set()
		end
	end)

	if props.flag then
		pack.bind = self:bind_chip(pack.right, props.flag)
		pack.bind.LayoutOrder = 1
		local meta = self.option_meta and self.option_meta[props.flag]
		if meta then
			meta.pack = pack
		end
	end
	pack.refresh(true)
	return pack
end

function veteran:close_dropdown()
	local pack = self._dropdown
	self._dropdown = nil
	if not pack then
		self:close_slider_entry()
		return
	end
	if pack.menu then
		pack.menu:Destroy()
		pack.menu = nil
	end
	if pack.icon then
		pack.icon.Text = "+"
		self:tween(pack.icon, { TextColor3 = theme["Disabled Text"] }, TWEEN)
	end
	if pack.well then
		self:tween(pack.well, { BorderColor3 = theme["Object Border"] }, TWEEN)
	end
	self:close_slider_entry()
end

function veteran:close_slider_entry()
	if self.slider_entry then
		self.slider_entry:Destroy()
		self.slider_entry = nil
	end
	self._slider_entry_pack = nil
end

function veteran:click_outside_slider_entry(input)
	if not self.slider_entry then
		return
	end
	local mx, my = gui_mouse(input)
	if point_in(self.slider_entry, mx, my) then
		return
	end
	self:close_slider_entry()
end

local function round_step(value, step)
	step = step == 0 and 1 or (step or 1)
	return math.floor(value / step + 0.5) * step
end

local function format_slider(value, step, suffix)
	suffix = suffix or ""
	value = tonumber(value) or 0
	if step and step < 1 then
		local digits = math.max(0, math.floor(-math.log10(step) + 0.5))
		local text = string.format("%." .. tostring(digits) .. "f", value)
		text = text:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
		return text .. suffix
	end
	return tostring(math.floor(value + 0.5)) .. suffix
end

function veteran:open_slider_entry(pack, input)
	if not pack then
		return
	end
	if self._opening_slider then
		return
	end
	self._opening_slider = true
	task.defer(function()
		self._opening_slider = nil
	end)
	self:close_dropdown()
	self:close_picker()
	self:close_slider_entry()
	local mx, my = gui_mouse(input)
	local pop = self:create("Frame", {
		Parent = self.gui,
		Name = "slider_entry",
		Size = UDim2.fromOffset(148, 34),
		Position = UDim2.fromOffset(mx + 8, my + 8),
		BackgroundColor3 = theme["Window Background"],
		Theme = "Window Background",
		ThemeProp = "BackgroundColor3",
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		Active = true,
		ZIndex = 90,
	})
	self:accent_cap(pop, 96)
	local inner = self:create("Frame", {
		Parent = pop,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 91,
	})
	local box = self:create("TextBox", {
		Parent = inner,
		Position = UDim2.fromOffset(4, 5),
		Size = UDim2.new(1, -36, 0, 18),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		ThemeText = "Text",
		BorderSizePixel = 1,
		Font = Enum.Font.SourceSans,
		TextSize = TEXT_SIZE,
		Text = format_slider(pack.get and pack.get() or pack.min, pack.interval, ""),
		PlaceholderText = "value",
		PlaceholderColor3 = theme["Disabled Text"],
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 92,
	})
	self:create("UIPadding", {
		Parent = box,
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	local ok_shell, ok_well = self:make_shell(inner, {
		size = UDim2.fromOffset(22, 22),
		z = 92,
	})
	ok_shell.AnchorPoint = Vector2.new(1, 0.5)
	ok_shell.Position = UDim2.new(1, -4, 0.5, 0)
	local ok = self:create("TextButton", {
		Parent = ok_well,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSans,
		Text = "✓",
		TextSize = 14,
		ThemeText = "Text",
		AutoButtonColor = false,
		ZIndex = 94,
	})
	self.slider_entry = pop
	self._slider_entry_pack = pack
	local function confirm()
		if not self.slider_entry then
			return
		end
		local n = tonumber((box.Text or ""):gsub("[^%d%.%-]+", ""))
		if not n then
			box.Text = format_slider(pack.get and pack.get() or pack.min, pack.interval, "")
			return
		end
		local value = pack.clamp and pack.clamp(n) or n
		self._option_silent = true
		if pack.set then
			pack.set(value)
		end
		self._option_silent = false
		if pack.refresh then
			pack.refresh(true)
		end
		self:close_slider_entry()
	end
	self:connect(ok.MouseButton1Click, confirm)
	self:connect(box.FocusLost, function(enter)
		if enter then
			confirm()
		end
	end)
	task.defer(function()
		if box.Parent then
			box:CaptureFocus()
			box.CursorPosition = #box.Text + 1
		end
	end)
	task.defer(function()
		if not pop.Parent then
			return
		end
		local cam = workspace.CurrentCamera
		local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local x = math.clamp(pop.AbsolutePosition.X, 8, math.max(8, vs.X - pop.AbsoluteSize.X - 8))
		local y = math.clamp(pop.AbsolutePosition.Y, BAR_HEIGHT + 8, math.max(BAR_HEIGHT + 8, vs.Y - pop.AbsoluteSize.Y - 8))
		pop.Position = UDim2.fromOffset(x, y)
	end)
end

function veteran:ensure_slider_input()
	if self._slider_input_hooked then
		return
	end
	self._slider_input_hooked = true
	self:connect(uis.InputChanged, function(input)
		local pack = self._slider_drag
		if not pack or not pack.write_from_x then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			pack.write_from_x(gui_mouse(input))
		end
	end)
	self:connect(uis.InputEnded, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local pack = self._slider_drag
		self._slider_drag = nil
		if pack and pack.finish_drag then
			pack.finish_drag()
		end
	end)
end

function veteran:make_slider(parent, props)
	local min_v = props.min or 0
	local max_v = props.max or 100
	local step = props.interval or props.step or 1
	local suffix = props.suffix or ""
	local get = props.get or function()
		return min_v
	end
	local set = props.set or function() end

	local holder = self:create("Frame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layout_order or 0,
		ZIndex = 55,
	})
	self:create("UIListLayout", {
		Parent = holder,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local head = self:create("Frame", {
		Parent = holder,
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 56,
	})
	local label = self:create("TextLabel", {
		Parent = head,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -60, 1, 0),
		Font = Enum.Font.SourceSans,
		Text = props.name or "slider",
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 56,
	})
	local value_label = self:create("TextLabel", {
		Parent = head,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(56, ROW_H),
		Font = Enum.Font.SourceSans,
		Text = "",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		Active = true,
		ZIndex = 56,
	})
	local shell, well = self:make_shell(holder, {
		size = UDim2.new(1, 0, 0, 10),
		layout_order = 2,
		z = 56,
	})
	local fill = self:create("Frame", {
		Parent = well,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = theme.Accent,
		Theme = "Accent",
		ThemeProp = "BackgroundColor3",
		BorderSizePixel = 0,
		ZIndex = 58,
	})

	local dragging = false
	local pack = {
		row = holder,
		label = label,
		well = well,
		shell = shell,
		fill = fill,
		get = get,
		set = set,
		min = min_v,
		max = max_v,
		interval = step,
		suffix = suffix,
	}

	local function clamp_value(value)
		value = tonumber(value) or min_v
		value = math.clamp(round_step(value, step), min_v, max_v)
		if step >= 1 then
			return value
		end
		local digits = math.max(0, math.floor(-math.log10(step) + 0.5))
		return tonumber(string.format("%." .. tostring(digits) .. "f", value)) or value
	end
	pack.clamp = clamp_value

	function pack.refresh(instant)
		local value = clamp_value(get())
		local alpha = (max_v == min_v) and 0 or (value - min_v) / (max_v - min_v)
		value_label.Text = format_slider(value, step, suffix)
		if instant then
			fill.Size = UDim2.new(alpha, 0, 1, 0)
		else
			self:tween(fill, { Size = UDim2.new(alpha, 0, 1, 0) }, TWEEN)
		end
		if not dragging then
			if instant then
				value_label.TextColor3 = theme.Text
				well.BorderColor3 = theme["Object Border"]
			else
				self:tween(value_label, { TextColor3 = theme.Text }, TWEEN)
				self:tween(well, { BorderColor3 = theme["Object Border"] }, TWEEN)
			end
		end
	end

	local last_written
	local function write_from_x(x)
		local pos = well.AbsolutePosition.X
		local width = well.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local alpha = math.clamp((x - pos) / width, 0, 1)
		local value = clamp_value(min_v + (max_v - min_v) * alpha)
		if last_written == value then
			return
		end
		last_written = value
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		value_label.Text = format_slider(value, step, suffix)
		value_label.TextColor3 = theme.Accent
		self._option_silent = true
		set(value)
		self._option_silent = false
	end
	pack.write_from_x = write_from_x
	function pack.finish_drag()
		if not dragging then
			return
		end
		dragging = false
		if self._slider_drag == pack then
			self._slider_drag = nil
		end
		self:tween(value_label, { TextColor3 = theme.Text }, TWEEN)
		self:tween(well, { BorderColor3 = theme["Object Border"] }, TWEEN)
		self:flush_save_config()
	end

	local function open_entry(input)
		self:open_slider_entry(pack, input)
	end

	local function begin_drag(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			open_entry(input)
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			self._slider_drag = pack
			self:tween(well, { BorderColor3 = theme.Accent }, TWEEN)
			self:tween(value_label, { TextColor3 = theme.Accent }, TWEEN)
			write_from_x(gui_mouse(input))
		end
	end

	self:connect(well.InputBegan, begin_drag)
	self:connect(shell.InputBegan, begin_drag)
	self:connect(label.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			open_entry(input)
		end
	end)
	self:connect(value_label.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			open_entry(input)
		end
	end)
	self:connect(head.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			open_entry(input)
		end
	end)
	self:ensure_slider_input()

	if props.flag then
		local meta = self.option_meta and self.option_meta[props.flag]
		if meta then
			meta.pack = pack
		end
	end
	pack.refresh(true)
	return pack
end

local function dropdown_list(value)
	if type(value) ~= "table" then
		return value ~= nil and { value } or {}
	end
	if #value > 0 then
		return value
	end
	local list = {}
	for key, selected in pairs(value) do
		if selected == true and type(key) == "string" then
			table.insert(list, key)
		elseif type(selected) == "string" then
			table.insert(list, selected)
		end
	end
	return list
end

local function dropdown_has(list, item)
	for _, value in ipairs(list) do
		if value == item then
			return true
		end
	end
	return false
end

function veteran:make_dropdown(parent, props)
	local items = props.items or { "none" }
	local multi = props.multi == true
	local get = props.get or function()
		return multi and {} or items[1]
	end
	local set = props.set or function() end

	local holder = self:create("Frame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layout_order or 0,
		ZIndex = 55,
	})
	self:create("UIListLayout", {
		Parent = holder,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local label = self:create("TextLabel", {
		Parent = holder,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW_H),
		Font = Enum.Font.SourceSans,
		Text = props.name or "dropdown",
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		LayoutOrder = 1,
		ZIndex = 56,
	})
	local shell, well = self:make_shell(holder, {
		size = UDim2.new(1, 0, 0, 18),
		layout_order = 2,
		z = 56,
	})
	local btn = self:create("TextButton", {
		Parent = well,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 58,
	})
	local value_label = self:create("TextLabel", {
		Parent = btn,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Font = Enum.Font.SourceSans,
		Text = "",
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 59,
	})
	local icon_slot = self:create("Frame", {
		Parent = btn,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 59,
	})
	local icon = self:create("TextLabel", {
		Parent = icon_slot,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -1),
		Size = UDim2.fromOffset(16, 16),
		Font = Enum.Font.SourceSans,
		Text = "+",
		TextSize = 16,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 60,
	})
	self:animate_button(well, function()
		return theme["Object Background"]
	end)

	local pack = {
		row = holder,
		label = label,
		well = well,
		icon = icon,
		anchor = shell,
		get = get,
		set = set,
		multi = multi,
	}

	local function current_list()
		return dropdown_list(get())
	end

	local function format_value()
		if not multi then
			return tostring(get() or "")
		end
		local list = current_list()
		if #list == 0 then
			return "none"
		end
		local text = table.concat(list, ", ")
		if #text > 28 then
			return tostring(#list) .. " selected"
		end
		return text
	end

	local function is_on(item)
		if multi then
			return dropdown_has(current_list(), item)
		end
		return get() == item
	end

	function pack.refresh(instant)
		value_label.Text = format_value()
		if instant then
			value_label.TextColor3 = theme.Text
		else
			value_label.TextColor3 = theme.Accent
			self:tween(value_label, { TextColor3 = theme.Text }, TWEEN)
		end
	end

	function pack:refresh_options(new_items)
		items = new_items or items
		if veteran._dropdown == self then
			veteran:close_dropdown()
		end
		self.refresh(true)
	end

	local function pick(item)
		if not multi then
			set(item)
			pack.refresh()
			self:close_dropdown()
			return
		end
		local list = current_list()
		local next_list = {}
		local found = false
		for _, value in ipairs(list) do
			if value == item then
				found = true
			else
				table.insert(next_list, value)
			end
		end
		if not found then
			table.insert(next_list, item)
		end
		set(next_list)
		pack.refresh()
	end

	local function open_menu()
		if self._dropdown == pack and pack.menu then
			self:close_dropdown()
			return
		end
		self:close_dropdown()
		self:close_picker()
		icon.Text = "-"
		self:tween(icon, { TextColor3 = theme.Accent }, TWEEN)
		self:tween(well, { BorderColor3 = theme.Accent }, TWEEN)

		local pos = shell.AbsolutePosition
		local size = shell.AbsoluteSize
		local height = math.min(math.max(#items, 1), 6) * 18 + 12
		local menu = self:create("Frame", {
			Parent = self.gui,
			Position = UDim2.fromOffset(pos.X, pos.Y + size.Y + 2),
			Size = UDim2.fromOffset(size.X, height),
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			BorderColor3 = Color3.fromRGB(10, 10, 10),
			BorderSizePixel = 1,
			ZIndex = 130,
		})
		local inner = self:create("Frame", {
			Parent = menu,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
			BackgroundColor3 = theme["Object Background"],
			Theme = "Object Background",
			ThemeProp = "BackgroundColor3",
			ThemeBorder = "Object Border",
			BorderSizePixel = 1,
			ZIndex = 131,
		})
		local list = self:create("ScrollingFrame", {
			Parent = inner,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = theme.Accent,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 132,
		})
		self:create("UIListLayout", {
			Parent = list,
			Padding = UDim.new(0, 1),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		self:create("UIPadding", {
			Parent = list,
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		})
		for i, item in ipairs(items) do
			local row = self:create("TextButton", {
				Parent = list,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = i,
				ZIndex = 133,
			})
			local text = self:create("TextLabel", {
				Parent = row,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(6, 0),
				Size = UDim2.new(1, -10, 1, 0),
				Font = Enum.Font.SourceSans,
				Text = tostring(item),
				TextSize = TEXT_SIZE,
				TextColor3 = is_on(item) and theme.Text or theme["Disabled Text"],
				TextXAlignment = Enum.TextXAlignment.Left,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.5,
				ZIndex = 134,
			})
			self:connect(row.MouseEnter, function()
				self:tween(text, { TextColor3 = theme.Text }, TWEEN)
			end)
			self:connect(row.MouseLeave, function()
				self:tween(text, {
					TextColor3 = is_on(item) and theme.Text or theme["Disabled Text"],
				}, TWEEN)
			end)
			self:connect(row.MouseButton1Click, function()
				pick(item)
				if multi then
					text.TextColor3 = is_on(item) and theme.Text or theme["Disabled Text"]
				end
			end)
		end
		pack.menu = menu
		self._dropdown = pack
	end

	self:connect(btn.MouseButton1Click, function()
		open_menu()
	end)
	self:connect(shell:GetPropertyChangedSignal("AbsolutePosition"), function()
		if not pack.menu then
			return
		end
		local pos = shell.AbsolutePosition
		local size = shell.AbsoluteSize
		pack.menu.Position = UDim2.fromOffset(pos.X, pos.Y + size.Y + 2)
		pack.menu.Size = UDim2.fromOffset(size.X, pack.menu.Size.Y.Offset)
	end)

	if props.flag then
		local meta = self.option_meta and self.option_meta[props.flag]
		if meta then
			meta.pack = pack
		end
	end
	pack.refresh(true)
	return pack
end

function veteran:make_button(parent, props)
	local shell, well = self:make_shell(parent, {
		size = UDim2.new(1, 0, 0, 20),
		layout_order = props.layout_order,
		z = 55,
	})
	local btn = self:create("TextButton", {
		Parent = well,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSans,
		Text = props.name or "button",
		TextSize = TEXT_SIZE,
		TextColor3 = theme.Text,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		AutoButtonColor = false,
		ZIndex = 57,
	})
	self:animate_button(well, function()
		return theme["Object Background"]
	end)
	self:connect(btn.MouseButton1Click, function()
		self:tween(btn, { TextColor3 = theme.Accent }, 0.08)
		self:tween(well, { BorderColor3 = theme.Accent }, 0.08)
		task.delay(0.12, function()
			if btn.Parent then
				self:tween(btn, { TextColor3 = theme.Text }, TWEEN)
				self:tween(well, { BorderColor3 = theme["Object Border"] }, TWEEN)
			end
		end)
		if props.set then
			props.set()
		end
	end)
	local pack = { row = shell, label = btn, well = well }
	if props.flag then
		local meta = self.option_meta and self.option_meta[props.flag]
		if meta then
			meta.pack = pack
		end
	end
	return pack
end

function veteran:make_textbox(parent, props)
	local get = props.get or function()
		return ""
	end
	local set = props.set or function() end
	local holder = self:create("Frame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layout_order or 0,
		ZIndex = 55,
	})
	self:create("UIListLayout", {
		Parent = holder,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	if props.name then
		self:create("TextLabel", {
			Parent = holder,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ROW_H),
			Font = Enum.Font.SourceSans,
			Text = display_name(props.name),
			TextSize = TEXT_SIZE,
			ThemeText = "Text",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			LayoutOrder = 1,
			ZIndex = 56,
		})
	end
	local shell, well = self:make_shell(holder, {
		size = UDim2.new(1, 0, 0, 18),
		layout_order = 2,
		z = 56,
	})
	local box = self:create("TextBox", {
		Parent = well,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSans,
		Text = tostring(get() or ""),
		PlaceholderText = props.placeholder or "",
		PlaceholderColor3 = theme["Disabled Text"],
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = props.clear_on_focus == true,
		ZIndex = 58,
	})
	self:create("UIPadding", {
		Parent = box,
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	self:connect(box.Focused, function()
		self:tween(well, { BorderColor3 = theme.Accent }, TWEEN)
		self:tween(box, { TextColor3 = theme.Text }, TWEEN)
	end)
	self:connect(box.FocusLost, function()
		self:tween(well, { BorderColor3 = theme["Object Border"] }, TWEEN)
		set(box.Text)
	end)
	local pack = { row = holder, box = box, well = well, get = get, set = set }
	function pack.refresh()
		if box:IsFocused() then
			return
		end
		box.Text = tostring(get() or "")
	end
	if props.flag then
		local meta = self.option_meta and self.option_meta[props.flag]
		if meta then
			meta.pack = pack
		end
	end
	pack.refresh()
	return pack
end

function veteran:make_keybind(parent, props)
	local pack = self:make_option_row(parent, {
		name = props.name or "keybind",
		layout_order = props.layout_order,
		led = false,
	})
	pack.label.TextColor3 = theme.Text
	if props.flag then
		pack.bind = self:bind_chip(pack.right, props.flag)
		local meta = self.option_meta and self.option_meta[props.flag]
		if meta then
			meta.pack = pack
		end
	end
	function pack.refresh(instant)
		if instant then
			pack.label.TextColor3 = theme.Text
		else
			self:tween(pack.label, { TextColor3 = theme.Text }, TWEEN)
		end
		if pack.bind then
			local meta = props.flag and self.option_meta and self.option_meta[props.flag]
			local binding = self._binding == props.flag
			pack.bind.Text = binding and "[...]" or ("[" .. key_label(meta and meta.key) .. "]")
			if instant then
				pack.bind.TextColor3 = binding and theme.Accent or theme["Disabled Text"]
			else
				self:tween(pack.bind, {
					TextColor3 = binding and theme.Accent or theme["Disabled Text"],
				}, TWEEN)
			end
		end
	end
	pack.refresh(true)
	return pack
end

function veteran:layout_notifications()
	local y = 12
	for i, pack in ipairs(self._notifs or {}) do
		if pack.holder and pack.holder.Parent then
			self:tween(pack.holder, {
				Position = UDim2.new(1, -12, 1, -(y + pack.holder.AbsoluteSize.Y)),
			}, 0.18)
			y += pack.holder.AbsoluteSize.Y + 6
		end
	end
end

function veteran:notification(props)
	if type(props) == "string" then
		props = { text = props }
	end
	props = props or {}
	if not self.gui then
		return
	end
	self._notifs = self._notifs or {}
	local text = tostring(props.text or props.name or "")
	local duration = tonumber(props.duration or props.time) or 3

	local holder = self:create("Frame", {
		Parent = self.gui,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		ZIndex = 120,
	})
	local inner = self:create("Frame", {
		Parent = holder,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 121,
	})
	self:create("UIPadding", {
		Parent = inner,
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	})
	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Font = Enum.Font.SourceSans,
		Text = text,
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 122,
	})
	self:accent_cap(holder, 123)

	local pack = { holder = holder }
	table.insert(self._notifs, pack)
	self:layout_notifications()
	task.delay(math.max(0.4, duration), function()
		if not holder.Parent then
			return
		end
		self:tween(holder, { BackgroundTransparency = 1 }, TWEEN)
		task.delay(TWEEN, function()
			holder:Destroy()
		end)
		for i, other in ipairs(self._notifs) do
			if other == pack then
				table.remove(self._notifs, i)
				break
			end
		end
		self:layout_notifications()
	end)
	return pack
end

function veteran:confirm(props)
	props = props or {}
	self:close_dropdown()
	self:close_picker()
	self:close_slider_entry()
	if self._confirm then
		self._confirm:Destroy()
		self._confirm = nil
	end
	local overlay = self:create("Frame", {
		Parent = self.gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 130,
	})
	self._confirm = overlay
	local panel, inner = self:make_panel({
		Parent = overlay,
		Name = "ConfirmPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(280, 92),
		ZIndex = 131,
	})
	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 36),
		Font = Enum.Font.SourceSans,
		Text = props.name or props.text or "are you sure?",
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 133,
	})
	local row = self:create("Frame", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 52),
		Size = UDim2.new(1, -20, 0, 22),
		ZIndex = 133,
	})
	self:create("UIListLayout", {
		Parent = row,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	})
	local options = props.options or { "Yes", "No" }
	local function finish(choice)
		if overlay.Parent then
			overlay:Destroy()
		end
		if self._confirm == overlay then
			self._confirm = nil
		end
		if props.callback then
			props.callback(choice)
		end
	end
	for _, name in ipairs(options) do
		local shell, well = self:make_shell(row, {
			size = UDim2.fromOffset(72, 20),
			z = 134,
		})
		local btn = self:create("TextButton", {
			Parent = well,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSans,
			Text = string.lower(tostring(name)),
			TextSize = TEXT_SIZE,
			TextColor3 = theme.Text,
			AutoButtonColor = false,
			ZIndex = 136,
		})
		self:animate_button(well, function()
			return theme["Object Background"]
		end)
		self:connect(btn.MouseButton1Click, function()
			finish(name)
		end)
	end
	self:connect(overlay.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not point_in(panel, gui_mouse(input)) then
			finish(options[2] or "No")
		end
	end)
	return overlay
end

function veteran:panel(props)
	return self:confirm(props)
end

function veteran:is_config_chrome_flag(flag)
	return flag == "config_autoload"
		or flag == "config_name_list"
		or flag == "config_name_text_box"
end

function veteran:is_ui_config_flag(flag, meta)
	if self:is_config_chrome_flag(flag) then
		return false
	end
	meta = meta or (self.option_meta and self.option_meta[flag])
	if not meta then
		return flag == "menu"
			or flag == "watermark"
			or flag == "ui_watermark"
			or flag == "ui_accent"
			or flag == "backpack_panel"
			or flag == "emotes_panel"
	end
	if meta.tab == "ui" or meta.section == "ui" then
		return true
	end
	return flag == "menu"
		or flag == "watermark"
		or flag == "ui_watermark"
		or flag == "ui_accent"
		or flag == "backpack_panel"
		or flag == "emotes_panel"
end

function veteran:dump_config()
	local binds = {}
	local options = {}
	for flag, meta in pairs(self.option_meta or {}) do
		if self:is_ui_config_flag(flag, meta) or self:is_config_chrome_flag(flag) then
			continue
		end
		if meta.key then
			binds[flag] = {
				key = key_to_token(meta.key),
				mode = meta.mode or "toggle",
			}
		end
		if self.options and self.options[flag] ~= nil then
			options[flag] = self.options[flag]
		end
	end
	return {
		options = options,
		binds = binds,
	}
end

function veteran:export_config()
	return http_service:JSONEncode(self:dump_config())
end

function veteran:import_config(json)
	if type(json) ~= "string" then
		return false
	end
	local decoded
	pcall(function()
		decoded = http_service:JSONDecode(json)
	end)
	if type(decoded) ~= "table" then
		return false
	end
	self._applying_options = true
	if type(decoded.options) == "table" then
		for flag, value in pairs(decoded.options) do
			if not self:is_ui_config_flag(flag) and not self:is_config_chrome_flag(flag) then
				self.options[flag] = value
			end
		end
	end
	if type(decoded.binds) == "table" then
		for flag, bind in pairs(decoded.binds) do
			if self:is_ui_config_flag(flag) or self:is_config_chrome_flag(flag) then
				continue
			end
			local meta = self.option_meta[flag]
			if meta and type(bind) == "table" then
				meta.key = token_to_key(bind.key)
				meta.mode = bind.mode == "hold" and "hold" or "toggle"
			end
		end
	end
	self._applying_options = false
	self:apply_saved_options()
	self:refresh_keybind_list()
	self:save_config()
	return true
end

function veteran:apply_saved_options()
	self._applying_options = true
	for flag, meta in pairs(self.option_meta or {}) do
		if not meta or not meta.set or meta.kind == "button" or meta.kind == "keybind" then
			continue
		end
		if self:is_ui_config_flag(flag, meta) or self:is_config_chrome_flag(flag) then
			continue
		end
		local value = self.options and self.options[meta.flag]
		if value == nil then
			continue
		end
		if meta.kind == "color" then
			meta.set(color_from_rgb_table(value) or theme.Accent)
		else
			meta.set(value)
		end
	end
	self._applying_options = false
	self:refresh_option_packs()
end

function veteran:get_option(flag)
	if self.options and self.options[flag] ~= nil then
		return self.options[flag]
	end
	local meta = self.option_meta and self.option_meta[flag]
	if meta then
		return meta.default
	end
	return nil
end

function veteran:set_option(flag, value, skip_save)
	self.options = self.options or {}
	self.flags = self.options
	self.option_meta = self.option_meta or {}
	local meta = self.option_meta[flag]
	if not meta then
		return
	end
	if meta.kind == "toggle" then
		value = value and true or false
		self.options[flag] = value
		if meta.set then
			meta.set(value)
		end
	elseif meta.kind == "color" then
		value = rgb_table_from(value)
		self.options[flag] = value
		if meta.set then
			meta.set(color_from_rgb_table(value) or Color3.new(1, 1, 1))
		end
	elseif meta.kind == "slider" then
		value = tonumber(value)
		if not value then
			return
		end
		if type(meta.min) == "number" and type(meta.max) == "number" then
			value = math.clamp(value, meta.min, meta.max)
		end
		self.options[flag] = value
		if meta.set then
			meta.set(value)
		end
	elseif meta.kind == "dropdown" or meta.kind == "text" then
		self.options[flag] = value
		if meta.set then
			meta.set(value)
		end
		elseif meta.kind == "button" or meta.kind == "keybind" then
			if meta.set then
				meta.set()
			end
			return
	else
		return
	end
	if meta.pack and meta.pack.refresh and not self._option_silent then
		meta.pack.refresh(true)
	end
	if not skip_save then
		self:queue_save_config()
	end
end

function veteran:add_option(def)
	self.options = self.options or {}
	self.flags = self.options
	self.option_meta = self.option_meta or {}
	local prev = self.option_meta[def.flag]
	if prev then
		if def.key == nil then
			def.key = prev.key
		end
		if def.mode == nil then
			def.mode = prev.mode
		end
		if def.pack == nil then
			def.pack = prev.pack
		end
	end
	self.option_meta[def.flag] = def
	if def.kind == "toggle" and self.options[def.flag] == nil then
		self.options[def.flag] = def.default and true or false
	elseif def.kind == "color" and self.options[def.flag] == nil then
		self.options[def.flag] = rgb_table_from(def.default or theme.Accent)
	elseif def.kind == "slider" and self.options[def.flag] == nil then
		self.options[def.flag] = tonumber(def.default) or 0
	elseif (def.kind == "dropdown" or def.kind == "text") and self.options[def.flag] == nil then
		self.options[def.flag] = def.default
	end
	if typeof(def.default) == "EnumItem" then
		def.key = def.key or def.default
	end
	return def
end

function veteran:save_config()
	self:ensure_theme_dir()
	local options = {}
	local binds = {}
	for flag, meta in pairs(self.option_meta or {}) do
		if not self:is_ui_config_flag(flag, meta) then
			continue
		end
		if self.options and self.options[flag] ~= nil then
			options[flag] = self.options[flag]
		end
		if meta.key then
			binds[flag] = {
				key = key_to_token(meta.key),
				mode = meta.mode or "toggle",
			}
		end
	end
	self:fs("writefile", CONFIG_FILE, http_service:JSONEncode({
		options = options,
		binds = binds,
	}))
end

function veteran:persist_session()
	self:save_config()
	if type(self.autosave_named_config) == "function" then
		self:autosave_named_config()
	end
end

function veteran:queue_save_config()
	if self._applying_options or self._slider_drag then
		return
	end
	self._save_gen = (self._save_gen or 0) + 1
	local gen = self._save_gen
	task.delay(0.4, function()
		if gen == self._save_gen then
			self:persist_session()
		end
	end)
end

function veteran:flush_save_config()
	self._save_gen = (self._save_gen or 0) + 1
	self:persist_session()
end

function veteran:load_config()
	self.options = self.options or {}
	self.option_meta = self.option_meta or {}
	local ok, body = self:fs("readfile", CONFIG_FILE)
	if not ok or type(body) ~= "string" or body == "" then
		ok, body = self:fs("readfile", LEGACY_CONFIG_FILE)
	end
	if not ok or type(body) ~= "string" or body == "" then
		return
	end
	local decoded
	pcall(function()
		decoded = http_service:JSONDecode(body)
	end)
	if type(decoded) ~= "table" then
		return nil
	end
	if type(decoded.options) == "table" then
		for flag, value in pairs(decoded.options) do
			if not self:is_ui_config_flag(flag) then
				continue
			end
			if type(value) == "boolean" or type(value) == "number" or type(value) == "string" then
				self.options[flag] = value
			elseif type(value) == "table" then
				if type(value[1]) == "number" or value.r or value.R then
					self.options[flag] = rgb_table_from(value)
				else
					self.options[flag] = value
				end
			end
		end
	end
	if type(decoded.binds) == "table" then
		for flag, bind in pairs(decoded.binds) do
			if not self:is_ui_config_flag(flag) then
				continue
			end
			local meta = self.option_meta[flag]
			if meta and type(bind) == "table" then
				meta.key = token_to_key(bind.key)
				meta.mode = bind.mode == "hold" and "hold" or "toggle"
			end
		end
	end
	return decoded
end

function veteran:begin_bind(flag)
	local meta = self.option_meta and self.option_meta[flag]
	if not meta then
		return
	end
	self._binding = flag
	self:refresh_keybind_list()
	if meta.pack and meta.pack.refresh then
		meta.pack.refresh()
	end
end

function veteran:cancel_bind()
	if not self._binding then
		return
	end
	self._binding = nil
	self:refresh_keybind_list()
	self:refresh_option_packs()
end

function veteran:finish_bind(key)
	local flag = self._binding
	self._binding = nil
	local meta = flag and self.option_meta[flag]
	if not meta then
		self:refresh_keybind_list()
		return
	end
	if key == Enum.KeyCode.Escape then
		meta.key = flag == "menu" and Enum.KeyCode.RightControl or nil
	else
		meta.key = key
	end
	self:persist_session()
	self:refresh_keybind_list()
	if meta.pack and meta.pack.refresh then
		meta.pack.refresh()
	end
end

function veteran:is_always_bind(flag)
	return flag == "menu" or flag == "backpack_panel" or flag == "emotes_panel"
end

function veteran:fire_bind(key, down)
	if not key then
		return
	end
	for flag, meta in pairs(self.option_meta or {}) do
		if meta.key ~= key then
			continue
		end
		if not self:is_always_bind(flag) and self.menu_visible == false then
			continue
		end
		if meta.kind == "toggle" then
			if (meta.mode or "toggle") == "hold" then
				self:set_option(flag, down)
			elseif down then
				self:set_option(flag, not self:get_option(flag))
			end
		elseif (meta.kind == "button" or meta.kind == "keybind") and down and meta.set then
			meta.set()
		end
	end
end

function veteran:click_outside_dropdown(input)
	local pack = self._dropdown
	if not pack or not pack.menu then
		return
	end
	local mx, my = gui_mouse(input)
	if point_in(pack.menu, mx, my) then
		return
	end
	if pack.anchor and point_in(pack.anchor, mx, my) then
		return
	end
	if pack.well and point_in(pack.well, mx, my) then
		return
	end
	self:close_dropdown()
end

function veteran:listen_keys()
	if self._keys_listening then
		return
	end
	self._keys_listening = true
	self:connect(uis.InputBegan, function(input, game_processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:click_outside_dropdown(input)
			self:click_outside_chrome_menu(input)
			self:click_outside_slider_entry(input)
		end
		if self.slider_entry and input.KeyCode == Enum.KeyCode.Escape then
			self:close_slider_entry()
			return
		end
		if uis:GetFocusedTextBox() then
			return
		end
		if self:wants_coregui_redesign() then
			if input.KeyCode == Enum.KeyCode.Slash then
				self:set_utility_open("chat", true)
				return
			end
			if self:activate_hotbar_key(input.KeyCode) then
				return
			end
		end
		local key = input_to_key(input)
		if self._binding then
			if key then
				self:finish_bind(key)
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:cancel_bind()
			end
			return
		end
		local allow = false
		if key then
			for flag, meta in pairs(self.option_meta or {}) do
				if meta.key == key and self:is_always_bind(flag) then
					allow = true
					break
				end
			end
		end
		if game_processed and not allow then
			return
		end
		self:fire_bind(key, true)
	end)
	self:connect(uis.InputEnded, function(input)
		if self._binding or uis:GetFocusedTextBox() then
			return
		end
		self:fire_bind(input_to_key(input), false)
	end)
end

function veteran:set_menu_visible(on)
	self.menu_visible = on and true or false
	if self.topbar then
		self.topbar.Visible = true
	end
	for name, is_open in pairs(self.open_tabs or {}) do
		local panel = self:tab_panel(name)
		if not panel then
			continue
		end
		if panel == self.info_panel then
			if self.menu_visible and is_open then
				self:set_info_open(true)
			else
				panel.Visible = false
				panel.Position = UDim2.fromOffset(-INFO_WIDTH, BAR_HEIGHT)
			end
		else
			panel.Visible = self.menu_visible and is_open
		end
	end
	if not self.menu_visible then
		self:close_picker()
		self:close_dropdown()
		self:close_slider_entry()
	end
	self:refresh_left_chrome()
end

function veteran:refresh_option_packs()
	for _, meta in pairs(self.option_meta or {}) do
		if meta.pack and meta.pack.refresh then
			meta.pack.refresh(true)
		end
	end
end

function veteran:bind_chip(parent, flag)
	local meta = self.option_meta[flag]
	local btn = self:create("TextButton", {
		Parent = parent,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, ROW_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSans,
		TextSize = TEXT_SIZE,
		Text = "[" .. key_label(meta and meta.key) .. "]",
		TextColor3 = theme["Disabled Text"],
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		AutoButtonColor = false,
		ZIndex = 56,
	})
	self:connect(btn.MouseButton1Click, function()
		self:begin_bind(flag)
	end)
	self:connect(btn.MouseButton2Click, function()
		self._binding = flag
		self:finish_bind(flag == "menu" and Enum.KeyCode.RightControl or Enum.KeyCode.Escape)
	end)
	return btn
end

local function clear_fill(parent)
	if not parent then
		return
	end
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

function veteran:make_named_box(parent, title, layout_order)
	local holder = self:create("Frame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layout_order or 0,
		ZIndex = 53,
	})
	local box = self:create("Frame", {
		Parent = holder,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		ZIndex = 53,
	})
	local inner = self:create("Frame", {
		Parent = box,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 54,
	})
	self:create("UIPadding", {
		Parent = inner,
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	self:create("UIListLayout", {
		Parent = inner,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self:create("TextLabel", {
		Parent = box,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 0, 1),
		Font = Enum.Font.SourceSans,
		Text = display_name(title),
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 56,
	})
	return holder, inner
end

function veteran:keybind_query()
	return string.lower(self.keybind_search and self.keybind_search.Text or "")
end

function veteran:refresh_keybind_tabs(tab_names)
	if not self.keybind_tabs then
		return
	end
	clear_fill(self.keybind_tabs)
	local current = self.keybind_tab or "all"
	local chips = { "all" }
	for _, name in ipairs(tab_names) do
		table.insert(chips, name)
	end
	for i, name in ipairs(chips) do
		local on = current == name
		local btn = self:create("TextButton", {
			Parent = self.keybind_tabs,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 18),
			BackgroundColor3 = on and theme["Tab Toggle Background"] or theme["Object Background"],
			Theme = on and "Tab Toggle Background" or "Object Background",
			ThemeProp = "BackgroundColor3",
			ThemeBorder = "Object Border",
			BorderSizePixel = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = i,
			ZIndex = 56,
		})
		self:create("UIPadding", {
			Parent = btn,
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		})
		self:create("TextLabel", {
			Parent = btn,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Font = Enum.Font.SourceSans,
			Text = name,
			TextSize = TEXT_SIZE,
			TextColor3 = on and theme.Text or theme["Disabled Text"],
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			ZIndex = 57,
		})
		self:connect(btn.MouseButton1Click, function()
			self.keybind_tab = name
			self:refresh_keybind_list()
		end)
	end
end

function veteran:refresh_keybind_list()
	if not self.keybind_list then
		return
	end
	clear_fill(self.keybind_list)

	local query = self:keybind_query()
	local tabs_seen = {}
	local candidates = {}
	for flag, meta in pairs(self.option_meta or {}) do
		if meta.kind ~= "toggle" and meta.kind ~= "button" and meta.kind ~= "keybind" then
			continue
		end
		local tab = meta.tab or "ui"
		tabs_seen[tab] = true
		table.insert(candidates, { flag = flag, meta = meta, tab = tab })
	end

	local tab_names = {}
	for name in pairs(tabs_seen) do
		table.insert(tab_names, name)
	end
	table.sort(tab_names, function(a, b)
		if a == "ui" or b == "ui" then
			return a == "ui"
		end
		return a < b
	end)
	local tab_filter = self.keybind_tab or "all"
	if tab_filter ~= "all" and not tabs_seen[tab_filter] then
		self.keybind_tab = "all"
		tab_filter = "all"
	end
	self:refresh_keybind_tabs(tab_names)

	local items = {}
	for _, item in ipairs(candidates) do
		local meta = item.meta
		local hay = string.lower(table.concat({
			display_name(meta.name, item.flag),
			meta.section or "",
			item.tab,
			(string.gsub(item.flag, "_", " ")),
			key_label(meta.key) or "",
		}, " "))
		if query ~= "" and not string.find(hay, query, 1, true) then
			continue
		end
		if tab_filter ~= "all" and item.tab ~= tab_filter then
			continue
		end
		table.insert(items, item)
	end

	local grouped = {}
	for _, item in ipairs(items) do
		local tab = grouped[item.tab]
		if not tab then
			tab = {}
			grouped[item.tab] = tab
		end
		local section = item.meta.section or "misc"
		tab[section] = tab[section] or {}
		table.insert(tab[section], item)
	end

	local visible_tabs = {}
	for name in pairs(grouped) do
		table.insert(visible_tabs, name)
	end
	table.sort(visible_tabs, function(a, b)
		if a == "ui" or b == "ui" then
			return a == "ui"
		end
		return a < b
	end)

	local order = 0
	local shown = 0
	for _, tab_name in ipairs(visible_tabs) do
		order += 1
		local head = self:create("Frame", {
			Parent = self.keybind_list,
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 53,
		})
		local tab_label = self:create("TextLabel", {
			Parent = head,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, -1),
			Font = Enum.Font.SourceSans,
			Text = tab_name,
			TextSize = TEXT_SIZE,
			ThemeText = "Text",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			ZIndex = 54,
		})
		self:create("Frame", {
			Parent = tab_label,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 1),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = theme.Accent,
			Theme = "Accent",
			ThemeProp = "BackgroundColor3",
			BorderSizePixel = 0,
			ZIndex = 55,
		})

		local sections = {}
		for name in pairs(grouped[tab_name]) do
			table.insert(sections, name)
		end
		table.sort(sections)
		for _, section_name in ipairs(sections) do
			order += 1
			local _, inner = self:make_named_box(self.keybind_list, section_name, order)
			local rows = grouped[tab_name][section_name]
			table.sort(rows, function(a, b)
				return (a.meta.name or a.flag) < (b.meta.name or b.flag)
			end)
			for i, item in ipairs(rows) do
				shown += 1
				local flag = item.flag
				local meta = item.meta
				local on = meta.kind == "toggle" and self:get_option(flag)
				local pack = self:make_option_row(inner, {
					name = display_name(meta.name, flag),
					layout_order = i,
					led = meta.kind == "toggle",
					name_tag = "BindRow",
				})
				self:paint_toggle(pack, on, true)
				pack.label.TextColor3 = (meta.kind == "button" or on) and theme.Text or theme["Disabled Text"]

				local binding = self._binding == flag
				local mode = meta.kind == "toggle" and (meta.mode or "toggle") or "press"
				self:create("TextLabel", {
					Parent = pack.right,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, ROW_H),
					Font = Enum.Font.SourceSans,
					Text = binding and "..." or key_label(meta.key),
					TextSize = TEXT_SIZE,
					TextColor3 = binding and theme.Accent or theme["Disabled Text"],
					LayoutOrder = 1,
					ZIndex = 56,
				})
				self:create("TextLabel", {
					Parent = pack.right,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, ROW_H),
					Font = Enum.Font.SourceSans,
					Text = mode,
					TextSize = TEXT_SIZE,
					TextColor3 = theme["Disabled Text"],
					LayoutOrder = 2,
					ZIndex = 56,
				})
				self:connect(pack.row.MouseButton1Click, function()
					self:begin_bind(flag)
				end)
				self:connect(pack.row.MouseButton2Click, function()
					if meta.kind == "toggle" then
						meta.mode = (meta.mode == "hold") and "toggle" or "hold"
						self:persist_session()
						self:refresh_keybind_list()
					end
				end)
			end
		end
	end

	if self.keybind_empty then
		self.keybind_empty.Visible = shown == 0
		if shown == 0 then
			if query ~= "" then
				self.keybind_empty.Text = "no matches"
			elseif tab_filter ~= "all" then
				self.keybind_empty.Text = "no binds in this tab"
			else
				self.keybind_empty.Text = "no keybinds"
			end
		end
	end
end

function veteran:register_section(tab, name, pack)
	self.feature_map = self.feature_map or {}
	self.section_list = self.section_list or {}
	self.feature_map[string.lower(tostring(tab or "")) .. "/" .. string.lower(tostring(name or ""))] = pack
	table.insert(self.section_list, pack)
end

local function normalize_search_query(query)
	query = string.lower(tostring(query or ""))
	query = string.gsub(query, "^%s+", "")
	query = string.gsub(query, "%s+$", "")
	return query
end

function veteran:section_matches_query(pack, query)
	query = normalize_search_query(query)
	if query == "" or not pack then
		return true
	end
	local parts = {
		tostring(pack.name or ""),
		pack.page and tostring(pack.page.name or "") or "",
	}
	for _, term in ipairs(pack._search or {}) do
		parts[#parts + 1] = tostring(term)
	end
	local section_name = string.lower(tostring(pack.name or ""))
	local page_name = string.lower(tostring(pack.page and pack.page.name or ""))
	for _, meta in pairs(self.option_meta or {}) do
		if string.lower(tostring(meta.section or "")) == section_name then
			local tab = string.lower(tostring(meta.tab or ""))
			if tab == "" or tab == page_name then
				parts[#parts + 1] = tostring(meta.name or "")
				parts[#parts + 1] = tostring(meta.flag or "")
			end
		end
	end
	local hay = string.lower(table.concat(parts, " "))
	if string.find(hay, query, 1, true) then
		return true
	end
	if string.find(section_name, "config", 1, true) then
		for _, name in ipairs(self.config_file_names or {}) do
			if string.find(string.lower(tostring(name)), query, 1, true) then
				return true
			end
		end
	end
	return false
end

function veteran:apply_config_section_search(opts)
	opts = opts or {}
	local query = normalize_search_query(self.config_search_query)
	local window = self.config_window
	if not window then
		return
	end

	local first_tab = nil
	local current_has = false
	local current = window._current
	for _, pack in ipairs(self.section_list or {}) do
		if pack.window == window then
			local match = self:section_matches_query(pack, query)
			if match then
				if not first_tab and pack.page then
					first_tab = pack.page.name
				end
				if current and pack.page == current then
					current_has = true
				end
			end
		end
	end

	if opts.switch_tab ~= false and query ~= "" and first_tab and not current_has and window.open_tab then
		window:open_tab(first_tab)
	end

	for _, pack in ipairs(self.section_list or {}) do
		if pack.window == window and pack.holder then
			pack.holder.Visible = self:section_matches_query(pack, query)
		end
	end

	local shown = false
	local current_page = window._current
	if query ~= "" then
		for _, pack in ipairs(self.section_list or {}) do
			if pack.window == window and pack.holder and pack.holder.Visible and pack.page == current_page then
				shown = true
				break
			end
		end
	end
	if self.config_search_empty then
		self.config_search_empty.Visible = query ~= "" and not shown
	end
end

function veteran:filter_config_names(names)
	local query = normalize_search_query(self.config_search_query)
	local out = {}
	for _, name in ipairs(names or {}) do
		if query == "" or string.find(string.lower(tostring(name)), query, 1, true) then
			out[#out + 1] = name
		end
	end
	return out
end

function veteran:filter_config_search(query)
	self.config_search_query = tostring(query or "")
	if type(self.config_list_update) == "function" then
		self.config_list_update()
	end
	self:apply_config_section_search({ switch_tab = true })
end

function veteran:find_section(tab, name)
	self.feature_map = self.feature_map or {}
	return self.feature_map[string.lower(tostring(tab or "")) .. "/" .. string.lower(tostring(name or ""))]
end

function veteran:ensure_chrome(name)
	if self.menu_visible == false then
		if self.option_meta and self.option_meta.menu then
			self:set_option("menu", true)
		else
			self:set_menu_visible(true)
		end
	end
	local panel = self:tab_panel(name)
	if not panel then
		return nil
	end
	self.open_tabs = self.open_tabs or {}
	self.open_tabs[name] = true
	self:refresh_tabs()
	self:set_window_open(panel, true)
	self:bring_front(panel)
	return panel
end

function veteran:scroll_to_feature(scroll, target)
	if not scroll or not target or not scroll:IsA("ScrollingFrame") then
		return
	end
	local abs_scroll = scroll.AbsolutePosition.Y
	local abs_target = target.AbsolutePosition.Y
	local next_y = scroll.CanvasPosition.Y + (abs_target - abs_scroll) - 10
	local max_y = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteSize.Y)
	if max_y < 0 then
		max_y = 0
	end
	if next_y < 0 then
		next_y = 0
	elseif next_y > max_y then
		next_y = max_y
	end
	self:cancel_tweens(scroll)
	self:tween(scroll, { CanvasPosition = Vector2.new(0, next_y) }, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
end

local SHELL_BORDER = Color3.fromRGB(10, 10, 10)
local JUMP_HOLD = 0.28
local JUMP_FADE = TWEEN

function veteran:restore_section_pulse(pack)
	if not pack then
		return
	end
	if pack.box then
		self:cancel_tweens(pack.box)
		pack.box.BorderColor3 = SHELL_BORDER
	end
	if pack.inner then
		self:cancel_tweens(pack.inner)
		pack.inner.BorderColor3 = theme["Object Border"]
	end
	if pack.title then
		self:cancel_tweens(pack.title)
		pack.title.TextColor3 = theme.Text
	end
	local scale = pack.holder and pack.holder:FindFirstChild("JumpScale")
	if scale then
		self:cancel_tweens(scale)
		scale.Scale = 1
	end
end

function veteran:restore_control_pulse(pack)
	if not pack then
		return
	end
	if pack.label then
		self:cancel_tweens(pack.label)
		pack.label.TextColor3 = theme.Text
	end
	if pack.well then
		self:cancel_tweens(pack.well)
		local on = pack.get and pack.get()
		pack.well.BorderColor3 = on and theme.Accent or theme["Object Border"]
	end
end

function veteran:clear_jump_highlights()
	for _, pack in ipairs(self._jump_sections or {}) do
		self:restore_section_pulse(pack)
	end
	for _, pack in ipairs(self._jump_controls or {}) do
		self:restore_control_pulse(pack)
	end
	self._jump_sections = {}
	self._jump_controls = {}
end

function veteran:pulse_section(tab, name, should_scroll)
	local pack = self:find_section(tab, name)
	if not pack or not pack.box then
		return
	end
	if should_scroll then
		self:scroll_to_feature(pack.column, pack.holder or pack.box)
	end
	self._jump_sections = self._jump_sections or {}
	table.insert(self._jump_sections, pack)
	local token = self._jump_token
	local scale = pack.holder and pack.holder:FindFirstChild("JumpScale")
	if pack.holder and not scale then
		scale = self:create("UIScale", {
			Parent = pack.holder,
			Name = "JumpScale",
			Scale = 1,
		})
	end
	if scale then
		self:cancel_tweens(scale)
		scale.Scale = 0.92
		self:tween(scale, { Scale = 1.045 }, 0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		task.delay(0.12, function()
			if token ~= self._jump_token or not scale then
				return
			end
			self:tween(scale, { Scale = 1 }, 0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		end)
	end
	if pack.inner then
		self:cancel_tweens(pack.inner)
		pack.inner.BorderColor3 = theme.Accent
	end
	if pack.title then
		self:cancel_tweens(pack.title)
		pack.title.TextColor3 = theme.Accent
	end
	task.delay(JUMP_HOLD, function()
		if token ~= self._jump_token then
			return
		end
		if pack.inner then
			self:tween(pack.inner, { BorderColor3 = theme["Object Border"] }, JUMP_FADE)
		end
		if pack.title then
			self:tween(pack.title, { TextColor3 = theme.Text }, JUMP_FADE)
		end
	end)
end

function veteran:pulse_control(flag)
	local meta = self.option_meta and self.option_meta[flag]
	local pack = meta and meta.pack
	if not pack or not pack.row then
		return
	end
	self._jump_controls = self._jump_controls or {}
	table.insert(self._jump_controls, pack)
	local token = self._jump_token
	if pack.label then
		self:cancel_tweens(pack.label)
		pack.label.TextColor3 = theme.Accent
	end
	if pack.well then
		self:cancel_tweens(pack.well)
		pack.well.BorderColor3 = theme.Accent
	end
	task.delay(JUMP_HOLD, function()
		if token ~= self._jump_token then
			return
		end
		if pack.label then
			self:tween(pack.label, { TextColor3 = theme.Text }, JUMP_FADE)
		end
		if pack.well then
			local on = pack.get and pack.get()
			self:tween(pack.well, {
				BorderColor3 = on and theme.Accent or theme["Object Border"],
			}, JUMP_FADE)
		end
	end)
end

function veteran:reveal_feature(spec)
	spec = spec or {}
	self:clear_jump_highlights()
	self._jump_token = (self._jump_token or 0) + 1
	if spec.chrome then
		self:ensure_chrome(spec.chrome)
		return self
	end
	local window = self.config_window
	if not window then
		return self
	end
	self:ensure_chrome("Configurations")
	local panel = self.config_panel
	if panel then
		local x = 68
		if self.open_tabs and self.open_tabs.info and self.info_panel and self.info_panel.Visible then
			x = INFO_WIDTH + 16
		end
		local dest = UDim2.fromOffset(x, BAR_HEIGHT + 18)
		self:cancel_tweens(panel)
		panel.Position = UDim2.fromOffset(x, BAR_HEIGHT + 36)
		self:tween(panel, { Position = dest }, 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	end
	if spec.tab and window.open_tab then
		if self.config_search and self.config_search.Text ~= "" then
			self.config_search.Text = ""
		end
		window:open_tab(spec.tab)
	end
	local names = spec.sections
	if type(names) ~= "table" then
		names = spec.section and { spec.section } or {}
	end
	task.delay(0.12, function()
		for i, name in ipairs(names) do
			self:pulse_section(spec.tab or "main", name, i == 1)
		end
		if spec.flag then
			self:pulse_control(spec.flag)
		end
	end)
	return self
end

function veteran:register_default_options()
	if self._options_ready then
		return
	end
	self._options_ready = true
	self.options = self.options or {}
	self.flags = self.options
	self.option_meta = self.option_meta or {}
	self.menu_visible = true

	self:add_option({
		flag = "menu",
		name = "menu",
		section = "ui",
		tab = "ui",
		kind = "toggle",
		default = true,
		key = Enum.KeyCode.RightControl,
		mode = "toggle",
		set = function(on)
			self:set_menu_visible(on)
		end,
	})
	self:add_option({
		flag = "backpack_panel",
		name = "backpack",
		section = "ui",
		tab = "ui",
		kind = "button",
		key = Enum.KeyCode.Backquote,
		set = function()
			if self:wants_coregui_redesign() then
				self:set_utility_open("backpack")
			end
		end,
	})
	self:add_option({
		flag = "emotes_panel",
		name = "emotes",
		section = "ui",
		tab = "ui",
		kind = "button",
		key = Enum.KeyCode.Period,
		set = function()
			if self:wants_coregui_redesign() then
				self:set_utility_open("emotes")
			end
		end,
	})
	self:add_option({
		flag = "watermark",
		name = "watermark",
		section = "ui",
		tab = "ui",
		kind = "toggle",
		default = true,
		mode = "toggle",
		set = function(on)
			self:set_watermark_opt("enabled", on)
		end,
	})
	self:add_option({
		flag = "copy_user",
		name = "copy user id",
		section = "actions",
		tab = "ui",
		kind = "button",
		set = function()
			local lp = players.LocalPlayer
			if lp then
				pcall(function()
					setclipboard(tostring(lp.UserId))
				end)
			end
		end,
	})
	self:add_option({
		flag = "copy_job",
		name = "copy job id",
		section = "actions",
		tab = "ui",
		kind = "button",
		set = function()
			pcall(function()
				setclipboard(tostring(game.JobId))
			end)
		end,
	})
	self:add_option({
		flag = "copy_place",
		name = "copy place id",
		section = "actions",
		tab = "ui",
		kind = "button",
		set = function()
			pcall(function()
				setclipboard(tostring(game.PlaceId))
			end)
		end,
	})
	self:add_option({
		flag = "unload",
		name = "unload",
		section = "actions",
		tab = "ui",
		kind = "button",
		set = function()
			self:unload()
		end,
	})

	self._applying_options = true
	local loaded = self:load_config()
	local loaded_opts = loaded and type(loaded.options) == "table" and loaded.options or nil
	if (not loaded_opts or loaded_opts.watermark == nil) and self.watermark_opts then
		self.options.watermark = self.watermark_opts.enabled == true
	end
	local menu = self.option_meta.menu
	if menu and not menu.key then
		menu.key = Enum.KeyCode.RightControl
	end
	for _, meta in pairs(self.option_meta) do
		if meta.kind == "toggle" or meta.kind == "slider" or meta.kind == "dropdown" or meta.kind == "text" then
			local value = self.options[meta.flag]
			if value == nil then
				value = meta.default
				self.options[meta.flag] = value
			end
			if meta.set and value ~= nil then
				meta.set(value)
			end
		end
	end
	self._applying_options = false
end

function veteran:column_list(parent, position, size)
	local column = self:create("ScrollingFrame", {
		Parent = parent,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = theme.Accent,
		Theme = "Accent",
		ThemeProp = "ScrollBarImageColor3",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 52,
	})
	self:create("UIPadding", {
		Parent = column,
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 12),
	})
	self:create("UIListLayout", {
		Parent = column,
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return column
end

function veteran:make_chat_filter(page, opt)
	opt = opt or {}
	local side = opt.side == "left" and "left" or "right"
	local flag = opt.flag or "chat_filter_keywords"
	local enabled_flag = opt.enabled_flag or "chat_filter_enabled"
	page._order[side] += 1

	self:add_option({
		flag = enabled_flag,
		name = (opt.name or "chat filter") .. " enabled",
		section = opt.name or "chat filter",
		tab = page.name or "main",
		kind = "toggle",
		default = true,
	})
	self:add_option({
		flag = flag,
		name = opt.name or "chat filter",
		section = opt.name or "chat filter",
		kind = "dropdown",
		multi = true,
		default = {},
	})

	local holder = self:create("Frame", {
		Parent = page[side],
		Size = UDim2.new(1, 0, 0, opt.height or 280),
		BackgroundTransparency = 1,
		LayoutOrder = page._order[side],
		ZIndex = 53,
	})
	local box = self:create("Frame", {
		Parent = holder,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 1, -8),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		ZIndex = 53,
	})
	local inner = self:create("Frame", {
		Parent = box,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 54,
	})
	self:create("TextLabel", {
		Parent = box,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -70, 0, 1),
		Font = Enum.Font.SourceSans,
		Text = opt.name or "chat filter",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 56,
	})

	local on_btn = self:create("TextButton", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -70, 0, 4),
		Size = UDim2.fromOffset(28, 14),
		Font = Enum.Font.SourceSans,
		Text = "on",
		TextSize = TEXT_SIZE,
		TextColor3 = theme.Accent,
		AutoButtonColor = false,
		ZIndex = 56,
	})
	local clear_btn = self:create("TextButton", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -38, 0, 4),
		Size = UDim2.fromOffset(30, 14),
		Font = Enum.Font.SourceSans,
		Text = "clear",
		TextSize = TEXT_SIZE,
		TextColor3 = theme["Disabled Text"],
		AutoButtonColor = false,
		ZIndex = 56,
	})

	local shell, well = self:make_shell(inner, {
		size = UDim2.new(1, -16, 0, 18),
		z = 55,
	})
	shell.Position = UDim2.fromOffset(8, 18)
	shell.Size = UDim2.new(1, -16, 0, 18)
	local box_in = self:create("TextBox", {
		Parent = well,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSans,
		Text = "",
		PlaceholderText = opt.placeholder or "type a keyword...",
		PlaceholderColor3 = theme["Disabled Text"],
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 58,
	})
	self:create("UIPadding", {
		Parent = box_in,
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})

	local chips = self:create("ScrollingFrame", {
		Parent = inner,
		Position = UDim2.fromOffset(8, 42),
		Size = UDim2.new(1, -16, 0, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 55,
	})
	self:create("UIListLayout", {
		Parent = chips,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local log = self:create("ScrollingFrame", {
		Parent = inner,
		Position = UDim2.fromOffset(8, 84),
		Size = UDim2.new(1, -16, 1, -92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 55,
	})
	self:create("UIListLayout", {
		Parent = log,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local empty = self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 86),
		Size = UDim2.new(1, -20, 0, 18),
		Font = Enum.Font.SourceSans,
		Text = "press enter to add a keyword",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 56,
	})

	local keywords = {}
	local keyword_set = {}
	local keyword_chips = {}
	local logged = {}
	local row_count = 0
	local next_order = 0
	local skip_self = opt.skip_self ~= false

	local function sync_flag()
		local copy = {}
		for i, word in ipairs(keywords) do
			copy[i] = word
		end
		self.options[flag] = copy
	end

	local function set_empty()
		if row_count > 0 then
			empty.Visible = false
			return
		end
		empty.Visible = true
		if not self:get_option(enabled_flag) then
			empty.Text = "filter is off"
		elseif #keywords == 0 then
			empty.Text = "press enter to add a keyword"
		else
			empty.Text = "no matches yet"
		end
	end

	local function paint_toggle()
		local on = self:get_option(enabled_flag) == true
		on_btn.Text = on and "on" or "off"
		on_btn.TextColor3 = on and theme.Accent or theme["Disabled Text"]
		set_empty()
	end

	local function remove_keyword(word)
		local key = string.lower(word)
		if keyword_chips[key] then
			keyword_chips[key]:Destroy()
			keyword_chips[key] = nil
		end
		keyword_set[key] = nil
		for i = #keywords, 1, -1 do
			if string.lower(keywords[i]) == key then
				table.remove(keywords, i)
			end
		end
		sync_flag()
		set_empty()
	end

	local function add_keyword(word)
		word = tostring(word or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if word == "" then
			return
		end
		local key = string.lower(word)
		if keyword_set[key] then
			return
		end
		keyword_set[key] = true
		table.insert(keywords, word)
		local chip = self:create("Frame", {
			Parent = chips,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			BackgroundColor3 = theme["Object Background"],
			Theme = "Object Background",
			ThemeProp = "BackgroundColor3",
			ThemeBorder = "Object Border",
			BorderSizePixel = 1,
			ZIndex = 56,
		})
		self:create("UIPadding", {
			Parent = chip,
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 4),
		})
		self:create("UIListLayout", {
			Parent = chip,
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
		})
		self:create("TextLabel", {
			Parent = chip,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			Font = Enum.Font.SourceSans,
			Text = word,
			TextSize = TEXT_SIZE,
			ThemeText = "Text",
			ZIndex = 57,
		})
		local close = self:create("TextButton", {
			Parent = chip,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(10, 16),
			Font = Enum.Font.SourceSans,
			Text = "x",
			TextSize = TEXT_SIZE,
			TextColor3 = theme["Disabled Text"],
			AutoButtonColor = false,
			ZIndex = 57,
		})
		self:connect(close.MouseButton1Click, function()
			remove_keyword(word)
		end)
		keyword_chips[key] = chip
		sync_flag()
		set_empty()
	end

	local function add_row(player)
		local user_id = player.UserId
		if logged[user_id] then
			next_order -= 1
			logged[user_id].LayoutOrder = next_order
			return
		end
		row_count += 1
		next_order -= 1
		local row = self:create("TextButton", {
			Parent = log,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = next_order,
			ZIndex = 56,
		})
		self:create("TextLabel", {
			Parent = row,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 0, 14),
			Font = Enum.Font.SourceSans,
			Text = player.DisplayName,
			TextSize = TEXT_SIZE,
			ThemeText = "Text",
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 57,
		})
		self:create("TextLabel", {
			Parent = row,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 16),
			Size = UDim2.new(1, -4, 0, 12),
			Font = Enum.Font.SourceSans,
			Text = tostring(user_id),
			TextSize = TEXT_SIZE,
			ThemeText = "Disabled Text",
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 57,
		})
		self:connect(row.MouseButton1Click, function()
			pcall(function()
				setclipboard(player.DisplayName .. " | " .. tostring(user_id))
			end)
			self:notification({ text = "copied " .. player.DisplayName, duration = 2 })
		end)
		logged[user_id] = row
		set_empty()
	end

	local function matches(message)
		local lower = string.lower(message)
		for _, word in ipairs(keywords) do
			if string.find(lower, string.lower(word), 1, true) then
				return true
			end
		end
		return false
	end

	self:connect(on_btn.MouseButton1Click, function()
		self:set_option(enabled_flag, not self:get_option(enabled_flag))
		paint_toggle()
	end)
	self:connect(clear_btn.MouseButton1Click, function()
		for _, child in ipairs(log:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		table.clear(logged)
		row_count = 0
		set_empty()
	end)
	self:connect(box_in.FocusLost, function(enter)
		if enter then
			add_keyword(box_in.Text)
			box_in.Text = ""
		end
	end)
	self:connect(box_in.Focused, function()
		self:tween(well, { BorderColor3 = theme.Accent }, TWEEN)
	end)
	self:connect(box_in:GetPropertyChangedSignal("Text"), function()
		-- keep
	end)

	local lp = players.LocalPlayer
	local function hook_player(player)
		self:connect(player.Chatted, function(message)
			if not self:get_option(enabled_flag) then
				return
			end
			if skip_self and player == lp then
				return
			end
			if #keywords == 0 or not matches(message) then
				return
			end
			add_row(player)
		end)
	end
	for _, player in ipairs(players:GetPlayers()) do
		hook_player(player)
	end
	self:connect(players.PlayerAdded, hook_player)

	local saved = self:get_option(flag)
	if type(saved) == "table" then
		for _, word in ipairs(saved) do
			add_keyword(word)
		end
	end
	paint_toggle()
	return holder
end

function veteran:window(props)
	props = props or {}
	local name = props.name or "window"
	if self.config_window and (name == "configurations" or props.tab == "Configurations") then
		if props.size then
			self.config_window.frame.Size = props.size
		end
		return self.config_window
	end

	local size = props.size or UDim2.fromOffset(560, 430)
	local position = props.position or UDim2.fromOffset(68, BAR_HEIGHT + 18)

	local panel, inner = self:make_panel({
		Parent = self.gui,
		Name = props.frame_name or "ConfigPanel",
		Position = position,
		Size = size,
		Visible = false,
		ZIndex = 50,
	})

	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -176, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = name,
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 52,
	})

	local tab_bar = self:create("Frame", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 24),
		Size = UDim2.new(1, -16, 0, 20),
		Visible = false,
		ZIndex = 52,
	})
	self:create("UIListLayout", {
		Parent = tab_bar,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	})
	local tab_rule = self:create("Frame", {
		Parent = inner,
		Position = UDim2.fromOffset(8, 44),
		Size = UDim2.new(1, -16, 0, 1),
		BackgroundColor3 = theme["Object Border"],
		Theme = "Object Border",
		ThemeProp = "BackgroundColor3",
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 52,
	})

	local pages = self:create("Frame", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 26),
		Size = UDim2.new(1, -16, 1, -34),
		ClipsDescendants = true,
		ZIndex = 52,
	})

	local handle = self:drag_handle(panel)
	handle.Size = UDim2.new(1, -176, 0, 26)

	local search = self:create("TextBox", {
		Parent = inner,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 4),
		Size = UDim2.fromOffset(156, 18),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		ThemeText = "Text",
		BorderSizePixel = 1,
		Font = Enum.Font.SourceSans,
		TextSize = TEXT_SIZE,
		Text = "",
		PlaceholderText = "search",
		PlaceholderColor3 = theme["Disabled Text"],
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 95,
		Active = true,
	})
	self:create("UIPadding", {
		Parent = search,
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	self.config_search = search
	self:connect(search:GetPropertyChangedSignal("Text"), function()
		self:filter_config_search(search.Text)
	end)
	self:connect(search.Focused, function()
		search.BorderColor3 = theme.Accent
	end)
	self:connect(search.FocusLost, function()
		search.BorderColor3 = theme["Object Border"]
	end)

	local search_empty = self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.new(1, -32, 0, 18),
		Font = Enum.Font.SourceSans,
		Text = "no matches",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		Visible = false,
		ZIndex = 54,
	})
	self.config_search_empty = search_empty

	local ui = self
	local window = {
		ui = ui,
		frame = panel,
		inner = inner,
		pages = {},
		tab_buttons = {},
		_tab_order = 0,
		_current = nil,
	}

	local function layout_pages()
		local has_tabs = window._tab_order > 0
		tab_bar.Visible = has_tabs
		tab_rule.Visible = has_tabs
		if has_tabs then
			pages.Position = UDim2.fromOffset(8, 48)
			pages.Size = UDim2.new(1, -16, 1, -56)
		else
			pages.Position = UDim2.fromOffset(8, 26)
			pages.Size = UDim2.new(1, -16, 1, -34)
		end
	end

	local function paint_tabs(instant)
		for tab_name, btn in pairs(window.tab_buttons) do
			local on = window._current and window._current.name == tab_name
			local text = on and theme.Text or theme["Disabled Text"]
			local line_alpha = on and 0 or 1
			btn.line.Visible = true
			if instant then
				btn.label.TextColor3 = text
				btn.line.BackgroundColor3 = theme.Accent
				btn.line.BackgroundTransparency = line_alpha
			else
				ui:tween(btn.label, { TextColor3 = text }, TWEEN)
				ui:tween(btn.line, {
					BackgroundColor3 = theme.Accent,
					BackgroundTransparency = line_alpha,
				}, TWEEN)
			end
		end
	end

	local function make_section(page, section_props)
		section_props = section_props or {}
		local side = section_props.side == "right" and "right" or "left"
		local parent = page[side]
		page._order[side] += 1

		local holder = ui:create("Frame", {
			Parent = parent,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = page._order[side],
			ZIndex = 53,
		})
		local box = ui:create("Frame", {
			Parent = holder,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			BorderColor3 = Color3.fromRGB(10, 10, 10),
			BorderSizePixel = 1,
			ZIndex = 53,
		})
		local inner_sec = ui:create("Frame", {
			Parent = box,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = theme["Section Background"],
			Theme = "Section Background",
			ThemeProp = "BackgroundColor3",
			ThemeBorder = "Object Border",
			BorderSizePixel = 1,
			ZIndex = 54,
		})
		ui:create("UIPadding", {
			Parent = inner_sec,
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		})
		ui:create("UIListLayout", {
			Parent = inner_sec,
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		local title = ui:create("TextLabel", {
			Parent = box,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -16, 0, 1),
			Font = Enum.Font.SourceSans,
			Text = section_props.name or "section",
			TextSize = TITLE_SIZE,
			ThemeText = "Text",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			ZIndex = 56,
		})

		local section = {
			ui = ui,
			window = window,
			page = page,
			box = inner_sec,
			holder = holder,
			shell = box,
			name = section_props.name or "section",
			_order = 1,
		}
		local section_pack = {
			holder = holder,
			box = box,
			inner = inner_sec,
			title = title,
			column = parent,
			page = page,
			window = window,
			name = section.name,
			_search = {
				string.lower(section.name),
				string.lower(tostring(page.name or "")),
			},
		}
		section.pack = section_pack
		ui:register_section(page.name, section.name, section_pack)

		local function remember(text)
			if type(text) ~= "string" then
				return
			end
			text = string.lower(text)
			if text == "" then
				return
			end
			section_pack._search[#section_pack._search + 1] = text
		end

		function section:toggle(opt)
			opt = opt or {}
			self._order += 1
			local flag = opt.flag
			if flag then
				ui:add_option({
					flag = flag,
					name = display_name(opt.name, flag),
					section = self.name,
					tab = bind_tab(self),
					kind = "toggle",
					default = opt.default and true or false,
					set = opt.callback or opt.set,
				})
			end
			remember(display_name(opt.name, flag, "toggle"))
			local pack = ui:make_toggle(inner_sec, {
				name = display_name(opt.name, flag, "toggle"),
				flag = flag,
				layout_order = self._order,
				color = opt.color,
				section = self.name,
				get = opt.get or function()
					if flag then
						return ui:get_option(flag)
					end
					return false
				end,
				set = function(on)
					if flag then
						ui:set_option(flag, on)
					elseif opt.callback then
						opt.callback(on)
					elseif opt.set then
						opt.set(on)
					end
				end,
			})
			ui:refresh_keybind_list()
			return pack
		end

		function section:colorpicker(opt)
			opt = opt or {}
			self._order += 1
			local flag = opt.flag
			local default = opt.default or opt.color or theme.Accent
			if flag then
				ui:add_option({
					flag = flag,
					name = display_name(opt.name, flag),
					section = self.name,
					kind = "color",
					default = rgb_table_from(default),
					set = opt.callback or opt.set,
				})
			end
			remember(display_name(opt.name, flag, "color"))
			local pack = ui:make_color(inner_sec, {
				name = display_name(opt.name, flag, "color"),
				flag = flag,
				layout_order = self._order,
				get = opt.get or function()
					if flag then
						return color_from_rgb_table(ui:get_option(flag)) or default
					end
					return default
				end,
				set = function(color)
					if flag then
						ui:set_option(flag, color)
					elseif opt.callback then
						opt.callback(color)
					elseif opt.set then
						opt.set(color)
					end
				end,
			})
			return pack
		end

		function section:slider(opt)
			opt = opt or {}
			self._order += 1
			local flag = opt.flag
			local min_v = opt.min or opt.minimum or 0
			local max_v = opt.max or opt.maximum or 100
			local default = opt.default
			if default == nil then
				default = min_v
			end
			if flag then
				ui:add_option({
					flag = flag,
					name = display_name(opt.name, flag),
					section = self.name,
					kind = "slider",
					default = default,
					min = min_v,
					max = max_v,
					set = opt.callback or opt.set,
				})
			end
			remember(display_name(opt.name, flag, "slider"))
			return ui:make_slider(inner_sec, {
				name = display_name(opt.name, flag, "slider"),
				flag = flag,
				layout_order = self._order,
				min = min_v,
				max = max_v,
				interval = opt.interval or opt.step or opt.decimal,
				suffix = opt.suffix,
				get = opt.get or function()
					if flag then
						return ui:get_option(flag)
					end
					return default
				end,
				set = function(value)
					if flag then
						ui:set_option(flag, value)
					elseif opt.callback then
						opt.callback(value)
					elseif opt.set then
						opt.set(value)
					end
				end,
			})
		end

		function section:dropdown(opt)
			opt = opt or {}
			self._order += 1
			local flag = opt.flag
			local items = opt.items or opt.options or { "none" }
			local multi = opt.multi == true
			local default = opt.default
			if default == nil then
				default = multi and {} or items[1]
			end
			if flag then
				ui:add_option({
					flag = flag,
					name = display_name(opt.name, flag),
					section = self.name,
					kind = "dropdown",
					default = default,
					items = items,
					multi = multi,
					set = opt.callback or opt.set,
				})
			end
			remember(display_name(opt.name, flag, "dropdown"))
			if type(items) == "table" then
				for _, item in ipairs(items) do
					if type(item) == "string" then
						remember(item)
					end
				end
			end
			return ui:make_dropdown(inner_sec, {
				name = display_name(opt.name, flag, "dropdown"),
				flag = flag,
				layout_order = self._order,
				items = items,
				multi = multi,
				get = opt.get or function()
					if flag then
						return ui:get_option(flag)
					end
					return default
				end,
				set = function(value)
					if flag then
						ui:set_option(flag, value)
					elseif opt.callback then
						opt.callback(value)
					elseif opt.set then
						opt.set(value)
					end
				end,
			})
		end

		function section:button(opt)
			opt = opt or {}
			self._order += 1
			local flag = opt.flag
			if flag then
				ui:add_option({
					flag = flag,
					name = display_name(opt.name, flag),
					section = self.name,
					tab = bind_tab(self),
					kind = "button",
					set = opt.callback or opt.set,
				})
			end
			remember(display_name(opt.name, flag, "button"))
			local pack = ui:make_button(inner_sec, {
				name = display_name(opt.name, flag, "button"),
				flag = flag,
				layout_order = self._order,
				set = function()
					if flag then
						ui:set_option(flag, true)
					elseif opt.callback then
						opt.callback()
					elseif opt.set then
						opt.set()
					end
				end,
			})
			if flag then
				ui:refresh_keybind_list()
			end
			return pack
		end

		function section:textbox(opt)
			opt = opt or {}
			self._order += 1
			local flag = opt.flag
			local default = opt.default or ""
			if flag then
				ui:add_option({
					flag = flag,
					name = display_name(opt.name, flag),
					section = self.name,
					kind = "text",
					default = default,
					set = opt.callback or opt.set,
				})
			end
			remember(display_name(opt.name, flag, "textbox"))
			return ui:make_textbox(inner_sec, {
				name = display_name(opt.name, flag),
				flag = flag,
				layout_order = self._order,
				placeholder = opt.placeholder,
				clear_on_focus = opt.clear_on_focus,
				get = opt.get or function()
					if flag then
						return ui:get_option(flag)
					end
					return default
				end,
				set = function(value)
					if flag then
						ui:set_option(flag, value)
					elseif opt.callback then
						opt.callback(value)
					elseif opt.set then
						opt.set(value)
					end
				end,
			})
		end

		function section:keybind(opt)
			opt = opt or {}
			self._order += 1
			local flag = opt.flag
			local default_key = opt.default or opt.key
			if flag then
				ui:add_option({
					flag = flag,
					name = display_name(opt.name, flag),
					section = self.name,
					tab = bind_tab(self),
					kind = "keybind",
					default = default_key,
					key = typeof(default_key) == "EnumItem" and default_key or nil,
					set = opt.callback or opt.set,
				})
			end
			remember(display_name(opt.name, flag, "keybind"))
			local pack = ui:make_keybind(inner_sec, {
				name = display_name(opt.name, flag, "keybind"),
				flag = flag,
				layout_order = self._order,
			})
			if flag then
				ui:refresh_keybind_list()
			end
			return pack
		end

		section.color = section.colorpicker
		return section
	end

	function window:resize(next_size)
		if typeof(next_size) == "UDim2" then
			panel.Size = next_size
		end
		return self
	end

	function window:open_tab(tab_name)
		local page = self.pages[tab_name]
		if not page then
			return self
		end
		ui:close_dropdown()
		for _, other in pairs(self.pages) do
			other.frame.Visible = other == page
		end
		self._current = page
		self.left = page.left
		self.right = page.right
		self._order = page._order
		paint_tabs(not self._tabs_painted)
		self._tabs_painted = true
		if ui.config_window == self then
			ui:apply_config_section_search({ switch_tab = false })
		end
		return page
	end

	function window:tab(tab_props)
		tab_props = tab_props or {}
		local tab_name = string.lower(tab_props.name or "main")
		if self.pages[tab_name] then
			return self:open_tab(tab_name)
		end

		self._tab_order += 1
		layout_pages()

		local btn = ui:create("TextButton", {
			Parent = tab_bar,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSans,
			Text = tab_name,
			TextSize = TEXT_SIZE,
			TextColor3 = theme["Disabled Text"],
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			AutoButtonColor = false,
			LayoutOrder = self._tab_order,
			ZIndex = 53,
		})
		local line = ui:create("Frame", {
			Parent = btn,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = theme.Accent,
			Theme = "Accent",
			ThemeProp = "BackgroundColor3",
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Visible = true,
			ZIndex = 54,
		})
		self.tab_buttons[tab_name] = { button = btn, label = btn, line = line }

		local page_frame = ui:create("Frame", {
			Parent = pages,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ClipsDescendants = true,
			ZIndex = 52,
		})
		local page = {
			name = tab_name,
			frame = page_frame,
			left = ui:column_list(page_frame, UDim2.fromScale(0, 0), UDim2.new(0.5, -5, 1, 0)),
			right = ui:column_list(page_frame, UDim2.new(0.5, 5, 0, 0), UDim2.new(0.5, -5, 1, 0)),
			_order = { left = 0, right = 0 },
		}
		function page:section(section_props)
			return make_section(self, section_props)
		end
		function page:chat_filter(opt)
			return ui:make_chat_filter(self, opt)
		end
		function page.open_tab()
			window:open_tab(tab_name)
			return page
		end
		page.open = page.open_tab
		self.pages[tab_name] = page

		ui:connect(btn.MouseEnter, function()
			if window._current and window._current.name == tab_name then
				return
			end
			ui:tween(btn, { TextColor3 = theme.Text }, TWEEN)
		end)
		ui:connect(btn.MouseLeave, function()
			if window._current and window._current.name == tab_name then
				return
			end
			ui:tween(btn, { TextColor3 = theme["Disabled Text"] }, TWEEN)
		end)
		ui:connect(btn.MouseButton1Click, function()
			window:open_tab(tab_name)
		end)

		if not self._current then
			self:open_tab(tab_name)
		else
			paint_tabs(true)
		end
		return page
	end

	function window:section(section_props)
		local page = self._current
		if not page then
			page = self:tab({ name = "main" })
		end
		return page:section(section_props)
	end

	if name == "configurations" or props.tab == "Configurations" then
		self.config_window = window
		self.config_panel = panel
	end
	return window
end

function veteran:build_configurations()
	self:register_default_options()
	self:window({
		name = "configurations",
		tab = "Configurations",
		size = UDim2.fromOffset(560, 430),
		position = UDim2.fromOffset(68, BAR_HEIGHT + 18),
		frame_name = "ConfigPanel",
	})
	self:listen_keys()
end

function veteran:build_keybinds()
	self:register_default_options()
	self.keybind_tab = self.keybind_tab or "all"

	local panel, inner = self:make_panel({
		Parent = self.gui,
		Name = "KeybindsPanel",
		Position = UDim2.fromOffset(300, BAR_HEIGHT + 18),
		Size = UDim2.fromOffset(480, 430),
		Visible = false,
		ZIndex = 50,
	})
	self.keybinds_panel = panel

	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "keybinds",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 52,
	})

	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 24),
		Size = UDim2.new(1, -16, 0, 14),
		Font = Enum.Font.SourceSans,
		Text = "left click bind · right click hold/toggle · esc clears",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 52,
	})

	local search = self:create("TextBox", {
		Parent = inner,
		Position = UDim2.fromOffset(8, 44),
		Size = UDim2.new(1, -16, 0, 18),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		ThemeText = "Text",
		BorderSizePixel = 1,
		Font = Enum.Font.SourceSans,
		TextSize = TEXT_SIZE,
		Text = "",
		PlaceholderText = "search keybinds",
		PlaceholderColor3 = theme["Disabled Text"],
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 53,
	})
	self:create("UIPadding", {
		Parent = search,
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	self.keybind_search = search
	self:connect(search:GetPropertyChangedSignal("Text"), function()
		self:refresh_keybind_list()
	end)

	local tabs = self:create("ScrollingFrame", {
		Parent = inner,
		Position = UDim2.fromOffset(8, 68),
		Size = UDim2.new(1, -16, 0, 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ZIndex = 53,
	})
	self:create("UIListLayout", {
		Parent = tabs,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	self.keybind_tabs = tabs

	local list_outer = self:create("Frame", {
		Parent = inner,
		Position = UDim2.fromOffset(8, 94),
		Size = UDim2.new(1, -16, 1, self:can_coregui_rewrite() and -198 or -110),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		ZIndex = 52,
	})
	local list_wrap = self:create("Frame", {
		Parent = list_outer,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 52,
	})
	local list = self:create("ScrollingFrame", {
		Parent = list_wrap,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = theme.Accent,
		Theme = "Accent",
		ThemeProp = "ScrollBarImageColor3",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 53,
	})
	self:create("UIPadding", {
		Parent = list,
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	self:create("UIListLayout", {
		Parent = list,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self.keybind_list = list

	self.keybind_empty = self:create("TextLabel", {
		Parent = list_wrap,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.SourceSans,
		Text = "no keybinds",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 54,
		Visible = false,
	})

	if self:can_coregui_rewrite() then
	local layout_outer = self:create("Frame", {
		Parent = inner,
		Position = UDim2.new(0, 8, 1, -96),
		Size = UDim2.new(1, -16, 0, 88),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		ZIndex = 52,
	})
	local layout_wrap = self:create("Frame", {
		Parent = layout_outer,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 52,
	})
	self:create("TextLabel", {
		Parent = layout_wrap,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 2),
		Size = UDim2.new(1, -16, 0, 14),
		Font = Enum.Font.SourceSans,
		Text = "hotbar",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 54,
	})
	local layout_list = self:create("Frame", {
		Parent = layout_wrap,
		Position = UDim2.fromOffset(6, 16),
		Size = UDim2.new(1, -12, 1, -20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 53,
	})
	self:create("UIListLayout", {
		Parent = layout_list,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self.layout_packs = self.layout_packs or {}
		self:make_layout_sliders(layout_list)
	end

	self:drag_handle(panel)
	self:refresh_keybind_list()
	self:listen_keys()
end

function veteran:set_panel_status(text)
	if self.staff_status then
		self.staff_status.Text = text or ""
	end
end

function veteran:join_veteran(row)
	if type(row) ~= "table" then
		return
	end
	local place = tonumber(row.place_id)
	local job = tostring(row.job_id or "")
	if not place or job == "" then
		self:set_panel_status("no server")
		return
	end
	if place == game.PlaceId and job == tostring(game.JobId) then
		self:set_panel_status("already here")
		return
	end
	self:set_panel_status("joining " .. tostring(row.username or "veteran"))
	pcall(function()
		teleport_service:TeleportToPlaceInstance(place, job, players.LocalPlayer)
	end)
end

function veteran:bring_to_user(user_id)
	user_id = tonumber(user_id)
	local target = user_id and players:GetPlayerByUserId(user_id)
	local lp = players.LocalPlayer
	if not target or not lp then
		return
	end
	local function root(plr)
		local char = plr.Character
		if not char then
			return nil
		end
		return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
	end
	local mine, theirs = root(lp), root(target)
	if mine and theirs then
		mine.CFrame = theirs.CFrame * CFrame.new(0, 0, 3)
	end
end

function veteran:apply_staff_command(cmd)
	if type(cmd) ~= "table" or cmd.action ~= "bring" then
		return
	end
	local place = tonumber(cmd.place_id)
	local job = tostring(cmd.job_id or "")
	if place and place == game.PlaceId and job == tostring(game.JobId) then
		self:bring_to_user(cmd.from_user_id)
		return
	end
	if place and job ~= "" then
		pcall(function()
			teleport_service:TeleportToPlaceInstance(place, job, players.LocalPlayer)
		end)
	end
end

function veteran:poll_staff_command()
	local payload = self:ops("poll")
	if payload and payload.command then
		self:apply_staff_command(payload.command)
	end
end

function veteran:bring_veteran(row)
	if type(row) ~= "table" then
		return
	end
	if row.can_bring ~= true then
		self:set_panel_status("cannot bring staff")
		return
	end
	self:set_panel_status("bringing " .. tostring(row.username or "veteran"))
	local payload = self:ops("bring", { target_user_id = tonumber(row.user_id) })
	if not payload then
		self:set_panel_status("bring failed")
		return
	end
	if payload.ok then
		self:set_panel_status("bring sent")
		return
	end
	self:set_panel_status(payload.reason or "bring failed")
end

function veteran:select_staff_row(row)
	self._panel_selected = row
	self:refresh_staff_actions()
	if self.staff_list then
		for _, child in ipairs(self.staff_list:GetChildren()) do
			if child:IsA("TextButton") then
				local selected = tonumber(child:GetAttribute("UserId")) == tonumber(row and row.user_id)
				child.BackgroundTransparency = selected and 0 or 1
				child.BackgroundColor3 = selected and theme["Tab Toggle Background"] or theme["Dropdown Option Background"]
			end
		end
	end
end

function veteran:refresh_staff_actions()
	local row = self._panel_selected
	local join = self.staff_join
	local bring = self.staff_bring
	if not join or not bring then
		return
	end
	if type(row) ~= "table" then
		join.Visible = false
		bring.Visible = false
		return
	end
	join.Visible = row.self ~= true
	bring.Visible = row.can_bring == true
end

function veteran:refresh_staff_panel(quiet)
	if not self.staff_list then
		return
	end
	if not quiet then
		self:set_panel_status("loading")
	end
	local payload, err = self:ops("live")
	for _, child in ipairs(self.staff_list:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	if not payload then
		self.staff_empty.Visible = true
		self.staff_empty.Text = err or "could not load"
		self:set_panel_status(err or "could not load")
		self._panel_selected = nil
		self:refresh_staff_actions()
		return
	end
	if payload.ok ~= true then
		self.staff_empty.Visible = true
		self.staff_empty.Text = payload.reason or "could not load"
		self:set_panel_status(payload.reason or "could not load")
		self._panel_selected = nil
		self:refresh_staff_actions()
		return
	end
	local rows = payload.players or {}
	if #rows == 0 then
		self.staff_empty.Visible = true
		self.staff_empty.Text = "no veteran live"
		self:set_panel_status("no veteran live")
		self._panel_selected = nil
		self:refresh_staff_actions()
		return
	end
	self.staff_empty.Visible = false
	local selected_id = self._panel_selected and tonumber(self._panel_selected.user_id)
	local keep
	for i, row in ipairs(rows) do
		if tonumber(row.user_id) == selected_id then
			keep = row
		end
		local selected = tonumber(row.user_id) == selected_id
		local btn = self:create("TextButton", {
			Parent = self.staff_list,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = selected and theme["Tab Toggle Background"] or theme["Dropdown Option Background"],
			BackgroundTransparency = selected and 0 or 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = i,
			ZIndex = 58,
		})
		btn:SetAttribute("UserId", tonumber(row.user_id) or 0)
		local game_name = row.game
		if type(game_name) ~= "string" or game_name == "" then
			game_name = tostring(row.place_id or "—")
		end
		local here = row.same_server and " · here" or (row.same_place and " · this game" or "")
		self:create("TextLabel", {
			Parent = btn,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -16, 0, 16),
			Font = Enum.Font.SourceSans,
			Text = string.format("%s  %s%s", tostring(row.username or "unknown"), tostring(row.role or "veteran"), row.self and " · you" or ""),
			TextSize = TEXT_SIZE,
			ThemeText = "Text",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			ZIndex = 59,
		})
		self:create("TextLabel", {
			Parent = btn,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 14),
			Size = UDim2.new(1, -16, 0, 12),
			Font = Enum.Font.SourceSans,
			Text = game_name .. here,
			TextSize = 12,
			ThemeText = "Disabled Text",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			ZIndex = 59,
		})
		self:connect(btn.MouseButton1Click, function()
			self:select_staff_row(row)
		end)
	end
	if keep then
		self._panel_selected = keep
	elseif selected_id then
		self._panel_selected = nil
	end
	self:refresh_staff_actions()
	self:set_panel_status(string.format("%d live", #rows))
end

function veteran:build_staff_panel()
	if not self:can_staff_panel() then
		return
	end
	local panel, inner = self:make_panel({
		Parent = self.gui,
		Name = "StaffPanel",
		Position = UDim2.fromOffset(300, BAR_HEIGHT + 18),
		Size = UDim2.fromOffset(480, 430),
		Visible = false,
		ZIndex = 50,
	})
	self.staff_panel = panel

	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -90, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "panel",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 52,
	})

	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 24),
		Size = UDim2.new(1, -16, 0, 14),
		Font = Enum.Font.SourceSans,
		Text = "live veteran · join their server · bring if they are in this game",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 52,
	})

	local refresh = self:create("TextButton", {
		Parent = inner,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(72, 18),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 53,
	})
	self:create("TextLabel", {
		Parent = refresh,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.SourceSans,
		Text = "refresh",
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		ZIndex = 54,
	})
	self:animate_button(refresh, function()
		return theme["Object Background"]
	end)
	self:connect(refresh.MouseButton1Click, function()
		self:refresh_staff_panel()
	end)

	local list = self:create("ScrollingFrame", {
		Parent = inner,
		Position = UDim2.fromOffset(8, 46),
		Size = UDim2.new(1, -16, 1, -92),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 52,
	})
	self:create("UIListLayout", {
		Parent = list,
		Padding = UDim.new(0, 1),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self:create("UIPadding", {
		Parent = list,
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
	})
	self.staff_list = list

	self.staff_empty = self:create("TextLabel", {
		Parent = list,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.SourceSans,
		Text = "no veteran live",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		ZIndex = 53,
	})

	local actions = self:create("Frame", {
		Parent = inner,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.new(1, -16, 0, 34),
		BackgroundTransparency = 1,
		ZIndex = 52,
	})

	local join = self:create("TextButton", {
		Parent = actions,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromOffset(72, 20),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 53,
	})
	self:create("TextLabel", {
		Parent = join,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.SourceSans,
		Text = "join",
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		ZIndex = 54,
	})
	self:animate_button(join, function()
		return theme["Object Background"]
	end)
	self:connect(join.MouseButton1Click, function()
		self:join_veteran(self._panel_selected)
	end)
	self.staff_join = join

	local bring = self:create("TextButton", {
		Parent = actions,
		Position = UDim2.fromOffset(80, 8),
		Size = UDim2.fromOffset(72, 20),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 53,
	})
	self:create("TextLabel", {
		Parent = bring,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.SourceSans,
		Text = "bring",
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		ZIndex = 54,
	})
	self:animate_button(bring, function()
		return theme["Object Background"]
	end)
	self:connect(bring.MouseButton1Click, function()
		self:bring_veteran(self._panel_selected)
	end)
	self.staff_bring = bring

	self.staff_status = self:create("TextLabel", {
		Parent = actions,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(160, 8),
		Size = UDim2.new(1, -160, 0, 20),
		Font = Enum.Font.SourceSans,
		Text = "",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 53,
	})

	self:drag_handle(panel)
end

function veteran:paint_report_btn()
	if self.report_btn then
		self.report_btn.BackgroundColor3 = self.report_open and theme["Tab Toggle Background"] or theme["Object Background"]
	end
end

function veteran:set_report_cooldown(seconds)
	self._report_wait = math.max(0, math.floor(tonumber(seconds) or 0))
	self._report_wait_at = os.clock()
	self:tick_report_cooldown()
end

function veteran:tick_report_cooldown()
	local left = self._report_wait or 0
	if self._report_wait_at then
		left = math.max(0, left - math.floor(os.clock() - self._report_wait_at))
	end
	if self.report_cool then
		self.report_cool.Text = left > 0 and format_cooldown(left) or "ready"
	end
	if self.report_submit then
		self.report_submit.AutoButtonColor = false
		self.report_submit.BackgroundColor3 = left > 0 and theme["Section Background"] or theme["Object Background"]
	end
	return left
end

function veteran:set_report_open(open)
	self.report_open = open and true or nil
	if self.report_overlay then
		self.report_overlay.Visible = self.report_open == true
	end
	if self.report_panel then
		self:set_window_open(self.report_panel, self.report_open == true)
	end
	if self.report_open then
		local z = math.min(math.max(90, (self._front_z or 50) + 10), 120)
		if self.report_overlay then
			self.report_overlay.ZIndex = z
		end
		if self.report_panel then
			self.report_panel.ZIndex = z + 2
		end
	end
	self:paint_report_btn()
	if self.report_open then
		task.spawn(function()
			local payload = self:ops("cooldown")
			if payload then
				self:set_report_cooldown(payload.wait or 0)
			end
		end)
	else
		self:close_dropdown()
	end
end

function veteran:submit_report()
	local left = self:tick_report_cooldown()
	if left > 0 then
		if self.report_hint then
			self.report_hint.Text = format_cooldown(left)
		end
		return
	end
	local kind = REPORT_KIND[self._report_kind or ""]
	local text = self.report_box and string.gsub(self.report_box.Text or "", "^%s+", "")
	text = text and string.gsub(text, "%s+$", "") or ""
	if not kind then
		if self.report_hint then
			self.report_hint.Text = "pick a type"
		end
		return
	end
	if #text < 3 then
		if self.report_hint then
			self.report_hint.Text = "write an explanation"
		end
		return
	end
	if self.report_hint then
		self.report_hint.Text = "sending"
	end
	local payload = self:ops("report", { kind = kind, text = text })
	if not payload then
		if self.report_hint then
			self.report_hint.Text = "could not send"
		end
		return
	end
	if payload.ok then
		if self.report_box then
			self.report_box.Text = ""
		end
		self:set_report_cooldown(payload.wait or 600)
		if self.report_hint then
			self.report_hint.Text = "sent"
		end
		return
	end
	if payload.cooldown then
		self:set_report_cooldown(payload.wait or 0)
	end
	if self.report_hint then
		self.report_hint.Text = payload.reason or "could not send"
	end
end

function veteran:build_report_panel()
	local overlay = self:create("TextButton", {
		Parent = self.gui,
		Name = "ReportOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		Visible = false,
		ZIndex = 90,
	})
	self.report_overlay = overlay
	self:connect(overlay.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local mx, my = gui_mouse(input)
		if self.report_panel and point_in(self.report_panel, mx, my) then
			return
		end
		local pack = self._dropdown
		if pack and pack.menu and point_in(pack.menu, mx, my) then
			return
		end
		self:set_report_open(false)
	end)

	local panel, inner = self:make_panel({
		Parent = self.gui,
		Name = "ReportPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 8),
		Size = UDim2.fromOffset(340, 286),
		Visible = false,
		Active = true,
		ZIndex = 92,
	})
	self.report_panel = panel
	inner.Active = true

	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -40, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "report",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 84,
	})

	local close = self:create("TextButton", {
		Parent = inner,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 85,
	})
	self:create("TextLabel", {
		Parent = close,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -1),
		Size = UDim2.fromOffset(18, 18),
		Font = Enum.Font.SourceSans,
		Text = "x",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 86,
	})
	self:animate_button(close, function()
		return theme["Object Background"]
	end)
	self:connect(close.MouseButton1Click, function()
		self:set_report_open(false)
	end)

	self._report_kind = REPORT_OPTIONS[1]
	local drop_hold = self:create("Frame", {
		Parent = inner,
		Position = UDim2.fromOffset(10, 30),
		Size = UDim2.new(1, -20, 0, 40),
		BackgroundTransparency = 1,
		ZIndex = 84,
	})
	self:make_dropdown(drop_hold, {
		name = "type",
		items = REPORT_OPTIONS,
		get = function()
			return self._report_kind
		end,
		set = function(value)
			self._report_kind = value
		end,
	})

	local box = self:create("TextBox", {
		Parent = inner,
		Position = UDim2.fromOffset(10, 78),
		Size = UDim2.new(1, -20, 0, 128),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		Font = Enum.Font.SourceSans,
		TextSize = TEXT_SIZE,
		Text = "",
		PlaceholderText = "explanation",
		PlaceholderColor3 = theme["Disabled Text"],
		ClearTextOnFocus = false,
		MultiLine = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 84,
	})
	self:create("UIPadding", {
		Parent = box,
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	self.report_box = box

	local submit = self:create("TextButton", {
		Parent = inner,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(92, 20),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 85,
	})
	self:create("TextLabel", {
		Parent = submit,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.SourceSans,
		Text = "submit",
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		ZIndex = 86,
	})
	self:animate_button(submit, function()
		return theme["Object Background"]
	end)
	self:connect(submit.MouseButton1Click, function()
		self:submit_report()
	end)
	self.report_submit = submit

	self.report_cool = self:create("TextLabel", {
		Parent = inner,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -20, 0, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSans,
		Text = "ready",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		ZIndex = 84,
	})
	self.report_hint = self.report_cool
	self:drag_handle(panel)
end

function veteran:build_report_btn(parent)
	local btn = self:chrome_btn(parent, 1, 26)
	self:create("TextLabel", {
		Parent = btn,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.SourceSans,
		Text = "?",
		TextSize = TAB_SIZE,
		ThemeText = "Text",
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = (btn.ZIndex or 44) + 1,
	})
	self:animate_button(btn, function()
		return self.report_open and theme["Tab Toggle Background"] or theme["Object Background"]
	end)
	self:connect(btn.MouseButton1Click, function()
		self:set_report_open(self.report_open ~= true)
	end)
	self.report_btn = btn
	return btn
end

function veteran:start_ops_loop()
	if self._ops_loop then
		return
	end
	self._ops_loop = true
	task.spawn(function()
		while self.gui and self.gui.Parent do
			pcall(function()
				self:poll_staff_command()
			end)
			if self.staff_panel and self.staff_panel.Visible then
				pcall(function()
					self:refresh_staff_panel(true)
				end)
			end
			if self.report_open then
				self:tick_report_cooldown()
			end
			task.wait(4)
		end
		self._ops_loop = nil
	end)
end

function veteran:refresh_autoload_toggle()
	local pack = self.autoload_toggle
	if pack and pack.refresh then
		pack.refresh()
	end
end

function veteran:refresh_theme_list()
	if not self.theme_list then
		return
	end
	for _, child in ipairs(self.theme_list:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for i, name in ipairs(self:list_theme_files()) do
		local selected = name == self.theme_name
		local row = self:create("TextButton", {
			Parent = self.theme_list,
			Size = UDim2.new(1, 0, 0, ROW_H),
			BackgroundColor3 = selected and theme["Tab Toggle Background"] or theme["Dropdown Option Background"],
			BackgroundTransparency = selected and 0 or 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = i,
			ZIndex = 58,
		})
		self:create("TextLabel", {
			Parent = row,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Font = Enum.Font.SourceSans,
			Text = name,
			TextSize = TEXT_SIZE,
			ThemeText = selected and "Text" or "Disabled Text",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			ZIndex = 59,
		})
		self:connect(row.MouseButton1Click, function()
			self.theme_name = name
			if self.theme_name_box then
				self.theme_name_box.Text = name
			end
			self:load_theme_file(name)
		end)
	end
end

function veteran:build_themes_panel()
	local panel, clip = self:make_panel({
		Parent = self.gui,
		Name = "ThemesPanel",
		Position = UDim2.fromOffset(8, BAR_HEIGHT + 8),
		Size = UDim2.fromOffset(430, 430),
		Visible = false,
		ZIndex = 50,
	})
	self.themes_panel = panel
	local header = self:create("Frame", {
		Parent = clip,
		Size = UDim2.new(1, 0, 0, 276),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 51,
	})
	self:create("UIPadding", {
		Parent = header,
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	self:create("UIListLayout", {
		Parent = header,
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local inner = self:create("ScrollingFrame", {
		Parent = clip,
		Position = UDim2.fromOffset(0, 276),
		Size = UDim2.new(1, 0, 1, -276),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = theme.Accent,
		Theme = "Accent",
		ThemeProp = "ScrollBarImageColor3",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 320),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Active = true,
		ScrollingEnabled = true,
		ZIndex = 51,
	})
	self:create("UIPadding", {
		Parent = inner,
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 10),
	})
	local themes_layout = self:create("UIListLayout", {
		Parent = inner,
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local function place_themes_scroll()
		local h = math.max(header.AbsoluteSize.Y, 276)
		inner.Position = UDim2.fromOffset(0, h)
		inner.Size = UDim2.new(1, 0, 1, -h)
		inner.CanvasSize = UDim2.fromOffset(0, themes_layout.AbsoluteContentSize.Y + 16)
	end
	self:connect(header:GetPropertyChangedSignal("AbsoluteSize"), place_themes_scroll)
	self:connect(themes_layout:GetPropertyChangedSignal("AbsoluteContentSize"), place_themes_scroll)
	task.defer(place_themes_scroll)

	self:create("TextLabel", {
		Parent = header,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "themes",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		LayoutOrder = 1,
		ZIndex = 52,
	})

	local files = self:create("Frame", {
		Parent = header,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 2,
		ZIndex = 52,
	})
	self:create("UIListLayout", {
		Parent = files,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local name_box = self:create("TextBox", {
		Parent = files,
		Size = UDim2.new(0, 140, 1, 0),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		ThemeText = "Text",
		BorderSizePixel = 1,
		Font = Enum.Font.SourceSans,
		TextSize = TEXT_SIZE,
		Text = self.theme_name or "current",
		PlaceholderText = "theme name",
		PlaceholderColor3 = theme["Disabled Text"],
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		ZIndex = 53,
	})
	self:create("UIPadding", {
		Parent = name_box,
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	self.theme_name_box = name_box
	self:connect(name_box.FocusLost, function()
		local name = name_box.Text:gsub("[^%w%-%._ ]", "")
		if name == "" then
			name = "current"
		end
		name_box.Text = name
		self.theme_name = name
	end)

	self:mini_button(files, "save", 2, function()
		self.theme_name = name_box.Text
		self:write_theme_file(self.theme_name)
		self:refresh_theme_list()
	end)
	self:mini_button(files, "load", 3, function()
		self:load_theme_file(name_box.Text)
	end)
	self:mini_button(files, "delete", 4, function()
		self:delete_theme_file(name_box.Text)
	end)
	self:mini_button(files, "reset", 5, function()
		self:reset_theme()
	end)

	self.autoload_toggle = self:make_toggle(header, {
		name = "autoload",
		layout_order = 3,
		get = function()
			return self.theme_autoload
		end,
		set = function(on)
			if on then
				self:set_autoload(name_box.Text)
			else
				self:set_autoload(nil)
			end
		end,
	})
	self.topbar_autohide_toggle = self:make_toggle(header, {
		name = "autohide top bar",
		layout_order = 4,
		get = function()
			return self:layout_value("topbar_autohide")
		end,
		set = function(on)
			self:set_layout("topbar_autohide", on)
		end,
	})
	self:bind_layout_pack("topbar_autohide", self.topbar_autohide_toggle)
	if self:can_coregui_rewrite() then
		self.rewrite_toggle = self:make_toggle(header, {
			name = "rewrite coregui",
			layout_order = 5,
			get = function()
				return self:wants_coregui_redesign()
			end,
			set = function(on)
				self:set_coregui_rewrite(on)
			end,
		})
		self.fullscreen_exit_toggle = self:make_toggle(header, {
			name = "hide fullscreen exit",
			layout_order = 6,
			get = function()
				return self:layout_value("hide_fullscreen_exit")
			end,
			set = function(on)
				self:set_layout("hide_fullscreen_exit", on)
			end,
		})
		self:bind_layout_pack("hide_fullscreen_exit", self.fullscreen_exit_toggle)

		self:create("TextLabel", {
			Parent = header,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			Font = Enum.Font.SourceSans,
			Text = "hotbar",
			TextSize = TITLE_SIZE,
			ThemeText = "Text",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			LayoutOrder = 7,
			ZIndex = 52,
		})
		local layout_outer = self:create("Frame", {
			Parent = header,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			BorderColor3 = Color3.fromRGB(10, 10, 10),
			BorderSizePixel = 1,
			LayoutOrder = 8,
			ZIndex = 52,
		})
		local layout_wrap = self:create("Frame", {
			Parent = layout_outer,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = theme["Section Background"],
			Theme = "Section Background",
			ThemeProp = "BackgroundColor3",
			ThemeBorder = "Object Border",
			BorderSizePixel = 1,
			ZIndex = 53,
		})
		self:create("UIPadding", {
			Parent = layout_wrap,
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		})
		self:create("UIListLayout", {
			Parent = layout_wrap,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		self:make_layout_sliders(layout_wrap)
	end

	local list_outer = self:create("Frame", {
		Parent = inner,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		LayoutOrder = 4,
		ZIndex = 52,
	})
	local list_wrap = self:create("Frame", {
		Parent = list_outer,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 53,
	})
	self:create("UIPadding", {
		Parent = list_wrap,
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	self:create("UIListLayout", {
		Parent = list_wrap,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self.theme_list = list_wrap

	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "colors",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		LayoutOrder = 5,
		ZIndex = 52,
	})

	local table_wrap = self:create("Frame", {
		Parent = inner,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 6,
		ZIndex = 52,
	})
	self:create("UIListLayout", {
		Parent = table_wrap,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	for i, key in ipairs(THEME_KEYS) do
		local row = self:create("Frame", {
			Parent = table_wrap,
			Size = UDim2.new(1, 0, 0, ROW_H),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = 53,
		})
		self:create("TextLabel", {
			Parent = row,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -100, 1, 0),
			Font = Enum.Font.SourceSans,
			Text = key,
			TextSize = TEXT_SIZE,
			ThemeText = "Text",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			ZIndex = 54,
		})
		local rgb_label = self:create("TextLabel", {
			Parent = row,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -22, 0.5, 0),
			Size = UDim2.fromOffset(78, ROW_H),
			Font = Enum.Font.SourceSans,
			Text = rgb_string(theme[key]),
			TextSize = TEXT_SIZE,
			ThemeText = "Disabled Text",
			TextXAlignment = Enum.TextXAlignment.Right,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			ZIndex = 54,
		})
		local swatch, fill = self:make_swatch(row, {
			z = 55,
		})
		swatch.AnchorPoint = Vector2.new(1, 0.5)
		swatch.Position = UDim2.new(1, 0, 0.5, 0)
		fill.BackgroundColor3 = theme[key]
		theme_swatches[key] = { fill = fill, rgb = rgb_label, hit = swatch }
		self:connect(swatch.MouseButton1Click, function()
			if self.picker_key == key then
				self:close_picker()
			else
				self:open_picker(swatch, key)
			end
		end)
	end

	self:connect(uis.InputBegan, function(input_obj)
		if input_obj.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if not self.picker then
			return
		end
		local mx, my = gui_mouse(input_obj)
		if point_in(self.picker, mx, my) then
			return
		end
		for _, pack in pairs(theme_swatches) do
			if (pack.hit and point_in(pack.hit, mx, my)) or (pack.fill and point_in(pack.fill, mx, my)) then
				return
			end
		end
		self:close_picker()
	end)

	self:refresh_theme_list()
	self:refresh_autoload_toggle()
	self:drag_handle(panel)
end

function veteran:boot_saved_theme()
	self:ensure_theme_dir()
	local autoload = self:read_autoload()
	if autoload then
		self.theme_autoload = true
		self.theme_name = autoload
		self:load_theme_file(autoload)
		if self.theme_name_box then
			self.theme_name_box.Text = autoload
		end
		self:refresh_theme_list()
		self:refresh_autoload_toggle()
		return
	end
	self.theme_autoload = false
	self.theme_name = "current"
	self._theme_lock = true
	for _, key in ipairs(THEME_KEYS) do
		self:set_theme(key, DEFAULT_THEME[key])
	end
	for key, value in pairs(LAYOUT_DEFAULTS) do
		self:set_layout(key, value)
	end
	self._theme_lock = false
	if self.theme_name_box then
		self.theme_name_box.Text = "current"
	end
	self:refresh_theme_list()
	self:refresh_autoload_toggle()
end

local function relation_color(status)
	if status == "friendly" then
		return Color3.fromRGB(15, 179, 255)
	elseif status == "enemy" then
		return Color3.fromRGB(255, 44, 44)
	elseif status == "owner" then
		return Color3.fromRGB(204, 164, 50)
	elseif status == "dev" then
		return Color3.fromRGB(112, 28, 44)
	elseif status == "veteran" then
		return theme.Accent
	end
	return theme["Disabled Text"]
end

local function player_id(player)
	if typeof(player) == "Instance" then
		return player.UserId
	end
	return tonumber(player)
end

local function peer_state(id)
	id = tonumber(id)
	if not id then
		return nil
	end
	local sync = env_table().veteran_sync
	local peer = sync and sync.peers and sync.peers[id]
	if type(peer) == "table" then
		return peer
	end
	return nil
end

local function forced_role(id)
	id = tonumber(id)
	if not id then
		return nil
	end
	if OWNER_IDS[id] then
		return "owner"
	end
	if DEV_IDS[id] then
		return "dev"
	end
	local local_id = tonumber(veteran:local_user_id())
	if local_id and id == local_id then
		return veteran:license_role()
	end
	local peer = peer_state(id)
	if peer then
		local role = peer.role
		if role == "owner" or role == "dev" or role == "veteran" then
			return role
		end
		return "veteran"
	end
	if veteran.veteran_ids and veteran.veteran_ids[id] then
		return "veteran"
	end
	return nil
end

function veteran:load_relations()
	self.relations = self.relations or {}
	self.veteran_ids = self.veteran_ids or {}
	local ok, body = self:fs("readfile", RELATION_FILE)
	if not ok or type(body) ~= "string" or body == "" then
		ok, body = self:fs("readfile", "veteran/environment.json")
	end
	if not ok or type(body) ~= "string" or body == "" then
		return
	end
	local decoded
	local parse_ok = pcall(function()
		decoded = http_service:JSONDecode(body)
	end)
	if not parse_ok or type(decoded) ~= "table" then
		return
	end
	local function eat(list, status)
		if type(list) ~= "table" then
			return
		end
		for _, id in ipairs(list) do
			id = tonumber(id)
			if id then
				self.relations[id] = status
			end
		end
	end
	eat(decoded.friendly, "friendly")
	eat(decoded.enemy, "enemy")
end

function veteran:save_relations()
	self:ensure_theme_dir()
	local buckets = {
		friendly = {},
		enemy = {},
	}
	for id, status in pairs(self.relations or {}) do
		if buckets[status] then
			table.insert(buckets[status], id)
		end
	end
	self:fs("writefile", RELATION_FILE, http_service:JSONEncode(buckets))
end

function veteran:is_veteran(player)
	return forced_role(player_id(player)) == "veteran"
end

function veteran:forced_role(player)
	return forced_role(player_id(player))
end

function veteran:owner_tag(player)
	local id = player_id(player)
	if not id then
		return nil
	end
	local local_id = tonumber(self:local_user_id())
	if local_id and id == local_id then
		local session = env_table().veteran_session
		if session and type(session.owner_tag) == "string" and session.owner_tag ~= "" then
			return session.owner_tag
		end
	end
	local peer = peer_state(id)
	if peer and type(peer.owner_tag) == "string" and peer.owner_tag ~= "" then
		return peer.owner_tag
	end
	return nil
end

function veteran:tagged_name(player)
	if typeof(player) ~= "Instance" then
		return "?"
	end
	local name = player.DisplayName or player.Name or "?"
	local role = forced_role(player.UserId)
	if role == "owner" or role == "dev" then
		return name .. " [" .. role .. "]"
	end
	return name
end

local ROLE_TAG_NAME = "veteran_owner_tag"

function veteran:clear_role_tag(player)
	local char = player and player.Character
	local head = char and char:FindFirstChild("Head")
	local existing = head and head:FindFirstChild(ROLE_TAG_NAME)
	if existing then
		existing:Destroy()
	end
end

function veteran:apply_role_tag(player)
	if not player or player == players.LocalPlayer then
		return
	end
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local role = forced_role(player.UserId)
	local show = role == "owner" or role == "dev"
	local existing = head:FindFirstChild(ROLE_TAG_NAME)
	if not show then
		if existing then
			existing:Destroy()
		end
		return
	end
	if not existing then
		existing = Instance.new("BillboardGui")
		existing.Name = ROLE_TAG_NAME
		existing.AlwaysOnTop = true
		existing.Size = UDim2.fromOffset(180, 18)
		existing.StudsOffset = Vector3.new(0, 3.15, 0)
		existing.MaxDistance = 250
		existing.LightInfluence = 0
		existing.ResetOnSpawn = false
		existing.Adornee = head
		existing.Parent = head
		local text = Instance.new("TextLabel")
		text.Name = "label"
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.SourceSans
		text.TextSize = 14
		text.TextStrokeTransparency = 0.35
		text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		text.Parent = existing
	end
	existing.Adornee = head
	existing.Enabled = true
	local label = existing:FindFirstChild("label")
	if label then
		local tag = self:owner_tag(player)
		if tag then
			label.Text = role .. "  ·  " .. string.lower(tag)
		else
			label.Text = role
		end
		label.TextColor3 = relation_color(role)
	end
end

function veteran:refresh_live_presence()
	for _, player in ipairs(players:GetPlayers()) do
		self:apply_role_tag(player)
		self:refresh_player_row(player)
	end
	self:refresh_environment_detail()
end

function veteran:bind_live_presence()
	if self._live_presence then
		return
	end
	self._live_presence = true
	local sync = env_table().veteran_sync
	if sync and type(sync.on_aura) == "function" then
		sync.on_aura(function(user_id, state)
			local player = players:GetPlayerByUserId(user_id)
			if not player then
				return
			end
			if state and state.present == false then
				self:clear_role_tag(player)
			else
				self:apply_role_tag(player)
			end
			self:refresh_player_row(player)
			if self.selected_player == player then
				self:refresh_environment_detail()
			end
		end)
	end
	if sync and type(sync.publish_aura) == "function" then
		task.defer(function()
			sync.publish_aura(sync._last_aura or { enabled = false })
		end)
	end
	local function hook(player)
		if not player or player == players.LocalPlayer then
			return
		end
		self:connect(player.CharacterAdded, function()
			task.wait(0.8)
			self:apply_role_tag(player)
		end)
		if player.Character then
			task.defer(function()
				self:apply_role_tag(player)
			end)
		end
	end
	for _, player in ipairs(players:GetPlayers()) do
		hook(player)
	end
	self:connect(players.PlayerAdded, hook)
	self:connect(players.PlayerRemoving, function(player)
		self:clear_role_tag(player)
	end)
	task.spawn(function()
		while self.gui and self.gui.Parent do
			task.wait(2)
			self:refresh_live_presence()
		end
	end)
	task.defer(function()
		self:refresh_live_presence()
	end)
end

function veteran:get_relation(player)
	local id = player_id(player)
	if not id then
		return "neutral"
	end
	return forced_role(id) or self.relations[id] or "neutral"
end

function veteran:set_relation(player, status)
	local id = player_id(player)
	if not id then
		return false
	end
	if forced_role(id) then
		return false
	end
	if status ~= "friendly" and status ~= "enemy" and status ~= "neutral" then
		return false
	end
	if status == "neutral" then
		self.relations[id] = nil
	else
		self.relations[id] = status
	end
	self:save_relations()
	self:refresh_player_row(id)
	self:refresh_environment_detail()
	return true
end

-- Detector (later) calls this. Veteran is forced and cannot be cleared from the UI.
function veteran:mark_veteran(player, enabled)
	local id = player_id(player)
	if not id then
		return
	end
	if enabled == false then
		self.veteran_ids[id] = nil
	else
		self.veteran_ids[id] = true
	end
	self:refresh_player_row(id)
	self:refresh_environment_detail()
end

function veteran:refresh_environment_colors()
	for _, pack in pairs(self.player_rows or {}) do
		self:refresh_player_row(pack.player)
	end
	self:refresh_environment_detail()
end

function veteran:sort_player_rows()
	local list = {}
	for _, pack in pairs(self.player_rows or {}) do
		table.insert(list, pack)
	end
	table.sort(list, function(a, b)
		return string.lower(a.player.DisplayName) < string.lower(b.player.DisplayName)
	end)
	for i, pack in ipairs(list) do
		pack.row.LayoutOrder = i
	end
end

function veteran:filter_player_list()
	local query = string.lower(self.env_search and self.env_search.Text or "")
	local shown = 0
	for _, pack in pairs(self.player_rows or {}) do
		local hay = string.lower((pack.player.DisplayName or "") .. " " .. (pack.player.Name or ""))
		local vis = query == "" or hay:find(query, 1, true) ~= nil
		pack.row.Visible = vis
		if vis then
			shown += 1
		end
	end
	if self.env_empty then
		self.env_empty.Visible = shown == 0
		self.env_empty.Text = query == "" and "no players" or "no matches"
	end
	if self.env_count then
		self.env_count.Text = tostring(shown)
	end
end

function veteran:refresh_player_row(player)
	local id = player_id(player)
	local pack = id and self.player_rows[id]
	if not pack then
		return
	end
	local status = self:get_relation(pack.player)
	pack.status.Text = status
	pack.status.TextColor3 = relation_color(status)
	pack.team.Text = pack.player.Team and pack.player.Team.Name or "-"
	pack.name.Text = pack.player.DisplayName
	local on = self.selected_player == pack.player
	pack.row.BackgroundTransparency = on and 0 or 1
	pack.row.BackgroundColor3 = on and theme["Tab Toggle Background"] or theme["Section Background"]
end

function veteran:select_environment_player(player)
	self.selected_player = player
	for _, pack in pairs(self.player_rows or {}) do
		local on = pack.player == player
		pack.row.BackgroundTransparency = on and 0 or 1
		pack.row.BackgroundColor3 = on and theme["Tab Toggle Background"] or theme["Section Background"]
	end
	self:refresh_environment_detail()
end

function veteran:refresh_environment_detail()
	local player = self.selected_player
	local status = player and self:get_relation(player) or "neutral"
	if self.env_display then
		self.env_display.Text = player and ("display  " .. player.DisplayName) or "display  —"
	end
	if self.env_name then
		self.env_name.Text = player and ("name  " .. player.Name) or "name  —"
	end
	if self.env_userid then
		self.env_userid.Text = player and ("id  " .. tostring(player.UserId)) or "id  —"
	end
	if self.env_status then
		local tag = player and self:owner_tag(player)
		if tag and (status == "owner" or status == "dev") then
			self.env_status.Text = "status  " .. status .. "  ·  " .. string.lower(tag)
		else
			self.env_status.Text = player and ("status  " .. status) or "status  —"
		end
		self.env_status.TextColor3 = player and relation_color(status) or theme["Disabled Text"]
	end
	for name, pack in pairs(self.relation_buttons or {}) do
		local on = player ~= nil and status == name
		pack.button.BackgroundColor3 = on and theme["Tab Toggle Background"] or theme["Object Background"]
		pack.label.TextColor3 = on and relation_color(name) or theme.Text
	end
end

function veteran:remove_player_row(player)
	local id = player_id(player)
	local pack = id and self.player_rows[id]
	if not pack then
		return
	end
	if pack.row then
		pack.row:Destroy()
	end
	self.player_rows[id] = nil
	if self.selected_player == pack.player then
		self.selected_player = nil
		self:refresh_environment_detail()
	end
	self:filter_player_list()
end

function veteran:add_player_row(player)
	if not player or not self.env_list then
		return
	end
	if player == players.LocalPlayer then
		return
	end
	local id = player.UserId
	if self.player_rows[id] then
		self:refresh_player_row(player)
		return
	end

	local row = self:create("TextButton", {
		Parent = self.env_list,
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundColor3 = theme["Tab Toggle Background"],
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 54,
	})

	local name = self:create("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(2, 0),
		Size = UDim2.new(1, -194, 1, 0),
		Font = Enum.Font.SourceSans,
		Text = player.DisplayName,
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 55,
	})

	local team = self:create("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -78, 0, 0),
		Size = UDim2.fromOffset(110, ROW_H),
		Font = Enum.Font.SourceSans,
		Text = player.Team and player.Team.Name or "-",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 55,
	})

	local status = self:create("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 0),
		Size = UDim2.fromOffset(72, ROW_H),
		Font = Enum.Font.SourceSans,
		Text = self:get_relation(player),
		TextSize = TEXT_SIZE,
		TextColor3 = relation_color(self:get_relation(player)),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 55,
	})

	self.player_rows[id] = {
		player = player,
		row = row,
		name = name,
		team = team,
		status = status,
	}

	self:connect(row.MouseButton1Click, function()
		self:select_environment_player(player)
	end)
	self:connect(player:GetPropertyChangedSignal("Team"), function()
		self:refresh_player_row(player)
	end)
	self:connect(player:GetPropertyChangedSignal("DisplayName"), function()
		self:refresh_player_row(player)
		self:sort_player_rows()
		self:filter_player_list()
	end)

	self:sort_player_rows()
	self:filter_player_list()
end

function veteran:relation_chip(parent, status, layout_order)
	local btn = self:create("TextButton", {
		Parent = parent,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 18),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = layout_order or 0,
		ZIndex = 56,
	})
	self:create("UIPadding", {
		Parent = btn,
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	local label = self:create("TextLabel", {
		Parent = btn,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Font = Enum.Font.SourceSans,
		Text = status,
		TextSize = TEXT_SIZE,
		TextColor3 = theme.Text,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 57,
	})
	self.relation_buttons = self.relation_buttons or {}
	self.relation_buttons[status] = { button = btn, label = label }
	self:connect(btn.MouseButton1Click, function()
		if not self.selected_player then
			return
		end
		self:set_relation(self.selected_player, status)
	end)
	self:animate_button(btn, function()
		return theme["Object Background"]
	end)
	return btn
end

function veteran:env_action_chip(parent, name, layout_order, callback)
	local btn = self:create("TextButton", {
		Parent = parent,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 18),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = layout_order or 0,
		ZIndex = 56,
	})
	self:create("UIPadding", {
		Parent = btn,
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	local label = self:create("TextLabel", {
		Parent = btn,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Font = Enum.Font.SourceSans,
		Text = name,
		TextSize = TEXT_SIZE,
		TextColor3 = theme.Text,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 57,
	})
	self.env_action_buttons = self.env_action_buttons or {}
	self.env_action_buttons[name] = { button = btn, label = label }
	self:connect(btn.MouseButton1Click, function()
		if callback then
			callback()
		end
	end)
	self:animate_button(btn, function()
		return theme["Object Background"]
	end)
	return btn
end

function veteran:goto_selected_player()
	local player = self.selected_player
	local lp = players.LocalPlayer
	local mine = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local theirs = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not mine or not theirs then
		return
	end
	pcall(function()
		mine.CFrame = theirs.CFrame * CFrame.new(0, 0, 3)
	end)
end

local ENV_VIEW_BIND = "VeteranEnvView"

function veteran:env_view_parts(player)
	local char = player and player.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
		or char:FindFirstChild("Torso")
		or char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("Head")
	return root, hum, char
end

function veteran:stop_env_view_loop()
	if self._env_view_conn then
		pcall(function()
			self._env_view_conn:Disconnect()
		end)
		self._env_view_conn = nil
	end
	pcall(function()
		run_service:UnbindFromRenderStep(ENV_VIEW_BIND)
	end)
end

function veteran:apply_env_view()
	local player = self._env_view_player
	if not player or not player.Parent then
		return false
	end
	local root, hum, char = self:env_view_parts(player)
	local cam = workspace.CurrentCamera
	if not cam or not root then
		return char ~= nil
	end
	pcall(function()
		-- game cameras (zee / hood) overwrite CameraSubject every frame;
		-- own the camera so view actually sticks on the selected player
		cam.CameraType = Enum.CameraType.Scriptable
		if hum then
			cam.CameraSubject = hum
		else
			cam.CameraSubject = char
		end
		local pos = root.Position
		local behind = root.CFrame.LookVector
		cam.CFrame = CFrame.new(pos - behind * 8 + Vector3.new(0, 3, 0), pos + Vector3.new(0, 1.5, 0))
	end)
	return true
end

function veteran:paint_env_view_chip()
	local pack = self.env_action_buttons and self.env_action_buttons.view
	if not pack or not pack.label then
		return
	end
	if self._env_viewing then
		pack.label.Text = "viewing"
		pack.label.TextColor3 = theme.Accent
	else
		pack.label.Text = "view"
		pack.label.TextColor3 = theme.Text
	end
end

function veteran:clear_env_view()
	self:stop_env_view_loop()
	self._env_viewing = false
	self._env_view_player = nil
	local lp = players.LocalPlayer
	local cam = workspace.CurrentCamera
	if cam then
		pcall(function()
			cam.CameraType = Enum.CameraType.Custom
			local mine = lp and lp.Character
			local subject = mine and (mine:FindFirstChildOfClass("Humanoid") or mine)
			if subject then
				cam.CameraSubject = subject
			end
		end)
	end
	self:paint_env_view_chip()
end

function veteran:start_env_view_loop()
	self:stop_env_view_loop()
	self:apply_env_view()
	local function step()
		if not self._env_viewing then
			return
		end
		if not self:apply_env_view() then
			if not (self._env_view_player and self._env_view_player.Parent) then
				self:clear_env_view()
			end
		end
	end
	local bound = pcall(function()
		run_service:BindToRenderStep(ENV_VIEW_BIND, Enum.RenderPriority.Camera.Value + 25, step)
	end)
	if not bound then
		self._env_view_conn = run_service.RenderStepped:Connect(step)
	end
end

function veteran:view_selected_player()
	local player = self.selected_player
	if not player or not player.Parent then
		self:clear_env_view()
		return
	end
	if self._env_viewing and self._env_view_player == player then
		self:clear_env_view()
		return
	end
	self._env_viewing = true
	self._env_view_player = player
	self:start_env_view_loop()
	self:paint_env_view_chip()
end

function veteran:build_environment_panel()
	self.relations = self.relations or {}
	self.veteran_ids = self.veteran_ids or {}
	self.player_rows = {}
	self.relation_buttons = {}
	self.selected_player = nil
	self:load_relations()

	local panel, inner = self:make_panel({
		Parent = self.gui,
		Name = "EnvironmentPanel",
		Position = UDim2.fromOffset(28, BAR_HEIGHT + 28),
		Size = UDim2.fromOffset(520, 418),
		Visible = false,
		ZIndex = 50,
	})
	self.environment_panel = panel

	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -80, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "environment",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 52,
	})

	self.env_count = self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(60, 16),
		Font = Enum.Font.SourceSans,
		Text = "0",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 52,
	})

	local search = self:create("TextBox", {
		Parent = inner,
		Position = UDim2.fromOffset(8, 26),
		Size = UDim2.new(1, -16, 0, 18),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		ThemeText = "Text",
		BorderSizePixel = 1,
		Font = Enum.Font.SourceSans,
		TextSize = TEXT_SIZE,
		Text = "",
		PlaceholderText = "search players",
		PlaceholderColor3 = theme["Disabled Text"],
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 53,
	})
	self:create("UIPadding", {
		Parent = search,
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	self.env_search = search
	self:connect(search:GetPropertyChangedSignal("Text"), function()
		self:filter_player_list()
	end)

	local header = self:create("Frame", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 50),
		Size = UDim2.new(1, -16, 0, 16),
		ZIndex = 52,
	})
	self:create("TextLabel", {
		Parent = header,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -200, 1, 0),
		Font = Enum.Font.SourceSans,
		Text = "name",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 53,
	})
	self:create("TextLabel", {
		Parent = header,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -78, 0, 0),
		Size = UDim2.fromOffset(110, 16),
		Font = Enum.Font.SourceSans,
		Text = "team",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 53,
	})
	self:create("TextLabel", {
		Parent = header,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.fromOffset(72, 16),
		Font = Enum.Font.SourceSans,
		Text = "status",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 53,
	})

	local list_outer = self:create("Frame", {
		Parent = inner,
		Position = UDim2.fromOffset(8, 68),
		Size = UDim2.new(1, -16, 1, -178),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		ZIndex = 52,
	})
	local list_wrap = self:create("Frame", {
		Parent = list_outer,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 52,
	})

	local list = self:create("ScrollingFrame", {
		Parent = list_wrap,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = theme.Accent,
		Theme = "Accent",
		ThemeProp = "ScrollBarImageColor3",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 53,
	})
	self:create("UIPadding", {
		Parent = list,
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
		PaddingLeft = UDim.new(0, 3),
		PaddingRight = UDim.new(0, 3),
	})
	self:create("UIListLayout", {
		Parent = list,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self.env_list = list

	self.env_empty = self:create("TextLabel", {
		Parent = list_wrap,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.SourceSans,
		Text = "no players",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 54,
		Visible = true,
	})

	local detail = self:create("Frame", {
		Parent = inner,
		Position = UDim2.new(0, 8, 1, -102),
		Size = UDim2.new(1, -16, 0, 68),
		BackgroundTransparency = 1,
		ZIndex = 52,
	})
	self:create("UIListLayout", {
		Parent = detail,
		Padding = UDim.new(0, 1),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	self.env_display = self:create("TextLabel", {
		Parent = detail,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "display  —",
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		LayoutOrder = 1,
		ZIndex = 53,
	})
	self.env_name = self:create("TextLabel", {
		Parent = detail,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "name  —",
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		LayoutOrder = 2,
		ZIndex = 53,
	})
	self.env_userid = self:create("TextButton", {
		Parent = detail,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "id  —",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		LayoutOrder = 3,
		ZIndex = 53,
	})
	self.env_status = self:create("TextLabel", {
		Parent = detail,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "status  —",
		TextSize = TEXT_SIZE,
		TextColor3 = theme["Disabled Text"],
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		LayoutOrder = 4,
		ZIndex = 53,
	})
	self:connect(self.env_userid.MouseButton1Click, function()
		local player = self.selected_player
		if not player then
			return
		end
		pcall(function()
			setclipboard(player.DisplayName .. " | " .. tostring(player.UserId))
		end)
	end)

	local chips = self:create("Frame", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 1, -28),
		Size = UDim2.new(1, -16, 0, 20),
		ZIndex = 52,
	})
	self:create("UIListLayout", {
		Parent = chips,
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self:relation_chip(chips, "neutral", 1)
	self:relation_chip(chips, "friendly", 2)
	self:relation_chip(chips, "enemy", 3)
	self:env_action_chip(chips, "goto", 4, function()
		self:goto_selected_player()
	end)
	self:env_action_chip(chips, "view", 5, function()
		self:view_selected_player()
	end)

	for _, player in ipairs(players:GetPlayers()) do
		self:add_player_row(player)
	end

	self:connect(players.PlayerAdded, function(player)
		task.defer(function()
			self:add_player_row(player)
		end)
	end)
	self:connect(players.PlayerRemoving, function(player)
		if self._env_view_player == player then
			self:clear_env_view()
		end
		self:remove_player_row(player)
	end)

	self:refresh_environment_detail()
	self:drag_handle(panel)
	self:bind_live_presence()
end

local WATERMARK_FILE = "veteran/watermark.json"

function veteran:default_watermark_opts()
	return {
		enabled = true,
		user = true,
		time = true,
		fps = false,
		ping = false,
		x_scale = 1,
		x_offset = -8,
		y_scale = 0,
		y_offset = BAR_HEIGHT + 8,
		anchor_x = 1,
		anchor_y = 0,
	}
end

function veteran:load_watermark_opts()
	local opts = self:default_watermark_opts()
	local ok, body = self:fs("readfile", WATERMARK_FILE)
	if not ok or type(body) ~= "string" or body == "" then
		ok, body = self:fs("readfile", "veteran/watermark.json")
	end
	if ok and type(body) == "string" and body ~= "" then
		local decoded
		pcall(function()
			decoded = http_service:JSONDecode(body)
		end)
		if type(decoded) == "table" then
			for key, value in pairs(decoded) do
				opts[key] = value
			end
		end
	end
	self.watermark_opts = opts
	return opts
end

function veteran:save_watermark_opts()
	self:ensure_theme_dir()
	local opts = self.watermark_opts or self:default_watermark_opts()
	if self.watermark then
		local pos = self.watermark.Position
		opts.x_scale = pos.X.Scale
		opts.x_offset = pos.X.Offset
		opts.y_scale = pos.Y.Scale
		opts.y_offset = pos.Y.Offset
		opts.anchor_x = self.watermark.AnchorPoint.X
		opts.anchor_y = self.watermark.AnchorPoint.Y
	end
	self:fs("writefile", WATERMARK_FILE, http_service:JSONEncode(opts))
end

function veteran:read_ping()
	local ping = 0
	pcall(function()
		ping = math.floor(stats_service.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
	end)
	return ping
end

function veteran:watermark_text()
	local opts = self.watermark_opts or self:default_watermark_opts()
		local parts = { "veteran" }
	if opts.user then
		local lp = players.LocalPlayer
		table.insert(parts, lp and lp.DisplayName or "?")
	end
	if opts.time then
		local _, time_text = clock_text()
		table.insert(parts, time_text)
	end
	if opts.fps then
		table.insert(parts, tostring(self._fps or 0) .. " fps")
	end
	if opts.ping then
		table.insert(parts, tostring(self._ping or 0) .. "ms")
	end
	return table.concat(parts, "  ·  ")
end

function veteran:refresh_watermark()
	local opts = self.watermark_opts or self:default_watermark_opts()
	if self.watermark then
		self.watermark.Visible = opts.enabled == true
	end
	if self.watermark_label then
		self.watermark_label.Text = self:watermark_text()
	end
	for _, pack in pairs(self.watermark_toggles or {}) do
		if pack.refresh then
			pack.refresh()
		end
	end
	local meta = self.option_meta and self.option_meta.watermark
	if meta and meta.pack and meta.pack.refresh then
		meta.pack.refresh()
	end
end

function veteran:set_watermark_opt(key, value)
	self.watermark_opts = self.watermark_opts or self:default_watermark_opts()
	self.watermark_opts[key] = value
	if key == "enabled" then
		self.options = self.options or {}
		self.options.watermark = value and true or false
		if not self._applying_options then
			self:save_config()
		end
	end
	self:refresh_watermark()
	self:save_watermark_opts()
end

function veteran:watermark_toggle(parent, key, label, layout_order)
	self.watermark_toggles = self.watermark_toggles or {}
	local pack = self:make_toggle(parent, {
		name = label,
		layout_order = layout_order,
		get = function()
			local opts = self.watermark_opts or self:default_watermark_opts()
			return opts[key] == true
		end,
		set = function(on)
			self:set_watermark_opt(key, on)
		end,
	})
	self.watermark_toggles[key] = pack
	return pack.row
end

function veteran:build_watermark()
	self:load_watermark_opts()
	local opts = self.watermark_opts

	local mark = self:create("Frame", {
		Parent = self.gui,
		Name = "Watermark",
		AnchorPoint = Vector2.new(opts.anchor_x or 1, opts.anchor_y or 0),
		Position = UDim2.new(
			opts.x_scale or 1,
			opts.x_offset or -8,
			opts.y_scale or 0,
			opts.y_offset or (BAR_HEIGHT + 8)
		),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		BackgroundColor3 = theme["Window Background"],
		Theme = "Window Background",
		ThemeProp = "BackgroundColor3",
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		Active = true,
		Visible = opts.enabled == true,
		ZIndex = 45,
	})
	self.watermark = mark
	self:apply_wash(mark)

	self:create("Frame", {
		Parent = mark,
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = theme.Accent,
		Theme = "Accent",
		ThemeProp = "BackgroundColor3",
		BorderSizePixel = 0,
		ZIndex = 46,
	})

	self:create("UIPadding", {
		Parent = mark,
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	})

	self.watermark_label = self:create("TextLabel", {
		Parent = mark,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Font = Enum.Font.SourceSans,
		Text = self:watermark_text(),
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 47,
	})

	self:make_draggable(mark, mark, function()
		self:save_watermark_opts()
	end)

	local panel, inner = self:make_panel({
		Parent = self.gui,
		Name = "WatermarkPanel",
		Position = UDim2.fromOffset(48, BAR_HEIGHT + 48),
		Size = UDim2.fromOffset(240, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 50,
	})
	self.watermark_panel = panel
	self:create("UIPadding", {
		Parent = inner,
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	self:create("UIListLayout", {
		Parent = inner,
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "watermark",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		LayoutOrder = 1,
		ZIndex = 52,
	})

	self.watermark_toggles = {}
	self:watermark_toggle(inner, "enabled", "enabled", 2)
	self:watermark_toggle(inner, "user", "name", 3)
	self:watermark_toggle(inner, "time", "time", 4)
	self:watermark_toggle(inner, "fps", "fps", 5)
	self:watermark_toggle(inner, "ping", "ping", 6)

	self:drag_handle(panel)

	self._fps = 0
	self._ping = 0
	local frames = 0
	local last = os.clock()
	self:connect(run_service.RenderStepped, function()
		frames += 1
		local now = os.clock()
		if now - last >= 1 then
			self._fps = frames
			frames = 0
			last = now
			self._ping = self:read_ping()
			if self.watermark and self.watermark.Visible then
				self.watermark_label.Text = self:watermark_text()
			end
		end
	end)

	self:refresh_watermark()
end

function veteran:connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self.connections, connection)
	return connection
end

function veteran:tween(inst, props, duration, style, direction)
	local tween = tween_service:Create(
		inst,
		TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

function veteran:cancel_tweens(inst)
	if not inst then
		return
	end
	pcall(function()
		for _, tw in ipairs(tween_service:GetTweensOf(inst)) do
			tw:Cancel()
		end
	end)
end

function veteran:wait_tween(inst, props, duration, style, direction)
	local tween = self:tween(inst, props, duration, style, direction)
	tween.Completed:Wait()
end

local function wash(parent)
	return veteran:create("UIGradient", {
		Parent = parent,
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 170, 170)),
		}),
	})
end

function veteran:apply_wash(parent)
	return wash(parent)
end

function veteran:edge(frame, kind)
	if not frame then
		return
	end
	frame.BorderSizePixel = 1
	if kind == "window" then
		frame.BorderColor3 = Color3.fromRGB(10, 10, 10)
	else
		frame.BorderColor3 = theme["Object Border"]
		self:bind_theme(frame, "Object Border", "BorderColor3")
	end
end

function veteran:accent_cap(parent, z)
	return self:create("Frame", {
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = theme.Accent,
		Theme = "Accent",
		ThemeProp = "BackgroundColor3",
		BorderSizePixel = 0,
		ZIndex = z or ((parent and parent.ZIndex or 50) + 2),
	})
end

function veteran:make_panel(props)
	props = props or {}
	local z = props.ZIndex or 50
	local auto = props.AutomaticSize
	local panel = self:create("Frame", {
		Parent = props.Parent or self.gui,
		Name = props.Name,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		AutomaticSize = auto,
		BackgroundColor3 = theme["Window Background"],
		Theme = "Window Background",
		ThemeProp = "BackgroundColor3",
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		Visible = props.Visible,
		Active = props.Active ~= false,
		ClipsDescendants = true,
		ZIndex = z,
	})
	wash(panel)
	self:accent_cap(panel, z + 2)
	local inner = self:create("Frame", {
		Parent = panel,
		Position = UDim2.fromOffset(2, 2),
		Size = auto == Enum.AutomaticSize.Y and UDim2.new(1, -4, 0, 0) or UDim2.new(1, -4, 1, -4),
		AutomaticSize = auto,
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ClipsDescendants = true,
		ZIndex = z + 1,
	})
	return panel, inner
end

-- Roblox registers SetCore a bit after inject. Calling it once usually
-- no-ops, so we keep retrying until it sticks.
local CORE_TYPES = {}
for _, name in ipairs({ "Chat", "PlayerList", "Backpack", "EmotesMenu", "Health", "Captures" }) do
	pcall(function()
		table.insert(CORE_TYPES, Enum.CoreGuiType[name])
	end)
end

local function set_core(name, value)
	local ok = pcall(function()
		starter_gui:SetCore(name, value)
	end)
	return ok
end

local function is_ours(inst)
	if not inst then
		return false
	end
	if veteran.gui and (inst == veteran.gui or inst:IsDescendantOf(veteran.gui)) then
		return true
	end
	return false
end

local function pin_hidden(inst)
	if not inst or not veteran._topbar_hide then
		return
	end
	veteran._chrome_pins = veteran._chrome_pins or {}
	if veteran._chrome_pins[inst] then
		return
	end
	veteran._chrome_pins[inst] = true
	if inst:IsA("LayerCollector") then
		veteran:connect(inst:GetPropertyChangedSignal("Enabled"), function()
			if veteran._topbar_hide and inst.Enabled then
				pcall(function()
					inst.Enabled = false
				end)
			end
		end)
	elseif inst:IsA("GuiObject") then
		veteran:connect(inst:GetPropertyChangedSignal("Visible"), function()
			if veteran._topbar_hide and inst.Visible then
				pcall(function()
					inst.Visible = false
				end)
			end
		end)
	end
end

local function hide_instance(inst)
	if not inst or is_ours(inst) then
		return
	end
	if inst:IsA("LayerCollector") then
		if not veteran.hidden_guis[inst] then
			veteran.hidden_guis[inst] = { kind = "enabled", value = inst.Enabled }
		end
		pcall(function()
			inst.Enabled = false
		end)
	elseif inst:IsA("GuiObject") then
		if not veteran.hidden_guis[inst] then
			veteran.hidden_guis[inst] = { kind = "visible", value = inst.Visible }
		end
		pcall(function()
			inst.Visible = false
		end)
	else
		return
	end
	pin_hidden(inst)
end

local function hide_core_icons()
	pcall(function()
		starter_gui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	for _, kind in ipairs(CORE_TYPES) do
		pcall(function()
			starter_gui:SetCoreGuiEnabled(kind, false)
		end)
	end
end

local CORE_CHROME_NAMES = {
	TopBarApp = true,
	Unibar = true,
	UnibarLeftFrame = true,
	TopBarContainer = true,
	Chrome = true,
	ChromeWindow = true,
	nine_dot = true,
	chrome_menu = true,
	roblox_logo = true,
	experience = true,
	voice = true,
	unmute_mic = true,
	mute_mic = true,
}

local function name_is_topbar(name)
	local raw = tostring(name or "")
	if CORE_CHROME_NAMES[raw] then
		return true
	end
	name = string.lower(raw)
	if name:find("topbar", 1, true) or name:find("top_bar", 1, true) then
		return true
	end
	if name:find("unibar", 1, true) or name:find("topbarapp", 1, true) then
		return true
	end
	if name:find("iconcontainer", 1, true) or name:find("topbarcontainer", 1, true) then
		return true
	end
	if name:find("ninedot", 1, true) or name:find("nine_dot", 1, true) then
		return true
	end
	if name:find("chrome", 1, true) or name:find("voice", 1, true) then
		return true
	end
	return false
end

local function watch_chrome_root(root)
	if not root or not veteran._topbar_hide then
		return
	end
	veteran._chrome_watched = veteran._chrome_watched or {}
	if veteran._chrome_watched[root] then
		return
	end
	veteran._chrome_watched[root] = true
	veteran:connect(root.ChildAdded, function(child)
		if not veteran._topbar_hide or is_ours(child) then
			return
		end
		if name_is_topbar(child.Name) then
			hide_instance(child)
			watch_chrome_root(child)
		end
	end)
end

local function hide_core_chrome()
	for _, child in ipairs(core_gui:GetChildren()) do
		if is_ours(child) then
			continue
		end
		local dive = name_is_topbar(child.Name) or child.Name == "RobloxGui" or child:IsA("LayerCollector")
		if name_is_topbar(child.Name) then
			hide_instance(child)
			watch_chrome_root(child)
		end
		if not dive then
			continue
		end
		for _, grand in ipairs(child:GetChildren()) do
			if is_ours(grand) then
				continue
			end
			if name_is_topbar(grand.Name) then
				hide_instance(grand)
				watch_chrome_root(grand)
			end
			if name_is_topbar(grand.Name) or grand.Name == "TopBarApp" then
				for _, great in ipairs(grand:GetChildren()) do
					if not is_ours(great) and name_is_topbar(great.Name) then
						hide_instance(great)
					end
				end
			end
		end
	end
end

local function is_topbar_plus_gui(inst)
	return inst and inst.Name == "TopbarStandard"
end

local function is_fullscreen_title(inst)
	if not inst or is_ours(inst) then
		return false
	end
	local name = tostring(inst.Name or "")
	if name == "InGameFullscreenTitleBarScreen" or name == "InGameFullscreenTitleBar" or name == "FullscreenTitleBar" then
		return true
	end
	return string.lower(name):find("fullscreentitle", 1, true) ~= nil
end

function veteran:each_fullscreen_title(fn)
	local seen = {}
	local function consider(inst)
		if not inst or seen[inst] or not is_fullscreen_title(inst) then
			return
		end
		seen[inst] = true
		fn(inst)
	end
	consider(core_gui:FindFirstChild("InGameFullscreenTitleBarScreen"))
	consider(core_gui:FindFirstChild("InGameFullscreenTitleBar"))
	consider(core_gui:FindFirstChild("FullscreenTitleBar"))
	for _, child in ipairs(core_gui:GetChildren()) do
		consider(child)
	end
end

function veteran:pin_fullscreen_title(inst)
	self._fs_title_pins = self._fs_title_pins or {}
	if self._fs_title_pins[inst] then
		return
	end
	self._fs_title_pins[inst] = true
	if inst:IsA("LayerCollector") then
		self:connect(inst:GetPropertyChangedSignal("Enabled"), function()
			if self:layout_value("hide_fullscreen_exit") and inst.Enabled then
				pcall(function()
					inst.Enabled = false
				end)
			end
		end)
	elseif inst:IsA("GuiObject") then
		self:connect(inst:GetPropertyChangedSignal("Visible"), function()
			if self:layout_value("hide_fullscreen_exit") and inst.Visible then
				pcall(function()
					inst.Visible = false
				end)
			end
		end)
	end
end

function veteran:apply_fullscreen_title()
	if not self:wants_coregui_redesign() then
		return
	end
	local hide = self:layout_value("hide_fullscreen_exit")
	self:each_fullscreen_title(function(inst)
		if hide then
			if inst:IsA("LayerCollector") then
				if not self.hidden_guis[inst] then
					self.hidden_guis[inst] = { kind = "enabled", value = inst.Enabled }
				end
				pcall(function()
					inst.Enabled = false
				end)
			elseif inst:IsA("GuiObject") then
				if not self.hidden_guis[inst] then
					self.hidden_guis[inst] = { kind = "visible", value = inst.Visible }
				end
				pcall(function()
					inst.Visible = false
				end)
			end
			self:pin_fullscreen_title(inst)
		else
			local saved = self.hidden_guis[inst]
			if inst:IsA("LayerCollector") then
				pcall(function()
					inst.Enabled = saved and saved.value or true
				end)
			elseif inst:IsA("GuiObject") then
				pcall(function()
					inst.Visible = saved and saved.value or true
				end)
			end
		end
	end)
end

function veteran:is_tooltip_layer(inst)
	if not inst or is_ours(inst) then
		return false
	end
	return inst.Name == "TooltipLayer"
end

function veteran:pin_tooltip_layer(inst)
	self._tooltip_pins = self._tooltip_pins or {}
	if self._tooltip_pins[inst] then
		return
	end
	self._tooltip_pins[inst] = true
	if inst:IsA("LayerCollector") then
		self:connect(inst:GetPropertyChangedSignal("Enabled"), function()
			if self._topbar_hide and inst.Enabled then
				pcall(function()
					inst.Enabled = false
				end)
			end
		end)
	elseif inst:IsA("GuiObject") then
		self:connect(inst:GetPropertyChangedSignal("Visible"), function()
			if self._topbar_hide and inst.Visible then
				pcall(function()
					inst.Visible = false
				end)
			end
		end)
	end
end

function veteran:kill_tooltip_layer(inst)
	if not self._topbar_hide then
		return
	end
	if not inst then
		inst = core_gui:FindFirstChild("TooltipLayer")
	end
	if not self:is_tooltip_layer(inst) then
		return
	end
	if inst:IsA("LayerCollector") then
		pcall(function()
			inst.Enabled = false
		end)
	elseif inst:IsA("GuiObject") then
		pcall(function()
			inst.Visible = false
		end)
	end
	self:pin_tooltip_layer(inst)
end

function veteran:restore_tooltip_layer()
	local inst = core_gui:FindFirstChild("TooltipLayer")
	if not inst then
		return
	end
	if inst:IsA("LayerCollector") then
		pcall(function()
			inst.Enabled = true
		end)
	elseif inst:IsA("GuiObject") then
		pcall(function()
			inst.Visible = true
		end)
	end
end

function veteran:watch_tooltip_layer()
	if self._tooltip_watch_hooked then
		return
	end
	self._tooltip_watch_hooked = true
	self:connect(core_gui.ChildAdded, function(child)
		if not self._topbar_hide then
			return
		end
		if self:is_tooltip_layer(child) then
			self:kill_tooltip_layer(child)
		end
	end)
	task.spawn(function()
		while self.gui and self.gui.Parent do
			if self._topbar_hide then
				self:kill_tooltip_layer()
			end
			task.wait(0.2)
		end
		self._tooltip_watch_hooked = false
	end)
end

function veteran:hide_roblox_topbar(full)
	if full == nil then
		full = self:wants_coregui_redesign()
	end
	self._topbar_hide = true
	self._topbar_hide_full = full and true or false
	self:layout_native_chrome(false)
	if full then
		hide_core_icons()
		self:apply_fullscreen_title()
	end
	hide_core_chrome()
	self:watch_topbar_plus()
	self:layout_topbar_plus(false)
	self:watch_tooltip_layer()
	self:kill_tooltip_layer()
	if full then
		set_core("TopbarEnabled", false)
	end

	task.spawn(function()
		for _ = 1, 4 do
			if not self._topbar_hide then
				return
			end
			if self._topbar_hide_full then
				hide_core_icons()
				self:apply_fullscreen_title()
				set_core("TopbarEnabled", false)
			end
			hide_core_chrome()
			if not self._roblox_bar_open then
				self:layout_topbar_plus(false)
			end
			self:kill_tooltip_layer()
			if self.topbar then
				self.topbar.Visible = true
			end
			task.wait(0.75)
		end
	end)

	if self._topbar_watch_hooked then
		return
	end
	self._topbar_watch_hooked = true

	self:connect(core_gui.ChildAdded, function(child)
		if not self._topbar_hide or is_ours(child) then
			return
		end
		if is_fullscreen_title(child) then
			self:apply_fullscreen_title()
			return
		end
		if self:is_tooltip_layer(child) then
			self:kill_tooltip_layer(child)
			return
		end
		if name_is_topbar(child.Name) or child.Name == "RobloxGui" then
			hide_core_chrome()
		end
	end)

	task.spawn(function()
		local local_player = players.LocalPlayer or players.PlayerAdded:Wait()
		local player_gui = local_player:FindFirstChildOfClass("PlayerGui") or local_player:WaitForChild("PlayerGui")
		self:connect(player_gui.ChildAdded, function(child)
			if is_topbar_plus_gui(child) then
				self:layout_topbar_plus(self._roblox_bar_open and true or false)
			end
		end)
	end)
end

function veteran:restore_roblox_topbar()
	self._topbar_hide = false
	self._chrome_pins = nil
	self._chrome_watched = nil
	for inst, saved in pairs(self.hidden_guis) do
		if inst and inst.Parent then
			if saved.kind == "enabled" and inst:IsA("LayerCollector") then
				inst.Enabled = saved.value
			elseif saved.kind == "visible" and inst:IsA("GuiObject") then
				inst.Visible = saved.value
			end
		end
		self.hidden_guis[inst] = nil
	end
	pcall(function()
		starter_gui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
	set_core("TopbarEnabled", true)
	self:restore_tooltip_layer()
end

local NATIVE_BAR_Y = 40
local NATIVE_CHAT_SHIFT = 20
local NATIVE_BAR_SIZE = UDim2.new(1, 0, 0, 48)
local NATIVE_SHIFT_NAMES = {
	UnibarLeftFrame = true,
	MenuIconHolder = true,
	UnibarRightFrame = true,
	Unibar = true,
}

function veteran:collect_native_chrome()
	local found = {}
	local function take(inst, kind)
		if not inst or found[inst] or is_ours(inst) then
			return
		end
		if inst:IsA("LayerCollector") then
			for _, child in ipairs(inst:GetChildren()) do
				if child:IsA("GuiObject") then
					take(child, kind)
				end
			end
			return
		end
		if inst:IsA("GuiObject") then
			found[inst] = kind
		end
	end

	local function take_named(root)
		if not root then
			return
		end
		for name in pairs(NATIVE_SHIFT_NAMES) do
			local inst = root:FindFirstChild(name, true)
			if inst then
				take(inst, "roblox")
			end
		end
	end

	take_named(core_gui:FindFirstChild("TopBarApp"))
	local roblox_gui = core_gui:FindFirstChild("RobloxGui")
	if roblox_gui then
		take_named(roblox_gui:FindFirstChild("TopBarApp"))
	end

	take(core_gui:FindFirstChild("ExperienceChat"), "chat")

	local function scan_extra(root)
		if not root then
			return
		end
		for _, child in ipairs(root:GetChildren()) do
			if is_ours(child) or is_topbar_plus_gui(child) then
				continue
			end
			local name = string.lower(child.Name)
			local extra = name:find("iconcontainer", 1, true) or name:find("topbarplus", 1, true) or name:find("iconui", 1, true)
			if extra then
				take(child, "extra")
			end
			if child:IsA("LayerCollector") or extra then
				for _, grand in ipairs(child:GetChildren()) do
					if grand:IsA("GuiObject") and not self:looks_like_custom_bar(grand) then
						local abs_y = 999
						local abs_h = 0
						pcall(function()
							abs_y = grand.AbsolutePosition.Y
							abs_h = grand.AbsoluteSize.Y
						end)
						if abs_y <= 48 and abs_h > 0 and abs_h <= 72 then
							take(grand, "extra")
						end
					end
				end
			end
		end
	end

	scan_extra(core_gui)

	for inst in pairs(found) do
		local parent = inst.Parent
		while parent and parent ~= game do
			if found[parent] then
				found[inst] = nil
				break
			end
			parent = parent.Parent
		end
	end
	return found
end

function veteran:roblox_bar_anchor()
	local holder = self:menu_icon_holder()
	if holder then
		return holder
	end
	local function find_in(root)
		if not root then
			return nil
		end
		return root:FindFirstChild("UnibarLeftFrame", true) or root:FindFirstChild("MenuIconHolder", true)
	end
	local top = find_in(core_gui:FindFirstChild("TopBarApp"))
	if top then
		return top
	end
	local roblox_gui = core_gui:FindFirstChild("RobloxGui")
	return find_in(roblox_gui and roblox_gui:FindFirstChild("TopBarApp"))
end

function veteran:menu_icon_holder()
	local function find_in(root)
		if not root then
			return nil
		end
		local inner = root:FindFirstChild("TopBarApp") or root
		local holder = inner:FindFirstChild("MenuIconHolder") or root:FindFirstChild("MenuIconHolder", true)
		if holder and holder:IsA("GuiObject") then
			return holder
		end
		return nil
	end
	local holder = find_in(core_gui:FindFirstChild("TopBarApp"))
	if holder then
		return holder
	end
	local roblox_gui = core_gui:FindFirstChild("RobloxGui")
	return find_in(roblox_gui and roblox_gui:FindFirstChild("TopBarApp"))
end

function veteran:topbar_standard()
	local local_player = players.LocalPlayer
	local player_gui = local_player and local_player:FindFirstChildOfClass("PlayerGui")
	if not player_gui then
		return nil
	end
	local gui = player_gui:FindFirstChild("TopbarStandard")
	if gui and not is_ours(gui) then
		return gui
	end
	return nil
end

function veteran:topbar_standard_holders()
	local gui = self:topbar_standard()
	local holders = gui and gui:FindFirstChild("Holders")
	if holders and holders:IsA("GuiObject") then
		return holders, gui
	end
	return nil, gui
end

local PLUS_SIZE = UDim2.new(1, 0, 0, 48)
local PLUS_REST = UDim2.new(0, 16, 0, 40)

function veteran:plus_off_pos(holders)
	local width = 200
	pcall(function()
		width = math.max(holders.AbsoluteSize.X, 80)
	end)
	return UDim2.new(0, 16 - width - 24, 0, 40)
end

function veteran:plus_target_pos(holders)
	if self._plus_slide then
		return PLUS_REST
	end
	return self:plus_off_pos(holders)
end

function veteran:each_plus_widget(holders, fn)
	if not holders then
		return
	end
	for _, inst in ipairs(holders:GetDescendants()) do
		if inst.Name == "Widget" and inst:IsA("GuiObject") then
			fn(inst)
		end
	end
end

function veteran:lift_topbar_standard(gui)
	if not gui or not gui:IsA("LayerCollector") then
		return
	end
	pcall(function()
		if gui.DisplayOrder < 5100 then
			gui.DisplayOrder = 5100
		end
		gui.IgnoreGuiInset = true
	end)
	self._plus_order_pins = self._plus_order_pins or {}
	if not self._plus_order_pins[gui] then
		self._plus_order_pins[gui] = true
		self:connect(gui:GetPropertyChangedSignal("DisplayOrder"), function()
			if self._plus_released then
				return
			end
			if gui.DisplayOrder < 5100 then
				pcall(function()
					gui.DisplayOrder = 5100
				end)
			end
		end)
	end
	local holders = gui:FindFirstChild("Holders")
	if holders and holders:IsA("GuiObject") then
		pcall(function()
			holders.Active = false
			holders.Visible = true
		end)
	end
end

function veteran:scale_plus_widget(widget)
	if not widget or not widget:IsA("GuiObject") then
		return
	end
	self._plus_widget_dest = self._plus_widget_dest or {}
	local dest = self._plus_widget_dest[widget]
	if not dest then
		local size = widget.Size
		local width = size.X.Offset
		local height = size.Y.Offset
		if width > 0 and height > 0 and math.abs(width - height) < 2 and width <= 48 then
			dest = UDim2.fromOffset(48, 48)
		else
			dest = UDim2.new(size.X.Scale, size.X.Offset, 0, 48)
		end
		self._plus_widget_dest[widget] = dest
		self:connect(widget:GetPropertyChangedSignal("Size"), function()
			if self._plus_released or self._native_lock then
				return
			end
			if widget.Size ~= dest then
				self._native_lock = true
				pcall(function()
					widget.Size = dest
				end)
				self._native_lock = false
			end
		end)
	end
	if widget.Size == dest then
		return
	end
	self._native_lock = true
	pcall(function()
		widget.Size = dest
	end)
	self._native_lock = false
end

function veteran:pin_plus_holders(holders)
	self._plus_pins = self._plus_pins or {}
	if self._plus_pins[holders] then
		return
	end
	self._plus_pins[holders] = true
	local function keep()
		if self._native_lock or self._plus_released or self._plus_tweening then
			return
		end
		self:lock_plus_holders(holders)
	end
	self:connect(holders:GetPropertyChangedSignal("Size"), keep)
	self:connect(holders:GetPropertyChangedSignal("Position"), keep)
	self:connect(holders.DescendantAdded, function(child)
		if self._plus_released then
			return
		end
		if child.Name == "Widget" and child:IsA("GuiObject") then
			self:scale_plus_widget(child)
		end
	end)
end

function veteran:lock_plus_holders(holders)
	if not holders or not holders.Parent then
		return
	end
	self._native_lock = true
	pcall(function()
		holders.Visible = true
		holders.Size = PLUS_SIZE
		if not self._plus_tweening then
			if self._plus_slide or not self._plus_opened then
				holders.Position = PLUS_REST
			else
				holders.Position = self:plus_off_pos(holders)
			end
		end
	end)
	self._native_lock = false
	self:each_plus_widget(holders, function(widget)
		self:scale_plus_widget(widget)
	end)
end

function veteran:slide_plus(on)
	local holders, gui = self:topbar_standard_holders()
	if gui then
		self:lift_topbar_standard(gui)
	end
	if not holders then
		return
	end
	self:pin_plus_holders(holders)
	on = on and true or false
	if not self._plus_ready then
		self._plus_ready = true
		self._plus_slide = true
		self._plus_opened = true
		self._native_lock = true
		pcall(function()
			holders.Visible = true
			holders.Size = PLUS_SIZE
			holders.Position = PLUS_REST
		end)
		self._native_lock = false
		self:each_plus_widget(holders, function(widget)
			self:scale_plus_widget(widget)
		end)
		if on then
			self._plus_boot_hide = nil
			return
		end
		-- inject starts at rest, then slides the custom buttons off
		self._plus_boot_hide = true
		task.delay(0.22, function()
			if self._plus_released or self._roblox_bar_open then
				self._plus_boot_hide = nil
				return
			end
			self._plus_boot_hide = nil
			self:slide_plus(false)
		end)
		return
	end
	if self._plus_boot_hide and not on then
		self:lock_plus_holders(holders)
		return
	end
	if on then
		self._plus_opened = true
		self._plus_boot_hide = nil
		if self._plus_slide then
			self:lock_plus_holders(holders)
			return
		end
	elseif not self._plus_slide then
		self:lock_plus_holders(holders)
		return
	elseif not self._plus_opened then
		self:lock_plus_holders(holders)
		return
	end
	self._plus_slide = on
	local dest = on and PLUS_REST or self:plus_off_pos(holders)
	self:cancel_tweens(holders)
	self._plus_tweening = true
	self._native_lock = true
	pcall(function()
		holders.Visible = true
		holders.Size = PLUS_SIZE
	end)
	self._native_lock = false
	self:tween(holders, { Position = dest }, 0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	task.delay(0.3, function()
		self._plus_tweening = false
		if holders and holders.Parent and not self._plus_released then
			self:lock_plus_holders(holders)
		end
	end)
	self:each_plus_widget(holders, function(widget)
		self:scale_plus_widget(widget)
	end)
end

function veteran:watch_topbar_plus()
	if self._plus_watch_hooked then
		return
	end
	self._plus_watch_hooked = true
	task.spawn(function()
		local local_player = players.LocalPlayer or players.PlayerAdded:Wait()
		local player_gui = local_player:FindFirstChildOfClass("PlayerGui") or local_player:WaitForChild("PlayerGui")
		local function hook_gui(gui)
			if not is_topbar_plus_gui(gui) then
				return
			end
			self:connect(gui.DescendantAdded, function()
				self:layout_topbar_plus(self._roblox_bar_open and true or false)
			end)
			self:layout_topbar_plus(self._roblox_bar_open and true or false)
		end
		self:connect(player_gui.ChildAdded, function(child)
			hook_gui(child)
		end)
		hook_gui(player_gui:FindFirstChild("TopbarStandard"))
		self:layout_topbar_plus(self._roblox_bar_open and true or false)
	end)
end

function veteran:layout_topbar_plus(on)
	self:watch_topbar_plus()
	self:slide_plus(on and true or false)
end

function veteran:release_topbar_plus()
	self._plus_released = true
	self._plus_pins = {}
	self._plus_order_pins = {}
	self._plus_widget_dest = {}
	self._plus_tweening = nil
	self._plus_slide = nil
	self._plus_ready = nil
	self._plus_opened = nil
	self._plus_boot_hide = nil
end

function veteran:looks_like_custom_bar(inst)
	if not inst or not inst:IsA("GuiObject") then
		return false
	end
	local ok, size = pcall(function()
		return inst.Size
	end)
	if not ok or typeof(size) ~= "UDim2" then
		return false
	end
	return size.X.Scale >= 0.95 and size.Y.Scale >= 0.9
end

function veteran:roblox_bar_size()
	local function search(root)
		if not root then
			return nil
		end
		for _, inst in ipairs(root:GetDescendants()) do
			if inst:IsA("GuiObject") then
				local size = inst.Size
				if size.X.Scale == 1 and size.Y.Scale == 0 and size.Y.Offset == 48 then
					return size
				end
			end
		end
		return nil
	end
	return search(core_gui:FindFirstChild("TopBarApp"))
		or search(core_gui:FindFirstChild("RobloxGui"))
		or NATIVE_BAR_SIZE
end

function veteran:roblox_bar_abs_y()
	local anchor = self:roblox_bar_anchor()
	if anchor and anchor:IsA("GuiObject") then
		return anchor.AbsolutePosition.Y
	end
	return NATIVE_BAR_Y
end

function veteran:nudge_abs_y(inst, target_y)
	if not inst or not inst.Parent or self._native_lock then
		return
	end
	local current = inst.AbsolutePosition.Y
	local delta = target_y - current
	if math.abs(delta) < 1 then
		return
	end
	local pos = inst.Position
	self._native_lock = true
	pcall(function()
		inst.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset + delta)
	end)
	self._native_lock = false
end

function veteran:apply_native_bar_size(inst)
	if not inst or not inst.Parent then
		return
	end
	if not self:looks_like_custom_bar(inst) and not (self._native_size and self._native_size[inst]) then
		return
	end
	self._native_size = self._native_size or {}
	if not self._native_size[inst] then
		self._native_size[inst] = inst.Size
	end
	local dest = self:roblox_bar_size()
	self._native_size_dest = self._native_size_dest or {}
	self._native_size_dest[inst] = dest
	if inst.Size == dest then
		return
	end
	self._native_lock = true
	pcall(function()
		inst.Size = dest
	end)
	self._native_lock = false
end

function veteran:align_extra_chrome()
	local target = self:roblox_bar_abs_y()
	for inst, kind in pairs(self._native_kind or {}) do
		if kind == "extra" and inst and inst.Parent then
			self:apply_native_bar_size(inst)
			self:nudge_abs_y(inst, target)
		end
	end
end

function veteran:ensure_native_align_loop()
	if self._native_align_hooked then
		return
	end
	self._native_align_hooked = true
	self:connect(run_service.Heartbeat, function()
		if not self._roblox_bar_open then
			return
		end
		self:align_extra_chrome()
	end)
end

function veteran:native_dest(inst, kind)
	local pos = inst.Position
	if kind == "roblox" then
		return UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, NATIVE_BAR_Y)
	end
	if kind == "extra" then
		return pos
	end
	return UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset + NATIVE_CHAT_SHIFT)
end

function veteran:pin_native_shift(inst, kind)
	self._native_pins = self._native_pins or {}
	if self._native_pins[inst] then
		return
	end
	self._native_pins[inst] = true
	self:connect(inst:GetPropertyChangedSignal("Size"), function()
		if not self._roblox_bar_open or self._native_lock or kind ~= "extra" then
			return
		end
		self:apply_native_bar_size(inst)
	end)
	self:connect(inst:GetPropertyChangedSignal("Position"), function()
		if not self._roblox_bar_open or self._native_lock then
			return
		end
		if kind == "extra" then
			self:apply_native_bar_size(inst)
			self:nudge_abs_y(inst, self:roblox_bar_abs_y())
			return
		end
		local dest = self._native_dest and self._native_dest[inst]
		if not dest then
			return
		end
		local pos = inst.Position
		if math.abs(pos.Y.Offset - dest.Y.Offset) > 0.5 or pos.Y.Scale ~= dest.Y.Scale then
			self._native_lock = true
			pcall(function()
				inst.Position = UDim2.new(pos.X.Scale, pos.X.Offset, dest.Y.Scale, dest.Y.Offset)
			end)
			self._native_lock = false
		end
	end)
end

function veteran:apply_native_shift(inst, kind)
	if not inst or not inst.Parent then
		return
	end
	self._native_shift = self._native_shift or {}
	self._native_ready = self._native_ready or {}
	self._native_dest = self._native_dest or {}
	self._native_kind = self._native_kind or {}
	self._native_kind[inst] = kind
	if not self._native_shift[inst] then
		self._native_shift[inst] = inst.Position
	end
	local origin = self._native_shift[inst]
	local dest
	if kind == "roblox" then
		dest = UDim2.new(origin.X.Scale, origin.X.Offset, origin.Y.Scale, NATIVE_BAR_Y)
	elseif kind == "extra" then
		dest = origin
	else
		dest = UDim2.new(origin.X.Scale, origin.X.Offset, origin.Y.Scale, origin.Y.Offset + NATIVE_CHAT_SHIFT)
	end
	self._native_dest[inst] = dest
	self:pin_native_shift(inst, kind)
	if kind == "extra" then
		self:apply_native_bar_size(inst)
		if not self._native_ready[inst] then
			self._native_ready[inst] = true
			self:cancel_tweens(inst)
			self:nudge_abs_y(inst, self:roblox_bar_abs_y())
			local pos = inst.Position
			local width = 80
			pcall(function()
				width = math.max(inst.AbsoluteSize.X, 80)
			end)
			self._native_lock = true
			pcall(function()
				inst.Position = UDim2.new(pos.X.Scale, pos.X.Offset - width - 28, pos.Y.Scale, pos.Y.Offset)
			end)
			self._native_lock = false
			self:tween(inst, { Position = pos }, 0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		end
		self:nudge_abs_y(inst, self:roblox_bar_abs_y())
		return
	end
	if self._native_ready[inst] then
		self._native_lock = true
		pcall(function()
			inst.Position = dest
		end)
		self._native_lock = false
		return
	end
	self._native_ready[inst] = true
	self._native_lock = true
	self:cancel_tweens(inst)
	local width = 80
	pcall(function()
		width = math.max(inst.AbsoluteSize.X, 80)
	end)
	pcall(function()
		inst.Position = UDim2.new(dest.X.Scale, dest.X.Offset - width - 28, dest.Y.Scale, dest.Y.Offset)
	end)
	self._native_lock = false
	self:tween(inst, { Position = dest }, 0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
end

function veteran:layout_native_chrome(on)
	if on then
		local found = self:collect_native_chrome()
		for inst, kind in pairs(found) do
			if kind ~= "extra" then
				self:apply_native_shift(inst, kind)
			end
		end
		for inst, kind in pairs(found) do
			if kind == "extra" then
				self:apply_native_shift(inst, kind)
			end
		end
		self:ensure_native_align_loop()
		self:align_extra_chrome()
		self:layout_topbar_plus(true)
		return
	end
	self:layout_topbar_plus(false)
	for inst, origin in pairs(self._native_shift or {}) do
		if inst and inst.Parent then
			self:cancel_tweens(inst)
			pcall(function()
				inst.Position = origin
			end)
		end
	end
	for inst, size in pairs(self._native_size or {}) do
		if inst and inst.Parent then
			pcall(function()
				inst.Size = size
			end)
		end
	end
	self._native_shift = {}
	self._native_ready = {}
	self._native_dest = {}
	self._native_kind = {}
	self._native_size = {}
	self._native_size_dest = {}
end

function veteran:watch_native_shift()
	if self._native_shift_hooked then
		return
	end
	self._native_shift_hooked = true
	self:connect(core_gui.ChildAdded, function()
		if not self._roblox_bar_open then
			return
		end
		task.defer(function()
			if self._roblox_bar_open then
				self:layout_native_chrome(true)
			end
		end)
	end)
	local local_player = players.LocalPlayer
	local player_gui = local_player and local_player:FindFirstChildOfClass("PlayerGui")
	if player_gui then
		local function relayout()
			if not self._roblox_bar_open then
				return
			end
			task.defer(function()
				if self._roblox_bar_open then
					self:layout_native_chrome(true)
					self:layout_topbar_plus(true)
				end
			end)
		end
		self:connect(player_gui.ChildAdded, function(child)
			relayout()
			if is_topbar_plus_gui(child) then
				self:connect(child.ChildAdded, function()
					relayout()
				end)
			end
		end)
		for _, child in ipairs(player_gui:GetChildren()) do
			if is_topbar_plus_gui(child) then
				self:connect(child.ChildAdded, function()
					relayout()
				end)
			end
		end
	end
end

function veteran:mount_gui()
	if self.gui then
		self.gui:Destroy()
	end

	local parent = core_gui
	pcall(function()
		parent = gethui and gethui() or core_gui
	end)

	self.gui = self:create("ScreenGui", {
		Name = "veteran",
		Parent = parent,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = true,
	})

	return self.gui
end

function veteran:build_splash()
	local overlay = self:create("Frame", {
		Parent = self.gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 20,
	})

	local window = self:create("Frame", {
		Parent = overlay,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(250, 86),
		BackgroundColor3 = theme["Window Background"],
		BorderColor3 = theme["Window Border"],
		BorderSizePixel = 1,
		ZIndex = 21,
	})

	local inner = self:create("Frame", {
		Parent = window,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = theme["Section Background"],
		BorderColor3 = theme["Section Border"],
		BorderSizePixel = 1,
		ZIndex = 22,
	})
	wash(inner)

	self:create("Frame", {
		Parent = inner,
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		ZIndex = 23,
	})

	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 14),
		Size = UDim2.new(1, -20, 0, 20),
		Font = Enum.Font.SourceSans,
		Text = "veteran",
		TextSize = 18,
		TextColor3 = theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 24,
	})

	local track = self:create("Frame", {
		Parent = inner,
		Position = UDim2.new(0, 10, 1, -20),
		Size = UDim2.new(1, -20, 0, 6),
		BackgroundColor3 = theme["Object Background"],
		BorderColor3 = theme["Object Border"],
		BorderSizePixel = 1,
		ZIndex = 24,
	})

	local bar = self:create("Frame", {
		Parent = track,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		ZIndex = 25,
	})

	return overlay, window, bar
end

local function changelog_tag_color(tag)
	if tag == "+" then
		return theme.Accent
	end
	if tag == "-" then
		return Color3.fromRGB(220, 90, 90)
	end
	if tag == "M" then
		return Color3.fromRGB(204, 164, 50)
	end
	return theme["Disabled Text"]
end

function veteran:set_changelog(entries)
	self.changelog = type(entries) == "table" and entries or {}
	self:refresh_info_log()
	return self
end

function veteran:refresh_info_log()
	if not self.info_list then
		return
	end
	clear_fill(self.info_list)
	self.info_rows = {}
	for i, entry in ipairs(self.changelog or {}) do
		local tag_text = entry.tag
		local jump = entry.jump
		local row = self:create("TextButton", {
			Parent = self.info_list,
			Size = UDim2.new(1, 0, 0, ROW_H),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Active = jump ~= nil,
			LayoutOrder = i,
			ZIndex = 55,
		})
		local tag
		local text_left = 0
		if type(tag_text) == "string" and tag_text ~= "" then
			tag = self:create("TextLabel", {
				Parent = row,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(28, ROW_H),
				Font = Enum.Font.SourceSans,
				Text = "[" .. tag_text .. "]",
				TextSize = TEXT_SIZE,
				TextColor3 = changelog_tag_color(tag_text),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.5,
				ZIndex = 56,
			})
			text_left = 32
		end
		local label = self:create("TextLabel", {
			Parent = row,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(text_left, 0),
			Size = UDim2.new(1, -text_left, 1, 0),
			Font = Enum.Font.SourceSans,
			Text = entry.text or "",
			TextSize = TEXT_SIZE,
			ThemeText = tag_text == "" and "Disabled Text" or "Text",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			ZIndex = 56,
		})
		if jump then
			self:connect(row.MouseEnter, function()
				if label then
					self:tween(label, { TextColor3 = theme.Accent }, 0.12)
				end
			end)
			self:connect(row.MouseLeave, function()
				if label then
					self:tween(label, { TextColor3 = theme.Text }, 0.12)
				end
			end)
			self:connect(row.MouseButton1Click, function()
				self:reveal_feature(jump)
			end)
		end
		self.info_rows[i] = { row = row, tag = tag, label = label }
	end
end

function veteran:stop_info_intro()
	self._info_intro_token = (self._info_intro_token or 0) + 1
	for _, tw in ipairs(self._info_tweens or {}) do
		pcall(function()
			tw:Cancel()
		end)
	end
	self._info_tweens = {}
	local function snap(inst, key, value)
		if not inst then
			return
		end
		self:cancel_tweens(inst)
		inst[key] = value
	end
	snap(self.info_version_scale, "Scale", 1)
	snap(self.info_version_label, "TextTransparency", 0)
	snap(self.info_version_hint, "TextTransparency", 0)
	for _, pack in ipairs(self.info_rows or {}) do
		snap(pack.tag, "TextTransparency", 0)
		snap(pack.label, "TextTransparency", 0)
	end
end

function veteran:set_info_open(open)
	local panel = self.info_panel
	if not panel then
		return
	end
	self._info_open_token = (self._info_open_token or 0) + 1
	local token = self._info_open_token
	self:cancel_tweens(panel)
	if open then
		panel.Visible = true
		panel.Position = UDim2.fromOffset(-INFO_WIDTH, BAR_HEIGHT)
		self._info_slide_tween = self:tween(
			panel,
			{ Position = UDim2.fromOffset(0, BAR_HEIGHT) },
			0.22,
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.Out
		)
		self:play_info_intro()
		return
	end
	self:stop_info_intro()
	self._info_slide_tween = self:tween(
		panel,
		{ Position = UDim2.fromOffset(-INFO_WIDTH, BAR_HEIGHT) },
		0.18,
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.In
	)
	self:connect(self._info_slide_tween.Completed, function()
		if token ~= self._info_open_token then
			return
		end
		if self.open_tabs and self.open_tabs.info then
			return
		end
		panel.Visible = false
	end)
end

function veteran:play_info_intro()
	self:stop_info_intro()
	local token = self._info_intro_token
	self._info_tweens = {}
	local rows = self.info_rows
	if not rows then
		return
	end
	local function fade(inst, props, duration)
		if not inst then
			return
		end
		local tw = self:tween(inst, props, duration)
		table.insert(self._info_tweens, tw)
		return tw
	end
	if self.info_version_scale then
		self.info_version_scale.Scale = 0.9
		fade(self.info_version_scale, { Scale = 1 }, 0.2)
	end
	if self.info_version_label then
		self.info_version_label.TextTransparency = 1
		fade(self.info_version_label, { TextTransparency = 0 }, 0.2)
	end
	if self.info_version_hint then
		self.info_version_hint.TextTransparency = 1
		task.delay(0.08, function()
			if token ~= self._info_intro_token or not self.info_version_hint then
				return
			end
			fade(self.info_version_hint, { TextTransparency = 0 }, 0.18)
		end)
	end
	for i, pack in ipairs(rows) do
		if pack.tag then
			pack.tag.TextTransparency = 1
		end
		if pack.label then
			pack.label.TextTransparency = 1
		end
		task.delay(0.04 * i, function()
			if token ~= self._info_intro_token then
				return
			end
			fade(pack.tag, { TextTransparency = 0 }, 0.16)
			fade(pack.label, { TextTransparency = 0 }, 0.18)
		end)
	end
end

function veteran:clear_preview_rig()
	if self._preview_clone then
		pcall(function()
			self._preview_clone:Destroy()
		end)
		self._preview_clone = nil
	end
	self._preview_user_id = nil
	self._preview_parts = nil
end

function veteran:set_preview_target(player)
	if typeof(player) ~= "Instance" then
		player = nil
	end
	if self._preview_player == player then
		return
	end
	self._preview_player = player
end

function veteran:set_preview_spread(enabled, intensity)
	self._preview_spread_on = enabled and true or false
	self._preview_spread_value = tonumber(intensity) or 0
	if not self.preview_spread then
		return
	end
	local text
	if self._preview_spread_on then
		text = "spread  " .. tostring(math.floor(self._preview_spread_value + 0.5))
	else
		text = "spread  off"
	end
	if self.preview_spread.Text ~= text then
		self.preview_spread.Text = text
	end
end

function veteran:sync_preview_rig()
	local viewport = self.preview_viewport
	local world = self.preview_world
	if not viewport or not world or not self.preview_panel or not self.preview_panel.Visible then
		return
	end
	local player = self._preview_player
	if not player or not player.Parent then
		self:clear_preview_rig()
		if self.preview_empty then
			self.preview_empty.Visible = true
			self.preview_empty.Text = "no target"
		end
		if self.preview_name then
			self.preview_name.Text = "target  —"
		end
		return
	end
	local live = player.Character
	local hrp = live and live:FindFirstChild("HumanoidRootPart")
	if not live or not hrp then
		self:clear_preview_rig()
		if self.preview_empty then
			self.preview_empty.Visible = true
			self.preview_empty.Text = "no character"
		end
		if self.preview_name then
			self.preview_name.Text = "target  " .. (player.DisplayName or player.Name)
		end
		return
	end
	if self.preview_empty then
		self.preview_empty.Visible = false
	end
	if self.preview_name then
		local role = self:forced_role(player)
		local label = player.DisplayName or player.Name
		if role == "owner" or role == "dev" then
			label = label .. " [" .. role .. "]"
		end
		self.preview_name.Text = "target  " .. label
	end
	if self._preview_user_id ~= player.UserId or not self._preview_clone or not self._preview_clone.Parent then
		self:clear_preview_rig()
		live.Archivable = true
		local ok, clone = pcall(function()
			return live:Clone()
		end)
		live.Archivable = false
		if not ok or not clone then
			return
		end
		for _, inst in ipairs(clone:GetDescendants()) do
			if inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("Highlight") or inst:IsA("ForceField")
				or inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") or inst:IsA("Fire")
			then
				inst:Destroy()
			elseif inst:IsA("Humanoid") then
				inst.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				pcall(function()
					inst:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
				end)
			elseif inst:IsA("BasePart") then
				inst.Anchored = true
				inst.CanCollide = false
				inst.Massless = true
			end
		end
		clone.Parent = world
		self._preview_clone = clone
		self._preview_user_id = player.UserId
		self._preview_parts = {}
		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				self._preview_parts[#self._preview_parts + 1] = part
			end
		end
	end
	local clone = self._preview_clone
	local clone_hrp = clone and clone:FindFirstChild("HumanoidRootPart")
	if not clone or not clone_hrp then
		return
	end
	for _, part in ipairs(self._preview_parts or {}) do
		if part.Parent then
			local src = live:FindFirstChild(part.Name)
			if src and src:IsA("BasePart") then
				part.CFrame = hrp.CFrame:ToObjectSpace(src.CFrame)
			end
		end
	end
	local cam = self.preview_camera
	if cam then
		local spin = tick() * 0.35
		local dist = 6.2
		cam.CFrame = CFrame.new(Vector3.new(math.sin(spin) * dist, 1.6, math.cos(spin) * dist), Vector3.new(0, 1.1, 0))
	end
end

function veteran:build_preview_panel()
	local panel, inner = self:make_panel({
		Parent = self.gui,
		Name = "PreviewPanel",
		Position = UDim2.fromOffset(560, BAR_HEIGHT + 28),
		Size = UDim2.fromOffset(280, 418),
		Visible = false,
		ZIndex = 50,
	})
	self.preview_panel = panel

	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "preview",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 52,
	})

	self.preview_name = self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 24),
		Size = UDim2.new(1, -16, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "target  —",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 52,
	})

	local stage = self:create("Frame", {
		Parent = inner,
		Position = UDim2.fromOffset(8, 46),
		Size = UDim2.new(1, -16, 1, -86),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		ZIndex = 52,
	})
	local stage_inner = self:create("Frame", {
		Parent = stage,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 53,
	})
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Rig"
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(70, 70, 80)
	viewport.LightColor = Color3.fromRGB(210, 205, 220)
	viewport.LightDirection = Vector3.new(-1, -1, -0.6)
	viewport.ZIndex = 54
	viewport.Parent = stage_inner
	self.preview_viewport = viewport

	local world = Instance.new("WorldModel")
	world.Parent = viewport
	self.preview_world = world

	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.new(Vector3.new(0, 1.6, 6.2), Vector3.new(0, 1.1, 0))
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	self.preview_camera = cam

	self.preview_empty = self:create("TextLabel", {
		Parent = stage_inner,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.SourceSans,
		Text = "no target",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 55,
	})

	self.preview_spread = self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 1, -32),
		Size = UDim2.new(1, -16, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "spread  off",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 52,
	})

	self:drag_handle(panel)
	task.spawn(function()
		while self.gui and self.gui.Parent do
			if self._env_viewing then
				local player = self._env_view_player
				if not player or not player.Parent then
					self:clear_env_view()
				end
			end
			local preview_on = self.preview_panel and self.preview_panel.Visible
			if preview_on then
				self:sync_preview_rig()
				task.wait(0.14)
			else
				task.wait(0.3)
			end
		end
	end)
end

function veteran:build_info_panel()
	local panel = self:create("Frame", {
		Parent = self.gui,
		Name = "InfoDock",
		Position = UDim2.fromOffset(-INFO_WIDTH, BAR_HEIGHT),
		Size = UDim2.new(0, INFO_WIDTH, 1, -BAR_HEIGHT),
		BackgroundColor3 = theme["Window Background"],
		Theme = "Window Background",
		ThemeProp = "BackgroundColor3",
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		ClipsDescendants = true,
		ZIndex = 48,
	})
	wash(panel)
	self.info_panel = panel

	self:create("Frame", {
		Parent = panel,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = theme["Window Border"],
		Theme = "Window Border",
		ThemeProp = "BackgroundColor3",
		BorderSizePixel = 0,
		ZIndex = 49,
	})
	self:create("Frame", {
		Parent = panel,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = theme.Accent,
		Theme = "Accent",
		ThemeProp = "BackgroundColor3",
		BorderSizePixel = 0,
		ZIndex = 50,
	})

	local shell = self:create("Frame", {
		Parent = panel,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -2, 1, 0),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 0,
		ZIndex = 49,
	})
	local inner = self:create("Frame", {
		Parent = shell,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ClipsDescendants = true,
		ZIndex = 50,
	})

	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = "info",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 52,
	})

	local version_outer = self:create("Frame", {
		Parent = inner,
		Position = UDim2.fromOffset(8, 30),
		Size = UDim2.new(1, -16, 0, 52),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		ZIndex = 52,
	})
	self.info_version_scale = self:create("UIScale", {
		Parent = version_outer,
		Scale = 1,
	})
	local version_inner = self:create("Frame", {
		Parent = version_outer,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 53,
	})
	self:create("TextLabel", {
		Parent = version_outer,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 0, 1),
		Font = Enum.Font.SourceSans,
		Text = "version",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 56,
	})
	self.info_version_label = self:create("TextLabel", {
		Parent = version_inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 20),
		Font = Enum.Font.SourceSans,
		Text = VERSION,
		TextSize = 18,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 54,
	})
	self.info_version_hint = self:create("TextLabel", {
		Parent = version_inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 0, 14),
		Font = Enum.Font.SourceSans,
		Text = "universal",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 54,
	})

	local log_outer = self:create("Frame", {
		Parent = inner,
		Position = UDim2.fromOffset(8, 94),
		Size = UDim2.new(1, -16, 1, -176),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		ZIndex = 52,
	})
	local log_wrap = self:create("Frame", {
		Parent = log_outer,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 53,
	})
	self:create("TextLabel", {
		Parent = log_outer,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 0, 1),
		Font = Enum.Font.SourceSans,
		Text = "changelog",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 56,
	})

	local list = self:create("ScrollingFrame", {
		Parent = log_wrap,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = theme.Accent,
		Theme = "Accent",
		ThemeProp = "ScrollBarImageColor3",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 54,
	})
	self:create("UIPadding", {
		Parent = list,
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	self:create("UIListLayout", {
		Parent = list,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	self.info_list = list
	self.info_rows = {}
	self:refresh_info_log()

	local license_outer = self:create("Frame", {
		Parent = inner,
		Position = UDim2.new(0, 8, 1, -74),
		Size = UDim2.new(1, -16, 0, 66),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BorderColor3 = Color3.fromRGB(10, 10, 10),
		BorderSizePixel = 1,
		ZIndex = 52,
	})
	local license_inner = self:create("Frame", {
		Parent = license_outer,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundColor3 = theme["Section Background"],
		Theme = "Section Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		ZIndex = 53,
	})
	self:create("TextLabel", {
		Parent = license_outer,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 0, 1),
		Font = Enum.Font.SourceSans,
		Text = "license",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 56,
	})
	self.info_role_label = self:create("TextLabel", {
		Parent = license_inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 18),
		Font = Enum.Font.SourceSans,
		Text = "role  —",
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 54,
	})
	self.info_key_label = self:create("TextButton", {
		Parent = license_inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 30),
		Size = UDim2.new(1, -20, 0, 18),
		Font = Enum.Font.SourceSans,
		Text = "key  —",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoButtonColor = false,
		ZIndex = 54,
	})
	self:connect(self.info_key_label.MouseButton1Click, function()
		local key = self.script_key
		if type(key) == "string" and key ~= "" then
			pcall(function()
				setclipboard(key)
			end)
		end
	end)
	self:refresh_info_license()
end

function veteran:refresh_info_license()
	local role = self:license_role()
	if self.info_role_label then
		self.info_role_label.Text = "role  " .. (role or "veteran")
	end
	local key = self.script_key
	if type(key) ~= "string" or key == "" then
		local session = env_table().veteran_session
		key = session and session.key
	end
	if self.info_key_label then
		self.info_key_label.Text = "key  " .. (type(key) == "string" and key ~= "" and key or "—")
	end
end

function veteran:build_topbar()
	local bar = self:create("Frame", {
		Parent = self.gui,
		Name = "VeteranChrome",
		Position = UDim2.fromOffset(0, -BAR_HEIGHT),
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
		BackgroundColor3 = theme["Window Background"],
		Theme = "Window Background",
		ThemeProp = "BackgroundColor3",
		BorderSizePixel = 0,
		ZIndex = 40,
	})
	wash(bar)

	self:create("Frame", {
		Parent = bar,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = theme["Window Border"],
		Theme = "Window Border",
		ThemeProp = "BackgroundColor3",
		BorderSizePixel = 0,
		ZIndex = 41,
	})

	self:create("Frame", {
		Parent = bar,
		Position = UDim2.new(0, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = theme.Accent,
		Theme = "Accent",
		ThemeProp = "BackgroundColor3",
		BorderSizePixel = 0,
		ZIndex = 42,
	})

	self.topbar_holder = self:create("Frame", {
		Parent = bar,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, -2),
		ZIndex = 43,
	})

	self:build_topbar_items()

	self.topbar = bar
	self:ensure_topbar_autohide()
	return bar
end

function veteran:ensure_topbar_autohide()
	if self._topbar_hover_hooked then
		return
	end
	self._topbar_hover_hooked = true
	self:connect(uis.InputChanged, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if not self:layout_value("topbar_autohide") then
			return
		end
		self:update_topbar_autohide(gui_mouse(input))
	end)
end

function veteran:set_topbar_revealed(on, instant)
	if not self.topbar then
		return
	end
	local shown = on and true or false
	if not self:layout_value("topbar_autohide") then
		shown = true
	end
	self._topbar_revealed = shown
	self.topbar.Visible = true
	local dest = shown and UDim2.fromOffset(0, 0) or UDim2.fromOffset(0, -BAR_HEIGHT)
	if instant then
		self.topbar.Position = dest
	else
		self:tween(self.topbar, { Position = dest }, TWEEN)
	end
	if not shown then
		self:set_chrome_menu_open(false)
	end
end

function veteran:update_topbar_autohide(mx, my)
	if not self:layout_value("topbar_autohide") then
		self:set_topbar_revealed(true)
		return
	end
	local over = my <= 10
	if self._topbar_revealed then
		over = my <= BAR_HEIGHT + 6
		if self.topbar and point_in(self.topbar, mx, my) then
			over = true
		end
		if self.chrome_menu_open and self.chrome_tray and point_in(self.chrome_tray, mx, my) then
			over = true
		end
	end
	self:set_topbar_revealed(over)
end

function veteran:apply_topbar_autohide()
	self:ensure_topbar_autohide()
	if not self:layout_value("topbar_autohide") then
		self:set_topbar_revealed(true)
		return
	end
	self:update_topbar_autohide(gui_mouse())
end

function veteran:bar_box(parent, text, layout_order)
	local box = self:create("Frame", {
		Parent = parent,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, -8),
		BackgroundColor3 = theme["Object Background"],
		Theme = "Object Background",
		ThemeProp = "BackgroundColor3",
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		LayoutOrder = layout_order or 0,
		ZIndex = 44,
	})

	self:create("UIPadding", {
		Parent = box,
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	})

	local label = self:create("TextLabel", {
		Parent = box,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Font = Enum.Font.SourceSans,
		Text = text,
		TextSize = TAB_SIZE,
		ThemeText = "Text",
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 45,
	})

	return box, label
end

function veteran:chrome_btn(parent, layout_order, width, fill)
	local auto = not width and not fill
	local z = (parent and parent.ZIndex or 44) + 1
	local btn = self:create("TextButton", {
		Parent = parent,
		AutomaticSize = auto and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
		Size = fill and UDim2.new(1, 0, 0, 26) or UDim2.new(0, width or 0, 1, -8),
		BackgroundColor3 = theme["Object Background"],
		ThemeBorder = "Object Border",
		BorderSizePixel = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = layout_order or 0,
		ZIndex = z,
	})
	if auto or fill then
		self:create("UIPadding", {
			Parent = btn,
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		})
	end
	return btn
end

local function paint_chrome_face(btn, selected)
	if not btn then
		return
	end
	btn.BackgroundColor3 = selected and theme["Tab Toggle Background"] or theme["Object Background"]
	btn.BorderColor3 = theme["Object Border"]
end

function veteran:refresh_left_chrome()
	local menu_on = self.chrome_menu_open == true or self._roblox_bar_open == true or self._roblox_menu_open == true
	if self.menu_btn then
		paint_chrome_face(self.menu_btn, menu_on)
		local color = menu_on and theme.Accent or theme.Text
		for _, line in ipairs(self.menu_lines or {}) do
			if line and line.Parent then
				line.BackgroundColor3 = color
			end
		end
	end
	for name, btn in pairs(self.tray_buttons or {}) do
		local open = self.utility_open and self.utility_open[name]
		paint_chrome_face(btn, open == true)
		local label = btn:FindFirstChildWhichIsA("TextLabel")
		if label then
			label.TextColor3 = open and theme.Accent or theme.Text
		end
	end
end

local ROBLOX_MENU_HINTS = {
	"nine_dot",
	"ninedot",
	"nine-dot",
	"chrome_menu",
	"chromemenu",
	"hamburger",
	"unibarmenu",
}

local function name_is_roblox_menu(name)
	name = string.lower(tostring(name or ""))
	for _, hint in ipairs(ROBLOX_MENU_HINTS) do
		if name == hint or name:find(hint, 1, true) then
			return true
		end
	end
	return false
end

local function clickable_gui(inst)
	if not inst then
		return nil
	end
	if inst:IsA("GuiButton") then
		return inst
	end
	for _, child in ipairs(inst:GetDescendants()) do
		if child:IsA("GuiButton") then
			return child
		end
	end
	if inst:IsA("GuiObject") then
		return inst
	end
	return nil
end

function veteran:should_lift_roblox(inst)
	if not inst or is_ours(inst) or not inst:IsA("LayerCollector") then
		return false
	end
	local name = inst.Name
	if name == "RobloxGui" or name == "TopBarApp" or name == "ExperienceChat" then
		return true
	end
	return name_is_topbar(name)
end

function veteran:lift_roblox_chrome(on)
	self._roblox_orders = self._roblox_orders or {}
	for _, child in ipairs(core_gui:GetChildren()) do
		if not self:should_lift_roblox(child) then
			continue
		end
		if on then
			if self._roblox_orders[child] == nil then
				self._roblox_orders[child] = child.DisplayOrder
			end
			pcall(function()
				if child.DisplayOrder < 5100 then
					child.DisplayOrder = 5100
				end
			end)
		else
			local saved = self._roblox_orders[child]
			if saved ~= nil then
				pcall(function()
					child.DisplayOrder = saved
				end)
				self._roblox_orders[child] = nil
			end
		end
	end
	if on then
		set_core("TopbarEnabled", true)
	end
end

function veteran:watch_roblox_chrome_lift()
	if self._chrome_lift_hooked then
		return
	end
	self._chrome_lift_hooked = true
	self:connect(core_gui.ChildAdded, function(child)
		if self:wants_coregui_redesign() then
			return
		end
		task.defer(function()
			if not self:wants_coregui_redesign() then
				self:lift_roblox_chrome(true)
			end
		end)
	end)
end

function veteran:find_roblox_menu_button()
	if self._roblox_menu_btn and self._roblox_menu_btn.Parent then
		return self._roblox_menu_btn
	end
	local best
	local function consider(inst)
		if not inst or is_ours(inst) or best then
			return
		end
		if name_is_roblox_menu(inst.Name) then
			best = clickable_gui(inst)
		end
	end
	local function scan(root, depth)
		if not root or best or depth > 10 then
			return
		end
		for _, child in ipairs(root:GetChildren()) do
			if is_ours(child) then
				continue
			end
			consider(child)
			if best then
				return
			end
			scan(child, depth + 1)
		end
	end
	for _, child in ipairs(core_gui:GetChildren()) do
		if is_ours(child) then
			continue
		end
		consider(child)
		scan(child, 0)
		if best then
			break
		end
	end
	self._roblox_menu_btn = best
	return best
end

function veteran:fire_gui_button(btn)
	if not btn then
		return false
	end
	local fired = false
	local function fire_signal(signal)
		if typeof(signal) ~= "RBXScriptSignal" then
			return
		end
		if typeof(firesignal) == "function" then
			local ok = pcall(firesignal, signal)
			fired = fired or ok
		end
		if typeof(getconnections) == "function" then
			local ok, conns = pcall(getconnections, signal)
			if ok and type(conns) == "table" then
				for _, conn in ipairs(conns) do
					pcall(function()
						if conn.Fire then
							conn:Fire()
						elseif conn.Function then
							conn.Function()
						end
					end)
					fired = true
				end
			end
		end
	end
	if btn:IsA("GuiButton") then
		fire_signal(btn.MouseButton1Click)
		fire_signal(btn.Activated)
		pcall(function()
			btn:Activate()
			fired = true
		end)
	end
	return fired
end

function veteran:open_roblox_menu()
	self:lift_roblox_chrome(true)
	set_core("TopbarEnabled", true)
	local btn = self:find_roblox_menu_button()
	if self:fire_gui_button(btn) then
		self._roblox_menu_open = not self._roblox_menu_open
		return true
	end
	return false
end

function veteran:set_chrome_menu_open(on)
	on = on and true or false
	if on then
		self:set_topbar_revealed(true)
		if self:wants_coregui_redesign() then
			self.utility_open = self.utility_open or {}
			self:refresh_left_chrome()
		else
			self:sync_native_tray()
		end
	end
	self.chrome_menu_open = on
	if self.chrome_tray then
		self.chrome_tray.Visible = on
		if on then
			self.chrome_tray.Position = UDim2.fromOffset(8, BAR_HEIGHT)
			self:bring_front(self.chrome_tray)
		end
	end
	self:refresh_left_chrome()
end

function veteran:toggle_menu_chrome()
	if self:wants_coregui_redesign() then
		self._roblox_bar_open = false
		self._roblox_menu_open = false
		self:set_chrome_menu_open(not self.chrome_menu_open)
		return
	end
	self:set_chrome_menu_open(false)
	if self._roblox_bar_open then
		self._roblox_bar_open = false
		self._roblox_menu_open = false
		self:lift_roblox_chrome(false)
		self:hide_roblox_topbar(false)
	else
		self._roblox_bar_open = true
		self:restore_roblox_topbar()
		self:lift_roblox_chrome(true)
		self:watch_roblox_chrome_lift()
		self:watch_native_shift()
		set_core("TopbarEnabled", true)
		task.defer(function()
			if not self._roblox_bar_open or self:wants_coregui_redesign() then
				return
			end
			self:layout_native_chrome(true)
			self:open_roblox_menu()
		end)
	end
	self:refresh_left_chrome()
end

function veteran:click_outside_chrome_menu(input)
	if not self.chrome_menu_open then
		return
	end
	local mx, my = gui_mouse(input)
	if self.menu_btn and point_in(self.menu_btn, mx, my) then
		return
	end
	if self.chrome_tray and point_in(self.chrome_tray, mx, my) then
		return
	end
	self:set_chrome_menu_open(false)
end

function veteran:sync_native_tray()
	if self:wants_coregui_redesign() then
		return
	end
	self.utility_open = self.utility_open or {}
	for name, kind in pairs(NATIVE_CORE_TYPES) do
		local enabled = false
		pcall(function()
			enabled = starter_gui:GetCoreGuiEnabled(kind)
		end)
		self.utility_open[name] = enabled or nil
	end
	self:refresh_left_chrome()
end

function veteran:set_native_coregui(name, on)
	local kind = NATIVE_CORE_TYPES[name]
	if not kind then
		return
	end
	if on == nil then
		local current = false
		pcall(function()
			current = starter_gui:GetCoreGuiEnabled(kind)
		end)
		on = not current
	end
	pcall(function()
		starter_gui:SetCoreGuiEnabled(kind, on and true or false)
	end)
	self.utility_open = self.utility_open or {}
	self.utility_open[name] = on and true or nil
	self:refresh_left_chrome()
end

function veteran:set_utility_open(name, on)
	if not self:wants_coregui_redesign() then
		self:set_native_coregui(name, on)
		return
	end
	self.utility_open = self.utility_open or {}
	if on == nil then
		on = self.utility_open[name] ~= true
	end
	self.utility_open[name] = on or nil
	local panel = self.utility_panels and self.utility_panels[name]
	if panel then
		self:set_window_open(panel, on and true or false)
	end
	if name == "chat" and on and self.chat_box then
		task.defer(function()
			if not self.chat_box then
				return
			end
			self.chat_box:CaptureFocus()
			local typed = self.chat_box.Text
			if typed:sub(1, 1) == "/" then
				self.chat_box.Text = typed:sub(2)
			end
		end)
	end
	if name == "backpack" and on then
		self:refresh_backpack_list()
	end
	if name == "players" and on then
		self:refresh_players_list()
	end
	if name == "emotes" and on then
		self:refresh_emotes_list()
	end
	self:refresh_left_chrome()
end

function veteran:tray_row(parent, name, order, fn)
	local btn = self:chrome_btn(parent, order, nil, true)
	local label = self:create("TextLabel", {
		Parent = btn,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.SourceSans,
		Text = name,
		TextSize = TAB_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = btn.ZIndex + 1,
	})
	self:animate_button(btn, function()
		local open = self.utility_open and self.utility_open[name]
		return open and theme["Tab Toggle Background"] or theme["Object Background"]
	end)
	self:connect(btn.MouseButton1Click, function()
		fn()
	end)
	self.tray_buttons = self.tray_buttons or {}
	self.tray_buttons[name] = btn
	return btn, label
end

function veteran:make_utility_panel(props)
	local z = props.ZIndex or 80
	local panel, inner = self:make_panel({
		Name = props.Name,
		Position = props.Position,
		Size = props.Size,
		AutomaticSize = props.AutomaticSize,
		Visible = false,
		ZIndex = z,
	})
	panel.ClipsDescendants = props.clip == true
	inner.ClipsDescendants = props.clip == true
	self:create("TextLabel", {
		Parent = inner,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 16),
		Font = Enum.Font.SourceSans,
		Text = props.title or "panel",
		TextSize = TITLE_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = z + 2,
	})
	self.utility_panels = self.utility_panels or {}
	self.utility_panels[props.id] = panel
	return panel, inner
end

function veteran:utility_list(parent, z)
	local scroll = self:create("ScrollingFrame", {
		Parent = parent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 26),
		Size = UDim2.new(1, -16, 1, -34),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = z,
	})
	self:create("UIListLayout", {
		Parent = scroll,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local empty = self:create("TextLabel", {
		Parent = parent,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 26),
		Size = UDim2.new(1, -16, 1, -34),
		Font = Enum.Font.SourceSans,
		Text = "",
		TextSize = TEXT_SIZE,
		ThemeText = "Disabled Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = z,
	})
	return scroll, empty
end

function veteran:utility_item(parent, text, order, selected, click)
	local btn = self:chrome_btn(parent, order, nil, true)
	btn.ZIndex = (parent.ZIndex or 80) + 1
	local label = self:create("TextLabel", {
		Parent = btn,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.SourceSans,
		Text = text,
		TextSize = TEXT_SIZE,
		TextColor3 = selected and theme.Accent or theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = btn.ZIndex + 1,
	})
	paint_chrome_face(btn, selected)
	self:animate_button(btn, function()
		return selected and theme["Tab Toggle Background"] or theme["Object Background"]
	end)
	if click then
		self:connect(btn.MouseButton1Click, click)
	end
	return btn, label
end

function veteran:uses_textchat()
	local ok, version = pcall(function()
		return text_chat.ChatVersion
	end)
	return ok and version == Enum.ChatVersion.TextChatService
end

function veteran:push_chat_line(name, text, mine)
	if not self.chat_list then
		return
	end
	self.chat_count = (self.chat_count or 0) + 1
	local row = self:create("TextLabel", {
		Parent = self.chat_list,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.SourceSans,
		Text = tostring(name or "system") .. ": " .. tostring(text or ""),
		TextSize = TEXT_SIZE,
		TextColor3 = mine and theme.Accent or theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		LayoutOrder = self.chat_count,
		ZIndex = 83,
	})
	if self.chat_empty then
		self.chat_empty.Visible = false
	end
	local labels = {}
	for _, child in ipairs(self.chat_list:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	table.sort(labels, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #labels > 80 do
		labels[1]:Destroy()
		table.remove(labels, 1)
	end
	task.defer(function()
		if self.chat_list then
			self.chat_list.CanvasPosition = Vector2.new(0, self.chat_list.AbsoluteCanvasSize.Y)
		end
	end)
	return row
end

function veteran:send_chat(text)
	text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		return
	end
	local sent = false
	if self:uses_textchat() then
		pcall(function()
			local channels = text_chat:FindFirstChild("TextChannels")
			local ch = channels and (channels:FindFirstChild("RBXGeneral") or channels:FindFirstChildWhichIsA("TextChannel"))
			if ch then
				ch:SendAsync(text)
				sent = true
			end
		end)
	end
	if not sent then
		pcall(function()
			local folder = replicated_storage:FindFirstChild("DefaultChatSystemChatEvents")
			local ev = folder and folder:FindFirstChild("SayMessageRequest")
			if ev then
				ev:FireServer(text, "All")
				sent = true
			end
		end)
	end
	if not sent then
		local lp = players.LocalPlayer
		self:push_chat_line(lp and lp.DisplayName or "you", text, true)
	end
end

function veteran:hook_chat_feed()
	if self._chat_hooked then
		return
	end
	self._chat_hooked = true
	if self:uses_textchat() then
		self:connect(text_chat.MessageReceived, function(msg)
			if not msg then
				return
			end
			local name = "system"
			local mine = false
			pcall(function()
				if msg.TextSource then
					local player = players:GetPlayerByUserId(msg.TextSource.UserId)
					if player then
						name = player.DisplayName
						mine = player == players.LocalPlayer
					end
				end
			end)
			self:push_chat_line(name, msg.Text, mine)
		end)
		return
	end
	local function hook_player(player)
		self:connect(player.Chatted, function(message)
			self:push_chat_line(player.DisplayName, message, player == players.LocalPlayer)
		end)
	end
	for _, player in ipairs(players:GetPlayers()) do
		hook_player(player)
	end
	self:connect(players.PlayerAdded, hook_player)
end

function veteran:build_chat_panel()
	local panel, inner = self:make_utility_panel({
		id = "chat",
		Name = "ChatPanel",
		title = "chat",
		Position = UDim2.new(0, 8, 1, -268),
		Size = UDim2.fromOffset(340, 250),
		clip = true,
	})
	local list, empty = self:utility_list(inner, 82)
	list.Size = UDim2.new(1, -16, 1, -56)
	empty.Size = UDim2.new(1, -16, 1, -56)
	empty.Text = "no messages"
	empty.Visible = true
	self.chat_list = list
	self.chat_empty = empty

	local shell, well = self:make_shell(inner, {
		size = UDim2.new(1, -16, 0, 20),
		z = 82,
	})
	shell.Position = UDim2.new(0, 8, 1, -28)
	shell.AnchorPoint = Vector2.new(0, 0)
	local box = self:create("TextBox", {
		Parent = well,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.SourceSans,
		Text = "",
		PlaceholderText = "message",
		PlaceholderColor3 = theme["Disabled Text"],
		TextSize = TEXT_SIZE,
		ThemeText = "Text",
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 84,
	})
	self:create("UIPadding", {
		Parent = box,
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	})
	self:connect(box.Focused, function()
		self:tween(well, { BorderColor3 = theme.Accent }, TWEEN)
	end)
	self:connect(box.FocusLost, function(enter)
		self:tween(well, { BorderColor3 = theme["Object Border"] }, TWEEN)
		if enter then
			self:send_chat(box.Text)
			box.Text = ""
			task.defer(function()
				if self.utility_open and self.utility_open.chat and box.Parent then
					box:CaptureFocus()
				end
			end)
		end
	end)
	self.chat_box = box
	self.chat_panel = panel
	self:hook_chat_feed()
	return panel
end

function veteran:collect_tools()
	local lp = players.LocalPlayer
	local tools = {}
	local seen = {}
	local function take(folder)
		if not folder then
			return
		end
		for _, inst in ipairs(folder:GetChildren()) do
			if inst:IsA("Tool") and not seen[inst] then
				seen[inst] = true
				table.insert(tools, inst)
			end
		end
	end
	take(lp and lp:FindFirstChild("Backpack"))
	take(lp and lp.Character)
	return tools
end

function veteran:hotbar_slots()
	local tools = self:collect_tools()
	local prev = self._hotbar_slots or {}
	local next_slots = {}
	local used = {}
	for i = 1, 10 do
		local tool = prev[i]
		if tool and tool.Parent and tool:IsA("Tool") then
			next_slots[i] = tool
			used[tool] = true
		end
	end
	for _, tool in ipairs(tools) do
		if not used[tool] then
			for i = 1, 10 do
				if not next_slots[i] then
					next_slots[i] = tool
					used[tool] = true
					break
				end
			end
		end
	end
	self._hotbar_slots = next_slots
	return next_slots
end

function veteran:activate_hotbar_slot(index)
	local tool = self._hotbar_slots and self._hotbar_slots[index]
	if not tool or not tool.Parent then
		return false
	end
	local lp = players.LocalPlayer
	local character = lp and lp.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	if tool.Parent == character then
		hum:UnequipTools()
	else
		hum:EquipTool(tool)
	end
	task.defer(function()
		self:refresh_backpack_list()
	end)
	return true
end

function veteran:activate_hotbar_key(key)
	if not self:wants_coregui_redesign() or not self.hotbar then
		return false
	end
	if not key or self._binding then
		return false
	end
	local index = ({
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
		[Enum.KeyCode.Seven] = 7,
		[Enum.KeyCode.Eight] = 8,
		[Enum.KeyCode.Nine] = 9,
		[Enum.KeyCode.Zero] = 10,
	})[key]
	if not index then
		return false
	end
	return self:activate_hotbar_slot(index)
end

function veteran:apply_hotbar_layout()
	local box = self:layout_value("hotbar_size")
	local gap = self:layout_value("hotbar_spacing")
	if self.hotbar_layout then
		self.hotbar_layout.Padding = UDim.new(0, gap)
	end
	if self.hotbar then
		self.hotbar.Size = UDim2.fromOffset(0, box + 4)
	end
	local icon = math.max(6, math.floor(box * 0.5 + 0.5))
	local num_size = box < 22 and 9 or 11
	for _, slot in ipairs(self._hotbar_ui or {}) do
		if slot.shell then
			slot.shell.Size = UDim2.fromOffset(box, box)
		end
		if slot.icon then
			slot.icon.Size = UDim2.fromOffset(icon, icon)
		end
		if slot.glyph then
			slot.glyph.TextSize = num_size
		end
		if slot.key then
			slot.key.TextSize = num_size
			slot.key.Size = UDim2.new(1, -3, 0, math.min(12, box))
		end
	end
end

function veteran:refresh_hotbar()
	if not self.hotbar_list then
		return
	end
	self:apply_hotbar_layout()
	clear_fill(self.hotbar_list)
	self._hotbar_ui = {}
	local slots = self:hotbar_slots()
	local equipped = players.LocalPlayer and players.LocalPlayer.Character and players.LocalPlayer.Character:FindFirstChildOfClass("Tool")
	local shown = 0
	local box = self:layout_value("hotbar_size")
	local icon = math.max(6, math.floor(box * 0.5 + 0.5))
	local num_size = box < 22 and 9 or 11
	for i = 1, 10 do
		local tool = slots[i]
		if not tool then
			continue
		end
		shown += 1
		local on = tool == equipped
		local shell, well = self:make_shell(self.hotbar_list, {
			size = UDim2.fromOffset(box, box),
			layout_order = i,
			z = 61,
		})
		well.BorderColor3 = on and theme.Accent or theme["Object Border"]
		local btn = self:create("TextButton", {
			Parent = well,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 63,
		})
		local icon_inst
		local glyph
		local texture = tool.TextureId
		if type(texture) == "string" and texture ~= "" then
			icon_inst = self:create("ImageLabel", {
				Parent = btn,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(icon, icon),
				Image = texture,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 64,
			})
		else
			glyph = self:create("TextLabel", {
				Parent = btn,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Font = Enum.Font.SourceSans,
				Text = string.lower(tool.Name),
				TextSize = num_size,
				TextColor3 = on and theme.Accent or theme.Text,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.5,
				ZIndex = 64,
			})
		end
		local key = self:create("TextLabel", {
			Parent = btn,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, -3, 0, math.min(12, box)),
			Font = Enum.Font.SourceSans,
			Text = i == 10 and "0" or tostring(i),
			TextSize = num_size,
			TextColor3 = on and theme.Accent or theme["Disabled Text"],
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
			ZIndex = 65,
		})
		btn.MouseButton1Click:Connect(function()
			self:activate_hotbar_slot(i)
		end)
		table.insert(self._hotbar_ui, {
			shell = shell,
			well = well,
			icon = icon_inst,
			glyph = glyph,
			key = key,
		})
	end
	if self.hotbar then
		self.hotbar.Visible = shown > 0
	end
end

function veteran:build_hotbar()
	local box = self:layout_value("hotbar_size")
	local gap = self:layout_value("hotbar_spacing")
	local bar = self:create("Frame", {
		Parent = self.gui,
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, box + 4),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 60,
	})
	self.hotbar_layout = self:create("UIListLayout", {
		Parent = bar,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self.hotbar = bar
	self.hotbar_list = bar
	self:refresh_hotbar()
	return bar
end

function veteran:refresh_backpack_list()
	if self.backpack_list then
		clear_fill(self.backpack_list)
	end
	local lp = players.LocalPlayer
	local tools = self:collect_tools()
	if self.backpack_empty then
		self.backpack_empty.Visible = #tools == 0
		self.backpack_empty.Text = "no tools"
	end
	local equipped = lp and lp.Character and lp.Character:FindFirstChildOfClass("Tool")
	if self.backpack_list then
		for i, tool in ipairs(tools) do
			self:utility_item(self.backpack_list, string.lower(tool.Name), i, tool == equipped, function()
				local character = lp and lp.Character
				local hum = character and character:FindFirstChildOfClass("Humanoid")
				if not hum then
					return
				end
				if tool.Parent == character then
					hum:UnequipTools()
				else
					hum:EquipTool(tool)
				end
				task.defer(function()
					self:refresh_backpack_list()
				end)
			end)
		end
	end
	self:refresh_hotbar()
end

function veteran:schedule_tool_refresh()
	if self._tool_refresh_queued then
		return
	end
	self._tool_refresh_queued = true
	task.defer(function()
		self._tool_refresh_queued = false
		if not self.gui then
			return
		end
		self:refresh_backpack_list()
	end)
end

function veteran:hook_backpack_feed()
	if self._backpack_hooked then
		return
	end
	self._backpack_hooked = true
	local lp = players.LocalPlayer
	if not lp then
		return
	end
	self._watched_folders = self._watched_folders or {}
	local function watch(folder)
		if not folder or self._watched_folders[folder] then
			return
		end
		self._watched_folders[folder] = true
		self:connect(folder.ChildAdded, function(child)
			if child:IsA("Tool") then
				self:schedule_tool_refresh()
			end
		end)
		self:connect(folder.ChildRemoved, function(child)
			if child:IsA("Tool") then
				self:schedule_tool_refresh()
			end
		end)
	end
	watch(lp:FindFirstChild("Backpack"))
	self:connect(lp.ChildAdded, function(child)
		if child.Name == "Backpack" then
			watch(child)
			self:schedule_tool_refresh()
		end
	end)
	self:connect(lp.CharacterAdded, function(character)
		self._hotbar_slots = {}
		watch(character)
		self:schedule_tool_refresh()
	end)
	if lp.Character then
		watch(lp.Character)
	end
end

function veteran:build_backpack_panel()
	local panel, inner = self:make_utility_panel({
		id = "backpack",
		Name = "BackpackPanel",
		title = "backpack",
		Position = UDim2.fromOffset(8, BAR_HEIGHT + 8),
		Size = UDim2.fromOffset(220, 260),
		clip = true,
	})
	self.backpack_list, self.backpack_empty = self:utility_list(inner, 82)
	self.backpack_empty.Text = "no tools"
	self.backpack_panel = panel
	self:hook_backpack_feed()
	self:refresh_backpack_list()
	return panel
end

function veteran:refresh_players_list()
	if not self.players_list then
		return
	end
	clear_fill(self.players_list)
	local lp = players.LocalPlayer
	local list = players:GetPlayers()
	table.sort(list, function(a, b)
		return string.lower(a.DisplayName) < string.lower(b.DisplayName)
	end)
	if self.players_empty then
		self.players_empty.Visible = #list == 0
		self.players_empty.Text = "no players"
	end
	for i, player in ipairs(list) do
		local mine = player == lp
		local text = player.DisplayName
		if player.Name ~= player.DisplayName then
			text = player.DisplayName .. " @" .. player.Name
		end
		self:utility_item(self.players_list, text, i, mine, function()
			self.selected_player = player
			if self.ensure_chrome then
				self:ensure_chrome("Environment")
			end
		end)
	end
end

function veteran:build_players_panel()
	local panel, inner = self:make_utility_panel({
		id = "players",
		Name = "PlayersPanel",
		title = "players",
		Position = UDim2.fromOffset(236, BAR_HEIGHT + 8),
		Size = UDim2.fromOffset(220, 260),
		clip = true,
	})
	self.players_list, self.players_empty = self:utility_list(inner, 82)
	self.players_empty.Text = "no players"
	self.players_panel = panel
	self:connect(players.PlayerAdded, function()
		self:refresh_players_list()
	end)
	self:connect(players.PlayerRemoving, function()
		self:refresh_players_list()
	end)
	self:refresh_players_list()
	return panel
end

function veteran:refresh_emotes_list()
	if not self.emotes_list then
		return
	end
	clear_fill(self.emotes_list)
	local names = {}
	pcall(function()
		local lp = players.LocalPlayer
		local hum = lp and lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		local desc = hum and hum:FindFirstChildOfClass("HumanoidDescription")
		if not desc and lp then
			desc = players:GetHumanoidDescriptionFromUserId(lp.UserId)
		end
		if desc then
			for name in pairs(desc:GetEmotes()) do
				table.insert(names, name)
			end
		end
	end)
	table.sort(names, function(a, b)
		return string.lower(a) < string.lower(b)
	end)
	if self.emotes_empty then
		self.emotes_empty.Visible = #names == 0
		self.emotes_empty.Text = "no emotes"
	end
	for i, name in ipairs(names) do
		self:utility_item(self.emotes_list, string.lower(name), i, false, function()
			pcall(function()
				local lp = players.LocalPlayer
				local hum = lp and lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum:PlayEmote(name)
				end
			end)
		end)
	end
end

function veteran:build_emotes_panel()
	local panel, inner = self:make_utility_panel({
		id = "emotes",
		Name = "EmotesPanel",
		title = "emotes",
		Position = UDim2.fromOffset(464, BAR_HEIGHT + 8),
		Size = UDim2.fromOffset(220, 260),
		clip = true,
	})
	self.emotes_list, self.emotes_empty = self:utility_list(inner, 82)
	self.emotes_empty.Text = "no emotes"
	self.emotes_panel = panel
	local lp = players.LocalPlayer
	if lp then
		self:connect(lp.CharacterAdded, function()
			task.delay(0.4, function()
				self:refresh_emotes_list()
			end)
		end)
	end
	self:refresh_emotes_list()
	return panel
end

function veteran:build_core_tray()
	local panel, inner = self:make_panel({
		Name = "CoreTray",
		Position = UDim2.fromOffset(8, BAR_HEIGHT),
		Size = UDim2.fromOffset(168, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 80,
	})
	panel.ClipsDescendants = false
	inner.ClipsDescendants = false
	self:create("UIPadding", {
		Parent = inner,
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	local list = self:create("Frame", {
		Parent = inner,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 82,
	})
	self:create("UIListLayout", {
		Parent = list,
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self.chrome_tray = panel
	self.tray_buttons = {}
	self.utility_open = {}
	self:tray_row(list, "chat", 1, function()
		self:set_utility_open("chat")
	end)
	self:tray_row(list, "backpack", 2, function()
		self:set_utility_open("backpack")
	end)
	self:tray_row(list, "players", 3, function()
		self:set_utility_open("players")
	end)
	self:tray_row(list, "emotes", 4, function()
		self:set_utility_open("emotes")
	end)
	return panel
end

function veteran:build_menu_btn(parent)
	local btn = self:chrome_btn(parent, 1, 26)
	local wrap = self:create("Frame", {
		Parent = btn,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 10),
		BackgroundTransparency = 1,
		ZIndex = 45,
	})
	self.menu_lines = {}
	for i = 0, 2 do
		self.menu_lines[i + 1] = self:create("Frame", {
			Parent = wrap,
			Position = UDim2.fromOffset(0, i * 4),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = theme.Text,
			BorderSizePixel = 0,
			ZIndex = 46,
		})
	end
	self:animate_button(btn, function()
		local open = self.chrome_menu_open or self._roblox_bar_open or self._roblox_menu_open
		return open and theme["Tab Toggle Background"] or theme["Object Background"]
	end)
	self:connect(btn.MouseButton1Click, function()
		self:toggle_menu_chrome()
	end)
	self.menu_btn = btn
	return btn
end

function veteran:add_tab(name)
	self.tabs = self.tabs or {}
	self.tab_buttons = self.tab_buttons or {}
	self.open_tabs = self.open_tabs or {}
	self._tab_order = (self._tab_order or 0) + 1

	local btn = self:create("TextButton", {
		Parent = self.tab_row,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, -8),
		BackgroundColor3 = theme["Tab Background"],
		ThemeBorder = "Tab Border",
		BorderSizePixel = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = self._tab_order,
		ZIndex = 44,
	})

	self:create("UIPadding", {
		Parent = btn,
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	})

	local label = self:create("TextLabel", {
		Parent = btn,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Font = Enum.Font.SourceSans,
		Text = name,
		TextSize = TAB_SIZE,
		TextColor3 = theme["Disabled Text"],
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.5,
		ZIndex = 45,
	})

	local accent = self:create("Frame", {
		Parent = btn,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0, 0, 0, 1),
		BackgroundColor3 = theme.Accent,
		Theme = "Accent",
		ThemeProp = "BackgroundColor3",
		BorderSizePixel = 0,
		Visible = true,
		ZIndex = 46,
	})

	self.tab_buttons[name] = { button = btn, label = label, accent = accent }

	self:animate_button(btn, function()
		return self.open_tabs[name] and theme["Tab Toggle Background"] or theme["Tab Background"]
	end)

	self:connect(btn.MouseButton1Click, function()
		self:toggle_tab(name)
	end)

	return btn
end

function veteran:toggle_tab(name)
	self.open_tabs = self.open_tabs or {}
	local panel = self:tab_panel(name)
	if not panel then
		return
	end
	local now = os.clock()
	self._tab_lock = self._tab_lock or {}
	local lock_for = name == "info" and 0.28 or 0.14
	if self._tab_lock[name] and now < self._tab_lock[name] then
		return
	end
	self._tab_lock[name] = now + lock_for
	if self.menu_visible == false then
		self.open_tabs[name] = true
		self.current_tab = name
		if self.option_meta and self.option_meta.menu then
			self:set_option("menu", true)
		else
			self:set_menu_visible(true)
		end
		return
	end
	local open = self.open_tabs[name] ~= true
	self.open_tabs[name] = open or nil
	self.current_tab = name
	self:refresh_tabs()
	self:set_window_open(panel, open)
	self:close_dropdown()
	if name == "Themes" and not open then
		self:close_picker()
	end
	if name == "panel" and open then
		self:refresh_staff_panel()
	end
end

function veteran:select_tab(name)
	self:toggle_tab(name)
end

function veteran:build_topbar_items()
	local left = self:create("Frame", {
		Parent = self.topbar_holder,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 43,
	})
	self:create("UIListLayout", {
		Parent = left,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self.topbar_left = left
	self:build_menu_btn(left)

	self.tab_row = self:create("Frame", {
		Parent = left,
		LayoutOrder = 10,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 43,
	})

	self:create("UIListLayout", {
		Parent = self.tab_row,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	self:refresh_left_chrome()

	local right = self:create("Frame", {
		Parent = self.topbar_holder,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 43,
	})

	self:create("UIListLayout", {
		Parent = right,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	self:add_tab("info")
	self:add_tab("Configurations")
	self:add_tab("Themes")
	self:add_tab("Environment")
	self:add_tab("Previews")
	self:add_tab("Watermark")
	self:add_tab("Keybinds")
	if self:can_staff_panel() then
		self:add_tab("panel")
	end

	local date_now, time_now = clock_text()
	self:build_report_btn(right)
	self:bar_box(right, "veteran", 2)
	local _, date_label = self:bar_box(right, date_now, 3)
	local _, time_label = self:bar_box(right, time_now, 4)
	self.date_label = date_label
	self.time_label = time_label

	self:build_info_panel()
	self:build_themes_panel()
	self:build_environment_panel()
	self:build_preview_panel()
	self:build_watermark()
	self:build_configurations()
	self:build_keybinds()
	self:build_staff_panel()
	self:build_report_panel()
	self:start_ops_loop()
	self:build_core_tray()
	if self:wants_coregui_redesign() then
		self:ensure_coregui_rewrite_ui()
	end

	task.spawn(function()
		while self.gui and self.gui.Parent do
			local date_text, time_text = clock_text()
			if self.date_label then
				self.date_label.Text = date_text
			end
			if self.time_label then
				self.time_label.Text = time_text
			end
			task.wait(1)
		end
	end)
end

function veteran:play_boot()
	local env = (getgenv and getgenv()) or _G
	local skip_splash = env.veteran_fast_rejoin == true
	env.veteran_fast_rejoin = nil

	self:apply_session()
	self:load_rewrite_pref()
	self:mount_gui()

	local overlay, window, bar
	if not skip_splash then
		overlay, window, bar = self:build_splash()
		self:tween(overlay, { BackgroundTransparency = 0.35 }, 0.1)
		if bar then
			self:tween(bar, { Size = UDim2.new(1, 0, 1, 0) }, 0.28)
		end
	end

	local topbar = self:build_topbar()
	self:apply_coregui_rewrite()
	self:boot_saved_theme()
	self:apply_topbar_autohide()

	if skip_splash then
		topbar.Visible = true
		topbar.Position = UDim2.fromOffset(0, 0)
	else
		topbar.Visible = false
	end

	self.booted = true
	for _, fn in ipairs(self._ready or {}) do
		task.spawn(fn, self)
	end
	self._ready = {}

	if skip_splash then
		return
	end

	task.wait(0.22)
	if overlay then
		self:tween(overlay, { BackgroundTransparency = 1 }, 0.1)
		if window then
			self:tween(window, { BackgroundTransparency = 1 }, 0.1)
		end
		task.wait(0.1)
		pcall(function()
			overlay:Destroy()
		end)
	end
	topbar.Visible = true
	self:tween(topbar, { Position = UDim2.fromOffset(0, 0) }, 0.12)
end

function veteran:ready(callback)
	if type(callback) ~= "function" then
		return self
	end
	if self.booted then
		task.spawn(callback, self)
	else
		self._ready = self._ready or {}
		table.insert(self._ready, callback)
	end
	return self
end

function veteran:boot()
	self:apply_session()
	if self.booted and self.gui and self.gui.Parent then
		return self
	end
	task.spawn(function()
		local ok, err = pcall(function()
			self:play_boot()
		end)
		if not ok then
			warn("[veteran] boot failed: " .. tostring(err))
		end
	end)
	return self
end

function veteran:unload()
	if type(self._product_cleanup) == "function" then
		pcall(self._product_cleanup, self)
		self._product_cleanup = nil
	end
	self:clear_env_view()
	for _, connection in ipairs(self.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self.connections)
	self:close_picker()
	self:close_dropdown()
	self:close_slider_entry()
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
	self.topbar = nil
	self.topbar_holder = nil
	self._topbar_hover_hooked = nil
	self._topbar_revealed = nil
	self.topbar_autohide_toggle = nil
	self.rewrite_toggle = nil
	self.fullscreen_exit_toggle = nil
	self._fs_title_pins = nil
	self._tooltip_pins = nil
	self._tooltip_watch_hooked = nil
	self.topbar_left = nil
	self.menu_btn = nil
	self.menu_lines = nil
	self.chrome_menu_open = nil
	self._roblox_menu_open = nil
	self._roblox_bar_open = nil
	self._topbar_hide_full = nil
	self:layout_native_chrome(false)
	self:release_topbar_plus()
	self._plus_watch_hooked = nil
	self._native_pins = nil
	self._native_shift_hooked = nil
	self._roblox_menu_btn = nil
	self._chrome_lift_hooked = nil
	self:lift_roblox_chrome(false)
	self._roblox_orders = nil
	self.chrome_tray = nil
	self.tray_buttons = nil
	self._rewrite_ui_built = nil
	self._topbar_watch_hooked = nil
	self.utility_open = nil
	self.utility_panels = nil
	self.chat_panel = nil
	self.chat_list = nil
	self.chat_empty = nil
	self.chat_box = nil
	self.chat_count = nil
	self._chat_hooked = nil
	self.backpack_panel = nil
	self.backpack_list = nil
	self.backpack_empty = nil
	self._backpack_hooked = nil
	self.hotbar = nil
	self.hotbar_list = nil
	self.hotbar_layout = nil
	self._hotbar_slots = nil
	self._hotbar_ui = nil
	self._slider_drag = nil
	self._slider_input_hooked = nil
	self._window_drag = nil
	self._window_drag_hooked = nil
	self._watched_folders = nil
	self.players_panel = nil
	self.players_list = nil
	self.players_empty = nil
	self.emotes_panel = nil
	self.emotes_list = nil
	self.emotes_empty = nil
	self.staff_panel = nil
	self.staff_list = nil
	self.staff_empty = nil
	self.staff_join = nil
	self.staff_bring = nil
	self.staff_status = nil
	self._panel_selected = nil
	self.report_panel = nil
	self.report_overlay = nil
	self.report_box = nil
	self.report_btn = nil
	self.report_cool = nil
	self.report_hint = nil
	self.report_submit = nil
	self.report_open = nil
	self._ops_loop = nil
	self.tab_row = nil
	self.tab_buttons = nil
	self._tab_order = nil
	self.current_tab = nil
	self.open_tabs = {}
	self.date_label = nil
	self.time_label = nil
	self.info_panel = nil
	self.info_rows = nil
	self.info_list = nil
	self.info_version_label = nil
	self.info_version_hint = nil
	self.info_version_scale = nil
	self.themes_panel = nil
	self.theme_list = nil
	self.theme_name_box = nil
	self.autoload_toggle = nil
	self.config_panel = nil
	self.config_window = nil
	self.config_search = nil
	self.config_search_query = nil
	self.config_search_empty = nil
	self.config_file_names = nil
	self.section_list = {}
	self.feature_map = {}
	self._ready = nil
	self._example_built = nil
	self.keybinds_panel = nil
	self.keybind_list = nil
	self.keybind_search = nil
	self.keybind_tabs = nil
	self.keybind_empty = nil
	self.keybind_tab = nil
	self.layout_packs = nil
	self.slider_entry = nil
	self._slider_entry_pack = nil
	self.option_meta = nil
	self._options_ready = nil
	self._keys_listening = nil
	self._binding = nil
	self._applying_options = nil
	self.options = nil
	self.flags = nil
	self.menu_visible = true
	self.environment_panel = nil
	self.env_list = nil
	self.env_search = nil
	self.env_empty = nil
	self.env_count = nil
	self.env_display = nil
	self.env_name = nil
	self.env_userid = nil
	self.env_status = nil
	self.selected_player = nil
	self.relation_buttons = nil
	self.player_rows = {}
	self.watermark_panel = nil
	self.watermark = nil
	self.watermark_label = nil
	self.watermark_toggles = nil
	table.clear(theme_binds)
	table.clear(theme_swatches)
	self.booted = false
	self:restore_roblox_topbar()
	self.hidden_guis = {}
	self._chrome_pins = nil
	self._chrome_watched = nil
	if getgenv().veteran == self then
		getgenv().veteran = nil
	end
end

getgenv().veteran = veteran
veteran:apply_session()
veteran:boot()

return veteran
