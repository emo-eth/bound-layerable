// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PackedByteUtility} from "./PackedByteUtility.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {LayerType} from "./Enums.sol";
import {BadDistributions} from "./Errors.sol";

contract RandomTraits is Ownable {
    using Strings for uint256;

    bytes32 public traitGenerationSeed;

    // 32 possible traits per layerType  given uint8 distributions
    // getLayerId will check if traitValue is less than the distribution
    // so traits distribution cutoffs should be sorted left-to-right
    // ie smallest packed 8-bit segment should be the leftmost 8 bits
    mapping(LayerType => uint256) layerTypeToDistributions;
    // TODO: investigate more granular rarity distributions by packing shorts into 2 uint256's
    // mapping(LayerType => uint256[2]) layerTypeToShortDistributions;
    // mapping(uint256 => uint256[]) layerTypeToTraitIds;
    uint256 immutable NUM_TOKENS_PER_SET;

    constructor(uint256 _numTraitTypes) {
        NUM_TOKENS_PER_SET = _numTraitTypes;
    }

    /////////////
    // SETTERS //
    /////////////

    function setTraitGenerationSeed(bytes32 _traitGenerationSeed)
        public
        onlyOwner
    {
        traitGenerationSeed = _traitGenerationSeed;
    }

    /**
     * @notice Set the probability distribution for up to 32 different layer traitIds
     * @param _layerType layer type to set distribution for
     * @param _distribution a uint256 comprised of sorted, packed bytes
     *  that will be compared against a random byte to determine the layerId
     *  for a given tokenId
     */
    function setLayerTypeDistribution(
        LayerType _layerType,
        uint256 _distribution
    ) public onlyOwner {
        layerTypeToDistributions[_layerType] = _distribution;
    }

    /// @notice Get the random seed for a given tokenId by hashing it with the traitGenerationSeed
    function getLayerSeed(uint256 _tokenId, LayerType _layerType)
        public
        view
        returns (uint256)
    {
        return
            uint256(
                keccak256(abi.encode(traitGenerationSeed, _tokenId, _layerType))
            );
    }

    /**
     * @notice Determine layer type by its token ID
     */
    function getLayerType(uint256 _tokenId) public view returns (LayerType) {
        // might break tests but could move objects and borders to front:
        // LayerType((_tokenId % NUM_TOKENS_PER_SET) % 5);
        uint256 layerTypeValue = _tokenId % NUM_TOKENS_PER_SET;
        if (layerTypeValue == 4) {
            // objects
            return LayerType(3);
        } else if (layerTypeValue == 5 || layerTypeValue == 6) {
            // borders
            return LayerType(4);
        }
        // portraits, backgrounds, textures
        return LayerType(layerTypeValue);
    }

    /**
     * @notice Get the layerId for a given tokenId by hashing tokenId with the random seed
     * and comparing the final byte against the appropriate distributions
     */
    function getLayerId(uint256 _tokenId) public view returns (uint256) {
        LayerType layerType = getLayerType(_tokenId);
        uint256 layerSeed = getLayerSeed(_tokenId, layerType) & 0xff;
        uint256 distributions = layerTypeToDistributions[layerType];
        // iterate over distributions until we find one that our layer seed is *less than*
        uint256 i;
        for (; i < 32; ) {
            uint8 distribution = PackedByteUtility.getPackedByteFromLeft(
                i,
                distributions
            );
            // if distribution is 0, we've reached the end of the list
            if (distribution == 0) {
                if (i > 0) {
                    return (i + 1) + 32 * uint256(layerType);
                } else {
                    // first distribution should not be 0
                    revert BadDistributions();
                }
            }
            // note: for layers with multiple variations, the same value should be packed multiple times
            if (layerSeed < distribution) {
                return (i + 1) + 32 * uint256(layerType);
            }
            unchecked {
                ++i;
            }
        }
        // in the case that there are 32 distributions, default to the last id
        return (i) + 32 * uint256(layerType);
    }

    // function getLayerId2(uint256 _tokenId) public view returns (uint256) {
    //     LayerType layerType = getLayerType(_tokenId);
    //     uint256 layerSeed = getLayerSeed(_tokenId, layerType) & 0xffff;
    //     // uint256 distributions = layerTypeToDistributions[layerType];
    //     // iterate over distributions until we find one that our layer seed is *less than*
    //     uint256 i;
    //     uint256[2] memory distributions16Bit = layerTypeTo16BitDistributions[
    //         layerType
    //     ];
    //     for (uint256 j; j < 2; ) {
    //         uint256 distribution = PackedByteUtility.getPackedByteFromLeft(
    //             i,
    //             distributions16Bit[j]
    //         );
    //         for (; i < 16; ) {
    //             uint16 distributions = PackedByteUtility.getPackedShortFromLeft(
    //                 i,
    //                 distributions
    //             );
    //             // if distribution is 0, we've reached the end of the list
    //             if (distribution == 0) {
    //                 if (i > 0) {
    //                     return i + 32 * uint256(layerType);
    //                 } else {
    //                     // first distribution should not be 0
    //                     revert BadDistributions();
    //                 }
    //             }
    //             // note: for layers with multiple variations, the same value should be packed multiple times
    //             if (layerSeed < distribution) {
    //                 return i + 32 * uint256(layerType);
    //             }
    //             unchecked {
    //                 ++i;
    //             }
    //         }
    //     }
    //     // in the case that there are 32 distributions, default to the last id
    //     return (i - 1) + 32 * uint256(layerType);

    //     // revert("Something went wrong getting Trait ID");
    // }
}