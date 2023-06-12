#!/usr/bin/python3

import pytest
from ape import *


@pytest.fixture(scope="module")
def alice():
    return accounts.test_accounts[0]


@pytest.fixture(scope="module")
def views(math3, alice):
    return alice.deploy(project.UniversalViews, math3)


@pytest.fixture(scope="module")
def math3(alice):
    return alice.deploy(project.CurveCryptoMathOptimized3)


@pytest.fixture(scope="module")
def math2(alice):
    return alice.deploy(project.CurveCryptoMathOptimized2)


@pytest.fixture(scope="module")
def tricrypto_ng():
    # Test new generation of TriCrypto pools
    return project.CurveTricryptoOptimizedWETH.at('0xf5f5b97624542d72a9e06f04804bf81baa15e2b4')


@pytest.fixture(scope="module")
def tricrypto_tos():
    # Test old generation of TriCrypto pools
    return Contract('0xd51a44d3fae010294c616388b506acda1bfaae46')


@pytest.fixture(scope="module")
def cvxcrv():
    # Test newer generation of v2 pairs
    return Contract('0x971add32ea87f10bd192671630be3be8a11b8623')


@pytest.fixture(scope="module")
def crveth():
    # Test older generation of v2 pairs
    return Contract('0x8301ae4fc9c624d1d396cbdaa1ed877821d7c511')

@pytest.fixture(scope="module")
def steth():
    # Test older generation of v1 pairs
    return Contract('0xdc24316b9ae028f1497c275eb9192a3ea0f67022')


@pytest.fixture(scope="module")
def pegkeeper():
    # Test crvUSD Peg Keeper Pools
    return Contract('0xCa978A0528116DDA3cbA9ACD3e68bc6191CA53D0')


@pytest.fixture(scope="module")
def tripool():
    # Test classic 3pool 
    return Contract('0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7')


@pytest.fixture(scope="module")
def metaregistry():
    return Contract('0xF98B45FA17DE75FB1aD0e7aFD971b0ca00e379fC')



