<h1>Drag-Along Tests</h1>

<h2>1. Basic</h2>

<h4>Announcement</h4>

* Owner can make announcement <b>OK</b>
* NEG - Only owner can make announcement <b>OK</b>

<h4>Set Claim Parameters</h4>

* Custom claim collateral set correctly <b>OK</b>
* Claim period set correctly <b>OK</b>
* NEG - Collateral rate cannot be negative <b>OK</b>
* NEG - Only owner can set custom collateral <b>OK</b>
* NEG - Only owner can set claim period <b>OK</b>
* NEG - Can't break lower limit on claim period <b>OK</b>
 
<h2>2. Claimable</h2>
<h4>Claim After Acquisition</h4>

* Equity Claim process with XCHF still works <b>OK</b>
* Token Claim process with XCHF still works <b>OK</b>

<h4>Clearing Claim</h4>

- Clearing claims works <b>OK</b>
- NEG - Nothing happens when calling clear claim without an active claim <b>OK</b>

<h4>Claim Equity with XCHF</h4>

- Standard Claim Process with XCHF - Claim Equity with XCHF <b>OK</b>

<h4>Claim Tokens with XCHF</h4>

- Standard Claim Process with XCHF - Claim Tokens with XCHF <b>OK</b>

<h4>Delete Claims</h4>

- Deleting claims works <b>OK</b>
- NEG - Only deleter can delete claims <b>OK</b>
- NEG - Can't delete if there is no claim <b>OK</b>

<h4> Claim Lost - Equity</h4>

- NEG - Can't claim address if claiming is disabled <b>OK</b>
- NEG - Can't claim using unsupported collateral type <b>OK</b>
- NEG - Can't claim address with empty holdings <b>OK</b>
- NEG - Can't claim if currency allowance is insufficient <b>OK</b>
- NEG - Can't claim if currency balance is insufficient <b>OK</b>
- NEG - Can't claim address if there is an existing claim <b>OK</b>
- NEG - Preclaim period violated (too early) <b>OK</b>
- NEG - Preclaim period violated (too late) <b>OK</b>
- NEG - Can't claim with incorrect nonce <b>OK</b>

<h4>Resolve Claim</h4>

* Resolving claim works <b>OK</b>
* NEG - Can't resolve claim before claim period has ended <b>OK</b>
* NEG - Only claimant can resolve claim <b>OK</b>
* NEG - Can't resolve if there is no claim <b>OK</b>

<h2>3. Draggable</h2>

<h4>Burn</h4>

- Burn works <b>OK</b>
- NEG - Can't burn more than you have <b>OK</b>

<h4>Cancel Acquisition</h4>

- CancelAcquisition before voting <b>OK</b>
- CancelAcquisition after positive voting <b>OK</b>
- NEG - Only buyer can cancel acquisition <b>OK</b>
- NEG - Can't cancel if there is no offer <b>OK</b>

<h4>Complete Acquisition</h4>

- NEG - Only buyer can complete offer <b>OK</b>
- NEG - Can't complete if there is no offer <b>OK</b>
- NEG - Can't complete offer early <b>OK</b>
- NEG - Can't complete if money is missing (balance) <b>OK</b>
- NEG - Can't complete if money is missing (allowance) <b>OK</b>
- NEG - Can't complete if relative quorum is not reached <b>OK</b>

<h4>Contest Acquisition</h4>

- Contest works if offer is expired <b>OK</b>
- Contest works if absolute quorum has failed <b>OK</b>
- Contest works if relative quorum has failed <b>OK</b>
- Contest works if funding insufficient (balance) <b>OK</b>
- Contest works if funding insufficient (allowance) <b>OK</b>
- NEG - Can't contest a good offer <b>OK</b>
- NEG - Can't contest if there is no offer <b>OK</b>

<h4>Initiate Acquisition</h4>

- NEG - Can't initiate if accepted offer exists <b>OK</b>
- NEG - Can't initiate if contract does not represent enough equity <b>OK</b>
- NEG - Can't initiate if you don't have >= 5% of tokens <b>OK</b>
- NEG - Can't initiate if insufficiently funded <b>OK</b>
- NEG - Can't replace an offer if it is not at least 5% better <b>OK</b>

<h4>Migrate</h4>

- Standard migration scenario <b>OK</b>
- NEG - Can't migrate if contract is inactive <b>OK</b>
- NEG - Can't migrate if quorum not reached <b>OK</b>

<h4>Standard Process</h4>

- Early completion with absolute quorum <b>OK</b>
  - Offer is made
  - Users vote with absolute yes quorum
  - Offer completed
  - Users retrieve XCHF
- Standard offer process with relative quorum <b>OK</b>
  - Offer is made
  - Users vote with relative yes quorum
  - Offer completed
  - Users retrieve XCHF
- Standard offer process with counteroffer <b>OK</b>
  - Offer is made
  - Users vote with relative yes quorum
  - Better Offer made
  - Users vote with relative yes quorum
  - Offer completed
  - Users retrieve XCHF

<h4>Unwrap</h4>

- NEG - Can't unwrap if contract is active <b>OK</b>

<h4>Voting</h4>

* Vote Yes <b>OK</b>
* Vote No <b>OK</b>
* Changing vote from yes to no <b>OK</b>
* Changing vote from no to yes <b>OK</b>
* Votes change when shares are transferred <b>OK</b>

<h4>Wrap Negative Tests</h4>

- NEG - Can't wrap if contract is inactive <b>OK</b>
- NEG - Can't wrap if share balance insufficient <b>OK</b>
- NEG - Can't wrap if share allowance insufficient <b>OK</b>
- NEG - Can't wrap if there is a pending offer <b>OK</b>