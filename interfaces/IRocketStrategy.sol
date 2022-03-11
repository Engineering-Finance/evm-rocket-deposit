// SPDX-License-Identifier: MIXED
pragma solidity >=0.8.10 <0.9.0;

/**
 * @notice Rocket deposits work by incentivizing users to deposit tokens by giving them a discount
 * @notice on their purchase in exchange for keeping their tokens locked in a contract for a certain
 * @notice amount of time.
 **/
interface IRocketStrategy {

    /**
     * @notice IRocketStategy returns the discount depending on the _token used to make the sale,
     * @notice the _amount purchased, and the _lock_time amount of time to maturity.
     * @param _token The token used to make the sale
     * @param _amount The amount purchased
     * @param _lock_time The amount of time to maturity
     * @return _mul discount multiplier
     * @return _div discount divisor
     **/
    function discount(address _token, uint256 _amount, uint256 _lock_time) external view returns (uint256 _mul, uint256 _div);
}