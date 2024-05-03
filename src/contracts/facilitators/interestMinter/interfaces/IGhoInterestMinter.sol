// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IGhoFacilitator} from '../../../gho/interfaces/IGhoFacilitator.sol';
import {IGhoToken} from '../../../gho/interfaces/IGhoToken.sol';

/**
 * @title IGhoInterestMinter
 * @author Aave
 * @notice Defines the behavior of the GHO Flash Minter
 */
interface IGhoInterestMinter is IGhoFacilitator {
  /**
   * @dev Emitted when the percentage threshold is updated
   * @param oldThreshold The old threshold (in bps)
   * @param newThreshold The new threshold (in bps)
   */
  event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

  /**
   * @dev Emitted when a FlashMint occurs
   * @param oldAmount The previous GHO amount Minted through this facilitator
   * @param newAmount The new gho amount Minted through this facilitator
   */
  event InterestMintedUpdated(uint256 indexed oldAmount, uint256 indexed newAmount);

  /**
   * @notice Returns the maximum value the threshold can be set to
   * @return The maximum percentage threshold of the flash-minted amount that the flashThreshold can be set to (in bps).
   */
  function MAX_THRESHOLD() external view returns (uint256);

  /**
   * @notice Returns the address of the Aave Pool Addresses Provider contract
   * @return The address of the PoolAddressesProvider
   */
  function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

  /**
   * @notice Returns the address of the GHO token contract
   * @return The address of the GhoToken
   */
  function GHO_TOKEN() external view returns (IGhoToken);

  /**
   * @notice Updates the percentage threshold. It is the percentage of the flash-minted amount that needs to be repaid.
   * @dev The threshold is expressed in bps. A value of 100, results in 1.00%
   * @param newThreshold The new percentage threshold (in bps)
   */
  function updateThreshold(uint256 newThreshold) external;

  /**
   * @notice Returns the percentage of each flash mint taken as a threshold
   * @return The percentage threshold of the flash-minted amount that needs to be repaid, on top of the principal (in bps).
   */
  function getThreshold() external view returns (uint256);
}
