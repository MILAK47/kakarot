pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {PlainOpcodes} from "../src/PlainOpcodes/PlainOpcodes.sol";
import {ContractRevertsOnMethodCall, ContractWithSelfdestructMethod} from "../src/PlainOpcodes/RevertTestCases.sol";
import {Counter} from "../src/PlainOpcodes/Counter.sol";

contract PlainOpcodesTest is Test {
    PlainOpcodes plainOpcodes;
    Counter counter;

    function setUp() public {
        counter = new Counter();
        plainOpcodes = new PlainOpcodes(address(counter));
    }

    function testOpcodeExtCodeCopyReturnsCounterCode(uint256 offset, uint256 size) public {
        address target = address(counter);
        uint256 counterSize;
        assembly {
            counterSize := extcodesize(target)
        }
        vm.assume(size < counterSize + 1);
        vm.assume(offset < counterSize);
        bytes memory expectedResult;
        // see https://docs.soliditylang.org/en/v0.8.17/assembly.html#example
        assembly {
            counterSize := extcodesize(target)
            // get a free memory location to write result into
            expectedResult := mload(0x40)
            // update free memory pointer: write at 0x40 an empty memory address
            mstore(0x40, add(expectedResult, and(add(add(counterSize, 0x20), 0x1f), not(0x1f))))
            // store the size of the result at expectedResult
            // a bytes array stores its size in the first word
            mstore(expectedResult, counterSize)
            // actually copy the counter code from offset expectedResult + 0x20 (size location)
            extcodecopy(target, add(expectedResult, 0x20), 0, counterSize)
        }

        bytes memory bytecode = plainOpcodes.opcodeExtCodeCopy(0, counterSize);
        assertEq0(bytecode, expectedResult);
    }

    function testShouldRevertViaCall() public {
        ContractRevertsOnMethodCall doomedContract = new ContractRevertsOnMethodCall();

        (bool success, bytes memory returnData) =
            address(doomedContract).call(abi.encodeWithSignature("triggerRevert()"));

        assert(!success);
        assert(doomedContract.value() == 0);

        // slice the return data to remove the function selector and decode the revert reason
        bytes memory returnDataSlice = new bytes(returnData.length - 4);
        for (uint256 i = 4; i < returnData.length; i++) {
            returnDataSlice[i - 4] = returnData[i];
        }

        // decode the return data and check for the expected revert message
        (string memory errorMessage) = abi.decode(returnDataSlice, (string));
        assert(keccak256(bytes(errorMessage)) == keccak256("FAIL"));
    }

    function testSelfDestructAndCreateAgain() public {
        bytes memory bytecode = type(ContractWithSelfdestructMethod).creationCode;
        uint256 salt = 1234;
        address addr = plainOpcodes.create2(bytecode, salt);
        ContractWithSelfdestructMethod contract_ = ContractWithSelfdestructMethod(addr);
        contract_.inc();
        contract_.kill();
        plainOpcodes.create2(bytecode, salt);
        contract_.inc();
        uint256 count = contract_.count();
        assertEq(count, 2);
    }

    function testCreate() public {
        uint256 count = 4;
        address[] memory addresses = plainOpcodes.create(type(Counter).creationCode, count);
        assert(addresses.length == count);
        for (uint256 i = 0; i < count; i++) {
            console.logAddress(addresses[i]);
        }
    }

    function testSelfDestruct() public {
        (bool success,) = address(plainOpcodes).call{value: 0.1 ether}("");
        assert(success == true);

        uint256 contractBalanceBefore = address(plainOpcodes).balance;
        assert(contractBalanceBefore == 0.1 ether);
        uint256 callerBalanceBefore = address(this).balance;

        plainOpcodes.kill(payable(address(this)));

        uint256 contractBalanceAfter = address(plainOpcodes).balance;
        assert(contractBalanceAfter == 0);

        // Balance is transferred immediately
        uint256 callerBalanceAfter = address(this).balance;
        assert(callerBalanceAfter - callerBalanceBefore == 0.1 ether);

        // Account is still callable until the end of the tx
        uint256 value = plainOpcodes.loop(10);
        assert(value == 10);
    }

    function testStaticCallToInc() public view {
        (bool success,) = plainOpcodes.opcodeStaticCall2();
        assert(!success);
    }
}
