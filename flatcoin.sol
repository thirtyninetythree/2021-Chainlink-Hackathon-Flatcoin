// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts@4.3.2/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.3.2/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

contract FlatCoin is ERC20, Ownable, ChainlinkClient {
    using Chainlink for Chainlink.Request;
    address private constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    uint256 public immutable referenceIndex = 0.18917963102 * 10 ** 18;
    uint256 public currentIndex;
    
    uint256 public BRENTOIL_PRICE;
    uint256 public SUGAR_PRICE;
    uint256 public GOLD_PRICE;
    
    event Log(string message, uint256 amount);
    event Rebalancing(string message);
    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Kovan
     * Aggregator: ETH/USD
     * Address: 0x9326BFA02ADD2366b30bacB125260Af641031331
     */
    /**
     * Network: Kovan
     * Oracle: 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8 (Chainlink Devrel   
     * Node)
     * Job ID: d5270d1c311941d0b08bead21fea7747
     * Fee: 0.1 LINK
     */
    
    constructor() ERC20("StableCoin", "Stable") {
        _mint(msg.sender, 100000 * 10 ** decimals());
        priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        
        setPublicChainlinkToken();
        oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        jobId = "d5270d1c311941d0b08bead21fea7747";
        fee = 0.1 * 10 ** 18; // (Varies by network and job)
        requestBrentOilPrice();
        
    }

    function mint(address _to, uint256 _amount) public payable {
        currentIndex = BRENTOIL_PRICE + SUGAR_PRICE + GOLD_PRICE;
        currentIndex = currentIndex/referenceIndex;
        require(msg.value * uint256(getLatestETHPrice()) < (1 + currentIndex) * _amount, "Too little collateral");
        emit Log("ETH PRICE: ", msg.value * uint256(getLatestETHPrice()));
        emit Log("Stable minted:", currentIndex * _amount);
        _mint(_to, _amount);
    }
    
    function burn(uint256 _amount) public payable {
        //burns sstables and returns collateral
        uint256 valueInUSD = _amount * currentIndex/referenceIndex;
        uint256 valueInETH = valueInUSD/uint256(getLatestETHPrice());
        
        (bool os, ) = payable(msg.sender).call{value: valueInETH }("");
            require(os);
        emit Log("Collateral redeemed:", currentIndex * _amount);
    }

    function getFlatCoinPrice() public returns(uint) {
        return totalSupply()/address(this).balance;
    }
    
    function requestBrentOilPrice() public returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfillBrentOilPrice.selector);
        // Set the URL to perform the GET request on
        request.add("get", "https://commodities-api.com/api/latest?access_key=wlg8y3040rwruc47ys58d21vua223v23sm7eun0shrul9vs49wcgzadcmtxq");
       
        request.add("path", "data.rates.BRENTOIL");
        
        // Multiply the result by 1000000000000000000 to remove decimals
        int timesAmount = 10**18;
        request.addInt("times", timesAmount);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
     /**
     * Receive the response in the form of uint256
     */ 
    function fulfillBrentOilPrice(bytes32 _requestId, uint256 _BRENTOIL) public recordChainlinkFulfillment(_requestId){
        BRENTOIL_PRICE = _BRENTOIL;
    }

    
    /**
     * Returns the latest ETH  price
     */
    function getLatestETHPrice() public view returns (int) {
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }
}
