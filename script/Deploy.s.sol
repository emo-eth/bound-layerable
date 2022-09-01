// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {Script} from 'forge-std/Script.sol';
import {TestnetToken} from '../src/implementations/TestnetToken.sol';
import {Layerable} from '../src/metadata/Layerable.sol';
import {ImageLayerable} from '../src/metadata/ImageLayerable.sol';
import {Attribute} from '../src/interface/Structs.sol';
import {DisplayType} from '../src/interface/Enums.sol';
import {Strings} from 'openzeppelin-contracts/contracts/utils/Strings.sol';
import {Solenv} from 'solenv/Solenv.sol';

contract Deploy is Script {
    using Strings for uint256;

    struct AttributeTuple {
        uint256 traitId;
        string name;
    }

    function getLayerTypeStr(uint256 layerId)
        public
        pure
        returns (string memory result)
    {
        uint256 layerType = (layerId - 1) / 32;
        if (layerType == 0) {
            result = 'Portrait';
        } else if (layerType == 1) {
            result = 'Background';
        } else if (layerType == 2) {
            result = 'Border';
        } else if (layerType == 5) {
            result = 'Texture';
        } else if (layerType == 3 || layerType == 4) {
            result = 'Element';
        } else {
            result = 'Special';
        }
    }

    function setUp() public virtual {
        Solenv.config();
    }

    function run() public {
        address deployer = vm.envAddress('DEPLOYER');
        vm.startBroadcast(deployer);
        // if (chainId == 4) {coordinator 0x6168499c0cFfCaCD319c818142124B7A15E857ab
        // } else if (chainId == 137) {
        //     coordinator = 0xAE975071Be8F8eE67addBC1A82488F1C24858067;
        // } else if (chainId == 80001) {
        //     coordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
        // } else {
        //     coordinator = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;
        // }
        // emit log_named_address('coordinator', coordinator);

        AttributeTuple[164] memory attributeTuples = [
            AttributeTuple(3, 'Portrait A3'),
            AttributeTuple(9, 'Portrait C1'),
            AttributeTuple(1, 'Portrait A4'),
            AttributeTuple(4, 'Portrait B2'),
            AttributeTuple(8, 'Portrait C2'),
            AttributeTuple(5, 'Portrait A2'),
            AttributeTuple(6, 'Portrait A1'),
            AttributeTuple(2, 'Portrait B3'),
            AttributeTuple(7, 'Portrait B1'),
            AttributeTuple(41, 'Cranium'),
            AttributeTuple(60, 'Dirty Grid Paper'),
            AttributeTuple(42, 'Disassembled'),
            AttributeTuple(44, 'Postal Worker'),
            AttributeTuple(56, 'Angled Gradient'),
            AttributeTuple(36, 'Haze'),
            AttributeTuple(35, 'Upside Down'),
            AttributeTuple(50, 'Shoebox'),
            AttributeTuple(62, 'Blue'),
            AttributeTuple(40, '100 Dollars'),
            AttributeTuple(45, 'Close-up'),
            AttributeTuple(37, 'Sticky Fingers'),
            AttributeTuple(38, 'Top Secret'),
            AttributeTuple(64, 'Off White'),
            AttributeTuple(34, 'Censorship Can!'),
            AttributeTuple(49, '13 Years Old'),
            AttributeTuple(53, 'Washed Out'),
            AttributeTuple(61, 'Grunge Paper'),
            AttributeTuple(54, 'Marbled Paper'),
            AttributeTuple(46, 'Gene Sequencing'),
            AttributeTuple(51, 'Geological Study'),
            AttributeTuple(48, 'Refractory Factory'),
            AttributeTuple(43, 'Day Trader'),
            AttributeTuple(58, 'Linear Gradient'),
            AttributeTuple(63, 'Red'),
            AttributeTuple(47, 'Seedphrase'),
            AttributeTuple(33, 'Split'),
            AttributeTuple(52, 'Clouds'),
            AttributeTuple(55, 'Warped Gradient'),
            AttributeTuple(39, 'Fractals'),
            AttributeTuple(59, 'Spheres'),
            AttributeTuple(57, 'Radial Gradient'),
            AttributeTuple(192, 'Subtle Dust'),
            AttributeTuple(167, 'Rips Bottom'),
            AttributeTuple(171, 'Restricted'),
            AttributeTuple(186, 'Dirty'),
            AttributeTuple(168, 'Crusty Journal'),
            AttributeTuple(181, 'Plastic & Sticker'),
            AttributeTuple(174, 'Folded Paper Stack'),
            AttributeTuple(177, 'Extreme Dust & Grime'),
            AttributeTuple(179, 'Folded Paper'),
            AttributeTuple(165, 'Rips Top'),
            AttributeTuple(180, 'Midline Destroyed'),
            AttributeTuple(184, 'Wax Paper'),
            AttributeTuple(182, 'Wrinkled'),
            AttributeTuple(163, 'Crinkled & Torn'),
            AttributeTuple(169, 'Burn It'),
            AttributeTuple(185, 'Wheatpasted'),
            AttributeTuple(162, 'Perfect Tear'),
            AttributeTuple(161, 'Puzzle'),
            AttributeTuple(176, 'Old Document'),
            AttributeTuple(172, 'Destroyed Edges'),
            AttributeTuple(187, 'Magazine Glare'),
            AttributeTuple(178, 'Water Damage'),
            AttributeTuple(189, 'Inked'),
            AttributeTuple(166, 'Rips Mid'),
            AttributeTuple(173, 'Grainy Cover'),
            AttributeTuple(175, 'Single Fold'),
            AttributeTuple(188, 'Scanner'),
            AttributeTuple(190, 'Heavy Dust & Scratches'),
            AttributeTuple(191, 'Dust & Scratches'),
            AttributeTuple(183, 'Slightly Wrinkled'),
            AttributeTuple(170, 'Scuffed Up'),
            AttributeTuple(164, 'Torn & Taped'),
            AttributeTuple(148, 'TSA Sticker'),
            AttributeTuple(118, 'Postage Sticker'),
            AttributeTuple(157, 'Scribble 2'),
            AttributeTuple(121, 'Barcode Sticker'),
            AttributeTuple(113, 'Time Flies'),
            AttributeTuple(117, 'Clearance Sticker'),
            AttributeTuple(120, 'Item Label'),
            AttributeTuple(151, 'Record Sticker'),
            AttributeTuple(144, 'Monday'),
            AttributeTuple(149, 'Used Sticker'),
            AttributeTuple(112, 'Cutouts 2'),
            AttributeTuple(114, 'There'),
            AttributeTuple(116, 'Dossier Cut Outs'),
            AttributeTuple(153, 'Abstract Lines'),
            AttributeTuple(119, 'Special Sticker'),
            AttributeTuple(150, 'Bora Bora'),
            AttributeTuple(123, 'Alphabet'),
            AttributeTuple(124, 'Scribble 3'),
            AttributeTuple(155, 'Border Accents'),
            AttributeTuple(154, 'Sphynx'),
            AttributeTuple(125, 'Scribble 1'),
            AttributeTuple(115, 'SQR'),
            AttributeTuple(111, 'Cutouts 1'),
            AttributeTuple(145, 'Here'),
            AttributeTuple(146, 'Pointless Wayfinder'),
            AttributeTuple(122, 'Yellow Sticker'),
            AttributeTuple(156, 'Incomplete Infographic'),
            AttributeTuple(152, 'Shredded Paper'),
            AttributeTuple(147, 'Merch Sticker'),
            AttributeTuple(107, 'Chain-Links'),
            AttributeTuple(104, 'Weird Fruits'),
            AttributeTuple(143, 'Cutouts 3'),
            AttributeTuple(135, 'Floating Cactus'),
            AttributeTuple(140, 'Favorite Number'),
            AttributeTuple(109, 'Botany'),
            AttributeTuple(98, 'Puddles'),
            AttributeTuple(100, 'Game Theory'),
            AttributeTuple(137, 'Zeros'),
            AttributeTuple(130, 'Title Page'),
            AttributeTuple(136, 'Warning Labels'),
            AttributeTuple(131, 'Musical Chairs'),
            AttributeTuple(108, 'Windows'),
            AttributeTuple(102, 'Catz'),
            AttributeTuple(110, 'Facial Features'),
            AttributeTuple(105, 'Mindless Machines'),
            AttributeTuple(99, 'Asymmetry'),
            AttributeTuple(134, 'Meat Sweats'),
            AttributeTuple(142, 'Factory'),
            AttributeTuple(139, 'I C U'),
            AttributeTuple(132, 'Too Many Eyes'),
            AttributeTuple(101, 'Floriculture'),
            AttributeTuple(141, 'Anatomy Class'),
            AttributeTuple(129, 'Rubber'),
            AttributeTuple(133, 'Marked'),
            AttributeTuple(97, 'Split'),
            AttributeTuple(103, 'Some Birds'),
            AttributeTuple(106, 'Unhinged'),
            AttributeTuple(138, 'Mediocre Painter'),
            AttributeTuple(95, 'Simple Curved Border'),
            AttributeTuple(92, 'Taped Edge'),
            AttributeTuple(94, 'Simple Border With Square'),
            AttributeTuple(65, 'Dossier'),
            AttributeTuple(79, 'Sunday'),
            AttributeTuple(93, 'Cyber Frame'),
            AttributeTuple(75, 'Sigmund Freud'),
            AttributeTuple(70, 'EyeCU'),
            AttributeTuple(80, 'Expo 86'),
            AttributeTuple(76, 'Form'),
            AttributeTuple(86, 'Collectors General Warning'),
            AttributeTuple(71, 'Slime Magazine'),
            AttributeTuple(88, 'S'),
            AttributeTuple(72, 'Incomplete'),
            AttributeTuple(81, "Shopp'd"),
            AttributeTuple(66, 'Ephemera'),
            AttributeTuple(74, 'Animal Pictures'),
            AttributeTuple(85, 'Sundaze'),
            AttributeTuple(67, 'ScamAbro'),
            AttributeTuple(96, 'Simple White Border'),
            AttributeTuple(89, 'Maps'),
            AttributeTuple(83, '1977'),
            AttributeTuple(87, 'Dissection Kit'),
            AttributeTuple(90, 'Photo Album'),
            AttributeTuple(73, 'CNSRD'),
            AttributeTuple(69, 'CULT'),
            AttributeTuple(82, 'Area'),
            AttributeTuple(91, 'Baked Beans'),
            AttributeTuple(68, 'Masterpiece'),
            AttributeTuple(84, 'Half Banner'),
            AttributeTuple(78, 'Mushroom Farm'),
            AttributeTuple(77, 'Razor Blade'),
            AttributeTuple(255, 'Slimesunday 1 of 1')
        ];

        Attribute[] memory attributes = new Attribute[](attributeTuples.length);
        uint256[] memory traitIds = new uint256[](attributeTuples.length);
        for (uint256 i; i < attributeTuples.length; i++) {
            attributes[i] = Attribute(
                getLayerTypeStr(attributeTuples[i].traitId),
                attributeTuples[i].name,
                DisplayType.String
            );
            traitIds[i] = attributeTuples[i].traitId;
        }

        TestnetToken token = new TestnetToken();

        ImageLayerable(address(token.metadataContract())).setAttributes(
            traitIds,
            attributes
        );
        ImageLayerable(address(token.metadataContract())).setBaseLayerURI(
            'ipfs://bafybeihdhwqwskwwv3zdeousavfe5h4lbtxbqqz6yzrlgkzoui7h3smso4/'
        );
    }
}
