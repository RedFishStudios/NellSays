-- Tiny declarative UI helper + shared look.
local Ui = {}

Ui.Theme = {
	Bg = Color3.fromRGB(16, 14, 18),
	Panel = Color3.fromRGB(28, 24, 30),
	Panel2 = Color3.fromRGB(44, 38, 46),
	Text = Color3.fromRGB(240, 232, 214),
	Dim = Color3.fromRGB(170, 160, 150),
	Accent = Color3.fromRGB(214, 168, 86),
	Good = Color3.fromRGB(110, 210, 120),
	Bad = Color3.fromRGB(230, 80, 70),
	Nell = Color3.fromRGB(255, 214, 150),
	Font = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBlack,
	Mono = Enum.Font.Code,
}

function Ui.new(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		elseif type(k) == "number" then
			-- ignore
		else
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if inst:IsA("GuiObject") and props and props.BorderSizePixel == nil then
		inst.BorderSizePixel = 0
	end
	inst.Parent = parent
	return inst
end

function Ui.corner(r)
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

function Ui.stroke(color, thickness, transparency)
	return Ui.new(
		"UIStroke",
		{ Color = color or Color3.new(0, 0, 0), Thickness = thickness or 1, Transparency = transparency or 0 }
	)
end

function Ui.pad(px)
	return Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function Ui.list(dir, gap, align)
	return Ui.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function Ui.label(props)
	local p = {
		BackgroundTransparency = 1,
		Font = Ui.Theme.Font,
		TextColor3 = Ui.Theme.Text,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return Ui.new("TextLabel", p)
end

function Ui.button(props, onClick)
	local p = {
		BackgroundColor3 = Ui.Theme.Panel2,
		Font = Ui.Theme.Bold,
		TextColor3 = Ui.Theme.Text,
		TextSize = 18,
		AutoButtonColor = true,
		Size = UDim2.new(0, 160, 0, 40),
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	local b = Ui.new("TextButton", p, { Ui.corner(8) })
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

return Ui
