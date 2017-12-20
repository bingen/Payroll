var Payroll = artifacts.require("./Payroll.sol");
var ERC20Factory = artifacts.require("./tokens/ERC20Factory.sol");
var SimpleERC20 = artifacts.require("./tokens/SimpleERC20.sol");
var ERC223Factory = artifacts.require("./tokens/ERC223Factory.sol");
var ERC223BasicToken = artifacts.require("./tokens/ERC223BasicToken.sol");
var OracleMockup = artifacts.require("./OracleMockup.sol");


contract('Payroll', function(accounts) {
  var payroll;
  var owner = accounts[0];
  var oracle = accounts[1];
  var employee1_1 = accounts[2];
  var employee1 = employee1_1;
  var employee2 = accounts[3];
  var employee1_2 = accounts[4];
  var employee1_3 = accounts[5];
  var total_salary = 0;
  var salary1_1 = 100000;
  var salary1_2 = 110000;
  var salary1 = salary1_1;
  var salary2_1 = 120000;
  var salary2_2 = 125000;
  var salary2 = salary2_1;
  var erc20Factory;
  var eurToken;
  var erc20Token1;
  var erc20Token2;
  var erc223Factory;
  var erc223Token1;
  var erc223Token2;
  var etherExchangeRate = web3.toWei(2500, 'szabo');;
  var erc20Token1ExchangeRate = web3.toWei(5, 'ether');
  var erc20Token2ExchangeRate = web3.toWei(300, 'finney');
  var erc223Token1ExchangeRate = web3.toWei(7, 'ether');

  it("Deploying contract, and setting oracle", function() {

    return Payroll.deployed().then(function(instance) {
      payroll = instance;
      //console.log(payroll.address);
      assert.isTrue(true);
    }).then(function() {
      return OracleMockup.deployed();
    }).then(function(instance) {
      oracle = instance;
      return payroll.setOracle(oracle.address);
    }).then(function() {
      return payroll.oracle.call();
    }).then( function(result) {
      assert.equal(result.valueOf(), oracle.address, "Oracle address is wrong!");
      // transfer ETH to Payroll contract
      for (i = 0; i < 10; i++)
        payroll.addFunds.sendTransaction({ from: accounts[i], to: payroll.address, value: web3.toWei(90, 'ether') });
    });
  });

  it("Initial values should match", function() {
    return Payroll.deployed().then(function(instance) {
      payroll = instance;
      return payroll.getEmployeeCount.call();
    }).then(function(numEmployees) {
      assert.equal(numEmployees.valueOf(), 0, "Num Employees doesn't match!");
    }).then(function() {
      return payroll.calculatePayrollBurnrate.call();
    }).then( function(total) {
      assert.equal(total.valueOf(), 0, "Initial total payroll should be zero!");
      return payroll.calculatePayrollRunway.call();
    }).then( function(total) {
      assert.equal(total.valueOf(), 1.15792089237316195423570985008687907853269984665640564039457584007913129639935e+77, "Initial payroll runway is wrong!");
      return payroll.oracle.call();
    }).then( function(result) {
      assert.equal(result.valueOf(), oracle.address, "Oracle address is wrong!");
    });
  });

  it("Deploying tokens", function() {
    var totalSupply;

    function deployErc20Token() {
      var token;
      return erc20Factory.newToken().then(function() {
        return erc20Factory.lastToken.call();
      }).then(function(instance) {
        token = SimpleERC20.at(instance);
        return token.totalSupply.call();
      }).then(function(value) {
        totalSupply = value;
        return erc20Factory.approve(token.address, totalSupply);
      }).then(function() {
        return token.transferFrom(erc20Factory.address, payroll.address, totalSupply);
      }).then(function() {
        return token;
      });
    }
    function deployErc223Token() {
      var token;
      return erc223Factory.newToken().then(function() {
        return erc223Factory.lastToken.call();
      }).then(function(instance) {
        token = ERC223BasicToken.at(instance);
        //console.log("Factory: " + erc223Factory.address);
        //console.log("Token: " + token.address);
        return token.balanceOf.call(erc223Factory.address);
      }).then(function(result) {
        return token.totalSupply.call();
      }).then(function(value) {
        totalSupply = value;
        return erc223Factory.transfer(payroll.address, token.address, totalSupply);
      }).then(function() {
        return token;
      });
    }
    function setAndCheckRate(token, exchangeRate, name='') {
      return oracle.setRate(token.address, exchangeRate).then(function() {
        return payroll.getExchangeRate(token.address);
      }).then(function(result) {
        assert.equal(result.toString(), exchangeRate.toString(), "Exchange rate for " + name + " doesn't match!");
      });
    }
    return Payroll.deployed().then(function(instance) {
      payroll = instance;
      // EUR Token
      return ERC20Factory.deployed();
    }).then(function(instance) {
      erc20Factory = instance;
      return deployErc20Token();
    }).then(function(result) {
      eurToken = result;
      //console.log("EUR Token: " + eurToken.address);
      return payroll.setEurTokenAddress(eurToken.address);
    }).then(function() {
      return payroll.eurToken.call();
    }).then(function(token) {
      assert.equal(token.valueOf(), eurToken.address, "EUR Token address is wrong");
      // ERC 20 Tokens
      return deployErc20Token();
    }).then(function(result) {
      erc20Token1 = result;
      return deployErc20Token();
    }).then(function(result) {
      erc20Token2 = result;
      // ERC 223 Tokens
      return ERC223Factory.deployed();
    }).then(function(instance) {
      erc223Factory = instance;
      return deployErc223Token();
    }).then(function(result) {
      erc223Token1 = result;
      return deployErc223Token();
    }).then(function(result) {
      erc223Token2 = result;
      // finally set exchange rates
      return oracle.setPayroll(payroll.address);
    }).then(function() {
      return oracle.setRate("0x0", etherExchangeRate);
    }).then(function() {
      return payroll.getExchangeRate("0x0");
    }).then(function(result) {
      assert.equal(result.toString(), etherExchangeRate.toString(), "Exchange rate for Ether doesn't match!");
      return oracle.setRate(eurToken.address, 999);
    }).then(function() {
      return payroll.getExchangeRate(eurToken.address);
    }).then(function(result) {
      // EUR Token rate should be always 100
      assert.equal(result.valueOf(), 100, "Exchange rate for EUR Token doesn't match!");
      return setAndCheckRate(erc20Token1, erc20Token1ExchangeRate, "ERC20 Token 1");
    }).then(function() {
      return setAndCheckRate(erc20Token2, erc20Token2ExchangeRate, "ERC 20 Token 2");
    }).then(function() {
      return setAndCheckRate(erc223Token1, erc223Token1ExchangeRate, "ERC 223 Token 1");
    }).then(function() {
      return payroll.getExchangeRate.call(erc223Token2.address);
    }).then(function(rate) {
      assert.equal(rate.valueOf(), 0, "Exchange rate for ERC 223 Token 2 doesn't match!");
    });
  });

  it("Add employee", function() {
    var name = '';
    var employeeId = 1;
    return Payroll.deployed().then(function(instance) {
      payroll = instance;
      return payroll.addEmployee(employee1_1, [eurToken.address, erc20Token1.address, erc20Token2.address, erc223Token1.address, erc223Token2.address], salary1_1);
    }).then(function() {
      salary1 = salary1_1;
      return payroll.getEmployeeCount.call();
    }).then(function(numEmployees) {
      assert.equal(numEmployees.valueOf(), employeeId, "Num Employees doesn't match!");
      return payroll.getEmployee.call(employeeId);
    }).then(function(employee) {
      //console.log(employee);
      assert.equal(employee[0], employee1_1, "Employee account doesn't match");
      assert.equal(employee[1], salary1_1, "Employee salary doesn't match");
      assert.equal(employee[2], name, "Employee name doesn't match");
    });
  });
  it("Add employee with name", function() {
    var name = 'Joe';
    var employeeId = 2;
    return Payroll.deployed().then(function(instance) {
      payroll = instance;
      return payroll.addEmployeeWithName(employee2, [eurToken.address, erc20Token1.address, erc223Token1.address], salary2_1, name);
    }).then(function() {
      salary2 = salary2_1;
      return payroll.getEmployeeCount.call();
    }).then(function(numEmployees) {
      assert.equal(numEmployees.valueOf(), employeeId, "Num Employees doesn't match!");
      return payroll.getEmployee.call(employeeId);
    }).then(function(employee) {
      assert.equal(employee[0], employee2, "Employee account doesn't match");
      assert.equal(employee[1], salary2_1, "Employee salary doesn't match");
      assert.equal(employee[2], name, "Employee name doesn't match");
    });
  });
  it("Remove employee", function() {
    var employeeId = 2;
    return Payroll.deployed().then(function(instance) {
      payroll = instance;
      return payroll.removeEmployee(employeeId);
    }).then(function() {
      salary2 = 0;
      return payroll.getEmployeeCount.call();
    }).then(function(numEmployees) {
      assert.equal(numEmployees.valueOf(), 1, "Num Employees doesn't match!");
    });
  });
  it("Add it again and check global payroll", function() {
    var name = 'John';
    var employeeId = 3;
    var balance;
    var yearlyTotalPayroll;
    return Payroll.deployed().then(function(instance) {
      payroll = instance;
      return payroll.addEmployeeWithName(employee2, [eurToken.address, erc20Token1.address, erc223Token1.address], salary2_2, name);
    }).then(function(transaction) {
      //console.log(transaction);
      return payroll.getEmployeeCount.call();
    }).then(function(numEmployees) {
      assert.equal(numEmployees.valueOf(), 2, "Num Employees doesn't match!");
      return payroll.getEmployee.call(employeeId);
    }).then(function(employee) {
      assert.equal(employee[0], employee2, "Employee account doesn't match");
      assert.equal(employee[1], salary2_2, "Employee salary doesn't match");
      assert.equal(employee[2], name, "Employee name doesn't match");
      return payroll.calculatePayrollBurnrate.call();
    }).then(function(burnrate) {
      salary2 = salary2_2;
      var expected_burnrate = Math.trunc((salary1 + salary2) / 12);
      assert.equal(burnrate.valueOf(), expected_burnrate, "Payroll burnrate doesn't match");
      return web3.eth.getBalance(payroll.address);
    }).then(function(result) {
      balance = result;
      return payroll.getYearlyTotalPayroll.call();
    }).then(function(result) {
      yearlyTotalPayroll = result;
      return payroll.calculatePayrollRunway.call();
    }).then(function(runway) {
      var runwayExpected = balance * 365 / yearlyTotalPayroll;
      assert.equal(runwayExpected.valueOf(), runway, "Payroll runway doesn't match!");
    });
  });
  it("Modify employee salary ", function() {
    var employeeId = 1;
    return Payroll.deployed().then(function(instance) {
      payroll = instance;
      return payroll.setEmployeeSalary(employeeId, salary1_2);
    }).then(function() {
      return payroll.calculatePayrollBurnrate.call();
    }).then(function(burnrate) {
      salary1 = salary1_2;
      var expected_burnrate = Math.trunc((salary1 + salary2) / 12);
      assert.equal(burnrate.valueOf(), expected_burnrate, "Payroll burnrate doesn't match");
    });
  });
  it("Modify employee account address by Employer ", function() {
    var employeeId = 1;
    return Payroll.deployed().then(function(instance) {
      payroll = instance;
      return payroll.changeAddressByOwner(employeeId, employee1_2);
    }).then(function() {
      return payroll.getEmployee.call(employeeId);
    }).then(function(employee) {
      assert.equal(employee[0], employee1_2, "Employee employee doesn't match");
      employee1 = employee1_2;
    });
  });
  it("Modify employee account address by Employee ", function() {
    var account_old = employee1_2;
    var account_new = employee1_3;
    var employeeId = 1;
    return Payroll.deployed().then(function(instance) {
      payroll = instance;
      return payroll.changeAddressByEmployee(account_new, {from: account_old});
    }).then(function() {
      return payroll.getEmployee.call(employeeId);
    }).then(function(employee) {
      assert.equal(employee[0], account_new, "Employee account doesn't match");
      employee1 = employee1_3;
    });
  });

  function logPayroll(initialBalancePayroll, initialBalanceEmployee, payed, newBalancePayroll, newBalanceEmployee, expectedPayroll, expectedEmployee, name='') {
    console.log("");
    console.log("Checking " + name);
    console.log("Initial " + name + " Payroll: " + web3.fromWei(initialBalancePayroll, 'ether'));
    console.log("Initial " + name + " Employee: " + web3.fromWei(initialBalanceEmployee, 'ether'));
    console.log("Payed: " + web3.fromWei(payed, 'ether'));
    console.log("new " + name + " payroll: " + web3.fromWei(newBalancePayroll, 'ether'));
    console.log("expected " + name + " payroll: " + web3.fromWei(expectedPayroll, 'ether'));
    console.log("New " + name + " employee: " + web3.fromWei(newBalanceEmployee, 'ether'));
    console.log("Expected " + name + " employee: " + web3.fromWei(expectedEmployee, 'ether'));
    console.log("");
  }
  it("Test payday, NO Token allocation", function() {
    var initialEthPayroll = web3.eth.getBalance(payroll.address);
    var initialEthEmployee1 = web3.eth.getBalance(employee1);
    return Payroll.deployed().then(function(instance) {
      payroll = instance;
      // call payday
      return payroll.payday({from: employee1});
    }).then(function(transaction) {
      //console.log(transaction);
      //console.log(web3.eth.gasPrice.toNumber());
      var tx = web3.eth.getTransaction(transaction.tx);
      var gasPrice = new web3.BigNumber(tx.gasPrice);
      var txFee = gasPrice.times(transaction.receipt.cumulativeGasUsed);
      //console.log("TxFee: " + web3.fromWei(txFee, 'ether'));
      var newEthPayroll = web3.eth.getBalance(payroll.address);
      var newEthEmployee1 = web3.eth.getBalance(employee1);
      var payed = (new web3.BigNumber(salary1)).times(etherExchangeRate).dividedToIntegerBy(12);
      var expectedPayroll = initialEthPayroll.minus(payed);
      var expectedEmployee1 = initialEthEmployee1.plus(payed).minus(txFee);
      //logPayroll(initialEthPayroll, initialEthEmployee1, payed, newEthPayroll, newEthEmployee1, expectedPayroll, expectedEmployee1, "ETH");
      assert.equal(newEthPayroll.toString(), expectedPayroll.toString(), "Payroll Eth Balance doesn't match");
      assert.equal(newEthEmployee1.toString(), expectedEmployee1.toString(), "Employee 1 Eth Balance doesn't match");
    });
  });

  it("Test payday, WITH Token allocation", function() {
    var eurTokenAllocation = 50;
    var erc20Token1Allocation = 20;
    var erc223Token1Allocation = 15;
    var ethAllocation = 100 - eurTokenAllocation - erc20Token1Allocation - erc223Token1Allocation;
    var initialEthPayroll;
    var initialEurTokenPayroll;
    var initialErc20Token1Payroll;
    var initialErc223Token1Payroll;
    var initialEthEmployee2;
    var initialEurTokenEmployee2;
    var initialErc20Token1Employee2;
    var initialErc223Token1Employee2;

    function setInitialBalances() {
      initialEthPayroll = web3.eth.getBalance(payroll.address);
      initialEthEmployee2 = web3.eth.getBalance(employee2);
      // Token initial balances
      return eurToken.balanceOf.call(payroll.address).then(function(result) {
        initialEurTokenPayroll = result;
        return erc20Token1.balanceOf.call(payroll.address);
      }).then(function(result) {
        initialErc20Token1Payroll = result;
        return erc223Token1.balanceOf.call(payroll.address);
      }).then(function(result) {
        initialErc223Token1Payroll = result;
        return eurToken.balanceOf.call(employee2);
      }).then(function(result) {
        initialEurTokenEmployee2 = result;
        return erc20Token1.balanceOf.call(employee2);
      }).then(function(result) {
        initialErc20Token1Employee2 = result;
        return erc223Token1.balanceOf.call(employee2);
      }).then(function(result) {
        initialErc223Token1Employee2 = result;
      });
    }
    function checkTokenBalances(token, salary, initialBalancePayroll, initialBalanceEmployee, exchangeRate, allocation, name='') {
      var payed = (new web3.BigNumber(salary)).times(exchangeRate).times(allocation).dividedToIntegerBy(1200);
      var expectedPayroll = initialBalancePayroll.minus(payed);
      var expectedEmployee = initialBalanceEmployee.plus(payed);
      var newBalancePayroll;
      var newBalanceEmployee;
      return token.balanceOf.call(payroll.address).then(function(result) {
        newBalancePayroll = result;
        return token.balanceOf.call(employee2);
      }).then(function(result) {
        newBalanceEmployee = result;
        //logPayroll(initialBalancePayroll, initialBalanceEmployee, payed, newBalancePayroll, newBalanceEmployee, expectedPayroll, expectedEmployee, name);
        assert.equal(newBalancePayroll.toString(), expectedPayroll.toString(), "Payroll balance of Token " + name + " doesn't match");
        assert.equal(newBalanceEmployee.toString(), expectedEmployee.toString(), "Employee balance of Token "+ name +" doesn't match");
      });
    }
    function checkPayday(transaction) {
      // Check ETH
      //console.log(transaction);
      //console.log(web3.eth.gasPrice.toNumber());
      var tx = web3.eth.getTransaction(transaction.tx);
      var gasPrice = new web3.BigNumber(tx.gasPrice);
      var txFee = gasPrice.times(transaction.receipt.cumulativeGasUsed);
      //console.log("TxFee: " + web3.fromWei(txFee, 'ether'));
      var newEthPayroll = web3.eth.getBalance(payroll.address);
      var newEthEmployee2 = web3.eth.getBalance(employee2);
      var payed = (new web3.BigNumber(salary2)).times(etherExchangeRate).times(ethAllocation).dividedToIntegerBy(1200);
      var expectedPayroll = initialEthPayroll.minus(payed);
      var expectedEmployee2 = initialEthEmployee2.plus(payed).minus(txFee);
      //logPayroll(initialEthPayroll, initialEthEmployee2, payed, newEthPayroll, newEthEmployee2, expectedPayroll, expectedEmployee2, "ETH");
      assert.equal(newEthPayroll.toString(), expectedPayroll.toString(), "Payroll Eth Balance doesn't match");
      assert.equal(newEthEmployee2.toString(), expectedEmployee2.toString(), "Employee Eth Balance doesn't match");
      // Check Tokens
      return checkTokenBalances(eurToken, salary2, initialEurTokenPayroll, initialEurTokenEmployee2, 100, eurTokenAllocation, "EUR").then(function(result) {
        return checkTokenBalances(erc20Token1, salary2, initialErc20Token1Payroll, initialErc20Token1Employee2, erc20Token1ExchangeRate, erc20Token1Allocation, "ERC20 1");
      }).then(function(result) {
        return checkTokenBalances(erc223Token1, salary2, initialErc223Token1Payroll, initialErc223Token1Employee2, erc223Token1ExchangeRate, erc223Token1Allocation, "ERC 223 1");
      });
    }
    return Payroll.deployed().then(function(instance) {
      payroll = instance;
      // determine allocation
      return payroll.determineAllocation([eurToken.address, erc20Token1.address, erc223Token1.address], [eurTokenAllocation, erc20Token1Allocation, erc223Token1Allocation], {from: employee2});
    }).then(function(transaction) {
      return setInitialBalances();
    }).then(function() {
      // call payday
      return payroll.payday({from: employee2});
    }).then(function(transaction) {
      return checkPayday(transaction);
    }).then(function(result) {
      // set time forward, 1 month
      var time = 31 * 24 * 3600;
      web3.currentProvider.send({jsonrpc: "2.0", method: "evm_increaseTime", params: [time], id: 0});
    }).then(function(result) {
      return setInitialBalances();
    }).then(function() {
      // call payday again
      return payroll.payday({from: employee2});
    }).then(function(transaction) {
      return checkPayday(transaction);
    }).then(function(result) {
      // set time forward, 5 more months
      var time = 5 * 31 * 24 * 3600;
      web3.currentProvider.send({jsonrpc: "2.0", method: "evm_increaseTime", params: [time], id: 0});
    }).then(function(result) {
      return payroll.determineAllocation([eurToken.address, erc20Token1.address, erc223Token1.address], [60, 15, 10], {from: employee2});
    }).then(function(result) {
      return payroll.getAllocation(eurToken.address, {from: employee2});
    }).then(function(result) {
      assert.equal(result.valueOf(), 60, "EUR allocation doesn't match");
      return payroll.getAllocation(erc20Token1.address, {from: employee2});
    }).then(function(result) {
      assert.equal(result.valueOf(), 15, "ERC 20 Token 1 allocation doesn't match");
      return payroll.getAllocation(erc223Token1.address, {from: employee2});
    }).then(function(result) {
      assert.equal(result.valueOf(), 10, "ERC 223 Token 1 allocation doesn't match");
    });
  });

});
