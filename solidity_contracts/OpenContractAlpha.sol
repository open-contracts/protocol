pragma solidity >=0.8.0;

contract OpenContractAlpha {
    address openContractsHub;
    
    constructor(address hub) {
        openContractsHub = hub;
    }
    
    modifier onlyOracle(bytes32 oracleHash, bytes32 allowedHash) {
        require(oracleHash == allowedHash, "Incorrect Oracle Hash.");
        require(msg.sender == openContractsHub, "Call has to be relayed by Open Contracts Hub.");
        _;
    }
    
}
