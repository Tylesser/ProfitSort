# ProfitSort ("Tylesser - Auctionator Profit Sort")

Shared conventions, release steps and the game client are in the workspace file `../../CLAUDE.md` (if present). This file covers this addon only.

## Files (load order from ProfitSort.toc)

- `Tylesser.lua`: the shared Tylesser "Runestone" look (`ns.T`: stone panels, gold borders, studs, Cinzel, buttons,
  check boxes, options page header, chat prefix). Loaded first. The same file is in every Tylesser addon: edit them together
  (see the workspace CLAUDE.md).
- `Core.lua`: constants (`ns.AH_CUT = 0.95`), `ProfitSortDB` defaults (applied on load in `Events.lua`), and price lookups. Prices come
  **only** from the documented `Auctionator.API.v1` (caller ID = addon name); never read Auctionator internals.
  A reagent costs the cheaper of its vendor and auction price (2026-11-28: WoW Forever's Black Market vendor
  sells reagents far above the AH, and Auctionator records its prices too).
  Make or buy: `ns.BuildCraftIndex(entries)` maps product item IDs to the recipes of one scan; `ns.Evaluate(entry,
  ownedFree, crafts)` then uses a reagent's craft cost (recipe cost / average amount made, source `"craft"`) when it is
  cheaper than buying, recursively up to `ns.MAX_CRAFT_DEPTH` (3) with a cycle guard on item IDs. Without `crafts` the
  result is the same as before. Owned free applies only to the evaluated recipe's own reagents; sub-recipes use market
  prices. `entry.fullCost` is the cost without Owned free.
- `Shopping.lua`: the craft queue (right-click rows) and the Auctionator shopping list "Profit Sort".
- `Providers.lua`: one provider per profession window: the classic `TradeSkillFrame`, the classic `CraftFrame`
  (Enchanting) and the modern `ProfessionsFrame`. Each `Scan()` returns the same entry shape, documented at the top of
  the file. All three are kept on purpose: it is still unverified which one WoW Forever uses. Make or buy and the
  tooltip cache need `entry.itemID` (the product): TradeSkill reads it from `GetTradeSkillItemLink`, Craft from
  `GetCraftItemLink` (only item links; enchants have none), Professions from `GetRecipeOutputItemData` / `outputItemID`.
- `UI.lua`: the docked panel (columns Cost, AH Value, Profit, Margin, Per Skill; sort on header click; filters).
- `Events.lua`: event wiring, refresh after Auctionator scans and bag changes, slash commands `/psort` and `/profitsort`
  (`reset`, `flips`, `options`).
- `Vendor.lua`: flip finder at vendors (green border, "+profit", tooltip line). It works alongside VendorSearch's
  filtering, so test the two together. It lives here, not in VendorSearch: the user wants all AH-price features in ProfitSort.
- `Tooltip.lua`: profit line in item tooltips ("Profit Sort: +2g 10s profit (cost 1g 80s)") for items a scanned recipe
  makes. `ns.RememberProducts` (called from `UI:Refresh`) stores them in `ProfitSortCharDB.products`; `ns.HookItemTooltips`
  (called on ADDON_LOADED in `Events.lua`) uses TooltipDataProcessor, or OnTooltipSetItem on GameTooltip and ItemRefTooltip
  on clients without it. Skips shopping/compare tooltips, hidden scanner tooltips and the panel's own rows
  (`row.profitSortRow`). No line when Auctionator has no price for the item.
- `Options.lua`: Esc > Options > AddOns page, and the addon compartment entry (`ns.T.AddCompartment`, opens the options).

## Saved variables

- `ProfitSortDB` (account): defaults in `ns.defaults` (Core.lua): sort, filters, `ownedFree`, `queue`, `vendorFlips`,
  `shown`, `position`, `minProfitOn` + `minProfit` (copper; the Min profit row, `ns.ParseMoney`), `craftReagents` (make or buy, default on), `itemTooltips` (default on).
- `ProfitSortCharDB` (per character, `## SavedVariablesPerCharacter`): defaults in `ns.charDefaults`. `products[itemID] =
  { profit, cost, value, recipe, time }`: the last scan of each item you can craft, cost without Owned free, recipes with
  unpriced reagents or no AH price left out. Bounded to `ns.MAX_PRODUCTS` (500); the oldest scans are dropped first.

## Notes

- Requires Auctionator (`## RequiredDeps`, `.pkgmeta` `required-dependencies`). Show a clear message, not a Lua error,
  when Auctionator has no price yet.
- When the user reports a problem, first ask which profession window or provider was open, and whether
  `/console scriptErrors 1` shows a Lua error.
- The shopping list does not expand crafted reagents: it still lists the reagent itself, not what it is crafted from.
- `README.md` and `CHANGELOG.md` also appear on tylesser.com. After a release, rebuild the site
  (see `../../tylesser-site/CLAUDE.md`, repo Tylesser/tylesser-site).
