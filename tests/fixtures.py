from brownie import *

def test_get_dy(views):
    assert views.get_dy(1, 0, 10 ** 18, tricrypto, 3) > 0

