# Informal FAQ

> "How does this all work?"

Our main ingredient are *enclaves* aka *trusted execution environments* running [our open-source code](https://github.com/open-contracts/enclave-protocol), which can be hosted by anyone who has an account with a supported, reputable cloud provider. For now, only [AWS Nitro Enclaves](https://aws.amazon.com/ec2/nitro/nitro-enclaves/) are supported, but we'd like to support [Azure's SGX Enclaves](https://docs.microsoft.com/en-us/azure/confidential-computing/confidential-computing-enclaves) as well. Intuitively, you can think of such enclaves as a type of cloud instance where the cloud provider promises that nobody - neither the person who launched it nor the cloud provider itself - can manipulate the execution of a given computer environment once it started (or see any secrets generated inside of it), and where the provider signs a document stating that a certain environment returned a certain result. 

Our protocol consists of three pieces, one of which is [the code executed by the enclave](https://github.com/open-contracts/enclave-protocol), which runs a user-submitted python script with internet access, signs its results in a special way and returns them to the user. The [second piece](https://github.com/open-contracts/client-protocol) is executed by the user's browser. It makes sure they are talking to an enclave running our code, and it eventually receives and submits the enclave's results to piece no. 3: a [set of smart contracts](https://github.com/open-contracts/protocol/tree/main/solidity_contracts) which verify that the results come from the right python script, before forwarding it to the Open Contract the user wants to interact with.

<br/> 

> "But that's not decentralized!"


Yes, in a key way it's not, because we trust AWS's most secure instance type. But we're convinced that it is currently the right trade-off for most smart contracts who want to obtain proofs about internet data.

To make that case, let's imagine the best-case scenario that achieves what our protocol does: allow you to prove to a smart contract, for example that you made a certain online payment to another user of "FiatPay.com" (think Venmo, PayPal, Cash App, Zelle...). In the best case scenario, the smart contract could directly visit https://fiatpay.com on your browser, log in with your credentials (without making them public), look up the transaction, and if the right transaction happened: transfer tokens to you.
 
If you want this, you are willing to accept a couple points of centralization already:
  1. you trust FiatPay, especially that their servers aren't manipulated to falsely display a transaction that never happened - neither by a hacker nor by a rogue employee.
  2. you trust the centralized SSL certificate authorities (whose public keys are hardcoded in every browser) who gave FiatPay the certificate its server uses to "prove" its authenticity to your browser

Frankly, we believe 1. is already a stronger assumption than trusting AWS Nitro Enclaves. First of all, it is much, much easier for someone to manipulate FiatPay's server, than it is to hack into an AWS Nitro Enclave, for example. In the best case scenario, the FiatPay website would be running in such an enclave - but it's not. You're probably lucky if it's hosted a regular AWS instance, instead of FiatPay trying to set up their own security infrastructure. 

<br/> 

> "Do we really need enclaves?"

There currently most popular approach to decentralized oracles relies on a game-theoretic idea called *peer prediction*. A number of participants each put down a deposit into a contract, hold a majority vote about what some website showed, and the capital-weighted average report is taken as the truth. Whoever deviates from this average is penalized. This has a couple problems: 
 1. the contract needs to incentivize many oracle nodes, which is only viable for long-term, recurring requests such as high-frequency price-feeds
 2. if the data isn't public, you'd have to share your FiatPay login credentials
 3. easy to break: as soon as someone puts down large enough deposit, whatever they say becomes the 'truth' and everyone else is penalized. 

Instead, we would love something like a 'Zero Knowledge Proof' of the fact that you received a certain piece of data from some server. But the problem is how TLS works. It starts with a [cryptographic handshake](https://en.wikipedia.org/wiki/Transport_Layer_Security#Key_exchange_or_key_agreement), where you use FiatPay's SSL certificate to generate a secret known only by you and FiatPay's servers. All remaining https data - sent between you and the server over an untrusted connection - is encrypted with this secret. If you can decrypt a piece of data with this secret, you know it must have come from FiatPay's servers. But there's a problem when you want to prove this to a third party (e.g. a smart contract): you know the secret, so you could have decrypted the data, manipulated it, and encrypted it again before proving that it can be decrypted with a secret generated during a handshake with FiatPay. There has been a [proposal](https://github.com/tlsnotary/pagesigner/) to use a cryptographic tool called [Secure-Multi-Party-Computation (MPC)](https://en.wikipedia.org/wiki/Secure_multi-party_computation) to establish a TLS connection where the secret is split up between the user and a third party. If done correnctly, one could prove to this third party that some https data is authentic. But this crucially requires the third party doesn't make their part of the sercret public, and especially not share it with you. The best [proposal](https://research.chain.link/deco.pdf) for how to guarantee this in a blockchain context: put the third party into an enclave. So we're back to square one...

<br/> 

> "But could we think of a more decentralized enclave solution?"

Yes, because Intel SGX enclaves can be found in many consumer laptops. This approach is pursued by Chainlink and iExec. However, no enclave is perfect if you have full access to their hardware. That's how [researchers successfully compromised SGX](https://sgaxe.com/) in the past, fully exposing all the cryptographic secrets it relies on, to the point where they could make any data appear as if was produced by an SGX chip executing any logic. Counterintuitively, decentralization reduces security here - because it gives anyone hardware access to the enclaves trusted by the protocol. For this reason, we'd rather rely on enclaves hosted by known cloud providers, where we have additional layers of security: aside of direct legal risk, they could expect a major loss of clients if it turns out they voluntarily compromised their most secure instance type.

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

