# PMMP plugin server test

Updated: 2026-06-09 KST

## Source

Plugin source directory:

```text
C:\Users\champ\OneDrive\문서\개발\pmmp_develop\PMMP_develop\PMMP_plugin_develop
```

## Deployment

- Plugins were flattened into `main_pmmp/plugins`.
- Source folder plugins require `DevTools.phar`; it is included for this local runnable server.
- `Customies.phar` is included.
- Duplicated plugin names were reduced to one selected copy.
- Broken, missing-dependency, or current-PMMP-conflicting plugins were moved to `main_pmmp/var/plugin-disabled/20260609-boot`.

## Validation

- PHP lint after disabling broken `Guide`: `1701/1701` PHP files passed.
- Plugin hotpath audit: `warn`, findings `172`.
- Boot smoke: ready `true`, fatal `0`, plugin load errors `0`, enabled plugins `99`.
- Smoke RakNet ping on `19158`: sent `128`, received `128`, loss `0%`.
- Live server started on `19132`.
- Live RakNet ping on `19132`: sent `128`, received `128`, loss `0%`, avg latency about `30.30ms`.

## Disabled plugins

Disabled because they prevented boot or conflict with current PMMP/protocol/dependencies:

- `AdvancedLevel`
- `AdvancedPrefix`
- `AdvancedWarp`
- `AuctionHouse`
- `ChattingRoom`
- `Contents`
- `Core`
- `core_mob`
- `core_shield`
- `CrystalAPI`
- `CustomItemLoader`
- `DeliveryAPI`
- `EconomyAPI`
- `Enforce`
- `Guide`
- `ImageOnMap`
- `IslandFlying`
- `IslandLoader`
- `Lottery`
- `PlayTime`
- `RuneSystem`
- `SaveInventory`
- `ServerCore`
- `ShopKeeper`
- `SocialNetwork`
- `SynthesisPrice`
- `VanillaElytra`
- `VoteReward`

## Start command

```bat
pmmp-start-plugin-server.cmd -Port 19132 -MaxPlayers 400
```

Background start:

```bat
pmmp-start-plugin-server.cmd -Port 19132 -MaxPlayers 400 -Background
```
