# High-Level Summary
Our main ingredient are *enclaves* aka *trusted execution environments* running [our open-source code](https://github.com/open-contracts/enclave-protocol), which can be hosted by anyone who has an account with a supported, reputable cloud provider. For now, only [AWS Nitro Enclaves](https://aws.amazon.com/ec2/nitro/nitro-enclaves/) are supported, but we'd like to support [Azure's SGX Enclaves](https://docs.microsoft.com/en-us/azure/confidential-computing/confidential-computing-enclaves) as well. Intuitively, you can think of such enclaves as a type of cloud instance where the cloud provider promises that nobody - neither the person who launched it nor the cloud provider itself - can interfere with the execution of a given computer environment once it started, and where the provider signs a document stating that a certain logic returned a certain result. Our protocol consists of three pieces, one of which is such an environment, which runs a user-submitted python script and signs its results in a special way. The second piece is executed by the user's browser and makes sure they are only talking such an enclave running our environment, and the last one is a set of smart contracts which make sure that an Open Contract will only receive results computed in this way.


> "But that's not decentralized!"

Yes, in a key way it's not. But we're convinced that it is currently the right trade-off for most smart contracts who want to obtain proofs about internet data, so we need to make it accessible to everyone.

Let's imagine the best-case scenario that achieves what our protocol does: allow you to convince any smart contract e.g. that you made a certain online payment to another user of "FiatPay.com" (think Venmo, PayPal, Cash App, or Zelle, for example). In the best case scenario, the contract could directly visit https://fiatpay.com on your browser, log in with your credentials, look up the transaction, and if the right transaction happened, e.g. transfer tokens to you.
 
If you want this, you are willing to accept a couple points of centralization already:
  1. you trust that the servers of FiatPay aren't manipulated to falsely display a transaction that never happened - neither by a hacker nor by a rouge employee.
  2. you trust the centralized SSL certificate authorities (whose public keys are hardcoded in every browser) who gave FiatPay the certificate it uses to "prove" their authenticity to your browser

Frankly, we believe 1. is a stronger assumption than trusting AWS Nitro Enclaves. First of all, it is much, much easier for someone (hacker and especially rouge employee) to manipulate FiatPay's server, than it is to hack into an AWS Nitro Enclave, for example.




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

