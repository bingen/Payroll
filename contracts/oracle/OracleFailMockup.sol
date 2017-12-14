pragma solidity 0.4.18;

import "./OracleInterface.sol";


contract OracleFailMockup is OracleInterface {
    uint256 public exchangeRate;

    event OracleLogQuery (address sender, address token);
    event OracleLogSetPayroll (address sender, address payroll);
    event OracleLogSetRate (address sender, address token, uint256 value);

    function query(address token, function(address, uint256) external callback) public returns(bool) {
        uint256 rate = 0;
        callback(token, rate);
        OracleLogQuery(msg.sender, token);
        return true;
    }
}
