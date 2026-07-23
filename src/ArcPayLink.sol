// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ArcPayLink
/// @notice Create and settle payment requests using Arc's native USDC gas token.
contract ArcPayLink {
    struct PaymentRequest {
        address creator;
        address payable recipient;
        uint256 amount;
        string title;
        string memo;
        bool paid;
        bool cancelled;
        address payer;
        uint256 createdAt;
        uint256 paidAt;
    }

    uint256 public nextRequestId;
    mapping(uint256 => PaymentRequest) private paymentRequests;
    uint256 private locked = 1;

    error InvalidRecipient();
    error InvalidAmount();
    error InvalidText();
    error RequestNotFound();
    error AlreadyPaid();
    error RequestCancelled();
    error Unauthorized();
    error IncorrectPayment();
    error TransferFailed();
    error Reentrancy();
    error DirectPaymentDisabled();

    event PaymentRequestCreated(
        uint256 indexed requestId,
        address indexed creator,
        address indexed recipient,
        uint256 amount,
        string title,
        string memo
    );

    event PaymentRequestPaid(
        uint256 indexed requestId,
        address indexed payer,
        address indexed recipient,
        uint256 amount,
        uint256 paidAt
    );

    event PaymentRequestCancelled(uint256 indexed requestId, address indexed creator);

    modifier nonReentrant() {
        if (locked != 1) revert Reentrancy();
        locked = 2;
        _;
        locked = 1;
    }

    function createRequest(
        address payable recipient,
        uint256 amount,
        string calldata title,
        string calldata memo
    ) external returns (uint256 requestId) {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
        if (bytes(title).length == 0 || bytes(title).length > 80) revert InvalidText();
        if (bytes(memo).length > 280) revert InvalidText();

        requestId = nextRequestId++;
        paymentRequests[requestId] = PaymentRequest({
            creator: msg.sender,
            recipient: recipient,
            amount: amount,
            title: title,
            memo: memo,
            paid: false,
            cancelled: false,
            payer: address(0),
            createdAt: block.timestamp,
            paidAt: 0
        });

        emit PaymentRequestCreated(requestId, msg.sender, recipient, amount, title, memo);
    }

    function payRequest(uint256 requestId) external payable nonReentrant {
        PaymentRequest storage request = _getRequest(requestId);
        if (request.paid) revert AlreadyPaid();
        if (request.cancelled) revert RequestCancelled();
        if (msg.value != request.amount) revert IncorrectPayment();

        request.paid = true;
        request.payer = msg.sender;
        request.paidAt = block.timestamp;

        (bool success, ) = request.recipient.call{value: msg.value}("");
        if (!success) revert TransferFailed();

        emit PaymentRequestPaid(
            requestId,
            msg.sender,
            request.recipient,
            request.amount,
            request.paidAt
        );
    }

    function cancelRequest(uint256 requestId) external {
        PaymentRequest storage request = _getRequest(requestId);
        if (msg.sender != request.creator) revert Unauthorized();
        if (request.paid) revert AlreadyPaid();
        if (request.cancelled) revert RequestCancelled();

        request.cancelled = true;
        emit PaymentRequestCancelled(requestId, msg.sender);
    }

    function getRequest(uint256 requestId) external view returns (PaymentRequest memory) {
        return _getRequest(requestId);
    }

    function _getRequest(uint256 requestId) internal view returns (PaymentRequest storage request) {
        if (requestId >= nextRequestId) revert RequestNotFound();
        request = paymentRequests[requestId];
    }

    receive() external payable {
        revert DirectPaymentDisabled();
    }

    fallback() external payable {
        revert DirectPaymentDisabled();
    }
}
