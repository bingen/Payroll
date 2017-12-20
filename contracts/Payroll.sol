pragma solidity 0.4.18;

import "./tokens/ERC20Interface.sol";
import "./tokens/ERC223Interface.sol";
import "./oracle/OracleInterface.sol";
import "./lib/SafeMath.sol";


/**
 * @title Payroll in multiple currencies
 * @notice For the sake of simplicity lets asume EUR is a ERC20 token
 * Also lets asume we can 100% trust the exchange rate oracle
 * It would simplify it to consider ETH an ERC20 token too,
 * like WETH.
 */
contract Payroll {
    using SafeMath for uint;

    struct Employee {
        address accountAddress; // unique, but can be changed over time
        mapping(address => bool) allowedTokens; // Could it be defined globally?
        address[] allowedTokensArray;
        mapping(address => uint256) allocation;
        uint256 yearlyEURSalary;
        uint lastAllocation;
        uint lastPayroll;
        string name;
    }

    uint private numEmployees;
    uint private nextEmployee;
    mapping(uint => Employee) private employees;
    mapping(address => uint) private employeeIds;
    uint256 private yearlyTotalPayroll;

    address public oracle;
    address public eurToken;
    mapping(address => uint256) private exchangeRates;

    address public employer;

    event LogFund (address sender, address token, uint amount, uint balance, bytes indexed data);
    event LogSendPayroll (address sender, address token, uint amount);
    event LogSetExchangeRate (address token, uint rate);

    // function access restrictions
    modifier ownerOnly {
        require(msg.sender == employer);
        _;
    }

    modifier employeeOnly {
        require(employeeIds[msg.sender] != 0);
        _;
    }

    modifier oracleOnly {
        require(msg.sender == oracle);
        _;
    }

    /**
     * @dev Constructor, create new Payroll
     * @notice Sets owner (employer) and oracle
     * @param oracleAddress Address of Oracle used to update Token exchange rates
     */
    function Payroll(address oracleAddress) public {
        employer = msg.sender;
        oracle = oracleAddress;
        numEmployees = 0;
        nextEmployee = 1; // leave 0 to check null address mapping
    }

    /* OWNER ONLY */
    /**
     * @dev Set Oracle address
     * @notice Set Oracle address
     * @param oracleAddress Address of Oracle used to update Token exchange rates
     */
    function setOracle(address oracleAddress) public ownerOnly {
        oracle = oracleAddress;
    }

    /**
     * @dev Add employee to Payroll
     * @notice It actually calls function addEmployeeWithName
     * @param accountAddress Employer's address to receive Payroll
     * @param allowedTokens Array of tokens allowed for payment
     * @param initialYearlyEURSalary Employee's salary
     */
    function addEmployee(
        address accountAddress,
        address[] allowedTokens,
        uint256 initialYearlyEURSalary
    )
        public
        ownerOnly
    {
        addEmployeeWithName(accountAddress, allowedTokens, initialYearlyEURSalary, "");
    }

    /**
     * @dev Add employee to Payroll
     * @notice Creates employee, adds it to mappings, initializes values
               and tries to update allowed tokens exchange rates if needed.
               Updates also global Payroll salary sum.
     * @param accountAddress Employer's address to receive Payroll
     * @param allowedTokens Array of tokens allowed for payment
     * @param initialYearlyEURSalary Employee's salary
     * @param name Employee's name
     */
    function addEmployeeWithName(
        address accountAddress,
        address[] allowedTokens,
        uint256 initialYearlyEURSalary,
        string name
    )
        public
        ownerOnly
    {
        // check that account doesn't exist
        require(employeeIds[accountAddress] == 0);

        var employeeId = nextEmployee;
        employees[employeeId] = Employee({
            accountAddress: accountAddress,
            allowedTokensArray: allowedTokens,
            yearlyEURSalary: initialYearlyEURSalary,
            lastAllocation: 0,
            lastPayroll: 0,
            name: name
        });
        // allowed Tokens
        for (uint i = 0; i < allowedTokens.length; i++) {
            employees[employeeId].allowedTokens[allowedTokens[i]] = true;
            // make sure we have exchange rate
            checkExchangeRate(allowedTokens[i]);
        }
        employees[employeeId].allowedTokensArray = allowedTokens;
        // add ETH, represented as address 0 to allowed tokens array
        employees[employeeId].allowedTokensArray.push(address(0));
        // default allocation (all ETH)
        employees[employeeId].allocation[address(0)] = 100;
        // Ids mapping
        employeeIds[accountAddress] = employeeId;
        // update global variables
        yearlyTotalPayroll = yearlyTotalPayroll.add(initialYearlyEURSalary);
        numEmployees++;
        nextEmployee++;
    }

    /**
     * @dev Set employee's annual salary
     * @notice Updates also global Payroll salary sum
     * @param employeeId Employee's identifier
     * @param yearlyEURSalary Employee's new salary
     */
    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) public ownerOnly {
        /* check that employee exist */
        if (employeeIds[employees[employeeId].accountAddress] == 0)
            return;

        yearlyTotalPayroll = yearlyTotalPayroll.sub(employees[employeeId].yearlyEURSalary);
        employees[employeeId].yearlyEURSalary = yearlyEURSalary;
        yearlyTotalPayroll = yearlyTotalPayroll.add(yearlyEURSalary);
    }

    /**
     * @dev Remove employee from Payroll
     * @notice Updates also global Payroll salary sum
     * @param employeeId Employee's identifier
     */
    function removeEmployee(uint256 employeeId) public ownerOnly {
        /* check that employee exist */
        if (employeeIds[employees[employeeId].accountAddress] == 0)
            return;

        yearlyTotalPayroll = yearlyTotalPayroll.sub(employees[employeeId].yearlyEURSalary);
        delete employeeIds[employees[employeeId].accountAddress];
        delete employees[employeeId];
        numEmployees--;
    }

    /**
     * @dev Payable function to receive ETH
     * @notice Payable function to receive ETH
     */
    function addFunds() public payable {
        LogFund(msg.sender, address(0), msg.value, this.balance, "");
    }

    /**
     * @dev Implement escape hatch mechanism. Avoids locked in contract forever
     * @notice Implement escape hatch mechanism. Avoids locked in contract forever
     */
    function escapeHatch() public ownerOnly {
        selfdestruct(employer); // send funds to organizer
    }

    /**
     * @dev To be able to receive ERC20 Token transfers, using approveAndCall
     *      See, e.g: https://www.ethereum.org/token
     * @notice To be able to receive ERC20 Token transfers, using approveAndCall
     * @param from  Token sender address.
     * @param value Amount of tokens.
     * @param token Token to be received.
     * @param data  Transaction metadata.
     */
    function receiveApproval(address from, uint256 value, address token, bytes data) public returns(bool success) {
        ERC20Interface tokenContract = ERC20Interface(token);
        LogFund(from, token, value, tokenContract.balanceOf(this), data);
        return tokenContract.transferFrom(from, this, value);
    }

    /**
     * @dev To be able to receive ERC233 Token transfers, using transfer
     *      See: https://github.com/ethereum/EIPs/issues/223
     * @notice To be able to receive ERC233 Token transfers, using transfer
     * @param from  Token sender address.
     * @param value Amount of tokens.
     * @param data  Transaction metadata.
     */
    function tokenFallback(address from, uint256 value, bytes data) public {
        ERC223Interface tokenContract = ERC223Interface(msg.sender);
        LogFund(from, msg.sender, value, tokenContract.balanceOf(this), data);
    }

    /**
     * @dev Get number of employees in Payroll
     * @notice Get number of employees in Payroll
     * @return Number of employees
     */
    function getEmployeeCount() public constant ownerOnly returns(uint256 count) {
        count = numEmployees;
    }

    /**
     * @dev Return all important info too through employees mapping
     * @notice Return all Employee's important info
     * @param employeeId Employee's identifier
     * @return Employee's address to receive payments
     * @return Employee's annual salary
     * @return Employee's name
     * @return Employee's allowed tokens
     * @return Employee's last call to payment distribution date
     * @return Employee's last payment received date
     */
    function getEmployee(uint256 employeeId)
        public
        constant
        ownerOnly
        returns(
            address accountAddress,
            uint256 yearlyEURSalary,
            string name,
            address[] allowedTokens,
            uint lastAllocation,
            uint lastPayroll
        )
    {
        var employee = employees[employeeId];

        accountAddress = employee.accountAddress;
        yearlyEURSalary = employee.yearlyEURSalary;
        name = employee.name;
        allowedTokens = employee.allowedTokensArray;
        lastAllocation = employee.lastAllocation;
        lastPayroll = employee.lastPayroll;
    }

    /**
     * @dev Get total amount of salaries in Payroll
     * @notice Get total amount of salaries in Payroll
     * @return Integer with the amount
     */
    function getYearlyTotalPayroll() public constant ownerOnly returns(uint256 total) {
        total = yearlyTotalPayroll;
    }

    /**
     * @dev Monthly EUR amount spent in salaries
     * @notice Monthly EUR amount spent in salaries
     * @return Integer with the monthly amount
     */
    function calculatePayrollBurnrate() public constant ownerOnly returns(uint256 payrollBurnrate) {
        payrollBurnrate = yearlyTotalPayroll / 12;
    }

    /**
     * @dev Days until the contract can run out of funds
     * @notice Days until the contract can run out of funds
     * @return Integer with the number of days
     */
    function calculatePayrollRunway() public constant ownerOnly returns(uint256 payrollRunway) {
        if (yearlyTotalPayroll == 0)
            payrollRunway = 2**256 - 1;
        else
            payrollRunway = this.balance.mul(365) / yearlyTotalPayroll;
    }

    /**
     * @dev Set EUR Token address
     * @notice EUR Token is a special one, so we can not allow its exchange rate to be changed
     * @param token EUR Token's address
     */
    function setEurTokenAddress(address token) public ownerOnly {
        eurToken = token;
        exchangeRates[token] = 100; // 2 decimals for cents
    }

    /* EMPLOYEE ONLY */
    /**
     * @dev Set token distribution for payments to an employee (the caller)
     * @notice Only callable once every 6 months
     * @param tokens Array with the tokens to receive, they must belong to allowed tokens for employee
     * @param distribution Array (correlated to tokens) with the proportions (integers over 100)
     */
    function determineAllocation(address[] tokens, uint256[] distribution) public employeeOnly {
        var employee = employees[employeeIds[msg.sender]];
        // solhint-disable-next-line not-rely-on-time
        require(now > employee.lastAllocation && now - employee.lastAllocation > 15768000); // half a year in seconds

        // check arrays match
        require(tokens.length == distribution.length);

        // check distribution is right
        uint256 sum = 0;
        uint256 i;
        for (i = 0; i < distribution.length; i++) {
            // check token is allowed
            require(employee.allowedTokens[tokens[i]]);
            // set distribution
            employee.allocation[tokens[i]] = distribution[i];
            sum = sum.add(distribution[i]);
        }
        require(sum <= 100);

        // remaining up to 100% is assumed to be ETH, which we'll represent as address 0
        employee.allocation[address(0)] = 100 - sum;

        // solhint-disable-next-line not-rely-on-time
        employee.lastAllocation = now;
    }

    /**
     * @dev Get payment proportion for a token and an employee (the caller)
     * @notice Get payment proportion for a token and an employee (the caller)
     * @param token The token address
     */
    function getAllocation(address token) public constant employeeOnly returns(uint256 allocation) {
        var employee = employees[employeeIds[msg.sender]];
        allocation = employee.allocation[token];
    }

    /**
     * @dev payday To withdraw monthly payment by employee (the caller)
     * @notice Only callable once a month. Assumed token has these standard checks implemented:
     *         https://theethereum.wiki/w/index.php/ERC20_Token_Standard#How_Does_A_Token_Contract_Work.3F
     */
    function payday() public employeeOnly {
        var employee = employees[employeeIds[msg.sender]];
        // solhint-disable-next-line not-rely-on-time
        require(now > employee.lastPayroll && now - employee.lastPayroll > 2628000); // 1/12 year in seconds

        // loop over allowed tokens
        for (uint i = 0; i < employee.allowedTokensArray.length; i++) {
            var token = employee.allowedTokensArray[i];
            if (employee.allocation[token] == 0)
                continue;
            require(checkExchangeRate(token));
            uint256 tokenAmount =
                employee.yearlyEURSalary.mul(employee.allocation[token]).mul(exchangeRates[token]) / 1200;
            if (token == address(0)) { // Send ETH
                msg.sender.transfer(tokenAmount);
            } else { // Send Tokens
                ERC20Interface tokenContract = ERC20Interface(token);
                tokenContract.transfer(msg.sender, tokenAmount);
            }
            LogSendPayroll(msg.sender, token, tokenAmount);
        }
        // finally update last payroll date
        // solhint-disable-next-line not-rely-on-time
        employee.lastPayroll = now;
    }

    /**
     * @dev Change employee account address. To be called by Employer (owner).
     * @notice Change employee account address
     * @param employeeId Employee's identifier
     * @param newAddress New address to receive payments
     */
    function changeAddressByOwner(uint256 employeeId, address newAddress) public ownerOnly {
        // check that account doesn't exist
        require(employeeIds[newAddress] == 0);

        employees[employeeId].accountAddress = newAddress;
        employeeIds[newAddress] = employeeId;
    }

    /**
     * @dev Change employee account address. To be called by Employee
     * @notice Change employee account address
     * @param newAddress New address to receive payments
     */
    function changeAddressByEmployee(address newAddress) public employeeOnly {
        // check that account doesn't exist
        require(employeeIds[newAddress] == 0);

        var employeeId = employeeIds[msg.sender];
        employees[employeeId].accountAddress = newAddress;
        employeeIds[newAddress] = employeeId;
    }

    /* ORACLE ONLY */
    /**
     * @dev Set the EUR exchange rate for a token. Uses decimals from token
     * @notice Sets the EUR exchange rate for a token
     * @param token The token address
     * @param eurExchangeRate The exchange rate
     */
    // solhint-disable-next-line func-order
    function setExchangeRate(address token, uint256 eurExchangeRate) external oracleOnly {
        if (token == address(0) || token != eurToken) {
            exchangeRates[token] = eurExchangeRate;
            LogSetExchangeRate(token, eurExchangeRate);
        }
    }

    /* Aux functions */
    /**
     * @dev Get the EUR exchange rate of a Token
     * @notice Get the EUR exchange rate of a Token
     * @param token The token address
     * @return eurExchangeRate The exchange rate
     */
    function getExchangeRate(address token) public constant returns(uint256 rate) {
        rate = exchangeRates[token];
    }

    /**
     * @dev Check that a token has the exchange rate already set
     *      Internal function, needed to ensure that we have the rate before making a payment.
     *      In case not, tries to retrieve it from Oracle
     * @param token The token address
     * @return True if we have the exchange rate, false otherwise
     */
    function checkExchangeRate(address token) private returns(bool) {
        if (exchangeRates[token] == 0) {
            OracleInterface oracleContract = OracleInterface(oracle);
            if (oracleContract.query(token, this.setExchangeRate)) {
                if (exchangeRates[token] > 0) {
                    return true;
                }
            }
            return false;
        }
        return true;
    }


}
