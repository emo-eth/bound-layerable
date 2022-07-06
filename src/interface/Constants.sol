// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

uint256 constant NOT_0TH_BITMASK = 2**256 - 2;
uint256 constant MAX_INT = 2**256 - 1;
uint136 constant _2_128 = 2**128;
uint72 constant _2_64 = 2**64;
uint40 constant _2_32 = 2**32;
uint24 constant _2_16 = 2**16;
uint16 constant _2_8 = 2**8;
uint8 constant _2_4 = 2**4;
uint8 constant _2_2 = 2**2;
uint8 constant _2_1 = 2**1;

uint128 constant _128_MASK = 2**128 - 1;
uint64 constant _64_MASK = 2**64 - 1;
uint32 constant _32_MASK = 2**32 - 1;
uint16 constant _16_MASK = 2**16 - 1;
uint8 constant _8_MASK = 2**8 - 1;
uint8 constant _4_MASK = 2**4 - 1;
uint8 constant _2_MASK = 2**2 - 1;
uint8 constant _1_MASK = 2**1 - 1;

uint256 constant DUPLICATE_ACTIVE_LAYERS_SIGNATURE = 0x6411ce7500000000000000000000000000000000000000000000000000000000;
uint256 constant LAYER_NOT_BOUND_TO_TOKEN_ID_SIGNATURE = 0xa385f80500000000000000000000000000000000000000000000000000000000;
uint256 constant BAD_DISTRIBUTIONS_SIGNATURE = 0x326fd31d00000000000000000000000000000000000000000000000000000000;
uint256 constant MULTIPLE_VARIATIONS_ENABLED_SIGNATURE = 0x4d2e939600000000000000000000000000000000000000000000000000000000;
