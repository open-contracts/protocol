pragma solidity >=0.8.0;

contract OpenContract {
    OpenContractsHub private hub = OpenContractsHub(0x059dE2588d076B67901b07A81239286076eC7b89);
    OpenContractsPaymaster private paymaster = OpenContractsPaymaster(0x059dE2588d076B67901b07A81239286076eC7b89);
 
    // this call tells the Hub which oracleID is allowed for a given contract function
    function setOracleHash(bytes4 selector, bytes32 oracleHash) internal {
        hub.setOracleHash(selector, oracleHash);
    }
    
    function prepayGas(bytes4 selector, bytes32 gasID) internal { 
       // any additional gas params that need to be defined here?
       // goal: minimize params exposed via API subject to everything just working safely
       // might need to though, to de
       paymaster.prepayGas(selector, gasID);
    }
 
    modifier requiresOracle {
        // the Hub uses the Verifier to ensure that the calldata came from the right oracleID
        require(msg.sender == address(hub), "Can only be called via Open Contracts Hub.");
        _;
    }
}

interface OpenContractsHub {
    function setOracleHash(bytes4, bytes32) external;
}

interface OpenContractsPaymaster {
    function prepayGas(bytes3, bytes32) external;
}
