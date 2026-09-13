return function(Menu)
    local Library = Menu.Library
    local Images = Menu.Images
    local Flags = Menu.Flags

    local NewUDim2 = UDim2.new
    local Find = table.find

    local WindowThemes = Library:Window({
        Name = "Themes",
        Size = Vector2.new(450, 274),
        Bind = false,
        Visible = false,
        HasTabs = false,
    })
    
    local Images = Menu.Images
    local ThemeBar
    ThemeBar = WindowThemes:Bar({
                Side = "Fill",
                ButtonsSide = "Center",
                Buttons = {
                    {
                        "Default.json",
                        function(Value)
                            Menu.ConfigTheme("Load", Value)
    
    
    
                            Flags["Menu Outline Color"].FromRGB(Menu.Theme.Outline, false)
    
                            Flags["Accent Color"].FromRGB(Menu.Theme.Accent.A, false)
    
                            Flags["Indev Color"].FromRGB(Menu.Theme.Indev, false)
                            Flags["Unsafe Color"].FromRGB(Menu.Theme.Unsafe, false)
                            Flags["Blocked Color"].FromRGB(Menu.Theme.Blocked, false)
    
                            Flags["Tree Outline Color"].FromRGB(Menu.Theme.Tree.Outline, false)
                            Flags["Tree Active Color"].FromRGB(Menu.Theme.Tree.Active, false)
                            Flags["Tree Inactive Color"].FromRGB(Menu.Theme.Tree.Inactive, false)
    
                            Flags["Toggle Outline Color"].FromRGB(Menu.Theme.Toggle.Outline, false)
                            Flags["Toggle Active Color"].FromRGB(Menu.Theme.Toggle.Active, false)
                            Flags["Toggle Inactive Color"].FromRGB(Menu.Theme.Toggle.Inactive, false)
    
                            Flags["Slider Background Color"].FromRGB(Menu.Theme.Slider.Background, false)
                            Flags["Slider Fill Color"].FromRGB(Menu.Theme.Slider.Fill, false)
    
                            Flags["Dropdown Outline Color"].FromRGB(Menu.Theme.Dropdown.Outline, false)
                            Flags["Dropdown Gradient A"].FromRGB(Menu.Theme.Dropdown["Gradient A"], false)
                            Flags["Dropdown Gradient B"].FromRGB(Menu.Theme.Dropdown["Gradient B"], false)
    
                            Flags["TextBox Outline Color"].FromRGB(Menu.Theme.TextBox.Outline, false)
                            Flags["TextBox Inline Color"].FromRGB(Menu.Theme.TextBox.Inline, false)
                            Flags["TextBox Background Color"].FromRGB(Menu.Theme.TextBox.Background, false)
    
                            Flags["Button Outline Color"].FromRGB(Menu.Theme.Button.Outline, false)
                            Flags["Button Gradient A"].FromRGB(Menu.Theme.Button["Gradient A"], false)
                            Flags["Button Gradient B"].FromRGB(Menu.Theme.Button["Gradient B"], false)
    
                            Flags["Keybind Background Color"].FromRGB(Menu.Theme.Keybind.Background, false)
    
                            Flags["Contrast Color A"].FromRGB(Menu.Theme.Contrast.A, false)
                            Flags["Contrast Color B"].FromRGB(Menu.Theme.Contrast.B, false)
                            Flags["Contrast Color C"].FromRGB(Menu.Theme.Contrast.C, false)
                            Flags["Contrast Color D"].FromRGB(Menu.Theme.Contrast.D, false)
    
                            Flags["Text Color A"].FromRGB(Menu.Theme["Text Color"].A, false)
                            Flags["Text Color B"].FromRGB(Menu.Theme["Text Color"].B, false)
    
                            Flags["Text Stroke"].Set(Menu.Theme["Text Stroke"].Enabled, false)
                            Flags["Text Stroke Color"].FromRGB(Menu.Theme["Text Stroke"].Color, false)
                        end,
                        "Dropdown",
                        Menu.ConfigTheme("List"),
                        80
                    },
    
                    {
                        "Save",
                        function()
                            local String = ThemeBar.Buttons[1].GetChosen()
    
                            if String then
                                Menu.ConfigTheme("Save", String)
                            end
                        end
                    },
    
                    {
                        "Refresh",
                        function()
                            local Button = ThemeBar.Buttons[1]
                            local Choice = Button.GetChosen()
    
                            local NewTheme = Menu.ConfigTheme("List")
    
                            Button.Options = NewTheme
    
                            Button.Close()
    
                            if not Find(NewTheme, Choice) then
                                local First = NewTheme[1]
    
                                if First then
                                    Button.SetValue(First)
                                else
                                    Button.SetValue("Default.json")
                                end
                            else
                                Button.SetValue(Choice)
                            end
                        end
                    }
                }
            })
    
            local Tree
            local SecThemes = WindowThemes:ContentBox({
                Side = "Fill",
                Offset = -2,
                Size = 216
            })
            do
                SecThemes:Label({
                    Text = "Outline",
                    Icon = { Images["Palette Icon"], NewUDim2(0, 3, 0, 1), NewUDim2(0, 9, 0, 9) }
                }):Colorpicker({
                    Color = Menu.Theme.Outline,
                    Flag = "Menu Outline Color",
                    Side = "Left",
                    Exclude = true,
                    Callback = function(Color)
                        Menu.Theme.Outline = Color
    
                        Library:SetTheme(nil, { "Outline" })
                    end
                })
    
                SecThemes:Label({
                    Text = "Accent",
                    Icon = { Images["Palette Icon"], NewUDim2(0, 3, 0, 1), NewUDim2(0, 9, 0, 9) }
                }):Colorpicker({
                    Color = Menu.Theme.Accent.A,
                    Flag = "Accent Color",
                    Side = "Left",
                    Exclude = true,
                    Callback = function(Color)
                        Menu.Theme.Accent = Menu.GetAccents(Color)
    
                        Library:SetTheme(nil, { "Accent" })
                    end
                })
    
                SecThemes:Label({
                    Text = "Indev",
                    Icon = { Images["Palette Icon"], NewUDim2(0, 3, 0, 1), NewUDim2(0, 9, 0, 9) }
                }):Colorpicker({
                    Color = Menu.Theme.Indev,
                    Flag = "Indev Color",
                    Side = "Left",
                    Exclude = true,
                    Callback = function(Color)
                        Menu.Theme.Indev = Color
    
                        Library:SetTheme(nil, { "Indev" })
                    end
                })
    
                SecThemes:Label({
                    Text = "Unsafe",
                    Icon = { Images["Palette Icon"], NewUDim2(0, 3, 0, 1), NewUDim2(0, 9, 0, 9) }
                }):Colorpicker({
                    Color = Menu.Theme.Unsafe,
                    Flag = "Unsafe Color",
                    Side = "Left",
                    Exclude = true,
                    Callback = function(Color)
                        Menu.Theme.Unsafe = Color
    
                        Library:SetTheme(nil, { "Unsafe" })
                    end
                })
    
                SecThemes:Label({
                    Text = "Blocked",
                    Icon = { Images["Palette Icon"], NewUDim2(0, 3, 0, 1), NewUDim2(0, 9, 0, 9) }
                }):Colorpicker({
                    Color = Menu.Theme.Blocked,
                    Flag = "Blocked Color",
                    Side = "Left",
                    Exclude = true,
                    Callback = function(Color)
                        Menu.Theme.Blocked = Color
    
                        Library:SetTheme(nil, { "Blocked" })
                    end
                })
    
                Tree = SecThemes:ExpandableLabel({
                    Text = "Tree",
                    Icon = { Images["Folder Icon"], NewUDim2(0, 3, 0, 2), NewUDim2(0, 8, 0, 7) },
                    Size = 40
                })
                do
                    Tree:Label({
                        Text = "Outline"
                    }):Colorpicker({
                        Color = Menu.Theme.Tree.Outline,
                        Flag = "Tree Outline Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Tree.Outline = Color
    
                            Library:SetTheme(nil, { "Tree" }, { "Outline" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Active"
                    }):Colorpicker({
                        Color = Menu.Theme.Tree.Active,
                        Flag = "Tree Active Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Tree.Active = Color
    
                            Library:SetTheme(nil, { "Tree" }, { "Active" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Inactive"
                    }):Colorpicker({
                        Color = Menu.Theme.Tree.Inactive,
                        Flag = "Tree Inactive Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Tree.Inactive = Color
    
                            Library:SetTheme(nil, { "Tree" }, { "Inactive" })
                        end
                    })
                end
    
                Tree = SecThemes:ExpandableLabel({
                    Text = "Toggle",
                    Icon = { Images["Folder Icon"], NewUDim2(0, 3, 0, 2), NewUDim2(0, 8, 0, 7) },
                    Size = 40
                })
                do
                    Tree:Label({
                        Text = "Outline"
                    }):Colorpicker({
                        Color = Menu.Theme.Toggle.Outline,
                        Flag = "Toggle Outline Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Toggle.Outline = Color
    
                            Library:SetTheme(nil, { "Toggle" }, { "Outline" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Active"
                    }):Colorpicker({
                        Color = Menu.Theme.Toggle.Active,
                        Flag = "Toggle Active Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Toggle.Active = Color
    
                            Library:SetTheme(nil, { "Toggle" }, { "Active" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Inactive"
                    }):Colorpicker({
                        Color = Menu.Theme.Toggle.Inactive,
                        Flag = "Toggle Inactive Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Toggle.Inactive = Color
    
                            Library:SetTheme(nil, { "Toggle" }, { "Inactive" })
                        end
                    })
                end
    
                Tree = SecThemes:ExpandableLabel({
                    Text = "Slider",
                    Icon = { Images["Folder Icon"], NewUDim2(0, 3, 0, 2), NewUDim2(0, 8, 0, 7) },
                    Size = 28
                })
                do
                    Tree:Label({
                        Text = "Background"
                    }):Colorpicker({
                        Color = Menu.Theme.Slider.Background,
                        Flag = "Slider Background Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Slider.Background = Color
    
                            Library:SetTheme(nil, { "Slider" }, { "Background" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Fill"
                    }):Colorpicker({
                        Color = Menu.Theme.Slider.Fill,
                        Flag = "Slider Fill Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Slider.Fill = Color
    
                            Library:SetTheme(nil, { "Slider" }, { "Fill" })
                        end
                    })
                end
    
                Tree = SecThemes:ExpandableLabel({
                    Text = "Dropdown",
                    Icon = { Images["Folder Icon"], NewUDim2(0, 3, 0, 2), NewUDim2(0, 8, 0, 7) },
                    Size = 40
                })
                do
                    Tree:Label({
                        Text = "Outline"
                    }):Colorpicker({
                        Color = Menu.Theme.Dropdown.Outline,
                        Flag = "Dropdown Outline Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Dropdown.Outline = Color
    
                            Library:SetTheme(nil, { "Dropdown" }, { "Outline" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Gradient A"
                    }):Colorpicker({
                        Color = Menu.Theme.Dropdown["Gradient A"],
                        Flag = "Dropdown Gradient A",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Dropdown["Gradient A"] = Color
    
                            Library:SetTheme(nil, { "Dropdown" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Gradient B"
                    }):Colorpicker({
                        Color = Menu.Theme.Dropdown["Gradient B"],
                        Flag = "Dropdown Gradient B",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Dropdown["Gradient B"] = Color
    
                            Library:SetTheme(nil, { "Dropdown" })
                        end
                    })
                end
    
                Tree = SecThemes:ExpandableLabel({
                    Text = "Text Box",
                    Icon = { Images["Folder Icon"], NewUDim2(0, 3, 0, 2), NewUDim2(0, 8, 0, 7) },
                    Size = 40
                })
                do
                    Tree:Label({
                        Text = "Outline"
                    }):Colorpicker({
                        Color = Menu.Theme.TextBox.Outline,
                        Flag = "TextBox Outline Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.TextBox.Outline = Color
    
                            Library:SetTheme(nil, { "TextBox" }, { "Outline" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Inline"
                    }):Colorpicker({
                        Color = Menu.Theme.TextBox.Inline,
                        Flag = "TextBox Inline Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.TextBox.Inline = Color
    
                            Library:SetTheme(nil, { "TextBox" }, { "Inline" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Background"
                    }):Colorpicker({
                        Color = Menu.Theme.TextBox.Background,
                        Flag = "TextBox Background Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.TextBox.Background = Color
    
                            Library:SetTheme(nil, { "TextBox" }, { "Background" })
                        end
                    })
                end
    
                Tree = SecThemes:ExpandableLabel({
                    Text = "Button",
                    Icon = { Images["Folder Icon"], NewUDim2(0, 3, 0, 2), NewUDim2(0, 8, 0, 7) },
                    Size = 40
                })
                do
                    Tree:Label({
                        Text = "Outline"
                    }):Colorpicker({
                        Color = Menu.Theme.Button.Outline,
                        Flag = "Button Outline Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Button.Outline = Color
    
                            Library:SetTheme(nil, { "Button" }, { "Outline" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Gradient A"
                    }):Colorpicker({
                        Color = Menu.Theme.Button["Gradient A"],
                        Flag = "Button Gradient A",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Button["Gradient A"] = Color
    
                            Library:SetTheme(nil, { "Button" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Gradient B"
                    }):Colorpicker({
                        Color = Menu.Theme.Button["Gradient B"],
                        Flag = "Button Gradient B",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Button["Gradient B"] = Color
    
                            Library:SetTheme(nil, { "Button" })
                        end
                    })
                end
    
                Tree = SecThemes:ExpandableLabel({
                    Text = "Keybind",
                    Icon = { Images["Folder Icon"], NewUDim2(0, 3, 0, 2), NewUDim2(0, 8, 0, 7) },
                    Size = 16
                })
                do
                    Tree:Label({
                        Text = "Background"
                    }):Colorpicker({
                        Color = Menu.Theme.Keybind.Background,
                        Flag = "Keybind Background Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Keybind.Background = Color
    
                            Library:SetTheme(nil, { "Keybind" }, { "Background" })
                        end
                    })
                end
    
                Tree = SecThemes:ExpandableLabel({
                    Text = "Contrast",
                    Icon = { Images["Folder Icon"], NewUDim2(0, 3, 0, 2), NewUDim2(0, 8, 0, 7) },
                    Size = 52
                })
                do
                    Tree:Label({
                        Text = "Color A"
                    }):Colorpicker({
                        Color = Menu.Theme.Contrast.A,
                        Flag = "Contrast Color A",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Contrast.A = Color
    
                            Library:SetTheme(nil, { "Contrast" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Color B"
                    }):Colorpicker({
                        Color = Menu.Theme.Contrast.B,
                        Flag = "Contrast Color B",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Contrast.B = Color
    
                            Library:SetTheme(nil, { "Contrast" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Color C"
                    }):Colorpicker({
                        Color = Menu.Theme.Contrast.C,
                        Flag = "Contrast Color C",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme.Contrast.C = Color
    
                            Library:SetTheme(nil, { "Custom Gradient", "Contrast" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Color D"
                    }):Colorpicker({
                        Color = Menu.Theme.Contrast.D,
                        Flag = "Contrast Color D",
                        Side = "Left",
                        Exclude = true,
    
                        Callback = function(Color)
                            Menu.Theme.Contrast.D = Color
    
                            Library:SetTheme(nil, { "Custom Gradient", "Contrast" })
                        end
                    })
                end
    
                Tree = SecThemes:ExpandableLabel({
                    Text = "Text Color",
                    Icon = { Images["Folder Icon"], NewUDim2(0, 3, 0, 2), NewUDim2(0, 8, 0, 7) },
                    Size = 28
                })
                do
                    Tree:Label({
                        Text = "Color A"
                    }):Colorpicker({
                        Color = Menu.Theme["Text Color"].A,
                        Flag = "Text Color A",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme["Text Color"].A = Color
    
                            Library:SetTheme(nil, { "Text Color" }, { "A" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Color B"
                    }):Colorpicker({
                        Color = Menu.Theme["Text Color"].B,
                        Flag = "Text Color B",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme["Text Color"].B = Color
    
                            Library:SetTheme(nil, { "Text Color" }, { "B" })
                        end
                    })
                end
    
                Tree = SecThemes:ExpandableLabel({
                    Text = "Text Outlines",
                    Icon = { Images["Folder Icon"], NewUDim2(0, 3, 0, 2), NewUDim2(0, 8, 0, 7) },
                    Size = 29
                })
                do
                    Tree:Toggle({
                        Text = "Enabled",
                        Flag = "Text Stroke",
                        Exclude = true,
                        Default = Menu.Theme["Text Stroke"].Enabled,
                        Callback = function(Value)
                            Menu.Theme["Text Stroke"].Enabled = Value
    
                            Library:SetTheme(nil, { "Text Stroke" }, { "Enabled" })
                        end
                    })
    
                    Tree:Label({
                        Text = "Color"
                    }):Colorpicker({
                        Color = Menu.Theme["Text Stroke"].Color,
                        Flag = "Text Stroke Color",
                        Side = "Left",
                        Exclude = true,
                        Callback = function(Color)
                            Menu.Theme["Text Stroke"].Color = Color
    
                            Library:SetTheme(nil, { "Text Stroke" }, { "Color" })
                        end
                    })
                end
            end
    
    

    return WindowThemes
end
