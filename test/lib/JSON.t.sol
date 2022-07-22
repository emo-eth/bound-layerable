// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {json} from 'bound-layerable/lib/JSON.sol';
import {StringTestUtility} from '../helpers/StringTestUtility.sol';

contract JsonTest is Test {
    using json for string;
    using StringTestUtility for string;
    using StringTestUtility for string[];

    function testObject(string memory objectContents) public {
        string memory objectified = objectContents.object();
        assertTrue(objectified.startsWith('{'));
        assertTrue(objectified.endsWith('}'));
    }

    function testArray(string memory arrayContents) public {
        string memory arrayified = arrayContents.array();
        assertTrue(arrayified.startsWith('['));
        assertTrue(arrayified.endsWith(']'));
    }

    function testProperty(string memory name, string memory value) public {
        string memory propertyified = json.property(name, value);
        assertTrue(propertyified.startsWith('"'));
        assertTrue(propertyified.endsWith('"'));
        assertTrue(propertyified.contains(bytes1(':')));
        assertTrue(propertyified.startsWith(name.quote()));
        assertTrue(propertyified.endsWith(value.quote()));
    }

    function testRawProperty(string memory name, string memory value) public {
        string memory propertyified = json.rawProperty(name, value);
        assertTrue(propertyified.startsWith('"'));
        if (!value.endsWith('"')) {
            assertFalse(propertyified.endsWith('"'));
        }
        assertTrue(propertyified.contains(bytes1(':')));
        assertTrue(propertyified.startsWith(name.quote()));
        assertTrue(propertyified.endsWith(value));
    }

    function testObjectOf(
        string memory name,
        string memory value,
        uint8 num
    ) public {
        string memory property = num > 0 ? json.property(name, value) : '';
        string[] memory properties = new string[](num);
        for (uint8 i = 0; i < num; i++) {
            properties[i] = property;
        }
        string memory objectified = json.objectOf(properties);
        assertTrue(objectified.startsWith('{'));
        assertTrue(objectified.endsWith('}'));
        assertTrue(objectified.startsWith(string.concat('{', property)));
        assertTrue(objectified.endsWith(string.concat(property, '}')));
        uint256 countNativeComma = property.countChar(',');
        uint256 expectedAddedCommas = num > 0 ? num - 1 : 0;
        uint256 expectedNativeCommas = num * countNativeComma;
        assertEq(
            objectified.countChar(','),
            expectedAddedCommas + expectedNativeCommas
        );
    }

    function testArrayOf(string memory value, uint8 num) public {
        value = num > 0 ? value : '';
        string[] memory values = new string[](num);
        for (uint8 i = 0; i < num; i++) {
            values[i] = value;
        }
        string memory jsonArray = json.arrayOf(values);
        assertTrue(jsonArray.startsWith('['));
        assertTrue(jsonArray.endsWith(']'));
        assertTrue(jsonArray.startsWith(string.concat('[', value)));
        assertTrue(jsonArray.endsWith(string.concat(value, ']')));
        uint256 countNativeComma = value.countChar(',');
        uint256 expectedAddedCommas = num > 0 ? num - 1 : 0;
        uint256 expectedNativeCommas = num * countNativeComma;
        assertEq(
            jsonArray.countChar(','),
            expectedAddedCommas + expectedNativeCommas
        );
    }

    function testArrayOfTwo(
        string memory value,
        uint8 num1,
        uint8 num2
    ) public {
        num1 = uint8(bound(num1, 0, 127));
        num2 = uint8(bound(num2, 0, 127));
        uint256 total = num1 + num2;
        value = total > 0 ? value : '';
        string[] memory values1 = new string[](num1);
        for (uint8 i = 0; i < num1; i++) {
            values1[i] = value;
        }
        string[] memory values2 = new string[](num2);
        for (uint8 i = 0; i < num2; i++) {
            values2[i] = value;
        }
        string memory jsonArray = json.arrayOf(values1, values2);
        emit log_named_string('jsonArray', jsonArray);
        assertTrue(jsonArray.startsWith('['));
        assertTrue(jsonArray.endsWith(']'));
        assertTrue(jsonArray.startsWith(string.concat('[', value)));
        assertTrue(jsonArray.endsWith(string.concat(value, ']')));
        uint256 countNativeComma = value.countChar(',');
        uint256 expectedAddedCommas = total > 0 ? total - 1 : 0;
        uint256 expectedNativeCommas = total * countNativeComma;
        assertEq(
            jsonArray.countChar(','),
            expectedAddedCommas + expectedNativeCommas
        );
    }

    function testQuote(string memory value) public {
        string memory quoted = value.quote();
        assertTrue(quoted.startsWith('"'));
        assertTrue(quoted.endsWith('"'));
        assertTrue(quoted.contains(value));
    }

    function testJoinComma(string memory str, uint8 times) public {
        times = uint8(bound(times, 1, 255));
        string[] memory strings = new string[](times);
        for (uint8 i = 0; i < times; i++) {
            strings[i] = str;
        }
        string memory joined = json._commaJoin(strings);
        assertTrue(joined.startsWith(str));
        assertTrue(joined.endsWith(str));
        uint256 countNativeComma = str.countChar(',');
        uint256 expectedAddedCommas = times - 1;
        uint256 expectedNativeCommas = times * countNativeComma;
        assertEq(
            joined.countChar(','),
            expectedAddedCommas + expectedNativeCommas
        );
    }
}
