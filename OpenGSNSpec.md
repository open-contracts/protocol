According to the [OpenGSN docs](https://docs.opengsn.org/contracts/#paying-for-your-user-s-meta-transaction), the main logic to implement is the Paymaster. We want to create a paymaster that handles the deposits for all contracts, but defers to the individual contracts when it comes to defining the conditions for gas reimbursement, and depositing the gas funds in advance.


# OpenContract



# OpenContractsPaymaster

