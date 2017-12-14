pragma solidity 0.4.18;

import "./ERC223BasicToken.sol";


contract ERC223Factory {
    address public owner;
    address public lastToken;

    modifier ownerOnly {
        require(msg.sender == owner);
        _;
    }

    function ERC223Factory() public {
        owner = msg.sender;
    }

    function newToken() public {
        ERC223BasicToken t = new ERC223BasicToken();
        lastToken = address(t);
    }

    /// The actual token creator is the owner of the factory,
    /// so we must allow to send tokens on behalf of factory creator
    function transfer(address to, address token, uint256 amount) public ownerOnly {
        ERC223BasicToken tokenContract = ERC223BasicToken(token);
        tokenContract.transfer(to, amount);
    }
}
