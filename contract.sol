pragma solidity >=0.8.0;

contract OpenContractsForwarder {
    address public hub;
    address public devAddress;
    bool public completed = false;

    // upon deployment, we set the addresses of the first hub and of the Open Contracts Devs.
    constructor() {
        devAddress = msg.sender;
    }

    // if not frozen, allows the devs to update the hub and their address.
    function update(address newHub, address newDevAddress, bool complete) public {
        require(!completed, "The hub can no longer be updated.");
        require(msg.sender == devAddress, "Only the devs can update the forwarder.");
        hub = newHub;
        devAddress = newDevAddress;
        completed = complete;
    }

    // forwards call to destination contract
    function forwardCall(address payable destinationContract, bytes memory call) public payable returns(bool, bytes memory) {
        require(msg.sender == hub, 'Only the current hub can use the forwarder.');
        return destinationContract.call{value: msg.value, gas: gasleft()}(call);
    }
}
