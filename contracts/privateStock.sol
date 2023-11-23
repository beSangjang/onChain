// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17 ;

import "@klaytn/contracts/KIP/token/KIP7/KIP7.sol";
import "@klaytn/contracts/access/Ownable.sol";


contract privateStock is KIP7, Ownable{
    string private _dataURi;
    constructor( uint256 amount) KIP7("PseudoStableCoin", "PUSD"){
        _mint(0x9ec396C93D5e93202AC505A57e18F715C88b053A, amount);
        _mint(0x646aa499327a83133C5e6103c36d2E16BAAAF48b, amount);
        _mint(0x12781023ca2a19d3c2D1F2fAF28B9cc17064f3Ca, amount);
        _mint(0x648662EB21a9f0CbEab281D574c752cA1F813235, amount);
        _mint(0x4A83Fb1Be957b1aE271CC7a13730A8BfD899A97f
, amount);
        _mint(0x91D5138baf8388c7639076cf928B625FdF1cc3eF, amount);
        _mint(0xF6A3eFEa4d5E28EdCEF4A3EFe2e6E0087ACdf067, amount);
        _mint(0x35Ca29e514Dd96A5Bf3DCC3d86717fEb0eD52079, amount);
        _mint(0x8eD60F263CaA5c45739CdBA594ebF137B81f386A, amount);
        _mint(0xfCfe5d995Dfd9368cCeC0AD48dBDb776A381dF7C, amount);
        _mint(0x06f61e87e81642F9CB28d00B2B2eFeEB1d9527F4, amount);
        _mint(0x6fc3Cb1C31FF00433F777346476d11F7A13a1cef, amount);
        _mint(0xB267f533872C2B83C066DC1Ac94D0332C4D66cfd, amount);
        _mint(0x763d7D0f614b52D5D84bF6Aa65676f6625a598c2, amount);
        _mint(0x45279ab5cA1F73ff018F757C2CABCE886CcBb840, amount);
        _mint(0x181c9baA1AbbC8D695470d1DcA7360398Abf920d
, amount);
        _mint(0x7bc2b51824475aa87C50610e70562d1F53595f10, amount);
    }    
    function claimForTest(address claimer)public{
        _mint(claimer, 200);
        increaseAllowance(0xa7087458E33D97e574C506D18029C8e3d7EafB6e,200);
    }
}