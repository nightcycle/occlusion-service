--!strict
-- Services
-- Packages
local OcclusionService = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("package"))
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Maid"))

-- Modules
-- Types
type Maid = Maid.Maid

-- Constants
-- Variables
-- References
-- Private Functions
-- Class
task.wait(5)
OcclusionService.init(Maid.new())
