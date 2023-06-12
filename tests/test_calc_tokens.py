from ape import *
import pytest

def within_percentage(a, b, percentage):
    diff = abs(a - b)
    max_val = max(abs(a), abs(b))
    return diff <= max_val * percentage

def test_calc_tokens_tng(views, tricrypto_ng, alice):
    liq_arr = [0, 0, 10 ** 18]
    assert views.calc_token_amount(liq_arr, True, tricrypto_ng) > 0

    expected = views.calc_token_amount(liq_arr, True, tricrypto_ng)

    weth = Contract(tricrypto_ng.coins(2))
    weth.deposit(value=10**18, sender=alice)
    weth.approve(tricrypto_ng, 10 ** 18, sender=alice)

    tricrypto_ng.add_liquidity(liq_arr, 0, sender=alice)
    
    assert within_percentage(expected, tricrypto_ng.balanceOf(alice), .00001)

def test_calc_tokens_tos(views, metaregistry, tricrypto_tos, tricrypto_ng, alice):
    liq_arr = [0, 0, 10 ** 18]
    assert views.calc_token_amount(liq_arr, True, tricrypto_tos) > 0

    expected = views.calc_token_amount(liq_arr, True, tricrypto_tos)

    weth = Contract(tricrypto_tos.coins(2))
    weth.deposit(value=10**18, sender=alice)
    weth.approve(tricrypto_tos, 10 ** 18, sender=alice)

    tricrypto_tos.add_liquidity(liq_arr, 0, sender=alice)
    final_bal = Contract(metaregistry.get_lp_token(tricrypto_tos)).balanceOf(alice) 
    assert within_percentage(expected, final_bal , .00001)


def test_calc_tokens_crveth(views, crveth, alice, metaregistry):
    liq_arr = [10 ** 18, 0]
    expected = views.calc_token_amount(liq_arr, True, crveth)

    weth = Contract(crveth.coins(0))
    weth.deposit(value=10 ** 18, sender=alice)
    weth.approve(crveth, 10 ** 18, sender=alice)

    crveth.add_liquidity(liq_arr, 0, sender=alice)
    final_bal = Contract(metaregistry.get_lp_token(crveth)).balanceOf(alice) 
    assert within_percentage(expected, final_bal, .00001)


def test_calc_tokens_steth(views, steth, alice, metaregistry):
    liq_arr = [10 ** 18, 0]
    expected = views.calc_token_amount(liq_arr, True, steth)

    steth.add_liquidity(liq_arr, 0, sender=alice, value=10 ** 18)
     
    final_bal = Contract(metaregistry.get_lp_token(steth)).balanceOf(alice) 
    
    # XXX Why so far off?
    assert within_percentage(expected, final_bal, .1)


def test_calc_tokens_cvxcrv2(views, cvxcrv, crveth, alice):
    weth = Contract(crveth.coins(0))
    crv = Contract(crveth.coins(1))

    weth.deposit(value=10**18, sender=alice)
    weth.approve(crveth, 10 ** 18, sender=alice)
    crveth.exchange(0, 1, 10 ** 18, 0, sender=alice)
    crv_bal = crv.balanceOf(alice)
    assert crv_bal > 0

    liq_arr = [crv_bal, 0]
    crv.approve(cvxcrv, crv_bal, sender=alice)

    expected = views.calc_token_amount(liq_arr, True, cvxcrv)
    cvxcrv.add_liquidity(liq_arr, 0, sender=alice)
    
    # XXX Why so far off?
    assert within_percentage(expected, cvxcrv.balanceOf(alice), .01)


