# ProfitSort ("Tylesser - Auctionator Profit Sort")

Shared conventions, release steps and the game client are in the workspace file `../../CLAUDE.md` (if present). This file covers this addon only.

## Files (load order from ProfitSort.toc)

- `Core.lua`: constants (`ns.AH_CUT = 0.95`), `ProfitSortDB` defaults (applied on load in `Events.lua`), and price lookups. Prices come
  **only** from the documented `Auctionator.API.v1` (caller ID = addon name); never read Auctionator internals.
  Vendor prices come first for reagents, Auctionator after that.
- `Shopping.lua`: the craft queue (right-click rows) and the Auctionator shopping list "Profit Sort".
- `Providers.lua`: one provider per profession window: the classic `TradeSkillFrame`, the classic `CraftFrame`
  (Enchanting) and the modern `ProfessionsFrame`. Each `Scan()` returns the same entry shape, documented at the top of
  the file. All three are kept on purpose: it is still unverified which one WoW Forever uses.
- `UI.lua`: the docked panel (columns Cost, AH Value, Profit, Margin, Per Skill; sort on header click; filters).
- `Events.lua`: event wiring, refresh after Auctionator scans and bag changes, slash commands `/psort` and `/profitsort`
  (`reset`, `flips`, `options`).
- `Vendor.lua`: flip finder at vendors (green border, "+profit", tooltip line). It works alongside VendorSearch's
  filtering, so test the two together. It lives here, not in VendorSearch: the user wants all AH-price features in ProfitSort.
- `Options.lua`: Esc > Options > AddOns page.

## Notes

- Requires Auctionator (`## RequiredDeps`, `.pkgmeta` `required-dependencies`). Show a clear message, not a Lua error,
  when Auctionator has no price yet.
- When the user reports a problem, first ask which profession window or provider was open, and whether
  `/console scriptErrors 1` shows a Lua error.
- `README.md` and `CHANGELOG.md` also appear on tylesser.com. After a release, rebuild the site
  (see `../../tylesser-site/CLAUDE.md`, repo Tylesser/tylesser-site).
