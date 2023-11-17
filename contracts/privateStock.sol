// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17 ;

import "@klaytn/contracts/KIP/token/KIP7/KIP7.sol";
import "@klaytn/contracts/access/Ownable.sol";


contract privateStock is KIP7, Ownable{

    constructor() KIP7("Doonamoo", "Doo"){
        _mint(msg.sender, 1000000);
    }
}