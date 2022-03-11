// SPDX-License-Identifier: MIXED
pragma solidity >=0.8.10 <0.9.0;
import "./Ownable.sol";

/// @title Blacklistable - block certain wallets from using the contract
contract Blacklistable is Ownable {

    event Blacklisted(address indexed wallet);
    event Whitelisted(address indexed wallet);

    /// @notice blacklist mapping
    mapping(address => bool) public blacklist;

    /// @notice notifier for functions
    modifier notBlacklisted() {
        require(!blacklist[msg.sender]);
        _;
    }

    /// @notice blacklist a wallet
    function blacklistAddress(address _addr) public onlyOwner {
        blacklist[_addr] = true;
        emit Blacklisted(_addr);
    }

    /// @notice unblacklist a wallet
    function whitelistAddress(address _addr) public onlyOwner {
        blacklist[_addr] = false;
        emit Whitelisted(_addr);
    }
}
