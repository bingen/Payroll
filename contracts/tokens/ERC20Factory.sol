pragma solidity 0.4.18;

import "./SimpleERC20.sol";


// https://github.com/trufflesuite/truffle/issues/237#issuecomment-307609421
contract ERC20Factory {
    address public owner;
    address public lastToken;

    modifier ownerOnly {
        require(msg.sender == owner);
        _;
    }

    function ERC20Factory() public {
        owner = msg.sender;
    }

    function newToken() public {
        SimpleERC20 t = new SimpleERC20();
        lastToken = address(t);
    }

    /// The actual token creator is the owner of the factory,
    /// so we must allow it to approve token transactions
    function approve(address token, uint256 amount) public ownerOnly {
        SimpleERC20 tokenContract = SimpleERC20(token);
        tokenContract.approve(msg.sender, amount);
    }
}
