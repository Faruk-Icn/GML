# Contributing to GMLK

Thanks for helping improve GMLK. Bug reports, documentation fixes, examples, and focused code changes are welcome.

## Before you start

- For a bug, open an issue with the expected result, what happened, and a small reproduction. Include your Roblox Studio version if the issue happens only in Studio.
- For a new utility or a change to the public API, open an issue first so we can discuss where it fits and how it should work.
- Do not include webhook URLs, API keys, or other private game data in issues, commits, or examples.

## Project layout

- `src/GMLK/` contains the main ModuleScript and its shared utility children.
- `src/client/GMLKClient.client.luau` and `src/server/GMLKServer.server.luau` are the two bootstrap scripts.
- `examples/coin-counter/` is a runnable Rojo example. Its server modules map to `ServerStorage.Modules.Client`; the folder is named `Client` in this framework even though it runs on the server.
- `tests/` contains Luau checks, and `.github/workflows/luau.yml` runs the automated checks.

Keep changes small and consistent with the existing Luau style. Add or update a meaningful check when changing utility behavior, and update the README when changing setup steps or a public API.

## Check your change

Install the Luau CLI and Rojo, then run these from the repository root:

```sh
luau tests/utilities.luau
rojo build default.project.json -o gmlk.rbxlx
rojo build examples/coin-counter/default.project.json -o gmlk-example.rbxlx
```

Run `luau-compile --null` on changed `.luau` files to catch syntax errors. Try the [coin counter example](examples/coin-counter/README.md) in Studio when changing the loader, bootstraps, or remote helpers. GitHub Actions also checks Luau syntax, utility behavior, and both Rojo projects on each pull request.

## Submit a pull request

Fork the repository, make a branch for one focused change, and open a pull request against `main`. Explain what changed, why it helps, and how you checked it. Link any related issue. Screenshots or a short recording are useful for changes that affect what players see.
