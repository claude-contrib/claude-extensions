# Changelog

## [2.1.0](https://github.com/claude-contrib/claude-extensions/compare/v2.0.0...v2.1.0) (2026-11-14)


### Features

* **os-notify:** question alert, Allow/Deny and answer buttons ([#65](https://github.com/claude-contrib/claude-extensions/issues/65)) ([286d8a8](https://github.com/claude-contrib/claude-extensions/commit/286d8a8a498c56804fdcef3b18f4a42d3a92f1d6))
* **tmux-notify:** notify when Claude asks a question ([#66](https://github.com/claude-contrib/claude-extensions/issues/66)) ([da4aeb5](https://github.com/claude-contrib/claude-extensions/commit/da4aeb56eb5cdc03338966f9d712a02b10939800))

## [2.0.0](https://github.com/claude-contrib/claude-extensions/compare/v1.4.0...v2.0.0) (2026-11-14)


### ⚠ BREAKING CHANGES

* **macos-notify:** remove in favor of os-notify

### Features

* **macos-notify:** remove in favor of os-notify ([bd716d8](https://github.com/claude-contrib/claude-extensions/commit/bd716d817be934ee3b85c41321173cb35a43909a))
* **os-notify:** add cross-platform notification plugin ([7480f2d](https://github.com/claude-contrib/claude-extensions/commit/7480f2d537312db543b82cc3aaca1f6869c60e64))
* **os-notify:** detect the terminal from the process tree ([9def4fb](https://github.com/claude-contrib/claude-extensions/commit/9def4fb28e0d0eefc906e6050823091c26c89d5f))
* **os-notify:** X11 focus detection and click-to-focus on Linux ([a4c7ee9](https://github.com/claude-contrib/claude-extensions/commit/a4c7ee972f16e1daab70942399e050b91de08416))


### Bug Fixes

* add postCreateCommand to restore nix volume permissions ([1a49980](https://github.com/claude-contrib/claude-extensions/commit/1a49980d0706dc7576aaa39f2250689796172c30))
* **ci:** merge with the App token so main gets its CI run ([#59](https://github.com/claude-contrib/claude-extensions/issues/59)) ([ee4cafe](https://github.com/claude-contrib/claude-extensions/commit/ee4cafe5af938455707e6909f09f458e90ba9f12))
* **ci:** pin release-please baseline and set os-notify first version ([8e115b6](https://github.com/claude-contrib/claude-extensions/commit/8e115b6fc16da9f4daf1cbbdc74444b69c7ade2c))
* **github:** correct action versions in update.yml ([bafb814](https://github.com/claude-contrib/claude-extensions/commit/bafb814abcb77c7d340540a9278f86c46da3eb9d))
* **os-notify:** match X11 WM_CLASS by trailing component ([74ea9b0](https://github.com/claude-contrib/claude-extensions/commit/74ea9b03dfed6db18d128fa92fffcd966f1d5bd7))

## [1.4.0](https://github.com/claude-contrib/claude-extensions/compare/v1.3.1...v1.4.0) (2026-03-17)


### Features

* **tmux-notify:** remove window name management ([75514ef](https://github.com/claude-contrib/claude-extensions/commit/75514ef34a94d11dc0b60e994e0734f9a22a87af))

## [1.3.1](https://github.com/claude-contrib/claude-extensions/compare/v1.3.0...v1.3.1) (2026-03-06)


### Bug Fixes

* **tmux-notify:** update tests to match refactored script ([3d5119e](https://github.com/claude-contrib/claude-extensions/commit/3d5119e9800358bc810ae1f9b561720e642875e8))

## [1.3.0](https://github.com/claude-contrib/claude-extensions/compare/v1.2.2...v1.3.0) (2026-03-06)


### Features

* **tmux-notify:** separate auto-rename scope and change default to off ([d9f2298](https://github.com/claude-contrib/claude-extensions/commit/d9f2298bd6bf1bcf16039a7b37c88e5f467a38b1))

## [1.2.2](https://github.com/claude-contrib/claude-extensions/compare/v1.2.1...v1.2.2) (2026-03-06)


### Bug Fixes

* bump plugin.json versions and fix release pipeline ([5bc4513](https://github.com/claude-contrib/claude-extensions/commit/5bc45138e70e8dd6a05ca12f672b3da1ed7190bb))
* **release:** correct extra-files paths for sub-package plugins ([0e9e536](https://github.com/claude-contrib/claude-extensions/commit/0e9e536a57b271bb2b434693afc90cb6267287dd))

## [1.2.1](https://github.com/claude-contrib/claude-extensions/compare/v1.2.0...v1.2.1) (2026-03-06)


### Bug Fixes

* **tmux-notify:** restore window to 'claude' on Stop when no saved name; rename on SessionStart ([fcef042](https://github.com/claude-contrib/claude-extensions/commit/fcef0428b296fefae40d714aee842ccc07c7aef4))

## [1.2.0](https://github.com/claude-contrib/claude-extensions/compare/v1.1.0...v1.2.0) (2026-03-06)


### Features

* **tmux-notify:** rename window to "claude - &lt;tool&gt;" during tool use ([7bc97d5](https://github.com/claude-contrib/claude-extensions/commit/7bc97d5a00d456705a60588abfda46a94cc1e768))

## [1.1.0](https://github.com/claude-contrib/claude-extensions/compare/v1.0.0...v1.1.0) (2026-03-05)


### Features

* **agent-rules:** add agent-rules plugin ([d0b8767](https://github.com/claude-contrib/claude-extensions/commit/d0b8767c766d82d745ce447e1d00d35c679a92ca))
* **macos-notify:** add macos-notify plugin ([fbf5774](https://github.com/claude-contrib/claude-extensions/commit/fbf57745c2a648bf85033a243c8cdbf8ddae55b3))
* **tests:** add BATS test suite with nix dev environment ([698c5f7](https://github.com/claude-contrib/claude-extensions/commit/698c5f7126a8f2aa0e337abdcc0c5093cab698b6))
* **tmux-notify:** add tmux-notify plugin ([ebbe2f9](https://github.com/claude-contrib/claude-extensions/commit/ebbe2f9029234e0a43bcb1c5e80651090b2c5e5a))

## Changelog
