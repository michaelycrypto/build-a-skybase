# 🎯 Player Progression Guide

## Overview

This guide explains the complete player progression system for the spawner farming and collection game. The system focuses on automatic drop generation and economic progression without PvP/PvE mechanics.

## Table of Contents
- [Overview](#overview)
- [Core progression loop](#core-progression-loop)
- [Spawner types & economics](#spawner-types--economics)
- [Progression strategies](#progression-strategies)
- [Configuration & balancing](#configuration--balancing)
- [System features](#system-features)
- [Player statistics](#player-statistics)
- [Player experience](#player-experience)
- [Technical implementation](#technical-implementation)
- [Future expansion](#future-expansion)
- [Related docs](#related-docs)

## 🔄 Core Progression Loop

### 1. **Starting Out**
- New players receive a **Goblin Spawner** and **Basic Spawner Crate** from daily rewards
- Deploy the spawner to one of 8 available dungeon slots
- Spawners automatically generate drops every 30 seconds

### 2. **Farming & Collection**
- **Automatic Generation**: Spawners produce mob drops continuously
- **Offline Progress**: Up to 8 hours of drops calculated when returning
- **Drop Collection**: Collect drops from individual spawners or all at once
- **Daily Limits**: Each spawner has a maximum of 100 drops per day

### 3. **Economic System**
- **Sell Drops**: Convert mob drops into coins through the shop
- **Accumulate Wealth**: Build up coins for purchasing crates
- **Smart Pricing**: Higher-tier drops have proportionally higher sell values

### 4. **Crate System**
- **Purchase Crates**: Buy spawner crates with coins
- **Random Rewards**: Each crate contains random spawners based on tier
- **Progression Gates**: Higher-tier crates unlock based on collection milestones

### 5. **Progression Unlocks**
- **Individual Milestones**: Higher-tier crates unlock based on personal collection count
- **Long-term Goals**: Provides extended progression through collection growth
- **Tier-based Access**: Each crate tier requires reaching specific spawner counts

## 📊 Spawner Types & Economics

### **Mob Drops by Spawner Type**

| Spawner Type | Primary Drop | Secondary Drop | Drop Rate |
|-------------|-------------|------------|-----------|
| **Goblin Spawner** | Goblin Tooth | Dark Iron | 80% / 20% |

### **Spawner Crate System**

| Crate Type | Cost | Unlock Requirement | Contains |
|-----------|------|-------------------|----------|
| **Basic Spawner Crate** | 100 coins | Always unlocked | Goblin Spawner |
| **Enhanced Spawner Crate** | 500 coins | 10+ spawners owned | Goblin Spawner |
| **Superior Spawner Crate** | 2,000 coins | 25+ spawners owned | Goblin Spawner |
| **Elite Spawner Crate** | 10,000 coins | 50+ spawners owned | Goblin Spawner |

## 🚀 Progression Strategies

### **Early Game (0-10 Spawners)**
1. **Focus on Basic Crates**: Buy Basic Spawner Crates to increase spawner count
2. **Deploy Efficiently**: Use all 8 slots for maximum drop generation
3. **Regular Collection**: Collect drops frequently to maximize daily limits
4. **Save Coins**: Build up coins for more Spawner Crates

### **Mid Game (10-50 Spawners)**
1. **Scale Up**: Focus on getting more Goblin Spawners for increased income
2. **Collection Growth**: Focus on reaching next crate unlock threshold
3. **Offline Optimization**: Deploy spawners before logging off
4. **Resource Management**: Balance spending vs saving for higher tier crates

### **Late Game (50+ Spawners)**
1. **Elite Crates**: Access to more efficient crate purchasing
2. **Collection Mastery**: Work toward maximum spawner collection
3. **Economic Optimization**: Maximize drop-to-coin conversion efficiency
4. **Prestige Preparation**: Build foundation for future prestige systems

## ⚙️ Configuration & Balancing

### **Drop Rate Configuration**
```lua
-- Base drop generation every 30 seconds
BaseDropInterval = 30

-- 100 drops per spawner per day maximum
MaxDropsPerSpawner = 100

-- 10% bonus per spawner level
DropBonusPerLevel = 0.1

-- Up to 8 hours of offline drops
OfflineDropHours = 8
```

### **Economic Balance**
```lua
-- Crate costs scale exponentially
Basic: 100 coins (1 hour of basic farming)
Enhanced: 500 coins (5 hours of basic farming)
Superior: 2,000 coins (20 hours of basic farming)
Elite: 10,000 coins (100 hours of basic farming)
```

### **Progression Gates**
```lua
-- Unlock thresholds based on total collection
Enhanced Crates: 10 spawners (achievable in 1-2 days)
Superior Crates: 25 spawners (achievable in 1 week)
Elite Crates: 50 spawners (achievable in 2-3 weeks)
```

## 🔧 System Features

### **Automatic Systems**
- **Drop Generation**: Runs continuously on server
- **Offline Calculation**: Computed on login
- **Daily Reset**: Drop limits reset at midnight
- **Energy Regeneration**: Dungeon energy regens over time

### **Player Actions**
- **Deploy Spawners**: Place spawners in dungeon slots
- **Collect Drops**: Gather generated drops
- **Sell Items**: Convert drops to coins
- **Purchase Crates**: Buy new spawners
- **Manage Inventory**: Organize and stack items

### **Protection Systems**
- **Rate Limiting**: Prevents abuse of shop/collection systems
- **Daily Limits**: Prevents infinite farming
- **Cooldowns**: Prevents rapid-fire actions
- **Transaction Safety**: Rollback on failed operations

## 📈 Player Statistics

### **Tracked Metrics**
- **Spawners Deployed**: Total spawners placed
- **Drops Collected**: Total drops gathered
- **Crates Opened**: Total crates purchased
- **Items Sold**: Total items sold to shop
- **Coins Earned**: Total coins accumulated
- **Playtime**: Total time in game

### **Achievement Integration**
- **Collection Milestones**: Unlock achievements for spawner counts
- **Economic Milestones**: Achievements for coins earned
- **Circulation Contributions**: Recognition for community progress
- **Progression Achievements**: Unlock crate tiers and features

## 🎮 Player Experience

### **Engagement Layers**
- **Immediate**: Drops every 30 seconds
- **Short-term**: Daily goals and limits
- **Medium-term**: Crate unlocks and spawner collection
- **Long-term**: Circulation milestones and complete collection

### **Progression Satisfaction**
- **Visible Progress**: Clear advancement through crate tiers
- **Meaningful Choices**: Which spawners to deploy and upgrade
- **Community Contribution**: Individual progress helps everyone
- **Collection Goals**: Complete spawner collection endgame

## 🛠️ Technical Implementation

### **Server Architecture**
- **DropService**: Handles all drop generation and collection
- **ShopService**: Manages crate purchasing and item selling
- **DungeonService**: Manages spawner deployment
- **ItemService**: Tracks circulation and item creation
- **DataService**: Persists all player progress

### **Network Integration**
- **Real-time Updates**: Drop generation notifies clients
- **Offline Handling**: Calculates and awards offline progress
- **Transaction Safety**: Server-side validation and rollback
- **Rate Limiting**: Prevents abuse and maintains performance

## 🔮 Future Expansion

### **Planned Features**
- **Spawner Upgrades**: Enhance individual spawners
- **Automation**: Auto-collect and auto-sell unlocks
- **Prestige System**: Reset progress for permanent bonuses
- **Seasonal Events**: Limited-time spawners and bonuses
- **Trading System**: Player-to-player spawner trading

### **Balancing Considerations**
- **Economy Monitoring**: Track inflation and deflation
- **Progression Pacing**: Adjust unlock requirements based on data
- **Engagement Metrics**: Monitor player retention and satisfaction
- **Community Feedback**: Adjust based on player preferences

---

This progression system provides a complete, engaging experience focused on individual collection and economic growth without competitive elements. The system is designed to be easily configurable and expandable for future development.

## Related Docs
- [Documentation Index](DOCS_INDEX.md)