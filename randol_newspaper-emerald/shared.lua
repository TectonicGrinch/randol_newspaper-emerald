return {
    -- ═══════════════════════════════════════════════════════════
    --                    GENERAL SETTINGS
    -- ═══════════════════════════════════════════════════════════
    
    EnableBlip = true,
    Ped = 'a_m_m_paparazzi_01',
    PedCoords = vec4(-604.82, -926.45, 22.86, 181.1),
    
    -- ═══════════════════════════════════════════════════════════
    --                    LOGGING SETTINGS
    -- ═══════════════════════════════════════════════════════════
    
    -- Logging levels: 'none', 'minimal', 'debug'
    -- none: No console logging at all
    -- minimal: Only job start/end and payouts
    -- debug: Full verbose logging for troubleshooting
    LoggingLevel = 'minimal',
    
    -- ═══════════════════════════════════════════════════════════
    --                    VEHICLE SETTINGS
    -- ═══════════════════════════════════════════════════════════
    
    BikeModel = 'cruiser', -- Default bike model this isnt really needed as the levels come with their vehicles but its always good to have a fallback just incase
    
    -- Vehicle per level whatever level you have set they get this vehicle
    VehiclePerLevel = {
        [1] = 'cruiser',
        [2] = 'faggio',
        [3] = 'faggio',
        -- Add more levels here as needed
    },
    
    -- Vehicle display names shown in the gui suggested by original author <3
    VehicleDisplayNames = {
        ['cruiser'] = 'Cruiser Bicycle',
        ['bmx'] = 'BMX',
        ['scorcher'] = 'Scorcher',
        ['tribike'] = 'Tri-Cycles Race Bike',
        ['tribike2'] = 'Endurex Race Bike',
        ['tribike3'] = 'Whippet Race Bike',
        ['fixter'] = 'Fixter',
        ['faggio'] = 'Faggio',
        ['faggio2'] = 'Faggio Sport',
        ['faggio3'] = 'Faggio Mod',
    },
    
    -- Multiple bike spawn locations add as many as you want :D
    BikeSpawns = {
        vec4(-602.74, -927.65, 23.86, 179.5),
        vec4(-600.50, -927.65, 23.86, 179.5),
        -- vec4(-605.00, -927.65, 23.86, 179.5),
    },
    
    BikeSpawnCheckRadius = 5.0, -- lol this isnt really needed but i thought why not go all out
    
    -- ═══════════════════════════════════════════════════════════
    --                    PAYMENT SETTINGS
    -- ═══════════════════════════════════════════════════════════
    
    CompletionBonus = 75, -- This is the payout for completing a job with NO restocks
    
    -- ═══════════════════════════════════════════════════════════
    --                    EXPERIENCE SETTINGS
    -- ═══════════════════════════════════════════════════════════
    
    ExpPerPaper = 10, -- EXP gained per paper id change this it was big for testing
    ExpLossPerRestock = 10, -- EXP lost per restocking paper
    MaxExpBuffer = 100, -- Maximum EXP allowed above max level requirement (prevents infinite scaling)
    LevelRequirements = {
        [1] = 0,
        [2] = 100,
        [3] = 250, 
        -- This is how much EXP to reach the next level
    },
    
    -- ═══════════════════════════════════════════════════════════
    --                    PENALTY SETTINGS
    -- ═══════════════════════════════════════════════════════════
    
    PenaltyPerPaper = 5, -- Penalty percentage this is for those who dont complete the job but finish at npc it will charge 5% per missed so 2 = 10% off the money
    MaxPenalty = 50, -- Maximum penalty cap if you want to cap it if not set to 100% and will go nuts on punishing for not completing the job properly
    
    -- ═══════════════════════════════════════════════════════════
    --                    DELIVERY SETTINGS
    -- ═══════════════════════════════════════════════════════════
    
    DeliveryValidationDistance = 35.0, -- Max distance from delivery point to check if the paper landed this was another why not
    DeliveryMarkerDistance = 30.0, -- Distance at which delivery markers appear why not lol easy config
    
    -- Delivery Marker Settings | tinker mode activated
    MarkerType = 1, -- Marker type (1 = cylinder)
    MarkerColor = {r = 227, g = 14, b = 88, a = 165},
    MarkerSize = {x = 4.0, y = 4.0, z = 2.0},
    MarkerHeight = -1.5,
    
    -- ═══════════════════════════════════════════════════════════
    --                    NOTIFICATION SETTINGS
    -- ═══════════════════════════════════════════════════════════
    
    NotificationTitle = 'Paperboy', -- Title for all notifications
    
    -- ═══════════════════════════════════════════════════════════
    --                    ITEM SETTINGS
    -- ═══════════════════════════════════════════════════════════
    
    PaperItemName = 'WEAPON_ACIDPACKAGE', -- Item name for newspapers in inventory
    
    -- ═══════════════════════════════════════════════════════════
    --                    UI SETTINGS
    -- ═══════════════════════════════════════════════════════════
    
    ShowTopLeaderboard = 3, -- Number of top players to show on leaderboard inside the gui <3
}