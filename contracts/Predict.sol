// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@api3/contracts/v0.8/interfaces/IProxy.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external;
    function transfer(address recipient, uint256 amount) external;
    function transferFrom(address sender, address recipient, uint256 amount) external;
    function balanceOf(address holder) external returns (uint256);
}

// A Requester that will return the requested data by calling the specified Airnode.
contract Prediction is RrpRequesterV0, Ownable {
    mapping(bytes32 => bool) public incomingFulfillments;
    mapping(bytes32 => int256) public fulfilledData;
    // Mapping of bettor's address to their bet
    mapping(address => Bet) public bets;
    

    // This RRP contract will only accept uint256 requests from the Airnode.
    event RequestFulfilled(bytes32 indexed requestId, int256 response);
    event RequestedUint256(bytes32 indexed requestId);
    // Event for when a bet is placed
    event BetPlaced(address indexed bettor, uint betNumber, uint amount, uint insured);
    event ClaimPaid(address indexed bettor, uint amount);

    // The proxy contract address obtained from the API3 Market UI.
    address public ethProxyAddress;
    address public apeCoinProxyAddress;
    // Array of addresses that have placed bets
    address[] public bettors;

    uint256 public winningNumber;

    //Interface for token
    IERC20 Token;

    // Represents a bet made by a user
    struct Bet {
        uint betNumber;
        uint amount;
        bool insured;
        bool settled;
    }

    // Make sure you specify the right _rrpAddress for your chain while deploying the contract.
    constructor(address _rrpAddress, address _token) RrpRequesterV0(_rrpAddress) {
        Token = IERC20(_token);
    }

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
        winningNumber = uint256(decodedData);
        emit RequestFulfilled(requestId, decodedData);
    }


    function setProxyAddress (address _ethProxyAddress, address _apeCoinProxyAddress) public onlyOwner {
            ethProxyAddress = _ethProxyAddress;
            apeCoinProxyAddress = _apeCoinProxyAddress;
    }

    function readDataFeed(address _proxyAddress) public view returns (uint256, uint256){
            (int224 value, uint256 timestamp) = IProxy(_proxyAddress).read();
            //convert price to UINT256
            uint256 price = uint224(value);
            return (price, timestamp);
    }

    function placeBet(uint256 _betNumber, uint256 _insurance) external payable {
        //place bet
        require(msg.value > 0, "Bet amount must be greater than 0");
        require(_betNumber > 0, "Betting number must be greater than 0");

        // Record the bettor's address
        bettors.push(msg.sender);

        if (_insurance > 0) {
            //Check the price of tokens:
            (uint256 ethPrice, ) = readDataFeed(ethProxyAddress);
            (uint256 usdcPrice, ) = readDataFeed(apeCoinProxyAddress);

            // Calculate the Ether value of the insurance in USDC
            uint256 insuranceValueInETH = (_insurance * usdcPrice) / ethPrice;

            // Ensure that the insurance value is at least 25% of the bet value
            require(insuranceValueInETH  >= (msg.value / 4), "Insurance value must be at least 25% of the bet value");

            //make sure to set allowance to contract
            Token.transferFrom(msg.sender, address(this), _insurance);

            // Record the bet with insurance
            bets[msg.sender] = Bet({
            betNumber: _betNumber,
            amount: msg.value,
            insured: true,
            settled: false
            });

        } else {
            // Record the bet without insurance
            bets[msg.sender] = Bet({
            betNumber: _betNumber,
            amount: msg.value,
            insured: false,
            settled: false
            });
        }   

        emit BetPlaced(msg.sender, _betNumber, msg.value, _insurance);
    }

    // Function to settle all bets
    function settleAllBets() public {
        for (uint i = 0; i < bettors.length; i++) {
            address bettor = bettors[i];
            Bet storage bet = bets[bettor];
            if (!bet.settled) {
                if (bet.betNumber == winningNumber) {
                    // If the bettor guessed the correct number, send back the bet amount times a multiplier
                    (bool success, ) = payable(bettor).call{value: bet.amount * 2}("");
                    require(success, "Failed payout");
                } else if (bet.insured) {
                    // If the bettor's guess was incorrect but insured, send back half the bet amount
                    (bool success, ) = payable(bettor).call{value: bet.amount / 2}("");
                    require(success, "Failed payout");
                }

                bet.settled = true;
                emit ClaimPaid(bettor, bet.amount);
            }
        }

        // Clear the bettors array after settling all bets
        delete bettors;
    }

    // To receive funds from the sponsor wallet and send them to the owner.
    receive() external payable {
        payable(owner()).transfer(address(this).balance);
    }

    // To withdraw funds from the sponsor wallet to the contract.
    function withdraw(address airnode, address sponsorWallet) external onlyOwner {
        airnodeRrp.requestWithdrawal(
        airnode,
        sponsorWallet
        );
    }

    // Function to withdraw any remaining funds in the contract (for the owner)
    function withdrawProfit() external onlyOwner{
        (bool success, ) = payable(msg.sender).call{value: (address(this).balance)}("");
        require(success, "Failed payout");
    }
}