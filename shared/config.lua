Config = {}
Config.Debug = true
Config.InventoryImage = "ox_inventory/web/images/"  -- Source of inventory images (QB INVENTORY: "qb-inventory/html/images/")
Config.BusinessPawnShops = {
    [1] = {
        job = "whitewidow",
        coords = vec4(200.72, -235.76, 53.0, 300.26),
        label = "Open Shop",
        minimumRank = 4,
        weight = 999999,
        allowedItems = {
            "weed_ak47_baggy",
            "weed_amnesia_baggy",
            "weed_zkittlez_baggy",
            "weed_ogkush_baggy",
            "weed_purplehaze_baggy",
            "weed_skunk_baggy",
            "weed_whitewidow_baggy",
            "weed_gelato_baggy",
        },
        targetDistance = 1.5,
    }
}

Config.RegularPawnShops = {
    {
        coords = vec4(182.04, -1319.89, 29.31, 253.88),
        model = "a_m_y_business_02",
        shopItems = {
            {item = "testburger", price = 10}
        }
    },
    {
        coords = vec4(183.06, -1323.37, 29.32, 338.9),
        model = "a_m_y_business_02",
        shopItems = {
            {item = "iron", price = 10}
        }
    },
}