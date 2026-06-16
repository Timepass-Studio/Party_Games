local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker)
type Networker = Networker.client
return function()
	print("Hello, world!")
end
