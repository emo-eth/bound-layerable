// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {StringTestUtility} from './StringTestUtility.sol';

contract StringtestUtilityTest is Test {
    using StringTestUtility for string;

    function testStartsWith() public {
        string memory test = 'test';
        string memory ref = 'test';
        assertTrue(ref.startsWith(test));
        ref = 'test2';
        assertTrue(ref.startsWith(test));
        test = 'test3';
        assertFalse(ref.startsWith(test));
    }

    function testEndsWith() public {
        string memory test = 'test';
        string memory ref = 'test';
        assertTrue(ref.endsWith(test));
        ref = '2test';
        assertTrue(ref.endsWith(test));
        test = '3test';
        assertFalse(ref.endsWith(test));
    }

    function testEquals(string memory test) public {
        assertTrue(test.equals(test));
        string memory modified = string.concat(test, 'a');
        assertFalse(test.equals(modified));
    }

    function testEndsWith(string memory suffix) public {
        string memory ref = string.concat('prefix', suffix);
        assertTrue(ref.endsWith(suffix));
    }

    function testStartsWith(string memory prefix) public {
        string memory ref = string.concat(prefix, 'suffix');
        assertTrue(ref.startsWith(prefix));
    }

    function testFuzzContains(string memory test) public {
        string memory ref = string.concat('prefix', test, 'suffix');
        assertTrue(ref.contains(test));
    }

    // function testFuzzContainsFixedSuffix(
    //     string memory test,
    //     string memory prefix
    // ) public {
    //     string memory ref = string.concat(prefix, test, 'suffix');
    //     assertTrue(ref.contains(test));
    // }

    // function testFuzzContainsFixedPrefix(
    //     string memory test,
    //     string memory suffix
    // ) public {
    //     string memory ref = string.concat('prefix', test, suffix);
    //     assertTrue(ref.contains(test));
    // }

    function testContainsString() public {
        string memory ref = 'prefixsuffix';
        assertFalse(ref.contains('hello'));
        assertTrue(ref.contains('prefix'));
        assertTrue(ref.contains('suffix'));
    }
}
