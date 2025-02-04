print("FrostDK.lua загружен")  -- Отладочное сообщение

FrostDK = {
    lastUpdate = 0,
    cooldowns = {
        mindFreeze       = "Заморозка разума",
        icyTouch         = "Ледяное прикосновение",
        plagueStrike     = "Удар чумы",
        obliterate       = "Уничтожение",
        frostStrike      = "Ледяной удар",
        howlingBlast     = "Воющий ветер",
        bloodStrike      = "Кровавый удар",
        hornOfWinter     = "Зимний горн",
        bloodTap         = "Кровоотвод",
        unbreakableArmor = "Несокрушимая броня"
    }
}

function FrostDK:Execute(elapsed)
    if not UnitAffectingCombat("player") then return end
    if UnitIsDeadOrGhost("player") then return end
    if not UnitExists("target") or UnitIsDead("target") then return end

    self.lastUpdate = self.lastUpdate + elapsed
    if self.lastUpdate < 0.3 then return end
    self.lastUpdate = 0

    local script = ""
    local debugMsg = ""

    -- 1. Прерывание кастов
    local castingInfo = {UnitCastingInfo("target")}
    if castingInfo[9] == false then
        script = script .. "SpellStopCasting()\n"
        script = script .. self:GenerateScript("true", self.cooldowns.mindFreeze)
        debugMsg = "Прерывание каста"
    end

    local channelInfo = {UnitChannelInfo("target")}
    if channelInfo[8] == false then
        script = script .. "SpellStopCasting()\n"
        script = script .. self:GenerateScript("true", self.cooldowns.mindFreeze)
        debugMsg = "Прерывание ченела"
    end

    -- 2. Логика ротации
    local vFF = select(7, UnitDebuff("target", "Озноб", nil, "PLAYER")) or 0
    vFF = vFF > 0 and (vFF - GetTime()) or 0

    -- Обновление Озноба
    if vFF <= 3.5 and vFF > 0 then
        if select(3, GetRuneCooldown(1)) or select(3, GetRuneCooldown(2)) then
            script = script .. self:GenerateScript("true", "Мор")
            debugMsg = "Обновление Озноба"
        end
    end

    -- Восполнение рун через Кровоотвод
    if (vFF - select(2, GetRuneCooldown(1)) < 2 or vFF - select(2, GetRuneCooldown(2)) < 2) and vFF <= 2 and UnitAffectingCombat("player") then
        script = script .. self:GenerateScript("true", self.cooldowns.bloodTap)
        debugMsg = "Использование Кровоотвода"
    end

    -- Наложение Озноба
    if not UnitDebuff("target", "Озноб", nil, "PLAYER") then
        if self:CanCast(self.cooldowns.icyTouch) then
            script = script .. self:GenerateScript("true", self.cooldowns.icyTouch)
            debugMsg = "Наложение Озноба"
        end
    end

    -- Наложение Кровавой чумы
    if not UnitDebuff("target", "Кровавая чума", nil, "PLAYER") then
        if self:CanCast(self.cooldowns.plagueStrike) then
            script = script .. self:GenerateScript("true", self.cooldowns.plagueStrike)
            debugMsg = "Наложение Кровавой чумы"
        end
    end

    -- Несокрушимая броня
    if GetSpellCooldown("Несокрушимая броня") == 0 then
        script = script .. self:GenerateScript("true", self.cooldowns.unbreakableArmor)
        debugMsg = "Активация Несокрушимой брони"
    end

    -- Рунический удар
    if self:CanCast(self.cooldowns.howlingBlast) and UnitPower("player") > 20 then
        script = script .. self:GenerateScript("true", self.cooldowns.howlingBlast)
        debugMsg = "Использование Рунического удара"
    end

    -- Воющий ветер
    if UnitBuff("player", "Морозная дымка") then
        if self:CanCast(self.cooldowns.howlingBlast) then
            script = script .. self:GenerateScript("true", self.cooldowns.howlingBlast)
            debugMsg = "Использование Воющего ветра"
        end
    end

    -- Уничтожение
    if self:CanCast(self.cooldowns.obliterate) then
        if (select(3, GetRuneCooldown(3)) and select(3, GetRuneCooldown(5))) or
           (select(3, GetRuneCooldown(4)) and select(3, GetRuneCooldown(6))) or
           (select(3, GetRuneCooldown(3)) and select(3, GetRuneCooldown(6))) or
           (select(3, GetRuneCooldown(4)) and select(3, GetRuneCooldown(5))) or
           (select(3, GetRuneCooldown(1)) and select(3, GetRuneCooldown(2)) and 
            GetRuneType(1) == 4 and GetRuneType(2) == 4 and vFF > 10) then
            script = script .. self:GenerateScript("true", self.cooldowns.obliterate)
            debugMsg = "Использование Уничтожения"
        end
    end

    -- Ледяной удар
    if UnitBuff("player", "Машина для убийств") then
        if self:CanCast(self.cooldowns.frostStrike) then
            script = script .. self:GenerateScript("true", self.cooldowns.frostStrike)
            debugMsg = "Использование Ледяного удара"
        end
    end

    -- Кровавый удар
    if (GetRuneType(1) == 1 or GetRuneType(2) == 1) then
        if self:CanCast(self.cooldowns.bloodStrike) and vFF > 10 then
            script = script .. self:GenerateScript("true", self.cooldowns.bloodStrike)
            debugMsg = "Использование Кровавого удара"
        end
    end

    -- Зимний горн
    if GetSpellCooldown("Зимний горн") == 0 then
        script = script .. self:GenerateScript("true", self.cooldowns.hornOfWinter)
        debugMsg = "Использование Зимнего горна"
    end

    return script, debugMsg
end

function FrostDK:GenerateScript(condition, spell)
    return string.format([[
        if %s and not UnitCastingInfo("player") then
            CastSpellByName("%s")
        end
    ]], condition, spell)
end

function FrostDK:CanCast(spellName)
    return IsUsableSpell(spellName) and 
           GetSpellCooldown(spellName) == 0 and 
           IsSpellInRange(spellName, "target") == 1
end
