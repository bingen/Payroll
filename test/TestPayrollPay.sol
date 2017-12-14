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
    //uint public initialBalance = 10*10**18;

    address public target;
    bytes data;

    event Payed(address sender, uint256 value);

    function ThrowProxy(address _target) public {
        target = _target;
    }

    //prime the data using the fallback function.
    function payday() public {
        data = msg.data;
    }

    function() public payable {
        Payed(msg.sender, msg.value);
    }

    function execute() public returns (bool) {
        return target.call(data);
    }
}


contract TestPayrollPay {

    uint public initialBalance = 90*10**18;

    //SimpleERC20 erc20Token1;
    address[] tokens;
    uint256[] allocation;
    OracleMockup oracleGlobal;
    Payroll prGlobal;
    ThrowProxy throwProxyGlobal;

    /* Calling payday with a zero exchange rate */
    function testZeroRatePayday() public {
        bool r;

        OracleFailMockup oracle = OracleFailMockup(DeployedAddresses.OracleFailMockup());
        Payroll pr = new Payroll(oracle);
        //set Payroll as the contract to forward requests to. The target.
        ThrowProxy throwProxy = new ThrowProxy(address(pr));

        // throwProxy will be the actual caller, so we add it as employee
        address employee = address(throwProxy);
        pr.addEmployee(employee, tokens, 1200);

        // Add funds to be able to pay
        Assert.isAbove(pr.employer().balance, 50, "Not enough balance!");
        pr.addFunds.value(10*10**18).gas(200000)();
        throwProxy.transfer(10**18);
        Assert.isAbove(pr.balance, 9*10**18, "Not enough balance for PR!");
        Assert.isAbove(throwProxy.balance, 9*10**17, "Not enough balance for proxy!");

        Payroll(address(throwProxy)).payday();
        r = throwProxy.execute.gas(200000)();
        Assert.isFalse(r, "Should be false, as it should throw because payday is being called using a token with exchange rate value of zero");
    }

    /* Calling correct payday */
    function testCorrectPayday() public {
        bool r;

        oracleGlobal = OracleMockup(DeployedAddresses.OracleMockup());
        prGlobal = new Payroll(oracleGlobal);
        //set Payroll as the contract to forward requests to. The target.
        throwProxyGlobal = new ThrowProxy(address(prGlobal));

        // throwProxyGlobal will be the actual caller, so we add it as employee
        address employee = address(throwProxyGlobal);
        prGlobal.addEmployee(employee, tokens, 1200);

        // Add funds to be able to pay
        Assert.isAbove(prGlobal.employer().balance, 50, "Not enough balance!");
        prGlobal.addFunds.value(10*10**18).gas(200000)();
        throwProxyGlobal.transfer(10**18);
        Assert.isAbove(prGlobal.balance, 9*10**18, "Not enough balance for PR!");
        Assert.isAbove(throwProxyGlobal.balance, 9*10**17, "Not enough balance for proxy!");

        Payroll(address(throwProxyGlobal)).payday();
        r = throwProxyGlobal.execute.gas(200000)();
        Assert.isTrue(r, "Should be true");
    }

    /* Calling payday a second time */
    function testTimePayday() public {
        bool r;

        // A second time should fail because of time restriction
        Payroll(address(throwProxyGlobal)).payday();
        r = throwProxyGlobal.execute.gas(200000)();
        Assert.isFalse(r, "Should be false because of time restriction");
    }
}
