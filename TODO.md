Features:

- [x] on-chain VRF for reveals
  - [x] batched reveals
  - [x] implement
- [x] separate metadata into separate contract
- [x] investigate manually binding tokens owned by binder
- [x] TwoStepOwnable
  - [x] implement
- [x] Commission/Withdrawable
  - [x] implement
- [x] MaxMintable etc
  - [x] implement
- [x] allowlist
  - [x] implement
- [x] BoundLayerable
- [x] Layerable
- [ ] Token.sol should be full-fledged token with all utils
- [ ] decide on Variations


Optimizations:
- [ ] burnAndBindSingleAndSetActiveLayers methods?
- [x] use uint256s everywhere instead of uint8s
- [x] Genericize LayerType
  - [x] genericize getLayerType

Cleanup:
- [ ] natspec comments
  - [x] BoundLayerable
  - [x] PackedByteUtility
  - [x] BitMapUtility
- [x] remove leading underscores where not necessary to disambiguate
- [x] Split main Layerable functionality out and make ImageLayerable an example contract
- [x] rename bitField to bitMap
- [ ] more helper contracts?
- [ ] rename BatchVRFConsumer

Tests:
- [ ] test that switch to uint256s over uint8s doesn't allow anything weird
- [x] PackedByteUtility
- [x] BitMapUtility
- [ ] BoundLayerable
- [ ] RandomTraits
- [ ] 
- [ ] modifiers

Integration/e2e tests:
- [ ] e2e tests for chainlink vrf
  - [ ] add "integration" foundry profile
  - [ ] add suite of integration tests that run against a testnet when "integration" foundry profile is active
- [ ] 