pragma solidity 0.4.18;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Payroll.sol";


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


contract TestPayroll {

    /* Test Constructor */
    function testConstructor() public {
        address oracle = 0x960b236A07cf122663c4303350609A66A7B288C0;
        Payroll pr = new Payroll(oracle);
        Assert.equal(pr.oracle(), oracle, "Should be equal");
    }

    /* Test Non-employee calls */
    function testNonEmployeeCalling() public {
        bool r;

        Payroll pr = Payroll(DeployedAddresses.Payroll());
        //set Payroll as the contract to forward requests to. The target.
        ThrowProxy throwProxy = new ThrowProxy(address(pr));

        /* determineAllocation */
        address[] memory tokens = new address[](1);
        uint256[] memory distribution = new uint256[](1);
        Payroll(address(throwProxy)).determineAllocation(tokens, distribution);
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-employee calling determineAllocation function");

        /* payday */
        Payroll(address(throwProxy)).payday();
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-employee calling payday function");

        /* changeAddressByEmployee */
        Payroll(address(throwProxy)).changeAddressByEmployee(0x0);
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-employee calling changeAddressByEmployee function");
    }

    /* Test Non-oracle calls */
    function testNonOracleCalling() public {
        bool r;

        Payroll pr = Payroll(DeployedAddresses.Payroll());
        //set Payroll as the contract to forward requests to. The target.
        ThrowProxy throwProxy = new ThrowProxy(address(pr));

        /* setExchangeRate */
        Payroll(address(throwProxy)).setExchangeRate(0x0, 1);
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-oracle calling setExchangeRate function");
    }

}
