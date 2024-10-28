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