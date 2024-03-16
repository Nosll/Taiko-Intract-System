// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function mintTo(address to, uint amount) external;
    function burnFrom(address sender, uint256 amount) external;
    function delegateOwnership(address _newOwner) external;
}

contract stakeContract {
    address public owner;
    IERC20 public tokenContract;
    IERC20 public stakeTokenContract;

    constructor(address _tokenAddress, address _stakeTokenAddress) {
        owner = msg.sender;
        tokenContract = IERC20(_tokenAddress);
        stakeTokenContract = IERC20(_stakeTokenAddress);
    }

    function stakeAll() external {
        uint256 tokenBalance = tokenContract.balanceOf(msg.sender);
        require(tokenBalance > 0, "Insufficient funds to stake");
        tokenContract.transferFrom(msg.sender, address(this), tokenBalance);
        stakeTokenContract.mintTo(msg.sender, tokenBalance);
    }

    function redeemAll() external {
        uint256 stakeTokenBalance = stakeTokenContract.balanceOf(msg.sender);
        require(stakeTokenBalance > 0, "Insufficient funds to redeem");
        tokenContract.transfer(msg.sender, stakeTokenBalance);
        stakeTokenContract.burnFrom(msg.sender, stakeTokenBalance);
    }

    function stake(uint _amount) external {
        uint256 tokenBalance = tokenContract.balanceOf(msg.sender);
        require(
            _amount > 0 && _amount <= tokenBalance,
            "Insufficient funds to stake"
        );
        tokenContract.transferFrom(msg.sender, address(this), _amount);
        stakeTokenContract.mintTo(msg.sender, _amount);
    }

    function redeem(uint _amount) external {
        uint256 stakeTokenBalance = stakeTokenContract.balanceOf(msg.sender);
        require(
            _amount > 0 && _amount <= stakeTokenBalance,
            "Insufficient funds to redeem"
        );
        tokenContract.transfer(msg.sender, _amount);
        stakeTokenContract.burnFrom(msg.sender, _amount);
    }
}
