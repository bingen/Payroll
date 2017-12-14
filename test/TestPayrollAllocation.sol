pragma solidity 0.4.18;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Payroll.sol";
import "../contracts/oracle/OracleMockup.sol";
import "../contracts/oracle/OracleFailMockup.sol";
import "../contracts/tokens/ERC20Factory.sol";


// Proxy contract for testing throws
// http://truffleframework.com/tutorials/testing-for-throws-in-solidity-tests
contract ThrowProxy {
    address public target;
    bytes data;

    function ThrowProxy(address _target) public {
        target = _target;
    }

    //prime the data using the fallback function.
    function() public {
        data = msg.data;
    }

    function execute() public returns (bool) {
        return target.call(data);
    }
}


contract TestPayrollAllocation {

    SimpleERC20 erc20Token1;
    SimpleERC20 erc20Token2;
    address[] tokens;
    uint256[] allocation;
    OracleMockup oracle;
    Payroll pr;
    ThrowProxy throwProxy;

    function beforeAll() public {
        /* Set Tokens */
        erc20Token1 = new SimpleERC20();
        erc20Token2 = new SimpleERC20();
        tokens.push(address(erc20Token1));
        tokens.push(address(erc20Token2));
        oracle = OracleMockup(DeployedAddresses.OracleMockup());
        pr = new Payroll(oracle);
        //set Payroll as the contract to forward requests to. The target.
        throwProxy = new ThrowProxy(address(pr));

        // throwProxy will be the actual caller, so we add it as employee
        address employee = address(throwProxy);
        pr.addEmployee(employee, tokens, 100000);
    }

    /* Calling allocation with a sum greater than 100 */
    function testWrongAllocation() public {
        bool r;

        delete(allocation);
        allocation.push(60);
        allocation.push(50);
        Payroll(address(throwProxy)).determineAllocation(tokens, allocation);
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because determineAllocation is being called with a sum greater than 100");
    }

    /* Calling correct Allocation */
    function testCorrectAllocation() public {
        bool r;

        delete(allocation);
        allocation.push(60);
        allocation.push(40);
        Payroll(address(throwProxy)).determineAllocation(tokens, allocation);
        r = throwProxy.execute.gas(200000)();
        Assert.isTrue(r, "Should be true");
    }

    /* Calling Allocation again */
    function testTimeAllocation() public {
        bool r;

        delete(allocation);
        allocation.push(60);
        allocation.push(40);
        Payroll(address(throwProxy)).determineAllocation(tokens, allocation);
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, because of time condition");
    }

}
