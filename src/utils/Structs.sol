// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {DisplayType} from "./Enums.sol";

struct Attribute {
    string traitType;
    string value;
    DisplayType displayType;
}

struct LayerVariation {
    uint8 layerId;
    uint8 numVariations;
}
