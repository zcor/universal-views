# XXX Needs to test against actual values
from ape import *
import pytest

def within_percentage(a, b, percentage):
    diff = abs(a - b)
    max_val = max(abs(a), abs(b))
    return diff <= max_val * percentage


 
def test_calc_token_fees_amt_tng(views, tricrypto_ng, alice):
    assert views.calc_fee_token_amount([0, 0, 10 ** 18], True, tricrypto_ng) > 0

@pytest.mark.skip()
def test_calc_token_fees_amt_tos(views, metaregistry, tricrypto_tos, tricrypto_ng, alice):
    assert views.calc_fee_token_amount([0, 0, 10 ** 18], True, tricrypto_tos) > 0

@pytest.mark.skip()
def test_calc_token_fees_amt_crveth(views, crveth, alice, metaregistry):
    assert views.calc_fee_token_amount([0, 10 ** 18], True, crveth) > 0

@pytest.mark.skip()
def test_calc_token_fees_amt_steth(views, steth, alice, metaregistry):
    assert views.calc_fee_token_amount([0, 10 ** 18], True, steth) > 0

@pytest.mark.skip()
def test_calc_token_fees_amt_cvxcrv2(views, cvxcrv, crveth, alice):
    assert views.calc_fee_token_amount([0, 10 ** 18], True, cvxcrv) > 0

@pytest.mark.skip()
def test_calc_token_fees_amt_3pool(views, tripool, alice):
    assert views.calc_fee_token_amount(1, 0, 10 ** 18, True, tripool) > 0

