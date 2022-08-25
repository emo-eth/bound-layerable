# BoundLayerable

BoundLayerable is a set of smart contracts for minting and then composing layerable NFTs on-chain.

## The BoundLayerable flow:

-   A user mints a set of N "layers" efficiently using ERC721A
    -   The first is a "base" or "bindable" layer
-   Layers are revealed on-chain
-   Users can burn a layer to "bind" it to their base layer
-   Users can update the base layer's metadata on-chain to show/hide and reorder layers

## Technical specs

-   Secure on-chain randomness using ChainLink VRF
-   8 types of layers
    -   Up to 32 unique layers per "type" elements, except the 8th type, which supports 31 unique layers
    -   255 total unique layers
    -   16-bit granularity (~0.0015%) for trait rarity
-   Up to 32 "Active" layers at once
-   Traits and metadata stored on-chain
-   Updateable metadata contract
