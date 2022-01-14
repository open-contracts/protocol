# Informal Summary
Our main ingredient are *enclaves* aka *trusted execution environments* running [our open-source code](https://github.com/open-contracts/enclave-protocol), which can be hosted by anyone who has an account with a supported, reputable cloud provider. For now, only [AWS Nitro Enclaves](https://aws.amazon.com/ec2/nitro/nitro-enclaves/) are supported, but we'd like to support [Azure's SGX Enclaves](https://docs.microsoft.com/en-us/azure/confidential-computing/confidential-computing-enclaves) as well. Intuitively, you can think of such enclaves as a type of cloud instance where the cloud provider promises that nobody - neither the person who launched it nor the cloud provider itself - can manipulate the execution of a given computer environment once it started (or see any secrets generated inside of it), and where the provider signs a document stating that a certain environment returned a certain result. 

Our protocol consists of three pieces, one of which is [such an environment](https://github.com/open-contracts/enclave-protocol), which runs a user-submitted python script and signs its results in a special way. The [second piece](https://github.com/open-contracts/client-protocol) is executed by the user's browser and makes sure they are only talking such an enclave running our environment, and the last one is a [set of smart contracts](https://github.com/open-contracts/protocol/tree/main/solidity_contracts) which make sure that an Open Contract will only receive results computed in this way.

<br/> 

> "But that's not decentralized!"


Yes, in a key way it's not. But we're convinced that it is currently the right trade-off for most smart contracts who want to obtain proofs about internet data, so we need to make it accessible to everyone. 

To make that case, let's imagine the best-case scenario that achieves what our protocol does: allow you to convince any smart contract e.g. that you made a certain online payment to another user of "FiatPay.com" (think Venmo, PayPal, Cash App or Zelle, for example). In the best case scenario, the smart contract could directly visit https://fiatpay.com on your browser, log in with your credentials (without making them public), look up the transaction, and if the right transaction happened: transfer tokens to you.
 
If you want this, you are willing to accept a couple points of centralization already:
  1. you trusting FiatPay, especially that their servers aren't manipulated to falsely display a transaction that never happened - neither by a hacker nor by a rouge employee.
  2. you trust the centralized SSL certificate authorities (whose public keys are hardcoded in every browser) who gave FiatPay the certificate it uses to "prove" their authenticity to your browser

Frankly, we believe 1. is already a stronger assumption than trusting AWS Nitro Enclaves. First of all, it is much, much easier for someone to manipulate FiatPay's server, than it is to hack into an AWS Nitro Enclave, for example. In the best case scenario, the FiatPay website would be running in such an enclave - but it's not. You can probably be lucky if it's hosted a regular AWS instance, instead of FiatPay trying to set up their own security infrastructure. 

<br/> 

> "Do we really need enclaves?"

For public web data which can be accesses without credentials, there is an alternative approach which relies only on a game-theoretic idea called *peer prediction*. (...)

For data behing credentials, we can't just do a 'Zero Knowledge Proof' of the fact that you received a certain piece of data from some server, because of how TLS works. It starts with a [cryptographic handshake](https://en.wikipedia.org/wiki/Transport_Layer_Security#Key_exchange_or_key_agreement), where you use FiatPay's SSL certificate to generate a secret known only by you and FiatPay's servers. In simplified terms, the remaining data - sent between you and the server over an untrusted connection - is encrypted with this secret. If you can decrypt a piece of data with this secret, you know it must have come from FiatPay's servers. But there's a problem when you want to prove this to a third party (e.g. a smart contract): you know the secret, so you could have decrypted the data, manipulated it, and encrypted it again before sharing it along with the secret, or doing a zero-knowledge proof. There has been the [proposal](https://github.com/tlsnotary/pagesigner/) to use a cryptographic tool called [Secure-Multi-Party-Computation (MPC)](https://en.wikipedia.org/wiki/Secure_multi-party_computation) to establish a TLS connection where the secret is split up between the user and a third party. If done correnctly, one could prove to this third party that the data is authentic. However, this crucially requires the third party doesn't make their part of the sercret public. But smart contracts *are* public, so the best [blockchain proposal](https://research.chain.link/deco.pdf) of this idea suggested to use enclaves as the third party.

<br/> 

> "But could we think of a more decentralized enclave solution?"

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

