local Players = game:GetService("Players")
local InputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Text = game:GetService("TextService")
local Tween = game:GetService("TweenService")
local Gui = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local GameCamera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Color = {
	window = Color3.fromRGB(0, 0, 0),
	header = Color3.fromRGB(14, 14, 14),
	module = Color3.fromRGB(17, 17, 17),
	Row = Color3.fromRGB(22, 22, 22),
	rowHover = Color3.fromRGB(28, 28, 28),
	Action = Color3.fromRGB(32, 32, 32),
	actionHover = Color3.fromRGB(40, 40, 40),
	Track = Color3.fromRGB(40, 40, 40),
	text = Color3.fromRGB(255, 255, 255),
	Soft = Color3.fromRGB(190, 190, 190),
	muted = Color3.fromRGB(170, 170, 170),
	subtle = Color3.fromRGB(120, 120, 120),
	shadow = Color3.new(0, 0, 0)
}

local NotifColor = {
	Client = Color3.fromRGB(255, 255, 255),
	Success = Color3.fromRGB(46, 204, 113),
	Error = Color3.fromRGB(231, 76, 60),
	Warning = Color3.fromRGB(241, 196, 15),
	Info = Color3.fromRGB(52, 152, 219)
}

local TaskAPI = {
	Categories = {},
	CategoryList = {},
	Modules = {},
	Notifications = {},
	Visuals = {},
	Version = { "1.0.0" }
}

local SoundService = game:GetService("SoundService")

local Taskium = getgenv().Taskium or {}
getgenv().Taskium = Taskium
getgenv().TaskAPI = TaskAPI
Taskium.API = TaskAPI

local Config = Taskium.Config
TaskAPI.Config = Config

local GradStart = Color3.fromRGB(120, 140, 225)
local GradEnd = Color3.fromRGB(145, 165, 245)

local function Smooth(Alpha)
	Alpha = math.clamp(tonumber(Alpha) or 0, 0, 1)
	return Alpha * Alpha * (3 - (2 * Alpha))
end

local function Tint(Color, Amount)
	return Color:Lerp(Color3.new(1, 1, 1), math.clamp(tonumber(Amount) or 0, 0, 1))
end

local function SampleGrad(position, startColor, endColor, Options)
	Options = Options or {}
	position = (tonumber(position) or 0) % 1
	startColor = startColor or GradStart
	endColor = endColor or GradEnd

	local Blend = math.clamp(tonumber(Options.blend) or 0.66, 0, 1)
	local Lift = math.clamp(tonumber(Options.lift) or 0.35, 0, 1)
	local midpoint = startColor:Lerp(endColor, 0.5)
	local base = Tint(startColor, Lift)
	local peak = Tint(midpoint, Blend)
	local tail = endColor:Lerp(midpoint, Blend * 0.18)

	if position <= 0.28 then
		return base:Lerp(peak, Smooth(position / 0.28))
	end

	if position <= 0.64 then
		return peak:Lerp(tail, Smooth((position - 0.28) / 0.36))
	end

	return tail:Lerp(base, Smooth((position - 0.64) / 0.36))
end

local SharedModuleGradient = {
	DARK_ACCENT = GradStart,
	DARK_ACCENT_HOVER = GradEnd,
	gradientAt = SampleGrad
}

local State = {
	Ready = false,
	HideToken = 0,
	SetRowsDirty = true,
	ArrayEnabled = false,
	ArraySig = "",
	ArrayDirty = false,
	Tweens = setmetatable({}, { __mode = "k" }),
	Fade = setmetatable({}, { __mode = "k" }),
	Scale = setmetatable({}, { __mode = "k" }),
	SetModRows = {},
	ArrayRows = {}
}

local UI = {}
local Fn = {}
local ArraySettings = {
	Sort = "Length",
	Scale = 1,
	Font = "Modules",
	CustomFont = "",
	Shadow = true,
	Gradient = true,
	Animations = true,
	Watermark = false,
	Background = true,
	Transparency = 0.18,
	Tint = false,
	HideRender = false,
	RemoveSpaces = false,
	AddCustomText = false,
	CustomText = ""
}
local ArrayFonts = { "Modules", "Code", "Custom" }
for _, font in ipairs(Enum.Font:GetEnumItems()) do
	if not table.find(ArrayFonts, font.Name) then
		table.insert(ArrayFonts, font.Name)
	end
end
local ArrayFontFace = Font.fromEnum(Enum.Font.GothamBold)
local ArrayEnumFont = Enum.Font.GothamBold
local TextParams = Instance.new("GetTextBoundsParams")
TextParams.Width = math.huge

local Settings = {
	Open = false,
	Scale = 1,
	Blur = true,
	RainbowSpeed = 0.2,
	CategoryFade = true,
	GradientStart = SharedModuleGradient.DARK_ACCENT,
	GradientEnd = SharedModuleGradient.DARK_ACCENT_HOVER,
	GradientBlend = 0.66,
	GradientLift = 0.35,
	GradientSpread = 0.72,
	GradientGlow = 0.08,
	Viewmodel = false,
	ViewmodelDepth = 0.8,
	ViewmodelHorizontal = 0.8,
	ViewmodelVertical = -0.2,
	ViewmodelRotationX = 0,
	ViewmodelRotationY = 0,
	ViewmodelRotationZ = 0,
	ViewmodelNoBob = true
}

local UiSize = {
	CategoryWidth = 160,
	CategoryMinHeight = 36,
	CategoryHeader = 36,
	CategoryTail = 8,
	CategoryCorner = 8,
	ModuleHeight = 32,
	ModuleText = 11,
	KeybindText = 9,
	OptionText = 9,
	RowHeight = 24,
	SliderHeight = 36
}

local function ColorSave(color)
	return {
		R = math.floor(math.clamp(color.R, 0, 1) * 255 + 0.5),
		G = math.floor(math.clamp(color.G, 0, 1) * 255 + 0.5),
		B = math.floor(math.clamp(color.B, 0, 1) * 255 + 0.5)
	}
end

local function ColorLoad(Value, Default)
	if typeof(Value) == "Color3" then
		return Value
	end
	if type(Value) == "table" then
		return Color3.fromRGB(
			math.clamp(tonumber(Value.R or Value.r or Value[1]) or math.floor(Default.R * 255), 0, 255),
			math.clamp(tonumber(Value.G or Value.g or Value[2]) or math.floor(Default.G * 255), 0, 255),
			math.clamp(tonumber(Value.B or Value.b or Value[3]) or math.floor(Default.B * 255), 0, 255)
		)
	end
	return Default
end

local function RoundStep(Value, Step, Min)
	Step = tonumber(Step) or 1
	Min = tonumber(Min) or 0
	Value = tonumber(Value) or Min
	if Step > 0 then
		Value = math.floor(((Value - Min) / Step) + 0.5) * Step + Min
	end
	if math.abs(Value - math.floor(Value)) < 0.001 then
		Value = math.floor(Value)
	end
	return Value
end

local function TweenGui(object, properties, duration)
	if not object then
		return
	end

	if not State.Ready then
		for property, Value in pairs(properties) do
			object[property] = Value
		end
		return
	end

	local oldTween = State.Tweens[object]
	if oldTween then
		oldTween:Cancel()
	end

	local tween = Tween:Create(
		object,
		TweenInfo.new(duration or 0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		properties
	)
	State.Tweens[object] = tween
	tween.Completed:Connect(function()
		if State.Tweens[object] == tween then
			State.Tweens[object] = nil
		end
	end)
	tween:Play()
	return tween
end

local function Stroke(Parent, transparency, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(42, 42, 42)
	stroke.Transparency = transparency or 0.55
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = Parent
	return stroke
end

local function CfgKey(...)
	local parts = { ... }
	for i, Value in ipairs(parts) do
		parts[i] = tostring(Value)
	end
	return table.concat(parts, "/")
end

local function GetCfg(kind, Key, defaultValue)
	if Config and type(Config.Register) == "function" then
		return Config:Register(kind, Key, defaultValue)
	end
	return defaultValue
end

local function SetCfg(kind, Key, Value)
	if Config and type(Config.Set) == "function" then
		return Config:Set(kind, Key, Value)
	end
	return Value
end

local function SetOpt(Key, Value)
	Settings[Key] = Value
	if Key == "GradientStart" or Key == "GradientEnd" then
		SetCfg("Settings", Key, ColorSave(Value))
	else
		SetCfg("Settings", Key, Value)
	end
end

for Name, Value in pairs(ArraySettings) do
	ArraySettings[Name] = GetCfg("ArrayList", Name, Value)
end

for Key, Value in pairs(Settings) do
	if Key == "GradientStart" or Key == "GradientEnd" then
		Settings[Key] = ColorLoad(GetCfg("Settings", Key, ColorSave(Value)), Value)
	else
		Settings[Key] = GetCfg("Settings", Key, Value)
	end
end

local BuiltIns = {}
local SettingsArrayEnabled = GetCfg("Settings", "ArrayList", false)
local SettingsShadersEnabled = GetCfg("Settings", "Shaders", false)
local SetSettingsArrayList
local ShaderPreset = GetCfg("Shaders", "Preset", "Comet")
local ShaderCreated = {}
local ShaderConnections = {}
local ShaderFolder
local ShaderSaved
local ShaderProperties = {
	"Ambient",
	"Brightness",
	"ColorShift_Bottom",
	"ColorShift_Top",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ExposureCompensation",
	"FogColor",
	"FogEnd",
	"FogStart",
	"GlobalShadows",
	"OutdoorAmbient",
	"ShadowSoftness",
	"ClockTime",
	"GeographicLatitude"
}

local function Asset(id)
	return "http://www.roblox.com/asset/?id=" .. tostring(id)
end

local function WinterSky()
	return {
		SkyboxBk = Asset(8139677359),
		SkyboxDn = Asset(8139677253),
		SkyboxFt = Asset(8139677111),
		SkyboxLf = Asset(8139676988),
		SkyboxRt = Asset(8139676842),
		SkyboxUp = Asset(8139676647),
		SunAngularSize = 0,
		MoonAngularSize = 0,
		CelestialBodiesShown = false
	}
end

local function CometSky()
	return {
		SkyboxBk = Asset(16262356578),
		SkyboxDn = Asset(16262358026),
		SkyboxFt = Asset(16262360469),
		SkyboxLf = Asset(16262362003),
		SkyboxRt = Asset(16262363873),
		SkyboxUp = Asset(16262366016),
		SunAngularSize = 0,
		MoonAngularSize = 0,
		CelestialBodiesShown = false
	}
end

local function CalmSky()
	return {
		SkyboxBk = Asset(4495864450),
		SkyboxDn = Asset(4495864887),
		SkyboxFt = Asset(4495865458),
		SkyboxLf = Asset(4495866035),
		SkyboxRt = Asset(4495866584),
		SkyboxUp = Asset(4495867486),
		SunAngularSize = 0,
		MoonAngularSize = 0,
		CelestialBodiesShown = false
	}
end

local function NightSky()
	return {
		SkyboxBk = Asset(159454299),
		SkyboxDn = Asset(159454296),
		SkyboxFt = Asset(159454293),
		SkyboxLf = Asset(159454286),
		SkyboxRt = Asset(159454300),
		SkyboxUp = Asset(159454288),
		MoonTextureId = "rbxasset://sky/moon.jpg",
		SunTextureId = "rbxasset://sky/sun.jpg",
		StarCount = 3000,
		MoonAngularSize = 18,
		SunAngularSize = 1,
		CelestialBodiesShown = true
	}
end

local ShaderPresets = {
	Comet = {
		Ambient = Color3.fromRGB(88, 65, 120),
		Brightness = 2.65,
		ColorShift_Top = Color3.fromRGB(150, 92, 255),
		ColorShift_Bottom = Color3.fromRGB(36, 28, 58),
		OutdoorAmbient = Color3.fromRGB(78, 70, 120),
		ExposureCompensation = 0.25,
		ClockTime = 18.4,
		FogColor = Color3.fromRGB(78, 61, 125),
		FogStart = 120,
		FogEnd = 900,
		Effects = {
			{ "Sky", CometSky() },
			{ "Atmosphere", { Density = 0.35, Offset = 0.3, Color = Color3.fromRGB(230, 216, 255), Decay = Color3.fromRGB(70, 54, 115), Glare = 0.18, Haze = 1.15 } },
			{ "ColorCorrectionEffect", { TintColor = Color3.fromRGB(218, 200, 255), Saturation = 0.28, Contrast = 0.22, Brightness = 0.04 } },
			{ "BloomEffect", { Intensity = 0.56, Size = 36, Threshold = 1.12 } },
			{ "DepthOfFieldEffect", { FarIntensity = 0.05, FocusDistance = 180, InFocusRadius = 48, NearIntensity = 0 } }
		}
	},
	Winter = {
		Ambient = Color3.fromRGB(145, 172, 195),
		Brightness = 2.25,
		ColorShift_Top = Color3.fromRGB(195, 225, 255),
		ColorShift_Bottom = Color3.fromRGB(116, 145, 175),
		OutdoorAmbient = Color3.fromRGB(165, 190, 210),
		ExposureCompensation = 0.08,
		ClockTime = 12.2,
		FogColor = Color3.fromRGB(205, 232, 255),
		FogStart = 180,
		FogEnd = 1200,
		Effects = {
			{ "Sky", WinterSky() },
			{ "Atmosphere", { Density = 0.3, Offset = 0.25, Color = Color3.fromRGB(245, 250, 255), Decay = Color3.fromRGB(175, 205, 235), Glare = 0.08, Haze = 0.7 } },
			{ "ColorCorrectionEffect", { TintColor = Color3.fromRGB(225, 242, 255), Saturation = -0.08, Contrast = 0.1, Brightness = 0.025 } },
			{ "BloomEffect", { Intensity = 0.22, Size = 20, Threshold = 1.45 } },
			{ "DepthOfFieldEffect", { FarIntensity = 0.035, FocusDistance = 220, InFocusRadius = 65, NearIntensity = 0 } }
		}
	},
	Calm = {
		Ambient = Color3.fromRGB(135, 155, 145),
		Brightness = 2,
		ColorShift_Top = Color3.fromRGB(185, 218, 194),
		ColorShift_Bottom = Color3.fromRGB(96, 118, 105),
		OutdoorAmbient = Color3.fromRGB(135, 158, 142),
		ExposureCompensation = 0,
		ClockTime = 14.6,
		FogColor = Color3.fromRGB(198, 226, 205),
		FogStart = 220,
		FogEnd = 1400,
		Effects = {
			{ "Sky", CalmSky() },
			{ "Atmosphere", { Density = 0.3, Offset = 0.2, Color = Color3.fromRGB(235, 250, 235), Decay = Color3.fromRGB(145, 175, 150), Glare = 0.04, Haze = 0.45 } },
			{ "ColorCorrectionEffect", { TintColor = Color3.fromRGB(226, 244, 222), Saturation = 0.08, Contrast = 0.06, Brightness = 0.01 } },
			{ "BloomEffect", { Intensity = 0.12, Size = 16, Threshold = 1.7 } }
		}
	},
	Night = {
		Ambient = Color3.fromRGB(34, 38, 60),
		Brightness = 1.4,
		ColorShift_Top = Color3.fromRGB(58, 76, 130),
		ColorShift_Bottom = Color3.fromRGB(12, 14, 28),
		OutdoorAmbient = Color3.fromRGB(38, 44, 70),
		ExposureCompensation = -0.18,
		ClockTime = 0.2,
		FogColor = Color3.fromRGB(20, 24, 44),
		FogStart = 70,
		FogEnd = 650,
		Effects = {
			{ "Sky", NightSky() },
			{ "Atmosphere", { Density = 0.42, Offset = 0.12, Color = Color3.fromRGB(120, 136, 190), Decay = Color3.fromRGB(22, 26, 48), Glare = 0, Haze = 1.8 } },
			{ "ColorCorrectionEffect", { TintColor = Color3.fromRGB(176, 196, 255), Saturation = 0.05, Contrast = 0.18, Brightness = -0.025 } },
			{ "BloomEffect", { Intensity = 0.34, Size = 26, Threshold = 1.2 } },
			{ "SunRaysEffect", { Intensity = 0.018, Spread = 0.65 } }
		}
	},
	Sunset = {
		Ambient = Color3.fromRGB(140, 91, 72),
		Brightness = 2.25,
		ColorShift_Top = Color3.fromRGB(255, 162, 92),
		ColorShift_Bottom = Color3.fromRGB(110, 54, 74),
		OutdoorAmbient = Color3.fromRGB(125, 82, 76),
		ExposureCompensation = 0.1,
		ClockTime = 17.8,
		FogColor = Color3.fromRGB(210, 125, 98),
		FogStart = 150,
		FogEnd = 950,
		Effects = {
			{ "Atmosphere", { Density = 0.34, Offset = 0.24, Color = Color3.fromRGB(255, 196, 148), Decay = Color3.fromRGB(130, 62, 82), Glare = 0.28, Haze = 1.1 } },
			{ "ColorCorrectionEffect", { TintColor = Color3.fromRGB(255, 218, 180), Saturation = 0.18, Contrast = 0.16, Brightness = 0.03 } },
			{ "BloomEffect", { Intensity = 0.32, Size = 28, Threshold = 1.32 } },
			{ "SunRaysEffect", { Intensity = 0.08, Spread = 0.72 } }
		}
	},
	Cyber = {
		Ambient = Color3.fromRGB(36, 42, 72),
		Brightness = 2.35,
		ColorShift_Top = Color3.fromRGB(60, 255, 235),
		ColorShift_Bottom = Color3.fromRGB(255, 74, 210),
		OutdoorAmbient = Color3.fromRGB(45, 45, 88),
		ExposureCompensation = 0.12,
		ClockTime = 20.3,
		FogColor = Color3.fromRGB(35, 45, 78),
		FogStart = 90,
		FogEnd = 850,
		Effects = {
			{ "Atmosphere", { Density = 0.38, Offset = 0.1, Color = Color3.fromRGB(132, 255, 245), Decay = Color3.fromRGB(95, 32, 120), Glare = 0.16, Haze = 1.35 } },
			{ "ColorCorrectionEffect", { TintColor = Color3.fromRGB(210, 245, 255), Saturation = 0.42, Contrast = 0.24, Brightness = 0.02 } },
			{ "BloomEffect", { Intensity = 0.5, Size = 34, Threshold = 1.1 } },
			{ "SunRaysEffect", { Intensity = 0.025, Spread = 0.9 } }
		}
	},
	Emerald = {
		Ambient = Color3.fromRGB(58, 106, 76),
		Brightness = 2.15,
		ColorShift_Top = Color3.fromRGB(92, 255, 166),
		ColorShift_Bottom = Color3.fromRGB(30, 80, 56),
		OutdoorAmbient = Color3.fromRGB(66, 112, 84),
		ExposureCompensation = 0.05,
		ClockTime = 13.5,
		FogColor = Color3.fromRGB(106, 176, 132),
		FogStart = 160,
		FogEnd = 1050,
		Effects = {
			{ "Atmosphere", { Density = 0.32, Offset = 0.22, Color = Color3.fromRGB(210, 255, 225), Decay = Color3.fromRGB(65, 118, 82), Glare = 0.08, Haze = 0.85 } },
			{ "ColorCorrectionEffect", { TintColor = Color3.fromRGB(220, 255, 230), Saturation = 0.18, Contrast = 0.12, Brightness = 0.015 } },
			{ "BloomEffect", { Intensity = 0.24, Size = 22, Threshold = 1.45 } }
		}
	},
	Crimson = {
		Ambient = Color3.fromRGB(92, 40, 46),
		Brightness = 1.9,
		ColorShift_Top = Color3.fromRGB(255, 74, 80),
		ColorShift_Bottom = Color3.fromRGB(62, 18, 32),
		OutdoorAmbient = Color3.fromRGB(95, 48, 52),
		ExposureCompensation = -0.03,
		ClockTime = 19.4,
		FogColor = Color3.fromRGB(92, 30, 42),
		FogStart = 75,
		FogEnd = 720,
		Effects = {
			{ "Atmosphere", { Density = 0.4, Offset = 0.08, Color = Color3.fromRGB(255, 145, 136), Decay = Color3.fromRGB(95, 26, 38), Glare = 0.12, Haze = 1.5 } },
			{ "ColorCorrectionEffect", { TintColor = Color3.fromRGB(255, 188, 178), Saturation = 0.16, Contrast = 0.22, Brightness = -0.015 } },
			{ "BloomEffect", { Intensity = 0.3, Size = 24, Threshold = 1.28 } },
			{ "SunRaysEffect", { Intensity = 0.035, Spread = 0.55 } }
		}
	},
	Fullbright = {
		Ambient = Color3.fromRGB(255, 255, 255),
		Brightness = 3,
		ColorShift_Top = Color3.new(0, 0, 0),
		ColorShift_Bottom = Color3.new(0, 0, 0),
		OutdoorAmbient = Color3.fromRGB(255, 255, 255),
		ExposureCompensation = 0.45,
		GlobalShadows = false,
		ClockTime = 14,
		FogStart = 0,
		FogEnd = 100000,
		Effects = {
			{ "ColorCorrectionEffect", { TintColor = Color3.fromRGB(255, 255, 255), Saturation = 0, Contrast = 0.02, Brightness = 0.04 } }
		}
	},
	Clean = {
		Ambient = Color3.fromRGB(128, 128, 128),
		Brightness = 2,
		ColorShift_Top = Color3.new(0, 0, 0),
		ColorShift_Bottom = Color3.new(0, 0, 0),
		OutdoorAmbient = Color3.fromRGB(128, 128, 128),
		ExposureCompensation = 0,
		ClockTime = 14,
		FogStart = 0,
		FogEnd = 100000,
		Effects = {
			{ "ColorCorrectionEffect", { TintColor = Color3.fromRGB(255, 255, 255), Saturation = 0, Contrast = 0.04, Brightness = 0 } }
		}
	}
}

local ShaderPresetList = { "Comet", "Winter", "Calm", "Night", "Sunset", "Cyber", "Emerald", "Crimson", "Fullbright", "Clean" }
if not ShaderPresets[ShaderPreset] then
	ShaderPreset = "Comet"
end

Fn.MarkSetRows = function()
	State.SetRowsDirty = true
end

local function GradStartColor()
	return Settings.GradientStart or SharedModuleGradient.DARK_ACCENT
end

local function GradEndColor()
	return Settings.GradientEnd or SharedModuleGradient.DARK_ACCENT_HOVER
end

local GradCache = {}
local function GradOpts()
	GradCache.Blend = Settings.GradientBlend
	GradCache.Lift = Settings.GradientLift
	return GradCache
end

local function GradColor(offset, base)
	local t = ((base or tick() * Settings.RainbowSpeed) + (offset or 0)) % 1
	return SharedModuleGradient.gradientAt(t, GradStartColor(), GradEndColor(), GradOpts())
end

local function StackColor(index, count, base)
	count = math.max(1, count or 1)
	local stackPosition = ((index or 0) / count) * math.clamp(Settings.GradientSpread or 0.72, 0.1, 1.5)
	local t = (stackPosition - (base or tick() * Settings.RainbowSpeed)) % 1
	return SharedModuleGradient.gradientAt(t, GradStartColor(), GradEndColor(), GradOpts())
end

local function ContrastTextColor(background)
	local brightness = (background.R * 0.299) + (background.G * 0.587) + (background.B * 0.114)
	return brightness < 0.52 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
end

local function CategoryContrastColor(Category, baseHue)
	if not Category then
		return Color.text
	end
	return ContrastTextColor(GradColor(0, baseHue))
end

local function GradSeq(offset, base)
	local t = ((base or tick() * Settings.RainbowSpeed) + (offset or 0)) % 1
	local colorA = SharedModuleGradient.gradientAt(t, GradStartColor(), GradEndColor(), GradOpts())
	local colorB = SharedModuleGradient.gradientAt((t + 0.08) % 1, GradStartColor(), GradEndColor(), GradOpts())
	return ColorSequence.new(colorA, colorB)
end

local function StackSeq(index, count, base)
	count = math.max(1, count or 1)
	local gradientBase = base or tick() * Settings.RainbowSpeed
	local spread = math.clamp(Settings.GradientSpread or 0.72, 0.1, 1.5)
	local t0 = ((((index or 0) / count) * spread) - gradientBase) % 1
	local t1 = (((((index or 0) + 1) / count) * spread) - gradientBase) % 1
	local Options = GradOpts()
	return ColorSequence.new(
		SharedModuleGradient.gradientAt(t0, GradStartColor(), GradEndColor(), Options),
		SharedModuleGradient.gradientAt(t1, GradStartColor(), GradEndColor(), Options)
	)
end

local function RefreshGrads()
	if Fn.RefreshCatGrads then
		for _, Category in ipairs(TaskAPI.CategoryList) do
			Fn.RefreshCatGrads(Category)
		end
	end
	if State.ArrayEnabled and Fn.UpdateArrayColors then
		Fn.UpdateArrayColors()
	end
end

local function Clean(item)
	local itemType = typeof(item)
	if itemType == "RBXScriptConnection" then
		if item.Connected then
			item:Disconnect()
		end
	elseif itemType == "Instance" then
		item:Destroy()
	elseif type(item) == "function" then
		pcall(item)
	elseif type(item) == "table" then
		if type(item.Disconnect) == "function" then
			pcall(function() item:Disconnect() end)
		elseif type(item.Destroy) == "function" then
			pcall(function() item:Destroy() end)
		end
	end
end

local function ClearShaderWeather()
	for _, Connection in ipairs(ShaderConnections) do
		if Connection.Connected then
			Connection:Disconnect()
		end
	end
	table.clear(ShaderConnections)
	if ShaderFolder then
		ShaderFolder:Destroy()
		ShaderFolder = nil
	end
end

local function ClearShaders()
	ClearShaderWeather()
	for _, Object in ipairs(ShaderCreated) do
		if Object and Object.Parent then
			Object:Destroy()
		end
	end
	table.clear(ShaderCreated)
	for _, Child in ipairs(Lighting:GetChildren()) do
		if Child:GetAttribute("TaskiumShader") then
			Child:Destroy()
		end
	end
end

local function SaveLighting()
	if ShaderSaved then
		return
	end
	ShaderSaved = {
		Properties = {},
		Children = {}
	}
	for _, Property in ipairs(ShaderProperties) do
		pcall(function()
			ShaderSaved.Properties[Property] = Lighting[Property]
		end)
	end
	for _, Child in ipairs(Lighting:GetChildren()) do
		table.insert(ShaderSaved.Children, Child:Clone())
	end
end

local function ShaderVisualFolder()
	if ShaderFolder then
		return ShaderFolder
	end
	ShaderFolder = Instance.new("Folder")
	ShaderFolder.Name = "TaskiumShaderVisuals"
	ShaderFolder.Parent = workspace
	return ShaderFolder
end

local function ShaderVisualCenter()
	local Camera = workspace.CurrentCamera
	return Camera and Camera.CFrame.Position or Vector3.zero
end

local function KeepShaderField(Parts, Height, Spacing)
	local LastUpdate = 0
	table.insert(ShaderConnections, RunService.RenderStepped:Connect(function()
		local Now = os.clock()
		if Now - LastUpdate < 0.75 then
			return
		end
		LastUpdate = Now

		local Center = ShaderVisualCenter()
		local BaseX = math.floor(Center.X / Spacing + 0.5) * Spacing
		local BaseZ = math.floor(Center.Z / Spacing + 0.5) * Spacing
		for _, Data in ipairs(Parts) do
			local Part = Data.Part
			if Part and Part.Parent then
				Part.CFrame = CFrame.new(BaseX + Data.X, Center.Y + Height + Data.Y, BaseZ + Data.Z) * Data.Angle
			end
		end
	end))
end

local function ShaderEmitterPart(Name, Position, Angle)
	local Folder = ShaderVisualFolder()
	local Part = Instance.new("Part")
	Part.Name = Name
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanQuery = false
	Part.CanTouch = false
	Part.Transparency = 1
	Part.Size = Vector3.new(1, 1, 1)
	Part.CFrame = CFrame.new(Position or Vector3.zero) * (Angle or CFrame.new())
	Part.Parent = Folder
	return Part
end

local function ShaderVisualField(Name, Rows, Spacing, Height, Angle)
	local Center = ShaderVisualCenter()
	local Half = math.floor(Rows / 2)
	local Parts = {}
	for X = -Half, Half do
		for Z = -Half, Half do
			local JitterX = ((X + Z) % 2 == 0 and 0.32 or -0.28) * Spacing
			local JitterZ = ((X - Z) % 2 == 0 and -0.24 or 0.27) * Spacing
			local Data = {
				X = X * Spacing + JitterX,
				Y = ((X * 13 + Z * 7) % 24) - 12,
				Z = Z * Spacing + JitterZ,
				Angle = Angle or CFrame.new()
			}
			Data.Part = ShaderEmitterPart(Name, Vector3.new(Center.X + Data.X, Center.Y + Height + Data.Y, Center.Z + Data.Z), Data.Angle)
			table.insert(Parts, Data)
		end
	end
	KeepShaderField(Parts, Height, Spacing)
	return Parts
end

local function StartComets()
	for _, Data in ipairs(ShaderVisualField("Comets", 4, 170, 115, CFrame.Angles(math.rad(22), 0, math.rad(-34)))) do
		local Emitter = Instance.new("ParticleEmitter")
		Emitter.Name = "CometFall"
		Emitter.Texture = Asset(258128463)
		Emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(215, 190, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(95, 52, 190))
		})
		Emitter.EmissionDirection = Enum.NormalId.Front
		Emitter.LightEmission = 1
		Emitter.LightInfluence = 0
		Emitter.Rate = 2
		Emitter.Lifetime = NumberRange.new(1.45, 2.25)
		Emitter.Speed = NumberRange.new(135, 185)
		Emitter.SpreadAngle = Vector2.new(8, 14)
		Emitter.Rotation = NumberRange.new(-35, 35)
		Emitter.RotSpeed = NumberRange.new(-25, 25)
		Emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.8),
			NumberSequenceKeypoint.new(0.3, 0.8),
			NumberSequenceKeypoint.new(1, 0)
		})
		Emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.72, 0.04),
			NumberSequenceKeypoint.new(1, 1)
		})
		Emitter.Acceleration = Vector3.new(42, -22, 0)
		Emitter.Parent = Data.Part
	end
end

local function StartSnow()
	for _, Data in ipairs(ShaderVisualField("Snow", 7, 95, 95)) do
		local Emitter = Instance.new("ParticleEmitter")
		Emitter.Name = "Snowflakes"
		Emitter.Texture = Asset(8158344433)
		Emitter.Color = ColorSequence.new(Color3.fromRGB(248, 253, 255))
		Emitter.EmissionDirection = Enum.NormalId.Bottom
		Emitter.LightEmission = 0.5
		Emitter.LightInfluence = 0.05
		Emitter.Rate = 48
		Emitter.Lifetime = NumberRange.new(6.5, 9)
		Emitter.Speed = NumberRange.new(20, 34)
		Emitter.SpreadAngle = Vector2.new(58, 58)
		Emitter.Rotation = NumberRange.new(0, 360)
		Emitter.RotSpeed = NumberRange.new(-95, 95)
		Emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.15),
			NumberSequenceKeypoint.new(0.5, 1.55),
			NumberSequenceKeypoint.new(1, 0.9)
		})
		Emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.82, 0.03),
			NumberSequenceKeypoint.new(1, 0.75)
		})
		Emitter.Acceleration = Vector3.new(7, -22, -5)
		Emitter.Parent = Data.Part
	end
end

local function CharacterRoot(Character)
	return Character and (Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart)
end

local function StartNightLocalGlow()
	local Part = ShaderEmitterPart("LocalNightGlow", ShaderVisualCenter())
	Part.Size = Vector3.new(3, 3, 3)

	local Light = Instance.new("PointLight")
	Light.Name = "NightGlowLight"
	Light.Color = Color3.fromRGB(185, 210, 255)
	Light.Brightness = 2.4
	Light.Range = 22
	Light.Shadows = false
	Light.Parent = Part

	local Emitter = Instance.new("ParticleEmitter")
	Emitter.Name = "NightGlowAura"
	Emitter.Texture = Asset(258128463)
	Emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(135, 170, 255))
	})
	Emitter.LightEmission = 0.75
	Emitter.LightInfluence = 0
	Emitter.Rate = 28
	Emitter.Lifetime = NumberRange.new(1.2, 2.1)
	Emitter.Speed = NumberRange.new(1.5, 4.5)
	Emitter.SpreadAngle = Vector2.new(360, 360)
	Emitter.Rotation = NumberRange.new(0, 360)
	Emitter.RotSpeed = NumberRange.new(-35, 35)
	Emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.45, 1.4),
		NumberSequenceKeypoint.new(1, 0)
	})
	Emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.75, 0.45),
		NumberSequenceKeypoint.new(1, 1)
	})
	Emitter.Parent = Part

	table.insert(ShaderConnections, RunService.RenderStepped:Connect(function()
		local Root = CharacterRoot(LocalPlayer and LocalPlayer.Character)
		if Root and Part.Parent then
			Part.CFrame = Root.CFrame
		end
	end))
end

local function GlowShaderPlayer(Player)
	if not Player or Player == LocalPlayer then
		return
	end

	local function Apply(Character)
		if not ShaderFolder or not Character then
			return
		end

		local Highlight = Instance.new("Highlight")
		Highlight.Name = "NightPlayerGlow"
		Highlight.Adornee = Character
		Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		Highlight.FillColor = Color3.fromRGB(255, 255, 255)
		Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		Highlight.FillTransparency = 0.78
		Highlight.OutlineTransparency = 0.1
		Highlight.Parent = ShaderFolder
	end

	Apply(Player.Character)
	table.insert(ShaderConnections, Player.CharacterAdded:Connect(Apply))
end

local function StartNightGlow()
	StartNightLocalGlow()
	for _, Player in ipairs(Players:GetPlayers()) do
		GlowShaderPlayer(Player)
	end
	table.insert(ShaderConnections, Players.PlayerAdded:Connect(GlowShaderPlayer))
end

local function StartCleanRain()
	ShaderVisualFolder()
	for _, Data in ipairs(ShaderVisualField("Rain", 6, 82, 78, CFrame.Angles(0, 0, math.rad(-7)))) do
		local Emitter = Instance.new("ParticleEmitter")
		Emitter.Name = "CleanRain"
		Emitter.Texture = Asset(241685484)
		Emitter.Color = ColorSequence.new(Color3.fromRGB(178, 205, 235))
		Emitter.EmissionDirection = Enum.NormalId.Bottom
		Emitter.LightEmission = 0.15
		Emitter.LightInfluence = 0.1
		Emitter.Rate = 92
		Emitter.Lifetime = NumberRange.new(0.7, 1.05)
		Emitter.Speed = NumberRange.new(78, 116)
		Emitter.SpreadAngle = Vector2.new(12, 18)
		Emitter.Rotation = NumberRange.new(-8, 8)
		Emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.16),
			NumberSequenceKeypoint.new(1, 0.11)
		})
		Emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.78, 0.18),
			NumberSequenceKeypoint.new(1, 1)
		})
		Emitter.Acceleration = Vector3.new(14, -150, 0)
		Emitter.Parent = Data.Part
	end

	local Sound = Instance.new("Sound")
	Sound.Name = "CleanRainSound"
	Sound.SoundId = "rbxassetid://9125402735"
	Sound.Volume = 0.42
	Sound.Looped = true
	Sound.Parent = SoundService
	Sound:Play()
	table.insert(ShaderCreated, Sound)
end

local function ApplyShaderVisuals()
	ClearShaderWeather()
	if ShaderPreset == "Comet" then
		ShaderVisualFolder()
		StartComets()
	elseif ShaderPreset == "Winter" then
		ShaderVisualFolder()
		StartSnow()
	elseif ShaderPreset == "Night" then
		ShaderVisualFolder()
		StartNightGlow()
	elseif ShaderPreset == "Clean" then
		StartCleanRain()
	end
end

local function ApplyShaderPreset()
	SaveLighting()
	ClearShaders()
	local Data = ShaderPresets[ShaderPreset] or ShaderPresets.Comet
	if ShaderSaved then
		for _, Property in ipairs(ShaderProperties) do
			local Value = ShaderSaved.Properties[Property]
			if Value ~= nil then
				pcall(function()
					Lighting[Property] = Value
				end)
			end
		end
	end
	for Key, Value in pairs(Data) do
		if Key ~= "Effects" then
			pcall(function()
				Lighting[Key] = Value
			end)
		end
	end
	for _, EffectData in ipairs(Data.Effects or {}) do
		local Object = Instance.new(EffectData[1])
		Object.Name = "TaskiumShader_" .. EffectData[1]
		for Key, Value in pairs(EffectData[2] or {}) do
			pcall(function()
				Object[Key] = Value
			end)
		end
		Object:SetAttribute("TaskiumShader", true)
		Object.Parent = Lighting
		table.insert(ShaderCreated, Object)
	end
	ApplyShaderVisuals()
end

local function RestoreLighting()
	ClearShaders()
	if not ShaderSaved then
		return
	end
	for _, Property in ipairs(ShaderProperties) do
		local Value = ShaderSaved.Properties[Property]
		if Value ~= nil then
			pcall(function()
				Lighting[Property] = Value
			end)
		end
	end
	for _, Child in ipairs(ShaderSaved.Children) do
		if not Lighting:FindFirstChild(Child.Name) then
			local Clone = Child:Clone()
			Clone.Parent = Lighting
		end
		Child:Destroy()
	end
	ShaderSaved = nil
end

local function SetSettingsShaders(enabled)
	SettingsShadersEnabled = enabled and true or false
	SetCfg("Settings", "Shaders", SettingsShadersEnabled)
	if SettingsShadersEnabled then
		ApplyShaderPreset()
	else
		RestoreLighting()
	end
end

local function FlyKey(KeyCode)
	return KeyCode == Enum.KeyCode.Space or KeyCode == Enum.KeyCode.LeftShift
end

local function KeyCode(KeyName)
	if typeof(KeyName) == "EnumItem" then
		local Ok, IsKeyCode = pcall(function()
			return KeyName.EnumType == Enum.KeyCode
		end)
		return Ok and IsKeyCode and KeyName or nil
	end

	if type(KeyName) ~= "string" or KeyName == "" then
		return nil
	end

	local prefix = "Enum.KeyCode."
	if KeyName:sub(1, #prefix) == prefix then
		KeyName = KeyName:sub(#prefix + 1)
	end

	local Ok, KeyCode = pcall(function()
		return Enum.KeyCode[KeyName]
	end)

	if Ok and typeof(KeyCode) == "EnumItem" then
		return KeyCode
	end

	return nil
end

local function Reserved(module, KeyName)
	if type(KeyName) ~= "string" or KeyName == "" then
		return false
	end

	local KeyCode = KeyCode(KeyName)
	if not KeyCode then
		return false
	end

	if KeyCode == Enum.KeyCode.RightShift then
		return true, "RightShift is reserved for opening Taskium."
	end

	if module and module.Name == "Fly" and FlyKey(KeyCode) then
		return true, "Space and LeftShift are reserved for Fly movement."
	end

	return false
end

local function InputReserved(Input)
	if Input.UserInputType ~= Enum.UserInputType.Keyboard then
		return false
	end
	if Input.KeyCode == Enum.KeyCode.RightShift then
		return true
	end

	local fly = TaskAPI.Modules.Fly
	return fly and fly.Enabled and FlyKey(Input.KeyCode)
end

local function RunCb(kind, Name, callback, ...)
	if type(callback) ~= "function" then
		return nil
	end

	local Ok, result = pcall(callback, ...)
	if Ok then
		return result
	end

	warn(("BetaUI %s '%s' failed: %s"):format(kind, tostring(Name), tostring(result)))
	TaskAPI.Notification("Taskium", ("%s '%s' failed."):format(kind, tostring(Name)), 4, "Error")
	return nil
end

local function Disconnect(api)
	if type(api) ~= "table" then
		return
	end

	local seen = {}
	if type(api.Modules) == "table" then
		for _, module in pairs(api.Modules) do
			if type(module) == "table" and not seen[module] then
				seen[module] = true
				if type(module.SetEnabled) == "function" then
					pcall(function()
						module:SetEnabled(false, { SkipConfig = true, SkipNotify = true })
					end)
				end
				if type(module.Cleanup) == "function" then
					pcall(function()
						module:Cleanup()
					end)
				end
			end
		end
	end

	if type(api.Connections) == "table" then
		for _, connection in ipairs(api.Connections) do
			Clean(connection)
		end
	end

	if typeof(api.BlurEffect) == "Instance" then
		pcall(function()
			(api.BlurEffect).Enabled = false
		end)
	end
end

local OldApi = getgenv().TaskAPI
if OldApi and OldApi ~= TaskAPI then
	Disconnect(OldApi)
end

for _, Name in ipairs({ "UIHolder", "TaskUI", "Notifications", "TaskNotifications", "TaskArrayList" }) do
	local gui = PlayerGui:FindFirstChild(Name)
	if gui then
		gui:Destroy()
	end
end

local OldBlur = Lighting:FindFirstChild("UIBlur") or Lighting:FindFirstChild("TaskUIBlur")
if OldBlur then
	OldBlur:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UIHolder"
ScreenGui.Enabled = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local Blur = Instance.new("BlurEffect")
Blur.Name = "UIBlur"
Blur.Size = 10
Blur.Enabled = false
Blur.Parent = Lighting

local NotifGui = Instance.new("ScreenGui")
NotifGui.Name = "Notifications"
NotifGui.ResetOnSpawn = false
NotifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
NotifGui.Parent = PlayerGui

local NotifFrame = Instance.new("Frame")
NotifFrame.Name = "NotificationsContainer"
NotifFrame.Size = UDim2.new(0, 290, 0.4, 0)
NotifFrame.AnchorPoint = Vector2.new(1, 1)
NotifFrame.Position = UDim2.new(1, 0, 1, -6)
NotifFrame.BackgroundTransparency = 1
NotifFrame.BorderSizePixel = 0
NotifFrame.Parent = NotifGui

local NotifLayout = Instance.new("UIListLayout")
NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
NotifLayout.Padding = UDim.new(0, 6)
NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotifLayout.Parent = NotifFrame

TaskAPI.ScreenGui = ScreenGui
TaskAPI.screenGui = ScreenGui
TaskAPI.BlurEffect = Blur
TaskAPI.NotificationGui = NotifGui
TaskAPI.Connections = {}
TaskAPI.Settings = Settings
TaskAPI.Settings.ShaderPresets = ShaderPresetList
TaskAPI.Settings.ShaderPreset = ShaderPreset
TaskAPI.Settings.GetShaderPreset = function()
	return ShaderPreset
end
TaskAPI.Settings.SetShaderPreset = function(Value)
	if not ShaderPresets[Value] then
		return
	end
	ShaderPreset = Value
	TaskAPI.Settings.ShaderPreset = ShaderPreset
	SetCfg("Shaders", "Preset", ShaderPreset)
	if SettingsShadersEnabled then
		ApplyShaderPreset()
	end
	if Fn.MarkSetRows then
		Fn.MarkSetRows()
	end
end

UI.SettingsHolder = Instance.new("Frame")
UI.SettingsHolder.Name = "SettingsHolder"
UI.SettingsHolder.AnchorPoint = Vector2.new(0.5, 0)
UI.SettingsHolder.Position = UDim2.new(0.5, 0, 0, -480)
UI.SettingsHolder.Size = UDim2.new(0, 410, 0, 458)
UI.SettingsHolder.BackgroundColor3 = Color.window
UI.SettingsHolder.BorderSizePixel = 0
UI.SettingsHolder.ClipsDescendants = false
UI.SettingsHolder.Active = true
UI.SettingsHolder.Visible = false
UI.SettingsHolder.ZIndex = 60
UI.SettingsHolder.Parent = ScreenGui

local SettingsCorner = Instance.new("UICorner")
SettingsCorner.CornerRadius = UDim.new(0, 10)
SettingsCorner.Parent = UI.SettingsHolder

Stroke(UI.SettingsHolder, 0.45, Color3.fromRGB(55, 55, 55), 1)

local SettingsFrame = Instance.new("Frame")
SettingsFrame.Name = "Header"
SettingsFrame.Size = UDim2.new(1, 0, 0, 74)
SettingsFrame.BackgroundColor3 = Color.header
SettingsFrame.BackgroundTransparency = 0.08
SettingsFrame.BorderSizePixel = 0
SettingsFrame.ZIndex = 60
SettingsFrame.Parent = UI.SettingsHolder

local SettingsFrameCorner = Instance.new("UICorner")
SettingsFrameCorner.TopLeftRadius = UDim.new(0, 10)
SettingsFrameCorner.TopRightRadius = UDim.new(0, 10)
SettingsFrameCorner.BottomLeftRadius = UDim.new(0, 0)
SettingsFrameCorner.BottomRightRadius = UDim.new(0, 0)
SettingsFrameCorner.Parent = SettingsFrame

local SettingsDivider = Instance.new("Frame")
SettingsDivider.Name = "SettingsDivider"
SettingsDivider.AnchorPoint = Vector2.new(0, 1)
SettingsDivider.Position = UDim2.new(0, 14, 1, 0)
SettingsDivider.Size = UDim2.new(1, -28, 0, 1)
SettingsDivider.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
SettingsDivider.BackgroundTransparency = 0.25
SettingsDivider.BorderSizePixel = 0
SettingsDivider.ZIndex = 61
SettingsDivider.Parent = SettingsFrame

UI.SettingsHandler = Instance.new("TextButton")
UI.SettingsHandler.Name = "SettingsHandler"
UI.SettingsHandler.AnchorPoint = Vector2.new(0.5, 0)
UI.SettingsHandler.Position = UDim2.new(0.5, 0, 0, 0)
UI.SettingsHandler.Size = UDim2.new(0, 210, 0, 34)
UI.SettingsHandler.BackgroundColor3 = Color.window
UI.SettingsHandler.BorderSizePixel = 0
UI.SettingsHandler.AutoButtonColor = false
UI.SettingsHandler.Text = "Settings"
UI.SettingsHandler.TextColor3 = Color.text
UI.SettingsHandler.TextSize = 16
UI.SettingsHandler.Font = Enum.Font.GothamBold
UI.SettingsHandler.ZIndex = 70
UI.SettingsHandler.Parent = ScreenGui

UI.SettingsHandlerCorner = Instance.new("UICorner")
UI.SettingsHandlerCorner.TopLeftRadius = UDim.new(0, 0)
UI.SettingsHandlerCorner.TopRightRadius = UDim.new(0, 0)
UI.SettingsHandlerCorner.BottomLeftRadius = UDim.new(0, 8)
UI.SettingsHandlerCorner.BottomRightRadius = UDim.new(0, 8)
UI.SettingsHandlerCorner.Parent = UI.SettingsHandler

Stroke(UI.SettingsHandler, 0.5, Color3.fromRGB(48, 48, 48), 1)

UI.SettingsTitle = Instance.new("TextLabel")
UI.SettingsTitle.Name = "Title"
UI.SettingsTitle.Size = UDim2.new(1, -28, 0, 28)
UI.SettingsTitle.Position = UDim2.new(0, 18, 0, 16)
UI.SettingsTitle.BackgroundTransparency = 1
UI.SettingsTitle.BorderSizePixel = 0
UI.SettingsTitle.Text = "Settings"
UI.SettingsTitle.TextColor3 = Color.text
UI.SettingsTitle.TextSize = 18
UI.SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
UI.SettingsTitle.TextYAlignment = Enum.TextYAlignment.Center
UI.SettingsTitle.Font = Enum.Font.GothamBold
UI.SettingsTitle.ZIndex = 61
UI.SettingsTitle.Parent = UI.SettingsHolder

UI.SettingsSubtitle = Instance.new("TextLabel")
UI.SettingsSubtitle.Name = "Subtitle"
UI.SettingsSubtitle.Size = UDim2.new(1, -28, 0, 20)
UI.SettingsSubtitle.Position = UDim2.new(0, 18, 0, 43)
UI.SettingsSubtitle.BackgroundTransparency = 1
UI.SettingsSubtitle.BorderSizePixel = 0
UI.SettingsSubtitle.Text = "Customize the click GUI."
UI.SettingsSubtitle.TextColor3 = Color.muted
UI.SettingsSubtitle.TextSize = 11
UI.SettingsSubtitle.TextXAlignment = Enum.TextXAlignment.Left
UI.SettingsSubtitle.TextYAlignment = Enum.TextYAlignment.Center
UI.SettingsSubtitle.Font = Enum.Font.Gotham
UI.SettingsSubtitle.ZIndex = 61
UI.SettingsSubtitle.Parent = UI.SettingsHolder

local SettingsClose = Instance.new("TextButton")
SettingsClose.Name = "CloseButton"
SettingsClose.AnchorPoint = Vector2.new(1, 0)
SettingsClose.Position = UDim2.new(1, -16, 0, 16)
SettingsClose.Size = UDim2.new(0, 28, 0, 28)
SettingsClose.BackgroundColor3 = Color.Action
SettingsClose.BorderSizePixel = 0
SettingsClose.AutoButtonColor = false
SettingsClose.Text = "x"
SettingsClose.TextColor3 = Color.text
SettingsClose.TextSize = 14
SettingsClose.Font = Enum.Font.GothamBold
SettingsClose.ZIndex = 62
SettingsClose.Parent = UI.SettingsHolder

local SettingsCloseCorner = Instance.new("UICorner")
SettingsCloseCorner.CornerRadius = UDim.new(0, 7)
SettingsCloseCorner.Parent = SettingsClose

Stroke(SettingsClose, 0.62, Color3.fromRGB(62, 62, 62), 1)

UI.SettingsBody = Instance.new("ScrollingFrame")
UI.SettingsBody.Name = "Body"
UI.SettingsBody.Size = UDim2.new(1, -28, 1, -90)
UI.SettingsBody.Position = UDim2.new(0, 14, 0, 82)
UI.SettingsBody.BackgroundTransparency = 1
UI.SettingsBody.BorderSizePixel = 0
UI.SettingsBody.ScrollBarThickness = 3
UI.SettingsBody.ScrollBarImageColor3 = Color3.fromRGB(85, 85, 85)
UI.SettingsBody.ScrollBarImageTransparency = 0.2
UI.SettingsBody.ScrollingDirection = Enum.ScrollingDirection.Y
UI.SettingsBody.CanvasSize = UDim2.new(0, 0, 0, 0)
UI.SettingsBody.ZIndex = 61
UI.SettingsBody.Parent = UI.SettingsHolder

local SettingsBodyPadding = Instance.new("UIPadding")
SettingsBodyPadding.PaddingBottom = UDim.new(0, 8)
SettingsBodyPadding.Parent = UI.SettingsBody

local SettingsBodyLayout = Instance.new("UIListLayout")
SettingsBodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
SettingsBodyLayout.Padding = UDim.new(0, 5)
SettingsBodyLayout.Parent = UI.SettingsBody
SettingsBodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	UI.SettingsBody.CanvasSize = UDim2.new(0, 0, 0, SettingsBodyLayout.AbsoluteContentSize.Y + 12)
end)

local ToolTipFrame = Instance.new("Frame")
ToolTipFrame.Name = "ToolTip"
ToolTipFrame.Size = UDim2.new(0, 20, 0, 20)
ToolTipFrame.BackgroundColor3 = Color.window
ToolTipFrame.BackgroundTransparency = 0.1
ToolTipFrame.BorderSizePixel = 0
ToolTipFrame.ClipsDescendants = false
ToolTipFrame.Visible = false
ToolTipFrame.ZIndex = 50
ToolTipFrame.Parent = ScreenGui

local ToolTipCorner = Instance.new("UICorner")
ToolTipCorner.CornerRadius = UDim.new(0, 20)
ToolTipCorner.Parent = ToolTipFrame

local ToolTipText = Instance.new("TextLabel")
ToolTipText.Name = "ToolTipText"
ToolTipText.Size = UDim2.new(1, -12, 1, 0)
ToolTipText.Position = UDim2.new(0, 6, 0, 0)
ToolTipText.BackgroundTransparency = 1
ToolTipText.BorderSizePixel = 0
ToolTipText.Text = ""
ToolTipText.TextSize = 12
ToolTipText.TextColor3 = Color.text
ToolTipText.TextXAlignment = Enum.TextXAlignment.Center
ToolTipText.TextYAlignment = Enum.TextYAlignment.Center
ToolTipText.Font = Enum.Font.Gotham
ToolTipText.ZIndex = 51
ToolTipText.Parent = ToolTipFrame

local function ViewSize()
	return GameCamera and GameCamera.ViewportSize or Vector2.new(1920, 1080)
end

local function MoveTip(MousePosition)
	if not ToolTipFrame.Visible then
		return
	end

	local view = ViewSize()
	local x = math.clamp(MousePosition.X + 14, 6, view.X - ToolTipFrame.Size.X.Offset - 6)
	local y = math.clamp(MousePosition.Y + 16, 6, view.Y - ToolTipFrame.Size.Y.Offset - 6)
	ToolTipFrame.Position = UDim2.new(0, x, 0, y)
end

local function ShowTip(Message)
	if type(Message) ~= "string" or Message == "" then
		return
	end

	State.Tip = Message
	local Size = Text:GetTextSize(Message, 12, Enum.Font.Gotham, Vector2.new(1000, 20))
	ToolTipFrame.Size = UDim2.new(0, math.max(20, Size.X + 14), 0, 20)
	ToolTipText.Text = Message
	ToolTipFrame.Visible = true
	MoveTip(InputService:GetMouseLocation())
end

Fn.HideTip = function()
	State.Tip = nil
	ToolTipFrame.Visible = false
	ToolTipText.Text = ""
end

local function ModuleLayout(Module)
	if Module.SettingsOnly then
		Module.TargetHeight = 0
		Module.Container.Size = UDim2.new(1, 0, 0, 0)
		Module.OptionsHolder.Size = UDim2.new(1, 0, 0, 0)
		return
	end
	local OptionHeight = 0
	local function controlHeight(control, fallback)
		if control and control.Object and control.Object.Visible == false then
			return 0
		end
		return (control and control.ControlHeight) or fallback
	end
	if Module.Expanded then
		if Module.ControlList then
			for _, Control in ipairs(Module.ControlList) do
				OptionHeight += controlHeight(Control, Control and Control.ControlHeight or UiSize.RowHeight)
			end
		else
			for _, Toggle in ipairs(Module.ToggleList) do
				OptionHeight += controlHeight(Toggle, UiSize.RowHeight)
			end
			for _, Button in ipairs(Module.ButtonList) do
				OptionHeight += controlHeight(Button, UiSize.RowHeight)
			end
			for _, Slider in ipairs(Module.SliderList) do
				OptionHeight += controlHeight(Slider, UiSize.SliderHeight)
			end
			for _, Dropdown in ipairs(Module.DropdownList) do
				OptionHeight += controlHeight(Dropdown, UiSize.RowHeight)
			end
			for _, TextBox in ipairs(Module.TextBoxList) do
				OptionHeight += controlHeight(TextBox, UiSize.RowHeight)
			end
			for _, HotbarList in ipairs(Module.HotbarListList or {}) do
				OptionHeight += controlHeight(HotbarList, 40)
			end
		end
	end
	local Height = Module.BaseHeight + OptionHeight
	Module.TargetHeight = Height
	TweenGui(Module.Container, { Size = UDim2.new(1, 0, 0, Height) })
	TweenGui(Module.OptionsHolder, { Size = UDim2.new(1, 0, 0, OptionHeight) })
end

local function CategorySize(Category)
	local contentHeight = 0
	for _, module in ipairs(Category.ModuleList) do
		contentHeight += module.TargetHeight or module.BaseHeight or UiSize.ModuleHeight
	end
	local maxBodyHeight = math.max(Category.MaxHeight - UiSize.CategoryHeader - UiSize.CategoryTail, UiSize.ModuleHeight)
	local visibleBodyHeight = math.min(contentHeight, maxBodyHeight)
	if contentHeight > maxBodyHeight then
		visibleBodyHeight = math.max(UiSize.ModuleHeight, math.floor(maxBodyHeight / UiSize.ModuleHeight) * UiSize.ModuleHeight)
	end
	local targetHeight = UiSize.CategoryHeader + visibleBodyHeight + UiSize.CategoryTail
	local targetSize = UDim2.new(Category.DefaultSize.X.Scale, Category.DefaultSize.X.Offset, 0, targetHeight)
	TweenGui(Category.MainFrame, { Size = targetSize })
	if Category.CategoryShadow then
		TweenGui(Category.CategoryShadow, { Size = targetSize })
	end
	TweenGui(Category.ContainerFrame, { Size = targetSize })
	Category.ModulesHolder.Size = UDim2.new(1, 0, 0, visibleBodyHeight)
	Category.ModulesHolder.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
	if Category.CategoryGradientViewport then
		Category.CategoryGradientViewport.Size = Category.ModulesHolder.Size
	end
	if Category.CategoryGradientFrame then
		Category.CategoryGradientFrame.Size = UDim2.new(1, 0, 0, contentHeight)
		Category.CategoryGradientFrame.Position = UDim2.new(0, 0, 0, -Category.ModulesHolder.CanvasPosition.Y)
	end
end

local function SortModules(Category)
	table.sort(Category.ModuleList, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)
	for index, module in ipairs(Category.ModuleList) do
		module.Container.LayoutOrder = index
		module.Index = index
	end
end

local function IsPointer(Input)
	return Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch
end

local function IsDragPointer(Input)
	return Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch
end

local function InputY(Input)
	if ScreenGui and ScreenGui.IgnoreGuiInset then
		return Input.Position.Y
	end
	local inset = Gui:GetGuiInset()
	return Input.Position.Y - inset.Y
end

local function SetOpenPos()
	return UDim2.new(0.5, 0, 0, 42)
end

local function SetClosedPos()
	return UDim2.new(0.5, 0, 0, -480)
end

local function HandleClosedPos()
	return UDim2.new(0.5, 0, 0, 0)
end

local function HandleOpenPos()
	return HandleClosedPos()
end

local function HandleShape(open)
	if not UI.SettingsHandlerCorner then
		return
	end
	if open then
		UI.SettingsHandlerCorner.TopLeftRadius = UDim.new(0, 8)
		UI.SettingsHandlerCorner.TopRightRadius = UDim.new(0, 8)
		UI.SettingsHandlerCorner.BottomLeftRadius = UDim.new(0, 8)
		UI.SettingsHandlerCorner.BottomRightRadius = UDim.new(0, 8)
	else
		UI.SettingsHandlerCorner.TopLeftRadius = UDim.new(0, 0)
		UI.SettingsHandlerCorner.TopRightRadius = UDim.new(0, 0)
		UI.SettingsHandlerCorner.BottomLeftRadius = UDim.new(0, 8)
		UI.SettingsHandlerCorner.BottomRightRadius = UDim.new(0, 8)
	end
end

local function StoreFade(object)
	if not object:IsA("GuiObject") then
		return nil
	end
	local state = State.Fade[object]
	if state then
		return state
	end

	state = {
		Visible = object.Visible
	}
	if object:IsA("GuiObject") then
		state.BackgroundTransparency = object.BackgroundTransparency
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		state.TextTransparency = object.TextTransparency
		state.TextStrokeTransparency = object.TextStrokeTransparency
	end
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		state.ImageTransparency = object.ImageTransparency
	end
	State.Fade[object] = state
	return state
end

local function TweenCat(object, hidden)
	if not object or not object.Parent or not object:IsA("GuiObject") then
		return
	end
	local state = StoreFade(object)
	if not state then
		return
	end
	if hidden and not state.Visible then
		return
	end
	object.Visible = hidden and true or state.Visible
	local props = {}
	if object:IsA("GuiObject") then
		props.BackgroundTransparency = hidden and 1 or state.BackgroundTransparency
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		props.TextTransparency = hidden and 1 or state.TextTransparency
		props.TextStrokeTransparency = hidden and 1 or state.TextStrokeTransparency
	end
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		props.ImageTransparency = hidden and 1 or state.ImageTransparency
	end
	if next(props) then
		if Settings.CategoryFade then
			TweenGui(object, props, hidden and 0.16 or 0.2)
		else
			for property, Value in pairs(props) do
				object[property] = Value
			end
		end
	end
end

local function HideCats(hidden)
	State.HideToken += 1
	local token = State.HideToken
	for _, Category in ipairs(TaskAPI.CategoryList) do
		local Container = Category.ContainerFrame
		if Container then
			if hidden then
				Container.Visible = true
				for _, object in ipairs(Container:GetDescendants()) do
					TweenCat(object, true)
				end
				TweenCat(Container, true)
				task.delay(Settings.CategoryFade and 0.17 or 0, function()
					if State.HideToken == token and (Settings.Open or (State.SetDrag and State.SetDrag.PreviewHidden)) and Container.Parent then
						Container.Visible = false
					end
				end)
			else
				Container.Visible = true
				TweenCat(Container, false)
				for _, object in ipairs(Container:GetDescendants()) do
					TweenCat(object, false)
				end
			end
		end
	end
end

local function ResetCategories()
	local names = { "Combat", "Movement", "Render", "Player", "Inventory", "Other" }
	local width = 165
	local gap = 14
	local step = width + gap
	local center = ((#names - 1) * step) / 2
	for index, Name in ipairs(names) do
		local Category = TaskAPI.Categories[Name]
		if Category and Category.ContainerFrame then
			local position = UDim2.new(0.5, ((index - 1) * step) - center, 0.2, 0)
			Category.Position = position
			TweenGui(Category.ContainerFrame, { Position = position }, 0.22)
		end
	end
end

local function CatScale(Category)
	local Container = Category and Category.ContainerFrame
	if not Container then
		return
	end
	local scale = State.Scale[Container]
	if not (scale and scale.Parent) then
		scale = Instance.new("UIScale")
		scale.Name = "CategoryScale"
		scale.Parent = Container
		State.Scale[Container] = scale
	end
	scale.Scale = Settings.Scale
end

local CursorState = {
	Active = false,
	MouseBehavior = nil,
	MouseIconEnabled = nil,
	RestoreToken = 0
}

local function RestoreCursor(token, mouseBehavior, mouseIconEnabled)
	if CursorState.RestoreToken ~= token or CursorState.Active then
		return
	end

	if mouseBehavior == Enum.MouseBehavior.LockCenter then
		mouseBehavior = Enum.MouseBehavior.Default
		mouseIconEnabled = true
	end

	InputService.MouseBehavior = mouseBehavior or Enum.MouseBehavior.Default
	if mouseIconEnabled ~= nil then
		InputService.MouseIconEnabled = mouseIconEnabled
	end
end

local function SetCursorFree(enabled)
	enabled = enabled and true or false
	if enabled then
		CursorState.RestoreToken += 1
		if not CursorState.Active then
			CursorState.Active = true
			CursorState.MouseBehavior = InputService.MouseBehavior
			CursorState.MouseIconEnabled = InputService.MouseIconEnabled
		end
		InputService.MouseBehavior = Enum.MouseBehavior.Default
		InputService.MouseIconEnabled = true
		return
	end

	if not CursorState.Active then
		return
	end
	CursorState.RestoreToken += 1
	local token = CursorState.RestoreToken
	local mouseBehavior = CursorState.MouseBehavior
	local mouseIconEnabled = CursorState.MouseIconEnabled
	CursorState.Active = false
	CursorState.MouseBehavior = nil
	CursorState.MouseIconEnabled = nil
	RestoreCursor(token, mouseBehavior, mouseIconEnabled)
	task.defer(function()
		RestoreCursor(token, mouseBehavior, mouseIconEnabled)
	end)
	task.delay(0.05, function()
		RestoreCursor(token, mouseBehavior, mouseIconEnabled)
	end)
end

local ViewmodelState = {
	OldPlayAnimation = nil,
	OldC1 = nil,
	NoBobHooked = false
}

local function ViewmodelBedwars()
	local Bedwars = rawget(getgenv(), "bedwars")
	if type(Bedwars) ~= "table" then
		return nil
	end
	return Bedwars
end

local function ViewmodelControllerScript()
	local playerScripts = LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts")
	local ts = playerScripts and playerScripts:FindFirstChild("TS")
	local controllers = ts and ts:FindFirstChild("controllers")
	local global = controllers and controllers:FindFirstChild("global")
	local viewmodel = global and global:FindFirstChild("viewmodel")
	return viewmodel and viewmodel:FindFirstChild("viewmodel-controller")
end

local function ViewmodelWrist()
	local camera = workspace.CurrentCamera or GameCamera
	local viewmodel = camera and camera:FindFirstChild("Viewmodel")
	local rightHand = viewmodel and viewmodel:FindFirstChild("RightHand")
	return rightHand and rightHand:FindFirstChild("RightWrist")
end

local function RefreshViewmodelStore(Bedwars)
	if Bedwars and Bedwars.InventoryViewmodelController and Bedwars.Store and type(Bedwars.Store.getState) == "function" then
		pcall(function()
			Bedwars.InventoryViewmodelController:handleStore(Bedwars.Store:getState())
		end)
	end
end

local function ApplyViewmodel()
	local Bedwars = ViewmodelBedwars()
	local controllerScript = ViewmodelControllerScript()
	local wrist = ViewmodelWrist()

	if not Settings.Viewmodel then
		if Bedwars and Bedwars.ViewmodelController and ViewmodelState.OldPlayAnimation then
			Bedwars.ViewmodelController.playAnimation = ViewmodelState.OldPlayAnimation
		end
		if wrist and ViewmodelState.OldC1 then
			wrist.C1 = ViewmodelState.OldC1
		end
		if controllerScript then
			controllerScript:SetAttribute("ConstantManager_DEPTH_OFFSET", 0)
			controllerScript:SetAttribute("ConstantManager_HORIZONTAL_OFFSET", 0)
			controllerScript:SetAttribute("ConstantManager_VERTICAL_OFFSET", 0)
		end
		RefreshViewmodelStore(Bedwars)
		ViewmodelState.OldPlayAnimation = nil
		ViewmodelState.OldC1 = nil
		ViewmodelState.NoBobHooked = false
		return
	end

	if wrist and not ViewmodelState.OldC1 then
		ViewmodelState.OldC1 = wrist.C1
	end

	if Bedwars and Bedwars.ViewmodelController then
		if Settings.ViewmodelNoBob and not ViewmodelState.NoBobHooked then
			ViewmodelState.OldPlayAnimation = ViewmodelState.OldPlayAnimation or Bedwars.ViewmodelController.playAnimation
			local old = ViewmodelState.OldPlayAnimation
			Bedwars.ViewmodelController.playAnimation = function(self, animationType, ...)
				if Bedwars.AnimationType and animationType == Bedwars.AnimationType.FP_WALK then
					return
				end
				return old(self, animationType, ...)
			end
			ViewmodelState.NoBobHooked = true
		elseif not Settings.ViewmodelNoBob and ViewmodelState.NoBobHooked and ViewmodelState.OldPlayAnimation then
			Bedwars.ViewmodelController.playAnimation = ViewmodelState.OldPlayAnimation
			ViewmodelState.NoBobHooked = false
		end
	end

	if wrist and ViewmodelState.OldC1 then
		wrist.C1 = ViewmodelState.OldC1 * CFrame.Angles(
			math.rad(Settings.ViewmodelRotationX),
			math.rad(Settings.ViewmodelRotationY),
			math.rad(Settings.ViewmodelRotationZ)
		)
	end
	if controllerScript then
		controllerScript:SetAttribute("ConstantManager_DEPTH_OFFSET", -Settings.ViewmodelDepth)
		controllerScript:SetAttribute("ConstantManager_HORIZONTAL_OFFSET", Settings.ViewmodelHorizontal)
		controllerScript:SetAttribute("ConstantManager_VERTICAL_OFFSET", Settings.ViewmodelVertical)
	end
	RefreshViewmodelStore(Bedwars)
end

local function RestoreViewmodel()
	local wasEnabled = Settings.Viewmodel
	Settings.Viewmodel = false
	ApplyViewmodel()
	Settings.Viewmodel = wasEnabled
end

local function ApplySettings()
	for _, Category in ipairs(TaskAPI.CategoryList) do
		CatScale(Category)
	end
	if Blur then
		Blur.Enabled = ScreenGui.Enabled and Settings.Blur
	end
	ApplyViewmodel()
end

local function SetOpen(open)
	open = open and true or false
	if Settings.Open == open then
		if open and UI.SettingsHolder then
			UI.SettingsHolder.Visible = true
			UI.SettingsHandler.Visible = false
			HandleShape(true)
			TweenGui(UI.SettingsHolder, { Position = SetOpenPos() }, 0.2)
			TweenGui(UI.SettingsHandler, { Position = HandleOpenPos(), Size = UDim2.new(0, 210, 0, 34) }, 0.2)
		elseif not open then
			UI.SettingsHandler.Visible = true
			HandleShape(false)
			TweenGui(UI.SettingsHandler, { Position = HandleClosedPos(), Size = UDim2.new(0, 210, 0, 34) }, 0.2)
		end
		return
	end

	Settings.Open = open
	State.ActDrag = nil
	State.ActSlider = nil
	State.KeyMod = nil
	Fn.HideTip()
	SetCursorFree(ScreenGui.Enabled)
	if open then
		UI.SettingsHolder.Visible = true
		UI.SettingsHandler.Visible = false
	else
		UI.SettingsHandler.Visible = true
	end
	HandleShape(open)
	HideCats(open)
	TweenGui(UI.SettingsHolder, { Position = open and SetOpenPos() or SetClosedPos() }, 0.28)
	TweenGui(UI.SettingsHandler, { Position = open and HandleOpenPos() or HandleClosedPos() }, 0.28)
	TweenGui(UI.SettingsHandler, { Size = UDim2.new(0, 210, 0, 34) }, 0.28)
	if not open then
		task.delay(0.28, function()
			if not Settings.Open and UI.SettingsHolder then
				UI.SettingsHolder.Visible = false
			end
		end)
	end
end

TaskAPI.Settings.SetSettingsOpen = SetOpen
TaskAPI.Settings.ApplySettings = ApplySettings
TaskAPI.Settings.ResetCategoryPositions = ResetCategories

local function SetRow(Name, height)
	local Row = Instance.new("Frame")
	Row.Name = Name
	Row.Size = UDim2.new(1, 0, 0, height or 32)
	Row.BackgroundColor3 = Color.Row
	Row.BackgroundTransparency = 0.04
	Row.BorderSizePixel = 0
	Row.ZIndex = 62
	Row.Parent = UI.SettingsBody

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 7)
	Corner.Parent = Row

	Stroke(Row, 0.72, Color3.fromRGB(52, 52, 52), 1)

	Row.MouseEnter:Connect(function()
		TweenGui(Row, {
			BackgroundColor3 = Color.rowHover,
			BackgroundTransparency = 0
		}, 0.12)
	end)

	Row.MouseLeave:Connect(function()
		TweenGui(Row, {
			BackgroundColor3 = Color.Row,
			BackgroundTransparency = 0.04
		}, 0.12)
	end)

	return Row
end

local function SetLabel(Parent, text)
	local Label = Instance.new("TextLabel")
	Label.Name = "Label"
	Label.Size = UDim2.new(0.5, -12, 1, 0)
	Label.Position = UDim2.new(0, 12, 0, 0)
	Label.BackgroundTransparency = 1
	Label.BorderSizePixel = 0
	Label.Text = text
	Label.TextColor3 = Color.Soft
	Label.TextSize = 12
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextYAlignment = Enum.TextYAlignment.Center
	Label.Font = Enum.Font.GothamBold
	Label.ZIndex = 63
	Label.Parent = Parent
	return Label
end

local function SetToggle(Name, Key)
	local Row = SetRow(Name, 32)
	SetLabel(Row, Name)

	local state = Instance.new("TextButton")
	state.Name = "State"
	state.AnchorPoint = Vector2.new(1, 0.5)
	state.Position = UDim2.new(1, -10, 0.5, 0)
	state.Size = UDim2.new(0, 54, 0, 20)
	state.BackgroundColor3 = Color.Action
	state.BorderSizePixel = 0
	state.AutoButtonColor = false
	state.TextColor3 = Color.text
	state.TextSize = 10
	state.Font = Enum.Font.GothamBold
	state.ZIndex = 63
	state.Parent = Row

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = state

	local function Refresh()
		state.Text = Settings[Key] and "ON" or "OFF"
		state.BackgroundColor3 = Settings[Key] and Color3.fromRGB(55, 55, 55) or Color.Action
	end
	state.MouseButton1Click:Connect(function()
		SetOpt(Key, not Settings[Key])
		Refresh()
		ApplySettings()
		if Key == "CategoryFade" and Settings.Open then
			HideCats(true)
		end
	end)
	Refresh()
	return Row
end

local function SetSlider(Name, Key, min, max, step)
	local Row = SetRow(Name, 42)
	SetLabel(Row, Name)

	local ValueLabel = Instance.new("TextLabel")
	ValueLabel.Name = "Value"
	ValueLabel.AnchorPoint = Vector2.new(1, 0)
	ValueLabel.Position = UDim2.new(1, -12, 0, 4)
	ValueLabel.Size = UDim2.new(0, 58, 0, 18)
	ValueLabel.BackgroundTransparency = 1
	ValueLabel.BorderSizePixel = 0
	ValueLabel.TextColor3 = Color.text
	ValueLabel.TextSize = 11
	ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
	ValueLabel.TextYAlignment = Enum.TextYAlignment.Center
	ValueLabel.Font = Enum.Font.GothamBold
	ValueLabel.ZIndex = 63
	ValueLabel.Parent = Row

	local Track = Instance.new("Frame")
	Track.Name = "Track"
	Track.Size = UDim2.new(1, -24, 0, 4)
	Track.Position = UDim2.new(0, 12, 0, 31)
	Track.BackgroundColor3 = Color.Track
	Track.BorderSizePixel = 0
	Track.ZIndex = 63
	Track.Parent = Row

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color.text
	fill.BorderSizePixel = 0
	fill.ZIndex = 64
	fill.Parent = Track

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 8, 0, 8)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.BackgroundColor3 = Color.text
	knob.BorderSizePixel = 0
	knob.ZIndex = 65
	knob.Parent = Track

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local function SetVal(Value)
		Value = tonumber(Value) or Settings[Key]
		Value = math.clamp(Value, min, max)
		if step and step > 0 then
			Value = math.floor((Value / step) + 0.5) * step
		end
		SetOpt(Key, Value)
		local percent = (Value - min) / math.max(max - min, 0.001)
		fill.Size = UDim2.new(percent, 0, 1, 0)
		knob.Position = UDim2.new(percent, 0, 0.5, 0)
		ValueLabel.Text = string.format("%.2f", Value):gsub("%.?0+$", "")
		ApplySettings()
		if Key == "RainbowSpeed" or tostring(Key):find("Gradient", 1, true) == 1 then
			RefreshGrads()
		end
	end

	Row.InputBegan:Connect(function(Input)
		if not IsPointer(Input) then
			return
		end
		local percent = math.clamp((Input.Position.X - Track.AbsolutePosition.X) / math.max(Track.AbsoluteSize.X, 1), 0, 1)
		SetVal(min + (max - min) * percent)
		State.ActSlider = {
			Track = Track,
			Min = min,
			Max = max,
			SetValue = function(_, Value)
				SetVal(Value)
			end
		}
	end)
	SetVal(Settings[Key])
	return Row
end

local function RgbText(color)
	return ("(%d, %d, %d)"):format(
		math.floor(math.clamp(color.R, 0, 1) * 255 + 0.5),
		math.floor(math.clamp(color.G, 0, 1) * 255 + 0.5),
		math.floor(math.clamp(color.B, 0, 1) * 255 + 0.5)
	)
end

local function ParseRgb(text, fallback)
	local values = {}
	for Value in tostring(text or ""):gmatch("%d+") do
		table.insert(values, tonumber(Value))
		if #values >= 3 then
			break
		end
	end
	if #values < 3 then
		return fallback
	end
	return Color3.fromRGB(
		math.clamp(values[1], 0, 255),
		math.clamp(values[2], 0, 255),
		math.clamp(values[3], 0, 255)
	)
end

local function SetRgb(Label, Key)
	local Row = SetRow(Label, 32)
	SetLabel(Row, Label)

	local Swatch = Instance.new("Frame")
	Swatch.Name = "Swatch"
	Swatch.AnchorPoint = Vector2.new(1, 0.5)
	Swatch.Position = UDim2.new(1, -168, 0.5, 0)
	Swatch.Size = UDim2.new(0, 18, 0, 18)
	Swatch.BackgroundColor3 = Settings[Key]
	Swatch.BorderSizePixel = 0
	Swatch.ZIndex = 63
	Swatch.Parent = Row

	local SwatchCorner = Instance.new("UICorner")
	SwatchCorner.CornerRadius = UDim.new(0, 5)
	SwatchCorner.Parent = Swatch

	local Input = Instance.new("TextBox")
	Input.Name = Key .. "InputService"
	Input.AnchorPoint = Vector2.new(1, 0.5)
	Input.Position = UDim2.new(1, -10, 0.5, 0)
	Input.Size = UDim2.new(0, 148, 0, 20)
	Input.BackgroundColor3 = Color.Action
	Input.BorderSizePixel = 0
	Input.ClearTextOnFocus = false
	Input.PlaceholderText = "(120, 140, 225)"
	Input.Text = RgbText(Settings[Key])
	Input.TextColor3 = Color.text
	Input.PlaceholderColor3 = Color.subtle
	Input.TextSize = 10
	Input.TextXAlignment = Enum.TextXAlignment.Center
	Input.TextYAlignment = Enum.TextYAlignment.Center
	Input.Font = Enum.Font.GothamBold
	Input.ZIndex = 63
	Input.Parent = Row

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = Input

	local function Refresh()
		Swatch.BackgroundColor3 = Settings[Key]
		if not Input:IsFocused() then
			Input.Text = RgbText(Settings[Key])
		end
	end

	Input.FocusLost:Connect(function()
		local color = ParseRgb(Input.Text, Settings[Key])
		SetOpt(Key, color)
		Refresh()
		RefreshGrads()
	end)

	Refresh()
	return Row
end

local function SetButton(Name, callback, actionText)
	local Row = SetRow(Name, 32)
	SetLabel(Row, Name)
	local Action = Instance.new("TextButton")
	Action.Name = "Action"
	Action.AnchorPoint = Vector2.new(1, 0.5)
	Action.Position = UDim2.new(1, -10, 0.5, 0)
	Action.Size = UDim2.new(0, 70, 0, 20)
	Action.BackgroundColor3 = Color.Action
	Action.BorderSizePixel = 0
	Action.AutoButtonColor = false
	Action.Text = actionText or "Run"
	Action.TextColor3 = Color.text
	Action.TextSize = 10
	Action.Font = Enum.Font.GothamBold
	Action.ZIndex = 63
	Action.Parent = Row

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = Action
	Action.MouseButton1Click:Connect(callback)
	return Row
end

local function SetModToggle(Name)
	local Row = SetRow(Name, 32)
	SetLabel(Row, Name)

	local state = Instance.new("TextButton")
	state.Name = "ModuleState"
	state.AnchorPoint = Vector2.new(1, 0.5)
	state.Position = UDim2.new(1, -10, 0.5, 0)
	state.Size = UDim2.new(0, 70, 0, 20)
	state.BackgroundColor3 = Color.Action
	state.BorderSizePixel = 0
	state.AutoButtonColor = false
	state.TextColor3 = Color.text
	state.TextSize = 10
	state.Font = Enum.Font.GothamBold
	state.ZIndex = 63
	state.Parent = Row

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = state

	local Entry = {
		Kind = "Module",
		Name = Name,
		Button = state
	}
	table.insert(State.SetModRows, Entry)

	state.MouseButton1Click:Connect(function()
		local module = TaskAPI.Modules[Name]
		if module and type(module.SetEnabled) == "function" then
			module:SetEnabled(not module.Enabled)
		elseif module and type(module.Toggle) == "function" then
			module:Toggle()
		else
			TaskAPI.Notification("Taskium", Name .. " is still loading.", 2, "Info")
		end
		Fn.MarkSetRows()
	end)
	return Row
end

local function SetFeatureToggle(Name, getter, setter)
	local Row = SetRow(Name, 32)
	SetLabel(Row, Name)

	local state = Instance.new("TextButton")
	state.Name = Name:gsub("%s+", "") .. "State"
	state.AnchorPoint = Vector2.new(1, 0.5)
	state.Position = UDim2.new(1, -10, 0.5, 0)
	state.Size = UDim2.new(0, 70, 0, 20)
	state.BackgroundColor3 = Color.Action
	state.BorderSizePixel = 0
	state.AutoButtonColor = false
	state.TextColor3 = Color.text
	state.TextSize = 10
	state.Font = Enum.Font.GothamBold
	state.ZIndex = 63
	state.Parent = Row

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = state

	local Entry = {
		Kind = "FeatureToggle",
		Name = Name,
		Getter = getter,
		Button = state
	}
	table.insert(State.SetModRows, Entry)

	state.MouseButton1Click:Connect(function()
		setter(not getter())
		Fn.MarkSetRows()
	end)
	return Row
end

local function SetShaderPreset()
	local Row = SetRow("Shader Preset", 32)
	SetLabel(Row, "Shader Preset")

	local Value = Instance.new("TextButton")
	Value.Name = "PresetValue"
	Value.AnchorPoint = Vector2.new(1, 0.5)
	Value.Position = UDim2.new(1, -10, 0.5, 0)
	Value.Size = UDim2.new(0, 120, 0, 20)
	Value.BackgroundColor3 = Color.Action
	Value.BorderSizePixel = 0
	Value.AutoButtonColor = false
	Value.TextColor3 = Color.text
	Value.TextSize = 10
	Value.Font = Enum.Font.GothamBold
	Value.ZIndex = 63
	Value.Parent = Row

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = Value

	local Entry = {
		Kind = "ShaderPreset",
		Button = Value
	}
	table.insert(State.SetModRows, Entry)

	Value.MouseButton1Click:Connect(function()
		local presets = TaskAPI.Settings.ShaderPresets or { "Comet", "Winter", "Calm", "Night", "Sunset", "Cyber", "Emerald", "Crimson", "Fullbright", "Clean" }
		local current = TaskAPI.Settings.GetShaderPreset and TaskAPI.Settings.GetShaderPreset() or TaskAPI.Settings.ShaderPreset or presets[1]
		local index = table.find(presets, current) or 1
		local nextPreset = presets[(index % #presets) + 1]
		TaskAPI.Settings.ShaderPreset = nextPreset
		if type(TaskAPI.Settings.SetShaderPreset) == "function" then
			TaskAPI.Settings.SetShaderPreset(nextPreset)
		end
		Fn.MarkSetRows()
	end)
	return Row
end

local function SetArrayToggle(Label, option)
	local Row = SetRow(Label, 32)
	SetLabel(Row, Label)
	local state = Instance.new("TextButton")
	state.Name = option .. "State"
	state.AnchorPoint = Vector2.new(1, 0.5)
	state.Position = UDim2.new(1, -10, 0.5, 0)
	state.Size = UDim2.new(0, 70, 0, 20)
	state.BackgroundColor3 = Color.Action
	state.BorderSizePixel = 0
	state.AutoButtonColor = false
	state.TextColor3 = Color.text
	state.TextSize = 10
	state.Font = Enum.Font.GothamBold
	state.ZIndex = 63
	state.Parent = Row

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = state

	local Entry = {
		Kind = "ArrayOption",
		Option = option,
		Button = state
	}
	table.insert(State.SetModRows, Entry)

	state.MouseButton1Click:Connect(function()
		ArraySettings[option] = not ArraySettings[option]
		if TaskAPI.Visuals and type(TaskAPI.Visuals.SetArrayListOption) == "function" then
			TaskAPI.Visuals.SetArrayListOption(option, ArraySettings[option])
		end
		Fn.MarkSetRows()
	end)
	return Row
end

local function SetArraySort()
	local Row = SetRow("Array Sort", 32)
	SetLabel(Row, "Array Sort")
	local Value = Instance.new("TextButton")
	Value.Name = "ArraySortValue"
	Value.AnchorPoint = Vector2.new(1, 0.5)
	Value.Position = UDim2.new(1, -10, 0.5, 0)
	Value.Size = UDim2.new(0, 120, 0, 20)
	Value.BackgroundColor3 = Color.Action
	Value.BorderSizePixel = 0
	Value.AutoButtonColor = false
	Value.TextColor3 = Color.text
	Value.TextSize = 10
	Value.Font = Enum.Font.GothamBold
	Value.ZIndex = 63
	Value.Parent = Row

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = Value

	local Entry = {
		Kind = "ArraySort",
		Button = Value
	}
	table.insert(State.SetModRows, Entry)

	Value.MouseButton1Click:Connect(function()
		local nextValue = ArraySettings.Sort == "Length" and "Alphabetical" or "Length"
		if TaskAPI.Visuals and type(TaskAPI.Visuals.SetArrayListOption) == "function" then
			TaskAPI.Visuals.SetArrayListOption("Sort", nextValue)
		else
			ArraySettings.Sort = nextValue
		end
		Fn.MarkSetRows()
	end)
	return Row
end

local function SetArrayDrop(Label, option, list)
	local Row = SetRow(Label, 32)
	SetLabel(Row, Label)
	local Value = Instance.new("TextButton")
	Value.Name = option .. "Value"
	Value.AnchorPoint = Vector2.new(1, 0.5)
	Value.Position = UDim2.new(1, -10, 0.5, 0)
	Value.Size = UDim2.new(0, 120, 0, 20)
	Value.BackgroundColor3 = Color.Action
	Value.BorderSizePixel = 0
	Value.AutoButtonColor = false
	Value.TextColor3 = Color.text
	Value.TextSize = 10
	Value.Font = Enum.Font.GothamBold
	Value.ZIndex = 63
	Value.Parent = Row

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = Value

	local Entry = {
		Kind = "ArrayDropdown",
		Option = option,
		Button = Value
	}
	table.insert(State.SetModRows, Entry)

	Value.MouseButton1Click:Connect(function()
		local current = tostring(ArraySettings[option] or list[1] or "")
		local index = table.find(list, current) or 1
		local nextValue = list[(index % #list) + 1]
		if TaskAPI.Visuals and type(TaskAPI.Visuals.SetArrayListOption) == "function" then
			TaskAPI.Visuals.SetArrayListOption(option, nextValue)
		else
			ArraySettings[option] = nextValue
		end
		Fn.MarkSetRows()
	end)
	return Row
end

local function SetArraySlider(Label, option, min, max, step)
	local Row = SetRow(Label, 42)
	SetLabel(Row, Label)

	local ValueLabel = Instance.new("TextLabel")
	ValueLabel.Name = option .. "Value"
	ValueLabel.AnchorPoint = Vector2.new(1, 0)
	ValueLabel.Position = UDim2.new(1, -12, 0, 4)
	ValueLabel.Size = UDim2.new(0, 58, 0, 18)
	ValueLabel.BackgroundTransparency = 1
	ValueLabel.BorderSizePixel = 0
	ValueLabel.TextColor3 = Color.text
	ValueLabel.TextSize = 11
	ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
	ValueLabel.TextYAlignment = Enum.TextYAlignment.Center
	ValueLabel.Font = Enum.Font.GothamBold
	ValueLabel.ZIndex = 63
	ValueLabel.Parent = Row

	local Track = Instance.new("Frame")
	Track.Name = option .. "Track"
	Track.Size = UDim2.new(1, -24, 0, 4)
	Track.Position = UDim2.new(0, 12, 0, 31)
	Track.BackgroundColor3 = Color.Track
	Track.BorderSizePixel = 0
	Track.ZIndex = 63
	Track.Parent = Row

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color.text
	fill.BorderSizePixel = 0
	fill.ZIndex = 64
	fill.Parent = Track

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 8, 0, 8)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.BackgroundColor3 = Color.text
	knob.BorderSizePixel = 0
	knob.ZIndex = 65
	knob.Parent = Track

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local Entry = {
		Kind = "ArraySlider",
		Option = option,
		Min = min,
		Max = max,
		Step = step,
		Button = ValueLabel,
		Fill = fill,
		Knob = knob
	}
	table.insert(State.SetModRows, Entry)

	local function SetVal(Value)
		Value = math.clamp(tonumber(Value) or ArraySettings[option] or min, min, max)
		if step and step > 0 then
			Value = math.floor((Value / step) + 0.5) * step
		end
		if TaskAPI.Visuals and type(TaskAPI.Visuals.SetArrayListOption) == "function" then
			TaskAPI.Visuals.SetArrayListOption(option, Value)
		else
			ArraySettings[option] = Value
		end
		Fn.MarkSetRows()
	end

	Row.InputBegan:Connect(function(Input)
		if not IsPointer(Input) then
			return
		end
		local percent = math.clamp((Input.Position.X - Track.AbsolutePosition.X) / math.max(Track.AbsoluteSize.X, 1), 0, 1)
		SetVal(min + (max - min) * percent)
		State.ActSlider = {
			Track = Track,
			Min = min,
			Max = max,
			SetValue = function(_, Value)
				SetVal(Value)
			end
		}
	end)
	return Row
end

local function SetArrayBox(Label, option, placeholder)
	local Row = SetRow(Label, 32)
	SetLabel(Row, Label)

	local Input = Instance.new("TextBox")
	Input.Name = option .. "InputService"
	Input.AnchorPoint = Vector2.new(1, 0.5)
	Input.Position = UDim2.new(1, -10, 0.5, 0)
	Input.Size = UDim2.new(0, 150, 0, 20)
	Input.BackgroundColor3 = Color.Action
	Input.BorderSizePixel = 0
	Input.ClearTextOnFocus = false
	Input.PlaceholderText = placeholder or ""
	Input.Text = tostring(ArraySettings[option] or "")
	Input.TextColor3 = Color.text
	Input.PlaceholderColor3 = Color.subtle
	Input.TextSize = 10
	Input.TextXAlignment = Enum.TextXAlignment.Center
	Input.TextYAlignment = Enum.TextYAlignment.Center
	Input.Font = Enum.Font.GothamBold
	Input.ZIndex = 63
	Input.Parent = Row

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = Input

	local Entry = {
		Kind = "ArrayTextBox",
		Option = option,
		InputService = Input
	}
	table.insert(State.SetModRows, Entry)

	Input.FocusLost:Connect(function()
		if TaskAPI.Visuals and type(TaskAPI.Visuals.SetArrayListOption) == "function" then
			TaskAPI.Visuals.SetArrayListOption(option, Input.Text)
		else
			ArraySettings[option] = Input.Text
		end
		Fn.MarkSetRows()
	end)
	return Row
end

Fn.RefreshSetRows = function()
	State.SetRowsDirty = false
	for _, Entry in ipairs(State.SetModRows) do
		if Entry.Kind == "Module" then
			local module = TaskAPI.Modules[Entry.Name]
			if module then
				Entry.Button.Text = module.Enabled and "ON" or "OFF"
				Entry.Button.BackgroundColor3 = module.Enabled and Color3.fromRGB(55, 55, 55) or Color.Action
			else
				Entry.Button.Text = "..."
				Entry.Button.BackgroundColor3 = Color.Action
			end
		elseif Entry.Kind == "FeatureToggle" then
			local enabled = Entry.Getter and Entry.Getter()
			Entry.Button.Text = enabled and "ON" or "OFF"
			Entry.Button.BackgroundColor3 = enabled and Color3.fromRGB(55, 55, 55) or Color.Action
		elseif Entry.Kind == "ShaderPreset" then
			Entry.Button.Text = TaskAPI.Settings.GetShaderPreset and TaskAPI.Settings.GetShaderPreset() or TaskAPI.Settings.ShaderPreset or "Comet"
		elseif Entry.Kind == "ArrayOption" then
			Entry.Button.Text = ArraySettings[Entry.Option] and "ON" or "OFF"
			Entry.Button.BackgroundColor3 = ArraySettings[Entry.Option] and Color3.fromRGB(55, 55, 55) or Color.Action
		elseif Entry.Kind == "ArraySort" then
			Entry.Button.Text = ArraySettings.Sort
		elseif Entry.Kind == "ArrayDropdown" then
			Entry.Button.Text = tostring(ArraySettings[Entry.Option] or "")
		elseif Entry.Kind == "ArraySlider" then
			local Value = tonumber(ArraySettings[Entry.Option]) or Entry.Min
			local percent = math.clamp((Value - Entry.Min) / math.max(Entry.Max - Entry.Min, 0.001), 0, 1)
			Entry.Fill.Size = UDim2.new(percent, 0, 1, 0)
			Entry.Knob.Position = UDim2.new(percent, 0, 0.5, 0)
			Entry.Button.Text = string.format("%.2f", Value):gsub("%.?0+$", "")
		elseif Entry.Kind == "ArrayTextBox" and not Entry.InputService:IsFocused() then
			Entry.InputService.Text = tostring(ArraySettings[Entry.Option] or "")
		end
	end
end

SetFeatureToggle("ArrayList", function()
	return SettingsArrayEnabled
end, function(enabled)
	SetSettingsArrayList(enabled)
end)
SetArraySort()
SetArrayDrop("Array Font", "Font", ArrayFonts)
SetArrayBox("Custom Font", "CustomFont", "font asset/id")
SetArraySlider("Array Scale", "Scale", 0, 2, 0.1)
SetArrayToggle("Array Shadow", "Shadow")
SetArrayToggle("Array Gradient", "Gradient")
SetArrayToggle("Array Animations", "Animations")
SetArrayToggle("Watermark", "Watermark")
SetArrayToggle("Array Background", "Background")
SetArraySlider("Transparency", "Transparency", 0, 1, 0.01)
SetArrayToggle("Array Tint", "Tint")
SetArrayToggle("Hide Render", "HideRender")
SetArrayToggle("Remove Spaces", "RemoveSpaces")
SetArrayToggle("Add Custom Text", "AddCustomText")
SetArrayBox("Custom Text", "CustomText", "text")
SetFeatureToggle("Shaders", function()
	return SettingsShadersEnabled
end, SetSettingsShaders)
SetShaderPreset()
SetSlider("UI Scale", "Scale", 0.75, 1.35, 0.05)
SetToggle("Blur", "Blur")
SetSlider("Gradient Speed", "RainbowSpeed", 0.05, 0.7, 0.05)
SetSlider("Gradient Blend", "GradientBlend", 0, 1, 0.05)
SetSlider("Gradient Lift", "GradientLift", 0, 0.75, 0.05)
SetSlider("Gradient Spread", "GradientSpread", 0.1, 1.5, 0.05)
SetSlider("Gradient Glow", "GradientGlow", 0, 0.35, 0.01)
SetRgb("Gradient Start", "GradientStart")
SetRgb("Gradient End", "GradientEnd")
SetToggle("Viewmodel", "Viewmodel")
SetSlider("Viewmodel Depth", "ViewmodelDepth", 0, 2, 0.1)
SetSlider("Viewmodel Horizontal", "ViewmodelHorizontal", 0, 2, 0.1)
SetSlider("Viewmodel Vertical", "ViewmodelVertical", -0.2, 2, 0.1)
SetSlider("Viewmodel Rotation X", "ViewmodelRotationX", 0, 360, 1)
SetSlider("Viewmodel Rotation Y", "ViewmodelRotationY", 0, 360, 1)
SetSlider("Viewmodel Rotation Z", "ViewmodelRotationZ", 0, 360, 1)
SetToggle("Viewmodel No Bobbing", "ViewmodelNoBob")
SetToggle("Category Fade", "CategoryFade")
SetButton("Reset UI Positions", ResetCategories)
SetButton("Unload", function()
	TaskAPI:Shutdown()
end, "Unload")
Fn.RefreshSetRows()
ApplySettings()
if SettingsShadersEnabled then
	SetSettingsShaders(true)
end

UI.SettingsHandler.InputBegan:Connect(function(Input)
	if not IsPointer(Input) then
		return
	end
	State.SetDrag = {
		StartY = InputY(Input),
		PreviewHidden = false
	}
end)

UI.SettingsHandler.MouseEnter:Connect(function()
	TweenGui(UI.SettingsHandler, { BackgroundColor3 = Color3.fromRGB(8, 8, 8) }, 0.1)
end)

UI.SettingsHandler.MouseLeave:Connect(function()
	TweenGui(UI.SettingsHandler, { BackgroundColor3 = Color.window }, 0.1)
end)

SettingsClose.MouseButton1Click:Connect(function()
	SetOpen(false)
end)

SettingsClose.MouseEnter:Connect(function()
	TweenGui(SettingsClose, { BackgroundColor3 = Color.actionHover }, 0.1)
end)

SettingsClose.MouseLeave:Connect(function()
	TweenGui(SettingsClose, { BackgroundColor3 = Color.Action }, 0.1)
end)

Fn.RefreshCatGrads = function(Category, baseHue)
	if not Category or not Category.ModuleList then
		return
	end

	local visibleModules = {}
	local hasEnabled = false
	for _, module in ipairs(Category.ModuleList) do
		if not module.SettingsOnly and module.Container and module.Container.Visible then
			table.insert(visibleModules, module)
			hasEnabled = hasEnabled or module.Enabled
		end
	end
	if Category.CategoryGradient then
		Category.CategoryGradient.Rotation = 90
		Category.CategoryGradient.Color = StackSeq(0, 1, baseHue)
	end
	if Category.CategoryGradientFrame then
		Category.CategoryGradientFrame.BackgroundColor3 = GradColor(0, baseHue):Lerp(Color3.new(1, 1, 1), math.clamp(Settings.GradientGlow or 0.08, 0, 0.35))
	end
	if Category.CategoryGradientViewport then
		Category.CategoryGradientViewport.Visible = hasEnabled
	end
	if hasEnabled then
		Category.EnabledTextColor = Category.EnabledTextColor or CategoryContrastColor(Category, baseHue)
	else
		Category.EnabledTextColor = nil
	end
	for index, module in ipairs(visibleModules) do
		if module.Button and module.Enabled then
			module.Button.BackgroundTransparency = 1
			local textColor = Category.EnabledTextColor or Color.text
			module.NameLabel.TextColor3 = textColor
			module.KeybindButton.TextColor3 = textColor
			module.ArrowButton.TextColor3 = textColor
		elseif module.Button then
			module.Button.BackgroundTransparency = 0
			module.Button.BackgroundColor3 = Color.module
			module.NameLabel.TextColor3 = Color.text
			module.KeybindButton.TextColor3 = Color.muted
			module.ArrowButton.TextColor3 = Color.muted
		end
	end
end

local function ArrayFont(Name)
	if Name == "Modules" then
		return Font.fromEnum(Enum.Font.GothamBold), Enum.Font.GothamBold
	elseif Name == "Code" then
		return Font.fromEnum(Enum.Font.Code), Enum.Font.Code
	elseif Name == "Custom" then
		local Value = tostring(ArraySettings.CustomFont or "")
		local id = tonumber(Value:match("%d+"))
		if id then
			local Ok, font = pcall(Font.fromId, id)
			if Ok and font then
				return font, Enum.Font.GothamBold
			end
		elseif Value ~= "" then
			local Ok, font = pcall(Font.new, Value:find("rbxasset", 1, true) and Value or ("rbxasset://fonts/families/" .. Value .. ".json"))
			if Ok and font then
				return font, Enum.Font.GothamBold
			end
		end
	end

	for _, enumFont in ipairs(Enum.Font:GetEnumItems()) do
		if enumFont.Name == Name then
			return Font.fromEnum(enumFont), enumFont
		end
	end
	return Font.fromEnum(Enum.Font.GothamBold), Enum.Font.GothamBold
end

local function RefreshArrayFont()
	ArrayFontFace, ArrayEnumFont = ArrayFont(ArraySettings.Font)
end

local function ApplyArrayFont(Label)
	if Label then
		Label.Font = ArrayEnumFont
		Label.FontFace = ArrayFontFace
	end
end

local function ModWidth(text, textSize)
	text = tostring(text or "")
	textSize = textSize or 15
	TextParams.Text = text
	TextParams.Size = textSize
	TextParams.Font = ArrayFontFace
	local Ok, size = pcall(function()
		return Text:GetTextBoundsAsync(TextParams)
	end)
	if Ok and size then
		return math.max(size.X, #text * 8)
	end
	return math.max(Text:GetTextSize(text, textSize, ArrayEnumFont, Vector2.new(1000, 24)).X, #text * 8)
end

local function ArrayName(Name)
	Name = tostring(Name or "")
	if ArraySettings.RemoveSpaces then
		return Name:gsub("%s+", "")
	end
	return Name
end

local function ActiveArray()
	local modules = {}
	for _, module in pairs(TaskAPI.Modules) do
		if type(module) == "table"
			and module.Enabled
			and module.Name ~= "ArrayList"
			and not (ArraySettings.HideRender and module.Category and module.Category.Name == "Render") then
			local displayName = ArrayName(module.Name)
			table.insert(modules, {
				Name = module.Name,
				DisplayName = displayName,
				Length = #displayName,
				Width = ModWidth(displayName)
			})
		end
	end
	table.sort(modules, function(a, b)
		if ArraySettings.Sort == "Alphabetical" then
			return a.DisplayName < b.DisplayName
		end
		if a.Length ~= b.Length then
			return a.Length > b.Length
		end
		if a.Width ~= b.Width then
			return a.Width > b.Width
		end
		return a.DisplayName < b.DisplayName
	end)
	return modules
end

local function EnsureArray()
	if UI.ArrayGui and UI.ArrayGui.Parent then
		return
	end
	RefreshArrayFont()

	UI.ArrayGui = Instance.new("ScreenGui")
	UI.ArrayGui.Name = "TaskArrayList"
	UI.ArrayGui.ResetOnSpawn = false
	UI.ArrayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	UI.ArrayGui.Parent = PlayerGui

	UI.ArrayHolder = Instance.new("Frame")
	UI.ArrayHolder.Name = "Holder"
	UI.ArrayHolder.AnchorPoint = Vector2.new(1, 0)
	UI.ArrayHolder.Position = UDim2.new(1, -10, 0, 8)
	UI.ArrayHolder.Size = UDim2.new(0, 220, 1, -16)
	UI.ArrayHolder.BackgroundTransparency = 1
	UI.ArrayHolder.BorderSizePixel = 0
	UI.ArrayHolder.Parent = UI.ArrayGui

	UI.ArrayScale = Instance.new("UIScale")
	UI.ArrayScale.Scale = ArraySettings.Scale
	UI.ArrayScale.Parent = UI.ArrayHolder

	UI.ArrayWaterHolder = Instance.new("Frame")
	UI.ArrayWaterHolder.Name = "WatermarkHolder"
	UI.ArrayWaterHolder.BackgroundTransparency = 1
	UI.ArrayWaterHolder.BorderSizePixel = 0
	UI.ArrayWaterHolder.ClipsDescendants = false
	UI.ArrayWaterHolder.LayoutOrder = -2
	UI.ArrayWaterHolder.Visible = false
	UI.ArrayWaterHolder.Parent = UI.ArrayHolder

	UI.ArrayWaterShadow = Instance.new("TextLabel")
	UI.ArrayWaterShadow.Name = "WatermarkShadow"
	UI.ArrayWaterShadow.Size = UDim2.fromScale(1, 1)
	UI.ArrayWaterShadow.Position = UDim2.fromOffset(1, 1)
	UI.ArrayWaterShadow.BackgroundTransparency = 1
	UI.ArrayWaterShadow.BorderSizePixel = 0
	UI.ArrayWaterShadow.Text = "Taskium"
	UI.ArrayWaterShadow.TextSize = 18
	UI.ArrayWaterShadow.TextXAlignment = Enum.TextXAlignment.Right
	UI.ArrayWaterShadow.TextYAlignment = Enum.TextYAlignment.Center
	UI.ArrayWaterShadow.Font = Enum.Font.GothamBold
	ApplyArrayFont(UI.ArrayWaterShadow)
	UI.ArrayWaterShadow.TextColor3 = Color3.new()
	UI.ArrayWaterShadow.TextTransparency = 0.45
	UI.ArrayWaterShadow.Visible = false
	UI.ArrayWaterShadow.Parent = UI.ArrayWaterHolder

	UI.ArrayWater = Instance.new("TextLabel")
	UI.ArrayWater.Name = "Watermark"
	UI.ArrayWater.Size = UDim2.fromScale(1, 1)
	UI.ArrayWater.BackgroundTransparency = 1
	UI.ArrayWater.BorderSizePixel = 0
	UI.ArrayWater.Text = "Taskium"
	UI.ArrayWater.TextSize = 18
	UI.ArrayWater.TextXAlignment = Enum.TextXAlignment.Right
	UI.ArrayWater.TextYAlignment = Enum.TextYAlignment.Center
	UI.ArrayWater.Font = Enum.Font.GothamBold
	ApplyArrayFont(UI.ArrayWater)
	UI.ArrayWater.Visible = false
	UI.ArrayWater.Parent = UI.ArrayWaterHolder

	UI.ArrayCustomHolder = Instance.new("Frame")
	UI.ArrayCustomHolder.Name = "CustomTextHolder"
	UI.ArrayCustomHolder.BackgroundTransparency = 1
	UI.ArrayCustomHolder.BorderSizePixel = 0
	UI.ArrayCustomHolder.ClipsDescendants = false
	UI.ArrayCustomHolder.LayoutOrder = -1
	UI.ArrayCustomHolder.Visible = false
	UI.ArrayCustomHolder.Parent = UI.ArrayHolder

	UI.ArrayCustomShadow = Instance.new("TextLabel")
	UI.ArrayCustomShadow.Name = "CustomTextShadow"
	UI.ArrayCustomShadow.Size = UDim2.fromScale(1, 1)
	UI.ArrayCustomShadow.Position = UDim2.fromOffset(1, 1)
	UI.ArrayCustomShadow.BackgroundTransparency = 1
	UI.ArrayCustomShadow.BorderSizePixel = 0
	UI.ArrayCustomShadow.Text = ""
	UI.ArrayCustomShadow.TextSize = 15
	UI.ArrayCustomShadow.TextXAlignment = Enum.TextXAlignment.Right
	UI.ArrayCustomShadow.TextYAlignment = Enum.TextYAlignment.Center
	UI.ArrayCustomShadow.Font = Enum.Font.GothamBold
	ApplyArrayFont(UI.ArrayCustomShadow)
	UI.ArrayCustomShadow.TextColor3 = Color3.new()
	UI.ArrayCustomShadow.TextTransparency = 0.45
	UI.ArrayCustomShadow.Visible = false
	UI.ArrayCustomShadow.Parent = UI.ArrayCustomHolder

	UI.ArrayCustomLabel = Instance.new("TextLabel")
	UI.ArrayCustomLabel.Name = "CustomText"
	UI.ArrayCustomLabel.Size = UDim2.fromScale(1, 1)
	UI.ArrayCustomLabel.BackgroundTransparency = 1
	UI.ArrayCustomLabel.BorderSizePixel = 0
	UI.ArrayCustomLabel.Text = ""
	UI.ArrayCustomLabel.TextSize = 15
	UI.ArrayCustomLabel.TextXAlignment = Enum.TextXAlignment.Right
	UI.ArrayCustomLabel.TextYAlignment = Enum.TextYAlignment.Center
	UI.ArrayCustomLabel.Font = Enum.Font.GothamBold
	ApplyArrayFont(UI.ArrayCustomLabel)
	UI.ArrayCustomLabel.Visible = false
	UI.ArrayCustomLabel.Parent = UI.ArrayCustomHolder

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 0)
	layout.Parent = UI.ArrayHolder
end

local function UpdateCustom()
	if not UI.ArrayHolder then
		return
	end

	RefreshArrayFont()
	ApplyArrayFont(UI.ArrayWaterShadow)
	ApplyArrayFont(UI.ArrayWater)
	ApplyArrayFont(UI.ArrayCustomShadow)
	ApplyArrayFont(UI.ArrayCustomLabel)

	local WatermarkWidth = ModWidth("Taskium", 18) + 12
	if UI.ArrayWaterHolder then
		UI.ArrayWaterHolder.Size = UDim2.new(0, WatermarkWidth, 0, 28)
		UI.ArrayWaterHolder.Visible = ArraySettings.Watermark
	end
	if UI.ArrayWaterShadow then
		UI.ArrayWaterShadow.Visible = ArraySettings.Watermark and ArraySettings.Shadow
	end
	if UI.ArrayWater then
		UI.ArrayWater.Visible = ArraySettings.Watermark
	end

	local text = ArraySettings.CustomText or ""
	local visible = ArraySettings.AddCustomText and text ~= ""
	local size = ModWidth(text, 15)
	if UI.ArrayCustomHolder then
		UI.ArrayCustomHolder.Size = UDim2.new(0, size, 0, 21)
		UI.ArrayCustomHolder.Visible = visible
	end
	if UI.ArrayCustomShadow then
		UI.ArrayCustomShadow.Text = text
		UI.ArrayCustomShadow.Visible = visible and ArraySettings.Shadow
	end
	if UI.ArrayCustomLabel then
		UI.ArrayCustomLabel.Text = text
		UI.ArrayCustomLabel.Visible = visible
	end
	if UI.ArrayScale then
		UI.ArrayScale.Scale = ArraySettings.Scale
	end
end

local function ClearArray()
	for _, Row in ipairs(State.ArrayRows) do
		if Row.Frame then
			Row.Frame:Destroy()
		end
	end
	table.clear(State.ArrayRows)
	State.ArraySig = ""
end

local function RebuildArray(Force)
	if not State.ArrayEnabled then
		return
	end
	if not Force and not State.ArrayDirty then
		return
	end

	EnsureArray()
	local modules = ActiveArray()
	local names = {}
	for _, module in ipairs(modules) do
		table.insert(names, module.DisplayName)
	end
	local signature = table.concat(names, "\n")
		.. "|" .. tostring(ArraySettings.Sort)
		.. "|" .. tostring(ArraySettings.Scale)
		.. "|" .. tostring(ArraySettings.Font)
		.. "|" .. tostring(ArraySettings.CustomFont)
		.. "|" .. tostring(ArraySettings.Shadow)
		.. "|" .. tostring(ArraySettings.Gradient)
		.. "|" .. tostring(ArraySettings.Animations)
		.. "|" .. tostring(ArraySettings.Background)
		.. "|" .. tostring(ArraySettings.Transparency)
		.. "|" .. tostring(ArraySettings.Tint)
		.. "|" .. tostring(ArraySettings.HideRender)
		.. "|" .. tostring(ArraySettings.RemoveSpaces)
		.. "|" .. tostring(ArraySettings.AddCustomText)
		.. "|" .. tostring(ArraySettings.CustomText)
	if not Force and signature == State.ArraySig then
		State.ArrayDirty = false
		return
	end

	ClearArray()
	State.ArraySig = signature
	State.ArrayDirty = false
	UpdateCustom()

	for index, module in ipairs(modules) do
		local rowHeight = 21
		local rowWidth = module.Width + 7
		local displayName = module.DisplayName or module.Name
		local Row = Instance.new("Frame")
		Row.Name = module.Name
		Row.Size = UDim2.new(0, 0, 0, rowHeight)
		Row.BackgroundTransparency = 1
		Row.BorderSizePixel = 0
		Row.LayoutOrder = index
		Row.ClipsDescendants = true
		Row.Parent = UI.ArrayHolder
		local targetSize = UDim2.new(0, rowWidth, 0, rowHeight)

		local background = Instance.new("Frame")
		background.Name = "Background"
		background.Size = UDim2.fromScale(1, 1)
		background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		background.BackgroundTransparency = ArraySettings.Background and ArraySettings.Transparency or 1
		background.BorderSizePixel = 0
		background.Parent = Row

		local bottomLine = Instance.new("Frame")
		bottomLine.Name = "BottomLine"
		bottomLine.Size = UDim2.new(1, 0, 0, 1)
		bottomLine.Position = UDim2.new(0, 0, 1, -1)
		bottomLine.BackgroundColor3 = Color3.new()
		bottomLine.BackgroundTransparency = 1
		bottomLine.BorderSizePixel = 0
		bottomLine.Parent = background

		local topLine = bottomLine:Clone()
		topLine.Name = "Line"
		topLine.Position = UDim2.new()
		topLine.Parent = background

		local accent = Instance.new("Frame")
		accent.Name = "Accent"
		accent.AnchorPoint = Vector2.new(1, 0)
		accent.Position = UDim2.new(1, 0, 0, 0)
		accent.Size = UDim2.new(0, 2, 1, 0)
		accent.BorderSizePixel = 0
		accent.Visible = ArraySettings.Background
		accent.Parent = background

		local shadow = Instance.new("TextLabel")
		shadow.Name = "Shadow"
		shadow.Size = UDim2.new(1, -5, 1, 0)
		shadow.Position = UDim2.fromOffset(1, 3)
		shadow.BackgroundTransparency = 1
		shadow.BorderSizePixel = 0
		shadow.Text = displayName
		shadow.TextSize = 15
		shadow.TextXAlignment = Enum.TextXAlignment.Right
		shadow.TextYAlignment = Enum.TextYAlignment.Center
		shadow.Font = Enum.Font.GothamBold
		ApplyArrayFont(shadow)
		shadow.TextColor3 = Color3.new()
		shadow.TextTransparency = 0.45
		shadow.Visible = ArraySettings.Shadow
		shadow.Parent = Row

		local Label = Instance.new("TextLabel")
		Label.Name = "Text"
		Label.Size = UDim2.new(1, -5, 1, 0)
		Label.Position = UDim2.fromOffset(0, 2)
		Label.BackgroundTransparency = 1
		Label.BorderSizePixel = 0
		Label.Text = displayName
		Label.TextSize = 15
		Label.TextXAlignment = Enum.TextXAlignment.Right
		Label.TextYAlignment = Enum.TextYAlignment.Center
		Label.Font = Enum.Font.GothamBold
		ApplyArrayFont(Label)
		Label.TextColor3 = Color.text
		Label.Parent = Row

		table.insert(State.ArrayRows, {
			Frame = Row,
			Text = Label,
			Shadow = shadow,
			Background = background,
			Accent = accent
		})

		if ArraySettings.Animations and State.Ready then
			TweenGui(Row, { Size = targetSize }, 0.3)
		else
			Row.Size = targetSize
		end
	end

	for index, Row in ipairs(State.ArrayRows) do
		if Row.Accent and Row.Accent.Parent and Row.Accent.Parent:FindFirstChild("Line") then
			Row.Accent.Parent.Line.Visible = false
		end
	end
end

Fn.UpdateArrayColors = function(baseHue)
	if not State.ArrayEnabled then
		return
	end

	local rowCount = #State.ArrayRows
	for index, Row in ipairs(State.ArrayRows) do
		local color = ArraySettings.Gradient
			and StackColor(index - 1, rowCount, baseHue)
			or GradColor((index + 2) * -0.045, baseHue)
		if Row.Text then
			Row.Text.TextColor3 = color
		end
		if Row.Accent then
			Row.Accent.BackgroundColor3 = color
			Row.Accent.Visible = ArraySettings.Background
		end
		if Row.Background then
			Row.Background.BackgroundTransparency = ArraySettings.Background and ArraySettings.Transparency or 1
			local line = Row.Background:FindFirstChild("Line")
			if line then
				line.Visible = false
			end
			local bottomLine = Row.Background:FindFirstChild("BottomLine")
			if bottomLine then
				bottomLine.Visible = false
			end
		end
		if Row.Background and ArraySettings.Background and ArraySettings.Tint then
			local h, s, v = color:ToHSV()
			Row.Background.BackgroundColor3 = Color3.fromHSV(h, s, math.clamp(v - 0.75, 0, 1))
		elseif Row.Background then
			Row.Background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		end
	end
	if UI.ArrayCustomLabel then
		UI.ArrayCustomLabel.TextColor3 = GradColor(-0.12, baseHue)
	end
	if UI.ArrayWater then
		UI.ArrayWater.TextColor3 = GradColor(0, baseHue)
	end
end

function TaskAPI.Visuals.SetArrayListEnabled(enabled)
	State.ArrayEnabled = enabled and true or false
	if State.ArrayEnabled then
		State.ArrayDirty = true
		RebuildArray(true)
		Fn.UpdateArrayColors()
	else
		ClearArray()
		if UI.ArrayGui then
			UI.ArrayGui:Destroy()
			UI.ArrayGui = nil
			UI.ArrayHolder = nil
			UI.ArrayScale = nil
			UI.ArrayWaterHolder = nil
			UI.ArrayWater = nil
			UI.ArrayWaterShadow = nil
			UI.ArrayCustomHolder = nil
			UI.ArrayCustomLabel = nil
			UI.ArrayCustomShadow = nil
		end
	end
end

SetSettingsArrayList = function(enabled)
	SettingsArrayEnabled = enabled and true or false
	SetCfg("Settings", "ArrayList", SettingsArrayEnabled)
	TaskAPI.Visuals.SetArrayListEnabled(SettingsArrayEnabled)
end
if SettingsArrayEnabled then
	SetSettingsArrayList(true)
end

function TaskAPI.Visuals.RefreshArrayList()
	State.ArrayDirty = true
	RebuildArray()
	Fn.UpdateArrayColors()
end

function TaskAPI.Visuals.SetArrayListOption(Name, Value)
	if ArraySettings[Name] == nil then
		return
	end
	if Name == "Scale" then
		Value = math.clamp(tonumber(Value) or 1, 0, 2)
	elseif Name == "Transparency" then
		Value = math.clamp(tonumber(Value) or 0.18, 0, 1)
	elseif Name ~= "Sort" and Name ~= "CustomText" and Name ~= "Font" and Name ~= "CustomFont" then
		Value = Value and true or false
	end

	ArraySettings[Name] = Value
	SetCfg("ArrayList", Name, Value)
	Fn.MarkSetRows()
	if Name == "Font" or Name == "CustomFont" then
		RefreshArrayFont()
	end
	State.ArrayDirty = true
	if UI.ArrayScale then
		UI.ArrayScale.Scale = ArraySettings.Scale
	end
	UpdateCustom()
	RebuildArray(true)
	Fn.UpdateArrayColors()
end

local function RefreshModule(module)
	if module.SettingsOnly then
		module.Container.Visible = false
		module.Container.Size = UDim2.new(1, 0, 0, 0)
	end
	Fn.RefreshCatGrads(module.Category)
	TweenGui(module.Button, {
		BackgroundColor3 = Color.module,
		BackgroundTransparency = module.Enabled and 1 or 0
	}, 0.12)
	if module.Enabled then
		module.Category.EnabledTextColor = module.Category.EnabledTextColor or CategoryContrastColor(module.Category)
	else
		local hasEnabled = false
		for _, other in ipairs(module.Category.ModuleList or {}) do
			hasEnabled = hasEnabled or other.Enabled
		end
		if not hasEnabled then
			module.Category.EnabledTextColor = nil
		end
	end
	local enabledText = module.Category.EnabledTextColor or Color.text
	module.NameLabel.TextColor3 = module.Enabled and enabledText or Color.text
	module.KeybindButton.TextColor3 = module.Enabled and enabledText or Color.muted
	module.KeybindButton.Text = module.WaitingForKeybind and "..." or (module.Keybind or "None")
	module.ArrowButton.Text = module.Expanded and "v" or ">"
	module.ArrowButton.TextColor3 = module.Enabled and enabledText or Color.muted
	module.ArrowButton.Visible = (#module.ToggleList + #module.ButtonList + #module.SliderList + #module.DropdownList + #module.TextBoxList) > 0
end

local function Clipboard()
	return setclipboard or toclipboard or set_clipboard or clipboard_set
end

local function NotifyData(title, message, duration, notifType)
	if type(title) == "table" then
		return {
			Title = tostring(title.Title or title.Name or "Notification"),
			Message = tostring(title.Message or title.Text or ""),
			Duration = tonumber(title.Duration or title.Time) or 3,
			Type = title.Type or title.NotificationType or "Client",
			CopyText = title.CopyText,
			ClickToCopy = title.ClickToCopy == true
		}
	end

	return {
		Title = tostring(title or "Notification"),
		Message = tostring(message or ""),
		Duration = tonumber(duration) or 3,
		Type = notifType or "Client",
		CopyText = nil,
		ClickToCopy = false
	}
end

function TaskAPI.Notification(title, message, duration, notifType)
	local data = NotifyData(title, message, duration, notifType)

	local holder = Instance.new("Frame")
	holder.Name = "NotificationHolder"
	holder.Size = UDim2.new(0, 270, 0, 46)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = false
	holder.LayoutOrder = #TaskAPI.Notifications + 1
	holder.Parent = NotifFrame

	local frame = Instance.new("Frame")
	frame.Name = "NotificationFrame"
	frame.Size = UDim2.new(0, 270, 0, 46)
	frame.Position = UDim2.new(1, 0, 0, 0)
	frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.ZIndex = 10
	frame.Parent = holder

	local frameCorner = Instance.new("UICorner")
	frameCorner.TopLeftRadius = UDim.new(0, 8)
	frameCorner.TopRightRadius = UDim.new(0, 0)
	frameCorner.BottomLeftRadius = UDim.new(0, 8)
	frameCorner.BottomRightRadius = UDim.new(0, 0)
	frameCorner.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "NotificationTitle"
	titleLabel.Size = UDim2.new(1, -28, 0, 17)
	titleLabel.Position = UDim2.new(0, 14, 0, 7)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = data.Title
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = Color.text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.ZIndex = 11
	titleLabel.Parent = frame

	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "MessageText"
	messageLabel.Size = UDim2.new(1, -28, 0, 16)
	messageLabel.Position = UDim2.new(0, 14, 0, 24)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = data.Message
	messageLabel.TextSize = 12
	messageLabel.TextColor3 = Color.text
	messageLabel.TextWrapped = true
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextYAlignment = Enum.TextYAlignment.Top
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.ZIndex = 11
	messageLabel.Parent = frame

	local clickButton = Instance.new("TextButton")
	clickButton.Name = "ClickArea"
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.BackgroundTransparency = 1
	clickButton.BorderSizePixel = 0
	clickButton.AutoButtonColor = false
	clickButton.Text = ""
	clickButton.ZIndex = 12
	clickButton.Active = data.ClickToCopy
	clickButton.Visible = data.ClickToCopy
	clickButton.Parent = frame

	if data.ClickToCopy then
		clickButton.MouseButton1Click:Connect(function()
			local setter = Clipboard()
			if setter then
				setter(tostring(data.CopyText or data.Message))
			end
		end)
	end

	table.insert(TaskAPI.Notifications, holder)

	Tween:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	}):Play()

	task.spawn(function()
		task.wait(data.Duration)
		local out = Tween:Create(frame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 0, 0, 0)
		})
		out:Play()
		out.Completed:Wait()
		local index = table.find(TaskAPI.Notifications, holder)
		if index then
			table.remove(TaskAPI.Notifications, index)
		end
		holder:Destroy()
	end)

	return holder
end

function TaskAPI:Notify(data)
	return TaskAPI.Notification(data)
end

local function RegisterBuiltIns(Category)
	if not Category or Category.Name ~= "Render" or BuiltIns.Render then
		return
	end
	BuiltIns.Render = true
end

function TaskAPI:CreateCategory(CategoryData)
	CategoryData = CategoryData or {}
	if type(CategoryData.Name) ~= "string" or CategoryData.Name == "" then
		error("TaskAPI:CreateCategory requires a Category Name")
	end
	if self.Categories[CategoryData.Name] then
		error(("TaskAPI Category '%s' already exists"):format(CategoryData.Name))
	end

	local categoryPosition = CategoryData.Position or UDim2.new(0, 0, 0, 0)
	local categoryAnchor = CategoryData.AnchorPoint or Vector2.new(0, 0)
	local defaultSize = CategoryData.Size or UDim2.new(0, UiSize.CategoryWidth, 0, UiSize.CategoryMinHeight)

	local Container = Instance.new("Frame")
	Container.Name = "CategoryContainer_" .. CategoryData.Name
	Container.Size = defaultSize
	Container.AnchorPoint = categoryAnchor
	Container.Position = categoryPosition
	Container.BackgroundTransparency = 1
	Container.BorderSizePixel = 0
	Container.ClipsDescendants = false
	Container.ZIndex = 1
	Container.Parent = ScreenGui

	local categoryShadow = Instance.new("Frame")
	categoryShadow.Name = "CategoryShadow"
	categoryShadow.Size = defaultSize
	categoryShadow.BackgroundColor3 = Color.window
	categoryShadow.BackgroundTransparency = 0.99
	categoryShadow.BorderSizePixel = 0
	categoryShadow.ZIndex = 1
	categoryShadow.Parent = Container

	local categoryShadowCorner = Instance.new("UICorner")
	categoryShadowCorner.TopLeftRadius = UDim.new(0, UiSize.CategoryCorner)
	categoryShadowCorner.TopRightRadius = UDim.new(0, UiSize.CategoryCorner)
	categoryShadowCorner.BottomLeftRadius = UDim.new(0, UiSize.CategoryCorner)
	categoryShadowCorner.BottomRightRadius = UDim.new(0, UiSize.CategoryCorner)
	categoryShadowCorner.Parent = categoryShadow

	local main = Instance.new("Frame")
	main.Name = "MainFrame_" .. CategoryData.Name
	main.Size = defaultSize
	main.BackgroundColor3 = CategoryData.BackgroundColor3 or Color.window
	main.BorderSizePixel = 0
	main.ClipsDescendants = true
	main.ZIndex = 2
	main.Parent = Container

	local mainCorner = Instance.new("UICorner")
	mainCorner.TopLeftRadius = UDim.new(0, UiSize.CategoryCorner)
	mainCorner.TopRightRadius = UDim.new(0, UiSize.CategoryCorner)
	mainCorner.BottomLeftRadius = UDim.new(0, UiSize.CategoryCorner)
	mainCorner.BottomRightRadius = UDim.new(0, UiSize.CategoryCorner)
	mainCorner.Parent = main

	local header = Instance.new("Frame")
	header.Name = "CategoryFrame"
	header.Size = UDim2.new(1, 0, 0, UiSize.CategoryHeader)
	header.Active = true
	header.BackgroundColor3 = Color.header
	header.BorderSizePixel = 0
	header.ZIndex = 3
	header.Parent = main

	local headerCorner = Instance.new("UICorner")
	headerCorner.TopLeftRadius = UDim.new(0, UiSize.CategoryCorner)
	headerCorner.TopRightRadius = UDim.new(0, UiSize.CategoryCorner)
	headerCorner.BottomLeftRadius = UDim.new(0, 0)
	headerCorner.BottomRightRadius = UDim.new(0, 0)
	headerCorner.Parent = header

	local headerText = Instance.new("TextLabel")
	headerText.Name = "CategoryText"
	headerText.Size = UDim2.new(1, 0, 1, 0)
	headerText.BackgroundTransparency = 1
	headerText.Text = CategoryData.Name
	headerText.TextSize = 16
	headerText.TextColor3 = Color.text
	headerText.TextXAlignment = Enum.TextXAlignment.Center
	headerText.TextYAlignment = Enum.TextYAlignment.Center
	headerText.Font = Enum.Font.GothamBold
	headerText.ZIndex = 4
	headerText.Parent = header

	local holder = Instance.new("ScrollingFrame")
	holder.Name = "ModulesHolder"
	holder.Size = UDim2.new(1, 0, 1, -UiSize.CategoryHeader)
	holder.Position = UDim2.new(0, 0, 0, UiSize.CategoryHeader)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.CanvasSize = UDim2.new(0, 0, 0, 0)
	holder.ScrollBarThickness = 0
	holder.ScrollBarImageTransparency = 1
	holder.ScrollingDirection = Enum.ScrollingDirection.Y
	holder.ZIndex = 4
	holder.Parent = main

	local categoryGradientViewport = Instance.new("Frame")
	categoryGradientViewport.Name = "CategoryGradientViewport"
	categoryGradientViewport.Size = holder.Size
	categoryGradientViewport.Position = holder.Position
	categoryGradientViewport.BackgroundTransparency = 1
	categoryGradientViewport.BorderSizePixel = 0
	categoryGradientViewport.ClipsDescendants = true
	categoryGradientViewport.ZIndex = 3
	categoryGradientViewport.Parent = main

	local categoryGradientFrame = Instance.new("Frame")
	categoryGradientFrame.Name = "CategoryGradientFrame"
	categoryGradientFrame.Size = UDim2.new(1, 0, 0, 0)
	categoryGradientFrame.Position = UDim2.new(0, 0, 0, 0)
	categoryGradientFrame.BackgroundColor3 = SharedModuleGradient.gradientAt(0, GradStartColor(), GradEndColor(), GradOpts())
	categoryGradientFrame.BorderSizePixel = 0
	categoryGradientFrame.ZIndex = 3
	categoryGradientFrame.Parent = categoryGradientViewport

	local categoryGradient = Instance.new("UIGradient")
	categoryGradient.Name = "CategoryGradient"
	categoryGradient.Rotation = 90
	categoryGradient.Color = StackSeq(0, 1)
	categoryGradient.Parent = categoryGradientFrame

	local holderLayout = Instance.new("UIListLayout")
	holderLayout.SortOrder = Enum.SortOrder.LayoutOrder
	holderLayout.Padding = UDim.new(0, 0)
	holderLayout.Parent = holder

	local Category = {
		Name = CategoryData.Name,
		Position = categoryPosition,
		AnchorPoint = categoryAnchor,
		DefaultSize = defaultSize,
		MaxHeight = CategoryData.MaxHeight or 285,
		ContainerFrame = Container,
		MainFrame = main,
		TaskFrame = Container,
		CategoryShadow = categoryShadow,
		CategoryFrame = header,
		CategoryLabel = headerText,
		ModulesHolder = holder,
		CategoryGradientViewport = categoryGradientViewport,
		CategoryGradientFrame = categoryGradientFrame,
		CategoryGradient = categoryGradient,
		ModulesLayout = holderLayout,
		ModuleList = {},
		Modules = {}
	}

	holderLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		CategorySize(Category)
	end)

	table.insert(TaskAPI.Connections, holder:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		categoryGradientFrame.Position = UDim2.new(0, 0, 0, -holder.CanvasPosition.Y)
	end))

	header.InputBegan:Connect(function(Input)
		if Settings.Open or Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		State.ActDrag = {
			Category = Category,
			ContainerFrame = Container,
			DragStart = Input.Position,
			StartPosition = Container.Position
		}
	end)

	function Category:CreateModule(ModuleData)
		ModuleData = ModuleData or {}
		if type(ModuleData.Name) ~= "string" or ModuleData.Name == "" then
			error(("TaskAPI Category '%s' requires a valid Module Name"):format(self.Name))
		end
		if self.Modules[ModuleData.Name] then
			error(("Module '%s' already exists in Category '%s'"):format(ModuleData.Name, self.Name))
		end
		local settingsOnly = ModuleData.SettingsOnly or ModuleData.SettingsMenu or ModuleData.HideInCategory

		local moduleContainer = Instance.new("Frame")
		moduleContainer.Name = ModuleData.Name .. "_Container"
		moduleContainer.Size = UDim2.new(1, 0, 0, settingsOnly and 0 or UiSize.ModuleHeight)
		moduleContainer.BackgroundTransparency = 1
		moduleContainer.BorderSizePixel = 0
		moduleContainer.ClipsDescendants = true
		moduleContainer.Visible = not settingsOnly
		moduleContainer.ZIndex = 4
		moduleContainer.Parent = holder

		local moduleButton = Instance.new("TextButton")
		moduleButton.Name = ModuleData.Name
		moduleButton.Size = UDim2.new(1, 0, 0, UiSize.ModuleHeight)
		moduleButton.BackgroundColor3 = Color.module
		moduleButton.BorderSizePixel = 0
		moduleButton.AutoButtonColor = false
		moduleButton.Text = ""
		moduleButton.ZIndex = 4
		moduleButton.Parent = moduleContainer

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ModuleName"
		nameLabel.Size = UDim2.new(1, -75, 1, 0)
		nameLabel.Position = UDim2.new(0, 8, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = ModuleData.Name
		nameLabel.TextSize = UiSize.ModuleText
		nameLabel.TextColor3 = Color.text
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextYAlignment = Enum.TextYAlignment.Center
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.ZIndex = 5
		nameLabel.Parent = moduleButton

		local keybindButton = Instance.new("TextButton")
		keybindButton.Name = "KeybindButton"
		keybindButton.Size = UDim2.new(0, 50, 1, 0)
		keybindButton.AnchorPoint = Vector2.new(1, 0)
		keybindButton.Position = UDim2.new(1, -28, 0, 0)
		keybindButton.BackgroundTransparency = 1
		keybindButton.AutoButtonColor = false
		keybindButton.Text = "None"
		keybindButton.TextSize = UiSize.KeybindText
		keybindButton.TextColor3 = Color.muted
		keybindButton.TextXAlignment = Enum.TextXAlignment.Right
		keybindButton.TextYAlignment = Enum.TextYAlignment.Center
		keybindButton.Font = Enum.Font.Gotham
		keybindButton.ZIndex = 6
		keybindButton.Parent = moduleButton

		local arrowButton = Instance.new("TextButton")
		arrowButton.Name = "ExpandArrow"
		arrowButton.Size = UDim2.new(0, 16, 1, 0)
		arrowButton.AnchorPoint = Vector2.new(1, 0)
		arrowButton.Position = UDim2.new(1, -6, 0, 0)
		arrowButton.BackgroundTransparency = 1
		arrowButton.AutoButtonColor = false
		arrowButton.Text = ">"
		arrowButton.TextSize = 14
		arrowButton.TextColor3 = Color.muted
		arrowButton.Font = Enum.Font.GothamBold
		arrowButton.Visible = false
		arrowButton.ZIndex = 6
		arrowButton.Parent = moduleButton

		local optionsHolder = Instance.new("Frame")
		optionsHolder.Name = "OptionsHolder"
		optionsHolder.Size = UDim2.new(1, 0, 0, 0)
		optionsHolder.Position = UDim2.new(0, 0, 0, UiSize.ModuleHeight)
		optionsHolder.BackgroundTransparency = 1
		optionsHolder.BorderSizePixel = 0
		optionsHolder.ClipsDescendants = true
		optionsHolder.ZIndex = 4
		optionsHolder.Parent = moduleContainer

		local optionsLayout = Instance.new("UIListLayout")
		optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		optionsLayout.Padding = UDim.new(0, 0)
		optionsLayout.Parent = optionsHolder

		local module = {
			Name = ModuleData.Name,
			ConfigKey = CfgKey(self.Name, ModuleData.Name),
			Enabled = false,
			Expanded = false,
			RunId = 0,
			Function = ModuleData.Function,
			ToolTip = ModuleData.ToolTip or ModuleData.Tooltip,
			SettingsOnly = settingsOnly and true or false,
			BaseHeight = settingsOnly and 0 or UiSize.ModuleHeight,
			TargetHeight = settingsOnly and 0 or UiSize.ModuleHeight,
			Container = moduleContainer,
			Button = moduleButton,
			Gradient = nil,
			NameLabel = nameLabel,
			KeybindButton = keybindButton,
			ArrowButton = arrowButton,
			OptionsHolder = optionsHolder,
			OptionsLayout = optionsLayout,
			ToggleList = {},
			Toggles = {},
			ButtonList = {},
			Buttons = {},
			SliderList = {},
			Sliders = {},
			DropdownList = {},
			Dropdowns = {},
			TextBoxList = {},
			TextBoxes = {},
			HotbarListList = {},
			HotbarLists = {},
			ControlList = {},
			LastControl = nil,
			LastParentControl = nil,
			Category = self,
			Cleanups = {},
			Keybind = nil,
			WaitingForKeybind = false
		}
		function module:Clean(item)
			table.insert(self.Cleanups, item)
			return item
		end

		function module:Cleanup()
			for index = #self.Cleanups, 1, -1 do
				Clean(self.Cleanups[index])
				self.Cleanups[index] = nil
			end
		end

		function module:IsActive(runId)
			return self.Enabled and self.RunId == runId
		end

		function module:SetEnabled(Value, Options)
			Options = Options or {}
			Value = Value and true or false
			if self.Enabled == Value and not Options.Force then
				return self.Enabled
			end

			if not Value then
				self:Cleanup()
			end

			self.Enabled = Value
			self.RunId += 1
			local runId = self.RunId
			RefreshModule(self)

			if not Options.SkipConfig then
				SetCfg("Module", self.ConfigKey, self.Enabled)
			end
			if not Options.SkipNotify then
				TaskAPI.Notification("Taskium", self.Name .. (self.Enabled and " enabled." or " disabled."), 2, self.Enabled and "Success" or "Info")
			end
			if TaskAPI.Visuals and type(TaskAPI.Visuals.RefreshArrayList) == "function" then
				TaskAPI.Visuals.RefreshArrayList()
			end
			if Fn.RefreshSetRows then
				Fn.MarkSetRows()
			end

			task.spawn(function()
				RunCb("Module", self.Name, self.Function, self.Enabled, runId, self)
				if self.Enabled and self.RunId == runId and self.Function == nil then
					self:SetEnabled(false, { SkipConfig = true, SkipNotify = true })
				end
			end)

			return self.Enabled
		end

		function module:Toggle(Options)
			return self:SetEnabled(not self.Enabled, Options)
		end

		function module:SetKeybind(KeyName, Options)
			Options = Options or {}
			if KeyName ~= nil then
				local KeyCode = KeyCode(KeyName)
				if KeyCode then
					KeyName = KeyCode.Name
				else
					KeyName = nil
				end
			end

			if KeyName and not Options.AllowReserved then
				local denied, message = Reserved(self, KeyName)
				if denied then
					self.WaitingForKeybind = false
					RefreshModule(self)
					TaskAPI.Notification("Taskium", message, 4, "Warning")
					return self.Keybind
				end
			end

			self.Keybind = KeyName
			self.WaitingForKeybind = false
			if not Options.SkipConfig then
				SetCfg("Keybind", self.ConfigKey, self.Keybind)
			end
			RefreshModule(self)
			return self.Keybind
		end

		function module:BeginKeybindCapture()
			self.WaitingForKeybind = true
			RefreshModule(self)
		end

		function module:WatchControl(control)
			if control and control.Object and control.Object.GetPropertyChangedSignal then
				control.Object:GetPropertyChangedSignal("Visible"):Connect(function()
					ModuleLayout(self)
					CategorySize(self.Category)
				end)
			end
			return control
		end

		function module:ControlActive(control)
			if not control then
				return true
			end
			if control.Value ~= nil then
				return control.Value and true or false
			end
			if control.Enabled ~= nil then
				return control.Enabled and true or false
			end
			if control.Open ~= nil then
				return control.Open and true or false
			end
			return true
		end

		function module:ControlMatches(child, parent)
			if not parent then
				return true
			end
			if child.ParentCondition then
				local ok, result = pcall(child.ParentCondition, parent.Value, parent, child)
				return ok and result == true
			end
			local parentValue = child.ParentValue
			if parentValue ~= nil then
				if type(parentValue) == "table" then
					return table.find(parentValue, parent.Value) ~= nil
				end
				return parent.Value == parentValue
			end
			return self:ControlActive(parent)
		end

		function module:RefreshControlChildren(control, parentVisible)
			if not control or not control.Children then
				return
			end
			for _, child in ipairs(control.Children) do
				local active = parentVisible ~= false and self:ControlMatches(child, control)
				if child.Object then
					child.Object.Visible = active and child.BaseVisible ~= false
				end
				self:RefreshControlChildren(child, active)
			end
		end

		function module:RegisterControl(control, data, isParent)
			data = data or {}
			control.Children = control.Children or {}
			local parent = data.Parent or data.ParentControl or data.DependsOn or data.Dependency
			if type(parent) == "string" then
				parent = self.Toggles[parent] or self.Dropdowns[parent] or self.Sliders[parent] or self.TextBoxes[parent] or self.Buttons[parent]
			end
			if not parent
				and self.LastParentControl
				and self.LastParentControl.Type == "Toggle"
				and (data.Darker or data.SubOption or data.Sub or data.Child or data.Visible == false) then
				parent = self.LastParentControl
			end
			control.BaseVisible = parent and true or (data.Visible == nil or data.Visible)
			control.ParentValue = data.ParentValue or data.ParentValues
			control.ParentCondition = data.ParentCondition or data.Condition
			control.ParentControl = parent
			if parent then
				parent.Children = parent.Children or {}
				table.insert(parent.Children, control)
			else
				self.LastParentControl = isParent and control or self.LastParentControl
			end
			table.insert(self.ControlList, control)
			control.Object.LayoutOrder = #self.ControlList
			self.LastControl = control
			if isParent then
				self.LastParentControl = control
			end
			self:WatchControl(control)
			if parent then
				self:RefreshControlChildren(parent)
			elseif control.Object then
				control.Object.Visible = control.BaseVisible ~= false
			end
			return control
		end

		function module:CreateToggle(data)
			data = data or {}
			local Default = data.Default == true or data.DefaultValue == true

			local Row = Instance.new("TextButton")
			Row.Name = data.Name
			Row.Size = UDim2.new(1, 0, 0, UiSize.RowHeight)
			Row.Visible = data.Visible == nil or data.Visible
			Row.BackgroundColor3 = Color.Row
			Row.BorderSizePixel = 0
			Row.AutoButtonColor = false
			Row.Text = ""
			Row.ZIndex = 4
			Row.Parent = self.OptionsHolder

			local Label = Instance.new("TextLabel")
			Label.Name = "ToggleName"
			Label.Size = UDim2.new(1, -50, 1, 0)
			Label.Position = UDim2.new(0, 18, 0, 0)
			Label.BackgroundTransparency = 1
			Label.Text = data.Name
			Label.TextSize = UiSize.OptionText
			Label.TextColor3 = Color.Soft
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.TextYAlignment = Enum.TextYAlignment.Center
			Label.Font = Enum.Font.GothamBold
			Label.ZIndex = 5
			Label.Parent = Row

			local state = Instance.new("TextLabel")
			state.Name = "ToggleState"
			state.Size = UDim2.new(0, 36, 1, 0)
			state.AnchorPoint = Vector2.new(1, 0)
			state.Position = UDim2.new(1, -12, 0, 0)
			state.BackgroundTransparency = 1
			state.TextSize = UiSize.OptionText
			state.TextXAlignment = Enum.TextXAlignment.Right
			state.TextYAlignment = Enum.TextYAlignment.Center
			state.Font = Enum.Font.GothamBold
			state.ZIndex = 5
			state.Parent = Row

			local toggle = {
				Name = data.Name,
				Type = "Toggle",
				ConfigKey = CfgKey(self.ConfigKey, data.Name),
				Value = false,
				Function = data.Function,
				ToolTip = data.ToolTip or data.Tooltip,
				Object = Row,
				Button = Row,
				Label = Label,
				StateLabel = state,
				Module = self,
				ControlHeight = UiSize.RowHeight
			}

			function toggle:Refresh()
				self.StateLabel.Text = self.Value and "ON" or "OFF"
				self.StateLabel.TextColor3 = self.Value and Color.text or Color.subtle
			end

			function toggle:SetValue(Value, Options)
				Options = Options or {}
				self.Value = Value and true or false
				self:Refresh()
				if self.Module then
					self.Module:RefreshControlChildren(self)
					ModuleLayout(self.Module)
					CategorySize(self.Module.Category)
				end
				if not Options.SkipConfig then
					SetCfg("Toggle", self.ConfigKey, self.Value)
				end
				RunCb("Toggle", self.Name, self.Function, self.Value, self)
				return self.Value
			end

			Row.MouseButton1Click:Connect(function()
				toggle:SetValue(not toggle.Value)
			end)
			Row.MouseEnter:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.rowHover }, 0.1)
				ShowTip(toggle.ToolTip)
			end)
			Row.MouseLeave:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.Row }, 0.1)
				Fn.HideTip()
			end)

			table.insert(self.ToggleList, toggle)
			self.Toggles[toggle.Name] = toggle
			self:RegisterControl(toggle, data, true)
			toggle:SetValue(GetCfg("Toggle", toggle.ConfigKey, Default), { SkipConfig = true })
			RefreshModule(self)
			ModuleLayout(self)
			CategorySize(self.Category)
			return toggle
		end

		function module:CreateButton(data)
			data = data or {}
			local Row = Instance.new("TextButton")
			Row.Name = data.Name
			Row.Size = UDim2.new(1, 0, 0, UiSize.RowHeight)
			Row.Visible = data.Visible == nil or data.Visible
			Row.BackgroundColor3 = Color.Row
			Row.BorderSizePixel = 0
			Row.AutoButtonColor = false
			Row.Text = ""
			Row.ZIndex = 4
			Row.Parent = self.OptionsHolder

			local Label = Instance.new("TextLabel")
			Label.Name = "ButtonName"
			Label.Size = UDim2.new(1, -86, 1, 0)
			Label.Position = UDim2.new(0, 18, 0, 0)
			Label.BackgroundTransparency = 1
			Label.Text = data.Name
			Label.TextSize = UiSize.OptionText
			Label.TextColor3 = Color.Soft
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.TextYAlignment = Enum.TextYAlignment.Center
			Label.Font = Enum.Font.GothamBold
			Label.ZIndex = 5
			Label.Parent = Row

			local Action = Instance.new("TextLabel")
			Action.Name = "ButtonAction"
			Action.Size = UDim2.new(0, 54, 0, 18)
			Action.AnchorPoint = Vector2.new(1, 0.5)
			Action.Position = UDim2.new(1, -8, 0.5, 0)
			Action.BackgroundColor3 = Color.Action
			Action.BorderSizePixel = 0
			Action.Text = tostring(data.ActionText or data.Text or "Run")
			Action.TextSize = UiSize.OptionText
			Action.TextColor3 = Color3.fromRGB(210, 210, 210)
			Action.Font = Enum.Font.GothamBold
			Action.ZIndex = 5
			Action.Parent = Row

			local actionCorner = Instance.new("UICorner")
			actionCorner.CornerRadius = UDim.new(0, 6)
			actionCorner.Parent = Action

			local buttonData = {
				Name = data.Name,
				Type = "Button",
				ConfigKey = CfgKey(self.ConfigKey, data.Name),
				Function = data.Function,
				ToolTip = data.ToolTip or data.Tooltip,
				Object = Row,
				Button = Row,
				NameLabel = Label,
				ActionLabel = Action,
				Module = self,
				ControlHeight = UiSize.RowHeight
			}

			function buttonData:Press()
				RunCb("Button", self.Name, self.Function, self)
			end

			Row.MouseButton1Click:Connect(function()
				buttonData:Press()
			end)
			Row.MouseEnter:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.rowHover }, 0.1)
				TweenGui(Action, { BackgroundColor3 = Color.actionHover }, 0.1)
				ShowTip(buttonData.ToolTip)
			end)
			Row.MouseLeave:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.Row }, 0.1)
				TweenGui(Action, { BackgroundColor3 = Color.Action }, 0.1)
				Fn.HideTip()
			end)

			table.insert(self.ButtonList, buttonData)
			self.Buttons[buttonData.Name] = buttonData
			self:RegisterControl(buttonData, data, false)
			RefreshModule(self)
			ModuleLayout(self)
			CategorySize(self.Category)
			return buttonData
		end

		function module:CreateSlider(data)
			data = data or {}
			local min = tonumber(data.Min or data.Minimum) or 0
			local max = tonumber(data.Max or data.Maximum) or 100
			local Default = tonumber(data.Default or data.Value) or min
			local step = tonumber(data.Step or data.Increment) or 1
			if max < min then
				min, max = max, min
			end

			local Row = Instance.new("TextButton")
			Row.Name = data.Name
			Row.Size = UDim2.new(1, 0, 0, UiSize.SliderHeight)
			Row.Visible = data.Visible == nil or data.Visible
			Row.BackgroundColor3 = Color.Row
			Row.BorderSizePixel = 0
			Row.AutoButtonColor = false
			Row.Text = ""
			Row.ZIndex = 4
			Row.Parent = self.OptionsHolder

			local Label = Instance.new("TextLabel")
			Label.Name = "SliderName"
			Label.Size = UDim2.new(1, -74, 0, 18)
			Label.Position = UDim2.new(0, 16, 0, 1)
			Label.BackgroundTransparency = 1
			Label.Text = data.Name
			Label.TextSize = UiSize.OptionText
			Label.TextColor3 = Color.Soft
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.TextYAlignment = Enum.TextYAlignment.Center
			Label.Font = Enum.Font.GothamBold
			Label.ZIndex = 5
			Label.Parent = Row

			local ValueLabel = Instance.new("TextButton")
			ValueLabel.Name = "SliderValue"
			ValueLabel.Size = UDim2.new(0, 58, 0, 18)
			ValueLabel.AnchorPoint = Vector2.new(1, 0)
			ValueLabel.Position = UDim2.new(1, -10, 0, 1)
			ValueLabel.BackgroundTransparency = 1
			ValueLabel.BorderSizePixel = 0
			ValueLabel.AutoButtonColor = false
			ValueLabel.Text = ""
			ValueLabel.TextSize = UiSize.OptionText
			ValueLabel.TextColor3 = Color.text
			ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
			ValueLabel.TextYAlignment = Enum.TextYAlignment.Center
			ValueLabel.Font = Enum.Font.GothamBold
			ValueLabel.ZIndex = 5
			ValueLabel.Parent = Row

			local Input = Instance.new("TextBox")
			Input.Name = "SliderInput"
			Input.Size = ValueLabel.Size
			Input.AnchorPoint = ValueLabel.AnchorPoint
			Input.Position = ValueLabel.Position
			Input.BackgroundTransparency = 1
			Input.ClearTextOnFocus = false
			Input.Text = ""
			Input.TextSize = UiSize.OptionText
			Input.TextColor3 = Color.text
			Input.TextXAlignment = Enum.TextXAlignment.Right
			Input.TextYAlignment = Enum.TextYAlignment.Center
			Input.Font = Enum.Font.GothamBold
			Input.Visible = false
			Input.ZIndex = 6
			Input.Parent = Row

			local Track = Instance.new("Frame")
			Track.Name = "SliderTrack"
			Track.Size = UDim2.new(1, -20, 0, 4)
			Track.Position = UDim2.new(0, 10, 0, 25)
			Track.BackgroundColor3 = Color.Track
			Track.BorderSizePixel = 0
			Track.ZIndex = 5
			Track.Parent = Row

			local fill = Instance.new("Frame")
			fill.Name = "SliderFill"
			fill.Size = UDim2.new(0, 0, 1, 0)
			fill.BackgroundColor3 = Color.text
			fill.BorderSizePixel = 0
			fill.ZIndex = 6
			fill.Parent = Track

			local knob = Instance.new("Frame")
			knob.Name = "SliderKnob"
			knob.Size = UDim2.new(0, 8, 0, 8)
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			knob.Position = UDim2.new(0, 0, 0.5, 0)
			knob.BackgroundColor3 = Color.text
			knob.BorderSizePixel = 0
			knob.ZIndex = 7
			knob.Parent = Track

			local knobCorner = Instance.new("UICorner")
			knobCorner.CornerRadius = UDim.new(1, 0)
			knobCorner.Parent = knob

			local slider = {
				Name = data.Name,
				Type = "Slider",
				ConfigKey = CfgKey(self.ConfigKey, data.Name),
				Min = min,
				Max = max,
				Step = step,
				Value = Default,
				Function = data.Function,
				Suffix = data.Suffix,
				ToolTip = data.ToolTip or data.Tooltip,
				Object = Row,
				Button = Row,
				ValueLabel = ValueLabel,
				ValueInput = Input,
				Track = Track,
				Fill = fill,
				Knob = knob,
				Module = self,
				ControlHeight = UiSize.SliderHeight
			}

			function slider:Text(Value)
				local suffix = ""
				if type(self.Suffix) == "function" then
					suffix = tostring(self.Suffix(Value) or "")
				elseif type(self.Suffix) == "string" then
					suffix = self.Suffix
				end
				return tostring(Value) .. suffix
			end

			function slider:Refresh()
				local displayValue = math.clamp(self.Value, self.Min, self.Max)
				local percent = self.Max == self.Min and 0 or math.clamp((displayValue - self.Min) / (self.Max - self.Min), 0, 1)
				TweenGui(self.Fill, { Size = UDim2.new(percent, 0, 1, 0) }, 0.08)
				TweenGui(self.Knob, { Position = UDim2.new(percent, 0, 0.5, 0) }, 0.08)
				self.ValueLabel.Text = self:Text(self.Value)
				self.ValueInput.Text = tostring(self.Value)
			end

			function slider:SetValue(Value, skipCallback, Options)
				Options = Options or {}
				Value = tonumber(Value) or self.Value or self.Min
				if Options.AllowOverflow then
					Value = math.max(Value, self.Min)
				else
					Value = math.clamp(Value, self.Min, self.Max)
				end
				Value = RoundStep(Value, self.Step, self.Min)
				if not Options.AllowOverflow then
					Value = math.clamp(Value, self.Min, self.Max)
				end
				if math.abs(Value - math.floor(Value)) < 0.001 then
					Value = math.floor(Value)
				end
				local changed = self.Value ~= Value
				self.Value = Value
				self:Refresh()
				if not Options.SkipConfig then
					SetCfg("Slider", self.ConfigKey, self.Value)
				end
				if not skipCallback and (changed or Options.ForceCallback) then
					RunCb("Slider", self.Name, self.Function, self.Value, self)
				end
				return self.Value
			end

			local function SetMouse(x)
				local percent = math.clamp((x - Track.AbsolutePosition.X) / math.max(Track.AbsoluteSize.X, 1), 0, 1)
				slider:SetValue(slider.Min + (slider.Max - slider.Min) * percent)
			end

			Row.MouseButton1Down:Connect(function(x)
				if Input.Visible then
					return
				end
				State.ActSlider = slider
				SetMouse(x)
			end)
			local function EditValue()
				State.ActSlider = nil
				ValueLabel.Visible = false
				Input.Visible = true
				Input.Text = tostring(slider.Value)
				Input:CaptureFocus()
				Input.CursorPosition = #Input.Text + 1
			end

			ValueLabel.MouseButton1Click:Connect(EditValue)
			Row.MouseButton2Click:Connect(EditValue)
			Input.FocusLost:Connect(function()
				Input.Visible = false
				ValueLabel.Visible = true
				slider:SetValue(Input.Text, false, {
					AllowOverflow = true
				})
			end)
			Row.MouseEnter:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.rowHover }, 0.1)
				ShowTip(slider.ToolTip)
			end)
			Row.MouseLeave:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.Row }, 0.1)
				Fn.HideTip()
			end)

			table.insert(self.SliderList, slider)
			self.Sliders[slider.Name] = slider
			self:RegisterControl(slider, data, false)
			slider:SetValue(GetCfg("Slider", slider.ConfigKey, Default), false, {
				SkipConfig = true,
				ForceCallback = true,
				AllowOverflow = true
			})
			RefreshModule(self)
			ModuleLayout(self)
			CategorySize(self.Category)
			return slider
		end

		function module:CreateRangeSlider(data)
			data = data or {}
			local name = data.Name or "Range"
			local min = tonumber(data.Min or data.Minimum) or 0
			local max = tonumber(data.Max or data.Maximum) or 100
			if max < min then
				min, max = max, min
			end
			local step = tonumber(data.Step or data.Increment)
			if not step and tonumber(data.Decimal) and tonumber(data.Decimal) > 0 then
				step = 1 / tonumber(data.Decimal)
			end
			step = step or 1
			local defaultMin = tonumber(data.DefaultMin or data.MinValue or data.ValueMin) or min
			local defaultMax = tonumber(data.DefaultMax or data.MaxValue or data.ValueMax) or max
			local rand = Random.new()

			local Row = Instance.new("TextButton")
			Row.Name = name
			Row.Size = UDim2.new(1, 0, 0, UiSize.SliderHeight)
			Row.Visible = data.Visible == nil or data.Visible
			Row.BackgroundColor3 = Color.Row
			Row.BorderSizePixel = 0
			Row.AutoButtonColor = false
			Row.Text = ""
			Row.ZIndex = 4
			Row.Parent = self.OptionsHolder

			local Label = Instance.new("TextLabel")
			Label.Name = "RangeName"
			Label.Size = UDim2.new(1, -118, 0, 18)
			Label.Position = UDim2.new(0, 16, 0, 1)
			Label.BackgroundTransparency = 1
			Label.Text = name
			Label.TextSize = UiSize.OptionText
			Label.TextColor3 = Color.Soft
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.TextYAlignment = Enum.TextYAlignment.Center
			Label.Font = Enum.Font.GothamBold
			Label.ZIndex = 5
			Label.Parent = Row

			local MinLabel = Instance.new("TextLabel")
			MinLabel.Name = "RangeMin"
			MinLabel.Size = UDim2.new(0, 50, 0, 18)
			MinLabel.AnchorPoint = Vector2.new(1, 0)
			MinLabel.Position = UDim2.new(1, -62, 0, 1)
			MinLabel.BackgroundTransparency = 1
			MinLabel.TextSize = UiSize.OptionText
			MinLabel.TextColor3 = Color.text
			MinLabel.TextXAlignment = Enum.TextXAlignment.Right
			MinLabel.TextYAlignment = Enum.TextYAlignment.Center
			MinLabel.Font = Enum.Font.GothamBold
			MinLabel.ZIndex = 5
			MinLabel.Parent = Row

			local MaxLabel = MinLabel:Clone()
			MaxLabel.Name = "RangeMax"
			MaxLabel.Position = UDim2.new(1, -10, 0, 1)
			MaxLabel.Parent = Row

			local Track = Instance.new("Frame")
			Track.Name = "RangeTrack"
			Track.Size = UDim2.new(1, -20, 0, 4)
			Track.Position = UDim2.new(0, 10, 0, 25)
			Track.BackgroundColor3 = Color.Track
			Track.BorderSizePixel = 0
			Track.ZIndex = 5
			Track.Parent = Row

			local fill = Instance.new("Frame")
			fill.Name = "RangeFill"
			fill.BackgroundColor3 = Color.text
			fill.BorderSizePixel = 0
			fill.ZIndex = 6
			fill.Parent = Track

			local minKnob = Instance.new("Frame")
			minKnob.Name = "MinKnob"
			minKnob.Size = UDim2.new(0, 8, 0, 12)
			minKnob.AnchorPoint = Vector2.new(0.5, 0.5)
			minKnob.BackgroundColor3 = Color.text
			minKnob.BorderSizePixel = 0
			minKnob.ZIndex = 7
			minKnob.Parent = Track
			local minCorner = Instance.new("UICorner")
			minCorner.CornerRadius = UDim.new(1, 0)
			minCorner.Parent = minKnob

			local maxKnob = minKnob:Clone()
			maxKnob.Name = "MaxKnob"
			maxKnob.Parent = Track

			local range = {
				Name = name,
				Type = "RangeSlider",
				ConfigKey = CfgKey(self.ConfigKey, name),
				Min = min,
				Max = max,
				Step = step,
				ValueMin = defaultMin,
				ValueMax = defaultMax,
				Function = data.Function,
				Suffix = data.Suffix,
				ToolTip = data.ToolTip or data.Tooltip,
				Object = Row,
				Button = Row,
				Track = Track,
				Fill = fill,
				MinKnob = minKnob,
				MaxKnob = maxKnob,
				Module = self,
				ControlHeight = UiSize.SliderHeight
			}

			function range:Text(Value)
				local suffix = ""
				if type(self.Suffix) == "function" then
					suffix = tostring(self.Suffix(Value) or "")
				elseif type(self.Suffix) == "string" then
					suffix = self.Suffix
				end
				return tostring(Value) .. suffix
			end

			function range:Refresh()
				local minPercent = self.Max == self.Min and 0 or math.clamp((self.ValueMin - self.Min) / (self.Max - self.Min), 0, 1)
				local maxPercent = self.Max == self.Min and 0 or math.clamp((self.ValueMax - self.Min) / (self.Max - self.Min), 0, 1)
				TweenGui(self.Fill, {
					Position = UDim2.new(minPercent, 0, 0, 0),
					Size = UDim2.new(math.max(maxPercent - minPercent, 0), 0, 1, 0)
				}, 0.08)
				TweenGui(self.MinKnob, { Position = UDim2.new(minPercent, 0, 0.5, 0) }, 0.08)
				TweenGui(self.MaxKnob, { Position = UDim2.new(maxPercent, 0, 0.5, 0) }, 0.08)
				MinLabel.Text = self:Text(self.ValueMin)
				MaxLabel.Text = self:Text(self.ValueMax)
			end

			function range:SetValue(maxSide, Value, skipCallback, Options)
				if type(maxSide) == "table" then
					Options = Value or {}
					local tab = maxSide
					self.ValueMin = RoundStep(math.clamp(tonumber(tab.ValueMin or tab.Min or tab[1]) or self.ValueMin, self.Min, self.Max), self.Step, self.Min)
					self.ValueMax = RoundStep(math.clamp(tonumber(tab.ValueMax or tab.Max or tab[2]) or self.ValueMax, self.Min, self.Max), self.Step, self.Min)
				else
					Options = Options or {}
					Value = RoundStep(math.clamp(tonumber(Value) or (maxSide and self.ValueMax or self.ValueMin), self.Min, self.Max), self.Step, self.Min)
					if maxSide then
						self.ValueMax = Value
					else
						self.ValueMin = Value
					end
				end
				if self.ValueMax < self.ValueMin then
					self.ValueMin, self.ValueMax = self.ValueMax, self.ValueMin
				end
				self:Refresh()
				if not Options.SkipConfig then
					SetCfg("RangeSlider", self.ConfigKey, {
						ValueMin = self.ValueMin,
						ValueMax = self.ValueMax
					})
				end
				if not skipCallback and not Options.SkipCallback then
					RunCb("RangeSlider", self.Name, self.Function, self.ValueMin, self.ValueMax, self)
				end
				return self.ValueMin, self.ValueMax
			end

			function range:GetRandomValue()
				return rand:NextNumber(math.min(self.ValueMin, self.ValueMax), math.max(self.ValueMin, self.ValueMax))
			end

			local function beginDrag(x)
				local minPercent = range.Max == range.Min and 0 or (range.ValueMin - range.Min) / (range.Max - range.Min)
				local maxPercent = range.Max == range.Min and 1 or (range.ValueMax - range.Min) / (range.Max - range.Min)
				local percent = math.clamp((x - Track.AbsolutePosition.X) / math.max(Track.AbsoluteSize.X, 1), 0, 1)
				local maxSide = math.abs(percent - maxPercent) < math.abs(percent - minPercent)
				State.ActSlider = {
					Track = Track,
					Min = range.Min,
					Max = range.Max,
					SetValue = function(_, Value)
						range:SetValue(maxSide, Value)
					end
				}
				State.ActSlider:SetValue(range.Min + ((range.Max - range.Min) * percent))
			end

			Row.MouseButton1Down:Connect(beginDrag)
			Row.MouseEnter:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.rowHover }, 0.1)
				ShowTip(range.ToolTip)
			end)
			Row.MouseLeave:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.Row }, 0.1)
				Fn.HideTip()
			end)

			table.insert(self.SliderList, range)
			self.Sliders[range.Name] = range
			self:RegisterControl(range, data, false)
			range:SetValue(GetCfg("RangeSlider", range.ConfigKey, {
				ValueMin = defaultMin,
				ValueMax = defaultMax
			}), {
				SkipConfig = true,
				SkipCallback = true
			})
			RefreshModule(self)
			ModuleLayout(self)
			CategorySize(self.Category)
			return range
		end

		function module:CreateTwoSlider(data)
			return self:CreateRangeSlider(data)
		end

		function module:CreateColorSlider(data)
			data = data or {}
			local name = data.Name or "Color"
			local baseColor = ColorLoad(data.Default or data.DefaultColor, Color3.fromHSV(tonumber(data.DefaultHue) or 0, tonumber(data.DefaultSaturation or data.DefaultSat) or 1, tonumber(data.DefaultVibrance or data.DefaultValue) or 1))
			local defaultHue, defaultSat, defaultValue = baseColor:ToHSV()
			defaultHue = tonumber(data.DefaultHue) or defaultHue
			defaultSat = tonumber(data.DefaultSaturation or data.DefaultSat) or defaultSat
			defaultValue = tonumber(data.DefaultVibrance or data.DefaultValue) or defaultValue

			local Row = Instance.new("TextButton")
			Row.Name = name
			Row.Size = UDim2.new(1, 0, 0, UiSize.SliderHeight)
			Row.Visible = data.Visible == nil or data.Visible
			Row.BackgroundColor3 = Color.Row
			Row.BorderSizePixel = 0
			Row.AutoButtonColor = false
			Row.Text = ""
			Row.ZIndex = 4
			Row.Parent = self.OptionsHolder

			local Label = Instance.new("TextLabel")
			Label.Name = "ColorName"
			Label.Size = UDim2.new(1, -112, 0, 18)
			Label.Position = UDim2.new(0, 16, 0, 1)
			Label.BackgroundTransparency = 1
			Label.Text = name
			Label.TextSize = UiSize.OptionText
			Label.TextColor3 = Color.Soft
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.TextYAlignment = Enum.TextYAlignment.Center
			Label.Font = Enum.Font.GothamBold
			Label.ZIndex = 5
			Label.Parent = Row

			local Preview = Instance.new("Frame")
			Preview.Name = "Preview"
			Preview.Size = UDim2.new(0, 12, 0, 12)
			Preview.AnchorPoint = Vector2.new(1, 0)
			Preview.Position = UDim2.new(1, -74, 0, 4)
			Preview.BorderSizePixel = 0
			Preview.ZIndex = 5
			Preview.Parent = Row
			local previewCorner = Instance.new("UICorner")
			previewCorner.CornerRadius = UDim.new(1, 0)
			previewCorner.Parent = Preview

			local ValueLabel = Instance.new("TextButton")
			ValueLabel.Name = "ColorValue"
			ValueLabel.Size = UDim2.new(0, 58, 0, 18)
			ValueLabel.AnchorPoint = Vector2.new(1, 0)
			ValueLabel.Position = UDim2.new(1, -10, 0, 1)
			ValueLabel.BackgroundTransparency = 1
			ValueLabel.BorderSizePixel = 0
			ValueLabel.AutoButtonColor = false
			ValueLabel.TextSize = UiSize.OptionText
			ValueLabel.TextColor3 = Color.text
			ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
			ValueLabel.TextYAlignment = Enum.TextYAlignment.Center
			ValueLabel.Font = Enum.Font.GothamBold
			ValueLabel.ZIndex = 5
			ValueLabel.Parent = Row

			local ValueInput = Instance.new("TextBox")
			ValueInput.Name = "ColorInput"
			ValueInput.Size = ValueLabel.Size
			ValueInput.AnchorPoint = ValueLabel.AnchorPoint
			ValueInput.Position = ValueLabel.Position
			ValueInput.BackgroundTransparency = 1
			ValueInput.ClearTextOnFocus = false
			ValueInput.TextSize = UiSize.OptionText
			ValueInput.TextColor3 = Color.text
			ValueInput.TextXAlignment = Enum.TextXAlignment.Right
			ValueInput.TextYAlignment = Enum.TextYAlignment.Center
			ValueInput.Font = Enum.Font.GothamBold
			ValueInput.Visible = false
			ValueInput.ZIndex = 6
			ValueInput.Parent = Row

			local Track = Instance.new("Frame")
			Track.Name = "ColorTrack"
			Track.Size = UDim2.new(1, -20, 0, 4)
			Track.Position = UDim2.new(0, 10, 0, 25)
			Track.BackgroundColor3 = Color.text
			Track.BorderSizePixel = 0
			Track.ZIndex = 5
			Track.Parent = Row

			local trackGradient = Instance.new("UIGradient")
			trackGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
				ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
				ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
				ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
				ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
				ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1))
			})
			trackGradient.Parent = Track

			local Knob = Instance.new("Frame")
			Knob.Name = "ColorKnob"
			Knob.Size = UDim2.new(0, 8, 0, 12)
			Knob.AnchorPoint = Vector2.new(0.5, 0.5)
			Knob.BackgroundColor3 = Color.text
			Knob.BorderSizePixel = 0
			Knob.ZIndex = 7
			Knob.Parent = Track
			local knobCorner = Instance.new("UICorner")
			knobCorner.CornerRadius = UDim.new(1, 0)
			knobCorner.Parent = Knob

			local colorSlider = {
				Name = name,
				Type = "ColorSlider",
				ConfigKey = CfgKey(self.ConfigKey, name),
				Hue = defaultHue,
				Sat = defaultSat,
				Value = defaultValue,
				Opacity = tonumber(data.DefaultOpacity) or 1,
				Rainbow = false,
				CustomColor = true,
				Function = data.Function,
				ToolTip = data.ToolTip or data.Tooltip,
				Object = Row,
				Button = Row,
				Track = Track,
				Preview = Preview,
				Knob = Knob,
				Module = self,
				ControlHeight = UiSize.SliderHeight
			}

			function colorSlider:GetColor()
				return Color3.fromHSV(self.Hue, self.Sat, self.Value)
			end

			function colorSlider:Refresh()
				local current = self:GetColor()
				Preview.BackgroundColor3 = current
				ValueLabel.Text = RgbText(current)
				ValueInput.Text = RgbText(current)
				TweenGui(Knob, { Position = UDim2.new(math.clamp(self.Hue, 0, 1), 0, 0.5, 0) }, 0.08)
			end

			function colorSlider:SetValue(h, s, v, opacity, Options)
				if typeof(h) == "Color3" then
					h, s, v = h:ToHSV()
				elseif type(h) == "table" then
					Options = s or {}
					self.Rainbow = h.Rainbow and true or false
					h, s, v, opacity = h.Hue, h.Sat, h.Value, h.Opacity
				elseif type(opacity) == "table" then
					Options = opacity
					opacity = nil
				end
				Options = Options or {}
				self.Hue = math.clamp(tonumber(h) or self.Hue, 0, 1)
				self.Sat = math.clamp(tonumber(s) or self.Sat, 0, 1)
				self.Value = math.clamp(tonumber(v) or self.Value, 0, 1)
				self.Opacity = math.clamp(tonumber(opacity) or self.Opacity, 0, 1)
				self.CustomColor = true
				self:Refresh()
				if not Options.SkipConfig then
					SetCfg("ColorSlider", self.ConfigKey, {
						Hue = self.Hue,
						Sat = self.Sat,
						Value = self.Value,
						Opacity = self.Opacity,
						Rainbow = self.Rainbow,
						CustomColor = self.CustomColor
					})
				end
				if not Options.SkipCallback then
					RunCb("ColorSlider", self.Name, self.Function, self.Hue, self.Sat, self.Value, self.Opacity, self)
				end
				return self.Hue, self.Sat, self.Value
			end

			function colorSlider:Toggle()
				self.Rainbow = not self.Rainbow
				if self.RainbowConnection then
					self.RainbowConnection:Disconnect()
					self.RainbowConnection = nil
				end
				if self.Rainbow then
					self.RainbowConnection = RunService.RenderStepped:Connect(function()
						self:SetValue((tick() * (Settings.RainbowSpeed or 0.2)) % 1, self.Sat, self.Value, self.Opacity, {
							SkipConfig = true
						})
					end)
					table.insert(TaskAPI.Connections, self.RainbowConnection)
				else
					SetCfg("ColorSlider", self.ConfigKey, {
						Hue = self.Hue,
						Sat = self.Sat,
						Value = self.Value,
						Opacity = self.Opacity,
						Rainbow = false,
						CustomColor = self.CustomColor
					})
				end
				return self.Rainbow
			end

			local function beginDrag(x)
				local percent = math.clamp((x - Track.AbsolutePosition.X) / math.max(Track.AbsoluteSize.X, 1), 0, 1)
				State.ActSlider = {
					Track = Track,
					Min = 0,
					Max = 1,
					SetValue = function(_, Value)
						colorSlider:SetValue(Value, colorSlider.Sat, colorSlider.Value, colorSlider.Opacity)
					end
				}
				State.ActSlider:SetValue(percent)
			end

			local function editValue()
				State.ActSlider = nil
				ValueLabel.Visible = false
				ValueInput.Visible = true
				ValueInput.Text = RgbText(colorSlider:GetColor())
				ValueInput:CaptureFocus()
				ValueInput.CursorPosition = #ValueInput.Text + 1
			end

			Row.MouseButton1Down:Connect(beginDrag)
			ValueLabel.MouseButton1Click:Connect(editValue)
			Row.MouseButton2Click:Connect(function()
				colorSlider:Toggle()
			end)
			ValueInput.FocusLost:Connect(function()
				ValueInput.Visible = false
				ValueLabel.Visible = true
				colorSlider:SetValue(ParseRgb(ValueInput.Text, colorSlider:GetColor()))
			end)
			Row.MouseEnter:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.rowHover }, 0.1)
				ShowTip(colorSlider.ToolTip)
			end)
			Row.MouseLeave:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.Row }, 0.1)
				Fn.HideTip()
			end)

			table.insert(self.SliderList, colorSlider)
			self.Sliders[colorSlider.Name] = colorSlider
			self:RegisterControl(colorSlider, data, false)
			local savedColor = GetCfg("ColorSlider", colorSlider.ConfigKey, {
				Hue = defaultHue,
				Sat = defaultSat,
				Value = defaultValue,
				Opacity = colorSlider.Opacity,
				Rainbow = false,
				CustomColor = true
			})
			colorSlider:SetValue(savedColor, {
				SkipConfig = true,
				SkipCallback = true
			})
			if type(savedColor) == "table" and savedColor.Rainbow then
				colorSlider.Rainbow = false
				colorSlider:Toggle()
			end
			RefreshModule(self)
			ModuleLayout(self)
			CategorySize(self.Category)
			return colorSlider
		end

		function module:CreateTextBox(data)
			data = data or {}
			local Row = Instance.new("TextButton")
			Row.Name = data.Name
			Row.Size = UDim2.new(1, 0, 0, UiSize.RowHeight)
			Row.Visible = data.Visible == nil or data.Visible
			Row.BackgroundColor3 = Color.Row
			Row.BorderSizePixel = 0
			Row.AutoButtonColor = false
			Row.Text = ""
			Row.ZIndex = 4
			Row.Parent = self.OptionsHolder

			local Label = Instance.new("TextLabel")
			Label.Name = "TextBoxName"
			Label.Size = UDim2.new(0.5, -18, 1, 0)
			Label.Position = UDim2.new(0, 18, 0, 0)
			Label.BackgroundTransparency = 1
			Label.Text = data.Name
			Label.TextSize = UiSize.OptionText
			Label.TextColor3 = Color.Soft
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.TextYAlignment = Enum.TextYAlignment.Center
			Label.Font = Enum.Font.GothamBold
			Label.ZIndex = 5
			Label.Parent = Row

			local Input = Instance.new("TextBox")
			Input.Name = "TextBoxInput"
			Input.Size = UDim2.new(0.5, -14, 0, 22)
			Input.AnchorPoint = Vector2.new(1, 0.5)
			Input.Position = UDim2.new(1, -12, 0.5, 0)
			Input.BackgroundColor3 = Color.Action
			Input.BorderSizePixel = 0
			Input.ClearTextOnFocus = false
			Input.Text = tostring(data.Default or "")
			Input.TextSize = UiSize.OptionText
			Input.TextColor3 = Color.text
			Input.TextXAlignment = Enum.TextXAlignment.Center
			Input.TextYAlignment = Enum.TextYAlignment.Center
			Input.Font = Enum.Font.GothamBold
			Input.ZIndex = 5
			Input.Parent = Row

			local inputCorner = Instance.new("UICorner")
			inputCorner.CornerRadius = UDim.new(0, 6)
			inputCorner.Parent = Input

			local textBox = {
				Name = data.Name,
				Type = "TextBox",
				ConfigKey = CfgKey(self.ConfigKey, data.Name),
				Value = Input.Text,
				Function = data.Function,
				ToolTip = data.ToolTip or data.Tooltip,
				Object = Row,
				Button = Row,
				InputService = Input,
				Module = self,
				ControlHeight = UiSize.RowHeight
			}

			function textBox:SetValue(Value, Options)
				Options = Options or {}
				local changed = self.Value ~= tostring(Value or "")
				self.Value = tostring(Value or "")
				self.InputService.Text = self.Value
				if not Options.SkipConfig then
					SetCfg("TextBox", self.ConfigKey, self.Value)
				end
				if changed or Options.ForceCallback then
					RunCb("TextBox", self.Name, self.Function, self.Value, self)
				end
				return self.Value
			end

			Input.FocusLost:Connect(function()
				textBox:SetValue(Input.Text)
			end)
			Row.MouseButton1Click:Connect(function()
				Input:CaptureFocus()
			end)
			Row.MouseEnter:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.rowHover }, 0.1)
				ShowTip(textBox.ToolTip)
			end)
			Row.MouseLeave:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.Row }, 0.1)
				Fn.HideTip()
			end)

			table.insert(self.TextBoxList, textBox)
			self.TextBoxes[textBox.Name] = textBox
			self:RegisterControl(textBox, data, false)
			textBox:SetValue(GetCfg("TextBox", textBox.ConfigKey, textBox.Value), {
				SkipConfig = true,
				ForceCallback = true
			})
			RefreshModule(self)
			ModuleLayout(self)
			CategorySize(self.Category)
			return textBox
		end

		function module:CreateDropdown(data)
			data = data or {}
			local rawList = data.List or data.Values or {}
			local list = {}
			for _, Value in ipairs(rawList) do
				table.insert(list, tostring(Value))
			end
			local Default = tostring(data.Default or data.Value or list[1] or "")
			local optionHeight = 20

			local Container = Instance.new("Frame")
			Container.Name = data.Name .. "_Dropdown"
			Container.Size = UDim2.new(1, 0, 0, UiSize.RowHeight)
			Container.Visible = data.Visible == nil or data.Visible
			Container.BackgroundTransparency = 1
			Container.BorderSizePixel = 0
			Container.ClipsDescendants = true
			Container.ZIndex = 4
			Container.Parent = self.OptionsHolder

			local Row = Instance.new("TextButton")
			Row.Name = data.Name
			Row.Size = UDim2.new(1, 0, 0, UiSize.RowHeight)
			Row.BackgroundColor3 = Color.Row
			Row.BorderSizePixel = 0
			Row.AutoButtonColor = false
			Row.Text = ""
			Row.ZIndex = 4
			Row.Parent = Container

			local Label = Instance.new("TextLabel")
			Label.Name = "DropdownName"
			Label.Size = UDim2.new(0.5, -18, 1, 0)
			Label.Position = UDim2.new(0, 18, 0, 0)
			Label.BackgroundTransparency = 1
			Label.Text = data.Name
			Label.TextSize = UiSize.OptionText
			Label.TextColor3 = Color.Soft
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.TextYAlignment = Enum.TextYAlignment.Center
			Label.Font = Enum.Font.GothamBold
			Label.ZIndex = 5
			Label.Parent = Row

			local ValueLabel = Instance.new("TextLabel")
			ValueLabel.Name = "DropdownValue"
			ValueLabel.Size = UDim2.new(0.5, -34, 1, 0)
			ValueLabel.AnchorPoint = Vector2.new(1, 0)
			ValueLabel.Position = UDim2.new(1, -28, 0, 0)
			ValueLabel.BackgroundTransparency = 1
			ValueLabel.TextSize = UiSize.OptionText
			ValueLabel.TextColor3 = Color.text
			ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
			ValueLabel.TextYAlignment = Enum.TextYAlignment.Center
			ValueLabel.Font = Enum.Font.GothamBold
			ValueLabel.ZIndex = 5
			ValueLabel.Parent = Row

			local arrow = Instance.new("TextLabel")
			arrow.Name = "DropdownArrow"
			arrow.Size = UDim2.new(0, 18, 1, 0)
			arrow.AnchorPoint = Vector2.new(1, 0)
			arrow.Position = UDim2.new(1, -8, 0, 0)
			arrow.BackgroundTransparency = 1
			arrow.Text = ">"
			arrow.TextSize = UiSize.OptionText + 1
			arrow.TextColor3 = Color.muted
			arrow.Font = Enum.Font.GothamBold
			arrow.ZIndex = 5
			arrow.Parent = Row

			local ListHolder = Instance.new("Frame")
			ListHolder.Name = "DropdownList"
			ListHolder.Size = UDim2.new(1, 0, 0, 0)
			ListHolder.Position = UDim2.new(0, 0, 0, UiSize.RowHeight)
			ListHolder.BackgroundColor3 = Color.Row
			ListHolder.BorderSizePixel = 0
			ListHolder.ClipsDescendants = true
			ListHolder.ZIndex = 4
			ListHolder.Parent = Container

			local ListLayout = Instance.new("UIListLayout")
			ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
			ListLayout.Parent = ListHolder

			local Dropdown = {
				Name = data.Name,
				Type = "Dropdown",
				ConfigKey = CfgKey(self.ConfigKey, data.Name),
				Value = Default,
				List = list,
				Open = false,
				Function = data.Function,
				ToolTip = data.ToolTip or data.Tooltip,
				Object = Container,
				Button = Row,
				Container = Container,
				ListHolder = ListHolder,
				ValueLabel = ValueLabel,
				Arrow = arrow,
				Options = {},
				Module = self,
				ControlHeight = UiSize.RowHeight
			}

			function Dropdown:GetOption(Value)
				Value = tostring(Value or "")
				for _, optionValue in ipairs(self.List) do
					if optionValue == Value then
						return optionValue
					end
				end
				return nil
			end

			function Dropdown:Refresh()
				self.ValueLabel.Text = tostring(self.Value or "")
				self.Arrow.Text = self.Open and "v" or ">"
				local listHeight = self.Open and (#self.List * optionHeight) or 0
				local height = UiSize.RowHeight + listHeight
				self.ControlHeight = height
				TweenGui(self.Container, { Size = UDim2.new(1, 0, 0, height) })
				TweenGui(self.ListHolder, { Size = UDim2.new(1, 0, 0, listHeight) })
				for _, button in ipairs(self.Options) do
					button.TextColor3 = button:GetAttribute("OptionValue") == self.Value and Color.text or Color.Soft
				end
				if self.Module then
					self.Module:RefreshControlChildren(self)
				end
				ModuleLayout(self.Module)
				CategorySize(self.Module.Category)
			end

			function Dropdown:SetOpen(open)
				self.Open = open and true or false
				self:Refresh()
			end

			function Dropdown:SetValue(Value, skipCallback, Options)
				if type(skipCallback) == "table" and Options == nil then
					Options = skipCallback
					skipCallback = false
				end
				Options = Options or {}
				local matched = self:GetOption(Value)
				if not matched then
					matched = self:GetOption(Default) or self.List[1]
				end
				if not matched then
					return self.Value
				end
				local changed = self.Value ~= matched
				self.Value = matched
				self:Refresh()
				if not Options.SkipConfig then
					SetCfg("Dropdown", self.ConfigKey, self.Value)
				end
				if not skipCallback and (changed or Options.ForceCallback) then
					RunCb("Dropdown", self.Name, self.Function, self.Value, self)
				end
				return self.Value
			end

			for index, Value in ipairs(list) do
				local option = Instance.new("TextButton")
				option.Name = tostring(Value)
				option.Size = UDim2.new(1, 0, 0, optionHeight)
				option.BackgroundColor3 = Color.Row
				option.BorderSizePixel = 0
				option.AutoButtonColor = false
				option.Text = tostring(Value)
				option.TextSize = UiSize.OptionText
				option.TextColor3 = Color.Soft
				option.TextXAlignment = Enum.TextXAlignment.Center
				option.TextYAlignment = Enum.TextYAlignment.Center
				option.Font = Enum.Font.GothamBold
				option.LayoutOrder = index
				option.ZIndex = 5
				option:SetAttribute("OptionValue", Value)
				option.Parent = ListHolder
				table.insert(Dropdown.Options, option)
				option.MouseButton1Click:Connect(function()
					Dropdown:SetValue(Value)
					Dropdown:SetOpen(false)
				end)
				option.MouseEnter:Connect(function()
					TweenGui(option, { BackgroundColor3 = Color.rowHover }, 0.1)
				end)
				option.MouseLeave:Connect(function()
					TweenGui(option, { BackgroundColor3 = Color.Row }, 0.1)
				end)
			end

			Row.MouseButton1Click:Connect(function()
				Dropdown:SetOpen(not Dropdown.Open)
			end)
			Row.MouseButton2Click:Connect(function()
				Dropdown:SetOpen(not Dropdown.Open)
			end)
			Row.MouseEnter:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.rowHover }, 0.1)
				ShowTip(Dropdown.ToolTip)
			end)
			Row.MouseLeave:Connect(function()
				TweenGui(Row, { BackgroundColor3 = Color.Row }, 0.1)
				Fn.HideTip()
			end)

			table.insert(self.DropdownList, Dropdown)
			self.Dropdowns[Dropdown.Name] = Dropdown
			self:RegisterControl(Dropdown, data, true)
			Dropdown:SetValue(GetCfg("Dropdown", Dropdown.ConfigKey, Default), false, {
				SkipConfig = true,
				ForceCallback = true
			})
			RefreshModule(self)
			ModuleLayout(self)
			CategorySize(self.Category)
			return Dropdown
		end

		function module:CreateHotbarList(data)
			data = data or {}
			local selectedSlot = 1
			local defaultHotbars = data.Default or {
				{
					["1"] = "diamond_sword",
					["2"] = "wool_white",
					["3"] = "telepearl",
					["4"] = "fireball",
					["5"] = "diamond_axe",
					["6"] = "diamond_pickaxe",
					["7"] = "wood_bow"
				}
			}

			local Row = Instance.new("Frame")
			Row.Name = "HotbarList"
			Row.Size = UDim2.new(1, 0, 0, 40)
			Row.Visible = data.Visible == nil or data.Visible
			Row.BackgroundColor3 = Color.Row
			Row.BorderSizePixel = 0
			Row.ZIndex = 4
			Row.Parent = self.OptionsHolder

			local addButton = Instance.new("TextButton")
			addButton.Name = "AddHotbar"
			addButton.Size = UDim2.new(1, -20, 0, 28)
			addButton.Position = UDim2.new(0, 10, 0, 6)
			addButton.BackgroundColor3 = Color.Action
			addButton.BorderSizePixel = 0
			addButton.AutoButtonColor = false
			addButton.Text = "+"
			addButton.TextSize = 18
			addButton.TextColor3 = Color3.fromRGB(72, 214, 150)
			addButton.Font = Enum.Font.GothamBold
			addButton.ZIndex = 5
			addButton.Parent = Row

			local addCorner = Instance.new("UICorner")
			addCorner.CornerRadius = UDim.new(0, 6)
			addCorner.Parent = addButton

			local ListHolder = Instance.new("Frame")
			ListHolder.Name = "HotbarProfiles"
			ListHolder.Size = UDim2.new(1, 0, 1, -40)
			ListHolder.Position = UDim2.new(0, 0, 0, 40)
			ListHolder.BackgroundTransparency = 1
			ListHolder.BorderSizePixel = 0
			ListHolder.ZIndex = 4
			ListHolder.Parent = Row

			local ListLayout = Instance.new("UIListLayout")
			ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
			ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			ListLayout.Padding = UDim.new(0, 3)
			ListLayout.Parent = ListHolder

			local window = Instance.new("Frame")
			window.Name = "HotbarEditor"
			window.Size = UDim2.new(0, 660, 0, 465)
			window.Position = UDim2.new(0.5, 0, 0.5, 0)
			window.AnchorPoint = Vector2.new(0.5, 0.5)
			window.BackgroundColor3 = Color.window
			window.BorderSizePixel = 0
			window.Visible = false
			window.ZIndex = 50
			window.Parent = ScreenGui

			local windowCorner = Instance.new("UICorner")
			windowCorner.CornerRadius = UDim.new(0, 8)
			windowCorner.Parent = window

			local title = Instance.new("TextLabel")
			title.Name = "Title"
			title.Size = UDim2.new(1, -52, 0, 40)
			title.Position = UDim2.new(0, 14, 0, 0)
			title.BackgroundTransparency = 1
			title.Text = data.Title or "Auto Hotbar"
			title.TextSize = 13
			title.TextColor3 = Color.text
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Font = Enum.Font.GothamBold
			title.ZIndex = 51
			title.Parent = window

			local close = Instance.new("TextButton")
			close.Name = "Close"
			close.Size = UDim2.new(0, 26, 0, 26)
			close.Position = UDim2.new(1, -36, 0, 7)
			close.BackgroundColor3 = Color.Action
			close.BorderSizePixel = 0
			close.AutoButtonColor = false
			close.Text = "x"
			close.TextSize = 12
			close.TextColor3 = Color.Soft
			close.Font = Enum.Font.GothamBold
			close.ZIndex = 51
			close.Parent = window

			local closeCorner = Instance.new("UICorner")
			closeCorner.CornerRadius = UDim.new(1, 0)
			closeCorner.Parent = close

			local divider = Instance.new("Frame")
			divider.Name = "Divider"
			divider.Size = UDim2.new(1, 0, 0, 1)
			divider.Position = UDim2.new(0, 0, 0, 40)
			divider.BackgroundColor3 = Color.Action
			divider.BorderSizePixel = 0
			divider.ZIndex = 51
			divider.Parent = window

			local slotLabel = Instance.new("TextLabel")
			slotLabel.Name = "SlotLabel"
			slotLabel.Size = UDim2.new(0, 110, 0, 20)
			slotLabel.Position = UDim2.new(0, 12, 0, 198)
			slotLabel.BackgroundTransparency = 1
			slotLabel.Text = "SLOT 1"
			slotLabel.TextSize = 12
			slotLabel.TextColor3 = Color.Soft
			slotLabel.Font = Enum.Font.GothamBold
			slotLabel.ZIndex = 51
			slotLabel.Parent = window

			local searchBox = Instance.new("TextBox")
			searchBox.Name = "Search"
			searchBox.Size = UDim2.new(0, 496, 0, 31)
			searchBox.Position = UDim2.new(0, 142, 0, 80)
			searchBox.BackgroundColor3 = Color.Action
			searchBox.BorderSizePixel = 0
			searchBox.ClearTextOnFocus = false
			searchBox.PlaceholderText = "Search items"
			searchBox.Text = ""
			searchBox.TextSize = 12
			searchBox.TextColor3 = Color.text
			searchBox.PlaceholderColor3 = Color.subtle
			searchBox.TextXAlignment = Enum.TextXAlignment.Left
			searchBox.Font = Enum.Font.GothamBold
			searchBox.ZIndex = 51
			searchBox.Parent = window

			local searchPadding = Instance.new("UIPadding")
			searchPadding.PaddingLeft = UDim.new(0, 10)
			searchPadding.PaddingRight = UDim.new(0, 10)
			searchPadding.Parent = searchBox

			local searchCorner = Instance.new("UICorner")
			searchCorner.CornerRadius = UDim.new(0, 6)
			searchCorner.Parent = searchBox

			local children = Instance.new("ScrollingFrame")
			children.Name = "Children"
			children.Size = UDim2.new(0, 500, 0, 240)
			children.Position = UDim2.new(0, 144, 0, 122)
			children.BackgroundTransparency = 1
			children.BorderSizePixel = 0
			children.ScrollBarThickness = 3
			children.ScrollBarImageTransparency = 0.35
			children.CanvasSize = UDim2.new()
			children.ZIndex = 51
			children.Parent = window

			local grid = Instance.new("UIGridLayout")
			grid.SortOrder = Enum.SortOrder.LayoutOrder
			grid.FillDirectionMaxCells = 9
			grid.CellSize = UDim2.fromOffset(51, 52)
			grid.CellPadding = UDim2.fromOffset(4, 3)
			grid.Parent = children

			local HotbarList = {
				Name = data.Name or "HotbarList",
				ConfigKey = CfgKey(self.ConfigKey, data.Name or "HotbarList"),
				Type = "HotbarList",
				Hotbars = {},
				Selected = 1,
				Function = data.Function,
				ToolTip = data.ToolTip or data.Tooltip,
				Object = Row,
				Button = Row,
				AddButton = addButton,
				Holder = ListHolder,
				Window = window,
				Module = self,
				ControlHeight = 40
			}

			local function Bedwars()
				return rawget(getgenv(), "bedwars") or {}
			end

			local function ItemIcon(itemType)
				local bedwarsRef = Bedwars()
				local itemMeta = bedwarsRef.ItemMeta and bedwarsRef.ItemMeta[itemType]
				return itemMeta and itemMeta.image or ""
			end

			local function RefreshProfile()
				for index, Hotbar in ipairs(HotbarList.Hotbars) do
					if Hotbar.Object then
						Hotbar.Object.BackgroundColor3 = index == HotbarList.Selected and Color.rowHover or Color.Action
					end
				end
			end

			local function UpdateHeight()
				local height = math.min(43 + ListLayout.AbsoluteContentSize.Y, 603)
				HotbarList.ControlHeight = height
				Row.Size = UDim2.new(1, 0, 0, height)
				ModuleLayout(self)
				CategorySize(self.Category)
			end

			local function SelHotbar()
				return HotbarList.Hotbars[HotbarList.Selected]
			end

			local function SetSlotImage(Container, index, itemType)
				local slot = Container and Container:FindFirstChild("Slot" .. index)
				local image = slot and (slot:IsA("ImageLabel") and slot or slot:FindFirstChildWhichIsA("ImageLabel"))
				if image then
					image.Image = itemType and ItemIcon(itemType) or ""
				end
			end

			local function RefreshSlots()
				local current = SelHotbar()
				for index = 1, 9 do
					SetSlotImage(window, index, current and current.Hotbar[tostring(index)] or nil)
					local slotButton = window:FindFirstChild("Slot" .. index)
					local stroke = slotButton and slotButton:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Enabled = index == selectedSlot
					end
				end
				slotLabel.Text = "SLOT " .. selectedSlot
			end

			local function SaveHotbar(Options)
				Options = Options or {}
				local Hotbars = {}
				for _, Hotbar in ipairs(HotbarList.Hotbars) do
					local profile = {}
					for slot, itemType in pairs(Hotbar.Hotbar) do
						profile[tostring(slot)] = itemType
					end
					table.insert(Hotbars, profile)
				end
				local Value = {
					Selected = HotbarList.Selected,
					Hotbars = Hotbars
				}
				if not Options.SkipConfig then
					SetCfg("HotbarList", HotbarList.ConfigKey, Value)
				end
				if not Options.SkipCallback then
					RunCb("HotbarList", HotbarList.Name, HotbarList.Function, Value, HotbarList)
				end
			end

			local function SlotButton(index)
				local slotButton = Instance.new("TextButton")
				slotButton.Name = "Slot" .. index
				slotButton.Size = UDim2.fromOffset(51, 52)
				slotButton.Position = UDim2.fromOffset(89 + (index * 55), 382)
				slotButton.BackgroundColor3 = Color.Action
				slotButton.BorderSizePixel = 0
				slotButton.AutoButtonColor = false
				slotButton.Text = ""
				slotButton.ZIndex = 51
				slotButton.Parent = window

				local image = Instance.new("ImageLabel")
				image.Name = "Image"
				image.Size = UDim2.fromOffset(32, 32)
				image.Position = UDim2.new(0.5, -16, 0.5, -16)
				image.BackgroundTransparency = 1
				image.Image = ""
				image.ZIndex = 52
				image.Parent = slotButton

				local Corner = Instance.new("UICorner")
				Corner.CornerRadius = UDim.new(0, 6)
				Corner.Parent = slotButton

				local stroke = Instance.new("UIStroke")
				stroke.Color = Color.Soft
				stroke.Thickness = 2
				stroke.Enabled = index == selectedSlot
				stroke.Parent = slotButton

				slotButton.MouseButton1Click:Connect(function()
					selectedSlot = index
					RefreshSlots()
				end)
				slotButton.MouseButton2Click:Connect(function()
					local current = SelHotbar()
					if current then
						current.Hotbar[tostring(index)] = nil
						SetSlotImage(current.Object, index, nil)
						RefreshSlots()
						SaveHotbar()
					end
				end)
				slotButton.MouseEnter:Connect(function()
					TweenGui(slotButton, { BackgroundColor3 = Color.rowHover }, 0.1)
				end)
				slotButton.MouseLeave:Connect(function()
					TweenGui(slotButton, { BackgroundColor3 = Color.Action }, 0.1)
				end)
			end

			for index = 1, 9 do
				SlotButton(index)
			end

			local function ItemButton(itemType)
				local bedwarsRef = Bedwars()
				local itemMeta = bedwarsRef.ItemMeta and bedwarsRef.ItemMeta[itemType]
				if not (itemMeta and itemMeta.image) then
					return
				end

				local itemButton = Instance.new("TextButton")
				itemButton.Name = itemType
				itemButton.BackgroundColor3 = Color.Action
				itemButton.BorderSizePixel = 0
				itemButton.AutoButtonColor = false
				itemButton.Text = ""
				itemButton.ZIndex = 51
				itemButton.Parent = children

				local image = Instance.new("ImageLabel")
				image.Size = UDim2.fromOffset(32, 32)
				image.Position = UDim2.new(0.5, -16, 0.5, -16)
				image.BackgroundTransparency = 1
				image.Image = itemMeta.image
				image.ZIndex = 52
				image.Parent = itemButton

				local Corner = Instance.new("UICorner")
				Corner.CornerRadius = UDim.new(0, 6)
				Corner.Parent = itemButton

				itemButton.MouseButton1Click:Connect(function()
					local current = SelHotbar()
					if current then
						current.Hotbar[tostring(selectedSlot)] = itemType
						SetSlotImage(current.Object, selectedSlot, itemType)
						RefreshSlots()
						SaveHotbar()
					end
				end)
				itemButton.MouseEnter:Connect(function()
					TweenGui(itemButton, { BackgroundColor3 = Color.rowHover }, 0.1)
				end)
				itemButton.MouseLeave:Connect(function()
					TweenGui(itemButton, { BackgroundColor3 = Color.Action }, 0.1)
				end)
			end

			local function ClearItems()
				for _, child in ipairs(children:GetChildren()) do
					if child:IsA("TextButton") then
						child:Destroy()
					end
				end
			end

			local function SearchItems(text)
				ClearItems()
				text = tostring(text or "")
				if text == "" then
					for _, itemType in ipairs({ "diamond_sword", "diamond_pickaxe", "diamond_axe", "shears", "wood_bow", "wool_white", "fireball", "apple", "iron", "gold", "diamond", "emerald" }) do
						ItemButton(itemType)
					end
					return
				end

				local lower = text:lower()
				local bedwarsRef = Bedwars()
				for itemType in pairs(bedwarsRef.ItemMeta or {}) do
					if itemType:lower():sub(1, #lower) == lower then
						ItemButton(itemType)
					end
				end
			end

			function HotbarList:AddHotbar(hotbarData, Options)
				Options = Options or {}
				local dataCopy = {}
				for slot, itemType in pairs(hotbarData or {}) do
					dataCopy[tostring(slot)] = itemType
				end

				local hotbarDataObject = { Hotbar = dataCopy }
				table.insert(self.Hotbars, hotbarDataObject)

				local hotbarButton = Instance.new("TextButton")
				hotbarButton.Name = "HotbarProfile"
				hotbarButton.Size = UDim2.new(1, -24, 0, 27)
				hotbarButton.BackgroundColor3 = Color.Action
				hotbarButton.BorderSizePixel = 0
				hotbarButton.AutoButtonColor = false
				hotbarButton.Text = ""
				hotbarButton.ZIndex = 5
				hotbarButton.Parent = ListHolder
				hotbarDataObject.Object = hotbarButton

				local Corner = Instance.new("UICorner")
				Corner.CornerRadius = UDim.new(0, 6)
				Corner.Parent = hotbarButton

				for index = 1, 9 do
					local slot = Instance.new("ImageLabel")
					slot.Name = "Slot" .. index
					slot.Size = UDim2.fromOffset(12, 13)
					slot.Position = UDim2.fromOffset(7 + ((index - 1) * 13), 7)
					slot.BackgroundColor3 = Color.Row
					slot.BorderSizePixel = 0
					slot.Image = dataCopy[tostring(index)] and ItemIcon(dataCopy[tostring(index)]) or ""
					slot.ZIndex = 6
					slot.Parent = hotbarButton
				end

				local closeButton = Instance.new("TextButton")
				closeButton.Name = "Close"
				closeButton.Size = UDim2.fromOffset(16, 16)
				closeButton.Position = UDim2.new(1, -22, 0, 6)
				closeButton.BackgroundColor3 = Color.actionHover
				closeButton.BorderSizePixel = 0
				closeButton.AutoButtonColor = false
				closeButton.Text = "x"
				closeButton.TextSize = 9
				closeButton.TextColor3 = Color.subtle
				closeButton.Font = Enum.Font.GothamBold
				closeButton.ZIndex = 7
				closeButton.Parent = hotbarButton

				local closeCorner = Instance.new("UICorner")
				closeCorner.CornerRadius = UDim.new(1, 0)
				closeCorner.Parent = closeButton

				hotbarButton.MouseButton1Click:Connect(function()
					local index = table.find(self.Hotbars, hotbarDataObject)
					if not index then
						return
					end
					if index == self.Selected then
						SearchItems(searchBox.Text)
						window.Visible = true
						RefreshSlots()
					else
						self.Selected = index
						RefreshProfile()
						SaveHotbar()
					end
				end)

				closeButton.MouseButton1Click:Connect(function()
					local index = table.find(self.Hotbars, hotbarDataObject)
					if not index then
						return
					end
					hotbarButton:Destroy()
					table.remove(self.Hotbars, index)
					if #self.Hotbars == 0 then
						self.Selected = 1
						self:AddHotbar({}, { SkipConfig = true })
					else
						self.Selected = math.clamp(self.Selected, 1, #self.Hotbars)
					end
					RefreshProfile()
					RefreshSlots()
					UpdateHeight()
					SaveHotbar()
				end)

				if not self.Hotbars[self.Selected] then
					self.Selected = 1
				end
				RefreshProfile()
				UpdateHeight()
				if not Options.SkipConfig then
					SaveHotbar()
				end
			end

			function HotbarList:SetValue(Value, Options)
				Options = Options or {}
				for _, Hotbar in ipairs(self.Hotbars) do
					if Hotbar.Object then
						Hotbar.Object:Destroy()
					end
				end
				table.clear(self.Hotbars)

				local Hotbars = type(Value) == "table" and type(Value.Hotbars) == "table" and Value.Hotbars or defaultHotbars
				for _, Hotbar in ipairs(Hotbars) do
					self:AddHotbar(Hotbar, { SkipConfig = true })
				end
				if #self.Hotbars == 0 then
					self:AddHotbar({}, { SkipConfig = true })
				end
				self.Selected = math.clamp(tonumber(type(Value) == "table" and Value.Selected) or 1, 1, #self.Hotbars)
				RefreshProfile()
				RefreshSlots()
				UpdateHeight()
				if not Options.SkipConfig then
					SaveHotbar()
				end
			end

			addButton.MouseButton1Click:Connect(function()
				HotbarList:AddHotbar({})
			end)
			addButton.MouseEnter:Connect(function()
				TweenGui(addButton, { BackgroundColor3 = Color.actionHover }, 0.1)
				ShowTip(HotbarList.ToolTip)
			end)
			addButton.MouseLeave:Connect(function()
				TweenGui(addButton, { BackgroundColor3 = Color.Action }, 0.1)
				Fn.HideTip()
			end)
			close.MouseButton1Click:Connect(function()
				window.Visible = false
			end)
			searchBox:GetPropertyChangedSignal("Text"):Connect(function()
				SearchItems(searchBox.Text)
			end)
			grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				children.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y)
			end)
			ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateHeight)

			table.insert(self.HotbarListList, HotbarList)
			self.HotbarLists[HotbarList.Name] = HotbarList
			self:RegisterControl(HotbarList, data, false)
			SearchItems("")
			HotbarList:SetValue(GetCfg("HotbarList", HotbarList.ConfigKey, {
				Selected = 1,
				Hotbars = defaultHotbars
			}), { SkipConfig = true, SkipCallback = true })
			RefreshModule(self)
			ModuleLayout(self)
			CategorySize(self.Category)
			return HotbarList
		end

		for _, toggleData in ipairs(ModuleData.Toggles or {}) do
			module:CreateToggle(toggleData)
		end
		for _, buttonData in ipairs(ModuleData.Buttons or {}) do
			module:CreateButton(buttonData)
		end
		for _, sliderData in ipairs(ModuleData.Sliders or {}) do
			module:CreateSlider(sliderData)
		end
		for _, rangeData in ipairs(ModuleData.RangeSliders or {}) do
			module:CreateRangeSlider(rangeData)
		end
		for _, colorData in ipairs(ModuleData.ColorSliders or {}) do
			module:CreateColorSlider(colorData)
		end
		for _, dropdownData in ipairs(ModuleData.Dropdowns or {}) do
			module:CreateDropdown(dropdownData)
		end
		for _, textBoxData in ipairs(ModuleData.TextBoxes or {}) do
			module:CreateTextBox(textBoxData)
		end
		for _, hotbarListData in ipairs(ModuleData.HotbarLists or {}) do
			module:CreateHotbarList(hotbarListData)
		end
		if module.SettingsOnly then
			moduleContainer.Visible = false
			moduleContainer.Size = UDim2.new(1, 0, 0, 0)
			module.TargetHeight = 0
		end

		moduleButton.MouseButton1Click:Connect(function()
			module:Toggle()
		end)
		moduleButton.MouseButton2Click:Connect(function()
			module.Expanded = not module.Expanded
			RefreshModule(module)
			ModuleLayout(module)
			CategorySize(module.Category)
		end)
		moduleButton.MouseEnter:Connect(function()
			if not module.Enabled then
				TweenGui(moduleButton, { BackgroundColor3 = Color.rowHover }, 0.1)
			end
			ShowTip(module.ToolTip)
		end)
		moduleButton.MouseLeave:Connect(function()
			if not module.Enabled then
				TweenGui(moduleButton, { BackgroundColor3 = Color.module }, 0.1)
			end
			Fn.HideTip()
		end)
		keybindButton.MouseButton1Click:Connect(function()
			if State.KeyMod and State.KeyMod ~= module then
				State.KeyMod.WaitingForKeybind = false
				RefreshModule(State.KeyMod)
			end
			State.KeyMod = module
			module:BeginKeybindCapture()
		end)

		module:SetKeybind(GetCfg("Keybind", module.ConfigKey, nil), { SkipConfig = true })
		RefreshModule(module)

		table.insert(self.ModuleList, module)
		self.Modules[module.Name] = module
		TaskAPI.Modules[module.Name] = module
		SortModules(self)
		ModuleLayout(module)
		CategorySize(self)

		if GetCfg("Module", module.ConfigKey, false) then
			task.defer(function()
				if module.Button and module.Button.Parent then
					module:SetEnabled(true, { SkipConfig = true, SkipNotify = true })
				end
			end)
		end

		return module
	end

	self.Categories[Category.Name] = Category
	table.insert(self.CategoryList, Category)
	CatScale(Category)
	CategorySize(Category)
	RegisterBuiltIns(Category)
	return Category
end

table.insert(TaskAPI.Connections, InputService.InputBegan:Connect(function(Input, gameProcessed)
	if State.KeyMod and State.KeyMod.Button and State.KeyMod.Button.Parent then
		if Input.UserInputType == Enum.UserInputType.Keyboard then
			if Input.KeyCode == Enum.KeyCode.Escape or Input.KeyCode == Enum.KeyCode.Backspace then
				State.KeyMod:SetKeybind(nil)
			else
				State.KeyMod:SetKeybind(Input.KeyCode.Name)
			end
			State.KeyMod = nil
		end
		return
	elseif State.KeyMod then
		State.KeyMod = nil
	end

	if Input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if Input.KeyCode == Enum.KeyCode.RightShift then
		ScreenGui.Enabled = not ScreenGui.Enabled
		Blur.Enabled = ScreenGui.Enabled and Settings.Blur
		if not ScreenGui.Enabled then
			SetOpen(false)
			Fn.HideTip()
			SetCursorFree(false)
		else
			SetCursorFree(true)
		end
		return
	end

	if gameProcessed or InputReserved(Input) then
		return
	end

	for _, module in pairs(TaskAPI.Modules) do
		if type(module) == "table" and module.Keybind and module.Keybind == Input.KeyCode.Name then
			module:Toggle()
		end
	end
end))

table.insert(TaskAPI.Connections, InputService.InputChanged:Connect(function(Input)
	if State.SetDrag and IsDragPointer(Input) then
		local view = ViewSize()
		local y = math.clamp(InputY(Input), 0, view.Y - 44)
		local moved = y - State.SetDrag.StartY
		UI.SettingsHandler.Position = UDim2.new(0.5, 0, 0, y)
		if not Settings.Open and moved > 12 and not State.SetDrag.PreviewHidden then
			State.SetDrag.PreviewHidden = true
			HandleShape(true)
			SetOpen(true)
			State.SetDrag = nil
		elseif not Settings.Open and moved <= 12 and State.SetDrag.PreviewHidden then
			State.SetDrag.PreviewHidden = false
			HandleShape(false)
			HideCats(false)
		end
		if State.SetDrag and Settings.Open then
			UI.SettingsHolder.Position = UDim2.new(0.5, 0, 0, math.max(20, y + 36))
		end
	elseif State.ActSlider and IsDragPointer(Input) then
		local Track = State.ActSlider.Track
		local percent = math.clamp((Input.Position.X - Track.AbsolutePosition.X) / math.max(Track.AbsoluteSize.X, 1), 0, 1)
		State.ActSlider:SetValue(State.ActSlider.Min + (State.ActSlider.Max - State.ActSlider.Min) * percent)
	elseif State.ActDrag and Input.UserInputType == Enum.UserInputType.MouseMovement and not Settings.Open then
		local delta = Input.Position - State.ActDrag.DragStart
		State.ActDrag.ContainerFrame.Position = UDim2.new(
			State.ActDrag.StartPosition.X.Scale,
			State.ActDrag.StartPosition.X.Offset + delta.X,
			State.ActDrag.StartPosition.Y.Scale,
			State.ActDrag.StartPosition.Y.Offset + delta.Y
		)
	elseif State.Tip then
		MoveTip(Input.Position)
	end
end))

table.insert(TaskAPI.Connections, InputService.InputEnded:Connect(function(Input)
	if IsPointer(Input) then
		if State.SetDrag then
			local view = ViewSize()
			local inputY = InputY(Input)
			local moved = math.abs(inputY - State.SetDrag.StartY)
			if Settings.Open then
				SetOpen(not (inputY < 28 or moved < 3))
			else
				local shouldOpen = (inputY - State.SetDrag.StartY) > 12
				SetOpen(shouldOpen)
				if not shouldOpen then
					HandleShape(false)
					HideCats(false)
				end
			end
			State.SetDrag = nil
		end
		State.ActSlider = nil
		State.ActDrag = nil
	end
end))

table.insert(TaskAPI.Connections, RunService.RenderStepped:Connect(function()
	local wantsCursorFree = ScreenGui.Enabled or State.SetDrag ~= nil or State.KeyMod ~= nil
	if wantsCursorFree then
		SetCursorFree(true)
	elseif CursorState.Active then
		SetCursorFree(false)
	end
	local gradientOffset = tick() * Settings.RainbowSpeed
	for _, Category in ipairs(TaskAPI.CategoryList) do
		Fn.RefreshCatGrads(Category, gradientOffset)
	end
	if State.ArrayEnabled then
		RebuildArray()
		Fn.UpdateArrayColors(gradientOffset)
	end
	if Settings.Open and State.SetRowsDirty and Fn.RefreshSetRows then
		Fn.RefreshSetRows()
	end
end))

function TaskAPI:Shutdown()
	if self.Unloaded then
		return
	end
	self.Unloaded = true

	if self.Config and type(self.Config.Flush) == "function" then
		pcall(function()
			self.Config:Flush()
		end)
	end
	if self.Visuals and type(self.Visuals.SetArrayListEnabled) == "function" then
		self.Visuals.SetArrayListEnabled(false)
	end
	SetCursorFree(false)
	RestoreViewmodel()
	RestoreLighting()
	Disconnect(self)
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
	if self.NotificationGui then
		self.NotificationGui:Destroy()
	end
	if self.BlurEffect then
		self.BlurEffect:Destroy()
	end
	if getgenv().TaskAPI == self then
		getgenv().TaskAPI = nil
	end
	if getgenv().Taskium and getgenv().Taskium.API == self then
		getgenv().Taskium.API = nil
	end
end

State.Ready = true

return TaskAPI
