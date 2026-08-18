### 1.5.3

- Act 3 purchase logic mirrors the apworld's retune: `a3_purchase(count)` replaces the flat
  three-of-four-zones shop rule, with the Shop Holo Pelt asking for one open zone, the Nano Armor
  Generator for two, and the Clock for Gaudy Gem Land plus three
- The four Act 3 markers that sat in empty space now sit on the room each check is taken in: the
  Filthy Corpse World, Gaudy Gem Land and Foul Backwater shortcuts, and the Wizard Tower satellite
  dish. Positions come from the game's own `HoloMapWorldData` grids fitted to the map image
- The three Vessel Upgrades appear in all four Act 3 boss rooms, as `ref` sections on the boss
  room locations. They are still one set of checks, so the count stays three
- Item grids drop from 64px to 48px, so the act columns fit a window shorter than about 1000
  points instead of running off the bottom
- The Lonely Wizbot, Fishbot and Ourobot icons are cropped to the card art. Their name banners
  were unreadable at item size and are in the tooltip anyway
