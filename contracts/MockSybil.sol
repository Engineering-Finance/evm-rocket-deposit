// SPDX-License-Identifier: MIXED
pragma solidity >=0.6.6 <0.9.0;

import "../interfaces/ISybil.sol";
import "../interfaces/IERC20.sol";


// this is for testing purposes, it pretends any token price to be 1 USD, and BNB/ETH
// to be 1 USD also.
contract MockSybil is ISybil {
    
    function getBuyPrice(address token, uint256 amount) external pure returns (uint256) {
        return amount;
    }

    function getSellPrice(address token, uint256 amount) external pure returns (uint256) {
        return amount;
    }

    function getBuyPriceAs(string memory currency, address token, uint256 amount) external pure returns (uint256) {
        return amount;
    }

    function getSellPriceAs(string memory currency, address token, uint256 amount) external pure returns (uint256) {
        return amount;
    }
}