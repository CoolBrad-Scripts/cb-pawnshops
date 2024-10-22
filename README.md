![Intro Card](https://docs.coolbrad.com/images/README/CB-PawnShops.png)

## Description
**This script is a feature-rich Pawn Shop for your food/mechanic businesses. It's designed to allow your businesses to still purchase items from the public while all employees are off duty. In short, it keeps your economy turning while businesses are away.**

## Features:
- Employees can set which items to buy from civilians (Buy Orders)
- Delete Buy Orders
- Change price of Buy Orders
- Change amount of Buy Orders
- Employees of the business can remove stock from the pawn shop
- Server owners can set which items are allowed to be bought by each business (in other words, no food businesses buying steel)
- The PED only spawns when all members of the job are off duty

## Security Features:
- The script requires that businesses pay for the items upfront with cash. This ensures that when the civilian sells the item, they can be paid right away, and no integration is needed with your existing banking system.
- Whenever a civilian fulfills an entire Buy Order, the Buy Order is deleted, and no more of that item can be sold to the business (until the employee updates it again).

## Dependencies
- ox_lib
- ox_inventory