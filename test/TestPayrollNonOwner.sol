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


contract TestPayrollNonOwner {

    /* Test Non-owner calls */
    function testNonOwnerCalling() public {
        bool r;
        address randomAddress = 0x960b236A07cf122663c4303350609A66A7B288C0;

        Payroll pr = Payroll(DeployedAddresses.Payroll());
        //set Payroll as the contract to forward requests to. The target.
        ThrowProxy throwProxy = new ThrowProxy(address(pr));

        /* setOracle */
        Payroll(address(throwProxy)).setOracle(randomAddress);
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-owner calling setOracle function");

        /* addEmployee */
        address[] memory tokens = new address[](1);
        Payroll(address(throwProxy)).addEmployee(randomAddress, tokens, 100000);
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-owner calling addEmployee function");

        /* addEmployeeWithName */
        Payroll(address(throwProxy)).addEmployeeWithName(randomAddress, tokens, 100000, "test");
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-owner calling addEmployeeWithName function");

        /* setEmployeeSalary */
        Payroll(address(throwProxy)).setEmployeeSalary(1, 120000);
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-owner calling setEmployeeSalary function");

        /* removeEmployee */
        Payroll(address(throwProxy)).removeEmployee(1);
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-owner calling  function");

        /* escapeHatch */
        Payroll(address(throwProxy)).escapeHatch();
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-owner calling escapeHatch function");

        /* getEmployeeCount */
        Payroll(address(throwProxy)).getEmployeeCount();
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-owner calling getEmployeeCount function");

        /* getEmployee */
        Payroll(address(throwProxy)).getEmployee(1);
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-owner calling getEmployee function");

        /* calculatePayrollBurnrate */
        Payroll(address(throwProxy)).calculatePayrollBurnrate();
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-owner calling calculatePayrollBurnrate function");

        /* calculatePayrollRunway */
        Payroll(address(throwProxy)).calculatePayrollRunway();
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-owner calling calculatePayrollRunway function");

        /* setOracle */
        Payroll(address(throwProxy)).setEurTokenAddress(randomAddress);
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because of non-owner calling setEurTokenAddress function");

    }

}
