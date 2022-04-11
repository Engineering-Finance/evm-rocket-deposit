// SPDX-License-Identifier: MIXED
pragma solidity >=0.6.6 <0.9.0;

import "../interfaces/IERC20.sol";
import "../interfaces/ISybil.sol";
import "../interfaces/IRocketStrategy.sol";
import "../interfaces/IRocketDeposit.sol";
import "./Ownable.sol";
import "./Context.sol";
import "./Pausable.sol";
import "./Blacklistable.sol";


/**
 * @title RocketDeposit
 * @notice Defines a method for buying a certain quantity _asset tokens using _token tokens.
 * @notice The certains will be locked for a certain period of time and will be available for
 * @notice harvest after the period of time has passed.
 */
contract RocketDeposit is Ownable, Pausable, Blacklistable, IRocketDeposit {
    
    event SetMaturity(address indexed from, uint256 old_maturity, uint256 new_maturity);
    event SetSybil(address indexed _from, address indexed old_oracle, address indexed new_oracle);
    event SetStrategy(address indexed _from, address indexed old_strategy, address indexed new_strategy);
    event SetTreasury(address indexed _from, address indexed old_treasury, address indexed new_treasury);

    /**
     * @notice We are going to want to sell _asset tokens for a different type of tokens such
     * @notice as BUSD, DAI, BNB, etc. So we need to define a mapping between the tokens we are
     * @notice selling to the amount of asset available for sale.
     **/
    mapping(address => uint256) public allocations;
    
    /**
     * @notice the address of the asset, i.e. the token we are selling.
     */
    IERC20 private asset;

    /**
     * @notice the amount of time for the rocket deposit to mature, in seconds.
     * @dev set this to 21 days by default.
     */
    uint256 private lock_time = 60 * 60 * 24 * 21;

    /**
     * @notice sybil is an oracle-like contract that will provide the price of the asset
     * @notice depending on purchased quantity. See L<ISybil>.
     */
    ISybil public sybil;

    /**
     * @notice the strategy gives us discount % depending on token we are buying
     * @notice amount of tokens, and maturity.
     */
    IRocketStrategy public bond_strategy;

    // stored the amount of locked asset and the timestamp to release.
    struct Locked {
        uint256 amount; // amount to be released
        uint256 timestamp; // time to release
    }

    /**
     * @notice mapping between wallets and locked asset & timestamp to release.
     */
    mapping(address => Locked) public locked_asset;

    /**
     * @notice where we should be sending the funds to.
     */
    IERC20 private treasury;

    /**
     * @notice Constructor
     * @param _asset the address of the asset token
     * @param _sybil the address of the sybil oracle
     * @param _strategy the address of the bond strategy
     * @param _treasury the address of the treasury wallet
     */
    constructor(
        address _asset,
        address _sybil,
        address _strategy,
        address _treasury) Ownable() Pausable() Blacklistable()
    {
        asset = IERC20(_asset);
        sybil = ISybil(_sybil);
        bond_strategy = IRocketStrategy(_strategy);
        treasury = IERC20(_treasury);
    }

    /**
     * @notice changes the time to lock (maturity) in seconds.
     * @param _seconds the time to lock in seconds.
     */
    function setMaturity(uint256 _seconds) external onlyOwner {
        emit SetMaturity(_msgSender(), lock_time, _seconds);
        lock_time = _seconds;
    }

    /**
     * @notice changes the oracle used to determine the price of the asset token.
     * @param _sybil the address of the sybil.
     */
    function setSybil(address _sybil) external onlyOwner {
        emit SetSybil(_msgSender(), address(sybil), _sybil);
        sybil = ISybil(_sybil);
    }

    /**
     * @notice changes the strategy used to determine the discount.
     * @param _strategy the address of the strategy.
     */
    function setStrategy(address _strategy) external onlyOwner {
        emit SetStrategy(_msgSender(), address(bond_strategy), _strategy);
        bond_strategy = IRocketStrategy(_strategy);
    }

    /**
     * @notice changes the treasury wallet.
     * @param _treasury the address of the treasury.
     */
    function setTreasury(address _treasury) external onlyOwner {
        emit SetTreasury(_msgSender(), address(treasury), _treasury);
        treasury = IERC20(_treasury);
    }

    /**
     * @notice allocates _amount of asset to be sold at a discount for _token
     * @param _token address of the token we are selling asset for
     * @param _amount amount of asset token to be sold.
     */
    function allocate(address _token, uint256 _amount) public onlyOwner {
        require(asset.allowance(_msgSender(), address(this)) >= _amount);

        // transfer the asset tokens from _owner to the contract
        asset.transferFrom(_msgSender(), address(this), _amount);

        // add the amount of allocated asset to the _token -> allocated amount mapping
        allocations[_token] += _amount;
    }

    // deallocate operations below are symmetrical and opposite to the
    // allocate operations.

    /**
     * @notice deallocates token to be sold at a discount
     * @param _token address of the token we are selling asset for
     * @param _amount amount of asset token to be sold
     */
    function deallocate(address _token, uint256 _amount) public onlyOwner {
        deallocateTo(_msgSender(), _token, _amount);
    }

    /**
     * @notice deallocates all asset for a certain token.
     * @param _token address of the token we are selling asset for
     */
    function deallocate(address _token) public onlyOwner {
        deallocateTo(_msgSender(), _token, allocations[_token]);
    }

    /**
     * @notice deallocates all asset for a certain token, and sends it to some address.
     * @notice Requires the contract to be allowed to spend these tokens from the address.
     * @param _to address of the token owner
     * @param _token address of the token we are selling asset for
     */
    function deallocateTo(address _to, address _token) public onlyOwner {
        deallocateTo(_to, _token, allocations[_token]);
    }

    /**
     * @notice deallocates token to be sold to a certain address. This
     * @notice requires the contract to be allowed to spend these tokens from the
     * @notice address.
     * @param _to address of the token owner
     * @param _token address of the token we are selling asset for
     * @param _amount amount of token to be sold
     */
    function deallocateTo(address _to, address _token, uint256 _amount) public onlyOwner {

        // make sure there are enough asset tokens to deallocate
        require(allocations[_token] >= _amount);

        // remove the asset tokens from the mapping
        allocations[_token] -= _amount;

        // transfer the asset tokens
        asset.transfer(_to, _amount);
    }

    /**
     * @notice returns the amount of asset tokens allocated for a certain token
     * @param _token address of the token we are selling asset for
     * @return balance_ uint256 amount of remaining allocated asset tokens
     */
    function allocationBalance(address _token) public view returns (uint256 balance_) {
        balance_ = allocations[_token];
    }


    /**
     * @notice returns how much it would cost to buy _amount asset tokens
     * @param _token token to use for purchasing asset
     * @param _amount amount of asset tokens to be bought
     * @return price_ t1he value of tokens expressed in BNB it would cost
     */
    function quoteBNB(address _token, uint256 _amount) public view returns (uint256) {
        uint256 _tokenPricePerBNB = sybil.getBuyPrice(_token, IERC20(_token).decimals());
        (uint256 _mul, uint256 _div) = bond_strategy.discount(_token, _amount, lock_time);
        return _tokenPricePerBNB         // precision = 18
            *  _amount                   // precision = 36
            /  IERC20(_token).decimals() // precision = 18 again
            * _mul / _div;
    }


    /**
     * @notice returns the asset price per unit, expressed in BNB (precision = 18)
     */
    function assetPrice() private view returns (uint256) {
        return sybil.getBuyPrice(address(asset), asset.decimals());
    }


    /**
     * @notice returns how much _token should be required to purchase _amount of asset.
     */
    function quote(address _token, uint256 _amount) public view returns (uint256) {
        return asset.decimals()         // precision of our asset = 18
            * quoteBNB(_token, _amount) // expressed in BNB (precision = 18 so we're at 36 now)
            / assetPrice()              // also expressed in BNB (back to precision = 18)
        ;
    }

    /**
     * @notice executes a quote to buy _amount asset, depositing at most _max_price.
     * @param _token token to use for purchasing asset
     * @param _amount amount of asset tokens to be bought
     * @param _max_price maximum price to pay for the purchase
     * @return price_ the price paid for the purchase
     * @return maturity_ the maturity of the purchase, e.g. when it can be claimed
     */
    function deposit(address _token, uint256 _amount, uint256 _max_price) external notPaused notBlacklisted returns (uint256 price_, uint256 maturity_) {

        // this is the amount of _token we need (expressed as a fraction
        // with 10**18 precision) to purchase _amount asset tokens
        uint256 _quoted_amount = quote(_token, _amount);
        require(_quoted_amount <= _max_price, "Rocket: max price exceeded");

        // make sure we have enough & decrease balance asap
        require(allocationBalance(_token) >= _amount, "Rocket: insufficient asset allocation for order");
        require(IERC20(_token).allowance(_msgSender(), address(this)) >= _quoted_amount, "Rocket: insufficient allowance for order");

        // transfer their tokens to the treasury address
        // check if the sender is allowed to spend the tokens
        IERC20(_token).transferFrom(_msgSender(), address(treasury), _quoted_amount);
        allocations[_token] -= _amount;

        // lock the asset tokens for sale
        Locked memory _locked = locked_asset[_msgSender()];
        _locked.amount += _amount;
        _locked.timestamp = block.timestamp + lock_time;
        locked_asset[_msgSender()] = _locked;

        // return the price and maturity
        price_ = _quoted_amount;
        maturity_ = block.timestamp + lock_time;

        // emit an event to notify the user of the deposit
        // event Deposited(address indexed from, address indexed token, uint256 amount, uint256 max_price, uint256 price, uint256 maturity);
        emit Deposited(_msgSender(), _token, _amount, _max_price, price_, maturity_);
    }

    /**
     * @notice view function to see status of locked tokens.
     */
    function locked(address _wallet) external view returns (uint256 amount_, uint256 maturity_) {
        Locked memory _locked = locked_asset[_wallet];
        amount_ = _locked.amount;
        maturity_ = _locked.timestamp;
    }
    
    /**
     * @notice harvests locked tokens. Can only be done after the lock time has expired.
     */
    function harvest() external notPaused notBlacklisted {
        Locked memory _locked = locked_asset[_msgSender()];
        require(_locked.amount > 0, "Rocket: no order");
        require(_locked.timestamp <= block.timestamp, "Rocket: order not matured");
        locked_asset[_msgSender()] = Locked(0, 0);
        IERC20(asset).transfer(_msgSender(), _locked.amount);
        emit Harvested(_msgSender(), _locked.amount);
    }
}
