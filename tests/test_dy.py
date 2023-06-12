from ape import *
import pytest


def within_percentage(a, b, percentage):
    diff = abs(a - b)
    max_val = max(abs(a), abs(b))
    return diff <= max_val * percentage


def test_get_dy_tng(views, tricrypto_ng, alice):
    expected = views.get_dy(2, 0, 10 ** 18, tricrypto_ng)
    stablecoin = Contract(tricrypto_ng.coins(0))

    weth = Contract(tricrypto_ng.coins(2))
    weth.deposit(value=10**18, sender=alice)
    weth.approve(tricrypto_ng, 10 ** 18, sender=alice)

    tricrypto_ng.exchange(2, 0, 10 ** 18, 0, sender=alice)
    within_percentage(expected, stablecoin.balanceOf(alice), .00001)


def test_get_dy_tos(views, tricrypto_tos, alice):
    assert views.get_dy(1, 0, 10 ** 8, tricrypto_tos) > 0

    expected = views.get_dy(2, 0, 10 ** 18, tricrypto_tos)
    stablecoin = Contract(tricrypto_tos.coins(0))

    weth = Contract(tricrypto_tos.coins(2))
    weth.deposit(value=10**18, sender=alice)
    weth.approve(tricrypto_tos, 10 ** 18, sender=alice)

    tricrypto_tos.exchange(2, 0, 10 ** 18, 0, sender=alice)
    assert within_percentage(expected, stablecoin.balanceOf(alice), .00001)


def test_get_dy_crveth(views, crveth, alice):
    expected = views.get_dy(0, 1, 10 ** 18, crveth)
    token = Contract(crveth.coins(1))

    weth = Contract(crveth.coins(0))
    weth.deposit(value=10**18, sender=alice)
    weth.approve(crveth, 10 ** 18, sender=alice)

    crveth.exchange(0, 1, 10 ** 18, 0, sender=alice)
    assert within_percentage(expected, token.balanceOf(alice), .00001)
 

def test_get_dy_steth(views, steth, alice):
    expected = views.get_dy(0, 1, 10 ** 18, steth)

    token = Contract(steth.coins(1))
    actual = steth.exchange(0, 1, 10 ** 18, 0, value=10**18, sender=alice)

    assert within_percentage(expected, token.balanceOf(alice), .00001)


def test_get_dy_cvxcrv2(views, cvxcrv, alice,crveth):
    crv = Contract(cvxcrv.coins(0))
    
    weth = Contract(crveth.coins(0))
    weth.deposit(value=10**18, sender=alice)
    weth.approve(crveth, 10 ** 18, sender=alice)
    crveth.exchange(0, 1, 10 ** 18, 0, sender=alice)

    crv_bal = crv.balanceOf(alice)
    assert crv_bal > 0

    crv.approve(cvxcrv, crv_bal, sender=alice)

    expected = views.get_dy(0, 1, crv_bal, cvxcrv)
    cvxcrv.exchange(0, 1, crv_bal, 0, sender=alice)

    assert within_percentage(expected, Contract(cvxcrv.coins(1)).balanceOf(alice), .00001)


@pytest.mark.skip()
def test_get_dy_pegkeeper(views, pegkeeper, alice):
    assert views.get_dy(1, 0, 10 ** 18, pegkeeper) > 0
