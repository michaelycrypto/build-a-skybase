# NPC Shop & Merchant UI

## Overview
**IMPLEMENTED**: Single unified `NPCTradeUI` following MinionUI pattern with buy/sell modes:
- **Buy Mode** - Buy items from Shop Keeper NPC
- **Sell Mode** - Sell items to Merchant NPC

**Design Choice**: Instead of two nearly identical UIs, we use one `NPCTradeUI` with mode switching. This reduces code duplication, follows DRY principles, and is easier to maintain.

---

## Architecture (MinionUI Pattern)

### Class Structure
```lua
-- NPCTradeUI.lua (IMPLEMENTED)
local NPCTradeUI = {}
NPCTradeUI.__index = NPCTradeUI

function NPCTradeUI.new(inventoryManager)
    local self = setmetatable({}, NPCTradeUI)
    self.inventoryManager = inventoryManager
    self.isOpen = false
    self.mode = nil -- "buy" or "sell"
    self.npcId = nil
    return self
end

function NPCTradeUI:Initialize()
    -- Create ScreenGui
    -- Create panel with header, currency display, item list
    -- Register events (NPCShopOpened, NPCMerchantOpened, NPCTradeResult)
    -- Register with UIVisibilityManager
end

function NPCTradeUI:Open(data)
    -- data = {mode, npcId, items, playerCoins}
    self.mode = data.mode -- "buy" or "sell"
    -- Close other UIs via UIVisibilityManager
    -- Populate items based on mode
    -- Show panel
end
```

### GameClient Integration
```lua
-- In GameClient.client.lua (IMPLEMENTED)

-- Initialize NPC Trade UI (unified shop/merchant interface)
local NPCTradeUI = require(script.Parent.UI.NPCTradeUI)
local npcTradeUI = NPCTradeUI.new(inventoryManager)
npcTradeUI:Initialize()
Client.npcTradeUI = npcTradeUI
```

### Event-Driven Architecture
NPCTradeUI registers for server events directly - no NPCController wiring needed:
- `NPCShopOpened` → Opens UI in buy mode
- `NPCMerchantOpened` → Opens UI in sell mode
- `NPCTradeResult` → Shows success/error feedback

### UI Integration (Consistent with ChestUI/MinionUI)
- Uses `UIVisibilityManager:SetMode("npcTrade")` for proper backdrop/cursor handling
- `"npcTrade"` mode registered in UIVisibilityManager with proper hiddenComponents
- UIBackdrop handles dark overlay and mouse release (no manual overlay in NPCTradeUI)
- ESC/E/B keys properly close the UI (handled in GameClient.client.lua)
- CollectionService tag for responsive scaling

---

## Server Flow (IMPLEMENTED)

### NPCService Updates
```lua
-- In HandleNPCInteract() (IMPLEMENTED)
if interactionType == "SHOP" then
    self:OpenShopForPlayer(player, data.npcId)
elseif interactionType == "SELL" then
    self:OpenMerchantForPlayer(player, data.npcId)
else
    -- WARP and other types send generic NPCInteraction event
    EventManager:FireEvent("NPCInteraction", player, {...})
end

-- OpenShopForPlayer sends NPCShopOpened with shop stock data
-- OpenMerchantForPlayer sends NPCMerchantOpened with sellable items from inventory
```

---

## Events

### ServerToClient
| Event | Payload | Description |
|-------|---------|-------------|
| `NPCShopOpened` | `{npcId, items[], playerCoins}` | Opens shop with buyable items |
| `NPCMerchantOpened` | `{npcId, items[], playerCoins}` | Opens merchant with sellable items |
| `NPCTradeResult` | `{success, message, newCoins}` | Transaction result |

### ClientToServer
| Event | Payload | Description |
|-------|---------|-------------|
| `RequestNPCBuy` | `{npcId, itemId, quantity}` | Buy item from shop |
| `RequestNPCSell` | `{npcId, itemId, quantity}` | Sell item to merchant |
| `RequestNPCClose` | `{npcId}` | Close NPC UI |

---

## UI Layout

### NPCShopUI (Buy)
```
┌─────────────────────────────────────────┐
│  SHOP KEEPER                    [X]     │  54px header, Upheaval font
├─────────────────────────────────────────┤
│  💰 1,234 coins                         │  Currency display
├─────────────────────────────────────────┤
│  ┌────┐                                 │
│  │icon│ Wooden Pickaxe      50   [BUY]  │  Scrollable item list
│  └────┘                                 │
│  ┌────┐                                 │
│  │icon│ Stone Sword        100   [BUY]  │
│  └────┘                                 │
│  ...                                    │
└─────────────────────────────────────────┘
```

### NPCMerchantUI (Sell)
```
┌─────────────────────────────────────────┐
│  MERCHANT                       [X]     │  54px header, Upheaval font
├─────────────────────────────────────────┤
│  💰 1,234 coins                         │  Currency display
├─────────────────────────────────────────┤
│  Your Items:                            │
│  ┌────┐                                 │
│  │icon│ Cobblestone x64    +128  [SELL] │  Player's sellable inventory
│  └────┘                                 │
│  ┌────┐                                 │
│  │icon│ Oak Log x32         +96  [SELL] │
│  └────┘                                 │
│  ...                                    │
└─────────────────────────────────────────┘
```

---

## Style Constants
```lua
local CONFIG = {
    -- Dimensions
    PANEL_WIDTH = 400,
    HEADER_HEIGHT = 54,
    ITEM_HEIGHT = 56,
    ITEM_SPACING = 4,
    PADDING = 12,
    ICON_SIZE = 44,
    
    -- Colors (match existing panels)
    PANEL_BG = Color3.fromRGB(58, 58, 58),
    ITEM_BG = Color3.fromRGB(31, 31, 31),
    ITEM_HOVER = Color3.fromRGB(80, 80, 80),
    BORDER = Color3.fromRGB(77, 77, 77),
    
    -- Buttons
    BTN_BUY = Color3.fromRGB(80, 180, 80),
    BTN_BUY_HOVER = Color3.fromRGB(90, 200, 90),
    BTN_SELL = Color3.fromRGB(255, 200, 50),
    BTN_SELL_HOVER = Color3.fromRGB(255, 220, 80),
    BTN_DISABLED = Color3.fromRGB(60, 60, 60),
    
    -- Text
    TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
    TEXT_COINS = Color3.fromRGB(255, 215, 0),
}
```

---

## Files (IMPLEMENTED)

### Created Files
| File | Type | Purpose |
|------|------|---------|
| `UI/NPCTradeUI.lua` | Client | Unified buy/sell interface |
| `Configs/NPCTradeConfig.lua` | Shared | Shop items, prices, sell rates |

### Modified Files
| File | Changes |
|------|---------|
| `Services/NPCService.lua` | Added shop/merchant handlers, stock management |
| `Events/EventManifest.lua` | Added NPC trade events |
| `GameClient.client.lua` | Initialize NPCTradeUI |

---

## Economy Design (Skyblock-Style)

### Core Principles
1. **Players EARN** by selling farmed resources (crops, logs, raw blocks)
2. **Players SPEND** on expansion, utility, and decoratives (money sinks)
3. **Sell price = 40-60% of buy price** (NO ARBITRAGE)
4. **Early game:** Manual farming rewards
5. **Mid game:** Automation with diminishing returns
6. **Late game:** High-cost decoratives as inflation sinks

### Economy Tiers

| Tier | Stage | Income Sources | Typical Sell Value |
|------|-------|----------------|-------------------|
| 1 | Early | Basic farming (wheat, logs, cobble) | 1-5 coins |
| 2 | Early-Mid | Better crops, ores | 5-15 coins |
| 3 | Mid | Processed materials (ingots) | 15-40 coins |
| 4 | Late | Rare materials, storage blocks | 40-100+ coins |
| 5 | End-game | Premium decoratives | Money sink only |

### Sell Margins by Category

| Category | Sell % | Rationale |
|----------|--------|-----------|
| Raw Resources | 50% | Best margins - encourages farming |
| Processed Materials | 40-45% | Convenience tax for buying ingots |
| Tools | 40% | Prevent tool flipping |
| Decoratives | 30-40% | Pure money sinks |
| Utility Blocks | 30-35% | Strong money sinks |

### Money Sinks

1. **Utility Blocks:** Crafting Table (100), Furnace (150), Chest (200)
2. **Automation:** Minions (2,500-5,000+) with diminishing returns
3. **Building Expansion:** Colored blocks, stairs, slabs
4. **Decoratives:**
   - Tier 1: Wool (15 coins)
   - Tier 2: Stained Glass, Terracotta (20-25 coins)
   - Tier 3: Concrete (35 coins)
   - Tier 4: Quartz, Prismarine (100-200 coins)
   - Tier 5: End Stone, Amethyst, Beacon (500-10,000 coins)

### Progression Loop

```
Farm Resources → Sell to Merchant → Buy Utility/Tools → Farm More Efficiently
                                  ↓
                            Buy Decoratives (late game wealth sink)
```

---

## NPCTradeConfig Structure (IMPLEMENTED)
```lua
NPCTradeConfig.ShopItems = {
    -- Tools (with stock limits)
    { itemId = 1001, price = 50,  stock = 5, category = "Tools" },
    
    -- Seeds (kickstart farming)
    { itemId = 70,  price = 10,  stock = 16, category = "Seeds" },
    
    -- Utility (money sinks)
    { itemId = 13,  price = 100,  stock = 3, category = "Utility" },
    
    -- Decoratives (inflation sinks)
    { itemId = 156, price = 15,  stock = 16, category = "Decoration" },
}

NPCTradeConfig.SellPrices = {
    -- Farmables (50% margin - best income)
    [5]  = 4,   -- Oak Log
    [71] = 3,   -- Wheat
    
    -- Processed (40% margin)
    [33] = 20,  -- Iron Ingot (buy 50, sell 20)
    
    -- Decoratives (30-40% margin - money sinks)
    [156] = 5,  -- White Wool (buy 15, sell 5)
}

NPCTradeConfig.ToolSellMultiplier = 0.40
NPCTradeConfig.ArmorSellMultiplier = 0.30

-- Validation function to check for arbitrage
NPCTradeConfig.ValidateNoArbitrage()
```

---

## Implementation Status: COMPLETE

| Task | Status |
|------|--------|
| NPCTradeConfig | ✅ Implemented |
| EventManifest updates | ✅ Implemented |
| NPCTradeUI (unified) | ✅ Implemented |
| NPCService updates | ✅ Implemented |
| GameClient integration | ✅ Implemented |
| Transaction handling | ✅ Implemented |
| Sound/toast feedback | ✅ Implemented |
| Stock management | ✅ Implemented |
