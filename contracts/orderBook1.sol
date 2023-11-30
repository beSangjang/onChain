// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;


import "@klaytn/contracts/KIP/interfaces/IKIP7.sol";

// Define the Orderbook smart contract
contract orderbook{
struct Order {
    uint256 id;
    address trader;
    bool isBuyOrder;
    uint256 price;
    uint256 quantity;
    bool isFilled;
    address baseToken; // ERC20 token address for the base asset
    address quoteToken; // ERC20 token address for the quote asset (e.g., stablecoin)
}
// Arrays to store bid (buy) orders and ask (sell) orders
Order[] public bidOrders;
Order[] public askOrders;
// Events
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

// Place a buy order
function placeBuyOrder(uint256 price,
    uint256 quantity,
    address baseToken,
    address quoteToken
) external {
    // Check that the trader has approved enough quote tokens to cover the order value
    uint256 orderValue = price * quantity;
    IKIP7 quoteTokenContract = IKIP7(quoteToken);
    require(quoteTokenContract.allowance(msg.sender, address(this)) >= orderValue, "Insufficient allowance");
    // Insert the buy order and match it with compatible sell orders
    Order memory newOrder = Order({
        id: bidOrders.length,
        trader: msg.sender,
        isBuyOrder: true,
        price: price,
        quantity: quantity,
        isFilled: false,
        baseToken: baseToken,
        quoteToken: quoteToken
    });
    uint256 index= insertBidOrder(newOrder);
    matchBuyOrder(index);
}


 function viewAllOrders() view external returns(Order[] memory , Order[] memory) {
        return (bidOrders, askOrders);
    }

// Place a sell order
function placeSellOrder(
    uint256 price,
    uint256 quantity,
    address baseToken,
    address quoteToken
) external {
    // Check that the trader has approved enough base tokens to cover the order quantity
    IKIP7 baseTokenContract = IKIP7(baseToken);
    require(baseTokenContract.allowance(msg.sender, address(this)) >= quantity, "Insufficient allowance");
    // Insert the sell order and match it with compatible buy orders
    Order memory newOrder = Order({
        id: askOrders.length,
        trader: msg.sender,
        isBuyOrder: false,
        price: price,
        quantity: quantity,
        isFilled: false,
        baseToken: baseToken,
        quoteToken: quoteToken
    });
    uint256 index= insertAskOrder(newOrder);
    matchSellOrder(index);
}
// Function to cancel an existing order
function cancelOrder(uint256 orderId, bool isBuyOrder) external {
        // Retrieve the order from the appropriate array
        Order storage order = isBuyOrder
            ? bidOrders[getBidOrderIndex(orderId)]
            : askOrders[getAskOrderIndex(orderId)];
        // Verify that the caller is the original trader
        require(
            order.trader == msg.sender,
            "Only the trader can cancel the order"
        );
        // Mark the order as filled (canceled)
        order.isFilled = true;
        emit OrderCanceled(orderId, msg.sender, isBuyOrder);
}


    // Internal function to insert a new buy order into the bidOrders array
// while maintaining sorted order (highest to lowest price)
function insertBidOrder(Order memory newOrder) internal returns(uint256 index) {
    uint256 i = bidOrders.length;
    bidOrders.push(newOrder);
    while (i > 0 && bidOrders[i - 1].price < newOrder.price) {
        bidOrders[i] = bidOrders[i - 1];
        i--;
    }
    bidOrders[i] = newOrder;
    return (i);
}
// Internal function to insert a new sell order into the askOrders array
// while maintaining sorted order (lowest to highest price)
function  insertAskOrder(Order memory newOrder) internal returns(uint256 index){
    uint256 i = askOrders.length;
    askOrders.push(newOrder);
    while (i > 0 && askOrders[i - 1].price > newOrder.price) {
        askOrders[i] = askOrders[i - 1];
        i--;
    }
    askOrders[i] = newOrder;
    return (i);
}
// Internal function to match a buy order with compatible ask orders
function matchBuyOrder(uint256 buyOrderId) internal {
    Order storage buyOrder = bidOrders[buyOrderId];
    for (uint256 i = 0; i < askOrders.length && !buyOrder.isFilled; i++) {
        Order storage sellOrder = askOrders[i];
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
// Internal function to match a sell order with compatible bid orders
function matchSellOrder(uint256 sellOrderId) internal {
    Order storage sellOrder = askOrders[sellOrderId];
    for (uint256 i = 0; i < bidOrders.length && !sellOrder.isFilled; i++) {
        Order storage buyOrder = bidOrders[i];
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
// Function to get the index of a buy order in the bidOrders array
function getBidOrderIndex(uint256 orderId) public view returns (uint256) {
        require(orderId < bidOrders.length, "Order ID out of range");
        return orderId;
}
// Function to get the index of a seller order in the askOrders array
function getAskOrderIndex(uint256 orderId) public view returns (uint256) {
        require(orderId < askOrders.length, "Order ID out of range");
        return orderId;
}
// Helper function to find the minimum of two values
function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
}




}