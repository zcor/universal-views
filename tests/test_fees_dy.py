# XXX Needs to test against actual values
from ape import *
import pytest


def test_calc_token_fees_dy_tng(views, tricrypto_ng, alice):
    assert views.calc_fee_get_dy(2, 0, 10 ** 18, tricrypto_ng) > 0

def test_calc_token_fees_dy_tos(views, metaregistry, tricrypto_tos, tricrypto_ng, alice):
    assert views.calc_fee_get_dy(2, 0, 10 ** 18, tricrypto_tos) > 0

def test_calc_token_fees_dy_crveth(views, crveth, alice, metaregistry):
    assert views.calc_fee_get_dy(1, 0, 10 ** 18, crveth) > 0

def test_calc_token_fees_dy_steth(views, steth, alice, metaregistry):
    assert views.calc_fee_get_dy(1, 0, 10 ** 18, steth) > 0

def test_calc_token_fees_dy_cvxcrv2(views, cvxcrv, crveth, alice):
    assert views.calc_fee_get_dy(1, 0, 10 ** 18, cvxcrv) > 0

def test_calc_token_fees_dy_3pool(views, tripool, alice):
    assert views.calc_fee_get_dy(1, 0, 10 ** 18, tripool) > 0

