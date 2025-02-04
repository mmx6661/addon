print("|cFF00FF00RotationMaster: Core.lua загружен|r")

RotationMaster = {
    frame = nil,
    rotationFrame = nil,  -- Новый фрейм для ротации
    isEnabled = false,
    activeRotation = nil,
    minWidth = 220,
    minHeight = 220,
    debugMode = true,
    dbName = "RotationMasterDB",
    rotations = {
        DK = {
            FrostDK = "Фрост ДК",
            AnholiDK = "Анхоли ДК",
            TankAgr = "Танк (Агр)",
            TankHil = "Танк (Отхил)",
        },
        Druid = {
            BalanceDruid = "Баланс Друид",
            FeralDruid = "Кот-Друид",
            RestoDruid = "Рестор-Друид"
        }
    }
}

-- Цветные сообщения
function RotationMaster:InfoPrint(msg)
    print("|cFF00FF00" .. msg .. "|r")
end

function RotationMaster:ErrorPrint(msg)
    print("|cFFFF0000" .. msg .. "|r")
end

function RotationMaster:DebugPrint(debugMsg)
    print("|cFF00CCFF[DEBUG]|r " .. debugMsg)
end

-- Кнопка у миникарты (исправленная)
function RotationMaster:CreateMinimapButton()
    local button = CreateFrame("Button", "RotationMasterMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetPoint("CENTER", Minimap, "CENTER", -80, 0)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")

    -- Фон (Horde emblem)
    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
    button.background:SetSize(40, 40) -- Размер фона равен размеру кнопки
    button.background:SetPoint("CENTER", -4, 3) -- Центрирование фона

    -- Окантовка (стиль миникарты)
    button.border = button:CreateTexture(nil, "ARTWORK") -- Слой ARTWORK, чтобы не конфликтовать с фоном
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border:SetSize(54, 54) -- Размер окантовки
    button.border:SetPoint("CENTER", 0, 0) -- Центрирование окантовки

    -- Перемещение
    button:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local centerX, centerY = Minimap:GetCenter()
        local x, y = self:GetCenter()
        local dx, dy = x - centerX, y - centerY
        local angle = atan2(dy, dx)
        local radius = math.min(sqrt(dx^2 + dy^2), Minimap:GetWidth() * 0.6)
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", radius * cos(angle), radius * sin(angle))
    end)

    -- Обработчик нажатия
    button:SetScript("OnClick", function()
        if not RotationMaster.frame then
            RotationMaster:CreateGUI()
            RotationMaster:LoadSettings()
        end
        if RotationMaster.frame:IsShown() then
            RotationMaster.frame:Hide()
        else
            RotationMaster.frame:Show()
        end
    end)

    -- Подсказка
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText("Rotation Master")
        GameTooltip:AddLine("ЛКМ: Открыть/Закрыть окно", 1, 1, 1)
        GameTooltip:AddLine("ЛКМ + Перетаскивание: Переместить кнопку", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- GUI (главное окно)
function RotationMaster:CreateGUI()
    if self.frame then return end

    self.frame = CreateFrame("Frame", "RM_MainFrame", UIParent)
    self.frame:SetSize(self.minWidth, self.minHeight)
    self.frame:SetPoint("CENTER")
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:SetResizable(true)
    self.frame:SetMinResize(self.minWidth, self.minHeight)
    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })

    -- Заголовок
    local title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Rotation Master")

    -- Кнопка закрытия
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        self.frame:Hide()  -- Только скрывает окно
    end)

    -- Кнопки классов
    local dkButton = CreateFrame("Button", "RM_ClassButton_DK", self.frame, "UIPanelButtonTemplate")
    dkButton:SetSize(100, 25)
    dkButton:SetPoint("TOP", -50, -30)
    dkButton:SetText("DK")
    dkButton:SetScript("OnClick", function()
        self:ShowRotationList("DK")
    end)

    local druidButton = CreateFrame("Button", "RM_ClassButton_Druid", self.frame, "UIPanelButtonTemplate")
    druidButton:SetSize(100, 25)
    druidButton:SetPoint("TOP", 50, -30)
    druidButton:SetText("Druid")
    druidButton:SetScript("OnClick", function()
        self:ShowRotationList("Druid")
    end)

    -- Чекбокс отладки
    self.debugCheckbox = CreateFrame("CheckButton", "RM_DebugCheckbox", self.frame, "UICheckButtonTemplate")
    self.debugCheckbox:SetPoint("BOTTOMLEFT", 20, 40)
    self.debugCheckbox:SetChecked(self.debugMode)
    self.debugCheckbox:SetScript("OnClick", function()
        self.debugMode = self.debugCheckbox:GetChecked()
    end)

    local debugText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugText:SetPoint("LEFT", self.debugCheckbox, "RIGHT", 5, 0)
    debugText:SetText("Отладка [DEBUG]")

    -- Ресайз
    local resizeHandle = CreateFrame("Button", nil, self.frame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetScript("OnMouseDown", function()
        self.frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        self.frame:StopMovingOrSizing()
        self:SaveSettings()
    end)

    -- Обработчики перемещения окна
    self.frame:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then
            self.frame:StartMoving()
        end
    end)
    self.frame:SetScript("OnMouseUp", function()
        self.frame:StopMovingOrSizing()
        self:SaveSettings()
    end)
end

-- Ротация
function RotationMaster:StartRotation()
    if not self.rotationFrame then
        self.rotationFrame = CreateFrame("Frame", nil, UIParent)
    end
    self.rotationFrame:SetScript("OnUpdate", function(_, elapsed)
        if self.activeRotation and UnitAffectingCombat("player") then
            local script, debugMsg = self.activeRotation:Execute(elapsed)
            if script and script ~= "" then
                if self.debugMode then
                    self:DebugPrint(debugMsg)
                end
                RunScript(script)
            end
        end
    end)
end

function RotationMaster:StopRotation()
    if self.rotationFrame then
        self.rotationFrame:SetScript("OnUpdate", nil)
    end
end

function RotationMaster:ToggleRotation(rotationKey, enable)
    if enable then
        if not _G[rotationKey] then
            self:ErrorPrint("Ротация не найдена: " .. rotationKey)
            return
        end
        self.activeRotation = _G[rotationKey]
        self.isEnabled = true
        self:StartRotation()
    else
        self:StopRotation()
        self.activeRotation = nil
        self.isEnabled = false
    end
end

-- Список ротаций
function RotationMaster:ShowRotationList(class)
    if self.rotationList then
        self.rotationList:Hide()
    end

    -- Окно выбора ротаций
    self.rotationList = CreateFrame("Frame", "RM_RotationList", self.frame)
    self.rotationList:SetSize(200, 170)
    self.rotationList:SetPoint("LEFT", self.frame, "RIGHT", 10, 0)
    self.rotationList:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })

    -- Заголовок окна
    local title = self.rotationList:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Выберите ротацию")

    -- Кнопка закрытия
    local closeBtn = CreateFrame("Button", nil, self.rotationList, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        self.rotationList:Hide()
    end)

    -- Список ротаций
    local yOffset = -40
    for rotationKey, rotationName in pairs(self.rotations[class]) do
        local checkbox = CreateFrame("CheckButton", "RM_RotationCheckbox_" .. rotationKey, self.rotationList, "UICheckButtonTemplate")
        checkbox:SetSize(26, 26)
        checkbox:SetPoint("TOPLEFT", 20, yOffset)
        checkbox:SetChecked(self.activeRotation == rotationKey)
        checkbox:SetScript("OnClick", function()
            self:ToggleRotation(rotationKey, checkbox:GetChecked())
        end)

        local text = self.rotationList:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
        text:SetText(rotationName)

        yOffset = yOffset - 30
    end
end

-- Загрузка настроек
function RotationMaster:LoadSettings()
    if not _G[self.dbName] then
        _G[self.dbName] = {}
        self:InfoPrint("Настройки созданы.")
        return
    end

    local db = _G[self.dbName]

    -- Загружаем позицию окна
    if db.position then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(db.position.point, db.position.x, db.position.y)
        self.frame:SetSize(db.position.width, db.position.height)
    end

    -- Загружаем режим отладки
    if db.debugMode ~= nil then
        self.debugMode = db.debugMode
        self.debugCheckbox:SetChecked(self.debugMode)
    end
end

-- Сохранение настроек
function RotationMaster:SaveSettings()
    _G[self.dbName] = _G[self.dbName] or {}
    local db = _G[self.dbName]

    db.position = {
        point = select(1, self.frame:GetPoint()),
        x = select(2, self.frame:GetPoint()),
        y = select(3, self.frame:GetPoint()),
        width = self.frame:GetWidth(),
        height = self.frame:GetHeight()
    }

    db.debugMode = self.debugMode
end

-- Регистрация ротаций
function RotationMaster:RegisterRotations()
    for class, rotations in pairs(self.rotations) do
        for rotationKey, rotationName in pairs(rotations) do
            if not _G[rotationKey] then
                self:ErrorPrint("Ротация не найдена: " .. rotationKey)
            end
        end
    end
end

-- Инициализация
function RotationMaster:Initialize()
    self:InfoPrint("Инициализация RotationMaster...")
    self:CreateGUI()
    self:CreateMinimapButton()
    self:LoadSettings()
    self:RegisterRotations()
    self.frame:Hide()  -- По умолчанию окно скрыто
end

-- Слэш-команды
SLASH_ROTMASTER1 = "/rotmaster"
SlashCmdList["ROTMASTER"] = function()
    if RotationMaster.frame then
        RotationMaster.frame:SetShown(not RotationMaster.frame:IsShown())
    end
end

SLASH_ROTSTOP1 = "/rotstop"
SlashCmdList["ROTSTOP"] = function()
    if RotationMaster.isEnabled then
        RotationMaster:StopRotation()
        RotationMaster.isEnabled = false
        RotationMaster:InfoPrint("Ротация остановлена.")
    else
        RotationMaster:StartRotation()
        RotationMaster.isEnabled = true
        RotationMaster:InfoPrint("Ротация возобновлена.")
    end
end

SLASH_ROTSTATUS1 = "/rotstatus"
SlashCmdList["ROTSTATUS"] = function()
    if RotationMaster.isEnabled then
        RotationMaster:InfoPrint("Ротация активна: " .. RotationMaster.activeRotation.name)
    else
        RotationMaster:InfoPrint("Ротация не активна.")
    end
end

-- Запуск аддона
RotationMaster:Initialize()
