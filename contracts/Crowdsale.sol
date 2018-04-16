pragma solidity ^0.4.18;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for crowdsales. They are *not* intended to be modified / overriden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override 
 * the methods to add functionality. Consider using 'super' where appropiate to concatenate
 * behavior.
 */

contract Crowdsale is Ownable {
    using SafeMath for uint256;

    // The token being sold
    ERC20 public token;

    // Address where funds are collected
    address public wallet;

    // How many token units a buyer gets per wei
    uint256 public rate = 600;

    // Amount of wei raised
    uint256 public weiRaised;

    // Amount of token sold
    uint256 public tokenSold;

    // Stage information
    uint public constant STAGE1_START_DATE = 1524182400;
    uint public constant STAGE1_END_DATE = 1529193600;
    uint public constant STAGE2_START_DATE = 1529625600;
    uint public constant STAGE2_END_DATE = 1534291200;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    /**
     * Event for token allocate logging
     * @param beneficiary who got the tokens
     * @param amount amount of tokens allocated
     */
    event TokenAllocate(address indexed beneficiary, uint256 amount);

    /**
     * @param _wallet Address where collected funds will be forwarded to
     * @param _token Address of BITTOToken contract
     */
    function Crowdsale(address _wallet, ERC20 _token) public {
        require(_wallet != address(0) && _token != address(0));
        token = _token;
        wallet = _wallet;
    }

    // -----------------------------------------
    // Crowdsale external interface
    // -----------------------------------------

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     */
    function () external payable {
        buyTokens(msg.sender);
    }

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * @param _beneficiary Address performing the token purchase
     */
    function buyTokens(address _beneficiary) public payable {

        uint256 weiAmount = msg.value;
        _preValidatePurchase(_beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        tokens += _getBonusAmount(_beneficiary, weiAmount, tokens);

        _processPurchase(_beneficiary, tokens);

        // update state
        weiRaised = weiRaised.add(weiAmount);

        TokenPurchase(msg.sender, _beneficiary, weiAmount, tokens);

        _forwardFunds();
    }

    function allocate(address _to, uint _amount) onlyOwner public {
        _processPurchase(_to, _amount);
        TokenAllocate(_to, _amount);
    }

    /// @notice Allow users to buy tokens for `_rate` eth
    /// @param _rate rate the users can sell to the contract
    function setRate(uint256 _rate) onlyOwner public {
        require(_rate > 0);
        rate = _rate;
    }

    /// @notice withdraw unsold tokens to team fund address, transfer ownership to the sender
    function withdraw(address _beneficiary) onlyOwner public {
        require(now > STAGE2_END_DATE);
        _deliverTokens(_beneficiary, token.balanceOf(this));
    }

    // -----------------------------------------
    // Internal interface (extensible)
    // -----------------------------------------

    /**
     * @dev Validation of an incoming purchase. Use require statemens to revert state when conditions are not met. Use super to concatenate validations.
     * @param _beneficiary Address performing the token purchase
     * @param _weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) view internal {
        require(_beneficiary != address(0));
        require(_weiAmount != 0);
        require((now >= STAGE1_START_DATE && now < STAGE1_END_DATE) || (now >= STAGE2_START_DATE && now < STAGE2_END_DATE));
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
     * @param _beneficiary Address performing the token purchase
     * @param _tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
        token.transfer(_beneficiary, _tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
     * @param _beneficiary Address receiving the tokens
     * @param _tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
        tokenSold = tokenSold.add(_tokenAmount);
        _deliverTokens(_beneficiary, _tokenAmount);
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param _weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
        return _weiAmount.mul(rate);
    }

    function _getBonusAmount(address _beneficiary, uint256 _weiAmount, uint256 _tokenAmount) internal view returns(uint256) {
        // send bonus for each ICO Stage
        uint256 bonus;

        if (now >= STAGE1_START_DATE && now < STAGE1_END_DATE) {
            if (_weiAmount >= 20 ether) {
                bonus = _tokenAmount.mul(60).div(100);
            } else if (_weiAmount >= 10 ether) {
                bonus = _tokenAmount.mul(48).div(100);
            } else if (_weiAmount >= 5 ether) {
                bonus = _tokenAmount.mul(20).div(100);
            } else if (_weiAmount >= 1 ether) {
                bonus = _tokenAmount.mul(12).div(100);
            }
        } else if (now >= STAGE2_START_DATE && now < STAGE2_END_DATE) {
            if (_weiAmount >= 20 ether) {
                bonus = _tokenAmount.mul(30).div(100);
            } else if (_weiAmount >= 10 ether) {
                bonus = _tokenAmount.mul(24).div(100);
            } else if (_weiAmount >= 5 ether) {
                bonus = _tokenAmount.div(10);
            } else if (_weiAmount >= 1 ether) {
                bonus = _tokenAmount.mul(6).div(100);
            }
        }

        return bonus;
    }

    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds() internal {
        wallet.transfer(msg.value);
    }
}