pragma solidity >=0.8.0;

contract OpenContractAlpha {
    address forwarder = 0x9dAe5581fAf4a2C11150D8302D80D4009d2DFDa9;
    
    modifier onlyOracle(bytes32 oracleHash, bytes32 allowedHash) {
        require(oracleHash == allowedHash, "Incorrect Oracle Hash.");
        require(msg.sender == forwarder, "Call has to be relayed by Open Contracts Hub.");
        _;
    }
    
}
