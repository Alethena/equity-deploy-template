/**
* MIT License with Automated License Fee Payments
*
* Copyright (c) 2019 Equility AG (alethena.com)
*
* Permission is hereby granted to any person obtaining a copy of this software
* and associated documentation files (the "Software"), to deal in the Software
* without restriction, including without limitation the rights to use, copy,
* modify, merge, publish, distribute, sublicense, and/or sell copies of the
* Software, and to permit persons to whom the Software is furnished to do so,
* subject to the following conditions:
*
* - The above copyright notice and this permission notice shall be included in
*   all copies or substantial portions of the Software.
* - All automated license fee payments integrated into this and related Software
*   are preserved.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/
pragma solidity 0.5.10;

import "./SafeMath.sol";
import "./ERC20.sol";
import "./IERC20.sol";

/**
 * @title Claimable
 * In case of tokens that represent real-world assets such as shares of a company, one needs a way
 * to handle lost private keys. With physical certificates, courts can declare share certificates as
 * invalid so the company can issue replacements. Here, we want a solution that does not depend on
 * third parties to resolve such cases. Instead, when someone has lost a private key, he can use the
 * declareLost function to post a deposit and claim that the shares assigned to a specific address are
 * lost. To prevent front running, a commit reveal scheme is used. If he actually is the owner of the shares,
 * he needs to wait for a certain period and can then reclaim the lost shares as well as the deposit.
 * If he is an attacker trying to claim shares belonging to someone else, he risks losing the deposit
 * as it can be claimed at anytime by the rightful owner.
 * Furthermore, if "getClaimDeleter" is defined in the subclass, the returned address is allowed to
 * delete claims, returning the collateral. This can help to prevent obvious cases of abuse of the claim
 * function.
 */

contract ERC20Claimable is ERC20 {

    using SafeMath for uint256;
    using SafeMath for uint32;

    // A struct that represents a claim made
    struct Claim {
        address claimant; // the person who created the claim
        uint256 collateral; // the amount of collateral deposited
        uint32 timestamp;  // the timestamp of the block in which the claim was made
        address currencyUsed; // The currency (XCHF) can be updated, we record the currency used for every request
    }

    // Every claim must be preceded by an obscured preclaim in order to prevent front-running
    struct PreClaim {
        bytes32 msghash; // the hash of nonce + address to be claimed
        uint256 timestamp;  // the timestamp of the block in which the preclaim was made
    }

    uint256 public claimPeriod = XXX days; // Default of 180 days;
    uint256 public preClaimPeriod = 1 days; // One day. Minimum waiting period between preClaim and Claim;
    uint256 public preClaimPeriodEnd = 2 days; // Two days. Maximum waiting period between preClaim and Claim;

    mapping(address => Claim) public claims; // there can be at most one claim per address, here address is claimed address
    mapping(address => PreClaim) public preClaims; // there can be at most one preclaim per address, here address is claimer
    mapping(address => bool) public claimingDisabled; // disable claimability (e.g. for long term storage)

    // ERC-20 token that can be used as collateral or 0x0 if disabled
    address public customCollateralAddress;
    uint256 public customCollateralRate;

    /**
     * Returns the collateral rate for the given collateral type and 0 if that type
     * of collateral is not accepted. By default, only the token itself is accepted at
     * a rate of 1:1.
     *
     * Subclasses should override this method if they want to add additional types of
     * collateral.
     */
    function getCollateralRate(address collateralType) public view returns (uint256) {
        if (collateralType == address(this)) {
            return 1;
        } else if (collateralType == customCollateralAddress) {
            return customCollateralRate;
        } else {
            return 0;
        }
    }

    /**
     * Allows subclasses to set a custom collateral besides the token itself.
     * The collateral must be an ERC-20 token that returns true on successful transfers and
     * throws an exception or returns false on failure.
     * Also, do not forget to multiply the rate in accordance with the number of decimals of the collateral.
     * For example, rate should be 7*10**18 for 7 units of a collateral with 18 decimals.
     */
    function _setCustomClaimCollateral(address collateral, uint256 rate) internal {
        customCollateralAddress = collateral;
        if (customCollateralAddress == address(0)) {
            customCollateralRate = 0; // disabled
        } else {
            require(rate > 0, "Collateral rate can't be zero");
            customCollateralRate = rate;
        }
        emit CustomClaimCollateralChanged(collateral, rate);
    }

    function getClaimDeleter() public returns (address);

    /**
     * Allows subclasses to change the claim period, but not to fewer than 90 days.
     */
    function _setClaimPeriod(uint256 claimPeriodInDays) internal {
        require(claimPeriodInDays > 90, "Claim period must be at least 90 days"); // must be at least 90 days
        uint256 claimPeriodInSeconds = claimPeriodInDays.mul(1 days);
        claimPeriod = claimPeriodInSeconds;
        emit ClaimPeriodChanged(claimPeriod);
    }

    function setClaimable(bool enabled) public {
        claimingDisabled[msg.sender] = !enabled;
    }

    /**
     * Some users might want to disable claims for their address completely.
     * For example if they use a deep cold storage solution or paper wallet.
     */
    function isClaimsEnabled(address target) public view returns (bool) {
        return !claimingDisabled[target];
    }

    event ClaimMade(address indexed lostAddress, address indexed claimant, uint256 balance);
    event ClaimPrepared(address indexed claimer);
    event ClaimCleared(address indexed lostAddress, uint256 collateral);
    event ClaimDeleted(address indexed lostAddress, address indexed claimant, uint256 collateral);
    event ClaimResolved(address indexed lostAddress, address indexed claimant, uint256 collateral);
    event ClaimPeriodChanged(uint256 newClaimPeriodInDays);
    event CustomClaimCollateralChanged(address newCustomCollateralAddress, uint256 newCustomCollareralRate);

  /** Anyone can declare that the private key to a certain address was lost by calling declareLost
    * providing a deposit/collateral. There are three possibilities of what can happen with the claim:
    * 1) The claim period expires and the claimant can get the deposit and the shares back by calling resolveClaim
    * 2) The "lost" private key is used at any time to call clearClaim. In that case, the claim is deleted and
    *    the deposit sent to the shareholder (the owner of the private key). It is recommended to call resolveClaim
    *    whenever someone transfers funds to let claims be resolved automatically when the "lost" private key is
    *    used again.
    * 3) The owner deletes the claim and assigns the deposit to the claimant. This is intended to be used to resolve
    *    disputes. Generally, using this function implies that you have to trust the issuer of the tokens to handle
    *    the situation well. As a rule of thumb, the contract owner should assume the owner of the lost address to be the
    *    rightful owner of the deposit.
    * It is highly recommended that the owner observes the claims made and informs the owners of the claimed addresses
    * whenever a claim is made for their address (this of course is only possible if they are known to the owner, e.g.
    * through a shareholder register).
    * To prevent frontrunning attacks, a claim can only be made if the information revealed when calling "declareLost"
    * was previously commited using the "prepareClaim" function.
    */
    function prepareClaim(bytes32 hashedpackage) public {
        preClaims[msg.sender] = PreClaim({
            msghash: hashedpackage,
            timestamp: block.timestamp
        });
        emit ClaimPrepared(msg.sender);
    }

    function validateClaim(address lostAddress, bytes32 nonce) private view {
        PreClaim memory preClaim = preClaims[msg.sender];
        require(preClaim.msghash != 0, "Message hash can't be zero");
        require(preClaim.timestamp.add(preClaimPeriod) <= block.timestamp, "Preclaim period violated. Claimed too early");
        require(preClaim.timestamp.add(preClaimPeriodEnd) >= block.timestamp, "Preclaim period end. Claimed too late");
        require(preClaim.msghash == keccak256(abi.encodePacked(nonce, msg.sender, lostAddress)),"Package could not be validated");
    }

    function declareLost(address collateralType, address lostAddress, bytes32 nonce) public {
        require(lostAddress != address(0), "Can't claim zero address");
        require(isClaimsEnabled(lostAddress), "Claims disabled for this address");
        uint256 collateralRate = getCollateralRate(collateralType);
        require(collateralRate > 0, "Unsupported collateral type");
        address claimant = msg.sender;
        uint256 balance = balanceOf(lostAddress);
        uint256 collateral = balance.mul(collateralRate);
        IERC20 currency = IERC20(collateralType);
        require(balance > 0, "Claimed address holds no shares");
        require(currency.allowance(claimant, address(this)) >= collateral, "Currency allowance insufficient");
        require(currency.balanceOf(claimant) >= collateral, "Currency balance insufficient");
        require(claims[lostAddress].collateral == 0, "Address already claimed");
        validateClaim(lostAddress, nonce);
        require(currency.transferFrom(claimant, address(this), collateral), "Collateral transfer failed");

        claims[lostAddress] = Claim({
            claimant: claimant,
            collateral: collateral,
            timestamp: uint32(block.timestamp), // block timestamp is in seconds --> Should not overflow
            currencyUsed: collateralType
        });

        delete preClaims[claimant];
        emit ClaimMade(lostAddress, claimant, balance);
    }

    function getClaimant(address lostAddress) public view returns (address) {
        return claims[lostAddress].claimant;
    }

    function getCollateral(address lostAddress) public view returns (uint256) {
        return claims[lostAddress].collateral;
    }

    function getCollateralType(address lostAddress) public view returns (address) {
        return claims[lostAddress].currencyUsed;
    }

    function getTimeStamp(address lostAddress) public view returns (uint256) {
        return claims[lostAddress].timestamp;
    }

    function getPreClaimTimeStamp(address claimerAddress) public view returns (uint256) {
        return preClaims[claimerAddress].timestamp;
    }

    function getMsgHash(address claimerAddress) public view returns (bytes32) {
        return preClaims[claimerAddress].msghash;
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(super.transfer(recipient, amount), "Transfer failed");
        clearClaim();
        return true;
    }

    /**
     * Clears a claim after the key has been found again and assigns the collateral to the "lost" address.
     * This is the price an adverse claimer pays for filing a false claim and makes it risky to do so.
     */
    function clearClaim() public {
        if (claims[msg.sender].collateral != 0) {
            uint256 collateral = claims[msg.sender].collateral;
            IERC20 currency = IERC20(claims[msg.sender].currencyUsed);
            delete claims[msg.sender];
            require(currency.transfer(msg.sender, collateral), "Collateral transfer failed");
            emit ClaimCleared(msg.sender, collateral);
        }
    }

   /**
    * After the claim period has passed, the claimant can call this function to send the
    * tokens on the lost address as well as the collateral to himself.
    */
    function resolveClaim(address lostAddress) public {
        Claim memory claim = claims[lostAddress];
        uint256 collateral = claim.collateral;
        IERC20 currency = IERC20(claim.currencyUsed);
        require(collateral != 0, "No claim found");
        require(claim.claimant == msg.sender, "Only claimant can resolve claim");
        require(claim.timestamp.add(uint32(claimPeriod)) <= block.timestamp, "Claim period not over yet");
        address claimant = claim.claimant;
        delete claims[lostAddress];
        require(currency.transfer(claimant, collateral), "Collateral transfer failed");
        _transfer(lostAddress, claimant, balanceOf(lostAddress));
        emit ClaimResolved(lostAddress, claimant, collateral);
    }

    /**
     * This function is to be executed by the owner only in case a dispute needs to be resolved manually.
     */
    function deleteClaim(address lostAddress) public {
        require(msg.sender == getClaimDeleter(), "You cannot delete claims");
        Claim memory claim = claims[lostAddress];
        IERC20 currency = IERC20(claim.currencyUsed);
        require(claim.collateral != 0, "No claim found");
        delete claims[lostAddress];
        require(currency.transfer(claim.claimant, claim.collateral), "Collateral transfer failed");
        emit ClaimDeleted(lostAddress, claim.claimant, claim.collateral);
    }

}