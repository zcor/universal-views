
# XXX Needs to test against actual values
from ape import *
import pytest

def within_percentage(a, b, percentage):
    diff = abs(a - b)
    max_val = max(abs(a), abs(b))
    return diff <= max_val * percentage


def test_calc_token_fees_withdraw_tng(views, tricrypto_ng, alice):
    assert views.calc_fee_withdraw_one_coin(10 ** 18, 2, tricrypto_ng) > 0

def test_calc_token_fees_withdraw_tos(views, metaregistry, tricrypto_tos, tricrypto_ng, alice):
    assert views.calc_fee_withdraw_one_coin(10 ** 18, 2, tricrypto_tos) > 0

def test_calc_token_fees_withdraw_crveth(views, crveth, alice, metaregistry):
    assert views.calc_fee_withdraw_one_coin(10 ** 18, 1, crveth) > 0

def test_calc_token_fees_withdraw_steth(views, steth, alice, metaregistry):
    assert views.calc_fee_withdraw_one_coin(10 ** 18, 1, steth) > 0

def test_calc_token_fees_withdraw_cvxcrv2(views, cvxcrv, crveth, alice):
    assert views.calc_fee_withdraw_one_coin(10 ** 18, 1, cvxcrv) > 0


