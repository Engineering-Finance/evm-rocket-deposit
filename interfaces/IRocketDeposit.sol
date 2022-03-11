// SPDX-License-Identifier: MIXED
pragma solidity >=0.8.10 <0.9.0;


/**
 * @title IRocketDeposit
 * @notice Defines a method for buying a certain quantity _asset tokens using _token tokens.
 * @notice The certains will be locked for a certain period of time and will be available for
 * @notice harvest after the period of time has passed.
 */
interface IRocketDeposit {

    event Deposited(address indexed from, address indexed token, uint256 amount, uint256 max_price, uint256 price, uint256 maturity);
    event Harvested(address indexed from, uint256 amount);

    /**
     * @notice returns how much it would cost to buy _amount of _asset tokens using _token tokens.
     * @param _token address of token we are purchasing with
     * @param _amount amount of _asset tokens to buy
     * @return price_ quoted amount of _token tokens that should be spent
     */
    function quote(address _token, uint256 _amount) external view returns (uint256 price_);
    
    /**
     * @notice executes a quote to buy _amount of _asset tokens using _token tokens.
     * @param _token address of token we are purchasing with
     * @param _amount amount of _asset tokens to buy
     * @param _max_price maximum price we are willing to pay
     * @return price_ actual price that we paid
     */
    function deposit(address _token, uint256 _amount, uint256 _max_price) external returns (uint256 price_, uint256 maturity_);

    /**
     * @notice view status of locked _asset tokens of a given _wallet.
     * @param _wallet address of wallet we are checking
     * @return amount_ amount of _asset tokens locked
     * @return maturity_ maturity timestamp of locked _asset tokens
     */
    function locked(address _wallet) external view returns (uint256 amount_, uint256 maturity_);

    /**
     * @notice harvests locked tokens. Can only be done after the lock time has expired.
     */
    function harvest() external;
}

