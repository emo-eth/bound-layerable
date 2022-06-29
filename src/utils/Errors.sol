// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

error TradingAlreadyDisabled();
error IncorrectPayment();
error ArrayLengthMismatch(uint256 length1, uint256 length2);
error LayerNotBoundToTokenId();
error DuplicateActiveLayers();
error MultipleVariationsEnabled();
error InvalidLayer(uint256 layer);
error BadDistributions();
error NotOwner();
error TraitGenerationSeedNotSet();
error LayerAlreadyBound();
error NotBindable();
