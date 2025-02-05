# Informal Protocol FAQ

> "What does the protocol achieve?"

We're opening up smart contracts to _the whole internet_: for the first time, anyone can have a self-enforcing contract with anyone else, about any event observable on any https website. That is, we're solving the so-called _oracle problem_ of smart contracts, which would otherwise be blind to the outside world. In contrast to other oracle solutions, we empower contract _users_ to directly prove to a contract that some event happened on some https site they can visit - even non-API data behind login credentials, 2-factor authentication or CAPTCHAs, for example. We call a smart contract that is open to the internet an _Open Contract_. It is very easy to build, as it consists of just two pieces: the Ethereum contract logic written in Solidity, and the web logic written in Python. Our protocol takes care of the rest, making sure that a given Solidity function will only accept the results from its corresponding Python script. We even create a web3 interface ("dAapp") for your contract automatically, so you can focus on what matters most: understanding the real world problem, and the people whose cooperation you might kickstart with the right contract.  

<br/> 

> "How does this all work?"

Our main ingredient are *enclaves* aka *trusted execution environments* running [our open-source code](https://github.com/open-contracts/enclave-protocol), which can be hosted by anyone who has an account with a supported cloud provider. For now, only [AWS Nitro Enclaves](https://aws.amazon.com/ec2/nitro/nitro-enclaves/) are supported, but we'd like to support [Azure's SGX Enclaves](https://docs.microsoft.com/en-us/azure/confidential-computing/confidential-computing-enclaves) as well. Intuitively, you can think of such enclaves as a type of cloud instance where the cloud provider promises that nobody - neither the person who launched it nor the cloud provider itself - can manipulate the execution of a given computer environment once it started (or see any secrets generated inside of it), and where the provider signs an "attestation document", with which we can cryptographically verify that a certain computation returned a certain result.

Our protocol consists of three pieces. The first is [the code executed by the enclave](https://github.com/open-contracts/enclave-protocol) and connects to the [second piece](https://github.com/open-contracts/client-protocol) which is executed by the user's browser. The user submits the Python part of the Open Contract to the enclave, which executes it with internet access. The script can ask the user to submit credentials for API requests or even interactively control a chrome browser running in the enclave. It eventually computes some result from the web data, signs it in a special way and returns it to the user, who then submits it to the third piece of our protocol: a [set of smart contracts](https://github.com/open-contracts/ethereum-protocol) which verify the signatures guaranteeing that the results come from the right Python script, before forwarding it to the Open Contract the user wants to interact with, and ensure that users reimburse enclave providers using our [OPN](https://app.uniswap.org/#/swap?inputCurrency=eth&outputCurrency=0xa2d9519A8692De6E47fb9aFCECd67737c288737F&chain=mainnet&exactAmount=.1&exactField=output) token. A 20% surcharge is added and removed from supply, which deflates the currency to incentivize the token liquidity needed for enclave providers to cash out.

<br/> 

> "But that's not decentralized!"


Yes, in a key way it's not, because we choose to trust AWS's most secure instance type. But we're convinced that it is currently the right trade-off for most smart contracts who want to obtain proofs about internet data.

To make that case, let's imagine the best-case scenario: a protocol that allows you to prove to a smart contract  - without additional trust assumptions - for example that you made a certain online payment to another user of "FiatPayments.com" (think Venmo, PayPal, Cash App, Zelle...). In the best case, the smart contract would obtain the same proof that you get when you visit `https://fiatpayments.com` on your browser, log in with your credentials (without making them public) and look up if a transaction occurred.
 
If you agree this would be useful - e.g. for a trustless, peer-to-peer crypto on-/offramp - you are willing to let this contract trust a couple centralized entities already:
  1. It trusts FiatPayments.com, especially that their servers aren't manipulated to falsely display a transaction that never happened - neither by a hacker nor by a rogue employee.
  2. It trusts the centralized SSL certificate authorities (whose public keys are hardcoded in every browser) who gave FiatPayments the certificate its server uses to "prove" its authenticity to your browser.

Frankly, we believe 1. is already a stronger assumption than trusting AWS Nitro Enclaves. First of all, it is much, much easier for someone - hacker or employee - to manipulate FiatPayments's server, than it is to hack into an AWS Nitro Enclave. In the best case scenario, the FiatPayments website would be running in such an enclave - but it's not. You're probably lucky if it's hosted on a regular AWS instance, instead of FiatPayments trying to set up their own security infrastructure. There's also a significant difference in the downstream costs of such an attack for the respective companies: at no point did FiatPayments commit to never errorneously displaying a false transaction for a few minutes. Nitro Enclaves however are the most secure instance type offered by AWS, rented out with the explicit promise of providing certain security guaratees. The reputational and legal risk, and as a consequence the economic losses associated with even the appearance of breaking this promise, would dramatically exceed the costs of FiatPayments.com temporarily displaying incorrect web content. 

In short: AWS Nitro Enclaves require much less trust than most websites do to begin with - so avoiding them wouldn't make an Open Contract significantly more 'trustless'.

<br/> 

> "Do we really need enclaves?"

The currently most popular approach to decentralized internet access for smart contracts relies on a game-theoretic idea called *peer prediction*. A number of participants each put down a deposit into a contract, hold a majority vote about what some website showed, and the capital-weighted average report is taken as the truth. Whoever deviates from this average is penalized. This has a couple of problems: 
 1. Easy to break, if it's truly permissionless: as soon as someone puts down large enough deposit (a "51% attack"), whatever they say becomes the 'truth' and everyone else is penalized. Taking historic accuracy into account only delays this issue.
 2. Contracts need to incentivize a huge number of votes to make a 51% attack difficult, which is only affordable for long-term, recurring requests used by multiple contracts (e.g. price-feeds). It doesn't work as well if you're trying to sell a secure weather insurance which needs to reliably verify *once* whether it rained more than some amount over the course of next summer.
 3. If the data isn't public - like your FiatPayments transaction - you'd have to share your FiatPayments login credentials.

Instead, we would love something like a '[Zero Knowledge Proof](https://en.wikipedia.org/wiki/Zero-knowledge_proof)' (ZKP) of the fact that you received a certain piece of data from some server, empowering individual contract users to prove the authenticity of any web data they have access to. But cryptographic zero-knowledge proofs can only verify computations, which is not enough, given how https works: It starts with a [cryptographic handshake](https://en.wikipedia.org/wiki/Transport_Layer_Security#Key_exchange_or_key_agreement), where you use FiatPayments's SSL certificate to perform a computation that generates a secret known only by you and FiatPayments's servers, even over an untrusted connection. All remaining https data is encrypted with this secret. If you can decrypt a piece of data with this secret, you know it must have come from FiatPayments's servers. But there's a problem when you want to prove this to a third party (e.g. a smart contract): you know the secret, so you could have decrypted the data, manipulated it, and encrypted it again before proving that it can be decrypted with a secret generated during a handshake with FiatPayments. 

One [proposed solution](https://tlsnotary.org/) to this problem is to use a cryptographic tool called [Secure-Multi-Party-Computation (MPC)](https://en.wikipedia.org/wiki/Secure_multi-party_computation) to establish a TLS connection where the secret is "split up" between the user and a third party acting as "notary". If done correctly, one could prove to the notary that some https data is authentic. But this crucially requires the notary doesn't share their secret with the prover. Since a smart contract is public, it therefore can't be the notary itself. So the contract - and its users - would have to trust that the prover and their notary are different individuals who did not collude. Proposed [smart contract applications](https://research.chain.link/deco.pdf) often don't mention this problem, for which we only know one acceptable solution: put the notary into an enclave. And now we're back to square one...

<br/> 

> "But could we have a more decentralized enclave solution?"

Yes we could, because Intel SGX enclaves can be found in many consumer laptops. This approach is pursued by Chainlink and iExec. However, no enclave is perfect if you have full access to their hardware. That's how [researchers successfully compromised SGX](https://sgaxe.com/) in the past, fully exposing all the cryptographic secrets it relies on, to the point where they could make any data appear as if was produced by an SGX chip executing any logic. Counterintuitively, decentralization *reduces* security here - because it gives anyone hardware access to the enclaves trusted by the protocol. For this reason, we'd rather rely on enclaves hosted by known cloud providers, where we have additional layers of security: aside of direct legal risk, they could expect a major loss of clients if it turns out their most secure instance type wasn't secure. We believe most contracts should rather bet that AWS or Azure can offer an enclave instance which can't be cracked by a rogue employee without being caught before succeeding, than bet that Intel can build a chip which can't be cracked by anyone.

In the meantime, we can focus on other aspects of decentralization: make sure the protocol is has no bugs in it, so that we can remove the centralized backdoor that currently allows us to quickly fix bugs our protocol as they arise. Support other reputable cloud providers so that we don't depend on anyone in particular. Make sure that it is as easy as possible for anyone to start a cloud instance participating in the protocol. Anyone can join the open-source development efforts, and we are happy to accept pull requests! 

<br/> 

> "That's a bit sad. Any hope for an Open Contracts with a fully decentralized trust model in the future?"

Yes! For example, if multi-party computation algorithms improve to the point that we can efficiently split the TLS secret between, say, a permissionless group of 100 randomly selected notaries, then it would be enough to trust that just one of them keeps their secret. If they can jointly perform the TLS handshake quickly enough, almost trustless web access for smart contracts would be possible. But to enable a platform that is as general-purpose, privacy preserving and developer friendly as Open Contracts is today, we also expect to need performant ZKPs for a whole Linux VM (Good News: we can already run [Linux on the EVM](https://github.com/cartesi/machine-solidity-step), and soon we'll get [ZK](https://blog.polygon.technology/polygon-zk-days-recap-polygon-zero-reveal-and-panel-talk-with-vitalik/)[Ps](https://zksync.io/zkevm/) of the EVM as well!).

To get there, a lot more research will be needed. We believe the best way to incentivize this research is to finally start creating contracts which take in more than just price feeds and provide real utility to people. And for that, we need a platform that makes creating them easy. So let's dive into the details!

# The Protocol

We proceed to dive into the inner workings of the protocol for a more technical audience. The following figure provides an overview of the protocol, which will be explained by the remaining document in more detail. 

```ascii
             
                                   
             TLS based on pubkey                 TLS based on Linux's
             in attestation doc                  Root CA store
┌─────────┐ ── ── ── ── ── ── ── ┌─────────────┐ ── ── ── ── ── ── ┌─────────────┐ 
│         │ oracle.py,           │             │ user login creds  │             │
│         │ any dependencies,    │  Oracle     │─────────────────► │ Some Website│
│ USER    │ e.g. login creds,    │  enclave    │ ◄─────────────────│             │
│(browser)│────────────────────► │ ┌─────────┐ │ data for contract │             │
│         │                      │ │oracle.py│ │ ── ── ── ── ── ── └─────────────┘
│         │ ◄────────────────────│ └─────────┘ │ 
│         │ results, addrs, sigs |             │
└─────────┘ ── ── ── ── ── ── ── └─────────────┘ ◄──────────────────┐ If attestation valid:
       │                                │                           │
       │                                │attestation                │ registry signature of 
       │ $OPN payment                   │                           │ {oracle enclave pubkey, oracle provider}
       │                                │                           │
       │ oracle enclave pubkey          ▼                           │ 
       │ oracle provider address   ┌─────────┐                     ┌──────────┐
       │(signed by registry encl)  │Oracle   │──────────────────►  │ Registry │
       │                           │Provider │ attestation,        │ Enclave  │
       │ results, oracleHash       │(on EC2) │ + provider address  └──────────┘
       │ (signed by oracle encl)   └─────────┘                         ▲                             Off-Chain
   ┌───┴────────────────┐                ▲                             │                     ─────────────────
 ┌─│    Verifier.sol    │ ───────────────┴──────────────────────────┐  │ provider address             On-Chain
 │ └────────────────────┘         $OPN payment                      ▼  │        
 │  │ if sigs ok:       ▲                                          ┌───┴──────────────┐
 │  │ results           └──────────────────────────────────────────│ Registry Provider│
 │  ▼ oracleHash                                   registration tx └──────────────────┘ 
 │ ┌────────────────────┐ declare oracleHash ┌────────────┐                                
 │ │       Hub.sol      │ ◄──────────────────│Contract.sol│
 │ └────────────────────┘ ────────────────►  └────────────┘
 │                         if oracleHash ok: 
 │ $OPN payment            submit results
 │ reducing supply   
 │ ┌─────────────────┐
 └►│ Burner Address  │
   └─────────────────┘
```
#### High level explanation:
The Oracle and Registry providers are customers of the cloud provider (for now: AWS), who rent an enclave-capable cloud instance from them, install our open-source code and let it participate in the protocol. `Contract.sol` is the Solidty part of the Open Contract, executed on the Ethereum blockchain. `Oracle.py` is the python part (and its dependencies), which is executed by the Oracle enclave and describes the logic by which it requests data from some website, and computes the results. The results are initially submitted to the `Verifier.sol` which checks the validity of the signatures to convince itself that:
1. a known (=previously registered) registry enclave verified the attestation doc of a correctly setup oracle enclave
2. the results came from an `oracle.py` script with the right `oracleHash=hash(oracle.py, dependencies)`
3. The  user reimburses the enclave providers via the OPN token, while adding a 20% surcharge of [OPN](https://app.uniswap.org/#/swap?inputCurrency=eth&outputCurrency=0xa2d9519A8692De6E47fb9aFCECd67737c288737F&chain=mainnet&exactAmount=.1&exactField=output) that is removed from circulation.
It then forwards the results to the Hub, which forwards them to a specific open contract function if the `oracleHash` was whitelisted for this function. The Verifier and Hub are separate contracts, allowing us to replace the former with updated versions without resetting the `oracleHash` whitelists of existing contracts.

## 1. Cryptographic Attestation Mechanism

The attestation process lies at the heart of how smart contracts, users, or enclaves can computationally validate that a piece of data was produced by some enclave running a particular image. An enclave image is the full snapshot of the virtual machine which will be executed by an enclave. See Section 2 for more details about the particular image of the _Oracle_ enclave, the main enclave of our protocol. Central to the attestation process is the *attestation document* which can only be generated inside an enclave, and it contains three important pieces of information:

 1. The hash of the enclave image
 2. The public key computed from a private key that was generated by and remains secret inside of the enclave
 3. A signature of the above, by a public key with a certificate path to the cloud provider's (known) root certificate.

By verifying the validity of the signature and its certificate path relative to the enclave provider's root certificate, users/contracts/enclaves can convince themselves that a given public key was generated by a particular enclave image, as identified by its hash. Any data signed by this public key must therefore come from inside an enclave running a particular image.

Unfortunately, the format of the AWS Nitro attestation document is not particularly suited for direct verification by the EVM, requiring signature verification on elliptic curves other than Ethereum's Secp256k1 curve as well as deserialization and certificate parsing operations, which exceed the computational capabilities of the EVM. We therefore require a way for the Verifier contract to offload this computation away from the EVM.

Currently, the Verifier will do so by offloading this computation into a special _Registry_ enclave. This is a single enclave which is runs a special image different from that of the Oracle enclaves. It is not intended to be shut down, such that its public key always stays the same. Its main job is to verify the attestation documents of fresh Oracles, which connect to the Registry right at launch and submit their attestation document. The Registry verifies that the Oracle's attestation is valid and contains the right image hash, extracts its public key, signs it in an EVM-friendly way, and returns the signature to the fresh Oracle. The Oracle can now register its public key with the Hub, which can verify that it is signed with the (hardcoded) public key of the (first) Registry enclave. Before trusting the protocol, users can just check the Registry's public key once - off-chain - by verifying its attestation document. Anyone can launch an additional Registry enclave by obtaining a signature of its public key from an existing Registry (just like an Oracle would), and submitting its signed public key to the Hub.

This current design has the disadvantage that if all Registries went offline at the same time, the protocol could only recover if someone launched a new Hub and Verifier - which would not be accepted by previous Open Contracts who would effectively turn blind. The developers therefore currently maintain a centralized backdoor to the Hub, which allows them to manually register a new Registry in this event. The same backdoor is currently also used to deliver bugfixes as they arise, by changing the Onclave and Registry image hashes permitted by the protocol. Once the security of the images is established, this backdoor will be removed. By then, new Registry enclaves might be able to register with the Verifier directly, which could verify their attestation document by an general-purpose optimistic rollup such as [Descartes Rollup](https://github.com/open-contracts/cartesi-attestation-verification) or [Truebit](https://github.com/open-contracts/verify-nitro-attestation).



## 2. The Oracle Enclave <-> User interaction

When the user visits [our](https://github.com/open-contracts/open-contracts.github.io) (or any other) website conforming to our [client protocol](https://github.com/open-contracts/client-protocol), they connect to a registry that registered with the Verifier, and get forwarded by it to the cheapest available oracle enclave. Oracle and Registry providers can freely set their prices per submission. The oracle [enclave image](https://github.com/open-contracts/enclave-protocol/) always exectues the same steps after it is started:

 1. It connects to a registry enclave, goes through the attestation process and receives a signature of its public key from the registry and saves it for Step 8.
 2. It establishes a bi-directional WebSocket connection to a user (who was forwarded by the registry). All communication is encrypted via AES after an RSA key exchange based on the Oracle's public key inside the attestation document. The enclave exposes a set of remote-procedure calls (RPCs) to the user's fontend, and vice versa.
 3. It asks the user to authenticate by signing random bytes, and lets the user upload an `oracle.py` script along with optional dependencies.
 4. It computes the `oracleHash`, which is the hash of the user-submitted `oracle.py` and its dependencies, and saves for Step 8.
 5. It installs the dependencies and runs the (untrusted) `oracle.py` script in a Python Virtualenv inside a [Firejail Sandbox](https://firejail.wordpress.com/)
 6. Any error in the `oracle.py` execution is intercepted and forwarded to the user.
 7. Any valid `oracle.py` script imports the `opencontracts` package, which exposes functions allowing it to call the RPCs of the users frontend in order to:
    -  print messages to the user
    -  ask the user for an input, which gets returned as string
    -  display a waiting timer to the user, along with some reason (e.g. "downloading NASA data...")
    -  start an "interactive session", where the user controls (via a [html5 X11 client](https://github.com/open-contracts/client-protocol/tree/main/xpra)) a Chrome browser in Kiosk-mode running inside the enclave. The Chrome instance is controlled via [pyppeteer](https://github.com/open-contracts/enclave-protocol/blob/main/oracle_enclave/backend/xpra/chrome.py) which saves the current DOM of the browser at the push of [a button](https://github.com/open-contracts/enclave-protocol/blob/main/oracle_enclave/backend/xpra/chrome_wrapper.py) and returns it to the `oracle.py` script
    -  submit the final results
 8. Once the submission is triggered by the `oracle.py` script, the results are prepended with the `oracleHash` from Step 4., and signed with the public key of the Oracle enclave. They are forwarded to the user, together with the registry's signature of the Oracle enclave's public key from Step 1.

The user now has all they need to submit the results of the computation to the Hub.

## 3. Core Contracts: Hub, Verifier and Token

Every Open Contract declares (via a Solidity function modifier) which of its Solidity functions can only be called with the results of a particular oracle computation, defined by an `oracle.py` script and its dependencies. It does so by only allowing calls to such a function if they come from the Open Contracts Hub, and informing it to only forward results to an Open Contract function if they came from the right `oracleHash`. These declarations are simplified by inheriting from the `OpenContract` [parent class](https://github.com/open-contracts/ethereum-protocol/blob/main/solidity_contracts/OpenContractOptimism.sol) and calling its `setOracleHash` function, as described in more detail in the docs. 

The [Verifier and Hub contracts](https://github.com/open-contracts/ethereum-protocol) are at the heart of the protocol. They have the following roles:
 - the Verifier keeps track of the public keys of all known Registry enclaves, each validated by a previous registry. The attestation of the first registry can be verified off-chain before trusting the protocol.
 - it checks that the `oracleHash` and the results are signed by an Oracle enclave public key which was signed by a known Registry public key
 - it transfers $OPN from the user to the Oracle provider, the Registry provider, and to the [0xdead burner address](https://etherscan.io/address/0x000000000000000000000000000000000000dead)
 - if everything checks out, it forwards the `oracleHash` and the results to the Hub, which forwards it to the respective Open Contract function only if it whitelisted the specific `oracleHash` via the `setOracleHash` function.
 
The [OPN](https://app.uniswap.org/#/swap?inputCurrency=eth&outputCurrency=0xa2d9519A8692De6E47fb9aFCECd67737c288737F&chain=mainnet&exactAmount=.1&exactField=output) token conforms to the regular ERC20 and RC777 token standards. The enforced burning of OPN at every Hub transaction aims to create a deflationary pressure that increases with the overall protocol activity - incentivizing early OPN liquidity on the one hand that is necessary to for enclave providers to cash out on the other hand, who ultimately have to rent out the instances from AWS or Azure. 

## 4. Compatibility with modern web browsers' security policies

While the protocol effectively establishes a secure TLS connection based on the cloud provider's attestation root cerificate, the attestation document itself does not follow the x509 standard and thus we cannot use the HTTPS API of the user's browser. As a result, the user's WebSocket connection to the enclave is flagged as an insecure connection, and automatically blocked if executed on a HTTPS website. As a workaround, we require registry providers to purchase some domain and point it to their registry. Our registry [code](https://github.com/open-contracts/enclave-protocol/tree/main/ec2_instance/reverse_proxy) automatically obtains a LetsEncrypt TLS certificate, and runs a reverse proxy server through which users connect to the registry and oracles.
