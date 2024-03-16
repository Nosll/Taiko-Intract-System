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
}

contract MockLendContract {
    IERC20 public depositToken;
    address public owner;
    uint256 public annualInterestRate;
    uint256 public ethTokenRate = 10000 * 10 ** 4; // 1 eth = 10000 tokens;
    uint256 public borrowRate = 80; // 80%

    mapping(address => uint256) public balance;
    mapping(address => uint256) public depositBalance;
    mapping(address => uint256) public depositTimestamps;
    mapping(address => uint256) public tokenLock;
    mapping(address => uint256) public debt;

    event Deposit(address from, uint256 amount);
    event Withdraw(address to, uint amount);

    constructor(address _tokenAddress) {
        depositToken = IERC20(_tokenAddress);
        owner = msg.sender;
    }

    receive() external payable {}

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function depositEth() external payable onlyOwner {}

    function withdrawEth() external payable onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // Modifier
    function setAnnualInterestRate(
        uint256 _annualInterestRate
    ) external onlyOwner {
        require(msg.sender == owner, "Only owner can set the interest rate");
        annualInterestRate = _annualInterestRate;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(msg.sender == owner, "Only the owner can transfer ownership");
        owner = newOwner;
    }

    function changeEthTokenRate(uint256 _rate) public onlyOwner {
        ethTokenRate = _rate;
    }

    function changeBorrowRate(uint256 _rate) public onlyOwner {
        borrowRate = _rate;
    }

    //
    function currentBalance() public view returns (uint256) {
        return balance[msg.sender] + calculateInterest(msg.sender);
    }

    function balanceOfContract() public view returns (uint256) {
        return depositToken.balanceOf(address(this));
    }

    function lendTokens(uint256 _amount) external {
        require(
            depositToken.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );
        uint256 interest = calculateInterest(msg.sender);
        balance[msg.sender] += (_amount + interest);
        depositTimestamps[msg.sender] = block.timestamp;
        depositBalance[msg.sender] += _amount;
        emit Deposit(msg.sender, _amount);
    }

    function calculateInterest(address _user) public view returns (uint256) {
        if (balance[_user] == 0) {
            return 0;
        }
        uint256 depositDuration = block.timestamp - depositTimestamps[_user];
        uint256 interest = (balance[_user] *
            depositDuration *
            annualInterestRate) / (365 days * 100);
        return interest;
    }

    function calculateBorrowLimit(address _user) public view returns (uint256) {
        uint256 rawBalance = depositBalance[_user];
        uint256 borrowLimit = (((rawBalance * 10 ** 18) / (10000 * 10 ** 4)) *
            borrowRate) / 100;
        return borrowLimit;
    }

    function withdrawTokens(uint256 _amount) external {
        require(_amount > 0, "Withdrawal amount must be greater than zero");
        uint256 principal = balance[msg.sender];
        uint256 interest = calculateInterest(msg.sender);
        uint256 currentLock = tokenLock[msg.sender];
        uint256 totalAvailable = principal + interest - currentLock;
        require(totalAvailable >= _amount, "Insufficient funds to withdraw");
        require(
            depositToken.transfer(msg.sender, _amount),
            "Withdrawal failed"
        );
        balance[msg.sender] = totalAvailable - _amount;
        depositTimestamps[msg.sender] = block.timestamp;
        depositBalance[msg.sender] -= _amount;
        emit Withdraw(msg.sender, _amount);
    }

    function withdrawAll() external {
        uint256 principal = balance[msg.sender];
        uint256 interest = calculateInterest(msg.sender);
        uint256 currentLock = tokenLock[msg.sender];
        uint256 totalAvailable = principal + interest - currentLock;
        require(totalAvailable > 0, "Insufficient funds to withdraw");
        require(
            depositToken.transfer(msg.sender, totalAvailable),
            "Withdrawal failed"
        );
        balance[msg.sender] = 0;
        depositTimestamps[msg.sender] = block.timestamp;
        depositBalance[msg.sender] = 0;
        emit Withdraw(msg.sender, totalAvailable);
    }

    function borrowAll() external payable {
        require(depositBalance[msg.sender] > 0, "Insufficient funds to borrow");
        uint256 borrowLimit = calculateBorrowLimit(msg.sender);
        uint256 lockAmount = ((borrowLimit * ethTokenRate) / borrowRate) /
            (10 ** 16);
        require(lockAmount > 0, "Lock amount should be greater than zero");
        payable(msg.sender).transfer(borrowLimit);
        tokenLock[msg.sender] += lockAmount;
        debt[msg.sender] += borrowLimit;
    }

    function repayAll() external payable {
        require(debt[msg.sender] > 0, "No debt to repay");
        require(msg.value == debt[msg.sender], "Error repay value");
        uint256 borrowLimit = calculateBorrowLimit(msg.sender);
        uint256 lockAmount = ((borrowLimit * ethTokenRate) / borrowRate) /
            (10 ** 16);
        require(lockAmount > 0, "Lock amount should be greater than zero");
        tokenLock[msg.sender] -= lockAmount;
        debt[msg.sender] -= borrowLimit;
    }

    function borrow(uint256 _amount) external payable {
        require(depositBalance[msg.sender] > 0, "Insufficient funds to borrow");
        uint256 borrowLimit = calculateBorrowLimit(msg.sender);
        require(_amount <= borrowLimit, "Borrow amount exceeds limit");
        uint256 lockAmount = ((_amount * ethTokenRate) / borrowRate) /
            (10 ** 16);
        require(lockAmount > 0, "Lock amount should be greater than zero");
        payable(msg.sender).transfer(_amount);
        tokenLock[msg.sender] += lockAmount;
        debt[msg.sender] += _amount;
    }

    function repay(uint256 _amount) external payable {
        require(debt[msg.sender] > 0, "No debt to repay");
        require(_amount <= debt[msg.sender], "Repay amount exceeds debt");
        uint256 lockAmount = ((_amount * ethTokenRate) / borrowRate) /
            (10 ** 16);
        require(lockAmount > 0, "Lock amount should be greater than zero");
        require(msg.value == _amount, "Incorrect repay amount");
        tokenLock[msg.sender] -= lockAmount;
        debt[msg.sender] -= _amount;
    }
}
