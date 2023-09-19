--!strict
local _Package = script
local _Packages = _Package.Parent

-- Services
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Packages
local OcclusionCamera =require(_Packages:WaitForChild("OcclusionCamera"))
local Maid = require(_Packages:WaitForChild("Maid"))
local ServiceProxy = require(_Packages:WaitForChild("ServiceProxy"))

-- Modules

-- Types
type Maid = Maid.Maid
export type OcclusionCamera = OcclusionCamera.OcclusionCamera
export type OcclusionService = {
	__index: OcclusionService,
	_Maid: Maid,
	_IsAlive: boolean,
	_Visibility: {[BasePart]: boolean},
	_Dependencies: {[BasePart]: {[number]: Instance}},
	_Shadows: {[BasePart]: {[number]: Instance}},
	_OcclusionCamera: OcclusionCamera,
	_RegionPartTag: string,
	_Radius: number,
	WorldRoot: WorldRoot,
	QueryRadiusOnMovementOnly: boolean,
	RegisterRegionPart: (self: OcclusionService, part: BasePart, dependents: {[number]: Instance}, shadows: {[number]: Instance}) -> (),
	DeregisterRegionPart: (self: OcclusionService, part: BasePart) -> (),
	SetRadius: (self: OcclusionService, radius: number) -> (),
	SetRegionPartTag: (self: OcclusionService, tag: string) -> (),
	_HidePart: (self: OcclusionService, part: BasePart) -> (),
	_LoadPart: (self: OcclusionService, part: BasePart) -> (),
	Destroy: (self: OcclusionService) -> (),
	new: () -> OcclusionService,
	init: (maid: Maid) -> nil
}

-- Constants
local ORIGINAL_PARENT_OBJ_NAME = "OcclusionServiceParentReference"
local DEBUG_HIGHLIGHT_ENABLED = true
-- Variables
-- References
-- Private Functions

-- Class
local CurrentOcclusionService: OcclusionService = nil :: any
local OcclusionService = {} :: OcclusionService
OcclusionService.__index = OcclusionService

function OcclusionService:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false
	if CurrentOcclusionService == self then
		CurrentOcclusionService = nil :: any
	end
	for k, _ in pairs(self._Dependencies) do
		self:DeregisterRegionPart(k)
	end
	self._Maid:Destroy()
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

function OcclusionService:_HidePart(part: BasePart)
	if self._Visibility[part] == false then return end
	if DEBUG_HIGHLIGHT_ENABLED then
		print(`hiding {part}`)
	end
	self._Visibility[part] = false
	part.Transparency = 1
	local dependents = self._Dependencies[part]
	if dependents then
		for i, inst in ipairs(dependents) do
			if inst:FindFirstChild(ORIGINAL_PARENT_OBJ_NAME) then
				inst.Parent = nil
			end
		end
	end

	local shadows = self._Shadows[part]
	if shadows then
		for i, inst in ipairs(shadows) do
			inst.Parent = workspace
		end
	end
end

function OcclusionService:_LoadPart(part: BasePart)
	if self._Visibility[part] == true then return end
	self._Visibility[part] = true
	if DEBUG_HIGHLIGHT_ENABLED then
		print(`loading {part}`)
	end
	part.Transparency = 0
	local dependents = self._Dependencies[part]
	if dependents then
		for i, inst in ipairs(dependents) do
			local parValue = inst:FindFirstChild(ORIGINAL_PARENT_OBJ_NAME)
			if parValue then
				assert(parValue:IsA("ObjectValue"))
				inst.Parent = parValue.Value
			end
		end
	end

	
	local shadows = self._Shadows[part]
	if shadows then
		for i, inst in ipairs(shadows) do
			inst.Parent = nil
		end
	end
end

function OcclusionService:SetRegionPartTag(tag: string)
	for k, _ in pairs(self._Dependencies) do
		assert(CollectionService:HasTag(k, tag), `registered region part {k:GetFullName()} is missing new tag {tag}`)
	end
	self._RegionPartTag = tag
end

function OcclusionService:SetRadius(radius: number)
	self._Radius = radius
	self._OcclusionCamera.MaxRenderDistance = radius
end

function OcclusionService:RegisterRegionPart(part: BasePart, dependents: {[number]: Instance}, shadows: {[number]: Instance})
	assert(CollectionService:HasTag(part, self._RegionPartTag), `region part {part:GetFullName()} doesn't have region tag {self._RegionPartTag}`)
	
	if self._Dependencies[part] ~= nil then warn(`part {part:GetFullName()} is already registered`); return end

	self._Dependencies[part] = table.clone(dependents)
	self._Shadows[part] = table.clone(shadows)

	for i, v in ipairs(self._Dependencies[part]) do
		local parentRef = Instance.new("ObjectValue")
		parentRef.Name = ORIGINAL_PARENT_OBJ_NAME
		parentRef.Archivable = false
		parentRef.Value = v.Parent
		parentRef.Parent = v
	end
	for i, v in ipairs(self._Shadows[part]) do
		v.Parent = nil
	end

	self._Visibility[part] = true
	if not self._OcclusionCamera:GetIfPartIsVisible(part) then
		self:_HidePart(part)
	end
end

function OcclusionService:DeregisterRegionPart(part: BasePart)
	self:_LoadPart(part)
	local dependents = self._Dependencies[part]
	if dependents then
		for i, v in ipairs(dependents) do
			local parValue = v:FindFirstChild(ORIGINAL_PARENT_OBJ_NAME)
			if parValue then
				parValue:Destroy()
			end
		end
		table.clear(dependents)
	end

	local shadows = self._Shadows[part]
	if shadows then
		table.clear(shadows)
	end

	self._Shadows[part] = nil
	self._Visibility[part] = nil
	self._Dependencies[part] = nil
end

function OcclusionService.new()

	local self: OcclusionService = setmetatable({}, OcclusionService) :: any
	self._IsAlive = true
	self._Maid = Maid.new()
	self.WorldRoot = workspace

	self._OcclusionCamera = self._Maid:GiveTask(OcclusionCamera.new(workspace.CurrentCamera))
	self._OcclusionCamera.RaycastParams.FilterType = Enum.RaycastFilterType.Include
	self._OcclusionCamera.RaycastParams.FilterDescendantsInstances = {}

	self._Visibility = {}
	self._Dependencies = {}
	self.QueryRadiusOnMovementOnly = true
	self._RegionPartTag = "OcclusionRegionPart"
	self._Radius = 512

	local highlights: {[BasePart]: Highlight} = {}
	if DEBUG_HIGHLIGHT_ENABLED then
		self._Maid:GiveTask(function()
			for k, v in pairs(highlights) do
				highlights[k] = nil
				v:Destroy()
			end
		end)
	
	end

	if DEBUG_HIGHLIGHT_ENABLED then

		self._Maid:GiveTask(self._OcclusionCamera.OnPartEnterFrustum:Connect(function(part: BasePart)
			if not highlights[part] then
				local box = Instance.new("Highlight")
				box.Adornee = part
				box.FillTransparency = 0.5
				box.Enabled = false
				box.FillColor = Color3.new(1,1,1)
				box.OutlineColor = box.FillColor
				box.DepthMode = Enum.HighlightDepthMode.Occluded
				box.Parent = part
				highlights[part] = box
			end
		end))

	end

	self._Maid:GiveTask(self._OcclusionCamera.OnObscurePart:Connect(function(part: BasePart)
		if DEBUG_HIGHLIGHT_ENABLED then
			local box = highlights[part]
			if box then
				box.OutlineColor = Color3.new(0,0,1)
				box.Enabled = true
				box.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				box.FillColor = box.OutlineColor
			end
		end
		self:_HidePart(part)
	end))
	self._Maid:GiveTask(self._OcclusionCamera.OnViewPart:Connect(function(part: BasePart)
		if DEBUG_HIGHLIGHT_ENABLED then
			local box = highlights[part]
			if box then
				box.OutlineColor = Color3.new(1,0,0)
				box.Enabled = false
				box.DepthMode = Enum.HighlightDepthMode.Occluded
				box.FillColor = box.OutlineColor
			end
		end
		self:_LoadPart(part)
	end))
	self._Maid:GiveTask(self._OcclusionCamera.OnPartExitFrustum:Connect(function(part: BasePart)
		if DEBUG_HIGHLIGHT_ENABLED then
			local box = highlights[part]
			if box then
				box:Destroy()
				highlights[part] = nil
			end
		end
		self:_HidePart(part)
	end))
	
	local position: Vector3?
	self._Maid:GiveTask(RunService.RenderStepped:Connect(function(deltaTime: number)
		local origin = self._OcclusionCamera.Instance.CFrame.Position
		self._OcclusionCamera.OnlyUpdateOnCameraMove = self.QueryRadiusOnMovementOnly
		self._OcclusionCamera.WorldRoot = self.WorldRoot
		if position ~= origin or self.QueryRadiusOnMovementOnly == false then
			position = origin

			local overlapParams = OverlapParams.new()
			overlapParams.FilterDescendantsInstances = CollectionService:GetTagged(self._RegionPartTag)
			overlapParams.FilterType = Enum.RaycastFilterType.Include
			overlapParams.RespectCanCollide = false

			local regionParts: {[number]: Instance} = self.WorldRoot:GetPartBoundsInRadius(origin, self._Radius, overlapParams) :: any
			self._OcclusionCamera.RaycastParams.FilterDescendantsInstances = regionParts
		end
	end))

	if CurrentOcclusionService ~= nil then
		 CurrentOcclusionService:Destroy()
		 CurrentOcclusionService = nil :: any
	end
	CurrentOcclusionService = self

	return self
end

function OcclusionService.init(maid: Maid)
	print(`booting {script.Name}`)
	maid:GiveTask(OcclusionService.new())
	return nil
end

return ServiceProxy(function()
	return CurrentOcclusionService or OcclusionService
end)