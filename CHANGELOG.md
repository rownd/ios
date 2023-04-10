

## [2.5.1](https://github.com/rownd/ios/compare/2.5.0...2.5.1) (2023-04-07)


### Bug Fixes

* **store:** failed to decode state after upgrade ([c2631e3](https://github.com/rownd/ios/commit/c2631e3508c317e96cdf75851657958fea68f75b))

# [2.5.0](https://github.com/rownd/ios/compare/2.4.1...2.5.0) (2023-04-06)


### Bug Fixes

* **auth:** social sign-in can block touch input ([#48](https://github.com/rownd/ios/issues/48)) ([50d132b](https://github.com/rownd/ios/commit/50d132be7be5a1d14e4391c036faeb954cdf4f3b))
* keyboardWillShow delegate gets triggered everytime ([#47](https://github.com/rownd/ios/issues/47)) ([d7c3d3c](https://github.com/rownd/ios/commit/d7c3d3c560f0eabd26caf071d33c62e1f861d11e))


### Features

* **passkeys:** meet server requirements ([#46](https://github.com/rownd/ios/issues/46)) ([17a2861](https://github.com/rownd/ios/commit/17a2861bca7e4091fc25251e42c4685242ad3599))
* recieved message from hub to disable webview loading ([#43](https://github.com/rownd/ios/issues/43)) ([c708bed](https://github.com/rownd/ios/commit/c708bed923f1f22d77d32a47a497e08ae69c8061)), closes [#44](https://github.com/rownd/ios/issues/44)

## [2.4.1](https://github.com/rownd/ios/compare/2.4.0...2.4.1) (2023-02-10)


### Bug Fixes

* pass down intent from hub to apple/google sign-in ([#42](https://github.com/rownd/ios/issues/42)) ([54c0def](https://github.com/rownd/ios/commit/54c0defe585c5d1549e77ceaae6433ffdf2f0ccd))

# [2.4.0](https://github.com/rownd/ios/compare/2.3.0...2.4.0) (2023-01-31)


### Bug Fixes

* **auth:** token sign-in may not work ([ebe593d](https://github.com/rownd/ios/commit/ebe593da95be008294dd0e097bc03e3a68c86e62))


### Features

* support split sign in/up flow ([#40](https://github.com/rownd/ios/issues/40)) ([282544c](https://github.com/rownd/ios/commit/282544cac330ecfa0b5222c4a9b717db4826d507))

# [2.3.0](https://github.com/rownd/ios/compare/2.2.2...2.3.0) (2023-01-23)


### Features

* **auth:** support third-party token exchange ([#41](https://github.com/rownd/ios/issues/41)) ([bd8ff45](https://github.com/rownd/ios/commit/bd8ff4584d5744b31a78e923afa65de7365b15a7))

## [2.2.2](https://github.com/rownd/ios/compare/2.2.1...2.2.2) (2023-01-06)

## [2.2.1](https://github.com/rownd/ios/compare/2.2.0...2.2.1) (2023-01-06)


### Bug Fixes

* **auth:** sign-in with Apple occasionally fails due to race condition ([#37](https://github.com/rownd/ios/issues/37)) ([6e5a910](https://github.com/rownd/ios/commit/6e5a910dd7e1a165c554efe34616cd25669e4660))
* **test:** intermittently failing auth test ([bbb4a90](https://github.com/rownd/ios/commit/bbb4a903e5534a5040f68b7f8d2a491e025fe3f3))

# [2.2.0](https://github.com/rownd/ios/compare/2.1.0...2.2.0) (2022-12-15)


### Features

* **users:** auto sign out if account is not found ([#36](https://github.com/rownd/ios/issues/36)) ([f9f1717](https://github.com/rownd/ios/commit/f9f1717e2d796bc65b1d2f17b488988cdd686abd))
* **auth:** support signing in using Passkeys ([#34](https://github.com/rownd/ios/pull/34)) ([7e3943c](https://github.com/rownd/ios/commit/7e3943ca86ab6e2fdec279944dace917dd64234d))

# [2.1.0](https://github.com/rownd/ios/compare/2.0.3...2.1.0) (2022-12-07)


### Features

* **auth:** try to use ntp for time checking token exp ([#33](https://github.com/rownd/ios/issues/33)) ([16cfcd9](https://github.com/rownd/ios/commit/16cfcd9faf8f1f1d7045ee46586524739af4d92b))

## [2.0.3](https://github.com/rownd/ios/compare/2.0.2...2.0.3) (2022-11-21)


### Bug Fixes

* **refresh:** prevent sign-outs on non-400 http statuses ([8af36fb](https://github.com/rownd/ios/commit/8af36fb04d62429632be1a9ee7f4c68744469193))

## [2.0.2](https://github.com/rownd/ios/compare/2.0.1...2.0.2) (2022-11-15)


### Bug Fixes

* **state:** crash during auth state sync ([c02ded4](https://github.com/rownd/ios/commit/c02ded4d0713efc8ae2280ba29d988da09529cb8))


### Features

* **ui:** increase initial bottomsheet height ([adeadb9](https://github.com/rownd/ios/commit/adeadb936e07c21003597f183cdf4761ce01d7c4))

## [2.0.1](https://github.com/rownd/ios/compare/2.0.0...2.0.1) (2022-11-14)


### Bug Fixes

* **refresh:** ensure authenticator always reflects current state ([#30](https://github.com/rownd/ios/issues/30)) ([e3a9856](https://github.com/rownd/ios/commit/e3a98564fea1a655be8bc554949a403cc46b7021))

# [2.0.0](https://github.com/rownd/ios/compare/1.13.0...2.0.0) (2022-11-11)


### Features

* **auth:** prevent sign-outs during poor network conditions ([#28](https://github.com/rownd/ios/issues/28)) ([a605b84](https://github.com/rownd/ios/commit/a605b844c79e651fb46317df6e001b3f2cc709b1))
* **email:** enable button to open email from app ([#25](https://github.com/rownd/ios/issues/25)) ([1d3c963](https://github.com/rownd/ios/commit/1d3c9635a64d3f3fc7071a4433b3f22138b1271b))

# [1.13.0](https://github.com/rownd/ios/compare/1.12.4...1.13.0) (2022-11-02)

## [1.12.4](https://github.com/rownd/ios/compare/1.12.3...1.12.4) (2022-10-25)

## [1.12.3](https://github.com/rownd/ios/compare/1.12.2...1.12.3) (2022-10-18)


### Bug Fixes

* **auth:** race condition preventing user data fetch ([#21](https://github.com/rownd/ios/issues/21)) ([44279c4](https://github.com/rownd/ios/commit/44279c40b192c0a8c362512e024e9de02ed235a7))

## [1.12.2](https://github.com/rownd/ios/compare/1.12.1...1.12.2) (2022-10-18)


### Bug Fixes

* **auth:** properly handle concurrent refresh token requests ([#20](https://github.com/rownd/ios/issues/20)) ([d655b9f](https://github.com/rownd/ios/commit/d655b9f2d6b24efde48e4138a1e514d0fed70236))

## [1.12.1](https://github.com/rownd/ios/compare/1.12.0...1.12.1) (2022-10-16)


### Bug Fixes

* **state:** handle fresh install case where store load fails ([930e088](https://github.com/rownd/ios/commit/930e088fd3eb4c80cc731bebb6c41a7e1340fba8))

# [1.12.0](https://github.com/rownd/ios/compare/1.11.0...1.12.0) (2022-10-14)


### Features

* **auth:** add flag to determine whether the access token is valid ([d086255](https://github.com/rownd/ios/commit/d086255d036c539f5fe51191a02ae80e719bfa02))

# [1.11.0](https://github.com/rownd/ios/compare/1.10.2...1.11.0) (2022-10-14)


### Features

* **state:** detect when sdk has finished initializing ([5f24e9f](https://github.com/rownd/ios/commit/5f24e9f122025fe4766e8baf93ae997812d8edfe))

# [1.10.0](https://github.com/rownd/ios/compare/1.9.1...1.10.0) (2022-10-12)


### Bug Fixes

* **build:** xcodeproj corruption ([f4c882e](https://github.com/rownd/ios/commit/f4c882ee2ab598483d97e1bf92388bf809c07da5))
* **google:** don't close hub if error ([#19](https://github.com/rownd/ios/issues/19)) ([7bbd6b0](https://github.com/rownd/ios/commit/7bbd6b07af4118d092fca2ea5c40c156d6c760d1))
* ui inconsistencies & crash in key xfer ([85e40c2](https://github.com/rownd/ios/commit/85e40c2da1eba845ffaabb41d853af45e95b218b))


### Features

* add sign in with google ([#17](https://github.com/rownd/ios/issues/17)) ([fdf5a8a](https://github.com/rownd/ios/commit/fdf5a8a786727164f0958c87a90355bc39fb919d))
* **google:** use iosClientConfig from AppConfig ([#18](https://github.com/rownd/ios/issues/18)) ([a92a0c9](https://github.com/rownd/ios/commit/a92a0c912af4a72f2e56d76711097a3d9d368fad))

## [1.9.1](https://github.com/rownd/ios/compare/1.9.0...1.9.1) (2022-10-02)


### Bug Fixes

* **auth:** working sign-in links ([15476f7](https://github.com/rownd/ios/commit/15476f7967060168e2457e32aab3d3b27e68456e))

# [1.9.0](https://github.com/rownd/ios/compare/1.8.4...1.9.0) (2022-09-28)


### Features

* **customizations:** support lottie animated loading indicators ([#16](https://github.com/rownd/ios/issues/16)) ([1580297](https://github.com/rownd/ios/commit/15802975a5bd25967ad74a348a5435b613b41de6))

## [1.8.4](https://github.com/rownd/ios/compare/1.8.3...1.8.4) (2022-09-26)


### Bug Fixes

* **state:** occasional crash during async state updates ([8fd78bd](https://github.com/rownd/ios/commit/8fd78bdf15db50efda7616fc29192ffa26a7de6f))

## [1.8.3](https://github.com/rownd/ios/compare/1.8.2...1.8.3) (2022-09-22)


### Bug Fixes

* **auth:** decoding issue during token refresh ([a7aaae2](https://github.com/rownd/ios/commit/a7aaae2419875c6c046d1005a3be67018bbc3c95))

## [1.8.2](https://github.com/rownd/ios/compare/1.8.1...1.8.2) (2022-09-19)


### Bug Fixes

* concurrent mutation errors during react native build ([dd5b900](https://github.com/rownd/ios/commit/dd5b900825f488463920df28404e9008da6ca3b5))

## [1.8.1](https://github.com/rownd/ios/compare/1.8.0...1.8.1) (2022-09-16)

# Changelog

All notable changes to this project will be documented in this file. See [standard-version](https://github.com/conventional-changelog/standard-version) for commit guidelines.

## [1.6.0](https://github.com/rownd/ios/compare/v1.1.1...v1.6.0) (2022-08-25)


### Features

* **encryption:** initial api + tests ([#1](https://github.com/rownd/ios/issues/1)) ([6289d42](https://github.com/rownd/ios/commit/6289d426408c15ad86cd9e93e940ff1cbd7480aa))
* **encryption:** initial transfer ui ([5fd7741](https://github.com/rownd/ios/commit/5fd7741acf8da7ef2b58506970ad98d62a54fe7e))
* **encryption:** polish key transfer flow ([5740a01](https://github.com/rownd/ios/commit/5740a015bc42c4d12c88b414fc1c9801ae0f6073))
* **encryption:** security improvements and ui fixes ([7ffdb34](https://github.com/rownd/ios/commit/7ffdb3449d7f6b892d4a36487bdc07d140283e6d))
* **encryption:** support for displaying transfer qr codes ([9087936](https://github.com/rownd/ios/commit/9087936728809608402e660c8e566e66a8e3127e))
* **encryption:** transfer ui improvements ([14f802d](https://github.com/rownd/ios/commit/14f802d2962f5413aea1d59f58e16124f1e293eb))
* **encryption:** ux improvements to transfer views ([16eb78d](https://github.com/rownd/ios/commit/16eb78d895830a92b531a8c95037b4914a80428b))
* improvements to user management and sign-in ([bf37c9e](https://github.com/rownd/ios/commit/bf37c9ed46b40a1835b171fe1bf487b63c4f2b78))
* **os:** now target ios v14+ ([1410178](https://github.com/rownd/ios/commit/141017870bb25602b00e2f023be2f412a541b1af))


### Bug Fixes

* **auth:** failing refresh token flow ([bb81e7a](https://github.com/rownd/ios/commit/bb81e7a305f6e0871226acdc420c2d60a26314e0))
* **auth:** intermittent sign-out issues ([07de523](https://github.com/rownd/ios/commit/07de523087243130f1b987fefc71b36b055d77b8))
* **encrypt:** generate complete qr codes on-demand ([2974a42](https://github.com/rownd/ios/commit/2974a42ed46a8c9ea24e99091f5af678ca9d3cf6))
* **encrypt:** improved error handling ([c842143](https://github.com/rownd/ios/commit/c842143f01fd03371b0c7c61376e30be2991b462))
* **release:** add missin deps ([8dd4132](https://github.com/rownd/ios/commit/8dd41326ef8cd40ce1346824fdc6e2aa7c28c3b2))
* **release:** broken reswift-thunk package name ([05fbb58](https://github.com/rownd/ios/commit/05fbb581fd01a10f64b875273a1110e230d0a2b4))
* **release:** delete unused file ([d2340d8](https://github.com/rownd/ios/commit/d2340d8bf9c308589c7cac44537bd69279a921f8))
* **release:** minimum ios version should be 15 ([ca103ad](https://github.com/rownd/ios/commit/ca103ad82b5bd5eca07ad7f350dfda10c7f965a5))
* **release:** missing comma ([dbdfed6](https://github.com/rownd/ios/commit/dbdfed68d5630fc78718494d3ec17c3f87ae565b))
* **release:** missing comma ([7844b3a](https://github.com/rownd/ios/commit/7844b3ae9e4725b46bde88ee7f072582ccdcf95b))
* **release:** remove reference to unneeded lib ([d9e8252](https://github.com/rownd/ios/commit/d9e8252816c91987c242ff92db0b83c8343ad8bc))
* **release:** remove unused file from target ([6faa196](https://github.com/rownd/ios/commit/6faa196d0946cf4f2db93bac6fd8eb5876ca9a7d))
* **ui:** compatibility with navigation controller ([1dfecb6](https://github.com/rownd/ios/commit/1dfecb64033c4cb9f321a990a5233dec2bcc786c))