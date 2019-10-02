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
import "./IERC20.sol";

/**
 * @title Acquisition Attempt
 * @author Benjamin Rickenbacher, benjamin@alethena.com
 * @author Luzius Meisser, luzius@meissereconomics.com
 *
 */

contract Acquisition {

    using SafeMath for uint256;

    uint256 public constant VOTING_PERIOD = 60 days;    // 2months/60days
    uint256 public constant VALIDITY_PERIOD = 90 days;  // 3months/90days

    uint256 public quorum;                              // Percentage of votes needed to start drag-along process

    address private parent;                             // the parent contract
    address payable public buyer;                       // the person who made the offer
    uint256 public price;                               // the price offered per share (in XCHF base units, so 10**18 is 1 XCHF)
    uint256 public timestamp;                           // the timestamp of the block in which the acquisition was created

    uint256 public noVotes;                             // number of tokens voting for no
    uint256 public yesVotes;                            // number of tokens voting for yes

    enum Vote { NONE, YES, NO }                         // Used internally, represents not voted yet or yes/no vote.
    mapping (address => Vote) private votes;            // Who votes what

    event VotesChanged(uint256 newYesVotes, uint256 newNoVotes);

    constructor (address payable buyer_, uint256 price_, uint256 quorum_) public {
        require(price_ > 0, "Price cannot be zero");
        parent = msg.sender;
        buyer = buyer_;
        price = price_;
        quorum = quorum_;
        timestamp = block.timestamp;
    }

    function isWellFunded(address currency_, uint256 sharesToAcquire) public view returns (bool) {
        IERC20 currency = IERC20(currency_);
        uint256 buyerXCHFBalance = currency.balanceOf(buyer);
        uint256 buyerXCHFAllowance = currency.allowance(buyer, parent);
        uint256 xchfNeeded = sharesToAcquire.mul(price);
        return xchfNeeded <= buyerXCHFBalance && xchfNeeded <= buyerXCHFAllowance;
    }

    function isQuorumReached() public view returns (bool) {
        if (isVotingOpen()) {
            // is it already clear that 75% will vote yes even though the vote is not over yet?
            return yesVotes.mul(10000).div(IERC20(parent).totalSupply()) >= quorum;
        } else {
            // did 75% of all cast votes say 'yes'?
            return yesVotes.mul(10000).div(yesVotes.add(noVotes)) >= quorum;
        }
    }

    function quorumHasFailed() public view returns (bool) {
        if (isVotingOpen()) {
            // is it already clear that 25% will vote no even though the vote is not over yet?
            return (IERC20(parent).totalSupply().sub(noVotes)).mul(10000).div(IERC20(parent).totalSupply()) < quorum;
        } else {
            // did 25% of all cast votes say 'no'?
            return yesVotes.mul(10000).div(yesVotes.add(noVotes)) < quorum;
        }
    }

    function adjustVotes(address from, address to, uint256 value) public parentOnly() {
        if (isVotingOpen()) {
            Vote fromVoting = votes[from];
            Vote toVoting = votes[to];
            update(fromVoting, toVoting, value);
        }
    }

    function update(Vote previousVote, Vote newVote, uint256 votes_) internal {
        if (previousVote != newVote) {
            if (previousVote == Vote.NO) {
                noVotes = noVotes.sub(votes_);
            } else if (previousVote == Vote.YES) {
                yesVotes = yesVotes.sub(votes_);
            }
            if (newVote == Vote.NO) {
                noVotes = noVotes.add(votes_);
            } else if (newVote == Vote.YES) {
                yesVotes = yesVotes.add(votes_);
            }
            emit VotesChanged(yesVotes, noVotes);
        }
    }

    function isVotingOpen() public view returns (bool) {
        uint256 age = block.timestamp.sub(timestamp);
        return age <= VOTING_PERIOD;
    }

    function hasExpired() public view returns (bool) {
        uint256 age = block.timestamp.sub(timestamp);
        return age > VALIDITY_PERIOD;
    }

    modifier votingOpen() {
        require(isVotingOpen(), "The vote has ended.");
        _;
    }

    function voteYes(address sender, uint256 votes_) public parentOnly() votingOpen() {
        vote(Vote.YES, votes_, sender);
    }

    function voteNo(address sender, uint256 votes_) public parentOnly() votingOpen() {
        vote(Vote.NO, votes_, sender);
    }

    function vote(Vote yesOrNo, uint256 votes_, address voter) internal {
        Vote previousVote = votes[voter];
        Vote newVote = yesOrNo;
        votes[voter] = newVote;
        update(previousVote, newVote, votes_);
    }

    function hasVotedYes(address voter) public view returns (bool) {
        return votes[voter] == Vote.YES;
    }

    function hasVotedNo(address voter) public view returns (bool) {
        return votes[voter] == Vote.NO;
    }

    function kill() public parentOnly() {
        // destroy the contract and send leftovers to the buyer.
        selfdestruct(buyer);
    }

    modifier parentOnly () {
        require(msg.sender == parent, "Can only be called by parent contract");
        _;
    }
}