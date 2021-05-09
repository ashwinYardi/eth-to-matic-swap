pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../lib/tunnel/FxBaseRootTunnel.sol";
import "../interfaces/IERC20.sol";

// PoS Bridge - Root Chain Manager
interface IRootChainManager {
    function depositEtherFor(address user) external payable;

    function depositFor(
        address user,
        address rootToken,
        bytes calldata depositData
    ) external;

    function tokenToType(address) external returns (bytes32);

    function typeToPredicate(bytes32) external returns (address);
}

// Plasma Bridge
interface IDepositManager {
    function depositERC20ForUser(
        address _token,
        address _user,
        uint256 _amount
    ) external;
}

contract EthToMaticSwap is FxBaseRootTunnel {
    IRootChainManager public rootChainManager;
    IDepositManager public depositManager;

    bytes32 public constant SWAP_TOKENS = keccak256("SWAP_TOKENS");

    address private constant maticAddress =
        0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0;

    constructor(
        address _rootChainManager,
        address _depositManager,
        address _checkpointManager,
        address _fxRoot
    ) FxBaseRootTunnel(_checkpointManager, _fxRoot) {
        rootChainManager = IRootChainManager(_rootChainManager);
        depositManager = IDepositManager(_depositManager);
        IERC20(maticAddress).approve(address(depositManager), uint256(-1));
    }

    function executeCrossChainSwap(
        address fromToken,
        address toTokenOnMatic,
        uint256 fromAmount,
        bytes memory polydexSwapData
    ) public payable returns (bool) {
        _pullTokens(fromToken, fromAmount);

        // First send the tokens
        if (msg.value > 0) {
            _bridgeMatic(fromAmount);
        } else {
            _bridgeToken(fromToken, fromAmount);
        }

        // Now, send the swap Data
        bytes memory message =
            abi.encode(
                SWAP_TOKENS,
                abi.encode(
                    fromToken,
                    toTokenOnMatic,
                    fromAmount,
                    polydexSwapData
                )
            );

        _sendMessageToChild(message);
    }

    function _pullTokens(address fromToken, uint256 fromAmount) internal {
        if (fromToken == address(0)) {
            require(msg.value > 0, "No eth sent");
            require(fromAmount == msg.value, "msg.value != fromAmount");
        } else {
            require(msg.value == 0, "Eth sent with token");

            // transfer token
            IERC20(fromToken).transferFrom(
                msg.sender,
                address(this),
                fromAmount
            );
        }
    }

    function _bridgeToken(address toToken, uint256 toTokenAmt) internal {
        if (toToken == address(0)) {
            rootChainManager.depositEtherFor{value: toTokenAmt}(msg.sender);
        } else {
            bytes32 tokenType = rootChainManager.tokenToType(toToken);
            address predicate = rootChainManager.typeToPredicate(tokenType);
            _approveToken(toToken, predicate);
            rootChainManager.depositFor(
                msg.sender,
                toToken,
                abi.encode(toTokenAmt)
            );
        }
    }

    function _bridgeMatic(uint256 maticAmount) internal {
        depositManager.depositERC20ForUser(
            maticAddress,
            msg.sender,
            maticAmount
        );
    }

    function _approveToken(address token, address spender) internal {
        IERC20 _token = IERC20(token);
        if (_token.allowance(address(this), spender) > 0) return;
        else {
            _token.approve(spender, uint256(-1));
        }
    }

    function _processMessageFromChild(bytes memory data) internal override {}
}
