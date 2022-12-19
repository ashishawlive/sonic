// SPDX-License-Identifier: MIT
// Sonic - The Hedge Coin
// Smart Contract for New Currency
// Will be deployed on Polygon/MATIC Mumbai Testnet
// The Currency will be called Sonic with symbol SON
// The Currency will have 100 Billion Coins
// Each Coin will have 18 decimals
// The Currency will have a 2% burn fee
// The Currency will have a 1% marketing fee
// The Currency will have a 1% development fee
// The Currency will have a 1% team fee
// The Currency will have a 1% rewards fee
// The Currency will have a 1% buyback fee
// The Currency will have a 1% dividend fee
// There are predefined addresses for the fees
// Minimum transaction amount is 0.1 SON
// Maximum transaction amount is 1000 SON
// Minimum wallet balance is 0.1 SON
// Minimum wallet hold for rewards is 1000 SON

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";

// Uniswap V2 Router
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract Sonic is Context, ERC20, ERC20Burnable, ERC20Snapshot, Ownable {
    using SafeMath for uint256;
    using Address for address;

    // Fees
    uint256 public _taxFee = 10;
    uint256 private _previousTaxFee = _taxFee;

    uint256 public _liquidityFee = 5;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _burnFee = 2;
    uint256 private _previousBurnFee = _burnFee;

    uint256 public _marketingFee = 1;
    uint256 private _previousMarketingFee = _marketingFee;

    uint256 public _developmentFee = 1;
    uint256 private _previousDevelopmentFee = _developmentFee;

    uint256 public _teamFee = 1;
    uint256 private _previousTeamFee = _teamFee;

    uint256 public _rewardsFee = 1;
    uint256 private _previousRewardsFee = _rewardsFee;

    uint256 public _buybackFee = 1;
    uint256 private _previousBuybackFee = _buybackFee;

    uint256 public _dividendFee = 1;
    uint256 private _previousDividendFee = _dividendFee;

    // Addresses
    address public _marketingWalletAddress;
    address public _developmentWalletAddress;
    address public _teamWalletAddress;
    address public _rewardsWalletAddress;
    address public _buybackWalletAddress;
    address public _dividendWalletAddress;

    // Uniswap V2 Router
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    // Swap and Liquify
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    uint256 public _maxTxAmount = 1000 * 10**18;
    uint256 private numTokensSellToAddToLiquidity = 500 * 10**18;

    // Events
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event SwapETHForTokens(
        uint256 amountIn,
        address[] path
    );
    event SwapTokensforETH(
        uint256 amountIn,
        address[] path
    );

    constructor() ERC20("Sonic", "SON") {
        _marketingWalletAddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        _developmentWalletAddress = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
        _teamWalletAddress = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
        _rewardsWalletAddress = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
        _buybackWalletAddress = 0x617F2E2fD72FD9D5503197092aC168c91465E7f2;
        _dividendWalletAddress = 0x17F6AD8Ef982297579C203069C1DbfFE4348c372;

        _mint(_msgSender(), 100000000000 * 10**18);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    receive() external payable {}

    // lock the swap and liquify function
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if (from != owner() && to != owner())
            require(
                amount <= _maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );

        uint256 contractTokenBalance = balanceOf(address(this));

        bool overMinimumTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
        if (
            overMinimumTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            swapAndLiquify(contractTokenBalance);
        }

        bool takeFee = true;

        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        if (!takeFee) removeAllFee();

        _tokenTransfer(from, to, amount, takeFee);

        if (!takeFee) restoreAllFee();
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(half);

        uint256 newBalance = address(this).balance.sub(initialBalance);

        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );

        emit SwapTokensforETH(tokenAmount, path);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    function removeAllFee() private {
        if (_taxFee == 0 && _liquidityFee == 0 && _burnFee == 0 && _marketingFee == 0 && _developmentFee == 0 && _teamFee == 0 && _rewardsFee == 0 && _buybackFee == 0 && _dividendFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousBurnFee = _burnFee;
        _previousMarketingFee = _marketingFee;
        _previousDevelopmentFee = _developmentFee;
        _previousTeamFee = _teamFee;
        _previousRewardsFee = _rewardsFee;
        _previousBuybackFee = _buybackFee;
        _previousDividendFee = _dividendFee;

        _taxFee = 0;
        _liquidityFee = 0;
        _burnFee = 0;
        _marketingFee = 0;
        _developmentFee = 0;
        _teamFee = 0;
        _rewardsFee = 0;
        _buybackFee = 0;
        _dividendFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _burnFee = _previousBurnFee;
        _marketingFee = _previousMarketingFee;
        _developmentFee = _previousDevelopmentFee;
        _teamFee = _previousTeamFee;
        _rewardsFee = _previousRewardsFee;
        _buybackFee = _previousBuybackFee;
        _dividendFee = _previousDividendFee;
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn, uint256 tMarketing, uint256 tDevelopment, uint256 tTeam, uint256 tRewards, uint256 tBuyback, uint256 tDividend) = _getValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            tBurn,
            tMarketing,
            tDevelopment,
            tTeam,
            tRewards,
            tBuyback,
            tDividend,
            _getRate()
        );
        _standardTransferContent(sender, recipient, rAmount, rTransferAmount);
        _sendToFee(tFee, tLiquidity, tBurn, tMarketing, tDevelopment, tTeam, tRewards, tBuyback, tDividend);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn, uint256 tMarketing, uint256 tDevelopment, uint256 tTeam, uint256 tRewards, uint256 tBuyback, uint256 tDividend) = _getValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            tBurn,
            tMarketing,
            tDevelopment,
            tTeam,
            tRewards,
            tBuyback,
            tDividend,
            _getRate()
        );
        _excludedFromTransferContent(sender, recipient, rAmount, rTransferAmount);
        _sendToFee(tFee, tLiquidity, tBurn, tMarketing, tDevelopment, tTeam, tRewards, tBuyback, tDividend);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn, uint256 tMarketing, uint256 tDevelopment, uint256 tTeam, uint256 tRewards, uint256 tBuyback, uint256 tDividend) = _getValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            tBurn,
            tMarketing,
            tDevelopment,
            tTeam,
            tRewards,
            tBuyback,
            tDividend,
            _getRate()
        );
        _excludedToTransferContent(sender, recipient, rAmount, rTransferAmount);
        _sendToFee(tFee, tLiquidity, tBurn, tMarketing, tDevelopment, tTeam, tRewards, tBuyback, tDividend);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn, uint256 tMarketing, uint256 tDevelopment, uint256 tTeam, uint256 tRewards, uint256 tBuyback, uint256 tDividend) = _getValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            tBurn,
            tMarketing,
            tDevelopment,
            tTeam,
            tRewards,
            tBuyback,
            tDividend,
            _getRate()
        );
        _bothTransferContent(sender, recipient, rAmount, rTransferAmount);
        _sendToFee(tFee, tLiquidity, tBurn, tMarketing, tDevelopment, tTeam, tRewards, tBuyback, tDividend);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _standardTransferContent(
        address sender,
        address recipient,
        uint256 rAmount,
        uint256 rTransferAmount
    ) private {
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
    }

    function _excludedFromTransferContent(
        address sender,
        address recipient,
        uint256 rAmount,
        uint256 rTransferAmount
    ) private {
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(rTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
    }

    function _excludedToTransferContent(
        address sender,
        address recipient,
        uint256 rAmount,
        uint256 rTransferAmount
    ) private {
        _tOwned[sender] = _tOwned[sender].sub(rAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
    }

    function _bothTransferContent(
        address sender,
        address recipient,
        uint256 rAmount,
        uint256 rTransferAmount
    ) private {
        _tOwned[sender] = _tOwned[sender].sub(rAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(rTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
    }

    function _sendToFee(
        uint256 tFee,
        uint256 tLiquidity,
        uint256 tBurn,
        uint256 tMarketing,
        uint256 tDevelopment,
        uint256 tTeam,
        uint256 tRewards,
        uint256 tBuyback,
        uint256 tDividend
    ) private {
        _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity).add(tBurn).add(tMarketing).add(tDevelopment).add(tTeam).add(tRewards).add(tBuyback).add(tDividend);
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tFee);
        }
        if (tFee > 0) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tFee);
        }
        if (tLiquidity > 0) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
        }
        if (tBurn > 0) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tBurn);
        }
        if (tMarketing > 0) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tMarketing);
        }
        if (tDevelopment > 0) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tDevelopment);
        }
        if (tTeam > 0) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tTeam);
        }
        if (tRewards > 0) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tRewards);
        }
        if (tBuyback > 0) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tBuyback);
        }
        if (tDividend > 0) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tDividend);
        }
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tBurn, uint256 tMarketing, uint256 tDevelopment, uint256 tTeam, uint256 tRewards, uint256 tBuyback, uint256 tDividend) = _getTValues(tAmount, _taxFee, _liquidityFee, _burnFee, _marketingFee, _developmentFee, _teamFee, _rewardsFee, _buybackFee, _dividendFee);
        return (tTransferAmount, tFee, tLiquidity, tBurn, tMarketing, tDevelopment, tTeam, tRewards, tBuyback, tDividend);
    }

    function _getTValues(
        uint256 tAmount,
        uint256 taxFee,
        uint256 liquidityFee,
        uint256 burnFee,
        uint256 marketingFee,
        uint256 developmentFee,
        uint256 teamFee,
        uint256 rewardsFee,
        uint256 buybackFee,
        uint256 dividendFee
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = tAmount.mul(taxFee).div(10000);
        uint256 tLiquidity = tAmount.mul(liquidityFee).div(10000);
        uint256 tBurn = tAmount.mul(burnFee).div(10000);
        uint256 tMarketing = tAmount.mul(marketingFee).div(10000);
        uint256 tDevelopment = tAmount.mul(developmentFee).div(10000);
        uint256 tTeam = tAmount.mul(teamFee).div(10000);
        uint256 tRewards = tAmount.mul(rewardsFee).div(10000);
        uint256 tBuyback = tAmount.mul(buybackFee).div(10000);
        uint256 tDividend = tAmount.mul(dividendFee).div(10000);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity).sub(tBurn).sub(tMarketing).sub(tDevelopment).sub(tTeam).sub(tRewards).sub(tBuyback).sub(tDividend);
        return (tTransferAmount, tFee, tLiquidity, tBurn, tMarketing, tDevelopment, tTeam, tRewards, tBuyback, tDividend);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 tBurn,
        uint256 tMarketing,
        uint256 tDevelopment,
        uint256 tTeam,
        uint256 tRewards,
        uint256 tBuyback,
        uint256 tDividend,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rBurn = tBurn.mul(currentRate);
        uint256 rMarketing = tMarketing.mul(currentRate);
        uint256 rDevelopment = tDevelopment.mul(currentRate);
        uint256 rTeam = tTeam.mul(currentRate);
        uint256 rRewards = tRewards.mul(currentRate);
        uint256 rBuyback = tBuyback.mul(currentRate);
        uint256 rDividend = tDividend.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity).sub(rBurn).sub(rMarketing).sub(rDevelopment).sub(rTeam).sub(rRewards).sub(rBuyback).sub(rDividend);
        return (rAmount, rTransferAmount, rFee);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
        }
    }

    function _takeBurn(uint256 tBurn) private {
        uint256 currentRate = _getRate();
        uint256 rBurn = tBurn.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rBurn);
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tBurn);
        }
    }

    function _takeMarketing(uint256 tMarketing) private {
        uint256 currentRate = _getRate();
        uint256 rMarketing = tMarketing.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rMarketing);
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tMarketing);
        }
    }

    function _takeDevelopment(uint256 tDevelopment) private {
        uint256 currentRate = _getRate();
        uint256 rDevelopment = tDevelopment.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rDevelopment);
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tDevelopment);
        }
    }

    function _takeTeam(uint256 tTeam) private {
        uint256 currentRate = _getRate();
        uint256 rTeam = tTeam.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rTeam);
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tTeam);
        }
    }

    function _takeRewards(uint256 tRewards) private {
        uint256 currentRate = _getRate();
        uint256 rRewards = tRewards.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rRewards);
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tRewards);
        }
    }

    function _takeBuyback(uint256 tBuyback) private {
        uint256 currentRate = _getRate();
        uint256 rBuyback = tBuyback.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rBuyback);
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tBuyback);
        }
    }

    function _takeDividend(uint256 tDividend) private {
        uint256 currentRate = _getRate();
        uint256 rDividend = tDividend.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rDividend);
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tDividend);
        }
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if (from != owner() && to != owner()) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        if (contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }

        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    // this method is responsible for taking all fee, if takeFee is true
    
}