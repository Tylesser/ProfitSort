# Changelog

## 1.9.1

- **Fix: vendors that sell above the auction house**: a reagent now costs the cheaper of its vendor price and its auction price. Before, a vendor price always won, so after a visit to a dear vendor such as the Black Market, recipes like the dyes showed a big loss.

## 1.9.0

- **Clearer options page**: a thin line now separates each option from the next.
- **Tylesser settings window**: the options now open in a window of their own with room for everything, every Tylesser addon you have listed on its left. Options > AddOns has one **Tylesser** entry that opens it.

## 1.8.0

- **In your language**: German, French, Spanish, Russian and Brazilian Portuguese game clients now show the addon in their language (other clients stay in English). Russian clients get the game's own font for headings, since the addon's fonts have no Cyrillic letters.

## 1.7.0

- New **Min profit** filter under the list: hides every recipe that loses money or earns less than the amount you type per craft (like `1s`, `50s` or `1g 50s`). Typing an amount turns it on; hover the check box to see how many recipes it hides.

## 1.6.0

- Each crafted item now remembers its materials too, so **Commerce Authority** can search the auction house for them when crafting a writ's item is cheaper than buying it.

## 1.5.0

- **Make or buy**: when another recipe of the same profession makes a reagent for less than it costs to buy, Cost uses the crafting cost (also for that recipe's own reagents, up to 3 levels deep). The reagent tooltip shows "crafted", the recipe and what buying would cost. Turn it off with **Craft reagents when cheaper** on the options page.
- **Profit in item tooltips**: items you can craft get a line like "Profit Sort: +2g 10s profit (cost 1g 80s)", from your last profession scan on that character. No line while Auctionator has no price for the item. Turn it off with **Show profit in item tooltips** on the options page.
- Profit Sort is in the addon compartment (the addons button by the minimap) on clients that have it. Click it to open the options.

## 1.4.1

- A **More addons** button on the options page, and the feedback window points to tylesser.com for the other Tylesser addons.

## 1.4.0

- Owned free shows how many recipes in the list it applies to, like "Owned free (12)", and its tooltip says how many of the recipes shown that is.
- A Feedback button on the options page and a `/psort feedback` command: they show the link to tylesser.com/feedback, where you can report a bug or suggest an idea.

## 1.3.0

- New Tylesser look: the profit panel and the options page are dark stone with gold borders and Cinzel headings, shared by all Tylesser addons.

## 1.2.0

- New **vendor flip finder**: at any vendor, items that sell for at least 10% and 1 silver more on the auction house (after the 5% cut) get a green border, a "+profit" label and a tooltip line. Works with Tylesser - Vendor Search filtering. Turn it off or on in the new options page (Esc > Options > AddOns > Tylesser - Auctionator Profit Sort, or `/psort options`) or with `/psort flips`.

## 1.1.0

- New **Per Skill** column: estimated cost per skill point from the recipe's colour (orange 100%, yellow ~75%, green ~25%, gray none). Sort by it to find the cheapest way to level a profession.
- New **craft queue and shopping list**: right-click recipes to queue crafts (Shift-right-click to remove), then click **Shopping list** to create the Auctionator shopping list "Profit Sort" with the reagents you still need, minus what's in your bags and bank. At the auction house the search starts right away.
- New **Owned free** option: reagents already in your bags and bank count as free, so Cost and Profit show what crafting from your own stock earns. The tooltip shows how many of each reagent you have.
- The Margin column header is no longer cut off.
- When the panel is closed, the addon icon (instead of a "Profit" button) next to the profession window reopens it.
- Shorter status text ("17/17 priced") to make room for the new option.

## 1.0.0

- First release.
- Profit panel next to the profession window, listing each recipe's crafting cost, AH value, profit and margin.
- Click a column header to sort by it; click again to reverse.
- Filters: "Craftable now" and "Has AH price".
- Click a row to select the recipe, Shift-click to link the item.
- Tooltip with reagent cost breakdown and price age.
- Works with the classic trade skill window, the classic craft (Enchanting) window and the modern Professions window.
