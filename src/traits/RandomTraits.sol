// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {PackedByteUtility} from '../lib/PackedByteUtility.sol';
import {Strings} from 'openzeppelin-contracts//utils/Strings.sol';
import {LayerType} from '../interface/Enums.sol';
import {BadDistributions, TraitGenerationSeedNotSet} from '../interface/Errors.sol';
import {BatchVRFConsumer} from '../vrf/BatchVRFConsumer.sol';

abstract contract RandomTraits is BatchVRFConsumer {
    using Strings for uint256;

    // 32 possible traits per layerType given uint8 distributions
    // except final trait type, which has 31, because 0 is not a valid layerId
    // getLayerId will check if traitValue is less than the distribution,
    // so traits distribution cutoffs should be sorted left-to-right
    // ie smallest packed 8-bit segment should be the leftmost 8 bits
    mapping(uint8 => uint256) layerTypeToPackedDistributions;

    constructor(
        string memory name,
        string memory symbol,
        address vrfCoordinatorAddress,
        uint256 maxNumSets,
        uint8 numTokensPerSet,
        uint64 subscriptionId
    )
        BatchVRFConsumer(
            name,
            symbol,
            vrfCoordinatorAddress,
            maxNumSets,
            numTokensPerSet,
            subscriptionId
        )
    {}

    /////////////
    // SETTERS //
    /////////////

    /**
     * @notice Set the probability distribution for up to 32 different layer traitIds
     * @param layerType layer type to set distribution for
     * @param distribution a uint256 comprised of sorted, packed bytes
     *  that will be compared against a random byte to determine the layerId
     *  for a given tokenId
     */
    function setLayerTypeDistribution(uint8 layerType, uint256 distribution)
        public
        onlyOwner
    {
        layerTypeToPackedDistributions[layerType] = distribution;
    }

    /// @notice Get the random seed for a given tokenId by hashing it with the traitGenerationSeed
    function getLayerSeed(uint256 tokenId, uint8 layerType)
        internal
        view
        returns (uint8)
    {
        // TODO: revisit this optimization if via_ir is enabled
        bytes32 seed = traitGenerationSeed;
        if (seed == 0) {
            revert TraitGenerationSeedNotSet();
        }
        return getLayerSeed(tokenId, layerType, seed);
    }

    function getLayerSeed(
        uint256 tokenId,
        uint8 layerType,
        bytes32 seed
    ) internal pure returns (uint8) {
        return uint8(uint256(keccak256(abi.encode(seed, tokenId, layerType))));
    }

    /**
     * @notice Determine layer type by its token ID
     */
    function getLayerType(uint256 tokenId)
        public
        view
        virtual
        returns (uint8 layerType);

    /**
     * @notice Get the layerId for a given tokenId by hashing tokenId with the random seed
     * and comparing the final byte against the appropriate distributions
     */
    function getLayerId(uint256 tokenId) public view virtual returns (uint256) {
        uint8 layerType = getLayerType(tokenId);
        uint256 layerSeed = getLayerSeed(tokenId, layerType);
        uint256 distributions = layerTypeToPackedDistributions[layerType];
        return getLayerId(layerType, layerSeed, distributions);
    }

    function getLayerId(uint256 tokenId, bytes32 seed)
        internal
        view
        virtual
        returns (uint256)
    {
        uint8 layerType = getLayerType(tokenId);
        uint256 layerSeed = getLayerSeed(tokenId, layerType, seed);
        uint256 distributions = layerTypeToPackedDistributions[layerType];
        return getLayerId(layerType, layerSeed, distributions);
    }

    function getLayerId(
        uint8 layerType,
        uint256 seed,
        uint256 distributions
    ) internal pure returns (uint256 layerId) {
        assembly {
            function revertWithBadDistributions() {
                let freeMem := mload(0x40)
                mstore(
                    freeMem,
                    0x326fd31d00000000000000000000000000000000000000000000000000000000
                )
                revert(freeMem, 0x20)
            }

            let i
            // iterate over distributions until we find one that our layer seed is *less than*
            for {

            } lt(i, 32) {
                i := add(1, i)
            } {
                let dist := byte(i, distributions)
                if iszero(dist) {
                    if gt(i, 0) {
                        // if distribution is 0, and it's not the first, we've reached the end of the list
                        // return the previous layerId.
                        layerId := add(add(1, i), mul(32, layerType))
                        break
                    }
                    // first element should never be 0; distributions are invalid
                    revertWithBadDistributions()
                }
                if lt(seed, dist) {
                    // if i is 31 here, math will overflow here if layerType == 7
                    // 31 + 1 + 32 * 7 = 256, which is too large for a uint8
                    if and(eq(i, 31), eq(layerType, 7)) {
                        revertWithBadDistributions()
                    }

                    // layerIds are 1-indexed, so add 1 to i
                    layerId := add(add(1, i), mul(32, layerType))
                    break
                }
            }
            // if i is 32, we've reached the end of the list and should default to the last id
            if eq(i, 32) {
                // math will overflow here if layerType == 7
                // 32 + 32 * 7 = 256, which is too large for a uint8
                if eq(layerType, 7) {
                    revertWithBadDistributions()
                }
                // return previous layerId
                layerId := add(i, mul(32, layerType))
            }
        }
    }
}
