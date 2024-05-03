// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IACLManager} from '@aave/core-v3/contracts/interfaces/IACLManager.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {IGhoToken} from '../../gho/interfaces/IGhoToken.sol';
import {IGhoFacilitator} from '../../gho/interfaces/IGhoFacilitator.sol';
import {IGhoInterestMinter} from './interfaces/IGhoInterestMinter.sol';
import {IGhoAToken} from './interfaces/IGhoAToken.sol';

/**
 * @title GhoInterestMinter
 * @author Aave
 * @notice Contract that enables FlashMinting of GHO.
 * @dev Based heavily on the EIP3156 reference implementation
 */
contract GhoInterestMinter is IGhoInterestMinter {
  using PercentageMath for uint256;

  // @inheritdoc IGhoInterestMinter
  IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;

  // The Access Control List manager contract
  IACLManager private immutable ACL_MANAGER;

  // @inheritdoc IGhoInterestMinter
  IGhoToken public immutable GHO_TOKEN;

  // @inheritdoc IGhoAToken
  IGhoAToken public immutable GHO_ATOKEN;

  // @inheritdoc IGhoAToken
  IGhoToken public immutable GHO_VTOKEN;

  // The GHO treasury, the recipient of threshold distributions
  address private _ghoTreasury;

  // amount of GHO minted through this Facilitator
  uint256 public interestMinted = 0;

  // The flashmint fee, expressed in bps (a value of 10000 results in 100.00%)
  uint256 private _threshold;

  // @inheritdoc IGhoFlashMinter
  uint256 public constant MAX_THRESHOLD = 100_000 ether;

  /**
   * @dev Only pool admin can call functions marked by this modifier.
   */
  modifier onlyPoolAdmin() {
    require(ACL_MANAGER.isPoolAdmin(msg.sender), 'CALLER_NOT_POOL_ADMIN');
    _;
  }

  /**
   * @dev Constructor
   * @param ghoAToken The address of the GHO AToken contract
   * @param ghoTreasury The address of the GHO treasury
   * @param threshold The threshold to account for discounted rates in bps.
   * @param addressesProvider The address of the PoolAddressesProvider
   */
  constructor(
    address ghoAToken,
    address ghoTreasury,
    uint256 threshold,
    address addressesProvider
  ) {
    GHO_ATOKEN = IGhoAToken(ghoAToken);
    GHO_TOKEN = IGhoToken(GHO_ATOKEN.UNDERLYING_ASSET_ADDRESS());
    GHO_VTOKEN = IGhoToken(GHO_ATOKEN.getVariableDebtToken());

    _updateGhoTreasury(ghoTreasury);
    _updateThreshold(threshold);

    ADDRESSES_PROVIDER = IPoolAddressesProvider(addressesProvider);
    ACL_MANAGER = IACLManager(IPoolAddressesProvider(addressesProvider).getACLManager());
  }

  /// @inheritdoc IGhoFacilitator
  function distributeFeesToTreasury() external {
    GHO_ATOKEN.distributeFeesToTreasury();

    uint256 balance = GHO_TOKEN.balanceOf(address(this));
    uint256 debtSupply = GHO_VTOKEN.totalSupply();
    uint256 ghoSupply = GHO_TOKEN.totalSupply();

    if (debtSupply < ghoSupply + _threshold) {
      uint256 excessAmount = (ghoSupply + _threshold - debtSupply);
      uint256 amountToBurn = excessAmount < balance ? excessAmount : balance;

      require(interestMinted < amountToBurn, 'something very wrong is going on!');
      GHO_TOKEN.burn(amountToBurn);
      GHO_TOKEN.transfer(_ghoTreasury, balance - amountToBurn);
      emit InterestMintedUpdated(interestMinted, interestMinted - amountToBurn);
      interestMinted -= amountToBurn;
    } else {
      uint256 amountToMint = (debtSupply - ghoSupply - _threshold);
      GHO_TOKEN.mint(_ghoTreasury, amountToMint);
      GHO_TOKEN.transfer(_ghoTreasury, balance);
      emit InterestMintedUpdated(interestMinted, interestMinted + amountToMint);
      interestMinted += amountToMint;
    }
  }

  // @inheritdoc IGhoInterestMinter
  function updateThreshold(uint256 newThreshold) external override onlyPoolAdmin {
    _updateThreshold(newThreshold);
  }

  /// @inheritdoc IGhoFacilitator
  function updateGhoTreasury(address newGhoTreasury) external override onlyPoolAdmin {
    _updateGhoTreasury(newGhoTreasury);
  }

  /// @inheritdoc IGhoInterestMinter
  function getThreshold() external view override returns (uint256) {
    return _threshold;
  }

  /// @inheritdoc IGhoFacilitator
  function getGhoTreasury() external view override returns (address) {
    return _ghoTreasury;
  }

  function _updateThreshold(uint256 newThreshold) internal {
    require(newThreshold <= MAX_THRESHOLD, 'FlashMinter: Threshold out of range');
    uint256 oldThreshold = _threshold;
    _threshold = newThreshold;
    emit ThresholdUpdated(oldThreshold, newThreshold);
  }

  function _updateGhoTreasury(address newGhoTreasury) internal {
    address oldGhoTreasury = _ghoTreasury;
    _ghoTreasury = newGhoTreasury;
    emit GhoTreasuryUpdated(oldGhoTreasury, newGhoTreasury);
  }
}
