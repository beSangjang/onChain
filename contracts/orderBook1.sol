// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IOrderBook } from "./interfaces/IOrderBook.sol";
import "@klaytn/contracts/KIP/token/KIP7/IKIP7.sol";







contract orderBook is ReentrancyGuard{
    using Math for uint256;
    using Math for uint8;
    
    
    struct Order {
   uint256 id;
    address trader;
    bool isBuyOrder;
    uint256 price;
    uint256 quantity;
    bool isFilled;
    address baseToken; 
    address quoteToken;
}

    event OrderCanceled(
         uint256 indexed orderId,
        address indexed trader,
        bool isBuyOrder
    );


    event TradeExecuted(
        uint256 indexed buyOrderId,
        uint256 indexed sellOrderId,
        address indexed buyer,
        address seller,
        uint256 price,
        uint256 quantity
    );
    

    IKIP7 public tradeToken;
    IKIP7 public baseToken;


    constructor(address _tradeToken, address _baseToken) { 
        tradeToken= IKIP7(_tradeToken);
        baseToken= IKIP7(_baseToken);
    }    


    Order[] public buyOrders;
    Order[] public sellOrders;
 
    function placeBuyOrder(uint256 price, uint256 quantity, address tokenTrade,address tokenBase)
    external {
        uint256 orderPrice= price*quantity;

        IKIP7 tokenTradeToken= IKIP7(tokenTrade);
         require(tokenTradeToken.allowance(msg.sender, address(this)) >= orderPrice, "Insufficient allowance");
        
        Order memory newOrder = Order({
        id: buyOrders.length,
        trader: msg.sender,
        isBuyOrder: true,
        price: price,
        quantity: quantity,
        isFilled: false,
        baseToken: tokenTrade,
        quoteToken: tokenBase
    });
    insertBuyOrder(newOrder);
    matchBuyOrder(newOrder.id);
    }

    function viewAllOrders() view external returns(Order[] memory , Order[] memory) {
        return (buyOrders, sellOrders);
    }

    function placeSellOrder(uint256 price, uint256 quantity, address tokenTrade, address tokenBase )external
    {
        IKIP7 baseTokenContract = IKIP7(tokenBase);
        require(baseTokenContract.allowance(msg.sender, address(this)) >= quantity, "Insufficient allowance");
        Order memory newOrder = Order({
        id: sellOrders.length,
        trader: msg.sender,
        isBuyOrder: false,
        price: price,
        quantity: quantity,
        isFilled: false,
        baseToken: tokenBase,
        quoteToken: tokenTrade
    });
    insertSellOrder(newOrder);
    matchSellOrder(newOrder.id);
    }

    function cancelOrder(uint256 orderId, bool isBuyOrder) external {
        // Retrieve the order from the appropriate array
        Order storage order = isBuyOrder
            ? buyOrders[getBuyOrderIndex(orderId)]
            : sellOrders[getSellOrderIndex(orderId)];
        // Verify that the caller is the original trader
        require(
            order.trader == msg.sender,
            "Only the trader can cancel the order"
        );
        // Mark the order as filled (canceled)
        order.isFilled = true;
        emit OrderCanceled(orderId, msg.sender, isBuyOrder);
}

    function insertBuyOrder(Order memory newOrder) internal {
    uint256 i = buyOrders.length;
    buyOrders.push(newOrder);
    while (i > 0 && buyOrders[i - 1].price < newOrder.price) {
        buyOrders[i] = buyOrders[i - 1];
        i--;
    }
    buyOrders[i] = newOrder;
}


    function insertSellOrder(Order memory newOrder) internal {
    uint256 i = sellOrders.length;
    sellOrders.push(newOrder);
    while (i > 0 && sellOrders[i - 1].price > newOrder.price) {
        sellOrders[i] = sellOrders[i - 1];
        i--;
    }
    sellOrders[i] = newOrder;
}   




function matchBuyOrder(uint256 buyOrderId) internal {
    Order storage buyOrder = buyOrders[buyOrderId];
    for (uint256 i = 0; i < sellOrders.length && !buyOrder.isFilled; i++) {
        Order storage sellOrder = sellOrders[i];
        if (sellOrder.price <= buyOrder.price && !sellOrder.isFilled) {
            uint256 tradeQuantity = min(buyOrder.quantity, sellOrder.quantity);
            // Execute the trade
            IKIP7 baseTokenContract = IKIP7(buyOrder.baseToken);
            IKIP7 quoteTokenContract = IKIP7(buyOrder.quoteToken);
            uint256 tradeValue = tradeQuantity * buyOrder.price;
            // Transfer base tokens from the seller to the buyer
            baseTokenContract.transferFrom(sellOrder.trader, buyOrder.trader, tradeQuantity);
            // Transfer quote tokens from the buyer to the seller
            quoteTokenContract.transferFrom(buyOrder.trader, sellOrder.trader, tradeValue);
            // Update order quantities and fulfillment status
            buyOrder.quantity -= tradeQuantity;
            sellOrder.quantity -= tradeQuantity;
            buyOrder.isFilled = buyOrder.quantity == 0;
            sellOrder.isFilled = sellOrder.quantity == 0;
            // Emit the TradeExecuted event
             emit TradeExecuted(
                    buyOrder.id,
                    i,
                    buyOrder.trader,
                    sellOrder.trader,
                    sellOrder.price,
                    tradeQuantity
             );
        }
    }
}

function matchSellOrder(uint256 sellOrderId) internal {
    Order storage sellOrder = sellOrders[sellOrderId];
    for (uint256 i = 0; i < buyOrders.length && !sellOrder.isFilled; i++) {
        Order storage buyOrder = buyOrders[i];
        if (buyOrder.price >= sellOrder.price && !buyOrder.isFilled) {
            uint256 tradeQuantity = min(buyOrder.quantity, sellOrder.quantity);
            // Execute the trade
            IKIP7 baseTokenContract = IKIP7(sellOrder.baseToken);
            IKIP7 quoteTokenContract = IKIP7(sellOrder.quoteToken);
            uint256 tradeValue = tradeQuantity * sellOrder.price;
            // Transfer base tokens from the seller to the buyer
            baseTokenContract.transferFrom(sellOrder.trader, buyOrder.trader, tradeQuantity);
            // Transfer quote tokens from the buyer to the seller
            quoteTokenContract.transferFrom(buyOrder.trader, sellOrder.trader, tradeValue);
            // Update order quantities and fulfillment status
            buyOrder.quantity -= tradeQuantity;
            sellOrder.quantity -= tradeQuantity;
            buyOrder.isFilled = buyOrder.quantity == 0;
            sellOrder.isFilled = sellOrder.quantity == 0;
             // Emit the TradeExecuted event
            emit TradeExecuted(
                    buyOrder.id,
                    i,
                    buyOrder.trader,
                    sellOrder.trader,
                    sellOrder.price,
                    tradeQuantity
            );
        }
    }
}
function getBuyOrderIndex(uint256 orderId) public view returns (uint256) {
        require(orderId < buyOrders.length, "Order ID out of range");
        return orderId;
}
// Function to get the index of a seller order in the askOrders array
function getSellOrderIndex(uint256 orderId) public view returns (uint256) {
        require(orderId < sellOrders.length, "Order ID out of range");
        return orderId;
}
// Helper function to find the minimum of two values
function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
}
}