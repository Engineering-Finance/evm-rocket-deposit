# nvm use 14
# brownie test tests/rocket.py -s --interactive
from multiprocessing.context import assert_spawning
from os import access
import pytest
from brownie import *
from brownie import reverts
import time

ZERO_ADDRESS = '0x' + '0' * 40
UNIT = 10**18


@pytest.fixture
def sybil():
    print("deploy mock Sybil")
    return accounts[0].deploy(MockSybil)


@pytest.fixture
def voodoo():
    print("deploy mock Voodoo")
    return accounts[0].deploy(MockERC20, "Voodoo", "VOO", 18, 1000*UNIT)


@pytest.fixture
def busd():
    print("deploy mock Busd")
    return accounts[0].deploy(MockERC20, "Binance USD", "BUSD", 18, 1000*UNIT)


@pytest.fixture
def strategy():
    print("deploy mock Strategy")
    return accounts[0].deploy(MockStrategy)


def test_rocket(sybil, voodoo, busd, strategy):
    assert(sybil.address != ZERO_ADDRESS)

    # make sure voodoo was deployed and that we have voodoo
    assert(voodoo.address != ZERO_ADDRESS)
    assert(voodoo.balanceOf(accounts[0]) == 1000*UNIT)

    # make sure busd was deployed and that we have busd
    assert(busd.address != ZERO_ADDRESS)
    assert(busd.balanceOf(accounts[0]) == 1000*UNIT)

    assert(strategy.address != ZERO_ADDRESS)

    treasury = accounts[1]
    print("treasury", treasury)

    # test Bonds constuction
    print("deploy Rocket Deposit")
    bonds = accounts[0].deploy(RocketDeposit, voodoo.address, sybil.address, strategy.address, treasury.address)
    assert(bonds.address != ZERO_ADDRESS)

    # we need to allow the bonds contract to spend Voodoo & BUSD on our behalf
    print("approve bonds to spend voodoo")
    voodoo.approve(bonds.address, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
    busd.approve(bonds.address, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)

    # allocate 100 Voodoo tokens to the bonds contract on BUSD market
    print("allocate 100 Voodoo tokens to the bonds contract on BUSD market")
    bonds.allocate(busd.address, 100*UNIT, {'from': accounts[0]})
    # make sure allocations are correct
    assert(bonds.allocations(busd.address) == 100*UNIT)
    # make sure the bond contract has 100 Voodoo
    assert(voodoo.balanceOf(bonds.address) == 100*UNIT)

    # deallocate 100 Voodoo tokens from the bonds contract on BUSD market
    print("deallocate 100 Voodoo tokens from the bonds contract on BUSD market")
    bonds.deallocate(busd.address, 100*UNIT, {'from': accounts[0]})
    # make sure allocations are correct
    assert(bonds.allocations(busd.address) == 0)
    # make sure the bond contract has 0 Voodoo
    assert(voodoo.balanceOf(bonds.address) == 0)
    # make sure we have 1000 Voodoo again
    assert(voodoo.balanceOf(accounts[0]) == 1000*UNIT)

    # allocate 100 Voodoo tokens to the bonds contract on BUSD market
    print("allocate 100 Voodoo tokens to the bonds contract on BUSD market again")
    bonds.allocate(busd.address, 100*UNIT, {'from': accounts[0]})

    # make sure we have 100 Voodoo allocation balance
    assert(bonds.allocationBalance(busd.address) == 100*UNIT)

    # make sure bond strategy returns 0.9 multiplier
    (mul, div) = strategy.discount(busd.address, UNIT, 3600*24*21)
    assert(mul/div == 0.9)

    # get a quote for buying 1 Voodoo tokens on BUSD market
    print("what is the USD price of Voodoo?")
    voodoo_price = sybil.getBuyPriceAs("USD", voodoo.address, 1*UNIT)
    print("Voodoo price is", voodoo_price/UNIT)

    print("what is the USD price of BUSD?")
    busd_price = sybil.getBuyPriceAs("USD", busd.address, 1*UNIT)
    print("BUSD Price is", busd_price/UNIT)

    print("get a quote for buying 1 Voodoo tokens on BUSD market")
    quote = bonds.quote(busd.address, UNIT, {'from': accounts[0]})

    # make sure quote is correct
    assert(quote == ((1*UNIT)/100)*90) # MockStrategy always gives 10% discount

    # try to harvest now, it should fail since we haven't executed any orders yet.
    print("try to harvest now, it should fail since we haven't executed any orders yet.")
    with reverts("Rocket: no order"):
        bonds.harvest({'from': accounts[0]})

    # execute quote with max_price less than quoted amount, make sure it fails
    print("execute quote with max_price less than quoted amount, make sure it fails")
    with reverts("Rocket: max price exceeded"):
        bonds.deposit(busd.address, UNIT, int(0.9*quote), {'from': accounts[0]})

    # execute quote exceeding voodoo allocation, make sure it fails
    print("execute quote exceeding voodoo allocation, make sure it fails")
    with reverts("Rocket: insufficient asset allocation for order"):
        bonds.deposit(busd.address, 101*UNIT, 101*10**19, {'from': accounts[0]})

    # execute quote, make sure we have the right price and maturity (21 days)
    print("execute quote, make sure we have the right price and maturity (21 days)")
    tx = bonds.deposit(busd.address, UNIT, quote, {'from': accounts[0]})
    assert(tx.return_value[0] == quote) # price paid

    # make sure tx.return_value[1] which is maturity unix timestamp is greater than now
    assert(tx.return_value[1] > int(time.time()))

    # make sure the treasury address received the BUSD
    print("balance of treasury is now", busd.balanceOf(treasury))
    assert(busd.balanceOf(treasury) == UNIT*0.9)

    # try to harvest now, it should fail since we haven't matured
    print("try to harvest now, it should fail since we haven't matured")
    with reverts("Rocket: order not matured"):
        bonds.harvest({'from': accounts[0]})
    
    # let's wait for the maturity
    print("let's wait for the maturity")
    chain.sleep(3600*24*21)

    # fetch our voodoo balance
    print("fetch our voodoo balance")
    our_voodoo_balance = voodoo.balanceOf(accounts[0])

    # try to harvest now, it should succeed
    print("try to harvest now, it should succeed")
    tx = bonds.harvest({'from': accounts[0]})

    # we should have one more voodoo than before
    print("we should have one more voodoo than before")
    assert(voodoo.balanceOf(accounts[0]) == our_voodoo_balance + UNIT)
    