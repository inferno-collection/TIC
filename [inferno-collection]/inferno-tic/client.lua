-- Inferno Collection TIC Camera 1.0 Alpha
--
-- Copyright (c) 2019, Christopher M, Inferno Collection. All rights reserved.
--
-- This project is licensed under the following:
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to use, copy, modify, and merge the software, under the following conditions:
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. THE SOFTWARE MAY NOT BE SOLD.
--

--
-- Resource Configuration
-- Please note, there is also some configuration required in the `server.lua` file, so make sure to edit that file as well
--
-- PLEASE RESTART SERVER AFTER MAKING CHANGES TO THIS CONFIGURATION
--

local Config = {} -- Do not edit this line
--  Vehicles from which you can collect a TIC
Config.Vehicles = {
    "firetruk"
}
-- The model to use as the TIC
Config.TICModel = "prop_flir"
-- Animation Directory to use
Config.AnimDict = "cellphone@"
-- Animation to use
Config.AnimName = "cellphone_photo_idle"

--
--		Nothing past this point needs to be edited, all the settings for the resource are found ABOVE this line.
--		Do not make changes below this line unless you know what you are doing!
--

local UsingTIC = false
local TICActive = false
local TICCam = false
local AnimStarted = false
local AimingAnimStarted = false
local Fading = false

-- Command to store and collect a TIC from an approved vehicle
RegisterCommand("tic", function(_, Args)
    if Args[1] then
        local Action = Args[1]:lower()

        if Action == "collect" then
            if not UsingTIC then
                if TruckTest() then collectTIC() end
            else
                NewNotification("~y~You already carrying a TIC!", true)
            end
        elseif Action == "store" then
            if UsingTIC then
                if TruckTest() then storeTIC() end
            else
                NewNotification("~y~You do not have a TIC out!", true)
            end
        else
            NewNotification("~r~Invalid action! Use: 'collect' or 'store'.", true)
        end
    else
        NewNotification("~r~No action specified!", true)
    end
end)

-- Create a TIC in the player's hands
function collectTIC()
    local PlayerPed = PlayerPedId()
    UsingTIC = CreateObjectNoOffset(GetHashKey(Config.TICModel), GetEntityCoords(PlayerPed, false), true, false, false)

    ClearPedTasksImmediately(PlayerPed)
    SetEntityAsMissionEntity(UsingTIC)
    AttachEntityToEntity(UsingTIC, PlayerPed, GetEntityBoneIndexByName(PlayerPed, "BONETAG_L_HAND"), vector3(0.12, 0.0, 0.02), vector3(100.0, 0.0, 170.0), false, false, false, false, 2, true)
end

-- Delete TIC
function storeTIC()
    DeleteObject(UsingTIC)
    SetEntityAsNoLongerNeeded(UsingTIC)
    ClearPedTasksImmediately(PlayerPedId())

    UsingTIC = false
end

-- Check if there is an approved vehicle in front of the player
function TruckTest()
    local PlayerPed = PlayerPedId()
    local PlayerCoords = GetEntityCoords(PlayerPed, false)
    local RayCast = StartShapeTestRay(PlayerCoords.x, PlayerCoords.y, PlayerCoords.z, GetOffsetFromEntityInWorldCoords(PlayerPed, 0.0, 10.0, 0.0), 10, PlayerPed, 0)
    local _, _, RayCoords, _, RayEntity = GetRaycastResult(RayCast)

    if Vdist(PlayerCoords.x, PlayerCoords.y, PlayerCoords.z, RayCoords.x, RayCoords.y, RayCoords.z) < 3 then
        for _, Vehicle in ipairs(Config.Vehicles) do if GetHashKey(Vehicle) == GetEntityModel(RayEntity) then return true end end

        NewNotification("~r~This vehicle does not carry TICs!", true)
        return false
    else
        NewNotification("~r~No TIC carrying vehicle found!", true)
        return false
    end
end

-- Draws a notification on the player's screen
function NewNotification(Text, Flash)
    if not Fading then
        SetNotificationTextEntry("STRING")
        AddTextComponentString(Text)
        DrawNotification(Flash, true)
    end
end

-- Draws a hint on the player's screen
function NewHint(Text)
    if not Fading then
        SetTextComponentFormat("STRING")
        AddTextComponentString(Text)
        DisplayHelpTextFromStringLabel(0, 0, 1, -1)
    end
end

-- Master loop
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if UsingTIC then
            local PlayerPed = PlayerPedId()

            if not TICActive then
                NewHint("~INPUT_ATTACK~ Activate TIC\n~INPUT_AIM~ Aim TIC")

                if AnimStarted then
                    AnimStarted = false
                    StopAnimTask(PlayerPed, Config.AnimDict, Config.AnimName, -8.0)
                    AttachEntityToEntity(UsingTIC, PlayerPed, GetEntityBoneIndexByName(PlayerPed, "BONETAG_L_HAND"), vector3(0.12, 0.0, 0.02), vector3(100.0, 0.0, 170.0), false, false, false, false, 2, true)
                end

                if IsDisabledControlJustPressed(0, 24) then -- LMB
                    if GetFollowPedCamZoomLevel() == 4 then -- First person
                        -- First person breaks TIC Cam
                        SetFollowPedCamViewMode(1)
                        Citizen.Wait(500)
                    end

                    TICActive = true
                end

                SetCurrentPedWeapon(PlayerPed, -1569615261, true) -- Unarmed
            else
                NewHint("~INPUT_AIM~ Deactivate TIC")

                if not AnimStarted or AimingAnimStarted then
                    AnimStarted = true

                    if AimingAnimStarted then
                        -- Hides the double animation in the fade
                        Citizen.Wait(500)
                        AimingAnimStarted = false
                    end

                    if not HasAnimDictLoaded(Config.AnimDict) then
                        RequestAnimDict(Config.AnimDict)
                        while not HasAnimDictLoaded(Config.AnimDict) do Wait(0) end
                    end

                    TaskPlayAnim(PlayerPed, Config.AnimDict, Config.AnimName, 8.0, -8.0, -1, 49, 0.0, false, false, false)
                    AttachEntityToEntity(UsingTIC, PlayerPed, GetEntityBoneIndexByName(PlayerPed, "BONETAG_L_HAND"), vector3(0.12, 0.02, 0.02), vector3(0.0, 145.0, 50.0), false, false, false, false, 2, true)
                end


            end

            if TICCam then
                local CamFov = GetCamFov(TICCam)

                ClampGameplayCamPitch(-50.0, 50.0)
                ClampGameplayCamYaw(-10.0, 10.0)
                SetCamRot(TICCam, GetGameplayCamRot(2), 2)
                SetCamCoord(TICCam, GetOffsetFromEntityInWorldCoords(PlayerPed, 0.0, 0.75, 0.6))

                -- Zoom in and out
                if IsDisabledControlJustReleased(0, 14) and CamFov < 50 then -- Scroll Down
                    SetCamFov(TICCam, CamFov + 10.0)
                elseif IsDisabledControlJustReleased(0, 15) and CamFov > 20 then -- Scroll Up
                    SetCamFov(TICCam, CamFov - 10.0)
                end

                DisableControlAction(0, 0, true) -- Change camera (V)
            end

            DisableControlAction(0, 14, true) -- Scroll Down
            DisableControlAction(0, 15, true) -- Scroll Up
            DisableControlAction(0, 23, true) -- Enter vehicle
            DisableControlAction(0, 24, true) -- Attack (LMB)
            DisableControlAction(0, 25, true) -- Aim (RMB)
            DisableControlAction(0, 37, true) -- Weapon Select (Tab)
            DisableControlAction(0, 44, true) -- Take Cover (Q)
            DisableControlAction(0, 140, true) -- Attack (R)
            DisableControlAction(0, 141, true) -- Attack (Q)
            DisableControlAction(0, 142, true) -- Attack (LMB)
            DisableControlAction(0, 257, true) -- Attack (LMB)
            DisableControlAction(0, 263, true) -- Attack (R)
            DisableControlAction(0, 264, true) -- Attack (Q)
        else
            if AnimStarted then
                AnimStarted = false
                StopAnimTask(PlayerPed, Config.AnimDict, Config.AnimName, -8.0)
            end

            if TICActive then
                if TICCam then
                    RenderScriptCams(false, false, 1, true, true)
                    SetCamActive(TICCam, false)
                    DestroyCam(TICCam, false)

                    TICCam = false
                end

                SetSeethrough(false)
                DisplayCash(false) -- false = unhide
                DisplayHud(true)
                DisplayRadar(true)

                TICActive = false
            end
        end

    end
end)

-- Secondary loop
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if UsingTIC and TICActive and TICActive ~= "set" then
            Fading = true
            DoScreenFadeOut(500)
            Citizen.Wait(500)

            SetSeethrough(true)
            SeethroughSetHeatscale(2, 0.3)
            SeethroughSetNoiseAmountMin(0.0)
            SeethroughSetNoiseAmountMax(0.0)
            SeethroughSetFadeStartDistance(100.0)
            SeethroughSetFadeEndDistance(300.0)
            SeethroughSetHiLightIntensity(1.0)
            SeethroughSetColorNear(105.0, 105.0, 105.0)

            TICCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", GetOffsetFromEntityInWorldCoords(PlayerPed, 0.0, 0.75, 0.6), 0.0, 0.0, 0.0, 60.0, false, 0)
            SetCamActive(TICCam, true)
            RenderScriptCams(true, false, 1, true, true)
            DisplayCash(true) -- true = hide
            DisplayHud(false)
            DisplayRadar(false)
            SetCamFov(TICCam, 50.0)

            DoScreenFadeIn(500)

            Fading = false
            TICActive = "set"
        elseif UsingTIC and TICActive and IsDisabledControlJustPressed(0, 25) then -- RMB
            Fading = true
            DoScreenFadeOut(500)
            Citizen.Wait(500)

            RenderScriptCams(false, false, 1, true, true)
            SetCamActive(TICCam, false)
            DestroyCam(TICCam, false)

            SetSeethrough(false)
            DisplayCash(false) -- false = unhide
            DisplayHud(true)
            DisplayRadar(true)

            DoScreenFadeIn(500)

            Fading = false
            TICCam = false
            TICActive = false
        elseif UsingTIC and not TICActive and not AimingAnimStarted and IsDisabledControlJustPressed(0, 25) then
            local PlayerPed = PlayerPedId()
            AimingAnimStarted = true

            if not HasAnimDictLoaded(Config.AnimDict) then
                RequestAnimDict(Config.AnimDict)
                while not HasAnimDictLoaded(Config.AnimDict) do Wait(0) end
            end

            TaskPlayAnim(PlayerPed, Config.AnimDict, Config.AnimName, 8.0, -8.0, -1, 49, 0.0, false, false, false)
            AttachEntityToEntity(UsingTIC, PlayerPed, GetEntityBoneIndexByName(PlayerPed, "BONETAG_L_HAND"), vector3(0.12, 0.02, 0.02), vector3(0.0, 145.0, 50.0), false, false, false, false, 2, true)
        elseif UsingTIC and not TICActive and AimingAnimStarted and IsDisabledControlJustReleased(0, 25) then
            AimingAnimStarted = false
            StopAnimTask(PlayerPedId(), Config.AnimDict, Config.AnimName, -8.0)
            AttachEntityToEntity(UsingTIC, PlayerPed, GetEntityBoneIndexByName(PlayerPed, "BONETAG_L_HAND"), vector3(0.12, 0.0, 0.02), vector3(100.0, 0.0, 170.0), false, false, false, false, 2, true)
        end
    end
end)