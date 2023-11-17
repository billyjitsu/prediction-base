// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@api3/contracts/v0.8/interfaces/IProxy.sol";

// A Requester that will return the requested data by calling the specified Airnode.
contract RrpRequester is RrpRequesterV0, Ownable {
    mapping(bytes32 => bool) public incomingFulfillments;
    mapping(bytes32 => int256) public fulfilledData;
    // Mapping of bettor's address to their bet
    mapping(address => Bet) public bets;
    

    // This RRP contract will only accept uint256 requests from the Airnode.
    event RequestFulfilled(bytes32 indexed requestId, int256 response);
    event RequestedUint256(bytes32 indexed requestId);
  

    // The proxy contract address obtained from the API3 Market UI.
    address public ethProxyAddress;
    address public usdcProxyAddress;


    uint256 public winningNumber;

    // Represents a bet made by a user
    struct Bet {
        uint betNumber;
        uint amount;
        bool insured;
        bool settled;
    }

    constructor(address _rrpAddress) RrpRequesterV0(_rrpAddress) {}

    // The main makeRequest function that will trigger the Airnode request.
    function makeRequest(
        address airnode,
        bytes32 endpointId,
        address sponsor,
        address sponsorWallet,
        bytes calldata parameters

    ) external {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,                        // airnode address
            endpointId,                     // endpointId
            sponsor,                        // sponsor's address
            sponsorWallet,                  // sponsorWallet
            address(this),                  // fulfillAddress
            this.fulfill.selector,          // fulfillFunctionId
            parameters                      // encoded API parameters
        );
        incomingFulfillments[requestId] = true;
        emit RequestedUint256(requestId);
    }
    
    function fulfill(bytes32 requestId, bytes calldata data)
        external
        onlyAirnodeRrp
    {
        require(incomingFulfillments[requestId], "No such request made");
        delete incomingFulfillments[requestId];
        int256 decodedData = abi.decode(data, (int256));
        fulfilledData[requestId] = decodedData;
        emit RequestFulfilled(requestId, decodedData);
    }

    // To withdraw funds from the sponsor wallet to the contract.
    function withdraw(address airnode, address sponsorWallet) external onlyOwner {
        airnodeRrp.requestWithdrawal(
        airnode,
        sponsorWallet
        );
    }

    function setProxyAddress (address _ethProxyAddress, address _usdcProxyAddress) public onlyOwner {
            ethProxyAddress = _ethProxyAddress;
            usdcProxyAddress = _usdcProxyAddress;
    }

    function readDataFeed(address _proxyAddress) public view returns (uint256, uint256){
            (int224 value, uint256 timestamp) = IProxy(_proxyAddress).read();
            //convert price to UINT256
            uint256 price = uint224(value);
            return (price, timestamp);
    }

    // To receive funds from the sponsor wallet and send them to the owner.
    receive() external payable {
        payable(owner()).transfer(address(this).balance);
    }

    // Function to withdraw any remaining funds in the contract (for the owner)
    function withdrawProfit() external onlyOwner{
        (bool success, ) = payable(msg.sender).call{value: (address(this).balance)}("");
        require(success, "Failed payout");
    }
}