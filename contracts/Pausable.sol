// SPDX-License-Identifier: MIXED
pragma solidity >=0.6.6 <0.9.0;
import "./Ownable.sol";

contract Pausable is Ownable {

    bool public is_paused = false;

    modifier notPaused() {
        require(is_paused == false);
        _;
    }

    function pause() external onlyOwner {
        is_paused = true;
    }

    function unpause() external onlyOwner {
        is_paused = false;
    }
}
