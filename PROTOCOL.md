# Informal FAQ

> "How does this all work?"

Our main ingredient are *enclaves* aka *trusted execution environments* running [our open-source code](https://github.com/open-contracts/enclave-protocol), which can be hosted by anyone who has an account with a supported, reputable cloud provider. For now, only [AWS Nitro Enclaves](https://aws.amazon.com/ec2/nitro/nitro-enclaves/) are supported, but we'd like to support [Azure's SGX Enclaves](https://docs.microsoft.com/en-us/azure/confidential-computing/confidential-computing-enclaves) as well. Intuitively, you can think of such enclaves as a type of cloud instance where the cloud provider promises that nobody - neither the person who launched it nor the cloud provider itself - can manipulate the execution of a given computer environment once it started (or see any secrets generated inside of it), and where the provider signs a document stating that a certain environment returned a certain result. 

Our protocol consists of three pieces, one of which is [the code executed by the enclave](https://github.com/open-contracts/enclave-protocol), which runs a user-submitted python script with internet access, signs its results in a special way and returns them to the user. The [second piece](https://github.com/open-contracts/client-protocol) is executed by the user's browser. It makes sure they are talking to an enclave running our code, optionally allows them to control a browser running in the enclave, and it eventually receives and submits the enclave's results to the third piece of our protocol: a [set of smart contracts](https://github.com/open-contracts/protocol/tree/main/solidity_contracts) which verify that the results come from the right python script, before forwarding it to the Open Contract the user wants to interact with.

<br/> 

> "But that's not decentralized!"


Yes, in a key way it's not, because we choose to trust AWS's most secure instance type. But we're convinced that it is currently the right trade-off for most smart contracts who want to obtain proofs about internet data.

To make that case, let's imagine the best-case scenario: a protocol that allows you to prove to a smart contract, for example that you made a certain online payment to another user of "FiatPay.com" (think Venmo, PayPal, Cash App, Zelle...), but without additional trust assumptions. In the best case, the smart contract could directly visit https://fiatpay.com on your browser, log in with your credentials (without making them public), look up the transaction, and if the right transaction happened: transfer tokens to you.
 
If you want this, you are willing to accept a couple points of centralization already:
  1. You trust FiatPay, especially that their servers aren't manipulated to falsely display a transaction that never happened - neither by a hacker nor by a rogue employee.
  2. You trust the centralized SSL certificate authorities (whose public keys are hardcoded in every browser) who gave FiatPay the certificate its server uses to "prove" its authenticity to your browser.

Frankly, we believe 1. is already a stronger assumption than trusting AWS Nitro Enclaves. First of all, it is much, much easier for someone - hacker or employee - to manipulate FiatPay's server, than it is to hack into an AWS Nitro Enclave. In the best case scenario, the FiatPay website would be running in such an enclave - but it's not. You're probably lucky if it's hosted a regular AWS instance, instead of FiatPay trying to set up their own security infrastructure. There's also a significant difference in the downstream costs of such an attack for the respective companies: at no point did FiatPay commit to never errorneously displaying a false transaction for a few minutes. Nitro Enclaves however are the most secure instance type offered by AWS, sold with the explicit promise of providing certain security guaratees. The reputational and legal risk, and as a consequence the economic losses associated with even the appearance of breaking this promise, would dramatically exceed those of FiatPay.

<br/> 

> "Do we really need enclaves?"

There currently most popular approach to decentralized internet access for smart contracts relies on a game-theoretic idea called *peer prediction*. A number of participants each put down a deposit into a contract, hold a majority vote about what some website showed, and the capital-weighted average report is taken as the truth. Whoever deviates from this average is penalized. This has a couple of problems: 
 1. Easy to break, if its truly permissionless: as soon as someone puts down large enough deposit, whatever they say becomes the 'truth' and everyone else is penalized. Taking historic accuracy into account only delays this issue.
 2. The contract needs to incentivize many oracle nodes, which is only viable for long-term, recurring requests such as price-feeds. It doesn't work as well if you're buying a weather insurance which needs to reliably verify *once* whether it rained more than some amount over the course of next summer.
 3. If the data isn't public - like your FiatPay transaction - you'd have to share your FiatPay login credentials.

Instead, we would love something like a '[Zero Knowledge Proof](https://en.wikipedia.org/wiki/Zero-knowledge_proof)' (ZKP) of the fact that you received a certain piece of data from some server. But cryptographic zero-knowledge proofs can only verify computations, which is not enough, given how TLS works: It starts with a [cryptographic handshake](https://en.wikipedia.org/wiki/Transport_Layer_Security#Key_exchange_or_key_agreement), where you use FiatPay's SSL certificate to generate a secret known only by you and FiatPay's servers. All remaining https data - sent between you and the server over an untrusted connection - is encrypted with this secret. If you can decrypt a piece of data with this secret, you know it must have come from FiatPay's servers. But there's a problem when you want to prove this to a third party (e.g. a smart contract): you know the secret, so you could have decrypted the data, manipulated it, and encrypted it again before proving that it can be decrypted with a secret generated during a handshake with FiatPay. 

One [proposed solution](https://tlsnotary.org/) to this problem is to use a cryptographic tool called [Secure-Multi-Party-Computation (MPC)](https://en.wikipedia.org/wiki/Secure_multi-party_computation) to establish a TLS connection where the secret is split up between the user and a third party acting as "notary". If done correctly, one could prove to the notary that some https data is authentic. But this crucially requires the notary doesn't share their secret with the prover. Since a smart contract is public, it therefore can't be the notary itself. So the contract - and its users - would have to trust that a given notary did not collude with the prover. The most credible way to guarantee this in [smart contract applications](https://research.chain.link/deco.pdf): Put the notary into an enclave. And now we're back to square one...

<br/> 

> "But could we have a more decentralized enclave solution?"

Yes we could, because Intel SGX enclaves can be found in many consumer laptops. This approach is pursued by Chainlink and iExec. However, no enclave is perfect if you have full access to their hardware. That's how [researchers successfully compromised SGX](https://sgaxe.com/) in the past, fully exposing all the cryptographic secrets it relies on, to the point where they could make any data appear as if was produced by an SGX chip executing any logic. Counterintuitively, decentralization reduces security here - because it gives anyone hardware access to the enclaves trusted by the protocol. For this reason, we'd rather rely on enclaves hosted by known cloud providers, where we have additional layers of security: aside of direct legal risk, they could expect a major loss of clients if it turns out they voluntarily compromised their most secure instance type. We believe most contracts should rather bet that AWS or Azure can offer an enclave instance which can't be cracked by a rogue employee without being caught before succeeding, than bet that Intel can build a chip which can't be cracked by anyone.

In the meantime, we can focus on other aspects of decentralization: support other reputable cloud providers so that we don't depend on anyone in particular. Make sure that it is as easy as possible to start an enclave running our protocol, such that that there always is one available. Make sure the protocol is has no bugs in it, so that we can remove the current centralized training-wheels of our protocol. Everything is open source, and we're accepting pull requests!

<br/> 

> "That's a bit sad. Any hope for secure, trustless Open Contracts in the future?"

Yes! For example, if multi-party computation algorithms improve to the point that we can efficiently split the secret between the prover and, say, a permissionless group of 100 randomly selecret notaries, then it would be enough to trust that just one of them keeps their secret. At this point, almost trustless web access for smart contracts would be possible. But to enable a platform that is as general-purpose, privacy preserving and developer friendly as Open Contracts is today, we expect to need performant ZKPs for a whole Linux VM (Good News: we can already run [Linux on the EVM](https://github.com/cartesi/machine-solidity-step), and soon we'll get ZKPs for the EVM as well!).

To get there, a lot more research will be needed. We believe the best way to incentivize this research is to finally start creating contracts which take in more than just price feeds and provide real utility to people. And for that, we need a platform that makes creating them easy.

# The Protocol





The protocol can be summarized by the following flow chart:

```ascii
             TLS-over-TLS
             based on pubkey
             in attestation                      
             and SSL cert from                   TLS based on Mozilla's
             registry enclave                    Root CA store
┌─────────┐ ── ── ── ── ── ── ── ┌─────────────┐ ── ── ── ── ── ── ┌─────────────┐ 
│         │ Oracle.py,           │             │ user login creds  │             │
│         │ any dependencies,    │  Oracle     │ ────────────────► │ Some Website│
│ USER    │ e.g. login creds,    │  Enclave    │ ◄──────────────── │             │
│(browser)│ ───────────────────► │ ┌─────────┐ │ data for contract │             │
│         │                      │ │Oracle.py│ │ ── ── ── ── ── ── └─────────────┘
│         │ ◄─────────────────── │ └─────────┘ │ 
│         │ Calldata, Signatures │             │
└─────────┘ ── ── ── ── ── ── ── └─────────────┘ ◄──────────────────┐ If valid:
       │                                │                           │
       │                                │attestation                │ signature over 
       │ $OPN payment                   │CSR (=cert sign request)   │ {Oracle Enclave pubkey, Oracle Provider}
       │                                │                           │
       │ Oracle Enclave pubkey          ▼                           │  SSL cert
       │ Oracle Provider           ┌─────────┐                     ┌──────────┐
       │(Signed by registry)       │Oracle   │ ─────────────────►  │ Registry │
       │                           │Provider │ attestation, CSR    │ Enclave  │
       │ Calldata                  │(on EC2) │ + provider address  └──────────┘
       │ (Signed by Oracle)        └─────────┘
       │                                 ▲
       │                                 │
       │                                 │
       │                  $OPN payments  │                         ┌──────────────────┐
       │           ┌─────────────────────┴──────────────────────►  │ Registry Provider│
       ▼           │                                               └──────────────────┘
   ┌───────────────┴────┐  If valid:         ┌────────────┐
   │OpenContractsHub.sol│ ────────────────►  │Contract.sol│
   └────────────────────┘  submit call       └────────────┘
       │    
       │ $OPN payment   
       ▼ reducing supply   
   ┌─────────────────┐
   │ Burner Address  │
   └─────────────────┘
```

