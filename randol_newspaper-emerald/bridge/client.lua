function GetPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

function hasPlyLoaded()
    return LocalPlayer.state.isLoggedIn
end

function DoNotification(msg, type)
    lib.notify({
        title = 'Paperboy',
        description = msg,
        type = type or 'inform'
    })
end

function handleVehicleKeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
end