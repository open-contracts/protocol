pragma solidity >=0.8.0;

contract OpenContractAlpha {
    address _forwarder = 0x9dAe5581fAf4a2C11150D8302D80D4009d2DFDa9;
    address _devs;
    bool public _completed;
    mapping(bytes4 => bytes32) _allowedHash;
    
    constructor() {
        _devs = msg.sender;
    }
    
    function  _complete_oracles() public {
        require(!_completed, "Oracle development is already completed.");
        require(msg.sender == _devs, "Only the devs can complete the development");
        _completed = true;
    }
    
    modifier _oracle(bytes32 oracleHash, address msgSender, bytes4 selector) {
        require(msg.sender == _forwarder, "Call has to be relayed by Open Contracts Hub.");
        if (_completed) {
            require(oracleHash == _allowedHash[selector], "Incorrect Oracle Hash.");
        } else if (msgSender == _devs) {
            _allowedHash[selector] = oracleHash;
        } else {
            revert("The devs are still updating the oracles. Only they can call this function for now.");
        }
        _;
    }
}
