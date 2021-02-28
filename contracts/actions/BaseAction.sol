// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >0.7.0;
pragma experimental ABIEncoderV2;

import "../storage/BalanceHandler.sol";
import "../storage/PortfolioHandler.sol";
import "../storage/SettleAssets.sol";
import "../storage/StorageLayoutV1.sol";
import "../common/Market.sol";
import "../math/Bitmap.sol";

abstract contract BaseAction is StorageLayoutV1 {
    using BalanceHandler for BalanceState;
    using PortfolioHandler for PortfolioState;
    using Market for MarketParameters;
    using Bitmap for bytes;

    function _beforeAction(
        address account,
        uint newAssetsHint,
        uint blockTime
    ) private view returns (AccountStorage memory, PortfolioState memory) {
        // Storage Read
        AccountStorage memory accountContext = accountContextMapping[account];
        PortfolioState memory portfolioState;

        if (accountContext.nextMaturingAsset <= blockTime || newAssetsHint > 0) {
            // We only fetch the portfolio state if there will be new assets added or if the account
            // must be settled.
            portfolioState = PortfolioHandler.buildPortfolioState(account, newAssetsHint);
        }

        return (accountContext, portfolioState);
    }

    function _beforeActionView(
        address account,
        uint newAssetsHint,
        uint blockTime
    ) internal view returns (
        AccountStorage memory,
        PortfolioState memory,
        BalanceState[] memory
    ) {
        (
            AccountStorage memory accountContext,
            PortfolioState memory portfolioState
        ) = _beforeAction(account, newAssetsHint, blockTime);
        BalanceState[] memory balanceState;

        if (accountContext.nextMaturingAsset <= blockTime) {
            if (accountContext.bitmapCurrencyId != 0) {
                // TODO: For a view, read bitmap into portfolio state
            }

            // This means that settlement is required
            balanceState = SettleAssets.getSettleAssetContextView(
                account,
                portfolioState,
                accountContext,
                blockTime
            );

        }

        return (accountContext, portfolioState, balanceState);
    }

    function _beforeActionStateful(
        address account,
        uint newAssetsHint,
        uint blockTime
    ) internal returns (
        AccountStorage memory,
        PortfolioState memory,
        BalanceState[] memory
    ) {
        (
            AccountStorage memory accountContext,
            PortfolioState memory portfolioState
        ) = _beforeAction(account, newAssetsHint, blockTime);
        BalanceState[] memory balanceState;

        if (accountContext.nextMaturingAsset <= blockTime) {
            // This means that settlement is required
            balanceState = SettleAssets.getSettleAssetContextStateful(
                account,
                portfolioState,
                accountContext,
                blockTime
            );

            if (accountContext.bitmapCurrencyId != 0) {
                // TODO: settle bitmap
            }

        }

        return (accountContext, portfolioState, balanceState);
    }

    function _finalizeState(
        address account,
        AccountStorage memory accountContext,
        PortfolioState memory portfolioState,
        BalanceState[] memory balanceState,
        CashGroupParameters[] memory cashGroups,
        MarketParameters[][] memory marketStates,
        uint blockTime
    ) internal {
        // Finalize will set active currencies if balance is not zero
        for (uint i; i < balanceState.length; i++) {
            // TODO: add redeem to underlying
            balanceState[i].finalize(account, accountContext, false);
        }

        AssetStorage[] storage assetStoragePointer = assetArrayMapping[account];
        // Storing assets will set active currencies to true for each unique currency id. We know that there
        // won't be a conflict with balance state because settlement will create a balance for the active currency.
        // Deposit currency: set to true, no portfolio asset, no change
        // Withdraw to zero: set to false, has portfolio, set to true
        // Settle to cash: set to true, no portfolio asset, no change

        // Edge case:
        // Net portfolio asset to zero: must set to false if no balance and no other portfolio assets
        portfolioState.storeAssets(assetStoragePointer);

        // Finalizing markets will always update to the current settlement date.
        uint settlementDate = CashGroup.getReferenceTime(blockTime) + CashGroup.QUARTER;
        for (uint i; i < marketStates.length; i++) {
            for (uint j; j < marketStates[i].length; j++) {
                if (!marketStates[i][j].hasUpdated) continue;
                marketStates[i][j].setMarketStorage(settlementDate);
            }
        }

        accountContext = _finalizeView(
            account,
            accountContext,
            portfolioState,
            balanceState,
            cashGroups,
            marketStates,
            blockTime
        );

        accountContextMapping[account] = accountContext;
    }

    function _finalizeView(
        address account,
        AccountStorage memory accountContext,
        PortfolioState memory portfolioState,
        BalanceState[] memory balanceState,
        CashGroupParameters[] memory cashGroups,
        MarketParameters[][] memory marketStates,
        uint blockTime
    ) internal view virtual returns (AccountStorage memory) {
        // TODO: need to make sure all the context variables are set properly here
        return accountContext;
    }
}