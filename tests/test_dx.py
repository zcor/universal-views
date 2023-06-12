from ape import *
import pytest

def within_percentage(a, b, percentage):
    diff = abs(a - b)
    max_val = max(abs(a), abs(b))
    return diff <= max_val * percentage

def test_get_dx_tng(views, tricrypto_ng, alice):
    weth = Contract(tricrypto_ng.coins(2))
    weth.deposit(value=10**18, sender=alice)
    weth.approve(tricrypto_ng, 10 ** 18, sender=alice)

    stablecoin = Contract(tricrypto_ng.coins(0))
    target = 10 ** stablecoin.decimals()

    dx = views.get_dx(2, 0, target, tricrypto_ng)
    tricrypto_ng.exchange(2, 0, dx, 0, sender=alice)

    assert within_percentage(target, stablecoin.balanceOf(alice), .00001)


def test_get_dx_tos(views, tricrypto_tos,alice):
    weth = Contract(tricrypto_tos.coins(2))
    weth.deposit(value=10**18, sender=alice)
    weth.approve(tricrypto_tos, 10 ** 18, sender=alice)

    stablecoin = Contract(tricrypto_tos.coins(0))
    target = 10 ** stablecoin.decimals()

    dx = views.get_dx(2, 0, target, tricrypto_tos)
    tricrypto_tos.exchange(2, 0, dx, 0, sender=alice)

    assert within_percentage(target, stablecoin.balanceOf(alice), .00001)

@pytest.mark.skip()
def test_get_dx_crveth(views, crveth, alice):
    token = Contract(crveth.coins(1))
    init_bal = token.balanceOf(alice)
    target = 10 ** token.decimals()

    dx = views.get_dx(0, 1, target, crveth)

    weth = Contract(crveth.coins(0))
    weth.deposit(value=dx, sender=alice)
    weth.approve(crveth, dx, sender=alice)

    crveth.exchange(0, 1, dx, 0, sender=alice)

    assert within_percentage(target - init_bal, token.balanceOf(alice), .00001)

def test_get_dx_steth(views, steth, alice):
    target = 10 ** 18
    dx = views.get_dx(0, 1, target, steth)
    actual = steth.exchange(0, 1, dx, 0, value=dx, sender=alice)

    token = Contract(steth.coins(1))
    assert within_percentage(target, token.balanceOf(alice), .00001)


def test_get_dx_cvxcrv2(views, cvxcrv, alice, crveth):
    crv = Contract(cvxcrv.coins(0))
    
    weth = Contract(crveth.coins(0))
    weth.deposit(value=10**18, sender=alice)
    weth.approve(crveth, 10 ** 18, sender=alice)
    crveth.exchange(0, 1, 10 ** 18, 0, sender=alice)

    crv_bal = crv.balanceOf(alice)
    assert crv_bal > 0

    crv.approve(cvxcrv, crv_bal, sender=alice)

    target = 10 ** 18
    dx = views.get_dx(0, 1, target, cvxcrv)
    cvxcrv.exchange(0, 1, dx, 0, sender=alice)

    assert within_percentage(target, Contract(cvxcrv.coins(1)).balanceOf(alice), .00001)


