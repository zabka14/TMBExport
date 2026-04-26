# Changelog

## 1.0.4

### Added
- **Expandable details panel for each item.** A small `+` button appears to the left of every item name in the wishlist view. Clicking it expands an inline table below the row showing each player's `Priority`, `Off-Spec`, `Note` and `Item Prio Note`. Empty fields are shown as `-` in grey.
- CSV parser now imports the `item_prio_note` column.

### Changed
- Main window widened from 950 px to 1100 px to accommodate the new details panel.

## 1.0.3

### Added
- **Automatic remapping of T4/T5/T6 set pieces to their tokens at import time.** A wishlist on *Justicar Shoulderguards* is now counted as a wishlist on *Pauldrons of the Fallen Champion*, with the correct boss (*High King Maulgar*) and instance (*Gruul's Lair*). Covers 306 set pieces across all three tiers, every class and every spec, including Sunwell off-pieces.
- Number of remapped entries reported in chat at import.

### Fixed
- CSV parser no longer drops rows without `instance_name`. This was required so set pieces — which have no instance/source in the TMB export — are imported and then remapped to their token.

## 1.0.1

### Added
- Added support for priority system.
- Added settings tab.
- Added toggle for wishlist info in item tooltip.
