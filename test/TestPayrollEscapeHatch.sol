pragma solidity 0.4.18;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Payroll.sol";
import "../contracts/oracle/OracleMockup.sol";
import "../contracts/tokens/ERC20Factory.sol";


contract TestPayrollEscapeHatch {

    uint public initialBalance = 90*10**18;

    /* Destroy contract and check recovered funds */
    function testEscapeHatch() public {
        address employer;
        uint256 employerInitialBalance;
        uint256 employerFundedBalance;
        uint256 employerDestructedBalance;
        uint256 payrollInitialBalance;
        uint256 payrollFundedBalance;
        uint256 payrollDestructedBalance;
        uint256 funds = 10*10**18;

        OracleMockup oracle = OracleMockup(DeployedAddresses.OracleMockup());
        Payroll pr = new Payroll(oracle);

        employer = pr.employer();
        employerInitialBalance = employer.balance;
        payrollInitialBalance = pr.balance;
        // Add funds
        pr.addFunds.value(funds).gas(200000)();
        employerFundedBalance = employer.balance;
        payrollFundedBalance = pr.balance;
        Assert.equal(employerInitialBalance, employerFundedBalance + funds, "Not funded (Employer)!");
        Assert.equal(payrollInitialBalance + funds, payrollFundedBalance, "Not funded (Payroll)!");
        // Escape Hatch
        pr.escapeHatch();
        employerDestructedBalance = employer.balance;
        payrollDestructedBalance = pr.balance;
        Assert.equal(employerInitialBalance, employerDestructedBalance, "Funds not recovered (Employer)!");
        Assert.equal(payrollDestructedBalance, 0, "Funds not recovered (Payroll)!");
    }
}
