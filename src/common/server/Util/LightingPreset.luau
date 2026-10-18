--!strict
-- LightingPreset: the game's shared look: warm late-afternoon light, soft haze, gentle
-- bloom and a little extra colour. Applied by both places so travelling between them
-- feels like one world. (Lighting.Technology isn't script-settable; set it to "Future"
-- in Studio's Lighting properties for the best result.)

local Lighting = game:GetService("Lighting")

local LightingPreset = {}

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

function LightingPreset.apply()
	Lighting.ClockTime = 15.6
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(70, 66, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 136, 150)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.ShadowSoftness = 0.25

	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(214, 190, 170)
	atmosphere.Decay = Color3.fromRGB(110, 86, 120)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.4

	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.5

	local grade = ensure("ColorCorrectionEffect", "ColorGrade") :: ColorCorrectionEffect
	grade.Saturation = 0.14
	grade.Contrast = 0.07
	grade.Brightness = 0.01
	grade.TintColor = Color3.fromRGB(255, 247, 236)

	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.07
	rays.Spread = 0.6

	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof then
		dof.Enabled = false -- the template's depth of field blurs the build area
	end
end

return LightingPreset
