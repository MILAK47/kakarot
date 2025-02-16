import pytest
import pytest_asyncio

from tests.utils.constants import ACCOUNT_BALANCE


@pytest_asyncio.fixture(scope="package")
async def safe(deploy_solidity_contract, owner):
    return await deploy_solidity_contract(
        "PlainOpcodes", "Safe", caller_eoa=owner.starknet_contract
    )


@pytest.mark.asyncio
@pytest.mark.Safe
class TestSafe:
    class TestReceive:
        async def test_should_receive_eth(self, safe, owner):
            balance_before = await safe.balance()
            await safe.deposit(value=ACCOUNT_BALANCE, caller_eoa=owner)
            balance_after = await safe.balance()
            assert balance_after - balance_before == ACCOUNT_BALANCE

    class TestWithdrawTransfer:
        async def test_should_withdraw_transfer_eth(self, safe, owner, eth_balance_of):
            await safe.deposit(value=ACCOUNT_BALANCE, caller_eoa=owner)

            safe_balance = await safe.balance()
            owner_balance_before = await eth_balance_of(owner.address)

            receipt = await safe.withdrawTransfer(caller_eoa=owner)

            owner_balance_after = await eth_balance_of(owner.address)
            assert await safe.balance() == 0
            assert (
                owner_balance_after - owner_balance_before
                == safe_balance - receipt.actual_fee
            )

    class TestWithdrawCall:
        async def test_should_withdraw_call_eth(self, safe, owner, eth_balance_of):
            await safe.deposit(value=ACCOUNT_BALANCE, caller_eoa=owner)

            safe_balance = await safe.balance()
            owner_balance_before = await eth_balance_of(owner.address)

            receipt = await safe.withdrawCall(caller_eoa=owner)

            owner_balance_after = await eth_balance_of(owner.address)
            assert await safe.balance() == 0
            assert (
                owner_balance_after - owner_balance_before
                == safe_balance - receipt.actual_fee
            )

    class TestDeploySafeWithValue:
        async def test_deploy_safe_with_value(
            self, safe, deploy_solidity_contract, owner
        ):
            safe = await deploy_solidity_contract(
                "PlainOpcodes", "Safe", caller_eoa=owner.starknet_contract, value=1
            )
            assert await safe.balance() == 1
