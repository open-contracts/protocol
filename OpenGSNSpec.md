The [OpenGSN docs](https://docs.opengsn.org/contracts/#paying-for-your-user-s-meta-transaction) clarify that the main logic to implement is the Paymaster. To achieve a design that is as simple as possible, we will only attempt to allow gasless transactions via enclaves. 


# OpenContract

Inside an Open Contract (let's assume FiatSwap for now), the `OpenContract` parent class will expose a minimal API to deposit into the `OpenContractsPaymaster` and define the conditions under which the deposit can be used up. This will likely involve just a single function call.

E.g. inside the `offerTokens` function of FiatSwap, one could call
```
prepayGas(selector=this.buyTokens.selector, gasID=offerID, ...gasParams)
```
which:
 - calls `OpenContractsPaymaster.prepayGas{value: msg.value}(msg.sender, selector, gasID, ...gasParams)`, where `gasParams` are (which?) parameters OpenGSN requires us to set.
 - in doing so, transfers enough ETH to the paymaster to pay for gas, and enough OPN to pay the Hub.

FiatSwap would prepay for individual offers, hence set `gasID=offerID`.

Inside `oracle.py`, we add an optional `gasID` arg to the submit-function:

```
session.submit(..., function="buyTokens", gasID=offerID)
```

This will inform the frontend that the OpenGSN ethereum provider should be used. On-chain, the paymaster is supposed to ensure that this call will only be reimbursed if enough ETH and OPN were deposited for this specific gasID of this specific function from a user of this specific contract. 

Set default gasID to 0, and make sure it is included in `oracleSignature` alongside nonce.

# OpenContractsPaymaster

The Paymaster implements the actual prepayment check, via:

```
prepayGas(depositor, selector, gasID, ...gasParams)
```

which:
 - updates `ethBalance[msg.sender][selector][gasID] += msg.value`
 - grabs the OPN via `OPNToken.transfer(tx.origin, address(this), opnAmount)`, which requires that the frontend asked the depositor to approve their OPN for the paymaster *!!!! EDIT: ppl say tx.origin is insecure. understand more deeply. https://medium.com/coinmonks/solidity-tx-origin-attacks-58211ad95514 *
 - updates `opnBalance[msg.sender][selector][gasID] += opnAmount`


Later, OpenGSN will call

```
preRelayedCall(request, approvalData, maxGas, ...)
```

which needs to:
- check that enough OPN and ETH were deposited for a given gasID for the given contract function 
- return flag "rejectOnRecipientRevert"
- then forward the call to the verifier, in a way that tells it to revert if the gasID wasn't signed


# Updates to Verifier

Literaly just make `oracleMsgHash` depend on gasID
