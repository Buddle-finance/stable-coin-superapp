// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    ContextDefinitions,
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    CFAv1Library
} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

// NOTE: Change version in file "@uniswap/swap-router-contracts/contracts/interfaces/IApproveAndCall.sol" to >=0.7.6
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";

abstract contract RedirectTokens is SuperAppBase, Ownable {

    using CFAv1Library for CFAv1Library.InitData;
    
    CFAv1Library.InitData public cfaV1;
    ISuperfluid private _host; // host
    ISuperToken private token1; // accepted token
    ISuperToken private token2; // accepted token
    IConstantFlowAgreementV1 cfa;
    int96 public fees_basis_points;
    ISwapRouter02 public swapRouter;
    uint256 poolFees;
    uint256 maxSlippage;

    constructor(
        ISuperfluid host,
        IConstantFlowAgreementV1 _cfa,
        ISuperToken _token1,
        ISuperToken _token2,
        ISwapRouter02 _swapRouter,
        uint256 _poolFees,
        uint256 _maxSlippage
    ) {
        require(address(host) != address(0), "host is zero address");
        require(address(_token1) != address(0), "token1 is zero address");
        require(address(_token2) != address(0), "token2 is zero address");
        require(address(_swapRouter) != address(0), "swap router is zero address");

        _host = host;
        fees_basis_points = 10;
        // initialize InitData struct, and set equal to cfaV1
        cfaV1 = CFAv1Library.InitData(
            host,
            //here, we are deriving the address of the CFA using the host contract
            IConstantFlowAgreementV1(
                address(host.getAgreementClass(
                    keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1")
                ))
            )
        );

        cfa = _cfa;
        token1 = _token1;
        token2 = _token2;
        swapRouter = _swapRouter;
        poolFees = _poolFees;
        maxSlippage = _maxSlippage;

        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);
    }


    modifier onlyHost() {
        require(msg.sender == address(_host), "RedirectAll: support only one host");
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isAcceptedToken(superToken), "RedirectAll: not accepted token");
        require(_isCFAv1(agreementClass), "RedirectAll: only CFAv1 supported");
        _;
    }
    
    function getRatio(uint256 numerator, uint256 denominator) internal pure returns (uint256) {
        uint _quotient = ((((numerator * (10 ** (18 + 1))) / denominator) + 5) / 10);
        return _quotient;
    }

    function safeCastToInt96(uint256 _value) internal pure returns (int96) {
        if (_value > (2 ** 96) - 1) {
            return int96(0);
        }
        return int96(int(_value));
    }

    // /* App Functions */
    function changeFeeBasisPoints(int96 _fees_basis_points) public onlyOwner {
        require(_fees_basis_points > 0, "RedirectAll: fees_basis_points must be greater than 0");
        fees_basis_points = _fees_basis_points;
    }

    function changePoolFees(uint256 _poolFees, uint256 _maxSlippage) public onlyOwner {
        poolFees = _poolFees;
        maxSlippage = _maxSlippage;
    }

    function rebalanceTokens() external {
        uint256 token1Balance = token1.balanceOf(address(this));
        uint256 token2Balance = token2.balanceOf(address(this));
        uint256 swapAmount;
        uint256 amountOutMin;
        bytes memory encodedPath;

        if (token1Balance == token2Balance) {
            return;
        }

        if (token1Balance > token2Balance)
        {
            swapAmount = token1Balance - token2Balance;
            TransferHelper.safeApprove(address(token1), address(swapRouter), swapAmount);
            encodedPath = abi.encodePacked(address(token1), poolFees, address(token2));
        } else {
            swapAmount = token2Balance - token1Balance;
            TransferHelper.safeApprove(address(token2), address(swapRouter), swapAmount);
            encodedPath = abi.encodePacked(address(token2), poolFees, address(token1));
        }

        amountOutMin = swapAmount * (10000 - maxSlippage) / 10000;

        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter
        .ExactInputParams({
            path: encodedPath,
            recipient: address(this),
            amountIn: swapAmount,
            amountOutMinimum: amountOutMin
        });

        // TODO: emit the swap amount
        swapRouter.exactInput(params);
    }

    // Create function to percent difference from token1 to token2 to calculate fees
    function calculateFlowToken1(int96 _flowRate) view public returns (int96) {
        uint256 flowRate = uint256(int(_flowRate));

        uint256 token1Balance = token1.balanceOf(address(this));
        uint256 token2Balance = token2.balanceOf(address(this));

        if (token1Balance == token2Balance) {
            return _flowRate;
        }

        bool isToken1Greater = token1.balanceOf(address(this)) > token2.balanceOf(address(this));
        uint ratio = isToken1Greater ? 
                        getRatio(token2Balance, token1Balance) : 
                        getRatio(token1Balance, token2Balance);

        return isToken1Greater ? 
                safeCastToInt96((ratio * flowRate) / 10 ** 18) :
                safeCastToInt96((2 * flowRate) - (ratio * flowRate) / 10 ** 18);
    }

    function calculateFlowToken2(int96 _flowRate) view public returns (int96) {
        uint256 flowRate = uint256(int(_flowRate));

        uint256 token1Balance = token1.balanceOf(address(this));
        uint256 token2Balance = token2.balanceOf(address(this));

        if (token1Balance == token2Balance) {
            return _flowRate;
        }

        bool isToken2Greater = token1.balanceOf(address(this)) < token2.balanceOf(address(this));
        uint ratio = isToken2Greater ? 
                        getRatio(token1Balance, token2Balance) : 
                        getRatio(token2Balance, token1Balance);

        return isToken2Greater ? 
                safeCastToInt96((2 * flowRate) - (ratio * flowRate) / 10 ** 18) :
                safeCastToInt96((ratio * flowRate) / 10 ** 18);
    }


    function _getShareholderInfo(bytes calldata _agreementData, ISuperToken _superToken)
        internal
        view
        returns (address _shareholder, int96 _flowRate, uint256 _timestamp)
    {
        (_shareholder, ) = abi.decode(_agreementData, (address, address));
        (_timestamp, _flowRate, , ) = cfa.getFlow(
            _superToken,
            _shareholder,
            address(this)
        );
    }

    /**************************************************************************
     * SuperApp callbacks
     *************************************************************************/

    function afterAgreementCreated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata _agreementData,
        bytes calldata ,// _cbdata,
        bytes calldata _ctx
    )
        external override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        // According to the app basic law, we should never revert in a termination callback
        if (!_isAcceptedToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;

        (address _shareholder, ) = abi.decode(_agreementData, (address, address));
        (, int96 _flowRate, , ) = cfa.getFlow(
            _superToken,
            _shareholder,
            address(this)
        );

        bool isToken1 = _superToken == token1;
        return cfaV1.createFlowWithCtx(
            _ctx, 
            _shareholder, 
            isToken1 ? token2 : token1, 
            _flowRate * (10000 - fees_basis_points) / 10000,
            "0x"
        );

    }

    function afterAgreementUpdated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 ,//_agreementId,
        bytes calldata _agreementData,
        bytes calldata ,//_cbdata,
        bytes calldata _ctx
    )
        external override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        // According to the app basic law, we should never revert in a termination callback
        if (!_isAcceptedToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;

        (address _shareholder, ) = abi.decode(_agreementData, (address, address));
        (, int96 _flowRate, , ) = cfa.getFlow(
            _superToken,
            _shareholder,
            address(this)
        );

        bool isToken1 = _superToken == token1;
        return cfaV1.updateFlowWithCtx(
            _ctx,
            _shareholder,
            isToken1 ? token2 : token1,
            _flowRate * (10000 - fees_basis_points) / 10000, // TODO: Ask Nik - subtract 0.1% from the flow rate to avoid rounding errors
            "0x"
        );
    }

    function afterAgreementTerminated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 ,//_agreementId,
        bytes calldata _agreementData,
        bytes calldata ,//_cbdata,
        bytes calldata _ctx
    )
        external override
        onlyHost
        returns (bytes memory newCtx)
    {
        // According to the app basic law, we should never revert in a termination callback
        if (!_isAcceptedToken(_superToken) || !_isCFAv1(_agreementClass)) return _ctx;
        
        (address _shareholder,, ) = _getShareholderInfo(
            _agreementData, _superToken
        );

        bool isToken1 = _superToken == token1;
        return cfaV1.deleteFlowWithCtx(
            _ctx,
            address(this),
            _shareholder,
            isToken1 ? token2 : token1
        );
    }

    function _isAcceptedToken(ISuperToken superToken) private view returns (bool) {
        return (address(superToken) == address(token1) || address(superToken) == address(token2));
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType()
            == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }
}

