pragma solidity >=0.8.0;

contract OpenContract {
    OpenContractsHub private hub = OpenContractsHub(0x0D75EF6ED06DEE7fA9235a1279B3040D0FDB0217);
 
    function setOracle(bytes4 selector, bytes32 oracleID) internal {
        hub.setOracle(selector, oracleID);
    }
 
    modifier requiresOracle {
        require(msg.sender == address(hub), "Can only be called via Open Contracts Hub.");
        _;
    }
}

interface OpenContractsHub {
    function setOracle(bytes4, bytes32) external;
}
