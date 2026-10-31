# Coin counter example

This small Roblox place demonstrates GMLK's client and server bootstraps, `Init` and `Start` lifecycle, argument validation, and per-player remote rate limiting.

1. Install [Rojo](https://rojo.space/) and open a new Roblox Studio place.
2. From the repository root, run `rojo serve examples/coin-counter/default.project.json`.
3. Connect the Rojo plugin in Studio, sync the project, then press **Play**.
4. Click **Add coin**. Each valid request adds one coin. After three quick requests, the server returns a retry delay; wait and try again.

The example uses the framework source directly through its Rojo project file. No extra framework installation or copy is needed. Balances exist only for the current server session and are cleared when a player leaves.
