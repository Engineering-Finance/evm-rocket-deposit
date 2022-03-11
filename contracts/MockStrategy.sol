// SPDX-License-Identifier: MIXED
pragma solidity >=0.6.6 <0.9.0;

import "../interfaces/IRocketStrategy.sol";

// strategy that always gives 10% discount.
import "../interfaces/IRocketStrategy.sol";

contract MockStrategy is IRocketStrategy {
    function discount(address _token, uint256 _amount, uint256 _maturity) public view returns (uint256 _mul, uint256 _div) {        
        _mul = 90;
        _div = 100;
    }
}