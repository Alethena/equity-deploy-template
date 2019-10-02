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
import "./ERC20Claimable.sol";
import "./Pausable.sol";

/**
 * @title ServiceHunter AG Shares
 * @author Benjamin Rickenbacher, benjamin@alethena.com
 * @author Luzius Meisser, luzius@meissereconomics.com
 * @dev These tokens are based on the ERC20 standard and the open-zeppelin library.
 *
 * These tokens are uncertified shares (Wertrechte according to the Swiss code of obligations),
 * with this smart contract serving as onwership registry (Wertrechtebuch), but not as shareholder
 * registry, which is kept separate and run by the company. This is equivalent to the traditional system
 * of having physical share certificates kept at home by the shareholders and a shareholder registry run by
 * the company. Just like with physical certificates, the owners of the tokens are the owners of the shares.
 * However, in order to exercise their rights (for example receive a dividend), shareholders must register
 * with the company. For example, in case the company pays out a dividend to a previous shareholder because
 * the current shareholder did not register, the company cannot be held liable for paying the dividend to
 * the "wrong" shareholder. In relation to the company, only the registered shareholders count as such.
 * Registration requires setting up an account with ledgy.com providing your name and address and proving
 * ownership over your addresses.
 * @notice The main addition is a functionality that allows the user to claim that the key for a certain address is lost.
 * @notice In order to prevent malicious attempts, a collateral needs to be posted.
 * @notice The contract owner can delete claims in case of disputes.
 *
 * https://github.com/ethereum/EIPs/issues/20
 * Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */

contract ServiceHunterShares is ERC20Claimable, Pausable {

    using SafeMath for uint256;

    string public constant symbol = "SHS";
    string public constant name = "ServiceHunter AG Shares";
    string public constant terms = "quitt.ch/ir";

    uint8 public constant decimals = 0; // legally, shares are not divisible

    uint256 public totalShares = 17000; // total number of shares, maybe not all tokenized
    uint256 public invalidTokens = 0;

    address[] public subregisters;

    event Announcement(string message);
    event TokensDeclaredInvalid(address holder, uint256 amount, string message);
    event ShareNumberingEvent(address holder, uint256 firstInclusive, uint256 lastInclusive);
    event SubRegisterAdded(address contractAddress);
    event SubRegisterRemoved(address contractAddress);

    /**
     * Declares the number of total shares, including those that have not been tokenized and those
     * that are held by the company itself. This number can be substiantially higher than totalSupply()
     * in case not all shares have been tokenized. Also, it can be lower than totalSupply() in case some
     * tokens have become invalid.
     */
    function setTotalShares(uint256 _newTotalShares) public onlyOwner() {
        require(_newTotalShares >= totalValidSupply(), "There can't be fewer tokens than shares");
        totalShares = _newTotalShares;
    }

    /**
     * Under some use-cases, tokens are held by smart contracts that are ERC20 contracts themselves.
     * A popular example are Uniswap contracts that hold traded coins and that are owned by various
     * liquidity providers. For such cases, having a list of recognized such subregisters might
     * be helpful with the automated registration and tracking of shareholders.
     * We assume that the number of sub registers stays limited, such that they are safe to iterate.
     * Subregisters should always have the same number of decimals as the main register.
     * To add subregisters with a different number of decimals, adapter contracts are needed.
     */
    function recognizeSubRegister(address contractAddress) public onlyOwner () {
        subregisters.push(contractAddress);
        emit SubRegisterAdded(contractAddress);
    }

    function removeSubRegister(address contractAddress) public onlyOwner() {
        for (uint256 i = 0; i<subregisters.length; i++) {
            if (subregisters[i] == contractAddress) {
                subregisters[i] = subregisters[subregisters.length - 1];
                subregisters.pop();
                emit SubRegisterRemoved(contractAddress);
            }
        }
    }

    /**
     * A deep balanceOf operator that also considers indirectly held tokens in
     * recognized sub registers.
     */
    function balanceOfDeep(address holder) public view returns (uint256) {
        uint256 balance = balanceOf(holder);
        for (uint256 i = 0; i<subregisters.length; i++) {
            IERC20 subERC = IERC20(subregisters[i]);
            balance = balance.add(subERC.balanceOf(holder));
        }
        return balance;
    }

    /**
     * Allows the issuer to make public announcements that are visible on the blockchain.
     */
    function announcement(string calldata message) external onlyOwner() {
        emit Announcement(message);
    }

    function setClaimPeriod(uint256 claimPeriodInDays) public onlyOwner() {
        super._setClaimPeriod(claimPeriodInDays);
    }

    /**
     * See parent method for collateral requirements.
     */
    function setCustomClaimCollateral(address collateral, uint256 rate) public onlyOwner() {
        super._setCustomClaimCollateral(collateral, rate);
    }

    function getClaimDeleter() public returns (address) {
        return owner;
    }

    /**
     * Signals that the indicated tokens have been declared invalid (e.g. by a court ruling in accordance
     * with article 973g of the planned adjustments to the Swiss Code of Obligations) and got detached from
     * the underlying shares. Invalid tokens do not carry any shareholder rights any more.
     */
    function declareInvalid(address holder, uint256 amount, string calldata message) external onlyOwner() {
        uint256 holderBalance = balanceOf(holder);
        require(amount <= holderBalance, "Cannot invalidate more tokens than held by address");
        invalidTokens = invalidTokens.add(amount);
        emit TokensDeclaredInvalid(holder, amount, message);
    }

    /**
     * The total number of valid tokens in circulation. In case some tokens have been declared invalid, this
     * number might be lower than totalSupply(). Also, it will always be lower than or equal to totalShares().
     */
    function totalValidSupply() public view returns (uint256) {
        return totalSupply().sub(invalidTokens);
    }

    /**
     * Allows the company to tokenize shares. If these shares are newly created, setTotalShares must be
     * called first in order to adjust the total number of shares.
     */
    function mint(address shareholder, uint256 _amount) public onlyOwner() {
        require(totalValidSupply().add(_amount) <= totalShares, "There can't be fewer shares than valid tokens");
        _mint(shareholder, _amount);
    }

    /**
     * Some companies like to number their shares so they can refer to them more explicitely in legal contracts.
     * A minority of Swiss lawyers even believes that numbering shares is compulsory (which is not true).
     * Nonetheless, this function allows to signal the numbers of freshly tokenized shares.
     * In case the shares ever get de-tokenized again, this information might help in deducing their
     * numbers again - although there might be some room for interpretation of what went where.
     * By convention, transfers should be considered FIFO (first in, first out) and transactions in
     * recognized subregisters be taken into account.
     */
    function mintNumbered(address shareholder, uint256 firstShareNumber, uint256 lastShareNumber) public onlyOwner() {
        mint(shareholder, lastShareNumber.sub(firstShareNumber).add(1));
        emit ShareNumberingEvent(shareholder, firstShareNumber, lastShareNumber);
    }

    /**
     * Transfers _amount tokens to the company and burns them.
     * The meaning of this operation depends on the circumstances and the fate of the shares does
     * not necessarily follow the fate of the tokens. For example, the company itself might call
     * this function to implement a formal decision to destroy some of the outstanding shares.
     * Also, this function might be called by an owner to return the shares to the company and
     * get them back in another form under an according agreement (e.g. printed certificates or
     * tokens on a different blockchain). It is not recommended to call this function without
     * having agreed with the company on the further fate of the shares in question.
     */
    function burn(uint256 _amount) public {
        require(_amount <= balanceOf(msg.sender), "Not enough shares available");
        _transfer(msg.sender, address(this), _amount);
        _burn(address(this), _amount);
    }

    function _transfer(address from, address _to, uint256 _value) internal {
        require(!paused, "Contract is paused");
        super._transfer(from, _to, _value);
    }

}