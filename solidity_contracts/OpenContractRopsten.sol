pragma solidity >=0.8.0;

contract OpenContract {
    OpenContractsHub private hub = OpenContractsHub(0xAAfa8f64a9EE68edB350Ea5F2A8839Cf0ad3A57B);
 
    // this call tells the Hub which oracleID is allowed for a given contract function
    function setOracle(bytes4 selector, bytes32 oracleID) internal {
        hub.setOracle(selector, oracleID);
    }
 
    modifier requiresOracle {
        // the Hub uses the Verifier to ensure that the calldata came from the right oracleID
        require(msg.sender == address(hub), "Can only be called via Open Contracts Hub.");
        _;
    }
}

interface OpenContractsHub {
    function setOracle(bytes4, bytes32) external;
}
