# 🌸 Pull A Lucky Fish — Sakura Automation Suite

Sleek, high-performance, single-script automation suite for **Pull A Lucky Fish** on Roblox.

---

## ⚡ Quick Start

Execute the script directly in your Roblox executor (Solara, Wave, Codex, Delta, Hydrogen, Arceus X, etc.):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/oufrob9/PullALuckyFish/main/main.luau"))()
```

> **UI Toggle Key:** Press `RightShift` on keyboard or tap the floating 🌸 flower button on mobile/touch screens.

---

## ✨ Features

- **💰 Auto-Collect Cash**: Continuous background collection from all player base plots.
- **🥚 Auto-Buy Eggs**: Automatically scans and purchases in-stock eggs while safely skipping Robux/Mythic items.
- **📦 Auto-Buy Boxes**: Purchases Float Crates and Functional Objects Crates upon restock.
- **🏷️ Auction House Direct-Buy**: Hourly direct-buy automation with proximity checks, prompt triggering, and strict action cooldown compliance (no bids).
- **⏳ Smart Auto-Place**: Strictly verifies available incubation capacity and base proximity before placing; supports priority ordering (High Tier First, Eggs First, Boxes First).
- **🐣 Smart Auto-Hatch / Open**: Strictly verifies timer completion (`0:00` / Ready) before opening eggs and boxes.
- **🛡️ Soft Anti-AFK**: Integrates with `VirtualUser` to prevent the 20-minute idle disconnect without risky auto-rejoining.
- **💾 Config Persistence**: Automatically saves and loads your preferences to/from the executor's workspace directory (`PullALuckyFish_Config.json`).
- **🌸 Ultra-Modern UI/UX**: Custom glassmorphism Sakura theme, smooth spring/quad animations on toggles and tabs, minimizable floating pill, and safe instant teardown.

---

## 🛡️ Clean Teardown

Closing the UI cleanly disconnects all background threads, loops, and listeners without requiring a game rejoin or leaving memory leaks.
