EXPAND:

-   configurable lock
-   lock layers from transfer?
-   use setAux to track date composed
-   limited signature layer for those minted in first week
-   first x slime holders
-   authorized burn function for future composability?
-   [ ] unset forceUnsafeReveal when unsafe revealing

Features:

-   [x] add "Layer Count" to base layers
-   [x] on-chain VRF for reveals
    -   [x] batched reveals
    -   [x] implement
-   [x] separate metadata into separate contract
-   [x] investigate manually binding tokens owned by binder
-   [x] TwoStepOwnable
    -   [x] implement
-   [x] Commission/Withdrawable
    -   [x] implement
-   [x] MaxMintable etc
    -   [x] implement
-   [x] allowlist
    -   [x] implement
-   [x] BoundLayerable
-   [x] Layerable
-   [ ] Token.sol should be full-fledged token with all utils
-   [x] decide on Variations
    -   [ ] punted for now, need to consider how to optimize
-   [ ] Placeholder image per layerType?
-   [ ] admin role in addition to owner?
-   [ ] EIP-2981

Optimizations:

-   [ ] burnAndBindSingleAndSetActiveLayers methods?
-   [x] use uint256s everywhere instead of uint8s
-   [x] Genericize LayerType
    -   [x] genericize getLayerType
-   [ ] remove DisplayType from Attribute?
-   [ ] consider storing Attributes using SSTORE2
    -   [ ] probably punt to later version
-   [ ] consider removing vrfCoordinatorAddress as constructor param and set via chainId (larger deploy size)

Cleanup:

-   [ ] natspec comments
    -   [x] BoundLayerable
    -   [x] PackedByteUtility
    -   [x] BitMapUtility
    -   [x] Layerable
    -   [x] ImageLayerable
    -   [x] JSON
-   [x] remove leading underscores where not necessary to disambiguate
-   [x] Split main Layerable functionality out and make ImageLayerable an example contract
-   [x] rename bitField to bitMap
-   [ ] more helper contracts?
-   [ ] rename BatchVRFConsumer
-   [ ] remove/update todos in comments
-   [x] rename traitGenerationSeed
-   [x] remove maxmintable etc and import utility-contracts
-   [ ] figure out why forge doesn't replace revert codes w error name
-   [ ] make subscription mutable?

Tests:

-   [ ] test that switch to uint256s over uint8s doesn't allow anything weird
-   [ ] test that switch to uint32 disguised as bytes32 for traitgenerationseed doesn't allow anything weird
-   [x] PackedByteUtility
-   [x] BitMapUtility
-   [x] BoundLayerable
-   [x] RandomTraits
-   [ ] modifiers
-   [ ] Layerable
-   [ ] ImageLayerable
-   [ ] BoundLayerable -> Layerable
-   [ ] BoundLayerable new combined BurnAndSetActive methods

Integration/e2e tests:

-   [ ] e2e tests for chainlink vrf
    -   [ ] add "integration" foundry profile
    -   [ ] add suite of integration tests that run against a testnet when "integration" foundry profile is active

v0.2

-   [ ] variations
-   [ ] sstore2
-   [ ] multiple attributes per layer
