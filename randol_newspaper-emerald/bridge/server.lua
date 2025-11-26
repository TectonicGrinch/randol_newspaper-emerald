function GetPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

function AddMoney(Player, account, amount)
    Player.Functions.AddMoney(account, amount)
end

function DoNotification(src, msg, type)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Paperboy',
        description = msg,
        type = type or 'inform'
    })
end