// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract Sonic is
    Context,
    Ownable,
    Pausable,
    ERC20,
    ERC20Burnable,
    ERC20Snapshot,
    ERC20Permit
{
    address public marketingAddress =
        0x000000000000000000000000000000000000dEaD;
    address public developmentAddress =
        0x000000000000000000000000000000000000dEaD;
    address public charityAddress = 0x000000000000000000000000000000000000dEaD;
    address public teamAddress = 0x000000000000000000000000000000000000dEaD;
    address public airdropAddress = 0x000000000000000000000000000000000000dEaD;
    address public stakingAddress = 0x000000000000000000000000000000000000dEaD;
    address public rewardsAddress = 0x000000000000000000000000000000000000dEaD;
    address public referralAddress = 0x000000000000000000000000000000000000dEaD;
    address public buybackAddress = 0x000000000000000000000000000000000000dEaD;
    address public dividendAddress = 0x000000000000000000000000000000000000dEaD;
    address public lotteryAddress = 0x000000000000000000000000000000000000dEaD;
    address public giveawayAddress = 0x000000000000000000000000000000000000dEaD;
    address public exchangeAddress = 0x000000000000000000000000000000000000dEaD;
    address public taxAddress = 0x000000000000000000000000000000000000dEaD;

    constructor() ERC20("Sonic", "SON") ERC20Permit("Sonic") {
        _mint(_msgSender(), 100000000000000000000000000000);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Snapshot) {
        require(
            amount >= 100000000000000000,
            "SONIC: Minimum transaction amount is 0.1 SON"
        );
        require(
            amount <= 1000000000000000000000,
            "SONIC: Maximum transaction amount is 1000 SON"
        );
        require(
            balanceOf(sender) >= 100000000000000000,
            "SONIC: Minimum wallet balance is 0.1 SON"
        );
        require(
            balanceOf(sender) >= 100000000000000000000000,
            "SONIC: Minimum wallet hold for rewards is 1000 SON"
        );
        require(
            balanceOf(sender) >= 100000000000000000000000,
            "SONIC: Minimum wallet hold for staking is 1000 SON"
        );
        require(
            balanceOf(sender) >= 100000000000000000000000,
            "SONIC: Minimum wallet hold for lottery is 1000 SON"
        );
        require(
            balanceOf(sender) >= 100000000000000000000000,
            "SONIC: Minimum wallet hold for giveaway is 1000 SON"
        );
        uint256 _amount = amount;
        uint256 _fee = _amount / 100;
        uint256 _transferAmount = _amount - _fee;
        super._transfer(sender, recipient, _transferAmount);
        super._transfer(sender, marketingAddress, _fee);
        super._transfer(sender, developmentAddress, _fee);
        super._transfer(sender, charityAddress, _fee);
        super._transfer(sender, teamAddress, _fee);
        super._transfer(sender, airdropAddress, _fee);
        super._transfer(sender, stakingAddress, _fee);
        super._transfer(sender, rewardsAddress, _fee);
        super._transfer(sender, referralAddress, _fee);
        super._transfer(sender, buybackAddress, _fee);
        super._transfer(sender, dividendAddress, _fee);
        super._transfer(sender, lotteryAddress, _fee);
        super._transfer(sender, giveawayAddress, _fee);
        super._transfer(sender, exchangeAddress, _fee);
        super._transfer(sender, taxAddress, _fee);
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setMarketingAddress(address _marketingAddress) public onlyOwner {
        marketingAddress = _marketingAddress;
    }

    function setDevelopmentAddress(address _developmentAddress)
        public
        onlyOwner
    {
        developmentAddress = _developmentAddress;
    }

    function setCharityAddress(address _charityAddress) public onlyOwner {
        charityAddress = _charityAddress;
    }

    function setTeamAddress(address _teamAddress) public onlyOwner {
        teamAddress = _teamAddress;
    }

    function setAirdropAddress(address _airdropAddress) public onlyOwner {
        airdropAddress = _airdropAddress;
    }

    function setStakingAddress(address _stakingAddress) public onlyOwner {
        stakingAddress = _stakingAddress;
    }

    function setRewardsAddress(address _rewardsAddress) public onlyOwner {
        rewardsAddress = _rewardsAddress;
    }

    function setReferralAddress(address _referralAddress) public onlyOwner {
        referralAddress = _referralAddress;
    }

    function setBuybackAddress(address _buybackAddress) public onlyOwner {
        buybackAddress = _buybackAddress;
    }

    function setDividendAddress(address _dividendAddress) public onlyOwner {
        dividendAddress = _dividendAddress;
    }

    function setLotteryAddress(address _lotteryAddress) public onlyOwner {
        lotteryAddress = _lotteryAddress;
    }

    function setGiveawayAddress(address _giveawayAddress) public onlyOwner {
        giveawayAddress = _giveawayAddress;
    }

    function setExchangeAddress(address _exchangeAddress) public onlyOwner {
        exchangeAddress = _exchangeAddress;
    }

    function setTaxAddress(address _taxAddress) public onlyOwner {
        taxAddress = _taxAddress;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) public onlyOwner {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        super.transferOwnership(newOwner);
    }

    function renounceOwnership() public override onlyOwner {
        super.renounceOwnership();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Snapshot, Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
