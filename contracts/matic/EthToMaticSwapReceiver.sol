pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../lib/tunnel/FxBaseChildTunnel.sol";

contract EthToMaticSwapReceiver is FxBaseChildTunnel {
    uint256 public latestStateId;
    address public latestRootMessageSender;
    bytes public latestData;
    address public dexRouter;
    bytes32 public constant SWAP_TOKENS = keccak256("SWAP_TOKENS");

    constructor(address _fxChild) FxBaseChildTunnel(_fxChild) {}

    function _processMessageFromRoot(
        uint256 stateId,
        address sender,
        bytes memory data
    ) internal override validateSender(sender) {
        latestStateId = stateId;
        latestRootMessageSender = sender;
        latestData = data;

        // decode incoming data
        (bytes32 messageType, bytes memory swapData) =
            abi.decode(data, (bytes32, bytes));

        if (messageType == SWAP_TOKENS) {
            _executeSwap(swapData);
        }
    }

    function _executeSwap(bytes memory swapData) internal {
        (
            address fromTokenOnEth,
            address toToken,
            uint256 amount,
            bytes memory dexSwapTxData
        ) = abi.decode(swapData, (address, address, uint256, bytes));
    }
}
