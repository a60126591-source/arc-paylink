// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ArcPayLink} from "../src/ArcPayLink.sol";

contract ArcPayLinkTest {
    ArcPayLink private app;

    receive() external payable {}

    function setUp() public {
        app = new ArcPayLink();
    }

    function testCreateRequest() public {
        setUp();
        uint256 id = app.createRequest(payable(address(this)), 1 ether, "Design invoice", "Arc demo payment");
        require(id == 0, "wrong id");
        require(app.nextRequestId() == 1, "wrong next id");

        ArcPayLink.PaymentRequest memory request = app.getRequest(id);
        require(request.creator == address(this), "wrong creator");
        require(request.recipient == address(this), "wrong recipient");
        require(request.amount == 1 ether, "wrong amount");
        require(!request.paid, "unexpected paid state");
        require(!request.cancelled, "unexpected cancelled state");
    }

    function testCancelRequest() public {
        setUp();
        uint256 id = app.createRequest(payable(address(this)), 1 ether, "Cancelled invoice", "Test");
        app.cancelRequest(id);
        ArcPayLink.PaymentRequest memory request = app.getRequest(id);
        require(request.cancelled, "request not cancelled");
    }

    function testPayRequest() public {
        setUp();
        uint256 amount = 0.01 ether;
        uint256 id = app.createRequest(payable(address(this)), amount, "Test payment", "Native USDC demo");
        uint256 beforeBalance = address(this).balance;
        app.payRequest{value: amount}(id);
        ArcPayLink.PaymentRequest memory request = app.getRequest(id);
        require(request.paid, "request not paid");
        require(request.payer == address(this), "wrong payer");
        require(address(this).balance == beforeBalance, "recipient did not receive payment");
    }

    function testRejectIncorrectPayment() public {
        setUp();
        uint256 id = app.createRequest(payable(address(this)), 1 ether, "Exact payment", "Test");
        (bool success, ) = address(app).call{value: 0.5 ether}(
            abi.encodeWithSelector(app.payRequest.selector, id)
        );
        require(!success, "incorrect payment accepted");
    }
}
