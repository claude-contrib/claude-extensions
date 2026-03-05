# Changelog

## [1.4.0](https://github.com/claude-contrib/claude-extensions/compare/v1.3.1...v1.4.0) (2026-03-05)


### Features

* **macos-notify:** suppress notification when user is already looking at Claude ([c90e708](https://github.com/claude-contrib/claude-extensions/commit/c90e70802e795b65dfdf8a9879eb4816ef27f8a1))
* **tests:** add BATS test suite with Nix dev environment and CI ([ba75c5e](https://github.com/claude-contrib/claude-extensions/commit/ba75c5ed3eb289c4b2244c77d1373d3d4c8f008d))


### Bug Fixes

* address deep code review findings ([7a98cff](https://github.com/claude-contrib/claude-extensions/commit/7a98cfffec5569d54bf05f88272a6c9d6929a1c3))
* **macos-notify:** focus terminal correctly when app is in fullscreen ([9cf7722](https://github.com/claude-contrib/claude-extensions/commit/9cf772283c75c45c48f2dd480586496d69f0332e))
* **tmux-notify:** address tech debt — version sync, docs, debug logging ([877be86](https://github.com/claude-contrib/claude-extensions/commit/877be86bca23db4ee29dc798eccfa4b655c222d6))


### Performance Improvements

* **tmux-notify:** reduce auto-focus sleep from 0.5s to 0.25s ([2750f0c](https://github.com/claude-contrib/claude-extensions/commit/2750f0c44dd2a6b6c387045e05694fd97d189990))

## [1.3.1](https://github.com/claude-contrib/claude-extensions/compare/v1.3.0...v1.3.1) (2026-03-04)


### Bug Fixes

* trigger version bump to 1.3.1 ([16af0e9](https://github.com/claude-contrib/claude-extensions/commit/16af0e985224a3c458a2457d3bdfe3eaae21fec0))

## [1.3.0](https://github.com/claude-contrib/claude-extensions/compare/v1.2.0...v1.3.0) (2026-03-04)


### Features

* add macos-notify plugin for Notification Center alerts ([4e28bc7](https://github.com/claude-contrib/claude-extensions/commit/4e28bc70b500cf54d36e532896b37c0ae40a616b))
* **notify:** limit notifications to user-interaction events only ([12a4b83](https://github.com/claude-contrib/claude-extensions/commit/12a4b8308837d1cb1e6b7c718529201fb37cbeef))


### Bug Fixes

* **macos-notify:** use window ID instead of name to avoid dot ambiguity ([b4525e1](https://github.com/claude-contrib/claude-extensions/commit/b4525e13935e486bba76e2499316c01c3da85eb4))
* **notify:** clear matcher patterns in hook configurations ([93d0810](https://github.com/claude-contrib/claude-extensions/commit/93d0810985ef58df41c820ccd7e0767c4e749e7f))
* **tmux-notify:** update stale filename in script header comment ([4ce36fc](https://github.com/claude-contrib/claude-extensions/commit/4ce36fceaf7c896009d4738da54ba54b4c06a796))


### Performance Improvements

* **tmux-notify:** reduce auto-focus sleep duration from 0.5s to 0.2s ([a0b3973](https://github.com/claude-contrib/claude-extensions/commit/a0b39738ad1a179f4a7b4fbccb100af2e404077d))

## [1.2.0](https://github.com/claude-contrib/claude-extensions/compare/v1.1.0...v1.2.0) (2026-03-04)


### Features

* add tmux-notify plugin — bell, display-message, and auto-focus ([82cf961](https://github.com/claude-contrib/claude-extensions/commit/82cf961141905cc23128581146b3d63e80a61dee))

## [1.1.0](https://github.com/claude-contrib/claude-extensions/compare/v1.0.0...v1.1.0) (2026-03-04)


### Features

* add agents-context plugin ([612a782](https://github.com/claude-contrib/claude-extensions/commit/612a7821df814ba7ef283daa9e3e72169c621aa1))


### Bug Fixes

* **sync-script:** correct typo in Claude rules directory variable ([aea4c22](https://github.com/claude-contrib/claude-extensions/commit/aea4c221b551e7298d303d8de060db1d18990fc1))
* sync.sh idempotency + add dependabot ([7cb6170](https://github.com/claude-contrib/claude-extensions/commit/7cb6170914c0fe2369692ad5eab0382cca11ca7d))
